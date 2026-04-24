import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../pages/detail.dart';
import '../pages/home.dart';
import 'product_data.dart';

class OrdersPage extends StatefulWidget {
  final String statusKey;
  final bool onlyUnreviewed;

  const OrdersPage({super.key, required this.statusKey, this.onlyUnreviewed = false});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _checkRoleAndFetchOrders();
  }

  Future<void> _checkRoleAndFetchOrders() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _userRole = (response?['role'] ?? 'user').toString().toLowerCase().trim();
        });
        debugPrint("SISTEM: LOGIN ROLE ADALAH -> $_userRole");
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      var request = Supabase.instance.client.from('orders').select();

      if (_userRole == 'admin') {
        debugPrint("SISTEM: Admin terdeteksi, menampilkan SEMUA pesanan pelanggan.");
      } else {
        debugPrint("SISTEM: User terdeteksi, hanya menampilkan pesanan sendiri.");
        request = request.eq('user_id', user.id);
      }

      if (widget.onlyUnreviewed) {
        request = request.or('status.eq.completed,status.eq.selesai');
      } else if (widget.statusKey != 'all') {
        if (widget.statusKey == 'packing') {
          request = request.or('status.eq.packing,status.eq.dikemas');
        } else if (widget.statusKey == 'shipped') {
          request = request.or('status.eq.shipped,status.eq.dikirim');
        } else if (widget.statusKey == 'delivered') {
          request = request.or('status.eq.delivered,status.eq.diterima,status.eq.completed,status.eq.selesai');
        } else {
          request = request.eq('status', widget.statusKey);
        }
      }

      final ordersResponse = await request.order('created_at', ascending: false);
      final List ordersList = ordersResponse as List;

      if (ordersList.isEmpty) {
        if (mounted) setState(() { _orders = []; _isLoading = false; });
        return;
      }

      final List<String> orderIds = ordersList.map((o) => o['id'].toString()).toList();
      final itemsResponse = await Supabase.instance.client
          .from('order_items')
          .select()
          .filter('order_id', 'in', orderIds);
      
      final List allItems = itemsResponse as List;

      final List combinedOrders = ordersList.map((order) {
        final Map<String, dynamic> orderData = Map<String, dynamic>.from(order);
        final String oid = orderData['id'].toString();
        final List items = allItems.where((item) => item['order_id'].toString() == oid).toList();
        orderData['order_items'] = items;
        return orderData;
      }).toList();

      if (widget.onlyUnreviewed) {
        combinedOrders.removeWhere((o) => o['is_reviewed'] == true);
      }

      if (mounted) {
        setState(() {
          _orders = combinedOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetching Orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await Supabase.instance.client.from('orders').update({'status': newStatus}).eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status berhasil diubah")));
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengubah status")));
    }
  }

  Future<void> _navigateToProductDetail(String productId, String orderId) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final response = await Supabase.instance.client.from('products').select().eq('id', productId).single();
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(product: Product.fromJson(response), orderId: orderId))).then((_) => _fetchOrders());
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  String _getStatusLabel(String rawStatus) {
    String s = rawStatus.toLowerCase().trim();
    if (s == 'pending') return 'Belum Bayar';
    if (s == 'packing' || s == 'dikemas') return 'Dikemas';
    if (s == 'shipped' || s == 'dikirim') return 'Dikirim';
    if (s == 'delivered' || s == 'diterima') return 'Diterima';
    if (s == 'completed' || s == 'selesai') return 'Selesai';
    if (s == 'canceled' || s == 'dibatalkan') return 'Dibatalkan';
    return rawStatus;
  }

  Color _getStatusColor(String rawStatus) {
    String s = rawStatus.toLowerCase().trim();
    if (s == 'pending') return Colors.orange;
    if (s == 'packing' || s == 'dikemas') return Colors.blue;
    if (s == 'shipped' || s == 'dikirim') return Colors.purple;
    if (s == 'delivered' || s == 'diterima') return Colors.green;
    if (s == 'completed' || s == 'selesai') return Colors.teal;
    if (s == 'canceled' || s == 'dibatalkan') return Colors.red;
    return Colors.grey;
  }

  String formatTitik(int number) {
    String str = number.toString();
    String result = "";
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result = str[i] + result;
      count++;
      if (count % 3 == 0 && i != 0) result = ".$result";
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23447D),
        elevation: 0,
        centerTitle: true,
        title: Text(_userRole == 'admin' ? "Admin: Semua Pesanan" : "Pesanan Saya", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final Map<String, dynamic> order = _orders[index];
                      final List items = (order['order_items'] as List?) ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat('dd MMM yyyy').format(DateTime.parse(order['created_at'])), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: _getStatusColor(order['status']).withAlpha(25), borderRadius: BorderRadius.circular(8)),
                                  child: Text(_getStatusLabel(order['status']), style: TextStyle(color: _getStatusColor(order['status']), fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ...items.map((item) {
                              return ListTile(
                                onTap: () => _navigateToProductDetail(item['product_id'].toString(), order['id'].toString()),
                                contentPadding: EdgeInsets.zero,
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item['product_image'] ?? '',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                title: Text(item['product_title'] ?? 'Produk', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text("${item['quantity']} x Rp ${formatTitik(item['product_price'] ?? 0)}"),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                              );
                            }),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Total: Rp ${formatTitik(order['total'])}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF23447D))),
                                _buildActionButtons(order),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 16), const Text("Belum ada pesanan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 24), ElevatedButton(onPressed: () { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomePage()), (route) => false); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF23447D), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: const Text("Pesan Sekarang"))]));
  }

  Widget _buildActionButtons(Map<String, dynamic> order) {
    String status = order['status'].toString().toLowerCase().trim();
    String id = order['id'].toString();
    bool isReviewed = order['is_reviewed'] ?? false;
    final List items = (order['order_items'] as List?) ?? [];
    if (_userRole == 'admin') {
      if (status == 'pending') return _adminBtn("Proses", Colors.blue, () => _updateOrderStatus(id, 'packing'));
      if (status == 'packing' || status == 'dikemas') return _adminBtn("Kirim", Colors.purple, () => _updateOrderStatus(id, 'shipped'));
      if (status == 'shipped' || status == 'dikirim') return _adminBtn("Sampai", Colors.green, () => _updateOrderStatus(id, 'delivered'));
      return const SizedBox();
    }
    if (status == 'pending') return _adminBtn("Batalkan", Colors.red, () => _updateOrderStatus(id, 'canceled'));
    if (status == 'delivered' || status == 'diterima') return _adminBtn("Terima Pesanan", Colors.teal, () => _updateOrderStatus(id, 'completed'));
    if ((status == 'completed' || status == 'selesai') && !isReviewed && items.isNotEmpty) {
      return _adminBtn("Beri Penilaian", Colors.orange, () {
        _navigateToProductDetail(items[0]['product_id'].toString(), id);
      });
    }
    return const SizedBox();
  }

  Widget _adminBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text(label, style: const TextStyle(fontSize: 11)));
  }
}
