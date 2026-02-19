import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui_helpers.dart'; // [PENTING] Import Helper UI

class DetailRewardPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const DetailRewardPage({super.key, required this.item});

  @override
  State<DetailRewardPage> createState() => _DetailRewardPageState();
}

class _DetailRewardPageState extends State<DetailRewardPage> {
  final _supabase = Supabase.instance.client;
  bool _isProcessing = false; // Flag cegah double tap

  // --- FUNGSI KLAIM HADIAH (DENGAN LOADING OVERLAY) ---
  Future<void> _claimReward() async {
    // 1. Konfirmasi Dulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Klaim"),
        content: Text("Tukar ${widget.item['points_required']} poin untuk hadiah ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Ya, Klaim", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (_isProcessing) return; // Cegah double tap

    setState(() => _isProcessing = true);
    
    // 2. TAMPILKAN LOADING SCENE
    showLoading(context);

    try {
      // 3. Panggil Robot Database 'claim_reward'
      await _supabase.rpc('claim_reward', params: {
        'reward_id_input': widget.item['id']
      });

      if (!mounted) return;
      hideLoading(context); // TUTUP LOADING

      // 4. Sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Berhasil diklaim! Cek menu History/Voucher."), 
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // Kembali ke list

    } on PostgrestException catch (e) {
      if (mounted) hideLoading(context); // TUTUP LOADING KALAU ERROR
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (mounted) hideLoading(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan sistem."), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          // 1. HEADER MERAH BACKGROUND
          Container(
            height: 200,
            color: const Color(0xFFD32F2F),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // 2. APP BAR CUSTOM (Tombol Kembali)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text("Kembali", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 3. KARTU JUDUL (Overlay)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Logo Kecil
                              Image.asset('assets/images/logo.png', height: 30, errorBuilder: (c,e,s) => const SizedBox()),
                              const SizedBox(height: 16),
                              // Nama Hadiah
                              Text(
                                widget.item['name'],
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              // Foto Besar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  widget.item['image_url'] ?? '',
                                  width: double.infinity,
                                  height: 150,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c,e,s) => const SizedBox(), // Hide jika error
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 4. DESKRIPSI & S&K
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Deskripsi
                              Text(widget.item['description'] ?? 'Tidak ada deskripsi.', style: const TextStyle(fontSize: 14, height: 1.5)),
                              
                              const SizedBox(height: 24),
                              
                              const Text("Syarat & Ketentuan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              Text(
                                widget.item['terms_condition'] ?? '1. Berlaku untuk satu kali penukaran.\n2. Tidak dapat diuangkan.',
                                style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 100), // Spasi bawah agar tidak ketutup tombol
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. BOTTOM BAR (Poin & Tombol Klaim)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Poin Saat Ini (Realtime Stream)
                  Row(
                    children: [
                      const Text("Poin Anda Saat Ini: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', _supabase.auth.currentUser?.id ?? ''),
                        builder: (context, snapshot) {
                          String points = "...";
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            points = snapshot.data![0]['points'].toString();
                          }
                          return Text("$points Points", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black));
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Harga Hadiah
                      Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "${widget.item['points_required']}",
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      // Tombol Klaim
                      ElevatedButton(
                        onPressed: _claimReward, // Tidak perlu cek isLoading di sini, karena sudah ditangani fungsi _claimReward
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Klaim", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}