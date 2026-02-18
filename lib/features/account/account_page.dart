import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import ini wajib
import '../../controllers/auth_controller.dart';
import 'edit_profile_page.dart'; 

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // Fungsi Refresh Tampilan
  void _refreshData() {
    setState(() {}); // "Bangunkan" halaman agar membaca data ulang
  }

  Future<void> _confirmLogout() async {
    final authController = AuthController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Keluar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await authController.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. AMBIL DATA USER TERBARU DARI SUPABASE
    final user = Supabase.instance.client.auth.currentUser;
    
    // Ambil Nama & Email
    final String name = user?.userMetadata?['full_name'] ?? 'User Upsol';
    final String email = user?.email ?? '-';
    
    // 2. AMBIL FOTO (LOGIKA BARU)
    // Cek apakah ada 'avatar_url' di metadata? Kalau tidak, pakai gambar default.
    final String? avatarUrl = user?.userMetadata?['avatar_url'];
    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Container(
      color: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Stack(
          children: [
            // Header Merah
            Positioned(
              top: 0, left: 0, right: 0, height: 220,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),
            ),

            // Konten Utama
            Column(
              children: [
                const SizedBox(height: 90), 
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // [FOTO PROFIL YANG SUDAH DIPERBAIKI]
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: hasAvatar
                                ? NetworkImage(avatarUrl!) // Pakai foto upload-an user
                                : const NetworkImage('https://i.pravatar.cc/150?img=12'), // Default
                            // Anti-Crash kalau URL error
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 13), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                // Tunggu hasil edit
                                final bool? updated = await Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(builder: (_) => const EditProfilePage())
                                );

                                // Kalau ada perubahan (updated == true), refresh halaman ini
                                if (updated == true) {
                                  _refreshData();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD32F2F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text("Edit Profile"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _confirmLogout,
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), foregroundColor: Colors.black),
                              child: const Text("Sign Out"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                // Menu List
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _buildMenuItem(Icons.settings_outlined, "Settings", () {}),
                      const Divider(height: 1),
                      _buildMenuItem(Icons.help_outline, "Help & Support", () {}),
                      const Divider(height: 1),
                      _buildMenuItem(Icons.privacy_tip_outlined, "Privacy Policy", () {}),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFFD32F2F), size: 20),
      ),
      title: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}