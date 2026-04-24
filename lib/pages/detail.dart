import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/cart_service.dart';
import 'checkout.dart';
import '../data/product_data.dart';

class DetailPage extends StatefulWidget {
  final Product product;
  final String? orderId;

  const DetailPage({super.key, required this.product, this.orderId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  List<Map<String, dynamic>> _reviews = [];
  final TextEditingController _reviewController = TextEditingController();
  int _userRating = 0;
  bool _isFavorite = false;
  bool _isLoadingReviews = true;
  String _userEmail = "user@gmail.com";

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _fetchReviewsFromSupabase();
    _checkIfFavorite();
  }

  Future<void> _loadUserEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() => _userEmail = user.email ?? "user@gmail.com");
    }
  }

  Future<void> _checkIfFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select()
          .eq('user_id', user.id)
          .eq('product_id', widget.product.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isFavorite = response != null;
        });
      }
    } catch (e) {
      debugPrint("Error checking favorite: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Silakan login untuk menyukai produk"))
      );
      return;
    }

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      if (_isFavorite) {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': user.id,
          'product_id': widget.product.id,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('product_id', widget.product.id);
      }
    } catch (e) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      debugPrint("Error toggling favorite: $e");
    }
  }

  Future<void> _fetchReviewsFromSupabase() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('target_id', widget.product.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(response);
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0.0;
    double total = 0;
    for (var review in _reviews) {
      total += review['rating'];
    }
    return total / _reviews.length;
  }

  String formatTitik(int number) {
    String str = number.toString();
    String result = "";
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i != 0) result = "." + result;
    }
    return result;
  }

  Future<void> _submitReview({int? editIndex}) async {
    if (_reviewController.text.isEmpty || _userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Isi rating dan ulasan!")));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

      final reviewData = {
        'user_id': user.id,
        'email': _userEmail,
        'target_id': widget.product.id,
        'rating': _userRating,
        'comment': _reviewController.text,
        'target_type': 'product',
        'created_at': DateTime.now().toIso8601String(),
      };

      if (editIndex != null) {
        await Supabase.instance.client.from('reviews').update(reviewData).eq('id', _reviews[editIndex]['id']);
      } else {
        await Supabase.instance.client.from('reviews').insert(reviewData);
        if (widget.orderId != null) {
          await Supabase.instance.client.from('orders').update({'is_reviewed': true}).eq('id', widget.orderId!);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        _fetchReviewsFromSupabase();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil menyimpan ulasan"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _deleteReview(int index) async {
    try {
      await Supabase.instance.client.from('reviews').delete().eq('id', _reviews[index]['id']);
      _fetchReviewsFromSupabase();
    } catch (e) {
      debugPrint("Error delete: $e");
    }
  }

  void _showReviewDialog({int? index}) {
    if (index != null) {
      _reviewController.text = _reviews[index]['comment'];
      _userRating = _reviews[index]['rating'];
    } else {
      _reviewController.clear();
      _userRating = 0;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Beri Ulasan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                FittedBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => IconButton(
                      icon: Icon(i < _userRating ? Icons.star : Icons.star_border, color: Colors.orange, size: 36),
                      onPressed: () => setDialogState(() => _userRating = i + 1),
                    )),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  decoration: InputDecoration(hintText: "Tulis pengalaman Anda...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text("Batal"))),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(onPressed: () => _submitReview(editIndex: index), child: const Text("Simpan"))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    final String phoneNumber = "6285733458516";
    final String message = "Halo, saya tertarik dengan produk ${widget.product.title}. Apakah masih tersedia?";
    final Uri url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak dapat membuka WhatsApp"))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF23447D),
        title: const Text("Detail Produk", style: TextStyle(color: Colors.white)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(widget.product.image, height: 350, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Rp ${formatTitik(widget.product.price)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF23447D))),
                  const SizedBox(height: 10),
                  Text(widget.product.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  const Text("Deskripsi", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(widget.product.description, style: const TextStyle(color: Colors.black54, height: 1.5)),
                  const SizedBox(height: 15),
                  _buildStatusSection(),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ulasan & Rating", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      TextButton.icon(icon: const Icon(Icons.add_comment_outlined), onPressed: () => _showReviewDialog(), label: const Text("Beri Ulasan")),
                    ],
                  ),
                  const Divider(),
                  _isLoadingReviews ? const Center(child: CircularProgressIndicator()) : _reviews.isEmpty ? const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text("Belum ada ulasan.", style: TextStyle(color: Colors.grey)))) : _buildReviewList(),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(child: _buildBottomBar()),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Colors.blue.shade50))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_reviews.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 20),
                const SizedBox(width: 5),
                Text("${_averageRating.toStringAsFixed(1)} (${_reviews.length} Ulasan)"),
              ],
            )
          else
            const Text("Belum ada penilaian", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : Colors.grey),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        bool isMe = review['user_id'] == currentUser?.id;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(isMe ? "Ulasan Anda" : review['email'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Row(children: List.generate(5, (i) => Icon(Icons.star, size: 14, color: i < review['rating'] ? Colors.orange : Colors.grey[300]))),
              trailing: isMe ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showReviewDialog(index: index)),
                IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deleteReview(index)),
              ]) : null,
            ),
            Text(review['comment'], style: const TextStyle(fontSize: 14)),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF23447D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _launchWhatsApp,
            child: Container(
              width: 65,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF6DA0B8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.chat_outlined, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              CartService().add(widget.product);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Produk ditambahkan ke keranjang"), duration: Duration(seconds: 1)));
            },
            child: Container(
              width: 65,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF6DA0B8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CheckoutPage(directProduct: widget.product)));
              },
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF6DA0B8),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Text(
                  "Checkout",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
