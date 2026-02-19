import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Privacy Policy", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. Pendahuluan"),
            _buildSectionText(
              "Selamat datang di Aplikasi Upsol Loyalty. Kami menghargai privasi Anda dan berkomitmen untuk melindungi data pribadi Anda."
            ),
            
            _buildSectionTitle("2. Data yang Kami Kumpulkan"),
            _buildSectionText(
              "Kami mengumpulkan informasi berikut untuk memberikan layanan terbaik:\n"
              "• Informasi Akun: Nama, Alamat Email, dan Password.\n"
              "• Profil Pengguna: Foto Profil dan Domisili.\n"
              "• Aktivitas: Riwayat Poin dan Penukaran Hadiah."
            ),

            _buildSectionTitle("3. Penggunaan Akses Perangkat"),
            _buildSectionText(
              "Aplikasi ini membutuhkan izin akses tertentu:\n"
              "• Kamera: Digunakan untuk memindai QR Code dan mengambil foto profil.\n"
              "• Galeri: Digunakan untuk mengunggah foto profil dari penyimpanan Anda."
            ),

            _buildSectionTitle("4. Keamanan Data"),
            _buildSectionText(
              "Data Anda disimpan dengan aman di server kami (Supabase). Kami tidak membagikan informasi pribadi Anda kepada pihak ketiga tanpa izin Anda, kecuali diwajibkan oleh hukum."
            ),

            _buildSectionTitle("5. Penghapusan Akun"),
            _buildSectionText(
              "Anda memiliki hak untuk menghapus akun Anda kapan saja melalui menu Settings > Hapus Akun. Tindakan ini akan menghapus seluruh data pribadi dan poin Anda secara permanen."
            ),

            _buildSectionTitle("6. Hubungi Kami"),
            _buildSectionText(
              "Jika ada pertanyaan mengenai kebijakan privasi ini, silakan hubungi kami melalui menu Help & Support."
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "Versi 1.0.0", 
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.grey),
      textAlign: TextAlign.justify,
    );
  }
}