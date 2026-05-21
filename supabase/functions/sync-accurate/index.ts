import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

// =========================================================================
// HELPER: Normalisasi customerNo → selalu UPPERCASE, e.g. c.0001 → C.0001
// Agar perbandingan case-insensitive dan tidak double karena perbedaan huruf
// =========================================================================
function normalizeCustomerNo(raw: string): string {
  return (raw ?? '').trim().toUpperCase();
}

serve(async (req) => {
  console.log("Menjalankan Auto-Sync Accurate...");

  // Gunakan SERVICE_ROLE_KEY agar bisa menembus RLS database saat berjalan di background
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );

  try {
    // 1. Ambil Kredensial Accurate dari app_config
    const { data: configs } = await supabase.from('app_config').select('key, value').in('key', ['accurate_access_token', 'accurate_db_host', 'accurate_db_session', 'default_conversion_rate']);

    let token = '', host = '', session = '', defaultRate = 10000;
    configs?.forEach((c: { key: string; value: string }) => {
      if (c.key === 'accurate_access_token') token = c.value;
      if (c.key === 'accurate_db_host') host = c.value;
      if (c.key === 'accurate_db_session') session = c.value;
      if (c.key === 'default_conversion_rate') defaultRate = parseInt(c.value) || 10000;
    });

    if (!token || !host || !session) throw new Error("Kredensial Accurate tidak lengkap di database.");

    // 2. Ambil User yang APPROVED dan punya accurate_customer_id (berisi customerNo, misal C.0001)
    const { data: users } = await supabase.from('profiles')
      .select('id, full_name, points, accurate_customer_id, point_conversion_rate')
      .eq('approval_status', 'APPROVED')
      .not('accurate_customer_id', 'is', null)
      .neq('accurate_customer_id', '');

    if (!users || users.length === 0) return new Response("Tidak ada user untuk disync.", { status: 200 });

    // [REVISI A] Set Jendela Waktu: hanya ambil faktur & retur mulai 1 Januari 2026
    // Sebelumnya: jendela dinamis 7 hari ke belakang dari hari ini
    const today = new Date();
    const formatDate = (d: Date) => `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
    const dateStart = "01/01/2026";
    const dateEnd = formatDate(today);

    let totalInvoices = 0;

    for (const user of users) {
      const userId = user.id;

      // PERUBAHAN UTAMA: accurate_customer_id sekarang berisi customerNo (C.0001)
      // Normalisasi ke UPPERCASE agar perbandingan case-insensitive
      const customerNo = normalizeCustomerNo(user.accurate_customer_id);
      if (!customerNo) continue;

      const rate = user.point_conversion_rate || defaultRate;
      let pointsToUpdate = 0;

      // ─────────────────────────────────────────────────────────────────
      // ANTI-DOUBLE: Ambil history yang sudah diklaim, sort ascending
      // (terlama duluan) agar jika ada duplikat di DB, yang diproses
      // adalah entri yang paling lama — sesuai aturan "ambil yang terlama"
      // ─────────────────────────────────────────────────────────────────
      const { data: history } = await supabase
        .from('point_history')
        .select('reference_id, reference_type, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: true }); // terlama dulu

      // Karena sudah sorted ascending, Set otomatis hanya akan memuat
      // entri pertama (terlama) jika ada referensi yang sama lebih dari sekali
      const claimedInvoices = new Set(
        history?.filter((h: { reference_type: string }) => h.reference_type === 'INVOICE')
               .map((h: { reference_id: string }) => h.reference_id)
      );
      const claimedReturns = new Set(
        history?.filter((h: { reference_type: string }) => h.reference_type === 'RETURN')
               .map((h: { reference_id: string }) => h.reference_id)
      );

      // ================= FAKTUR PENJUALAN =================
      // PERUBAHAN: Filter berdasarkan customerNo (C.0001), bukan internal ID angka
      const invoiceUrl =
        `${host}/accurate/api/sales-invoice/list.do` +
        `?fields=id,number,grandTotal,statusName,customer.id,customer.customerNo` +
        `&filter.transDate.op=BETWEEN` +
        `&filter.transDate.val[0]=${dateStart}` +
        `&filter.transDate.val[1]=${dateEnd}` +
        `&filter.customer.customerNo.op=EQUAL` +
        `&filter.customer.customerNo.val[0]=${encodeURIComponent(customerNo)}`;

      const resList = await fetch(invoiceUrl, {
        headers: { 'Authorization': `Bearer ${token}`, 'X-Session-ID': session }
      });
      const listData = await resList.json();

      if (listData.s && listData.d) {
        for (const inv of listData.d) {
          const invNumber: string = inv.number;
          if (!invNumber) continue;

          // [REVISI B] Skip faktur yang nomornya diawali "SI" (tidak berhak dapat poin)
          if (invNumber.toUpperCase().startsWith('SI')) {
            console.log(`  -> [SKIP] Faktur ${invNumber} diawali "SI", tidak diproses poin.`);
            continue;
          }

          // Cross-check customerNo di level list (case-insensitive)
          const listCustNo = normalizeCustomerNo(
            inv['customer.customerNo'] ?? inv?.customer?.customerNo ?? ''
          );
          if (listCustNo && listCustNo !== customerNo) {
            console.log(`  -> [SKIP LIST] Faktur ${invNumber} milik ${listCustNo}, bukan ${customerNo}`);
            continue;
          }

          // Lewati jika sudah pernah diklaim (anti-double)
          if (claimedInvoices.has(invNumber)) {
            console.log(`  -> [SUDAH KLAIM] Faktur ${invNumber} sudah diklaim. Melewati...`);
            continue;
          }

          // Tarik Detail hanya jika belum pernah diklaim
          const detailUrl = `${host}/accurate/api/sales-invoice/detail.do?id=${inv.id}`;
          const resDetail = await fetch(detailUrl, {
            headers: { 'Authorization': `Bearer ${token}`, 'X-Session-ID': session }
          });
          const detailData = await resDetail.json();

          if (detailData.s && detailData.d) {
            const detail = detailData.d;

            // Cross-check MUTLAK customerNo di level detail (case-insensitive)
            const detailCustNo = normalizeCustomerNo(
              detail?.customer?.customerNo ?? ''
            );
            if (detailCustNo && detailCustNo !== customerNo) {
              console.log(`  -> [SKIP MUTLAK] Faktur ${invNumber} aslinya milik ${detailCustNo}, bukan ${customerNo}! DITOLAK!`);
              continue;
            }

            const statusUpper = (detail.statusName || '').toUpperCase();

            // Cek jika LUNAS
            if (statusUpper === 'LUNAS' || statusUpper === 'PAID') {
              const nominal = detail.grandTotal || 0;
              const earned = Math.floor(nominal / rate);

              if (earned > 0) {
                await supabase.from('point_history').insert({
                  user_id: userId,
                  amount: earned,
                  description: `Faktur Lunas #${invNumber} (Auto-Sync)`,
                  reference_type: 'INVOICE',
                  reference_id: invNumber,
                });
                pointsToUpdate += earned;
                totalInvoices++;
                console.log(`  -> [BERHASIL] Faktur ${invNumber} +${earned} Poin`);
              }
            }
          }
        }
      }

      // ================= RETUR PENJUALAN =================
      // PERUBAHAN: Filter berdasarkan customerNo (C.0001), bukan internal ID angka
      const returnUrl =
        `${host}/accurate/api/sales-return/list.do` +
        `?fields=id,number,grandTotal,totalAmount,statusName,customer.id,customer.customerNo` +
        `&filter.transDate.op=BETWEEN` +
        `&filter.transDate.val[0]=${dateStart}` +
        `&filter.transDate.val[1]=${dateEnd}` +
        `&filter.customer.customerNo.op=EQUAL` +
        `&filter.customer.customerNo.val[0]=${encodeURIComponent(customerNo)}`;

      const resReturnList = await fetch(returnUrl, {
        headers: { 'Authorization': `Bearer ${token}`, 'X-Session-ID': session }
      });
      const returnListData = await resReturnList.json();

      if (returnListData.s && returnListData.d) {
        for (const ret of returnListData.d) {
          const retNumber: string = ret.number;
          if (!retNumber) continue;

          // Cross-check customerNo di level list (case-insensitive)
          const listRetCustNo = normalizeCustomerNo(
            ret['customer.customerNo'] ?? ret?.customer?.customerNo ?? ''
          );
          if (listRetCustNo && listRetCustNo !== customerNo) {
            console.log(`  -> [SKIP LIST RETUR] Retur ${retNumber} milik ${listRetCustNo}, bukan ${customerNo}`);
            continue;
          }

          // Lewati jika sudah pernah dipotong (anti-double)
          if (claimedReturns.has(retNumber)) {
            console.log(`  -> [SUDAH KLAIM RETUR] Retur ${retNumber} sudah diproses. Melewati...`);
            continue;
          }

          // Tarik Detail Retur
          const retDetailUrl = `${host}/accurate/api/sales-return/detail.do?id=${ret.id}`;
          const resRetDetail = await fetch(retDetailUrl, {
            headers: { 'Authorization': `Bearer ${token}`, 'X-Session-ID': session }
          });
          const retDetailData = await resRetDetail.json();

          if (retDetailData.s && retDetailData.d) {
            const retDetail = retDetailData.d;

            // Cross-check MUTLAK customerNo di level detail (case-insensitive)
            const detailRetCustNo = normalizeCustomerNo(
              retDetail?.customer?.customerNo ?? ''
            );
            if (detailRetCustNo && detailRetCustNo !== customerNo) {
              console.log(`  -> [SKIP MUTLAK RETUR] Retur ${retNumber} aslinya milik ${detailRetCustNo}, bukan ${customerNo}! DITOLAK!`);
              continue;
            }

            const nominalRetur = retDetail.grandTotal || retDetail.totalAmount || ret.grandTotal || ret.totalAmount || 0;
            const deducted = Math.floor(nominalRetur / rate);

            if (deducted > 0) {
              await supabase.from('point_history').insert({
                user_id: userId,
                amount: -deducted,
                description: `Retur Penjualan #${retNumber} (Auto-Sync)`,
                reference_type: 'RETURN',
                reference_id: retNumber,
              });
              pointsToUpdate -= deducted;
              console.log(`  -> [RETUR] Retur ${retNumber} -${deducted} Poin`);
            }
          }
        }
      }

      // Update Poin Profil jika ada perubahan (kalkulasi ulang akurat dari semua history)
      if (pointsToUpdate !== 0) {
        const { data: allHistory } = await supabase
          .from('point_history')
          .select('amount')
          .eq('user_id', userId);

        const finalPoints = Math.max(
          0,
          allHistory?.reduce((sum: number, item: { amount: number }) => sum + (item.amount || 0), 0) ?? 0
        );
        await supabase.from('profiles').update({ points: finalPoints }).eq('id', userId);
        console.log(`  => [UPDATE] Poin profil diperbarui menjadi: ${finalPoints}`);
      }
    }

    return new Response(JSON.stringify({ message: "Sync berhasil", invoices_synced: totalInvoices }), {
      headers: { "Content-Type": "application/json" }, status: 200
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: (error as Error).message }), { status: 500 });
  }
});