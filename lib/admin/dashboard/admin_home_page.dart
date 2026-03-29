import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upsol_loyalty/admin/manage_conversion/manage_menu_page.dart';
import '../admin_auth/admin_login_page.dart';
import '../kyc_approval/kyc_list_page.dart';
import '../admin_supabase.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  
  int _selectedIndex = 0;
  AnimationController? _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _fadeController?.reset();
    setState(() => _selectedIndex = index);
    _fadeController?.forward();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFB71C1C), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Text('Yakin ingin keluar dari panel admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminLoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      body: SafeArea(
        child: Column(
          children: [
            // ======= CUSTOM APP BAR =======
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB71C1C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('U', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, $adminName',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
                        ),
                        const Text(
                          'Upsol Admin Panel',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF0F0F0)),
                    ),
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.notifications_none_rounded, color: Color(0xFF6B7280), size: 20)),
                        Positioned(
                          right: 10, top: 10,
                          child: Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Color(0xFFB71C1C), shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleLogout,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                      ),
                      child: const Icon(Icons.logout_rounded, color: Color(0xFF6B7280), size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ======= CONTENT =======
            Expanded(
              child: _fadeController != null
                  ? FadeTransition(
                      opacity: _fadeController!,
                      child: _buildContent(),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),

      // ======= BOTTOM NAV =======
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _navItem(1, Icons.verified_user_rounded, 'KYC'),
                _navItem(2, Icons.tune_rounded, 'Kelola'),
                _navItem(3, Icons.insights_rounded, 'Laporan'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _DashboardTab(supabase: _supabase),
        const KycListPage(),
        const ManageMenuPage(),
        _buildPlaceholder('Laporan', Icons.insights_rounded, 'Penukaran & Histori Faktur'),
      ],
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB71C1C).withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isSelected ? 24 : 22,
                color: isSelected ? const Color(0xFFB71C1C) : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFB71C1C) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title, IconData icon, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: const Color(0xFFB71C1C)),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }
}

// ======= DASHBOARD TAB =======
class _DashboardTab extends StatefulWidget {
  final SupabaseClient supabase;
  
  const _DashboardTab({required this.supabase});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;
  final _admin = AdminSupabase.client;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      // Perubahan diterapkan di sini: mengganti widget.supabase.from menjadi _admin.from
      final approved = await _admin.from('profiles').select('id').eq('approval_status', 'APPROVED');
      final pending = await _admin.from('profiles').select('id').eq('approval_status', 'PENDING');
      final pointsData = await _admin.from('profiles').select('points');
      int totalPoints = 0;
      for (var p in pointsData) {
        totalPoints += (p['points'] as num?)?.toInt() ?? 0;
      }
      final rewards = await _admin.from('user_rewards').select('id');

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
    return RefreshIndicator(
      color: const Color(0xFFB71C1C),
      onRefresh: _fetchAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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
                    const Text(
                      'Dashboard Overview',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
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
            const SizedBox(height: 20),

            // ======= STAT CARDS =======
            Row(
              children: [
                Expanded(
                  child: _AnimEntry(
                    delay: 100,
                    child: _StatCard(
                      label: 'User Aktif',
                      value: _isLoading ? '-' : '${_stats['stores'] ?? 0}',
                      icon: Icons.store_rounded,
                      color: const Color(0xFF3B82F6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnimEntry(
                    delay: 150,
                    child: _StatCard(
                      label: 'Pending KYC',
                      value: _isLoading ? '-' : '${_stats['pending'] ?? 0}',
                      icon: Icons.hourglass_top_rounded,
                      color: const Color(0xFFF59E0B),
                      highlight: (_stats['pending'] ?? 0) > 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnimEntry(
                    delay: 200,
                    child: _StatCard(
                      label: 'Total Poin',
                      value: _isLoading ? '-' : _fmtNum(_stats['points'] ?? 0),
                      icon: Icons.stars_rounded,
                      color: const Color(0xFFB71C1C),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnimEntry(
                    delay: 250,
                    child: _StatCard(
                      label: 'Hadiah Diklaim',
                      value: _isLoading ? '-' : '${_stats['rewards'] ?? 0}',
                      icon: Icons.card_giftcard_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ======= ACTIVITY =======
            _AnimEntry(
              delay: 300,
              child: const Text('Aktivitas Terbaru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),

            if (_isLoading)
              ...List.generate(4, (i) => _AnimEntry(
                delay: 350 + (i * 60),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 14, width: 120, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6))),
                            const SizedBox(height: 6),
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
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF5F5F5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                          child: Icon(tIcon, color: tColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                                    child: Text(tLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tColor)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                            ],
                          ),
                        ),
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
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
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