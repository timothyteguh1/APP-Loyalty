import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

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
    configs?.forEach(c => {
      if (c.key === 'accurate_access_token') token = c.value;
      if (c.key === 'accurate_db_host') host = c.value;
      if (c.key === 'accurate_db_session') session = c.value;
      if (c.key === 'default_conversion_rate') defaultRate = parseInt(c.value) || 10000;
    });

    if (!token || !host || !session) throw new Error("Kredensial Accurate tidak lengkap di database.");

    // 2. Ambil User yang APPROVED
    const { data: users } = await supabase.from('profiles')
      .select('id, full_name, points, accurate_customer_id, point_conversion_rate')
      .eq('approval_status', 'APPROVED')
      .not('accurate_customer_id', 'is', null);

    if (!users || users.length === 0) return new Response("Tidak ada user untuk disync.", { status: 200 });

    // Set Jendela Waktu (Hanya cek 7 hari terakhir agar super ringan!)
    const today = new Date();
    const lastWeek = new Date();
    lastWeek.setDate(today.getDate() - 7);
    
    const formatDate = (d: Date) => `${d.getDate().toString().padStart(2, '0')}/${(d.getMonth() + 1).toString().padStart(2, '0')}/${d.getFullYear()}`;
    const dateStart = formatDate(lastWeek);
    const dateEnd = formatDate(today);

    let totalInvoices = 0;

    for (const user of users) {
      const userId = user.id;
      const customerId = user.accurate_customer_id;
      const rate = user.point_conversion_rate || defaultRate;
      let pointsToUpdate = 0;

      // Ambil Daftar Hitam (Supaya tidak double)
      const { data: history } = await supabase.from('point_history').select('reference_id, reference_type').eq('user_id', userId);
      const claimedInvoices = new Set(history?.filter(h => h.reference_type === 'INVOICE').map(h => h.reference_id));
      
      // ================= FAKTUR PENJUALAN =================
      const invoiceUrl = `${host}/accurate/api/sales-invoice/list.do?fields=id,number,grandTotal,statusName,customer.id&filter.transDate.op=BETWEEN&filter.transDate.val[0]=${dateStart}&filter.transDate.val[1]=${dateEnd}&filter.customer.id.op=EQUAL&filter.customer.id.val[0]=${customerId}`;
      
      const resList = await fetch(invoiceUrl, { headers: { 'Authorization': `Bearer ${token}`, 'X-Session-ID': session }});
      const listData = await resList.json();

      if (listData.s && listData.d) {
        for (const inv of listData.d) {
          const invNumber = inv.number;
          
          // Lewati jika sudah pernah diklaim (Efisiensi Daftar Hitam)
          if (claimedInvoices.has(invNumber)) continue;

          // Tarik Detail hanya jika belum pernah diklaim
          const detailUrl = `${host}/accurate/api/sales-invoice/detail.do?id=${inv.id}`;
          const resDetail = await fetch(detailUrl, { headers: { 'Authorization': `Bearer ${token}`, 'X-Session-ID': session }});
          const detailData = await resDetail.json();

          if (detailData.s && detailData.d) {
            const detail = detailData.d;
            const statusUpper = (detail.statusName || '').toUpperCase();
            
            // Cek jika LUNAS
            if (statusUpper === 'LUNAS' || statusUpper === 'PAID') {
               const nominal = detail.grandTotal || 0;
               const earned = Math.floor(nominal / rate);
               
               if (earned > 0) {
                 await supabase.from('point_history').insert({
                   user_id: userId, amount: earned, description: `Faktur Lunas #${invNumber} (Auto-Sync)`,
                   reference_type: 'INVOICE', reference_id: invNumber
                 });
                 pointsToUpdate += earned;
                 totalInvoices++;
               }
            }
          }
        }
      }

      // (Catatan: Untuk menghemat response, blok Retur bisa ditambahkan polanya sama persis seperti di atas).

      // Update Poin Profil jika ada perubahan
      if (pointsToUpdate > 0) {
        const { data: allHistory } = await supabase.from('point_history').select('amount').eq('user_id', userId);
        const finalPoints = allHistory?.reduce((sum, item) => sum + (item.amount || 0), 0) || 0;
        await supabase.from('profiles').update({ points: Math.max(0, finalPoints) }).eq('id', userId);
      }
    }

    return new Response(JSON.stringify({ message: "Sync berhasil", invoices_synced: totalInvoices }), {
      headers: { "Content-Type": "application/json" }, status: 200
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});