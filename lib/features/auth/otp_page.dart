import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class OtpPage extends StatefulWidget {
  final String email;
  const OtpPage({super.key, required this.email});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan 6 digit kode OTP!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verifikasi OTP ke Supabase
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: otp,
        type: OtpType.magiclink, // Supabase mengirim OTP bersamaan dengan magic link
      );
      
      // Jika berhasil, AuthGate di main.dart akan otomatis bereaksi 
      // dan melempar user ke halaman Edit Profil (Satpam Biodata)
      if (mounted) {
        Navigator.pop(context); // Tutup halaman OTP
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kode OTP salah atau kadaluarsa: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read_rounded, size: 80, color: Color(0xFF10B981)),
              const SizedBox(height: 24),
              const Text('Cek Email Anda', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              Text('Kami telah mengirimkan 6 digit kode verifikasi ke\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 40),
              CustomTextField(
                controller: _otpController,
                label: 'Kode Verifikasi (OTP)',
                hint: 'Masukkan 6 digit kode',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'Verifikasi',
                onPressed: _isLoading ? () {} : _verifyOtp,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}