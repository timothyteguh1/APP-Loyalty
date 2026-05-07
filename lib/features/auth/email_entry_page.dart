import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'otp_page.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class EmailEntryPage extends StatefulWidget {
  const EmailEntryPage({super.key});

  @override
  State<EmailEntryPage> createState() => _EmailEntryPageState();
}

class _EmailEntryPageState extends State<EmailEntryPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _emailFocus = FocusNode();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _emailFocused = false;

  late AnimationController _bgAnimController;
  late AnimationController _formAnimController;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _bgAnimController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat(reverse: true);
    _formAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _formAnimController,
        curve: const Interval(0.0, 0.35, curve: Curves.elasticOut)));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _formAnimController,
        curve: const Interval(0.15, 0.45, curve: Curves.easeOut)));
    _cardSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _formAnimController,
                curve: const Interval(0.3, 0.7,
                    curve: Curves.easeOutCubic)));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _formAnimController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _btnScale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(
        parent: _formAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.elasticOut)));

    _emailFocus.addListener(
        () => setState(() => _emailFocused = _emailFocus.hasFocus));
    _formAnimController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _formAnimController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _checkEmail() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showSnack('Masukkan alamat email yang valid!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, approval_status, is_profile_completed')
          .eq('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        _showSnack('Akun belum terdaftar. Silakan buat akun baru.',
            Colors.blueAccent);
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const RegisterPage()));
      } else {
        final isCompleted = response['is_profile_completed'] == true;
        final status = response['approval_status'];

        if (status == 'PENDING' && !isCompleted) {
          _showSnack(
              'Akun dari Accurate ditemukan! Mengirim kode OTP ke email Anda...',
              const Color(0xFF10B981));
          await _supabase.auth.signInWithOtp(email: email);
          if (mounted) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => OtpPage(email: email)));
          }
        } else {
          _showSnack('Akun aktif ditemukan. Silakan login.', Colors.blueAccent);
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const LoginPage()));
        }
      }
    } catch (e) {
      _showSnack('Terjadi kesalahan: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 14)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Background gradient — biru gelap sesuai tema
        Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
              Color(0xFF0A0E1A),
              Color(0xFF0D1B2A),
              Color(0xFF1A2744),
            ]))),

        // Animated circles
        ...List.generate(
            6,
            (i) => AnimatedBuilder(
                  animation: _bgAnimController,
                  builder: (_, __) {
                    final p = _bgAnimController.value;
                    return Positioned(
                      left: (i * 70.0 + 10) +
                          (p * 25 * (i.isEven ? 1 : -1)),
                      top: (i * 130.0 - 60) +
                          (p * 35 * (i.isOdd ? 1 : -1)),
                      child: Container(
                          width: 80.0 + i * 50,
                          height: 80.0 + i * 50,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withOpacity(0.03 + i * 0.008))),
                    );
                  },
                )),

        // Dot pattern
        Positioned.fill(child: CustomPaint(painter: _DotPainter())),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 50),

                    // Logo
                    ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10))
                            ]),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                                child: Text('U',
                                    style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF1A2744)))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    FadeTransition(
                      opacity: _titleFade,
                      child: Column(children: [
                        const Text('BKA Loyalty',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1))),
                          child: const Text('Program Loyalti Toko',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 36),

                    // Card
                    SlideTransition(
                      position: _cardSlide,
                      child: FadeTransition(
                        opacity: _cardFade,
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 40,
                                    offset: const Offset(0, 15))
                              ]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF1A2744),
                                        borderRadius:
                                            BorderRadius.circular(2))),
                                const SizedBox(width: 10),
                                const Text('Selamat Datang',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1A1A2E))),
                              ]),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 14),
                                child: Text(
                                    'Masukkan email Anda untuk melanjutkan',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[500])),
                              ),
                              const SizedBox(height: 24),

                              // Email field
                              _buildEmailField(),

                              const SizedBox(height: 28),

                              // Button
                              ScaleTransition(
                                scale: _btnScale,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _checkEmail,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1A2744),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            const Color(0xFF1A2744)
                                                .withOpacity(0.6),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    16))),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      child: _isLoading
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                              children: [
                                                  SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(
                                                          color: Colors
                                                              .white
                                                              .withOpacity(
                                                                  0.9),
                                                          strokeWidth:
                                                              2.5)),
                                                  const SizedBox(
                                                      width: 12),
                                                  const Text(
                                                      'Memeriksa...',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600)),
                                                ])
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .center,
                                              children: [
                                                  Text('Lanjutkan',
                                                      style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w600)),
                                                  SizedBox(width: 8),
                                                  Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 20),
                                                ]),
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

                    // Daftar link
                    FadeTransition(
                      opacity: _cardFade,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, a, __) =>
                                  const RegisterPage(),
                              transitionsBuilder: (_, a, __, c) =>
                                  SlideTransition(
                                      position: Tween<Offset>(
                                              begin: const Offset(1, 0),
                                              end: Offset.zero)
                                          .animate(CurvedAnimation(
                                              parent: a,
                                              curve:
                                                  Curves.easeOutCubic)),
                                      child: c),
                              transitionDuration:
                                  const Duration(milliseconds: 400),
                            )),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 24),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      Colors.white.withOpacity(0.15))),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Belum punya akun?',
                                    style: TextStyle(
                                        color:
                                            Colors.white.withOpacity(0.7),
                                        fontSize: 13)),
                                const SizedBox(width: 6),
                                const Text('Daftar Sekarang',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 16),
                              ]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    FadeTransition(
                        opacity: _cardFade,
                        child: Text('BKA Loyalty v2.0',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.3)))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmailField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _emailFocused
                  ? const Color(0xFF1A2744)
                  : const Color(0xFF374151)),
          child: const Text('Alamat Email')),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _emailFocused
                ? [
                    BoxShadow(
                        color: const Color(0xFF1A2744).withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : []),
        child: TextFormField(
          controller: _emailController,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _checkEmail(),
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(
            hintText: 'contoh@email.com',
            hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14),
            prefixIcon: Icon(Icons.email_outlined,
                size: 20,
                color: _emailFocused
                    ? const Color(0xFF1A2744)
                    : Colors.grey[400]),
            filled: true,
            fillColor:
                _emailFocused ? Colors.white : const Color(0xFFF8F9FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: Color(0xFF1A2744), width: 1.5)),
          ),
        ),
      ),
    ]);
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 40) {
      for (double y = 0; y < size.height; y += 40) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}