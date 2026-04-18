import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/layout_state.dart';
import 'login_page.dart';

class EmailVerificationPage extends StatefulWidget {
  final String email;
  const EmailVerificationPage({super.key, required this.email});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage>
    with TickerProviderStateMixin {
  final _auth = AuthController();
  bool _isResending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  late AnimationController _entryAnim;
  late Animation<double> _iconScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _entryAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)));
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _entryAnim, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)));
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _entryAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    if (_cooldownSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await _auth.resendVerificationEmail(email: widget.email);
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('Email verifikasi dikirim ulang ke ${widget.email}', style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) { timer.cancel(); _cooldownSeconds = 0; }
      });
    });
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Scaffold(
          body: Stack(children: [
            Container(height: 300, decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]))),

            SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
                    child: Column(children: [
                      const SizedBox(height: 60),

                      // Icon
                      ScaleTransition(
                        scale: _iconScale,
                        child: AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, child) => Container(
                            width: 110 + (_pulseAnim.value * 8), height: 110 + (_pulseAnim.value * 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 30 + (_pulseAnim.value * 10), offset: const Offset(0, 10))]),
                            child: const Icon(Icons.mark_email_read_rounded, size: 52, color: Color(0xFF1565C0)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      FadeTransition(opacity: _contentFade, child: SlideTransition(position: _contentSlide, child: Column(children: [
                        const Text('Cek Email Kamu!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 8),
                        Text('Kami sudah mengirim link verifikasi', style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85))),
                      ]))),
                      const SizedBox(height: 32),

                      // Card
                      FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))]),
                            child: Column(children: [
                              // Email box
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBAE6FD))),
                                child: Row(children: [
                                  Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.email_rounded, color: Color(0xFF1565C0), size: 18)),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Text('Email dikirim ke:', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                                    const SizedBox(height: 2),
                                    Text(widget.email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ])),
                                ]),
                              ),
                              const SizedBox(height: 24),

                              const Text('Langkah selanjutnya:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                              const SizedBox(height: 16),

                              _step('1', 'Buka inbox email kamu (cek juga folder Spam)', const Color(0xFF3B82F6)),
                              _connector(),
                              _step('2', 'Klik tombol "Verifikasi Email Saya" di email', const Color(0xFFF59E0B)),
                              _connector(),
                              _step('3', 'Kembali ke sini dan Login dengan akunmu', const Color(0xFF10B981)),
                              const SizedBox(height: 28),

                              // Resend
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: (_cooldownSeconds > 0 || _isResending) ? null : _resendEmail,
                                  icon: _isResending
                                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.grey[400], strokeWidth: 2))
                                      : Icon(Icons.refresh_rounded, size: 18, color: _cooldownSeconds > 0 ? Colors.grey[400] : const Color(0xFF1565C0)),
                                  label: Text(
                                    _cooldownSeconds > 0 ? 'Kirim ulang (${_cooldownSeconds}s)' : 'Kirim Ulang Email',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: _cooldownSeconds > 0 ? Colors.grey[400] : const Color(0xFF1565C0)),
                                  ),
                                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), side: BorderSide(color: _cooldownSeconds > 0 ? Colors.grey[300]! : const Color(0xFF1565C0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Login
                              SizedBox(
                                width: double.infinity, height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _goToLogin,
                                  icon: const Icon(Icons.login_rounded, size: 20),
                                  label: const Text('Ke Halaman Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(opacity: _contentFade, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text('Tidak menerima email? Periksa folder Spam atau Junk Mail kamu.', style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.5), textAlign: TextAlign.center))),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _step(String number, String text, Color color) {
    return Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Center(child: Text(number, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)))),
      const SizedBox(width: 14),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF374151), height: 1.4))),
    ]);
  }

  Widget _connector() {
    return Padding(padding: const EdgeInsets.only(left: 18), child: Container(width: 2, height: 20, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(1))));
  }
}