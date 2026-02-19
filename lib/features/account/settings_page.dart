import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- LOGIKA 1: GANTI PASSWORD (LEBIH AMAN & USER FRIENDLY) ---
  Future<void> _changePassword() async {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    
    final user = _supabase.auth.currentUser;
    if (user == null || user.email == null) return;

    // Tampilkan Dialog Form
    await showDialog(
      context: context,
      barrierDismissible: false, // User gabisa tutup sembarangan klik luar
      builder: (context) {
        bool isDialogLoading = false; // Loading lokal khusus dialog

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Ganti Password", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. PASSWORD LAMA
                    const Text("Password Lama", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    TextField(
                      controller: oldPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "Masukkan password saat ini",
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 2. PASSWORD BARU
                    const Text("Password Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    TextField(
                      controller: newPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "Min. 6 karakter",
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // 3. KONFIRMASI PASSWORD BARU
                    const Text("Konfirmasi Password Baru", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    TextField(
                      controller: confirmPassController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: "Ketik ulang password baru",
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // Tombol Batal
                TextButton(
                  onPressed: isDialogLoading ? null : () => Navigator.pop(context),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
                // Tombol Simpan
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isDialogLoading ? null : () async {
                    // --- VALIDASI INPUT ---
                    if (oldPassController.text.isEmpty) {
                      _showSnack(context, "Password lama wajib diisi");
                      return;
                    }
                    if (newPassController.text.length < 6) {
                      _showSnack(context, "Password baru minimal 6 karakter");
                      return;
                    }
                    if (newPassController.text != confirmPassController.text) {
                      _showSnack(context, "Konfirmasi password tidak cocok!");
                      return;
                    }

                    // Mulai Loading di Dialog
                    setStateDialog(() => isDialogLoading = true);

                    try {
                      // 1. CEK PASSWORD LAMA (Login Ulang)
                      await _supabase.auth.signInWithPassword(
                        email: user.email,
                        password: oldPassController.text,
                      );

                      // 2. JIKA SUKSES, UPDATE KE PASSWORD BARU
                      await _supabase.auth.updateUser(
                        UserAttributes(password: newPassController.text),
                      );

                      if (!mounted) return;
                      Navigator.pop(context); // Tutup Dialog
                      
                      // Tampilkan sukses di halaman utama
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text("Password berhasil diganti!"), backgroundColor: Colors.green),
                      );

                    } on AuthException catch (e) {
                      // --- PENERJEMAH ERROR (USER FRIENDLY) ---
                      String errorMsg = "Gagal mengganti password.";
                      
                      // Cek pesan error bawaan Supabase
                      if (e.message.contains("Invalid login") || e.message.contains("invalid_credentials")) {
                        errorMsg = "Password lama salah!";
                      } else if (e.message.contains("weak_password")) {
                        errorMsg = "Password terlalu mudah ditebak.";
                      } else if (e.message.contains("same_password")) {
                        errorMsg = "Password baru tidak boleh sama dengan yang lama.";
                      }
                      
                      _showSnack(context, errorMsg);
                    } catch (e) {
                      _showSnack(context, "Terjadi kesalahan sistem.");
                    } finally {
                      // Stop Loading
                      if (mounted) setStateDialog(() => isDialogLoading = false);
                    }
                  },
                  child: isDialogLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Simpan", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fungsi helper untuk snackbar di dalam dialog
  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), 
      backgroundColor: Colors.red,
      duration: const Duration(milliseconds: 1500),
      behavior: SnackBarBehavior.floating, // Biar tidak tertutup keyboard
    ));
  }

  // --- LOGIKA 2: HAPUS AKUN (BAHAYA!) ---
  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Akun?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          "Tindakan ini PERMANEN. Semua poin, riwayat, dan data profil akan hilang selamanya. Anda yakin?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("YA, HAPUS", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Panggil Robot SQL
      await _supabase.rpc('delete_own_account');

      // Logout Paksa
      await _supabase.auth.signOut();

      if (!mounted) return;
      
      // Kembali ke Login
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Akun berhasil dihapus.")));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menghapus akun"), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : Column(
            children: [
              const SizedBox(height: 20),
              
              // Menu Ganti Password
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.blue),
                  title: const Text("Ganti Password"),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _changePassword,
                ),
              ),

              const SizedBox(height: 12),

              // Menu Hapus Akun
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Hapus Akun", style: TextStyle(color: Colors.red)),
                  subtitle: const Text("Hapus data permanen", style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: _deleteAccount,
                ),
              ),
            ],
          ),
    );
  }
}