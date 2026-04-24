import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tefa_app/pages/detail.dart';
import 'package:tefa_app/pages/detail_jasa.dart';
import '../data/cart_service.dart';
import '../data/product_data.dart';
import '../data/jasa_data.dart' hide formatTitik;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;

  Future<void> _performSearch(String query) async {
    final cleanedQuery = query.trim().toLowerCase();

    if (cleanedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final productResponse = await Supabase.instance.client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      final jasaResponse = await Supabase.instance.client
          .from('services')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> allProducts = productResponse as List;
      final List<dynamic> allJasa = jasaResponse as List;

      final queryWords = cleanedQuery.split(' ').where((w) => w.isNotEmpty).toList();

      final productResults = allProducts.where((p) {
        final text = "${p['title']} ${p['category']}".toLowerCase();
        return queryWords.every((word) => text.contains(word));
      }).map((p) => Map<String, dynamic>.from({...p, 'search_type': 'product'})).toList();

      final jasaResults = allJasa.where((j) {
        final text = "${j['title']} ${j['category']}".toLowerCase();
        return queryWords.every((word) => text.contains(word));
      }).map((j) => Map<String, dynamic>.from({...j, 'search_type': 'jasa'})).toList();

      if (mounted) {
        setState(() {
          _isSearching = true;
          _isLoading = false;
          _searchResults = [...productResults, ...jasaResults];
          _searchResults.sort((a, b) => (a['title'] ?? '').toString().compareTo(b['title'] ?? ''));
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23447D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Cari Produk & Jasa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : !_isSearching ? _buildInitialState() : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF23447D),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: _performSearch,
        decoration: InputDecoration(
          hintText: 'Cari produk atau jasa...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
            _searchController.clear();
            _performSearch('');
          })
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return FutureBuilder(
      future: Supabase.instance.client.from('products').select().limit(6),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final products = (snapshot.data as List).map((j) => Product.fromJson(j)).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Rekomendasi Produk", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF23447D))),
              const SizedBox(height: 15),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) => ProductCard(
                  product: products[index],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(product: products[index]))),
                  onAddToCart: () {
                    CartService().add(products[index]);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("'${products[index].title}' ditambahkan ke keranjang.")),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('Tidak ditemukan hasil untuk "${_searchController.text}"', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    final products = _searchResults.where((item) => item['search_type'] == 'product').map((e) => Product.fromJson(e)).toList();
    final jasaItems = _searchResults.where((item) => item['search_type'] == 'jasa').map((e) => Jasa.fromJson(e)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (products.isNotEmpty) ...[
            const Text("Produk", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF23447D))),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) => ProductCard(
                product: products[index],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(product: products[index]))),
                onAddToCart: () {
                  CartService().add(products[index]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("'${products[index].title}' ditambahkan ke keranjang.")),
                  );
                },
              ),
            ),
            const SizedBox(height: 25),
          ],
          if (jasaItems.isNotEmpty) ...[
            const Text("Layanan Jasa", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF23447D))),
            const SizedBox(height: 15),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jasaItems.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: JasaCard(
                  jasa: jasaItems[index],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailJasaPage(jasa: jasaItems[index]))),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
