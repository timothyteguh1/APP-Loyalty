import 'package:flutter/material.dart';
import 'conversion_page.dart';
import '../manage_rewards/rewards_manage_page.dart';
import '../manage_banners/banners_manage_page.dart';
import 'manual_points_page.dart';

class ManageMenuPage extends StatelessWidget {
  const ManageMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kelola',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pengaturan sistem loyalty',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),

          _MenuItem(
            icon: Icons.sync_alt_rounded,
            color: const Color(0xFF3B82F6),
            title: 'Konversi Poin',
            subtitle: 'Atur rate global & per user',
            delay: 0,
            onTap: () => Navigator.push(
              context,
              _slideRoute(const _ConversionWrapper()),
            ),
          ),
          _MenuItem(
            icon: Icons.card_giftcard_rounded,
            color: const Color(0xFFB71C1C),
            title: 'Kelola Hadiah',
            subtitle: 'Tambah, edit, hapus hadiah',
            delay: 80,
            onTap: () =>
                Navigator.push(context, _slideRoute(const RewardsManagePage())),
          ),
          _MenuItem(
            icon: Icons.image_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Kelola Banner',
            subtitle: 'Promo & banner aplikasi',
            delay: 160,
            onTap: () =>
                Navigator.push(context, _slideRoute(const BannersManagePage())),
          ),
          _MenuItem(
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Manual Poin',
            subtitle: 'Tambah/kurangi poin manual',
            delay: 240,
            onTap: () =>
                Navigator.push(context, _slideRoute(const ManualPointsPage())),
          ),
        ],
      ),
    );
  }

  PageRouteBuilder _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}

// Wrapper supaya ConversionPage punya AppBar + back button
class _ConversionWrapper extends StatelessWidget {
  const _ConversionWrapper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
        ),
        title: const Text(
          'Konversi Poin',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: const ConversionPage(),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int delay;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeOutCubic,
      builder: (_, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - val)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
