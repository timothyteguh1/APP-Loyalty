import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upsol_loyalty/features/history/history_page.dart';
import 'package:upsol_loyalty/features/reward/reward_page.dart';
import '../../controllers/auth_controller.dart';
import '../account/account_page.dart';
import '../reward/detail_reward_page.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/layout_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authController = AuthController();
  final _supabase = Supabase.instance.client;

  int _selectedIndex = 0;
  int _currentBannerIndex = 0;
  late PageController _pageController;
  Timer? _timer;
  List<Map<String, dynamic>> _banners = [];
  List<Map<String, dynamic>> _bestDeals = [];
  bool _isLoadingBanner = true;
  bool _isLoadingDeals = true;

  Stream<List<Map<String, dynamic>>>? _pointsStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _initStreams();
    _fetchBanners();
    _fetchBestDeals();
  }

  void _initStreams() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      _pointsStream = _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', userId);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    try {
      final data = await _supabase.from('banners').select().eq('is_active', true).order('created_at', ascending: false);
      if (mounted) {
        setState(() { _banners = List<Map<String, dynamic>>.from(data); _isLoadingBanner = false; });
        _startAutoSlide();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBanner = false);
    }
  }

  // [REVISI] Best deals sekarang query dari is_best_deal = true
  Future<void> _fetchBestDeals() async {
    try {
      final data = await _supabase.from('rewards').select()
          .eq('is_active', true)
          .eq('is_best_deal', true)
          .gt('stock', 0)
          .order('points_required', ascending: true)
          .limit(3);
      if (mounted) {
        setState(() { _bestDeals = List<Map<String, dynamic>>.from(data); _isLoadingDeals = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDeals = false);
    }
  }

  void _startAutoSlide() {
    if (_banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_currentBannerIndex < _banners.length - 1) { _currentBannerIndex++; } else { _currentBannerIndex = 0; }
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentBannerIndex, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  Widget _buildBody(bool isDesktop) {
    switch (_selectedIndex) {
      case 0: return _buildHomeContent(isDesktop);
      case 1: return const RewardPage();
      case 2: return const HistoryPage();
      case 3: return const AccountPage();
      default: return const Center(child: Text("Fitur dalam pengembangan"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LayoutState().isDesktopMode,
      builder: (context, isDesktop, child) {
        if (isDesktop) { return _buildDesktopLayout(); } else { return _buildMobileLayout(); }
      },
    );
  }

  // ===== MOBILE LAYOUT =====
  // [REVISI] Hapus FAB scan QR, reorder nav items
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: false,
      body: _buildBody(false),
      bottomNavigationBar: BottomAppBar(
        height: 70, color: Colors.white, surfaceTintColor: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItemMobile(icon: Icons.home_filled, label: "Home", index: 0),
            _buildNavItemMobile(icon: Icons.card_giftcard, label: "Reward", index: 1),
            _buildNavItemMobile(icon: Icons.history_outlined, label: "History", index: 2),
            _buildNavItemMobile(icon: Icons.person_outline, label: "Account", index: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItemMobile({required IconData icon, required String label, required int index}) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey),
        Text(label, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ]),
    );
  }

  // ===== DESKTOP LAYOUT =====
  // [REVISI] Hapus scan QR button dari sidebar
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(children: [
        Container(
          width: 250, color: Colors.white,
          child: Column(children: [
            const SizedBox(height: 40),
            Image.asset('assets/images/logo.png', height: 60, errorBuilder: (c, e, s) => const Icon(Icons.star, size: 60, color: Color(0xFFD32F2F))),
            const SizedBox(height: 40),
            _buildNavItemWeb(icon: Icons.home_filled, label: "Dashboard", index: 0),
            _buildNavItemWeb(icon: Icons.card_giftcard, label: "Katalog Reward", index: 1),
            _buildNavItemWeb(icon: Icons.history_outlined, label: "Riwayat Transaksi", index: 2),
            _buildNavItemWeb(icon: Icons.person_outline, label: "Pengaturan Akun", index: 3),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: OutlinedButton.icon(
                onPressed: () => LayoutState().toggleMode(),
                icon: const Icon(Icons.phone_android),
                label: const Text("Beralih ke Mode HP"),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45), foregroundColor: Colors.grey[700], side: BorderSide(color: Colors.grey[300]!)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
        Expanded(child: _buildBody(true)),
      ]),
    );
  }

  Widget _buildNavItemWeb({required IconData icon, required String label, required int index}) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD32F2F).withOpacity(0.1) : Colors.transparent,
          border: Border(right: BorderSide(color: isSelected ? const Color(0xFFD32F2F) : Colors.transparent, width: 4)),
        ),
        child: Row(children: [
          Icon(icon, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 14, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
        ]),
      ),
    );
  }

  // ===== HOME CONTENT =====
  Widget _buildHomeContent(bool isDesktop) {
    final Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 220, width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Builder(builder: (context) {
                    final user = _supabase.auth.currentUser;
                    final name = user?.userMetadata?['full_name'] ?? 'User Upsol';
                    return Text("Selamat datang, $name", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500));
                  }),
                  if (!LayoutState().isDesktopMode.value)
                    InkWell(
                      onTap: () => LayoutState().toggleMode(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Row(children: [Icon(Icons.computer, color: Colors.white, size: 16), SizedBox(width: 6), Text("Mode Web", style: TextStyle(color: Colors.white, fontSize: 12))]),
                      ),
                    ),
                ]),
              ]),
            ),
            Positioned(
              top: 100, left: 24, right: 24,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(children: [
                  Builder(builder: (context) {
                    final user = _supabase.auth.currentUser;
                    final name = user?.userMetadata?['full_name'] ?? 'User Upsol';
                    final email = user?.email ?? '-';
                    final String? avatarUrl = user?.userMetadata?['avatar_url'];
                    final bool hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
                    return Row(children: [
                      CircleAvatar(
                        radius: 24, backgroundColor: Colors.grey[200],
                        backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                        child: !hasAvatar ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFD32F2F))) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis),
                      ])),
                      Image.asset('assets/images/logo.png', height: 30, errorBuilder: (c, e, s) => const Icon(Icons.star, color: Colors.amber)),
                    ]);
                  }),
                  const SizedBox(height: 16), const Divider(), const SizedBox(height: 12),
                  // [REVISI] Hanya tampilkan poin, tanpa tombol Redeem
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Poin anda saat ini", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      _pointsStream != null
                          ? StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _pointsStream,
                              builder: (context, snapshot) {
                                String points = "0";
                                try { if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) { points = (snapshot.data![0]['points'] ?? 0).toString(); } } catch (_) {}
                                return Text("$points Points", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black));
                              },
                            )
                          : const Text("0 Points", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                    ]),
                  ]),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 110),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Penawaran Menarik", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _isLoadingBanner
                ? AspectRatio(aspectRatio: 16 / 9, child: Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())))
                : _banners.isEmpty
                    ? Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)), child: const Center(child: Text("Belum ada promo")))
                    : Column(children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: PageView.builder(
                            controller: _pageController, onPageChanged: (index) => setState(() => _currentBannerIndex = index), itemCount: _banners.length,
                            itemBuilder: (context, index) => ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(_banners[index]['image_url'] ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image))))),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_banners.length, (index) => AnimatedContainer(duration: const Duration(milliseconds: 300), margin: const EdgeInsets.symmetric(horizontal: 4), width: _currentBannerIndex == index ? 24 : 8, height: 8, decoration: BoxDecoration(color: _currentBannerIndex == index ? const Color(0xFFD32F2F) : Colors.grey[300], borderRadius: BorderRadius.circular(4))))),
                      ]),
            const SizedBox(height: 30),
            const Text("Best Deal", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _isLoadingDeals
                ? Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F))))
                : _bestDeals.isEmpty
                    ? Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: const Text("Nantikan promo menarik segera!", style: TextStyle(color: Colors.grey)))
                    : Column(children: _bestDeals.map((item) => _buildBestDealCard(item)).toList()),
            const SizedBox(height: 100),
          ]),
        ),
      ],
    );

    return SingleChildScrollView(
      child: isDesktop
          ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: mainContent))
          : mainContent,
    );
  }

  // [REVISI] Best deal card — tampilkan NAMA (title), bukan deskripsi
  Widget _buildBestDealCard(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => navigateTo(context, DetailRewardPage(item: item)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Image.asset('assets/images/logo.png', height: 20, errorBuilder: (c, e, s) => const Icon(Icons.local_offer, color: Colors.red, size: 20)),
            const SizedBox(width: 8),
            const Text("UPSOL OFFICIAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: item['type'] == 'VOUCHER' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(item['type'] == 'VOUCHER' ? 'Voucher' : 'Produk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: item['type'] == 'VOUCHER' ? Colors.blue : Colors.green)),
            ),
          ]),
          const SizedBox(height: 12),
          // [REVISI] Tampilkan NAMA, bukan deskripsi
          Text(item['name'] ?? '-', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item['description'], style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16), const Divider(height: 1), const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.amber[50], shape: BoxShape.circle), child: const Icon(Icons.stars, color: Colors.amber, size: 18)),
              const SizedBox(width: 8),
              Text("${item['points_required'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ]),
            ElevatedButton(
              onPressed: () => navigateTo(context, DetailRewardPage(item: item)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), elevation: 0),
              child: const Text("Klaim", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ),
    );
  }
}