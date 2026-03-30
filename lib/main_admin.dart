import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Import dotenv

import 'admin/admin_auth/admin_login_page.dart';
import 'admin/dashboard/admin_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load file .env sebelum inisialisasi Supabase
  await dotenv.load(fileName: ".env");

  // 3. Inisialisasi Supabase khusus Admin
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // Karena ini untuk Admin, kita gunakan SERVICE_ROLE yang ada di .env
    anonKey: dotenv.env['SUPABASE_SERVICE_ROLE']!, 
  );

  runApp(const UpsolAdminApp());
}

class UpsolAdminApp extends StatelessWidget {
  const UpsolAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upsol Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB71C1C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFB71C1C)),
            ),
          );
        }

        final Session? session = snapshot.data?.session;

        if (session != null) {
          return const AdminHomePage();
        } else {
          return const AdminLoginPage();
        }
      },
    );
  }
}