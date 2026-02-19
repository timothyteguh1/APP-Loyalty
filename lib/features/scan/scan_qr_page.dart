import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui_helpers.dart'; // Import Helper UI kita

class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _cameraController = MobileScannerController();
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false; // Supaya gak scan berkali-kali dalam 1 detik

  // --- LOGIKA SAAT QR TERDETEKSI ---
  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final String code = barcode.rawValue!;
        
        // Cek apakah kode QR valid (Misal formatnya harus "UPSOL:50")
        // Contoh kode QR: "UPSOL_POINT_50" -> Artinya nambah 50 poin
        if (code.startsWith("UPSOL_POINT_")) {
          _processQrCode(code);
          break; // Stop loop setelah dapat 1 kode valid
        } else {
          _showError("QR Code tidak dikenali!");
        }
      }
    }
  }

Future<void> _processQrCode(String code) async {
    setState(() => _isProcessing = true);
    _cameraController.stop(); 
    showLoading(context);

    try {
      // Panggil Robot Database 'scan_qr'
      final response = await _supabase.rpc('scan_qr', params: {
        'code_input': code
      });

      if (!mounted) return;
      hideLoading(context);

      if (response['success'] == true) {
        // SUKSES
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
                  Navigator.pop(context); // Tutup Dialog
                  Navigator.pop(context); // Kembali ke Home
                },
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      } else {
        // GAGAL (Kode salah / Sudah dipakai)
        _showError(response['message']);
        _cameraController.start();
        setState(() => _isProcessing = false);
      }

    } catch (e) {
      if (mounted) hideLoading(context);
      _showError("Terjadi kesalahan sistem.");
      _cameraController.start();
      setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background Hitam sesuai desain
      body: Stack(
        children: [
          // 1. LAYAR KAMERA
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),

          // 2. OVERLAY GELAP & FRAME
          // Kita pakai ColorFiltered untuk bikin "lubang" kotak di tengah
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.black54, // Gelap transparan
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. GARIS MERAH SCANNER (Visual Only)
          // 3. GARIS MERAH SCANNER (Visual Only)
          Center(
            child: Container(
              width: 280,
              height: 2,
              margin: const EdgeInsets.only(bottom: 20),
              // PERBAIKAN: Masukkan color & boxShadow ke dalam BoxDecoration
              decoration: BoxDecoration(
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5), 
                    blurRadius: 10, 
                    spreadRadius: 2
                  )
                ],
              ),
            ),
          ),
          // 4. HEADER (Tombol Kembali & Judul)
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
                      const Text(
                        "Kembali",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "Scan QR Code",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Scan QR Code untuk mendapatkan poin.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // 5. TOMBOL KONTROL BAWAH (Flash & Gallery)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Tombol Upload (Placeholder, krn butuh logic tambahan image_picker)
                  _buildCircleButton(Icons.image, "Upload Gambar", () {
                     _showError("Fitur upload segera hadir!");
                  }),
                  
                  const SizedBox(width: 60),

          
                  // Tombol Flash (VERSI PERBAIKAN)
                  ValueListenableBuilder(
                    valueListenable: _cameraController, // Dengarkan controllernya langsung
                    builder: (context, state, child) {
                      // Ambil status torch dari state value
                      final bool isTorchOn = state.torchState == TorchState.on;
                      
                      return _buildCircleButton(
                        isTorchOn ? Icons.flash_on : Icons.flash_off, 
                        "Nyalakan Flash", 
                        () => _cameraController.toggleTorch()
                      );
                    },
                  ),
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
            decoration: const BoxDecoration(
              color: Colors.white, 
              shape: BoxShape.circle,
            ),
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