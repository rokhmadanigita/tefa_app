import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/orders.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _showBanner = true;
  List<String> _dismissedIds = [];
  String _userRole = 'user';
  bool _isInitializing = true;

  // Stream untuk mendapatkan data real-time dari tabel orders
  Stream<List<Map<String, dynamic>>>? _notificationStream;

  @override
  void initState() {
    super.initState();
    _initNotificationState();
  }

  Future<void> _initNotificationState() async {
    await _loadDismissedNotifications();
    await _setupStream();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _setupStream() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 1. Ambil Role User secara akurat
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      
      _userRole = (profile?['role'] ?? 'user').toString().toLowerCase().trim();
    } catch (e) {
      _userRole = 'user';
    }

    // 2. Setup Stream berdasarkan Role
    if (_userRole == 'admin') {
      _notificationStream = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(30);
    } else {
      _notificationStream = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);
    }
  }

  Future<void> _loadDismissedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dismissedIds = prefs.getStringList('dismissed_notifications') ?? [];
      });
    }
  }

  Future<void> _dismissNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _dismissedIds.add(id);
    });
    await prefs.setStringList('dismissed_notifications', _dismissedIds);
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return "-";
    try {
      DateTime date = DateTime.parse(dateStr).toLocal();
      Duration diff = DateTime.now().difference(date);
      
      if (diff.inSeconds < 60) return "Baru saja";
      if (diff.inMinutes < 60) return "${diff.inMinutes} mnt lalu";
      if (diff.inHours < 24) return "${diff.inHours} jam lalu";
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return "-";
    }
  }

  Map<String, dynamic> _getStatusDetails(String status) {
    String s = status.toLowerCase().trim();
    if (s == 'pending') {
      return {"title": "Menunggu Pembayaran", "desc": "Pesanan Anda menunggu untuk dibayar.", "icon": Icons.payment, "color": Colors.orange};
    } else if (s == 'packing' || s == 'dikemas') {
      return {"title": "Sedang Dikemas", "desc": "Pesanan sedang dipersiapkan oleh toko.", "icon": Icons.inventory_2, "color": Colors.blue};
    } else if (s == 'shipped' || s == 'dikirim') {
      return {"title": "Dalam Pengiriman", "desc": "Kurir sedang mengantar pesanan ke alamat Anda.", "icon": Icons.local_shipping, "color": Colors.purple};
    } else if (s == 'delivered' || s == 'diterima') {
      return {"title": "Sudah Sampai", "desc": "Pesanan telah tiba di lokasi tujuan.", "icon": Icons.check_circle, "color": Colors.green};
    } else if (s == 'completed' || s == 'selesai') {
      return {"title": "Pesanan Selesai", "desc": "Terima kasih! Jangan lupa beri ulasan terbaik.", "icon": Icons.star, "color": Colors.teal};
    } else if (s == 'canceled' || s == 'dibatalkan') {
      return {"title": "Pesanan Dibatalkan", "desc": "Pesanan telah dibatalkan.", "icon": Icons.cancel, "color": Colors.red};
    } else {
      return {"title": "Update Pesanan", "desc": "Ada pembaruan status pada pesanan.", "icon": Icons.notifications, "color": Colors.grey};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23447D),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          _userRole == 'admin' ? "Notifikasi Admin" : "Notifikasi Saya",
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_dismissedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('dismissed_notifications');
                setState(() => _dismissedIds = []);
              },
            )
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
        stream: _notificationStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Perbaikan error stream dengan refresh otomatis
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initNotificationState();
            });
            return const Center(child: Text("Menghubungkan ulang..."));
          }

          final allData = snapshot.data ?? [];
          final notifications = allData.where((o) => !_dismissedIds.contains(o['id'].toString())).toList();

          return Column(
            children: [
              if (_showBanner) _buildPermissionBanner(),
              Expanded(
                child: notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 100),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final order = notifications[index];
                          final String orderId = order['id'].toString();
                          final details = _getStatusDetails(order['status'] ?? '');
                          
                          String displayName = "Pelanggan";
                          if (order['name'] != null && order['name'].toString().trim().isNotEmpty) {
                            displayName = order['name'].toString();
                          } else if (order['email'] != null && order['email'].toString().trim().isNotEmpty) {
                            displayName = order['email'].toString();
                          }

                          return Dismissible(
                            key: Key(orderId),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) => _dismissNotification(orderId),
                            child: _buildNotificationItem(
                              title: details['title'],
                              desc: details['desc'],
                              icon: details['icon'],
                              color: details['color'],
                              time: _formatTime(order['created_at']),
                              orderId: orderId,
                              customerName: displayName,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF23447D).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF23447D).withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF23447D),
            radius: 18,
            child: Icon(Icons.notifications_active, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Notifikasi Aktif", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF23447D))),
                const SizedBox(height: 4),
                const Text("Semua update pesanan Anda akan muncul otomatis di sini.", style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => setState(() => _showBanner = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23447D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Tutup", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required String time,
    required String orderId,
    required String customerName,
  }) {
    return FutureBuilder<List<dynamic>>(
      future: Supabase.instance.client.from('order_items').select('product_title').eq('order_id', orderId).limit(1),
      builder: (context, snapshot) {
        String productInfo = "";
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
          productInfo = "[${snapshot.data![0]['product_title']}] ";
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
              Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Oleh: $customerName", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  "$productInfo$desc", 
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersPage(statusKey: 'all')));
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Belum ada notifikasi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}
