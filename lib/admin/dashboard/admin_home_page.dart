import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../admin_supabase.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  final _admin = AdminSupabase.client;
  final _supabase = Supabase.instance.client;

  // Master animation controller
  late AnimationController _masterCtrl;

  @override
  void initState() {
    super.initState();
    _masterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    // [PERBAIKAN] Beri jeda render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAll();
    });
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    _masterCtrl.reset();
    try {
      final approved = await _admin.from('profiles').select('id').eq('approval_status', 'APPROVED');
      final pending = await _admin.from('profiles').select('id').eq('approval_status', 'PENDING');
      final pointsData = await _admin.from('profiles').select('points');
      int totalPoints = 0;
      for (var p in pointsData) { totalPoints += (p['points'] as num?)?.toInt() ?? 0; }
      final rewards = await _admin.from('rewards').select('id');
      final activities = await _admin.from('point_history').select('*, profiles!inner(full_name)').order('created_at', ascending: false).limit(8);

      if (mounted) {
        setState(() {
          _stats = {'stores': approved.length, 'pending': pending.length, 'points': totalPoints, 'rewards': rewards.length};
          _activities = List<Map<String, dynamic>>.from(activities);
          _isLoading = false;
        });
        // Trigger all animations
        _masterCtrl.forward();
      }
    } catch (e) {
      // [PERBAIKAN] Print error ke log
      debugPrint("ERROR FETCH ADMIN HOME: $e"); 
      if (mounted) {
        setState(() => _isLoading = false);
        _masterCtrl.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final adminName = user?.userMetadata?['full_name'] ?? user?.email?.split('@')[0] ?? 'Admin';
    final bool isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: const Color(0xFFB71C1C),
        onRefresh: _fetchAll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _isLoading
                ? _buildLoadingSkeleton(isDesktop)
                : AnimatedBuilder(
                    animation: _masterCtrl,
                    builder: (context, _) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ======= WELCOME CARD (slide down + fade) =======
                          _buildStaggered(
                            delay: 0.0,
                            child: _buildWelcomeCard(adminName),
                          ),
                          const SizedBox(height: 24),

                          // ======= STAT CARDS (staggered left to right) =======
                          if (isDesktop)
                            Row(children: [
                              Expanded(child: _buildStaggered(delay: 0.1, child: _AnimatedStatCard(label: 'User Aktif', targetValue: _stats['stores'] ?? 0, icon: Icons.store_rounded, color: const Color(0xFF3B82F6), progress: _masterCtrl.value))),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStaggered(delay: 0.15, child: _AnimatedStatCard(label: 'Pending KYC', targetValue: _stats['pending'] ?? 0, icon: Icons.hourglass_top_rounded, color: const Color(0xFFF59E0B), highlight: (_stats['pending'] ?? 0) > 0, progress: _masterCtrl.value))),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStaggered(delay: 0.2, child: _AnimatedStatCard(label: 'Total Poin', targetValue: _stats['points'] ?? 0, icon: Icons.stars_rounded, color: const Color(0xFFB71C1C), format: true, progress: _masterCtrl.value))),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStaggered(delay: 0.25, child: _AnimatedStatCard(label: 'Item Hadiah', targetValue: _stats['rewards'] ?? 0, icon: Icons.card_giftcard_rounded, color: const Color(0xFF10B981), progress: _masterCtrl.value))),
                            ])
                          else
                            Column(children: [
                              Row(children: [
                                Expanded(child: _buildStaggered(delay: 0.1, child: _AnimatedStatCard(label: 'User Aktif', targetValue: _stats['stores'] ?? 0, icon: Icons.store_rounded, color: const Color(0xFF3B82F6), progress: _masterCtrl.value))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStaggered(delay: 0.15, child: _AnimatedStatCard(label: 'Pending KYC', targetValue: _stats['pending'] ?? 0, icon: Icons.hourglass_top_rounded, color: const Color(0xFFF59E0B), highlight: (_stats['pending'] ?? 0) > 0, progress: _masterCtrl.value))),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: _buildStaggered(delay: 0.2, child: _AnimatedStatCard(label: 'Total Poin', targetValue: _stats['points'] ?? 0, icon: Icons.stars_rounded, color: const Color(0xFFB71C1C), format: true, progress: _masterCtrl.value))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStaggered(delay: 0.25, child: _AnimatedStatCard(label: 'Item Hadiah', targetValue: _stats['rewards'] ?? 0, icon: Icons.card_giftcard_rounded, color: const Color(0xFF10B981), progress: _masterCtrl.value))),
                              ]),
                            ]),
                          const SizedBox(height: 32),

                          // ======= ACTIVITY HEADER =======
                          _buildStaggered(
                            delay: 0.3,
                            child: Row(children: [
                              const Text('Aktivitas Terbaru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                              const Spacer(),
                              Text('${_activities.length} transaksi', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                            ]),
                          ),
                          const SizedBox(height: 16),

                          // ======= ACTIVITY LIST (staggered) =======
                          if (_activities.isEmpty)
                            _buildStaggered(
                              delay: 0.35,
                              child: Container(
                                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 40),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                child: Column(children: [
                                  Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.inbox_rounded, color: Color(0xFF9CA3AF), size: 28)),
                                  const SizedBox(height: 12),
                                  const Text('Belum ada aktivitas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                                  const SizedBox(height: 4),
                                  const Text('Aktivitas poin akan muncul disini', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                                ]),
                              ),
                            )
                          else
                            ...List.generate(_activities.length, (i) {
                              final item = _activities[i];
                              final int amount = item['amount'] ?? 0;
                              final bool isPos = amount > 0;
                              final String name = item['profiles']?['full_name'] ?? 'Unknown';
                              final String type = item['reference_type'] ?? 'MANUAL';

                              IconData tIcon; Color tColor; String tLabel;
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

                              return _buildStaggered(
                                delay: 0.35 + (i * 0.05),
                                slideUp: true,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF3F4F6)),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Row(children: [
                                    Container(width: 42, height: 42, decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(tIcon, color: tColor, size: 20)),
                                    const SizedBox(width: 14),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Flexible(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                        const SizedBox(width: 8),
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: tColor.withOpacity(0.08), borderRadius: BorderRadius.circular(4)), child: Text(tLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tColor))),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
                                    ])),
                                    const SizedBox(width: 10),
                                    // Animated amount text
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: amount.toDouble()),
                                      duration: Duration(milliseconds: 600 + (i * 100)),
                                      curve: Curves.easeOutCubic,
                                      builder: (_, val, __) => Text(
                                        '${isPos ? "+" : ""}${val.toInt()}',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                      ),
                                    ),
                                  ]),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ======= STAGGERED ANIMATION HELPER =======
  Widget _buildStaggered({required double delay, required Widget child, bool slideUp = false}) {
    // Calculate the local progress based on delay
    final double start = delay;
    final double end = (delay + 0.3).clamp(0.0, 1.0);
    final progress = Curves.easeOutCubic.transform(
      (((_masterCtrl.value - start) / (end - start)).clamp(0.0, 1.0)),
    );

    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(slideUp ? 0 : 0, (1 - progress) * 20),
        child: child,
      ),
    );
  }

  // ======= WELCOME CARD =======
  Widget _buildWelcomeCard(String adminName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Stack(
        children: [
          // Subtle decorative circles
          Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
          Positioned(right: 40, bottom: -30, child: Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
          // Content
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  builder: (_, val, child) => Opacity(opacity: (val * 2).clamp(0, 1), child: child),
                  child: const Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                ),
                const SizedBox(width: 6),
                const Text('Sistem Aktif', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Halo, $adminName 👋', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Pantau aktivitas loyalty dari sini', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          ]),
        ],
      ),
    );
  }

  // ======= LOADING SKELETON =======
  Widget _buildLoadingSkeleton(bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Welcome shimmer
        _Shimmer(width: double.infinity, height: 120, radius: 20),
        const SizedBox(height: 24),
        // Stats shimmer
        if (isDesktop)
          Row(children: [
            Expanded(child: _Shimmer(width: double.infinity, height: 110, radius: 16)),
            const SizedBox(width: 16),
            Expanded(child: _Shimmer(width: double.infinity, height: 110, radius: 16)),
            const SizedBox(width: 16),
            Expanded(child: _Shimmer(width: double.infinity, height: 110, radius: 16)),
            const SizedBox(width: 16),
            Expanded(child: _Shimmer(width: double.infinity, height: 110, radius: 16)),
          ])
        else
          Column(children: [
            Row(children: [Expanded(child: _Shimmer(width: double.infinity, height: 100, radius: 16)), const SizedBox(width: 12), Expanded(child: _Shimmer(width: double.infinity, height: 100, radius: 16))]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: _Shimmer(width: double.infinity, height: 100, radius: 16)), const SizedBox(width: 12), Expanded(child: _Shimmer(width: double.infinity, height: 100, radius: 16))]),
          ]),
        const SizedBox(height: 32),
        _Shimmer(width: 150, height: 20, radius: 6),
        const SizedBox(height: 16),
        ...List.generate(4, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _Shimmer(width: double.infinity, height: 74, radius: 16),
        )),
      ]),
    );
  }

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ======= ANIMATED STAT CARD (count-up number) =======
class _AnimatedStatCard extends StatelessWidget {
  final String label;
  final int targetValue;
  final IconData icon;
  final Color color;
  final bool highlight;
  final bool format;
  final double progress; // 0.0 → 1.0

  const _AnimatedStatCard({
    required this.label,
    required this.targetValue,
    required this.icon,
    required this.color,
    this.highlight = false,
    this.format = false,
    required this.progress,
  });

  String _fmtNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    // Animate counter with easeOutCubic
    final easedProgress = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final currentValue = (targetValue * easedProgress).round();
    final displayValue = format ? _fmtNum(currentValue) : '$currentValue';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? color.withOpacity(0.2) : const Color(0xFFF0F0F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Animated icon with scale
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, val, child) => Transform.scale(scale: val, child: child),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19),
          ),
        ),
        const SizedBox(height: 14),
        Text(displayValue, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ======= SHIMMER LOADING =======
class _Shimmer extends StatelessWidget {
  final double width, height, radius;
  const _Shimmer({required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.04, end: 0.09),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, val, __) => Container(
        width: width, height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: Colors.black.withOpacity(val),
        ),
      ),
    );
  }
}