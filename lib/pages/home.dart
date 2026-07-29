import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tefa_app/pages/chat.dart';
import 'package:tefa_app/pages/profile.dart';
import 'package:tefa_app/pages/search.dart';
import 'cart.dart';
import '../data/cart_service.dart';
import 'detail.dart';
import 'detail_jasa.dart';
import 'notifikasi.dart';
import '../data/product_data.dart';
import '../data/jasa_data.dart';

class HomePage extends StatefulWidget {
  final int? initialCategory;

  const HomePage({super.key, this.initialCategory});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<String> _categories = ["Rekomendasi", "RPL", "TKI", "TEI", "TKR", "TAV"];
  int _activeCategory = 0;

  String? _profilePhotoUrl;
  bool _isLoadingPhoto = true;
  bool _showNavbar = true;

  final Map<int, String> _categoryBanners = {
    0: 'assets/banner/rec.jpg',
    1: 'assets/banner/rpl.png',
    2: 'assets/banner/tki.jpg',
    3: 'assets/banner/tei.jpg',
    4: 'assets/banner/tkr.jpg',
    5: 'assets/banner/tav.jpg'
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _activeCategory = widget.initialCategory!;
    }
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('profile_photo_url')
            .eq('user_id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _profilePhotoUrl = response?['profile_photo_url'];
            _isLoadingPhoto = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPhoto = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _loadProfilePhoto();
    setState(() {});
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  double _getAlignmentX() {
    switch (_selectedIndex) {
      case 0: return -0.75;
      case 1: return -0.25;
      case 2: return 0.25;
      case 3: return 0.75;
      default: return -0.75;
    }
  }

  IconData _getIconForIndex(int index) {
    if (index == 1) return Icons.notifications;
    if (index == 2) return Icons.shopping_cart;
    if (index == 3) return Icons.chat_bubble;
    return Icons.home;
  }

  Widget _buildNavButton(IconData icon, int index) {
    Widget buttonIcon = Icon(icon, color: Colors.white, size: 28);
    
    if (index == 2) {
      buttonIcon = _buildCartBadge(buttonIcon, isSmall: true);
    }

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: _selectedIndex == index ? 0 : 1,
        child: buttonIcon,
      ),
    );
  }

  Widget _buildCartBadge(Widget child, {bool isSmall = false}) {
    return ValueListenableBuilder<List<Product>>(
      valueListenable: CartService().items,
      builder: (context, items, _) {
        if (items.isEmpty) return child;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            child,
            Positioned(
              right: isSmall ? -6 : -8,
              top: isSmall ? -6 : -8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF23447D),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white, 
                    width: 1.5
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Center(
                  child: Text(
                    items.length > 9 ? "9+" : "${items.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWeb = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMainHome(),
          const NotificationPage(),
          const CartPage(),
          ChatPage(
            onToggleNavbar: (show) {
              setState(() => _showNavbar = show);
            },
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: (isWeb || !_showNavbar) ? null : SafeArea(bottom: true, child: _buildBottomNav(screenWidth)),
    );
  }

  Widget _buildBottomNav(double screenWidth) {
    return SizedBox(
      height: 80,
      width: screenWidth,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: -0.75, end: _getAlignmentX()),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return CustomPaint(
                size: Size(screenWidth, 60),
                painter: DynamicNotchPainter(value),
              );
            },
          ),
          Container(
            height: 60,
            width: screenWidth,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavButton(Icons.home, 0),
                _buildNavButton(Icons.notifications, 1),
                _buildNavButton(Icons.shopping_cart, 2),
                _buildNavButton(Icons.chat_bubble, 3),
              ],
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            alignment: Alignment(_getAlignmentX(), -3),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF6DA0B8),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: _selectedIndex == 2
                ? _buildCartBadge(Icon(_getIconForIndex(_selectedIndex), color: Colors.white, size: 26))
                : Icon(
                    _getIconForIndex(_selectedIndex),
                    color: Colors.white,
                    size: 26,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHome() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFF23447D),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBanner(),
                  _buildCategories(),
                  const SizedBox(height: 15),
                  _buildProductSection(),
                  const SizedBox(height: 15),
                  _buildJasaSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF23447D), Color(0xFF6DA0B8)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "TEFA STORE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      ).then((_) => _loadProfilePhoto());
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage: _profilePhotoUrl != null
                          ? NetworkImage(_profilePhotoUrl!)
                          : null,
                      child: _profilePhotoUrl == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // SEARCH
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  readOnly: true,
                  onTap: () async {
                    final selectedCategory = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                    if (selectedCategory != null && selectedCategory is int) {
                      setState(() => _activeCategory = selectedCategory);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: "Cari produk...",
                    hintStyle: TextStyle(color: Colors.grey),
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          _categoryBanners[_activeCategory]!,
          height: 300,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          bool isActive = _activeCategory == index;
          return GestureDetector(
            onTap: () => setState(() => _activeCategory = index),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF6DA0B8) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductSection() {
    return FutureBuilder(
      future: Supabase.instance.client
          .from('products')
          .select()
          .eq('category', _categories[_activeCategory])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return const SizedBox.shrink();
        }

        final rawData = snapshot.data as List;

        final products = rawData
            .map((json) => Product.fromJson(json))
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: buildProductGrid(
            context: context,
            products: products,
            onProductTap: (product) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailPage(product: product),
                ),
              );
            },
            onAddToCart: (product) {
              CartService().add(product);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Produk ditambahkan ke keranjang"),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildJasaSection() {
    var query = Supabase.instance.client.from('services').select();
    
    if (_categories[_activeCategory] == 'RPL') {
      query = query.or('category.eq.RPL,category.eq.Rekomendasi');
    } else {
      query = query.eq('category', _categories[_activeCategory]);
    }

    return FutureBuilder(
      future: query.order('created_at', ascending: false),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return const SizedBox.shrink();
        }

        final rawData = snapshot.data as List;

        final jasaList = rawData
            .map((json) => Jasa.fromJson(json))
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: jasaList.length,
            itemBuilder: (context, index) {
              final jasa = jasaList[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: JasaCard(
                  jasa: jasa,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailJasaPage(jasa: jasa),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class DynamicNotchPainter extends CustomPainter {
  final double alignmentX;
  DynamicNotchPainter(this.alignmentX);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = const Color(0xFF23447D)
      ..style = PaintingStyle.fill;

    Path path = Path();
    double centerX = (size.width / 2) + (alignmentX * (size.width / 2 - 30));
    double notchWidth = 80;

    path.moveTo(0, 0);
    path.lineTo(centerX - notchWidth / 2 - 10, 0);
    path.quadraticBezierTo(centerX - notchWidth / 2, 0,
        centerX - notchWidth / 2 + 5, 8);
    path.arcToPoint(
      Offset(centerX + notchWidth / 2 - 5, 8),
      radius: const Radius.circular(30),
      clockwise: false,
    );
    path.quadraticBezierTo(centerX + notchWidth / 2, 0,
        centerX + notchWidth / 2 + 10, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DynamicNotchPainter oldDelegate) =>
      oldDelegate.alignmentX != alignmentX;
}
