import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/email_notification_service.dart';

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  MobileScannerController? _cameraController;
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;
  String _debugScanResult = "Arahkan QR atau Upload Gambar...";

  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    try { return Platform.isAndroid || Platform.isIOS; } catch (_) { return false; }
  }

  @override
  void initState() {
    super.initState();
    if (_isMobilePlatform) {
      _cameraController = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
    }
  }

  Future<void> _pickAndScanImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isProcessing = true);
    showLoading(context);

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_cameraController != null) {
        final BarcodeCapture? capture = await _cameraController!.analyzeImage(image.path);
        if (!mounted) return;
        hideLoading(context);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final String? code = capture.barcodes.first.rawValue;
          if (code != null && code.trim().isNotEmpty) {
            setState(() => _debugScanResult = "Terbaca dari Upload: $code");
            _processQrCode(code);
          } else {
            _showError("QR Code kosong atau tidak valid.");
            setState(() => _isProcessing = false);
          }
        } else {
          _showError("QR Code tidak terdeteksi pada gambar ini.");
          setState(() => _isProcessing = false);
        }
      } else {
        if (!mounted) return;
        hideLoading(context);
        _showError("Upload QR tidak tersedia di desktop. Gunakan Input Manual.");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (!mounted) return;
      hideLoading(context);
      _showError("Gagal membaca gambar.");
      setState(() => _isProcessing = false);
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        final String code = barcode.rawValue!;
        if (mounted) { setState(() => _debugScanResult = "Terbaca dari Kamera: $code"); }
        _processQrCode(code);
        break;
      }
    }
  }

  Future<void> _processQrCode(String code) async {
    setState(() => _isProcessing = true);
    _cameraController?.stop();
    showLoading(context);

    try {
      final response = await _supabase.rpc('scan_qr', params: {'code_input': code});

      if (!mounted) return;
      hideLoading(context);

      if (response['success'] == true) {
        // ======= EMAIL NOTIFIKASI: QR Points =======
        final user = _supabase.auth.currentUser;
        if (user?.email != null) {
          final points = response['points'];
          EmailNotificationService.sendQrPoints(
            toEmail: user!.email!,
            userName: user.userMetadata?['full_name'] ?? 'User',
            pointsAmount: points is int ? points : 0,
            qrCode: code,
          );
        }
        // ======= END EMAIL =======

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Column(children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 10),
              Text("Berhasil!", style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            content: Text(response['message'], textAlign: TextAlign.center),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                onPressed: () { Navigator.pop(dialogContext); Navigator.pop(context); },
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      } else {
        _showError(response['message'] ?? "QR Code ditolak.");
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) { _cameraController?.start(); setState(() => _isProcessing = false); }
      }
    } catch (e) {
      if (mounted) hideLoading(context);
      _showError("Terjadi kesalahan sistem database.");
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) { _cameraController?.start(); setState(() => _isProcessing = false); }
    }
  }

  void _showManualInputDialog() {
    final TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Input Manual QR"),
        content: TextField(controller: inputController, decoration: const InputDecoration(hintText: "Contoh: UPSOL-TEST-50")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () { Navigator.pop(dialogContext); if (inputController.text.isNotEmpty) { _processQrCode(inputController.text.trim()); } },
            child: const Text("Proses", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 280, height: 280,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white, width: 2)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _isMobilePlatform && _cameraController != null
                    ? MobileScanner(controller: _cameraController!, onDetect: _onDetect, fit: BoxFit.cover)
                    : _buildDesktopFallback(),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
              child: Text(_isMobilePlatform ? _debugScanResult : "Desktop Mode: Gunakan Input Manual", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            ),
          ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Text("Kembali", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_isMobilePlatform) _buildCircleButton(Icons.image, "Upload QR", _pickAndScanImage),
              if (_isMobilePlatform) const SizedBox(width: 40),
              _buildCircleButton(Icons.keyboard, "Input Manual", _showManualInputDialog),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildDesktopFallback() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.desktop_windows_rounded, color: Colors.white38, size: 48),
        const SizedBox(height: 12),
        const Text("Kamera tidak tersedia", style: TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text("Gunakan Input Manual di bawah", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
      ])),
    );
  }

  Widget _buildCircleButton(IconData icon, String label, VoidCallback onTap) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(30),
        child: Container(width: 60, height: 60, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: Colors.black, size: 28)),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }

  @override
  void dispose() { _cameraController?.dispose(); super.dispose(); }
}