import 'package:supabase/supabase.dart';

/// Client khusus admin — bypass RLS untuk semua operasi data.
/// Tidak punya auth session, jadi service_role key dipakai penuh.
class AdminSupabase {
  static SupabaseClient? _client;

  static SupabaseClient get client {
    _client ??= SupabaseClient(
      'https://gzfdgfughmhjgbkdzotn.supabase.co',
      // PASTE service_role key yang sama dari main_admin.dart
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd6ZmRnZnVnaG1oamdia2R6b3RuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MTIzNTAxOSwiZXhwIjoyMDg2ODExMDE5fQ.X-IN6EELfWB1jaRDDGrgn5i8HZxx9S7m3a8ZnHmpXc4',
    );
    return _client!;
  }
}