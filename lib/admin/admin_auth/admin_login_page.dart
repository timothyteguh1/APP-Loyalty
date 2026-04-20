import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';
import '../dashboard/admin_home_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _error;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late AnimationController _bgAnimController;
  late AnimationController _formAnimController;
  late Animation<double> _logoScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  late Animation<double> _buttonScale;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _formAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _formAnimController, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _formAnimController, curve: const Interval(0.2, 0.5, curve: Curves.easeOut)));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _formAnimController, curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic)));
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _formAnimController, curve: const Interval(0.3, 0.7, curve: Curves.easeOut)));
    _buttonScale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _formAnimController, curve: const Interval(0.6, 1.0, curve: Curves.elasticOut)));
    _emailFocus.addListener(() => setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() => setState(() => _passwordFocused = _passwordFocus.hasFocus));
    _formAnimController.forward();
  }

  @override
  void dispose() {
    _bgAnimController.dispose(); 
    _formAnimController.dispose();
    _emailController.dispose(); 
    _passwordController.dispose();
    _emailFocus.dispose(); 
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) { 
      setState(() => _error = 'Email dan password wajib diisi'); 
      return; 
    }
    
    setState(() { _isLoading = true; _error = null; });
    
    try {
      await _supabase.auth.signInWithPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      final adminEmailsData = await AdminSupabase.client.from('app_config').select('value').eq('key', 'admin_emails').maybeSingle();
      
      if (adminEmailsData == null) { 
        await _supabase.auth.signOut(); 
        if (!mounted) return; // FIX: Cek mounted sebelum setState
        setState(() => _error = 'Konfigurasi admin belum diatur'); 
        return; 
      }
      
      final String adminEmails = adminEmailsData['value'];
      final String currentEmail = _emailController.text.trim().toLowerCase();
      
      if (!adminEmails.toLowerCase().contains(currentEmail)) { 
        await _supabase.auth.signOut(); 
        if (!mounted) return; // FIX: Cek mounted sebelum setState
        setState(() => _error = 'Akses ditolak. Hanya admin yang bisa login.'); 
        return; 
      }
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => const AdminHomePage(), transitionsBuilder: (context, animation, secondaryAnimation, child) { return FadeTransition(opacity: animation, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)), child: child)); }, transitionDuration: const Duration(milliseconds: 500)), (route) => false);
    } on AuthException catch (e) {
      if (!mounted) return; // FIX: Cek mounted di dalam catch
      String msg = 'Login gagal';
      if (e.message.contains('Invalid login') || e.message.contains('invalid_credentials')) msg = 'Email atau password salah';
      setState(() => _error = msg);
    } catch (e) { 
      if (!mounted) return; // FIX: Cek mounted di dalam catch
      setState(() => _error = 'Terjadi kesalahan koneksi'); 
    } finally { 
      // Ini sudah aman karena kamu sudah menaruh if (mounted)
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8B0000), Color(0xFFB71C1C), Color(0xFFD32F2F)]))),
        ...List.generate(5, (i) => AnimatedBuilder(animation: _bgAnimController, builder: (context, child) {
          final double progress = _bgAnimController.value;
          return Positioned(left: (i * 80.0 + 20) + (progress * 20 * (i.isEven ? 1 : -1)), top: (i * 120.0 - 50) + (progress * 30 * (i.isOdd ? 1 : -1)), child: Container(width: 100.0 + i * 60.0, height: 100.0 + i * 60.0, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03 + (i * 0.01)))));
        })),
        Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    ScaleTransition(scale: _logoScale, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))]),
                      child: Stack(alignment: Alignment.center, children: [Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.1), width: 2))), const Text('U', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C), letterSpacing: -1))]))),
                    const SizedBox(height: 24),

                    FadeTransition(opacity: _titleFade, child: Column(children: [
                      const Text('Upsol Admin', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                      const SizedBox(height: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.1))), child: const Text('Loyalty Management Panel', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500, letterSpacing: 0.5))),
                    ])),
                    const SizedBox(height: 36),

                    SlideTransition(position: _cardSlide, child: FadeTransition(opacity: _cardFade, child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 15))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Container(width: 4, height: 24, decoration: BoxDecoration(color: const Color(0xFFB71C1C), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 10), const Text('Masuk ke Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)))]),
                        const SizedBox(height: 24),
                        _buildAnimatedField(label: 'Email', controller: _emailController, focusNode: _emailFocus, isFocused: _emailFocused, hint: 'admin@gmail.com', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus)),
                        const SizedBox(height: 20),
                        _buildAnimatedField(label: 'Password', controller: _passwordController, focusNode: _passwordFocus, isFocused: _passwordFocused, hint: 'Masukkan password', icon: Icons.lock_outline_rounded, isPassword: true, textInputAction: TextInputAction.done, onSubmitted: (_) => _handleLogin()),

                        AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeOut, child: _error != null
                          ? Padding(padding: const EdgeInsets.only(top: 16), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFCDD2))),
                            child: Row(children: [Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16)), const SizedBox(width: 10), Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500)))])))
                          : const SizedBox.shrink()),
                        const SizedBox(height: 28),

                        ScaleTransition(scale: _buttonScale, child: SizedBox(width: double.infinity, height: 54, child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFB71C1C).withOpacity(0.6), elevation: 0, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: _isLoading
                            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white.withOpacity(0.9), strokeWidth: 2.5)), const SizedBox(width: 12), const Text('Memverifikasi...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))])
                            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 20)])),
                        ))),
                      ]),
                    ))),

                    const SizedBox(height: 28),
                    FadeTransition(opacity: _cardFade, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('Upsol Loyalty v2.0', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w500)),
                      const SizedBox(width: 8),
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle)),
                    ])),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAnimatedField({required String label, required TextEditingController controller, required FocusNode focusNode, required bool isFocused, required String hint, required IconData icon, bool isPassword = false, TextInputType keyboardType = TextInputType.text, TextInputAction textInputAction = TextInputAction.done, Function(String)? onSubmitted}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 200), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isFocused ? const Color(0xFFB71C1C) : const Color(0xFF374151)), child: Text(label)),
      const SizedBox(height: 8),
      AnimatedContainer(duration: const Duration(milliseconds: 250), curve: Curves.easeOut, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: isFocused ? [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))] : []),
        child: TextFormField(controller: controller, focusNode: focusNode, obscureText: isPassword && !_showPassword, keyboardType: keyboardType, textInputAction: textInputAction, enableInteractiveSelection: true, onFieldSubmitted: onSubmitted, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey[350], fontSize: 14, fontWeight: FontWeight.w400),
            prefixIcon: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: isFocused ? const Color(0xFFB71C1C) : Colors.grey[400])),
            suffixIcon: isPassword ? IconButton(icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Icon(_showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, key: ValueKey(_showPassword), size: 20, color: Colors.grey[400])), onPressed: () => setState(() => _showPassword = !_showPassword)) : null,
            filled: true, fillColor: isFocused ? Colors.white : const Color(0xFFF8F9FC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5))))),
    ]);
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += 40) { for (double y = 0; y < size.height; y += 40) { canvas.drawCircle(Offset(x, y), 1.5, paint); } }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}