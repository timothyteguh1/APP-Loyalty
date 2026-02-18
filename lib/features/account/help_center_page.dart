import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  final _supabase = Supabase.instance.client;
  
  // Variabel penampung data
  String? _waNumber;
  String? _email;
  String? _website;
  String? _instagram;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  // Ambil semua data kontak sekaligus
  Future<void> _fetchContacts() async {
    try {
      final response = await _supabase.from('app_config').select();
      
      // Mapping data dari database ke variabel
      if (mounted) {
        setState(() {
          for (var item in response) {
            if (item['key'] == 'wa_admin') _waNumber = item['value'];
            if (item['key'] == 'email_support') _email = item['value'];
            if (item['key'] == 'website_url') _website = item['value'];
            if (item['key'] == 'instagram_url') _instagram = item['value'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi Buka Link Universal (WA, Email, Web)
  Future<void> _launchUrl(String type, String value) async {
    Uri uri;
    if (type == 'wa') {
       final user = _supabase.auth.currentUser;
       final String emailUser = user?.email ?? 'Tamu';
       final message = "Halo Admin Upsol, saya butuh bantuan ($emailUser).";
       uri = Uri.parse("https://wa.me/$value?text=${Uri.encodeComponent(message)}");
    } else if (type == 'email') {
       uri = Uri.parse("mailto:$value?subject=Bantuan Aplikasi Upsol");
    } else {
       uri = Uri.parse(value); // Untuk Website / Instagram
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal membuka link")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Pusat Bantuan", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Hubungi Kami", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 16),

                // 1. WHATSAPP (Highlight Merah karena Utama)
                if (_waNumber != null)
                  _buildContactCard(
                    icon: Icons.chat, // Ikon Chat/WA
                    title: "WhatsApp",
                    subtitle: _waNumber!,
                    color: const Color(0xFFD32F2F), // Merah Upsol
                    textColor: Colors.white,
                    onTap: () => _launchUrl('wa', _waNumber!),
                  ),

                const SizedBox(height: 12),

                // 2. EMAIL
                if (_email != null)
                  _buildContactCard(
                    icon: Icons.email_outlined,
                    title: "Email Support",
                    subtitle: _email!,
                    color: Colors.white,
                    textColor: Colors.black,
                    onTap: () => _launchUrl('email', _email!),
                  ),

                const SizedBox(height: 12),

                // 3. WEBSITE
                if (_website != null)
                  _buildContactCard(
                    icon: Icons.language,
                    title: "Website",
                    subtitle: "Kunjungi website resmi kami",
                    color: Colors.white,
                    textColor: Colors.black,
                    onTap: () => _launchUrl('web', _website!),
                  ),

                 const SizedBox(height:12),

                 // 4. INSTAGRAM
                 if (_instagram != null)
                  _buildContactCard(
                    icon: Icons.camera_alt_outlined,
                    title: "Instagram",
                    subtitle: "Follow update terbaru",
                    color: Colors.white,
                    textColor: Colors.black,
                    onTap: () => _launchUrl('web', _instagram!),
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: textColor == Colors.white ? Colors.white.withOpacity(0.2) : Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: textColor == Colors.white ? Colors.white : const Color(0xFFD32F2F)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.8))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: textColor.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}