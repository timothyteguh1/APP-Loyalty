import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../../controllers/auth_controller.dart';
import '../../utils/layout_state.dart'; // <-- IMPORT GLOBAL STATE
import 'edit_profile_page.dart';
import 'help_center_page.dart'; 
import 'privacy_policy_page.dart';
import 'settings_page.dart';
import '../auth/login_page.dart'; 

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  
  void _refreshData() {
    setState(() {}); 
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
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()), 
        (route) => false, 
      );
    }
  }

  Future<void> _contactSupport() async {
    try {
      final data = await Supabase.instance.client
          .from('app_config')
          .select('value')
          .eq('key', 'wa_admin') 
          .single();

      final String phone = data['value']; 
      final user = Supabase.instance.client.auth.currentUser;
      final String emailUser = user?.email ?? 'Tamu';
      final String message = "Halo Admin Upsol, saya butuh bantuan terkait akun $emailUser.";
      final Uri url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Gagal membuka WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).push(
           MaterialPageRoute(builder: (_) => const HelpCenterPage())
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final String name = user?.userMetadata?['full_name'] ?? 'User Upsol';
    final String email = user?.email ?? '-';
    final String? avatarUrl = user?.userMetadata?['avatar_url'];
    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    // Mendengarkan perubahan mode (Web vs Mobile)
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Container(
          color: const Color(0xFFF5F5F5),
          // [PERBAIKAN] Stack digunakan pada level tertinggi agar warna merah menempel penuh ke atas
          child: Stack(
            children: [
              // HEADER MERAH (Dibuat lebih tinggi agar menutupi area kosong atas)
              Positioned(
                top: 0, left: 0, right: 0, 
                height: 280, // Tambah tinggi sedikit untuk menutupi status bar
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

              // KONTEN UTAMA SCROLLABLE
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  // [RESPONSIVE] Jika desktop, beri batasan lebar 800px di tengah
                  child: isDesktop 
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: _buildAccountContent(name, email, hasAvatar, avatarUrl),
                          ),
                        )
                      : _buildAccountContent(name, email, hasAvatar, avatarUrl),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // Fungsi pembangun konten utama agar kode tidak berulang
  Widget _buildAccountContent(String name, String email, bool hasAvatar, String? avatarUrl) {
    return Column(
      children: [
        // Jarak dari atas. Jika merahnya dirasa kurang ke bawah, ubah angka 90 ini.
        const SizedBox(height: 90), 
        
        // KARTU PROFIL
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
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: hasAvatar
                        ? NetworkImage(avatarUrl!)
                        : const NetworkImage('https://i.pravatar.cc/150?img=12'),
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
                        final bool? updated = await Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => const EditProfilePage())
                        );
                        if (updated == true) _refreshData();
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
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.grey), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
                        foregroundColor: Colors.black
                      ),
                      child: const Text("Sign Out"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 30),
        
        // MENU LIST
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _buildMenuItem(Icons.settings_outlined, "Settings", () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage())
                  );
              }),
              const Divider(height: 1),
              
              _buildMenuItem(Icons.help_outline, "Help & Support", () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const HelpCenterPage())
                  );
              }),
              
              const Divider(height: 1),
              _buildMenuItem(Icons.privacy_tip_outlined, "Privacy Policy", () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())
                  );
              }),
            ],
          ),
        ),
        const SizedBox(height: 100),
      ],
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