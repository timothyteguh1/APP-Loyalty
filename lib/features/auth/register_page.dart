import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/ui_helpers.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final _authController = AuthController();
  final _pageController = PageController();

  // Step tracking
  int _currentStep = 0;
  final int _totalSteps = 3;
  bool _isProcessing = false;

  // === STEP 1: Akun ===
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;

  // === STEP 2: Data Toko ===
  final _namaTokoController = TextEditingController();
  final _picNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  String? _selectedDomisili;
  final List<String> _listDomisili = [
    'Surabaya', 'Sidoarjo', 'Gresik', 'Malang', 'Jakarta', 'Bandung', 'Semarang', 'Lainnya',
  ];

  // === STEP 3: KTP ===
  final _ktpNumberController = TextEditingController();
  XFile? _ktpFile;
  Uint8List? _ktpBytes;

  // === ANIMATIONS ===
  late AnimationController _bgAnimController;
  late AnimationController _headerAnimController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();

    // Background floating animation
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    // Header entrance animation
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
    _ktpNumberController.dispose();
    super.dispose();
  }

  // ============================================================
  // NAVIGASI STEP
  // ============================================================
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
        if (_phoneController.text.trim().isEmpty) return _showError('Nomor HP wajib diisi');
        if (_phoneController.text.trim().length < 10) return _showError('Nomor HP minimal 10 digit');
        if (_emailController.text.trim().isEmpty) return _showError('Email wajib diisi untuk verifikasi akun');
        if (!_emailController.text.trim().contains('@')) return _showError('Format email tidak valid');
        if (_passwordController.text.length < 6) return _showError('Password minimal 6 karakter');
        if (_passwordController.text != _confirmPasswordController.text) return _showError('Konfirmasi password tidak cocok');
        return true;
      case 1:
        if (_namaTokoController.text.trim().isEmpty) return _showError('Nama Toko wajib diisi');
        if (_picNameController.text.trim().isEmpty) return _showError('Nama PIC wajib diisi');
        if (_storeAddressController.text.trim().isEmpty) return _showError('Alamat Toko wajib diisi');
        if (_selectedDomisili == null) return _showError('Domisili wajib dipilih');
        return true;
      case 2:
        if (_ktpNumberController.text.trim().isEmpty) return _showError('Nomor KTP wajib diisi');
        if (_ktpNumberController.text.trim().length < 16) return _showError('Nomor KTP harus 16 digit');
        if (_ktpBytes == null) return _showError('Foto KTP wajib diunggah');
        return true;
      default:
        return true;
    }
  }

  // ============================================================
  // PICK FOTO KTP
  // ============================================================
  Future<void> _pickKtpImage() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _ktpFile = picked; _ktpBytes = bytes; });
      }
    } catch (e) {
      if (mounted) _showError('Gagal memilih gambar: $e');
    }
  }

  Future<void> _takeKtpPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _ktpFile = picked; _ktpBytes = bytes; });
      }
    } catch (e) {
      if (mounted) _showError('Kamera tidak tersedia di perangkat ini. Gunakan Galeri.');
    }
  }

  // ============================================================
  // SUBMIT REGISTRASI
  // ============================================================
  Future<void> _handleRegister() async {
    if (!_validateCurrentStep()) return;
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    showLoading(context);

    try {
      await _authController.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
        fullName: _namaTokoController.text.trim(),
        picName: _picNameController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        domisili: _selectedDomisili!,
        ktpNumber: _ktpNumberController.text.trim(),
        ktpImageBytes: _ktpBytes,
        ktpFileName: _ktpFile?.name,
      );

      if (!mounted) return;
      hideLoading(context);
      _showSuccessDialog();
    } catch (e) {
      if (mounted) hideLoading(context);
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
              // Animated checkmark
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, c) => Transform.scale(scale: v, child: c),
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 44),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Pendaftaran Berhasil!',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Akun Anda sedang menunggu verifikasi dari Admin. Silakan login untuk cek status.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (r) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ke Halaman Login', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
        content: Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.warning_rounded, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
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
      case 0: return 'Informasi Akun';
      case 1: return 'Data Toko';
      case 2: return 'Verifikasi KTP';
      default: return '';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ======= ANIMATED GRADIENT HEADER =======
          Container(
            height: MediaQuery.of(context).size.height * 0.28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8B0000), Color(0xFFB71C1C), Color(0xFFD32F2F)],
              ),
            ),
          ),

          // Floating circles on header
          ...List.generate(4, (i) {
            return AnimatedBuilder(
              animation: _bgAnimController,
              builder: (context, child) {
                final double progress = _bgAnimController.value;
                final double x = (i * 90.0 - 20) + (progress * 20 * (i.isEven ? 1 : -1));
                final double y = (i * 40.0 - 30) + (progress * 15 * (i.isOdd ? 1 : -1));
                final double size = 60.0 + i * 40.0;

                return Positioned(
                  left: x, top: y,
                  child: Container(
                    width: size, height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04 + (i * 0.008)),
                    ),
                  ),
                );
              },
            );
          }),

          // Dot pattern on header
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.28,
            child: CustomPaint(painter: _DotPatternPainter()),
          ),

          // ======= MAIN CONTENT =======
          SafeArea(
            child: Column(
              children: [
                // ======= HEADER BAR =======
                FadeTransition(
                  opacity: _headerFade,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _prevStep,
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daftar Akun',
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                              Text(_stepTitle(_currentStep),
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                            ],
                          ),
                        ),
                        // Step counter badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${_currentStep + 1}/$_totalSteps',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),

                // ======= ANIMATED PROGRESS BAR =======
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: List.generate(_totalSteps, (index) {
                      final isActive = index <= _currentStep;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 8 : 0),
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: isActive ? Colors.white : Colors.white.withOpacity(0.25),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),

                // ======= FORM CONTAINER (rounded top) =======
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F8FB),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

                // ======= BOTTOM BUTTON =======
                Container(
                  color: const Color(0xFFF8F8FB),
                  padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : (_currentStep == _totalSteps - 1 ? _handleRegister : _nextStep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB71C1C).withOpacity(0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == _totalSteps - 1 ? 'Daftar Sekarang' : 'Lanjut',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep == _totalSteps - 1 ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
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
        ],
      ),
    );
  }

  // ============================================================
  // STEP ICON (animated bounce on each step)
  // ============================================================
  Widget _buildStepIcon(IconData icon) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: const Color(0xFFB71C1C), size: 30),
      ),
    );
  }

  // ============================================================
  // FORM CARD WRAPPER (animated entry)
  // ============================================================
  Widget _buildFormCard({required List<Widget> children}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 20 * (1 - v)), child: c),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  // ============================================================
  // STEP 1: AKUN (HP, Email, Password)
  // ============================================================
  Widget _buildStep1Akun() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          _buildStepIcon(Icons.person_add_rounded),
          const SizedBox(height: 20),

          _buildFormCard(children: [
            // No HP
            _buildLabel('Nomor HP', isRequired: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _phoneController,
              hint: 'Contoh: 08123456789',
              icon: Icons.phone_android_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),

            // Email
            _buildLabel('Email', isRequired: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _emailController,
              hint: 'Contoh: toko@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),

            // Password
            _buildLabel('Password', isRequired: true),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _passwordController,
              hint: 'Minimal 6 karakter',
              showPassword: _showPass,
              onToggle: () => setState(() => _showPass = !_showPass),
            ),
            const SizedBox(height: 18),

            // Konfirmasi Password
            _buildLabel('Konfirmasi Password', isRequired: true),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _confirmPasswordController,
              hint: 'Ulangi password',
              showPassword: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
          ]),
          const SizedBox(height: 14),

          // Info box
          _buildInfoBox(
            text: 'Nomor HP dan Email akan digunakan untuk login. Pastikan keduanya aktif.',
            bgColor: const Color(0xFFFFF8E1),
            borderColor: const Color(0xFFFFE082),
            iconColor: const Color(0xFFF57F17),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2: DATA TOKO
  // ============================================================
  Widget _buildStep2Toko() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          _buildStepIcon(Icons.store_rounded),
          const SizedBox(height: 20),

          _buildFormCard(children: [
            // Nama Toko
            _buildLabel('Nama Toko', isRequired: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _namaTokoController,
              hint: 'Contoh: Toko Jaya Motor',
              icon: Icons.storefront_rounded,
            ),
            const SizedBox(height: 18),

            // Nama PIC
            _buildLabel('Nama PIC (Penanggung Jawab)', isRequired: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _picNameController,
              hint: 'Contoh: Budi Santoso',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 18),

            // Alamat Toko
            _buildLabel('Alamat Toko', isRequired: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _storeAddressController,
              hint: 'Jl. Raya No. 123, Surabaya',
              icon: Icons.location_on_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 18),

            // Domisili
            _buildLabel('Domisili', isRequired: true),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: _inputDecoration(hint: 'Pilih Kota', prefixIcon: Icons.map_outlined),
              icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey),
              value: _selectedDomisili,
              items: _listDomisili.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _selectedDomisili = v),
            ),
          ]),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 3: VERIFIKASI KTP
  // ============================================================
  Widget _buildStep3Ktp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          _buildStepIcon(Icons.badge_rounded),
          const SizedBox(height: 20),

          _buildFormCard(children: [
            // Nomor KTP
            _buildLabel('Nomor KTP', isRequired: true),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _ktpNumberController,
              hint: '16 digit nomor KTP',
              icon: Icons.credit_card_rounded,
              keyboardType: TextInputType.number,
              maxLength: 16,
            ),
            const SizedBox(height: 18),

            // Upload Foto KTP
            _buildLabel('Foto KTP', isRequired: true),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: () => _showImageSourceDialog(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: _ktpBytes != null ? Colors.transparent : const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _ktpBytes != null ? const Color(0xFF10B981) : Colors.grey[300]!,
                    width: _ktpBytes != null ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_ktpBytes != null ? 14 : 15),
                  child: _ktpBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_ktpBytes!, fit: BoxFit.cover),
                            // Checkmark
                            Positioned(
                              top: 10, right: 10,
                              child: Container(
                                width: 32, height: 32,
                                decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                            // Ganti button
                            Positioned(
                              bottom: 10, right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Ganti', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB71C1C).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, size: 28, color: Color(0xFFB71C1C)),
                            ),
                            const SizedBox(height: 12),
                            const Text('Tap untuk unggah foto KTP',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                            const SizedBox(height: 4),
                            Text('Dari galeri atau kamera', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                          ],
                        ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Tips Card
          _buildTipsCard(),
        ],
      ),
    );
  }

  // ============================================================
  // REUSABLE WIDGETS
  // ============================================================

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(children: [
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      if (isRequired) const Text(' *', style: TextStyle(color: Color(0xFFD32F2F), fontSize: 13)),
    ]);
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
        prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey[400]),
        suffixIcon: IconButton(
          icon: Icon(showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 20, color: Colors.grey[400]),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 20, color: Colors.grey[400]),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      counterText: '',
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5)),
    );
  }

  Widget _buildInfoBox({required String text, required Color bgColor, required Color borderColor, required Color iconColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: iconColor, height: 1.5))),
      ]),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.tips_and_updates_rounded, size: 14, color: Color(0xFFB71C1C)),
          ),
          const SizedBox(width: 10),
          const Text('Tips Foto KTP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB71C1C))),
        ]),
        const SizedBox(height: 12),
        _tipItem('Pastikan foto tidak buram / blur'),
        _tipItem('Seluruh bagian KTP terlihat jelas'),
        _tipItem('Hindari pantulan cahaya (glare)'),
      ]),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ]),
    );
  }

  // Cek apakah kamera tersedia (tidak di Windows/Linux desktop)
  bool get _isCameraAvailable {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  void _showImageSourceDialog() {
    // Jika kamera tidak tersedia (desktop), langsung buka galeri
    if (!_isCameraAvailable) {
      _pickKtpImage();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Pilih Sumber Foto', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _sourceButton(Icons.photo_library_rounded, 'Galeri', () { Navigator.pop(ctx); _pickKtpImage(); })),
              const SizedBox(width: 12),
              Expanded(child: _sourceButton(Icons.camera_alt_rounded, 'Kamera', () { Navigator.pop(ctx); _takeKtpPhoto(); })),
            ]),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFB71C1C).withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 24, color: const Color(0xFFB71C1C)),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ======= BACKGROUND DOT PATTERN =======
class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.03)..style = PaintingStyle.fill;
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