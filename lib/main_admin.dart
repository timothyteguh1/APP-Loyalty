import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// [PERBAIKAN]: Import path sudah ditambahkan awalan 'admin/' sesuai struktur folder Anda
import 'admin/dashboard/admin_home_page.dart';
import 'admin/kyc_approval/kyc_list_page.dart';
import 'admin/manage_conversion/manage_menu_page.dart';
import 'admin/reports/reports_page.dart';
import 'admin/admin_auth/admin_login_page.dart';

// =========================================================================
// 1. FUNGSI UTAMA (ENTRY POINT)
// =========================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load file .env sebelum inisialisasi Supabase
  await dotenv.load(fileName: ".env");

  // Inisialisasi Supabase khusus Admin
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_SERVICE_ROLE']!, 
  );

  runApp(const UpsolAdminApp());
}

class UpsolAdminApp extends StatelessWidget {
  const UpsolAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upsol Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C))),
          );
        }

        final Session? session = snapshot.data?.session;

        // Jika sudah login, masuk ke layout Web Desktop. Jika belum, ke Login.
        if (session != null) {
          return const AdminMainPage(); 
        } else {
          return const AdminLoginPage();
        }
      },
    );
  }
}

// =========================================================================
// 2. KERANGKA WEB RESPONSIF (SIDEBAR & DRAWER)
// =========================================================================
class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _selectedIndex = 0;
  final _supabase = Supabase.instance.client;

  // Daftar Nama Menu
  final List<String> _menuTitles = [
    'Dashboard',
    'Approval KYC',
    'Kelola Sistem',
    'Laporan Poin',
  ];

  // Daftar Ikon Menu
  final List<IconData> _menuIcons = [
    Icons.dashboard_rounded,
    Icons.verified_user_rounded,
    Icons.tune_rounded,
    Icons.analytics_rounded,
  ];

  // Fungsi Logout
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFB71C1C), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Text('Yakin ingin keluar dari panel admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      // AuthGate di atas akan otomatis melempar user ke halaman Login saat sign out
    }
  }

  @override
  Widget build(BuildContext context) {
    // Daftar Halaman dari file yang sudah di-import di atas
    final List<Widget> pages = [
      const AdminHomePage(),
      const KycListPage(),
      const ManageMenuPage(),
      const ReportsPage(),
    ];

    // Kunci Responsif Flutter
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      
      appBar: isDesktop 
          ? null 
          : AppBar(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
              title: Text(_menuTitles[_selectedIndex], style: const TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _handleLogout),
              ],
            ),
            
      drawer: isDesktop ? null : _buildDrawer(),

      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(
            child: ClipRect(
              child: IndexedStack(
                index: _selectedIndex,
                children: pages,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SIDEBAR (DESKTOP) ---
  Widget _buildSidebar() {
    final user = _supabase.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Admin';

    return Container(
      width: 250,
      color: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            color: const Color(0xFFB71C1C),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('U', style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w900, fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upsol Admin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text(adminName, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: ListView.builder(
              itemCount: _menuTitles.length,
              itemBuilder: (context, index) {
                final bool isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(_menuIcons[index], color: isSelected ? Colors.white : Colors.white54, size: 20),
                    title: Text(
                      _menuTitles[index], 
                      style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 14),
                    ),
                    selected: isSelected,
                    selectedTileColor: Colors.white.withOpacity(0.1),
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              },
            ),
          ),
          
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent),
            title: const Text("Keluar Panel", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
            onTap: _handleLogout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- DRAWER (MOBILE) ---
  Widget _buildDrawer() {
    final user = _supabase.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Admin';

    return Drawer(
      backgroundColor: const Color(0xFF1A1A2E),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFB71C1C)),
            accountName: const Text("Upsol Admin Panel", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text(adminName, style: const TextStyle(color: Colors.white70)),
            currentAccountPicture: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('U', style: TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.w900, fontSize: 24))),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _menuTitles.length,
              itemBuilder: (context, index) {
                final bool isSelected = _selectedIndex == index;
                return ListTile(
                  leading: Icon(_menuIcons[index], color: isSelected ? Colors.white : Colors.white54),
                  title: Text(_menuTitles[index], style: TextStyle(color: isSelected ? Colors.white : Colors.white54)),
                  selected: isSelected,
                  selectedTileColor: Colors.white.withOpacity(0.1),
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}