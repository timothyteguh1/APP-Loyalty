import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../admin_supabase.dart';
import 'accurate_service.dart';

class AccurateConnectPage extends StatefulWidget {
  const AccurateConnectPage({super.key});

  @override
  State<AccurateConnectPage> createState() => _AccurateConnectPageState();
}

class _AccurateConnectPageState extends State<AccurateConnectPage> {
  final _admin = AdminSupabase.client;
  final _tokenController = TextEditingController();

  bool _isLoading = true;
  bool _isSyncing = false;
  bool _showManualToken = false;

  Map<String, String> _config = {};
  SyncResult? _lastSyncResult;
  String _syncProgress = '';

  // Database ID sudah diketahui dari URL Accurate
  static const String _knownDbId = 'a4512d3a-0595-4bf9-bc6f-9d89016f0ffc';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    await _loadConfig();

    // Coba detect token dari URL (Flutter Web)
    if (kIsWeb && !_isConnected) {
      _tryReadTokenFromUrl();
    }
  }

  // ============================================================
  // Baca token dari URL fragment setelah OAuth redirect
  // ============================================================
  void _tryReadTokenFromUrl() {
    try {
      final href = Uri.base.toString();
      if (!href.contains('access_token=')) return;

      // Cari fragment atau query yang mengandung access_token
      String tokenPart = '';
      if (href.contains('#')) {
        tokenPart = href.split('#').last;
      } else if (href.contains('?')) {
        tokenPart = href.split('?').last;
      }

      if (tokenPart.isEmpty) return;

      final params = Uri.splitQueryString(tokenPart);
      final token = params['access_token'];

      if (token != null && token.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _saveTokenAndOpenDb(token);
        });
      }
    } catch (e) {
      debugPrint('URL token read error: $e');
    }
  }

  Future<void> _loadConfig() async {
    try {
      _config = await AccurateService.loadConfig(_admin);
    } catch (e) {
      debugPrint('Load config error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Simpan token + langsung buka database yang sudah diketahui
  // ============================================================
  Future<void> _saveTokenAndOpenDb(String token) async {
    setState(() { _isLoading = true; _syncProgress = 'Menyimpan token...'; });
    try {
      await AccurateService.saveToken(_admin, token);
      await _loadConfig();

      _showSnack('Token tersimpan! Membuka database...', true);

      // Langsung buka database yang sudah diketahui
      setState(() => _syncProgress = 'Membuka database Accurate...');
      final result = await AccurateService.openDatabase(token, _knownDbId);
      await AccurateService.saveSession(_admin, _knownDbId, result['host']!, result['session']!);
      await _loadConfig();

      _showSnack('Berhasil terhubung ke Accurate!', true);
    } catch (e) {
      _showSnack('Gagal: $e', false);
    } finally {
      if (mounted) setState(() { _isLoading = false; _syncProgress = ''; });
    }
  }

  // ============================================================
  // Submit token manual
  // ============================================================
  Future<void> _submitManualToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      _showSnack('Token tidak boleh kosong', false);
      return;
    }
    setState(() => _showManualToken = false);
    _tokenController.clear();
    await _saveTokenAndOpenDb(token);
  }

  // ============================================================
  // Buka halaman OAuth Accurate
  // ============================================================
  Future<void> _connectAccurate() async {
    final authUrl = AccurateService.buildAuthUrl();
    final uri = Uri.parse(authUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
      // Setelah user kembali, muncul dialog untuk paste token
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _showManualToken = true);
      }
    } else {
      _showSnack('Tidak bisa membuka browser', false);
    }
  }

  // ============================================================
  // Refresh session (buka ulang DB)
  // ============================================================
  Future<void> _refreshSession() async {
    setState(() => _isLoading = true);
    try {
      final token = _config['accurate_access_token'] ?? '';
      if (token.isEmpty) throw 'Token tidak tersedia, hubungkan ulang';
      final result = await AccurateService.openDatabase(token, _knownDbId);
      await AccurateService.saveSession(_admin, _knownDbId, result['host']!, result['session']!);
      await _loadConfig();
      _showSnack('Session diperbarui!', true);
    } catch (e) {
      _showSnack('Gagal: $e', false);
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // Sync faktur → poin
  // ============================================================
  Future<void> _startSync() async {
    final host = _config['accurate_db_host'] ?? '';
    final session = _config['accurate_db_session'] ?? '';

    if (host.isEmpty || session.isEmpty) {
      _showSnack('Buka database terlebih dahulu', false);
      return;
    }

    setState(() { _isSyncing = true; _syncProgress = 'Memulai sync...'; _lastSyncResult = null; });

    try {
      final result = await AccurateService.syncInvoicesToPoints(
        admin: _admin,
        host: host,
        session: session,
        onProgress: (msg) { if (mounted) setState(() => _syncProgress = msg); },
      );
      if (mounted) setState(() { _lastSyncResult = result; _isSyncing = false; _syncProgress = ''; });
    } catch (e) {
      if (e.toString() == 'SESSION_EXPIRED') {
        _showSnack('Session expired, refresh dulu', false);
        await _refreshSession();
      } else {
        _showSnack('Sync gagal: $e', false);
      }
      if (mounted) setState(() { _isSyncing = false; _syncProgress = ''; });
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Putuskan Koneksi?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Token dan session akan dihapus. Poin yang sudah tersinkron tidak terpengaruh.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), elevation: 0), child: const Text('Putuskan', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    await AccurateService.disconnect(_admin);
    await _loadConfig();
    _showSnack('Koneksi diputus', true);
  }

  void _showSnack(String msg, bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  bool get _isConnected => AccurateService.isTokenValid(_config);
  bool get _isSessionOpen =>
      (_config['accurate_db_session'] ?? '').isNotEmpty &&
      (_config['accurate_db_host'] ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(color: Color(0xFFB71C1C)),
        const SizedBox(height: 12),
        if (_syncProgress.isNotEmpty) Text(_syncProgress, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
      ]));
    }

    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _loadConfig,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Koneksi Accurate', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Sinkronisasi faktur penjualan dari Accurate Online → poin toko', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 20),

          // STATUS CARD
          _buildStatusCard(),
          const SizedBox(height: 20),

          // ======= STEP 1: CONNECT =======
          _buildCard(
            step: 1,
            title: 'Hubungkan Akun Accurate',
            subtitle: _isConnected ? 'Akun Accurate sudah terhubung ✓' : 'Login ke Accurate lalu paste token',
            isDone: _isConnected,
            child: Column(children: [
              if (!_isConnected) ...[
                // TOMBOL OAUTH
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _connectAccurate,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('1. Login ke Accurate Online', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(height: 8),
                // TOMBOL PASTE TOKEN MANUAL
                SizedBox(
                  width: double.infinity, height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _showManualToken = !_showManualToken),
                    icon: const Icon(Icons.vpn_key_rounded, size: 16),
                    label: const Text('2. Paste Access Token di sini', style: TextStyle(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF059669), side: const BorderSide(color: Color(0xFF059669)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                if (_showManualToken) ...[
                  const SizedBox(height: 12),
                  _buildTokenInstructions(),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tokenController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Paste access_token dari URL setelah login Accurate...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                      filled: true, fillColor: const Color(0xFFF8F9FC),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity, height: 44,
                    child: ElevatedButton(
                      onPressed: _submitManualToken,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Simpan Token', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ] else ...[
                // SUDAH CONNECTED
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBF7D0))),
                  child: Row(children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Token aktif', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF065F46), fontSize: 13)),
                      Text(
                        'Expire: ${_config['accurate_token_expiry']?.substring(0, 10) ?? '-'}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                      ),
                    ])),
                    TextButton(
                      onPressed: _disconnect,
                      child: const Text('Putuskan', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                    ),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // ======= STEP 2: SESSION =======
          _buildCard(
            step: 2,
            title: 'Database Accurate',
            subtitle: _isSessionOpen ? 'Database aktif ✓' : 'Buka koneksi ke database',
            isDone: _isSessionOpen,
            isDisabled: !_isConnected,
            child: _isConnected ? Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8F9FC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  const Icon(Icons.storage_rounded, size: 18, color: Color(0xFF6B7280)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Database ID', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                    Text(_knownDbId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                  ])),
                  if (_isSessionOpen) const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                ]),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity, height: 44,
                child: ElevatedButton.icon(
                  onPressed: _refreshSession,
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: Text(_isSessionOpen ? 'Refresh Session' : 'Buka Database', style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]) : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // ======= STEP 3: SYNC =======
          _buildCard(
            step: 3,
            title: 'Sync Faktur → Poin',
            subtitle: 'Konversi faktur penjualan Accurate ke poin toko',
            isDone: _lastSyncResult != null,
            isDisabled: !_isSessionOpen,
            child: _isSessionOpen ? Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFDE68A))),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Anti-double otomatis — faktur yang sudah diproses tidak akan dihitung ulang.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4))),
                ]),
              ),
              const SizedBox(height: 10),
              if (_isSyncing) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBAE6FD))),
                  child: Row(children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_syncProgress, style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF)))),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              if (_lastSyncResult != null) ...[
                _buildSyncResult(_lastSyncResult!),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _startSync,
                  icon: _isSyncing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, size: 20),
                  label: Text(_isSyncing ? 'Menyinkronkan...' : 'Mulai Sync Faktur', style: const TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFB71C1C).withOpacity(0.5), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ]) : const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),
          _buildGuideCard(),
        ]),
      ),
    );
  }

  // ============================================================
  // INSTRUKSI CARA AMBIL TOKEN
  // ============================================================
  Widget _buildTokenInstructions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cara ambil Access Token:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
        const SizedBox(height: 8),
        _instrStep('1', 'Klik "Login ke Accurate Online" di atas'),
        _instrStep('2', 'Login dengan akun Accurate → klik Beri Akses'),
        _instrStep('3', 'Setelah redirect, lihat URL browser — akan ada #access_token=xxx'),
        _instrStep('4', 'Copy nilai setelah "access_token=" sampai "&token_type"'),
        _instrStep('5', 'Paste di kolom ini → klik Simpan Token'),
        const SizedBox(height: 8),
        const Text('Contoh URL:', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: const SelectableText(
            'localhost:3000/#access_token=abc123...&token_type=bearer',
            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF059669)),
          ),
        ),
      ]),
    );
  }

  Widget _instrStep(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 18, height: 18, margin: const EdgeInsets.only(top: 1),
          decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
          child: Center(child: Text(n, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4))),
      ]),
    );
  }

  Widget _buildStatusCard() {
    Color color;
    String status;
    String subtitle;
    IconData icon;

    if (_isSessionOpen) {
      color = const Color(0xFF10B981);
      status = 'Terhubung & Siap Sync';
      subtitle = 'Database Accurate aktif';
      icon = Icons.check_circle_rounded;
    } else if (_isConnected) {
      color = const Color(0xFFF59E0B);
      status = 'Token Valid — Database Belum Dibuka';
      subtitle = 'Klik "Buka Database" di bawah';
      icon = Icons.pending_rounded;
    } else {
      color = const Color(0xFF9CA3AF);
      status = 'Belum Terhubung';
      subtitle = 'Ikuti langkah di bawah';
      icon = Icons.link_off_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(status, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ])),
      ]),
    );
  }

  Widget _buildCard({required int step, required String title, required String subtitle, required Widget child, bool isDone = false, bool isDisabled = false}) {
    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDone ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFF0F0F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: isDone ? const Color(0xFF10B981) : const Color(0xFFB71C1C), shape: BoxShape.circle),
              child: Center(child: isDone
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text('$step', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ])),
          ]),
          if (!isDisabled) ...[const SizedBox(height: 16), child],
        ]),
      ),
    );
  }

  Widget _buildSyncResult(SyncResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFBBF7D0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Hasil Sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
        const SizedBox(height: 10),
        _resultRow('Faktur Dicek', '${result.totalInvoicesChecked}'),
        _resultRow('Poin Ditambahkan', '+${result.totalPointsAdded}'),
        _resultRow('User Terpengaruh', '${result.totalUsersAffected}'),
        _resultRow('Dilewati (duplikat)', '${result.totalSkipped}'),
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...result.errors.take(3).map((e) => Text('⚠ $e', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)))),
        ],
      ]),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46))),
      ]),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.person_search_rounded, size: 18, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Setup Accurate ID per Toko', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        const Text('Setiap toko perlu Accurate Customer ID agar fakturnya terbaca saat sync.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
        const SizedBox(height: 10),
        _guideStep('1', 'Buka KYC Approval → pilih toko yang Approved'),
        _guideStep('2', 'Isi field "Accurate ID" dengan Customer ID dari database Accurate'),
        _guideStep('3', 'Kembali ke sini → Sync Faktur'),
      ]),
    );
  }

  Widget _guideStep(String n, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 20, height: 20, decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Text(n, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF374151)))),
      ]),
    );
  }
}