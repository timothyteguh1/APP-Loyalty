import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'controllers/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/pending_page.dart';
import 'features/auth/rejected_page.dart';
import 'features/home/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load file .env
  await dotenv.load(fileName: ".env");

  // Inisialisasi Supabase menggunakan variabel dari .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upsol Loyalty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD32F2F)),
        useMaterial3: true,
      ),
      // Route '/' untuk AuthGate (dipakai saat pushNamedAndRemoveUntil)
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
      },
    );
  }
}

// ============================================================
// AUTH GATE - Satpam Utama Aplikasi
// ============================================================
// Flow:
// 1. Belum login → LoginPage
// 2. Sudah login → Cek approval_status di profiles
//    - PENDING  → PendingPage
//    - REJECTED → RejectedPage (dengan alasan)
//    - APPROVED → HomePage
// ============================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Loading saat mengecek koneksi awal
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
            ),
          );
        }

        final Session? session = snapshot.data?.session;

        if (session != null) {
          // Sudah login → cek approval status
          return const _ApprovalChecker();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// ============================================================
// APPROVAL CHECKER - Cek status setelah login
// ============================================================
class _ApprovalChecker extends StatefulWidget {
  const _ApprovalChecker();

  @override
  State<_ApprovalChecker> createState() => _ApprovalCheckerState();
}

class _ApprovalCheckerState extends State<_ApprovalChecker> {
  final _authController = AuthController();
  bool _isLoading = true;
  String _status = 'PENDING';
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final profile = await _authController.getProfile();
      final status = profile?['approval_status'] ?? 'PENDING';

      if (mounted) {
        setState(() {
          _status = status;
          _profileData = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'PENDING';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFD32F2F)),
              SizedBox(height: 16),
              Text('Memeriksa status akun...',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    switch (_status) {
      case 'APPROVED':
        return const HomePage();
      case 'REJECTED':
        return RejectedPage(profileData: _profileData ?? {});
      case 'PENDING':
      default:
        return const PendingPage();
    }
  }
}