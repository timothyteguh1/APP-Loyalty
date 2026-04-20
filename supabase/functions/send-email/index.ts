import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const SMTP_USER = Deno.env.get("SMTP_USER") || "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function buildEmail(type: string, data: any): { subject: string; html: string } {
  const userName = data?.userName || "User";

  const wrapper = (headerBg: string, headerTitle: string, bodyContent: string) => `
    <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px">
      <div style="background:linear-gradient(135deg,${headerBg});padding:30px;border-radius:16px 16px 0 0;text-align:center">
        <h1 style="color:white;margin:0;font-size:22px">${headerTitle}</h1>
      </div>
      <div style="background:white;padding:30px;border:1px solid #E5E7EB;border-radius:0 0 16px 16px">
        <p style="font-size:15px;color:#1F2937">Halo <strong>${userName}</strong>,</p>
        ${bodyContent}
        <hr style="border:none;border-top:1px solid #E5E7EB;margin:24px 0"/>
        <p style="color:#9CA3AF;font-size:11px;text-align:center;margin:0">Upsol Loyalty &copy; 2024</p>
      </div>
    </div>`;

  switch (type) {
    // ============================================================
    // ADMIN → USER
    // ============================================================
    case "APPROVED":
      return {
        subject: "✅ Akun Upsol Kamu Sudah Disetujui!",
        html: wrapper("#10B981,#059669", "🎉 Selamat!", `
          <p>Akun toko kamu di <strong>Upsol Loyalty</strong> sudah <span style="color:#10B981;font-weight:bold">DISETUJUI</span>!</p>
          <p>Sekarang kamu bisa:</p>
          <ul style="line-height:1.8">
            <li>📱 Login ke aplikasi Upsol Loyalty</li>
            <li>🎯 Scan QR Code untuk kumpulkan poin</li>
            <li>🎁 Tukar poin dengan hadiah menarik</li>
          </ul>`),
      };

    case "REJECTED":
      return {
        subject: "❌ Pendaftaran Upsol Ditolak",
        html: wrapper("#EF4444,#DC2626", "Pendaftaran Ditolak", `
          <p>Mohon maaf, pendaftaran akun toko kamu belum bisa disetujui.</p>
          <div style="background:#FFF8E1;border:1px solid #FFE082;border-radius:12px;padding:16px;margin:16px 0">
            <strong>📋 Alasan:</strong><br/>${data?.reason || "Tidak ada alasan spesifik."}
          </div>
          <p>Kamu bisa memperbaiki data dan mengirim ulang pendaftaran melalui aplikasi.</p>`),
      };

    case "MANUAL_POINTS": {
      const amount = data?.amount || 0;
      const isAdd = amount > 0;
      return {
        subject: isAdd ? `⭐ +${amount} Poin Ditambahkan!` : `📉 ${amount} Poin Dikurangi`,
        html: wrapper(
          isAdd ? "#10B981,#059669" : "#EF4444,#DC2626",
          isAdd ? "⭐ Poin Ditambahkan!" : "📉 Poin Dikurangi",
          `
          <p>Admin telah ${isAdd ? "menambahkan" : "mengurangi"} poin kamu:</p>
          <div style="background:${isAdd ? "#F0FDF4" : "#FEF2F2"};border-radius:12px;padding:20px;margin:16px 0;text-align:center">
            <p style="font-size:36px;font-weight:900;color:${isAdd ? "#10B981" : "#EF4444"};margin:0">${isAdd ? "+" : ""}${amount}</p>
            <p style="color:#6B7280;margin:4px 0 0">Poin</p>
          </div>
          <p><strong>Alasan:</strong> ${data?.reason || "-"}</p>`),
      };
    }

    case "WELCOME_NEW_USER":
      return {
        subject: "🎉 Selamat Datang di Upsol Loyalty!",
        html: wrapper("#D32F2F,#B71C1C", "🎉 Selamat Datang!", `
          <p>Akun toko kamu telah didaftarkan di <strong>Upsol Loyalty</strong> oleh Admin.</p>
          <div style="background:#F8F9FC;border-radius:12px;padding:20px;margin:16px 0">
            <p style="margin:0 0 8px"><strong>📧 Email:</strong> ${data?.email || "-"}</p>
            <p style="margin:0 0 8px"><strong>🔑 Password:</strong> ${data?.password || "-"}</p>
          </div>
          <div style="background:#FFF8E1;border:1px solid #FFE082;border-radius:12px;padding:12px;margin:16px 0">
            <p style="margin:0;font-size:12px;color:#92400E">⚠️ Segera ganti password setelah login pertama demi keamanan akunmu.</p>
          </div>
          <p>Silakan download aplikasi dan login untuk mulai mengumpulkan poin!</p>`),
      };

    case "POINTS_EARNED":
      return {
        subject: `⭐ +${data?.pointsAmount || 0} Poin dari Faktur!`,
        html: wrapper("#F59E0B,#D97706", "⭐ Poin dari Faktur!", `
          <p>Poin kamu bertambah dari sinkronisasi faktur penjualan:</p>
          <div style="background:#F0FDF4;border-radius:12px;padding:20px;margin:16px 0;text-align:center">
            <p style="font-size:36px;font-weight:900;color:#10B981;margin:0">+${data?.pointsAmount || 0}</p>
            <p style="color:#6B7280;margin:4px 0 0">Poin</p>
          </div>
          <p>Kumpulkan terus dan tukar dengan hadiah menarik!</p>`),
      };

    case "ANNUAL_RESET":
      return {
        subject: "🔄 Reset Poin Tahunan Upsol Loyalty",
        html: wrapper("#6B7280,#4B5563", "🔄 Reset Poin Tahunan", `
          <p>Sesuai kebijakan program loyalty, poin tahunan kamu telah di-reset.</p>
          <div style="background:#FEF2F2;border-radius:12px;padding:20px;margin:16px 0;text-align:center">
            <p style="font-size:36px;font-weight:900;color:#EF4444;margin:0">-${data?.pointsLost || 0}</p>
            <p style="color:#6B7280;margin:4px 0 0">Poin hangus</p>
          </div>
          <p>Saldo poin kamu sekarang <strong>0</strong>. Yuk mulai kumpulkan lagi!</p>`),
      };

    // ============================================================
    // USER → USER SENDIRI
    // ============================================================
    case "REWARD_CLAIMED":
      return {
        subject: "🎁 Hadiah Berhasil Diklaim!",
        html: wrapper("#D32F2F,#B71C1C", "🎁 Hadiah Diklaim!", `
          <p>Kamu berhasil mengklaim hadiah:</p>
          <div style="background:#F8F9FC;border-radius:12px;padding:20px;margin:16px 0;text-align:center">
            <p style="font-size:18px;font-weight:bold;color:#1A1A2E;margin:0">${data?.rewardName || "Hadiah"}</p>
          </div>
          <p>Buka menu <strong>History</strong> di aplikasi untuk melihat detail voucher kamu. Tunjukkan ke kasir/admin saat penukaran.</p>`),
      };

    case "QR_POINTS":
      return {
        subject: `⭐ +${data?.pointsAmount || 0} Poin dari QR Scan!`,
        html: wrapper("#8B5CF6,#7C3AED", "⭐ Poin dari QR!", `
          <p>Kamu berhasil scan QR Code dan mendapat poin:</p>
          <div style="background:#F0FDF4;border-radius:12px;padding:20px;margin:16px 0;text-align:center">
            <p style="font-size:36px;font-weight:900;color:#10B981;margin:0">+${data?.pointsAmount || 0}</p>
            <p style="color:#6B7280;margin:4px 0 0">Poin</p>
          </div>
          <p>QR Code: <code>${data?.qrCode || "-"}</code></p>`),
      };

    // ============================================================
    // USER → ADMIN
    // ============================================================
    case "NEW_REGISTRATION":
      return {
        subject: `📋 Pendaftaran Baru: ${userName}`,
        html: wrapper("#3B82F6,#2563EB", "📋 User Baru Mendaftar", `
          <p>Ada pendaftaran toko baru yang perlu di-review:</p>
          <div style="background:#F8F9FC;border-radius:12px;padding:20px;margin:16px 0">
            <p style="margin:0 0 8px"><strong>🏪 Nama Toko:</strong> ${userName}</p>
            <p style="margin:0"><strong>📱 No HP:</strong> ${data?.userPhone || "-"}</p>
          </div>
          <p>Silakan buka <strong>Admin Panel → KYC Approval</strong> untuk mereview.</p>`),
      };

    case "RESUBMISSION":
      return {
        subject: `🔄 Data Dikirim Ulang: ${userName}`,
        html: wrapper("#F59E0B,#D97706", "🔄 Pengiriman Ulang Data", `
          <p>User <strong>${userName}</strong> telah memperbaiki dan mengirim ulang data pendaftaran setelah ditolak.</p>
          <p>Silakan buka <strong>Admin Panel → KYC Approval → Tab Pending</strong> untuk mereview ulang.</p>`),
      };

    // ============================================================
    // CUSTOM / BROADCAST
    // ============================================================
    case "CUSTOM":
      return {
        subject: data?.customSubject || "Notifikasi Upsol Loyalty",
        html: wrapper("#D32F2F,#B71C1C", "Upsol Loyalty", `
          <p>${data?.customBody || ""}</p>`),
      };

    default:
      return { subject: "Notifikasi Upsol", html: `<p>Halo ${userName}</p>` };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!SMTP_USER || !SMTP_PASS) throw new Error("SMTP credentials not configured");

    const { to, type, data } = await req.json();
    if (!to || !type) throw new Error("Missing: to, type");

    const { subject, html } = buildEmail(type, data);

    const client = new SMTPClient({
      connection: {
        hostname: "smtp.gmail.com",
        port: 465,
        tls: true,
        auth: { username: SMTP_USER, password: SMTP_PASS },
      },
    });

    await client.send({
      from: `Upsol Loyalty <${SMTP_USER}>`,
      to: to,
      subject: subject,
      content: "auto",
      html: html,
    });

    await client.close();

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    });
  }
});