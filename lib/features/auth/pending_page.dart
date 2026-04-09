import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/layout_state.dart'; // <-- IMPORT GLOBAL STATE
import 'login_page.dart';

class PendingPage extends StatefulWidget {
  const PendingPage({super.key});

  @override
  State<PendingPage> createState() => _PendingPageState();
}

class _PendingPageState extends State<PendingPage> with TickerProviderStateMixin {
  final _auth = AuthController();
  bool _isChecking = false;

  late AnimationController _pulseAnim;
  late AnimationController _entryAnim;
  late Animation<double> _iconScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late AnimationController _rotateAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _rotateAnim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)));
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)));
  }

  @override
  void dispose() {
    _pulseAnim.dispose(); _rotateAnim.dispose(); _entryAnim.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    final status = await _auth.checkApprovalStatus();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (status == 'APPROVED' || status == 'REJECTED') {
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 18), SizedBox(width: 10),
          Text('Masih menunggu verifikasi admin', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFFF59E0B), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] ?? 'User';

    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Scaffold(
          body: Stack(
            children: [
              Container(height: 300, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF59E0B), Color(0xFFFF8F00)]))),
              Container(height: 300, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05))),

              SafeArea(
                child: Stack(
                  children: [
                    // --- KONTEN UTAMA ---
                    Positioned.fill(
                      child: SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
                            child: Column(
                              children: [
                                const SizedBox(height: 60), 
                                ScaleTransition(
                                  scale: _iconScale,
                                  child: AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (_, child) => Container(
                                      width: 110 + (_pulseAnim.value * 8), height: 110 + (_pulseAnim.value * 8),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 30 + (_pulseAnim.value * 10), offset: const Offset(0, 10))]),
                                      child: AnimatedBuilder(
                                        animation: _rotateAnim,
                                        builder: (_, __) => Transform.rotate(angle: _rotateAnim.value * 6.28 * 0.1, child: const Icon(Icons.hourglass_top_rounded, size: 52, color: Color(0xFFF59E0B))),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                FadeTransition(
                                  opacity: _contentFade,
                                  child: SlideTransition(
                                    position: _contentSlide,
                                    child: Column(children: [
                                      const Text('Menunggu Verifikasi', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                                      const SizedBox(height: 8),
                                      Text('Halo, $name', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85))),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                FadeTransition(
                                  opacity: _contentFade,
                                  child: SlideTransition(
                                    position: _contentSlide,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))]),
                                      child: Column(children: [
                                        const Text('Akun Anda sedang dalam proses verifikasi oleh Admin. Proses ini biasanya memakan waktu 1x24 jam.', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.6), textAlign: TextAlign.center),
                                        const SizedBox(height: 28),
                                        _statusStep(Icons.check_circle_rounded, 'Data pendaftaran terkirim', const Color(0xFF10B981), true, 0), _connector(),
                                        _statusStep(Icons.pending_rounded, 'Verifikasi admin diproses', const Color(0xFFF59E0B), true, 1), _connector(),
                                        _statusStep(Icons.lock_open_rounded, 'Akses penuh setelah disetujui', const Color(0xFFD1D5DB), false, 2),
                                        const SizedBox(height: 28),
                                        SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
                                          onPressed: _isChecking ? null : _checkStatus,
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFF59E0B).withOpacity(0.5), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                          child: _isChecking ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white.withOpacity(0.9), strokeWidth: 2.5)), const SizedBox(width: 12), const Text('Mengecek...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))]) : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.refresh_rounded, size: 20), SizedBox(width: 8), Text('Cek Status Verifikasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))]),
                                        )),
                                        const SizedBox(height: 12),
                                        SizedBox(width: double.infinity, height: 48, child: OutlinedButton(
                                          onPressed: _logout,
                                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6B7280), side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                          child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w600)),
                                        )),
                                      ]),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- TOMBOL SWITCH MODE ---
                    Positioned(
                      top: 16, right: 24,
                      child: InkWell(
                        onTap: () => LayoutState().toggleMode(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                          child: Row(
                            children: [
                              Icon(isDesktop ? Icons.phone_android_rounded : Icons.computer_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(isDesktop ? "Mode HP" : "Mode Web", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _statusStep(IconData icon, String text, Color color, bool active, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 600 + delay * 200), curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(20 * (1 - v), 0), child: c)),
      child: Row(children: [
        AnimatedBuilder(animation: _pulseAnim, builder: (_, __) => Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(active ? (0.1 + _pulseAnim.value * 0.05) : 0.08), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22))),
        const SizedBox(width: 14), Expanded(child: Text(text, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? const Color(0xFF1A1A2E) : const Color(0xFF9CA3AF)))),
      ]),
    );
  }

  Widget _connector() { return Padding(padding: const EdgeInsets.only(left: 20), child: Container(width: 2, height: 24, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(1)))); }
}