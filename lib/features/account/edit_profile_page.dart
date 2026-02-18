import 'dart:io'; // Untuk menangani File
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Plugin Kamera/Galeri
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_text_field.dart'; 
import '../../widgets/primary_button.dart';   

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _supabase = Supabase.instance.client;
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  
  bool _isLoading = false;
  
  // Variabel penampung foto
  File? _imageFile;        // Foto baru dari HP (lokal)
  String? _avatarUrl;      // Foto lama dari Server (URL)

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';
      _nameController.text = user.userMetadata?['full_name'] ?? '';
      
      // Ambil URL foto jika sudah pernah upload sebelumnya
      setState(() {
        _avatarUrl = user.userMetadata?['avatar_url'];
      });
    }
  }

  // --- LOGIKA 1: BUKA GALERI HP ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Buka galeri, ambil 1 foto
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      maxWidth: 600, // Kecilkan gambar biar hemat kuota upload
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path); // Simpan di variabel lokal
      });
    }
  }

  // --- LOGIKA 2: UPLOAD KE SUPABASE ---
  Future<String?> _uploadImage(String userId) async {
    // Jika user tidak memilih foto baru, kembalikan URL lama
    if (_imageFile == null) return _avatarUrl; 

    try {
      // Buat nama file unik: "user_id-timestamp.jpg"
      final fileExt = _imageFile!.path.split('.').last;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      // Upload ke bucket 'avatars'
      await _supabase.storage.from('avatars').upload(
        fileName,
        _imageFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      // Minta Public URL dari Supabase agar bisa ditampilkan
      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      debugPrint("Gagal upload foto: $e");
      // Jangan stop proses, kembalikan null atau url lama saja
      return _avatarUrl; 
    }
  }

  // --- LOGIKA 3: SIMPAN DATA ---
  Future<void> _updateProfile() async {
    // 1. Turunkan Keyboard
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      // 2. Upload Foto dulu (Tunggu sampai selesai)
      final String? newAvatarUrl = await _uploadImage(user.id);
      
      // [ANTI CRASH] Cek mounted sebelum lanjut
      if (!mounted) return;

      // 3. Update Data User (Nama & URL Foto) ke Metadata
      final UserResponse response = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'full_name': _nameController.text.trim(),
            'avatar_url': newAvatarUrl, // Simpan link fotonya
          },
        ),
      );

      // 4. Refresh agar aplikasi sadar data berubah
      if (response.user != null) {
        await _supabase.auth.refreshSession();
      }

      // [ANTI CRASH] Cek mounted lagi sebelum menampilkan pesan
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil diperbarui!')),
      );
      
      // 5. Jeda Aman Anti-Crash
      await Future.delayed(const Duration(milliseconds: 500));
      
      // [ANTI CRASH] Cek mounted terakhir sebelum pindah halaman
      if (!mounted) return;
      
      // 6. Kembali ke halaman sebelumnya dengan sinyal 'true'
      Navigator.pop(context, true); 
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
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
        title: const Text("Edit Profil", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- WIDGET FOTO PROFIL ---
            GestureDetector(
              onTap: _pickImage, // Klik foto untuk ganti
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    // Logika Tampilan Foto:
                    // 1. Jika ada foto baru di HP (_imageFile) -> Pakai FileImage
                    // 2. Jika tidak, cek foto di Server (_avatarUrl) -> Pakai NetworkImage
                    // 3. Jika tidak ada semua -> Pakai gambar default
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                            ? NetworkImage(_avatarUrl!)
                            : const NetworkImage('https://i.pravatar.cc/150?img=12') as ImageProvider,
                  ),
                  // Ikon Kamera Kecil
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text("Ketuk foto untuk mengubah", style: TextStyle(fontSize: 12, color: Colors.grey)),
            
            const SizedBox(height: 30),

            CustomTextField(
              label: "Nama Lengkap",
              hint: "Masukkan nama",
              controller: _nameController,
            ),
            const SizedBox(height: 20),
            
            IgnorePointer(
              child: Opacity(
                opacity: 0.5,
                child: CustomTextField(
                  label: "Email",
                  hint: "Email",
                  controller: _emailController,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            PrimaryButton(
              text: "SIMPAN PERUBAHAN",
              isLoading: _isLoading,
              onPressed: _updateProfile, 
            ),
          ],
        ),
      ),
    );
  }
}