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

  await dotenv.load(fileName: ".env");

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
      title: 'Bintang Kemenangan Abadi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD32F2F)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
      },
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))),
          );
        }

        final Session? session = snapshot.data?.session;

        // [BARU] Cek apakah ini event PASSWORD_RECOVERY
        final AuthChangeEvent? event = snapshot.data?.event;
        if (event == AuthChangeEvent.passwordRecovery) {
          // User baru klik link reset password → tampilkan form ganti password
          return const _ResetPasswordPage();
        }

        if (session != null) {
          return const _ApprovalChecker();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

// ============================================================
// [BARU] HALAMAN RESET PASSWORD
// Muncul otomatis saat user klik link reset dari email
// ============================================================
class _ResetPasswordPage extends StatefulWidget {
  const _ResetPasswordPage();

  @override
  State<_ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<_ResetPasswordPage> {
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _showPass = false;
  bool _showConfirm = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_newPassController.text.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter');
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      setState(() => _error = 'Konfirmasi password tidak cocok');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPassController.text.trim()),
      );

      if (!mounted) return;
      setState(() { _success = true; _isLoading = false; });

      // Tunggu 2 detik lalu redirect ke home
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on AuthException catch (e) {
      String msg = 'Gagal mengubah password';
      if (e.message.contains('same_password')) {
        msg = 'Password baru tidak boleh sama dengan yang lama';
      } else if (e.message.contains('weak_password')) {
        msg = 'Password terlalu lemah';
      }
      setState(() { _error = msg; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Terjadi kesalahan: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Icon
                      Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
                        ),
                        child: Icon(
                          _success ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                          size: 44,
                          color: _success ? const Color(0xFF10B981) : const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        _success ? 'Password Berhasil Diubah!' : 'Buat Password Baru',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _success ? 'Mengalihkan ke halaman utama...' : 'Masukkan password baru untuk akunmu',
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                      ),
                      const SizedBox(height: 36),

                      if (!_success)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Password Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _newPassController,
                                obscureText: !_showPass,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: 'Minimal 6 karakter',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey[400]),
                                  suffixIcon: IconButton(
                                    icon: Icon(_showPass ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: Colors.grey[400]),
                                    onPressed: () => setState(() => _showPass = !_showPass),
                                  ),
                                  filled: true, fillColor: const Color(0xFFF8F9FC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              const Text('Konfirmasi Password Baru', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _confirmPassController,
                                obscureText: !_showConfirm,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                onSubmitted: (_) => _handleResetPassword(),
                                decoration: InputDecoration(
                                  hintText: 'Ulangi password baru',
                                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey[400]),
                                  suffixIcon: IconButton(
                                    icon: Icon(_showConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: Colors.grey[400]),
                                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                                  ),
                                  filled: true, fillColor: const Color(0xFFF8F9FC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5)),
                                ),
                              ),

                              // Error
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFFCDD2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_rounded, color: Color(0xFFEF4444), size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity, height: 54,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleResetPassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFF1565C0).withOpacity(0.6),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: _isLoading
                                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white.withOpacity(0.9), strokeWidth: 2.5)),
                                          const SizedBox(width: 12),
                                          const Text('Menyimpan...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                        ])
                                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                          Icon(Icons.check_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text('Simpan Password Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                        ]),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// APPROVAL CHECKER
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
              Text('Memeriksa status akun...', style: TextStyle(color: Colors.grey, fontSize: 14)),
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