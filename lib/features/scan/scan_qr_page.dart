import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/ui_helpers.dart'; 

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _cameraController = MobileScannerController(
    formats: const [BarcodeFormat.qrCode], // Fokus QR saja agar ringan
  );
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false;

  String _debugScanResult = "Arahkan QR atau Upload Gambar...";

  // --- LOGIKA UPLOAD GAMBAR DARI LAPTOP/HP ---
  Future<void> _pickAndScanImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return; 

    setState(() => _isProcessing = true);
    showLoading(context);

    try {
      // Tunggu sebentar agar loading screen muncul sempurna di web
      await Future.delayed(const Duration(milliseconds: 500));

      final BarcodeCapture? capture = await _cameraController.analyzeImage(image.path);

      if (!mounted) return;
      hideLoading(context);

      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? code = capture.barcodes.first.rawValue;
        if (code != null) {
          setState(() => _debugScanResult = "Terbaca dari Upload: $code");
          _processQrCode(code); 
        }
      } else {
        _showError("QR Code tidak terdeteksi pada gambar ini.");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (!mounted) return;
      hideLoading(context);
      _showError("Gagal membaca gambar. Gunakan gambar PNG/JPG yang tajam.");
      setState(() => _isProcessing = false);
    }
  }

  // --- LOGIKA LIVE CAMERA ---
  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null) {
        final String code = barcode.rawValue!;
        
        if (mounted) {
          setState(() => _debugScanResult = "Terbaca dari Kamera: $code");
        }
        
        _processQrCode(code);
        break; 
      }
    }
  }

  // --- LOGIKA KE DATABASE SUPABASE ---
  Future<void> _processQrCode(String code) async {
    setState(() => _isProcessing = true);
    _cameraController.stop(); 
    showLoading(context);

    try {
      final response = await _supabase.rpc('scan_qr', params: {
        'code_input': code
      });

      if (!mounted) return;
      hideLoading(context);

      if (response['success'] == true) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 60),
                SizedBox(height: 10),
                Text("Berhasil!", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(response['message'], textAlign: TextAlign.center),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                onPressed: () {
                  Navigator.pop(context); 
                  Navigator.pop(context); 
                },
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      } else {
        _showError(response['message']); // Misal: "Kode sudah terpakai"
        _cameraController.start();
        setState(() => _isProcessing = false);
      }

    } catch (e) {
      if (mounted) hideLoading(context);
      _showError("Terjadi kesalahan sistem database.");
      _cameraController.start();
      setState(() => _isProcessing = false);
    }
  }

  // --- FITUR TESTING MANUAL (KETIK KODE) ---
  void _showManualInputDialog() {
    final TextEditingController inputController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Input Manual QR"),
        content: TextField(
          controller: inputController,
          decoration: const InputDecoration(hintText: "Contoh: UPSOL-TEST-50"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () {
              Navigator.pop(context);
              if (inputController.text.isNotEmpty) {
                _processQrCode(inputController.text.trim());
              }
            },
            child: const Text("Proses", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          // 1. BOX CAMERA
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: _cameraController,
                          onDetect: _onDetect,
                          fit: BoxFit.cover,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // TEKS DEBUG REALTIME
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _debugScanResult, 
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // 2. HEADER
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("Kembali", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 3. TOMBOL KONTROL BAWAH (Upload & Manual Input)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // TOMBOL UPLOAD GAMBAR
                  _buildCircleButton(Icons.image, "Upload QR", _pickAndScanImage),
                  
                  const SizedBox(width: 40),

                  // TOMBOL INPUT MANUAL (Penyelamat Testing)
                  _buildCircleButton(Icons.keyboard, "Input Manual", _showManualInputDialog),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60, height: 60,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.black, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
  
  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}