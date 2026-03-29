import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin/admin_auth/admin_login_page.dart';
import 'admin/dashboard/admin_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://gzfdgfughmhjgbkdzotn.supabase.co',
    // GANTI DENGAN SERVICE_ROLE KEY (JWT panjang, bukan sb_secret_)
    // Ambil dari: Supabase Dashboard > Settings > API > service_role (secret)
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6ZmRnZnVnaG1oamdia2R6b3RuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTIzNTAxOSwiZXhwIjoyMDg2ODExMDE5fQ.X-IN6EELfWB1jaRDDGrgn5i8HZxx9S7m3a8ZnHmpXc4',
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