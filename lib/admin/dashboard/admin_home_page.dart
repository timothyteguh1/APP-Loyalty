import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';

// [PERBAIKAN]: Nama class ini sekarang murni isi Dashboard, 
// tidak ada lagi Bottom Navigation dan AppBar ganda.
class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  
  final _admin = AdminSupabase.client;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final approved = await _admin.from('profiles').select('id').eq('approval_status', 'APPROVED');
      final pending = await _admin.from('profiles').select('id').eq('approval_status', 'PENDING');
      final pointsData = await _admin.from('profiles').select('points');
      int totalPoints = 0;
      for (var p in pointsData) {
        totalPoints += (p['points'] as num?)?.toInt() ?? 0;
      }
      final rewards = await _admin.from('rewards').select('id');

      final activities = await _admin
          .from('point_history')
          .select('*, profiles!inner(full_name)')
          .order('created_at', ascending: false)
          .limit(8);

      if (mounted) {
        setState(() {
          _stats = {
            'stores': approved.length,
            'pending': pending.length,
            'points': totalPoints,
            'rewards': rewards.length,
          };
          _activities = List<Map<String, dynamic>>.from(activities);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Admin';
    
    // Kunci Responsif: Cek lebar layar
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.transparent, // Transparan agar menyatu dengan background AdminMainPage
      body: RefreshIndicator(
        color: const Color(0xFFB71C1C),
        onRefresh: _fetchAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ======= WELCOME CARD =======
              _AnimEntry(
                delay: 0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB71C1C).withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                            SizedBox(width: 6),
                            Text('Sistem Aktif', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Halo, $adminName 👋',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pantau aktivitas loyalty dari sini',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ======= STAT CARDS (RESPONSIF) =======
              if (isDesktop)
                // Mode Desktop: 4 Kolom menyamping
                Row(
                  children: [
                    Expanded(child: _AnimEntry(delay: 100, child: _StatCard(label: 'User Aktif', value: _isLoading ? '-' : '${_stats['stores'] ?? 0}', icon: Icons.store_rounded, color: const Color(0xFF3B82F6)))),
                    const SizedBox(width: 16),
                    Expanded(child: _AnimEntry(delay: 150, child: _StatCard(label: 'Pending KYC', value: _isLoading ? '-' : '${_stats['pending'] ?? 0}', icon: Icons.hourglass_top_rounded, color: const Color(0xFFF59E0B), highlight: (_stats['pending'] ?? 0) > 0))),
                    const SizedBox(width: 16),
                    Expanded(child: _AnimEntry(delay: 200, child: _StatCard(label: 'Total Poin', value: _isLoading ? '-' : _fmtNum(_stats['points'] ?? 0), icon: Icons.stars_rounded, color: const Color(0xFFB71C1C)))),
                    const SizedBox(width: 16),
                    Expanded(child: _AnimEntry(delay: 250, child: _StatCard(label: 'Item Hadiah', value: _isLoading ? '-' : '${_stats['rewards'] ?? 0}', icon: Icons.card_giftcard_rounded, color: const Color(0xFF10B981)))),
                  ],
                )
              else
                // Mode Mobile: 2x2 Grid
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _AnimEntry(delay: 100, child: _StatCard(label: 'User Aktif', value: _isLoading ? '-' : '${_stats['stores'] ?? 0}', icon: Icons.store_rounded, color: const Color(0xFF3B82F6)))),
                        const SizedBox(width: 12),
                        Expanded(child: _AnimEntry(delay: 150, child: _StatCard(label: 'Pending KYC', value: _isLoading ? '-' : '${_stats['pending'] ?? 0}', icon: Icons.hourglass_top_rounded, color: const Color(0xFFF59E0B), highlight: (_stats['pending'] ?? 0) > 0))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _AnimEntry(delay: 200, child: _StatCard(label: 'Total Poin', value: _isLoading ? '-' : _fmtNum(_stats['points'] ?? 0), icon: Icons.stars_rounded, color: const Color(0xFFB71C1C)))),
                        const SizedBox(width: 12),
                        Expanded(child: _AnimEntry(delay: 250, child: _StatCard(label: 'Item Hadiah', value: _isLoading ? '-' : '${_stats['rewards'] ?? 0}', icon: Icons.card_giftcard_rounded, color: const Color(0xFF10B981)))),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 32),

              // ======= ACTIVITY =======
              _AnimEntry(
                delay: 300,
                child: const Text('Aktivitas Terbaru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                ...List.generate(4, (i) => _AnimEntry(
                  delay: 350 + (i * 60),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12))),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(height: 14, width: 120, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6))),
                              const SizedBox(height: 8),
                              Container(height: 11, width: 80, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6))),
                            ],
                          ),
                        ),
                        Container(height: 16, width: 50, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6))),
                      ],
                    ),
                  ),
                ))
              else if (_activities.isEmpty)
                _AnimEntry(
                  delay: 350,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.inbox_rounded, color: Color(0xFF9CA3AF), size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text('Belum ada aktivitas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                        const SizedBox(height: 4),
                        const Text('Aktivitas poin akan muncul disini', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                      ],
                    ),
                  ),
                )
              else
                ...List.generate(_activities.length, (i) {
                  final item = _activities[i];
                  final int amount = item['amount'] ?? 0;
                  final bool isPos = amount > 0;
                  final String name = item['profiles']?['full_name'] ?? 'Unknown';
                  final String type = item['reference_type'] ?? 'MANUAL';

                  IconData tIcon;
                  Color tColor;
                  String tLabel;
                  switch (type) {
                    case 'INVOICE': tIcon = Icons.receipt_long_rounded; tColor = const Color(0xFF3B82F6); tLabel = 'Faktur'; break;
                    case 'REWARD_CLAIM': tIcon = Icons.card_giftcard_rounded; tColor = const Color(0xFFB71C1C); tLabel = 'Klaim'; break;
                    case 'SYSTEM_CUTOFF': tIcon = Icons.restart_alt_rounded; tColor = const Color(0xFF6B7280); tLabel = 'Cutoff'; break;
                    case 'QR_SCAN': tIcon = Icons.qr_code_rounded; tColor = const Color(0xFF8B5CF6); tLabel = 'QR'; break;
                    default: tIcon = Icons.edit_rounded; tColor = const Color(0xFFF59E0B); tLabel = 'Manual';
                  }

                  String timeStr = '';
                  if (item['created_at'] != null) {
                    try {
                      final dt = DateTime.parse(item['created_at']).toLocal();
                      final diff = DateTime.now().difference(dt);
                      if (diff.inMinutes < 60) timeStr = '${diff.inMinutes}m lalu';
                      else if (diff.inHours < 24) timeStr = '${diff.inHours}h lalu';
                      else timeStr = '${diff.inDays}d lalu';
                    } catch (_) {}
                  }

                  return _AnimEntry(
                    delay: 350 + (i * 60),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF3F4F6)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                            child: Icon(tIcon, color: tColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                      child: Text(tLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tColor)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${isPos ? "+" : ""}$amount',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ======= STAT CARD =======
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatCard({required this.label, required this.value, required this.icon, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? color.withOpacity(0.2) : const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 14),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ======= STAGGERED ANIMATION =======
class _AnimEntry extends StatelessWidget {
  final int delay;
  final Widget child;
  const _AnimEntry({required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 16 * (1 - value)), child: child),
        );
      },
      child: child,
    );
  }
}