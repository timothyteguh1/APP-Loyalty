import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../utils/layout_state.dart';
import '../../utils/ui_helpers.dart';
import 'login_page.dart';
import 'email_verification_page.dart';

class RegisterPage extends StatefulWidget {
  final String? initialEmail;
  const RegisterPage({super.key, this.initialEmail});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _authController = AuthController();
  final _pageController = PageController();

  int _currentStep = 0;
  final int _totalSteps = 3;
  bool _isProcessing = false;

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;

  final _namaTokoController = TextEditingController();
  final _picNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _accurateIdController = TextEditingController();
  final _domisiliController = TextEditingController();

  final _ktpNumberController = TextEditingController();

  late AnimationController _bgAnimController;
  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }

    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _headerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _headerAnimController.dispose();
    _pageController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _namaTokoController.dispose();
    _picNameController.dispose();
    _storeAddressController.dispose();
    _accurateIdController.dispose();
    _domisiliController.dispose();
    _ktpNumberController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.pop(context);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        final phone = _phoneController.text.trim();
        if (phone.isEmpty) return _showError('Nomor HP wajib diisi');
        if (phone.length < 10) return _showError('Nomor HP minimal 10 digit');
        if (phone.startsWith('+62'))
          return _showError('Gunakan awalan 08, bukan +62');
        if (!phone.startsWith('08'))
          return _showError('Nomor HP harus diawali dengan 08');

        final emailText = _emailController.text.trim();
        if (emailText.isNotEmpty && !emailText.contains('@')) {
          return _showError('Format email tidak valid');
        }

        if (_passwordController.text.isEmpty) {
          return _showError('Password wajib diisi');
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          return _showError('Konfirmasi password tidak cocok');
        }
        return true;
      case 1:
        if (_accurateIdController.text.trim().isEmpty)
          return _showError('Kode Pelanggan wajib diisi');
        if (_namaTokoController.text.trim().isEmpty)
          return _showError('Nama Toko wajib diisi');
        if (_picNameController.text.trim().isEmpty)
          return _showError('Nama Pemilik Toko wajib diisi');
        if (_storeAddressController.text.trim().isEmpty)
          return _showError('Alamat Toko wajib diisi');
        if (_domisiliController.text.trim().isEmpty)
          return _showError('Kota/Domisili wajib diisi');
        return true;
      case 2:
        if (_ktpNumberController.text.trim().isEmpty)
          return _showError('Nomor KTP wajib diisi');
        if (_ktpNumberController.text.trim().length < 16)
          return _showError('Nomor KTP harus 16 digit');
        return true;
      default:
        return true;
    }
  }

  Future<void> _handleRegister() async {
    if (!_validateCurrentStep()) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    showLoading(context);

    try {
      // PERUBAHAN: Normalisasi ke UPPERCASE agar c.0001 dan C.0001 dianggap sama
      final accurateId = _accurateIdController.text.trim().toUpperCase();

      final result = await _authController.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        fullName: _namaTokoController.text.trim(),
        picName: _picNameController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        domisili: _domisiliController.text.trim(),
        ktpNumber: _ktpNumberController.text.trim(),
        accurateCustomerId: accurateId,
      );

      if (!mounted) return;
      hideLoading(context);

      if (result['needsEmailVerification'] == true) {
        _goToEmailVerification(result['email'] as String);
      } else {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) hideLoading(context);
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _goToEmailVerification(String email) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => EmailVerificationPage(email: email),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.1), end: Offset.zero)
                  .animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, c) => Transform.scale(scale: v, child: c),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pendaftaran Berhasil!',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Akun Anda sedang menunggu verifikasi dari Admin. Silakan login untuk cek status.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (r) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ke Halaman Login',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _showError(String msg) {
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    return false;
  }

  String _stepTitle(int step) {
    switch (step) {
      case 0:
        return 'Informasi Akun';
      case 1:
        return 'Data Toko';
      case 2:
        return 'Verifikasi KTP';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFB71C1C),
          body: Stack(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8B0000),
                      Color(0xFFB71C1C),
                      Color(0xFFD32F2F),
                    ],
                  ),
                ),
              ),
              ...List.generate(4, (i) {
                return AnimatedBuilder(
                  animation: _bgAnimController,
                  builder: (context, child) {
                    final double progress = _bgAnimController.value;
                    final double x =
                        (i * 90.0 - 20) + (progress * 20 * (i.isEven ? 1 : -1));
                    final double y =
                        (i * 40.0 - 30) + (progress * 15 * (i.isOdd ? 1 : -1));
                    final double size = 60.0 + i * 40.0;
                    return Positioned(
                      left: x,
                      top: y,
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withOpacity(0.04 + (i * 0.008)),
                        ),
                      ),
                    );
                  },
                );
              }),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.28,
                child: CustomPaint(painter: _DotPatternPainter()),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 800 : double.infinity,
                    ),
                    child: Column(
                      children: [
                        FadeTransition(
                          opacity: _headerFade,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _prevStep,
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Daftar Akun',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _stepTitle(_currentStep),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () => LayoutState().toggleMode(),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDesktop
                                              ? Icons.phone_android_rounded
                                              : Icons.computer_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isDesktop ? "HP" : "Web",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_currentStep + 1}/$_totalSteps',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: List.generate(_totalSteps, (index) {
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                  margin: EdgeInsets.only(
                                    right: index < _totalSteps - 1 ? 8 : 0,
                                  ),
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: index <= _currentStep
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.25),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F8FB),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            child: PageView(
                              controller: _pageController,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _buildStep1Akun(),
                                _buildStep2Toko(),
                                _buildStep3Ktp(),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          color: const Color(0xFFF8F8FB),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            12,
                            24,
                            MediaQuery.of(context).padding.bottom + 16,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isProcessing
                                  ? null
                                  : (_currentStep == _totalSteps - 1
                                      ? _handleRegister
                                      : _nextStep),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB71C1C),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFB71C1C).withOpacity(0.5),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentStep == _totalSteps - 1
                                        ? 'Daftar Sekarang'
                                        : 'Lanjut',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _currentStep == _totalSteps - 1
                                        ? Icons.check_circle_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepIcon(IconData icon) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB71C1C).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFFB71C1C), size: 30),
      ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, 20 * (1 - v)), child: c),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildStep1Akun() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          _buildStepIcon(Icons.person_add_rounded),
          const SizedBox(height: 20),
          _buildFormCard(
            children: [
              _buildLabel('Nomor HP', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _phoneController,
                hint: 'Contoh: 08123456789',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 18),
              _buildLabel('Email (Opsional)', isRequired: false),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'Kosongkan jika tidak ada',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _buildLabel('Password', isRequired: true),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _passwordController,
                hint: 'Masukkan password',
                showPassword: _showPass,
                onToggle: () => setState(() => _showPass = !_showPass),
              ),
              const SizedBox(height: 18),
              _buildLabel('Konfirmasi Password', isRequired: true),
              const SizedBox(height: 8),
              _buildPasswordField(
                controller: _confirmPasswordController,
                hint: 'Ulangi password',
                showPassword: _showConfirm,
                onToggle: () =>
                    setState(() => _showConfirm = !_showConfirm),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoBox(
            text:
                'Nomor HP akan digunakan sebagai ID login utama Anda. Simpan password Anda baik-baik.',
            bgColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFE082),
            iconColor: const Color(0xFFF57F17),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Toko() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          _buildStepIcon(Icons.store_rounded),
          const SizedBox(height: 20),
          _buildFormCard(
            children: [
              _buildLabel('Kode Pelanggan', isRequired: true),
              const SizedBox(height: 8),
              // PERUBAHAN: hint diubah ke format No. Pelanggan (C.0001)
              // Input otomatis UPPERCASE saat ketik
              TextFormField(
                controller: _accurateIdController,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500),
                onChanged: (val) {
                  final upper = val.toUpperCase();
                  if (upper != val) {
                    _accurateIdController.value =
                        _accurateIdController.value.copyWith(
                      text: upper,
                      selection: TextSelection.collapsed(offset: upper.length),
                    );
                  }
                },
                decoration: _inputDecoration(
                  hint: 'Contoh: C.0001 (Dari Admin)',
                  prefixIcon: Icons.tag_rounded,
                ),
              ),
              const SizedBox(height: 18),

              _buildLabel('Nama Toko', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _namaTokoController,
                hint: 'Contoh: Toko Jaya Motor',
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 18),
              _buildLabel('Nama Pemilik Toko', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _picNameController,
                hint: 'Contoh: Budi Santoso',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 18),
              _buildLabel('Alamat Toko', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _storeAddressController,
                hint: 'Jl. Raya No. 123, Surabaya',
                icon: Icons.location_on_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 18),
              _buildLabel('Kota / Domisili', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _domisiliController,
                hint: 'Contoh: Surabaya',
                icon: Icons.map_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Ktp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          _buildStepIcon(Icons.badge_rounded),
          const SizedBox(height: 20),
          _buildFormCard(
            children: [
              _buildLabel('Nomor KTP', isRequired: true),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _ktpNumberController,
                hint: '16 digit nomor KTP',
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
                maxLength: 16,
              ),

              const SizedBox(height: 14),
              _buildInfoBox(
                text:
                    'Nomor KTP digunakan untuk proses verifikasi identitas saat Anda melakukan klaim hadiah.',
                bgColor: const Color(0xFFF0F9FF),
                borderColor: const Color(0xFFBAE6FD),
                iconColor: const Color(0xFF0284C7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(color: Color(0xFFD32F2F), fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: _inputDecoration(hint: hint, prefixIcon: icon),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: Colors.grey[400],
        ),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            size: 20,
            color: Colors.grey[400],
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5),
      ),
    );
  }

  Widget _buildInfoBox({
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: iconColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}