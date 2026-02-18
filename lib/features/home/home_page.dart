import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../account/account_page.dart'; 

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
  bool _isLoadingBanner = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchBanners();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Selamat Datang Kembali, $_userName!"),
            backgroundColor: const Color(0xFFD32F2F),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchBanners() async {
    try {
      final data = await _supabase.from('banners').select();
      if (mounted) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(data);
          _isLoadingBanner = false;
        });
        _startAutoSlide();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingBanner = false);
    }
  }

  void _startAutoSlide() {
    if (_banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_currentBannerIndex < _banners.length - 1) {
        _currentBannerIndex++;
      } else {
        _currentBannerIndex = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  String get _userName {
    final user = _authController.currentUser;
    return user?.userMetadata?['full_name'] ?? 'User Upsol'; 
  }

  String get _userEmail => _authController.currentUser?.email ?? '';

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent(); 
      case 4:
        return const AccountPage(); 
      default:
        return const Center(child: Text("Fitur dalam pengembangan"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      
      // [ANTI CRASH] Jaga Layout Stabil
      resizeToAvoidBottomInset: false, 
      extendBody: true, 

      body: _buildBody(),

      floatingActionButton: SizedBox(
        height: 65, width: 65,
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: const Color(0xFFD32F2F),
          shape: const CircleBorder(),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
              Text("Scan", style: TextStyle(color: Colors.white, fontSize: 9))
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0, 
        height: 70, 
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.home_filled, label: "Home", index: 0),
            _buildNavItem(icon: Icons.card_giftcard, label: "Reward", index: 1),
            const SizedBox(width: 48),
            _buildNavItem(icon: Icons.history_outlined, label: "History", index: 3),
            _buildNavItem(icon: Icons.person_outline, label: "Account", index: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey),
          Text(label, style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFFD32F2F) : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 220,
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFD32F2F),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Selamat datang, $_userName",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 100, left: 24, right: 24,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(_userEmail, style: TextStyle(color: Colors.grey[600], fontSize: 12), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Image.asset('assets/images/logo.png', height: 30),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Poin anda saat ini", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 4),
                              const Text("120 Points", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                            child: const Text("Redeem"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 110),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Penawaran Menarik", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _isLoadingBanner
                  ? AspectRatio(aspectRatio: 16 / 9, child: Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())))
                  : _banners.isEmpty
                      ? Container(height: 150, width: double.infinity, color: Colors.grey[200], child: const Center(child: Text("Belum ada promo")))
                      : Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) => setState(() => _currentBannerIndex = index),
                                itemCount: _banners.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Image.network(_banners[index]['image_url'] ?? '', fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image)),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_banners.length, (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentBannerIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(color: _currentBannerIndex == index ? const Color(0xFFD32F2F) : Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                              )),
                            ),
                          ],
                        ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}