import 'package:flutter/material.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/layout_state.dart';
import 'register_page.dart';
import 'email_verification_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _authController = AuthController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isProcessing = false;
  bool _showPassword = false;
  String? _error;
  String? _unverifiedEmail;
  bool _idFocused = false;
  bool _pwFocused = false;

  late AnimationController _bgAnim;
  late AnimationController _formAnim;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _bgAnim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _formAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _formAnim, curve: const Interval(0.0, 0.35, curve: Curves.elasticOut)));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _formAnim, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(CurvedAnimation(parent: _formAnim, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _formAnim, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _btnScale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _formAnim, curve: const Interval(0.6, 1.0, curve: Curves.elasticOut)));
    _identifierFocus.addListener(() => setState(() => _idFocused = _identifierFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _pwFocused = _passwordFocus.hasFocus));
    _formAnim.forward();
  }

  @override
  void dispose() {
    _bgAnim.dispose(); _formAnim.dispose();
    _identifierController.dispose(); _passwordController.dispose();
    _identifierFocus.dispose(); _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_identifierController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() { _error = 'Email/No HP dan Password wajib diisi'; _unverifiedEmail = null; });
      return;
    }
    if (_isProcessing) return;
    setState(() { _isProcessing = true; _error = null; _unverifiedEmail = null; });

    try {
      await _authController.signIn(identifier: _identifierController.text.trim(), password: _passwordController.text.trim());
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg == 'EMAIL_NOT_CONFIRMED') {
        setState(() {
          _error = 'Email belum diverifikasi. Cek inbox email kamu dan klik link verifikasi.';
          _unverifiedEmail = _identifierController.text.trim();
        });
      } else {
        setState(() { _error = errorMsg; _unverifiedEmail = null; });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ============================================================
  // [BARU - POIN 2] Dialog Lupa Password
  // ============================================================
  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _identifierController.text.trim());
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Lupa Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan email akunmu. Kami akan mengirim link untuk reset password.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'email@contoh.com',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.email_outlined, size: 20, color: Colors.grey[400]),
                  filled: true, fillColor: const Color(0xFFF9FAFB),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSending ? null : () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Masukkan email yang valid'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }
                setD(() => isSending = true);
                try {
                  await _authController.sendPasswordResetEmail(email: email);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Link reset password dikirim ke $email', style: const TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ));
                  }
                } catch (e) {
                  setD(() => isSending = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Kirim Link Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Scaffold(
          body: Stack(
            children: [
              Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8B0000), Color(0xFFB71C1C), Color(0xFFD32F2F)]))),
              ...List.generate(6, (i) => AnimatedBuilder(
                animation: _bgAnim,
                builder: (_, __) {
                  final p = _bgAnim.value;
                  return Positioned(
                    left: (i * 70.0 + 10) + (p * 25 * (i.isEven ? 1 : -1)),
                    top: (i * 130.0 - 60) + (p * 35 * (i.isOdd ? 1 : -1)),
                    child: Container(width: 80.0 + i * 50, height: 80.0 + i * 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03 + i * 0.008))),
                  );
                },
              )),
              Positioned.fill(child: CustomPaint(painter: _DotPainter())),

              SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 50),
                              ScaleTransition(
                                scale: _logoScale,
                                child: Container(
                                  width: 88, height: 88,
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))]),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(26),
                                    child: Image.asset('assets/images/logo.png', fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Center(child: Text('U', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C))))),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FadeTransition(
                                opacity: _titleFade,
                                child: Column(children: [
                                  const Text('BKA Loyalty', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))),
                                    child: const Text('Program Loyalti Toko', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 36),
                              SlideTransition(
                                position: _cardSlide,
                                child: FadeTransition(
                                  opacity: _cardFade,
                                  child: Container(
                                    padding: const EdgeInsets.all(28),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 15))]),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Container(width: 4, height: 24, decoration: BoxDecoration(color: const Color(0xFFB71C1C), borderRadius: BorderRadius.circular(2))),
                                          const SizedBox(width: 10),
                                          const Text('Masuk ke Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                                        ]),
                                        const SizedBox(height: 24),
                                        _buildField(label: 'Email atau No HP', controller: _identifierController, focusNode: _identifierFocus, isFocused: _idFocused, hint: 'email@contoh.com atau 08xxx', icon: Icons.person_outline_rounded, action: TextInputAction.next, onSubmit: (_) => FocusScope.of(context).requestFocus(_passwordFocus)),
                                        const SizedBox(height: 20),
                                        _buildField(label: 'Password', controller: _passwordController, focusNode: _passwordFocus, isFocused: _pwFocused, hint: 'Masukkan password', icon: Icons.lock_outline_rounded, isPassword: true, action: TextInputAction.done, onSubmit: (_) => _handleLogin()),

                                        // ======= [BARU - POIN 2] Lupa Password =======
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: _showForgotPasswordDialog,
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Lupa Password?',
                                              style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),

                                        // Error display
                                        AnimatedSize(
                                          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
                                          child: _error != null ? Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Column(children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: _unverifiedEmail != null ? const Color(0xFFFFF8E1) : const Color(0xFFFEF2F2),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: _unverifiedEmail != null ? const Color(0xFFFFE082) : const Color(0xFFFFCDD2)),
                                                ),
                                                child: Row(children: [
                                                  Container(
                                                    width: 28, height: 28,
                                                    decoration: BoxDecoration(color: (_unverifiedEmail != null ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                                    child: Icon(_unverifiedEmail != null ? Icons.mark_email_unread_rounded : Icons.close_rounded, color: _unverifiedEmail != null ? const Color(0xFFF59E0B) : const Color(0xFFEF4444), size: 16),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(child: Text(_error!, style: TextStyle(color: _unverifiedEmail != null ? const Color(0xFF92400E) : const Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500))),
                                                ]),
                                              ),
                                              if (_unverifiedEmail != null) ...[
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                  width: double.infinity, height: 42,
                                                  child: OutlinedButton.icon(
                                                    onPressed: () {
                                                      Navigator.push(context, PageRouteBuilder(
                                                        pageBuilder: (_, __, ___) => EmailVerificationPage(email: _unverifiedEmail!),
                                                        transitionsBuilder: (_, anim, __, child) => SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
                                                        transitionDuration: const Duration(milliseconds: 350),
                                                      ));
                                                    },
                                                    icon: const Icon(Icons.email_rounded, size: 16),
                                                    label: const Text('Kirim Ulang Email Verifikasi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), side: const BorderSide(color: Color(0xFF1565C0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                  ),
                                                ),
                                              ],
                                            ]),
                                          ) : const SizedBox.shrink(),
                                        ),

                                        const SizedBox(height: 20),
                                        ScaleTransition(
                                          scale: _btnScale,
                                          child: SizedBox(
                                            width: double.infinity, height: 54,
                                            child: ElevatedButton(
                                              onPressed: _isProcessing ? null : _handleLogin,
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFB71C1C).withOpacity(0.6), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                              child: AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 200),
                                                child: _isProcessing
                                                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white.withOpacity(0.9), strokeWidth: 2.5)), const SizedBox(width: 12), const Text('Memverifikasi...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))])
                                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 20)]),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              FadeTransition(
                                opacity: _cardFade,
                                child: GestureDetector(
                                  onTap: () => Navigator.push(context, PageRouteBuilder(pageBuilder: (_, a, __) => const RegisterPage(), transitionsBuilder: (_, a, __, c) => SlideTransition(position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: c), transitionDuration: const Duration(milliseconds: 400))),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.15))),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text('Belum punya akun?', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                                      const SizedBox(width: 6),
                                      const Text('Daftar Sekarang', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                    ]),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              FadeTransition(opacity: _cardFade, child: Text('BKA Loyalty v2.0', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3)))),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16, right: 24,
                      child: InkWell(
                        onTap: () => LayoutState().toggleMode(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))),
                          child: Row(children: [
                            Icon(isDesktop ? Icons.phone_android_rounded : Icons.computer_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(isDesktop ? "Mode HP" : "Mode Web", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
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

  Widget _buildField({required String label, required TextEditingController controller, required FocusNode focusNode, required bool isFocused, required String hint, required IconData icon, bool isPassword = false, TextInputAction action = TextInputAction.done, Function(String)? onSubmit}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 200), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isFocused ? const Color(0xFFB71C1C) : const Color(0xFF374151)), child: Text(label)),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: isFocused ? [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))] : []),
        child: TextFormField(
          controller: controller, focusNode: focusNode, obscureText: isPassword && !_showPassword, textInputAction: action, onFieldSubmitted: onSubmit,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: hint, hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14),
            prefixIcon: Icon(icon, size: 20, color: isFocused ? const Color(0xFFB71C1C) : Colors.grey[400]),
            suffixIcon: isPassword ? IconButton(icon: Icon(_showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: Colors.grey[400]), onPressed: () => setState(() => _showPassword = !_showPassword)) : null,
            filled: true, fillColor: isFocused ? Colors.white : const Color(0xFFF8F9FC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
          ),
        ),
      ),
    ]);
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 40) { for (double y = 0; y < size.height; y += 40) { canvas.drawCircle(Offset(x, y), 1.5, paint); } }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}