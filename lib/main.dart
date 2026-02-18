import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import sesuai struktur folder di project-mu
import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';

void main() async {
  // 1. Pastikan binding Flutter sudah siap
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi Supabase dengan Key kamu
  await Supabase.initialize(
    url: 'https://gzfdgfughmhjgbkdzotn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6ZmRnZnVnaG1oamdia2R6b3RuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEyMzUwMTksImV4cCI6MjA4NjgxMTAxOX0.jjI5hOOx1SSByo_Il8ceMbi944uEY59JamP7_87A2Y4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upsol Loyalty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // AuthGate berfungsi sebagai satpam aplikasi
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Mendengarkan perubahan status autentikasi secara real-time
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Tampilkan loading jika sedang mengecek status koneksi
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Ambil session dari snapshot terbaru
        final Session? session = snapshot.data?.session;

        if (session != null) {
          // Jika ada session (sudah login), arahkan ke Home
          return const HomePage();
        } else {
          // Jika tidak ada session, arahkan ke Login
          return const LoginPage();
        }
      },
    );
  }
}