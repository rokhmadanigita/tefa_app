import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/cart_service.dart';
import '../data/product_data.dart';
import '../data/map_picker.dart';
import 'home.dart';
import 'login.dart';
import 'checkout_success.dart';

class CheckoutPage extends StatefulWidget {
  final Product? directProduct;
  final int? quantity;

  const CheckoutPage({super.key, this.directProduct, this.quantity});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final CartService _cartService = CartService();
  List<Product> _displayItems = [];
  Map<String, int> _quantities = {};
  
  String _userEmail = "";
  String _userName = "";
  String _userAddress = "Pilih alamat pengiriman";
  double? _latitude;
  double? _longitude;
  
  String _selectedPayment = "Bayar di tempat";
  final int _shippingFee = 0;
  final int _protectionFee = 1000;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  Future<void> _checkAuthAndLoadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLoginRequiredDialog();
      });
      return;
    }
    await _loadData();
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Login Diperlukan", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Anda harus login terlebih dahulu untuk melakukan checkout."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Login Sekarang"),
          ),
        ],
      ),
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadUserData();
    _prepareOrderItems();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _userEmail = user.email ?? "";
        final response = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            _userName = response['name'] ?? "";
            _userAddress = (response['address'] != null && response['address'].toString().isNotEmpty) 
                ? response['address'] 
                : "Pilih alamat pengiriman";
            _latitude = response['latitude'];
            _longitude = response['longitude'];
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
    }
  }

  void _prepareOrderItems() {
    if (widget.directProduct != null) {
      _displayItems = [widget.directProduct!];
      _quantities[widget.directProduct!.id] = widget.quantity ?? 1;
    } else {
      final cartItems = _cartService.items.value;
      _quantities = {};
      List<Product> uniqueItems = [];
      
      for (var product in cartItems) {
        if (_quantities.containsKey(product.id)) {
          _quantities[product.id] = _quantities[product.id]! + 1;
        } else {
          _quantities[product.id] = 1;
          uniqueItems.add(product);
        }
      }
      _displayItems = uniqueItems;
    }
  }

  int get _totalPrice {
    int subtotal = 0;
    for (var product in _displayItems) {
      subtotal += (product.price * (_quantities[product.id] ?? 1));
    }
    return subtotal + _shippingFee + _protectionFee;
  }

  String formatTitikLocal(int number) {
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

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _userAddress = result['address'] ?? _userAddress;
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client.from('profiles').upsert({
            'user_id': user.id,
            'address': _userAddress,
            'latitude': _latitude,
            'longitude': _longitude,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
        }
      } catch (e) {
        debugPrint("Error sync profile address: $e");
      }
    }
  }

  Future<void> _createOrder() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      _showLoginRequiredDialog();
      return;
    }

    if (_userAddress == 'Pilih alamat pengiriman' || _userAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih alamat pengiriman terlebih dahulu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
      final user = Supabase.instance.client.auth.currentUser;

      int subtotal = 0;
      for (var product in _displayItems) {
        subtotal += (product.price * (_quantities[product.id] ?? 1));
      }

      final orderData = {
        'user_id': user?.id,
        'email': _userEmail,
        'name': _userName,
        'address': _userAddress,
        'latitude': _latitude,
        'longitude': _longitude,
        'payment_method': _selectedPayment,
        'subtotal': subtotal,
        'protection_fee': _protectionFee,
        'shipping_fee': _shippingFee,
        'total': _totalPrice,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      final orderResponse = await Supabase.instance.client.from('orders').insert(orderData).select().single();
      final orderId = orderResponse['id'];

      for (var product in _displayItems) {
        await Supabase.instance.client.from('order_items').insert({
          'order_id': orderId,
          'product_id': product.id,
          'product_title': product.title,
          'product_price': product.price,
          'product_image': product.image,
          'quantity': _quantities[product.id],
        });
      }

      if (widget.directProduct == null) _cartService.clear();
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CheckoutSuccessPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat pesanan: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A8A),
          title: const Text("Checkout", style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAddressSection(),
            const SizedBox(height: 16),
            if (_displayItems.isEmpty)
              _buildSectionCard(child: const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Keranjang kosong', style: TextStyle(color: Colors.grey)))))
            else
              ..._displayItems.map((product) => _buildProductCard(product)),
            const SizedBox(height: 16),
            _buildShippingSection(),
            const SizedBox(height: 20),
            const Text("Metode pembayaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildPaymentOption("Bayar di tempat", Icons.payments_outlined),
            _buildPaymentOption("OVO", Icons.account_balance_wallet_outlined),
            _buildPaymentOption("DANA", Icons.wallet_outlined),
            _buildPaymentOption("QRIS", Icons.qr_code_scanner),
            _buildPaymentOption("Gopay", Icons.account_balance_outlined),
            const SizedBox(height: 20),
            _buildSummarySection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(child: _buildBottomBar(context)),
    );
  }

  Widget _buildAddressSection() {
    bool hasAddress = _userAddress != "Pilih alamat pengiriman" && _userAddress.isNotEmpty;
    return _buildSectionCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: hasAddress ? const Color(0xFF1E3A8A) : Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_userEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (_userName.isNotEmpty) Text(_userName, style: const TextStyle(color: Colors.black87, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _userAddress, 
                      style: TextStyle(
                        color: hasAddress ? Colors.black54 : Colors.red, 
                        fontSize: 12, 
                        height: 1.4,
                        fontWeight: hasAddress ? FontWeight.normal : FontWeight.bold,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map, size: 18),
              label: Text(hasAddress ? 'Ubah Alamat' : 'Pilih Alamat Sekarang'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                foregroundColor: hasAddress ? const Color(0xFF1E3A8A) : Colors.red,
                side: BorderSide(color: hasAddress ? const Color(0xFF1E3A8A) : Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    int qty = _quantities[product.id] ?? 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: _buildSectionCard(
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(product.image, width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(width: 80, height: 80, color: Colors.grey[300], child: const Icon(Icons.image_not_supported))),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(product.category, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Rp ${formatTitikLocal(product.price)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text("x$qty", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingSection() {
    return _buildSectionCard(
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Pengiriman standar", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          const Text("Gratis ongkir", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    int subtotal = 0;
    for (var product in _displayItems) {
      subtotal += (product.price * (_quantities[product.id] ?? 1));
    }
    return _buildSectionCard(
      child: Column(
        children: [
          const Text("Ringkasan Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(height: 20),
          _buildPriceRow('Subtotal', subtotal),
          _buildPriceRow('Proteksi', _protectionFee),
          _buildPriceRow('Ongkir', _shippingFee, isDiscount: true),
          const Divider(height: 20),
          _buildPriceRow('Total', _totalPrice, isBold: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int price, {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(isDiscount && price == 0 ? "Gratis" : "Rp ${formatTitikLocal(price)}",
            style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isDiscount && price == 0 ? Colors.teal : null)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildPaymentOption(String name, IconData icon) {
    bool isSelected = _selectedPayment == name;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFFF1F5F9) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey[200]!, width: isSelected ? 2 : 1)),
        child: ListTile(
          leading: Icon(icon, color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey),
          title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFF1E3A8A)) : null,
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      decoration: const BoxDecoration(color: Color(0xFF1E3A8A), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Total Tagihan", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("Rp ${formatTitikLocal(_totalPrice)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          ElevatedButton(
            onPressed: _createOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text("Bayar Sekarang", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
