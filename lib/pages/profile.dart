import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import '../data/map_picker.dart';
import '../data/orders.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _userEmail = "";
  String? _profilePhotoUrl;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;

  Map<String, int> _orderCounts = {
    'pending': 0,
    'packing': 0,
    'shipped': 0,
    'delivered': 0,
    'completed': 0,
    'review': 0,
    'all': 0,
  };

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      setState(() => _userEmail = user.email ?? "");

      final profileRes = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes != null && mounted) {
        setState(() {
          _nameController.text = profileRes['name'] ?? '';
          _bioController.text = profileRes['bio'] ?? '';
          _addressController.text = profileRes['address'] ?? '';
          _phoneController.text = profileRes['phone'] ?? '';
          _profilePhotoUrl = profileRes['profile_photo_url'];
          _latitude = profileRes['latitude'];
          _longitude = profileRes['longitude'];
        });
      }

      final response = await Supabase.instance.client
          .from('orders')
          .select('status, is_reviewed')
          .eq('user_id', user.id);

      final List ordersData = response as List;
      int p = 0, pk = 0, s = 0, d = 0, c = 0, r = 0;

      for (var order in ordersData) {
        String status = (order['status'] ?? '').toString().toLowerCase().trim();
        bool isReviewed = order['is_reviewed'] == true;

        switch (status) {
          case 'pending': p++; break;
          case 'packing': pk++; break;
          case 'shipped': s++; break;
          case 'delivered':d++; break;
          case 'completed': c++; break;
        }

        // Hitung untuk menu "Beri penilaian" hanya jika sudah selesai (tekan terima pesanan)
        // dan belum pernah diulas
        if (status == 'completed' && !isReviewed) {
          r++;
        }
      }

      if (mounted) {
        setState(() {
          _orderCounts = {
            'pending': p,
            'packing': pk,
            'shipped': s,
            'delivered': d,
            'completed': c,
            'review': r,
            'all': ordersData.length,
          };
        });
      }

    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        _addressController.text = result['address'] ?? _addressController.text;
        _latitude = result['latitude'];
        _longitude = result['longitude'];
      });

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client.from('profiles').upsert({
            'user_id': user.id,
            'address': _addressController.text,
            'latitude': _latitude,
            'longitude': _longitude,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id');
        }
      } catch (e) {
        debugPrint('Sync Error: $e');
      }
    }
  }

  Future<void> _saveProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client.from('profiles').upsert({
        'user_id': user.id,
        'name': _nameController.text,
        'bio': _bioController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'latitude': _latitude,
        'longitude': _longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil diperbarui!')),
        );
        _refreshData();
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Save Error: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F1F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildBiodataSection(),
              const SizedBox(height: 20),
              _buildOrdersSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 50, bottom: 30),
      decoration: const BoxDecoration(
        color: Color(0xFF23447D),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _showLogoutDialog,
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
            child: _profilePhotoUrl == null
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            _userEmail,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiodataSection() {
    return _buildSectionCard(
      title: "Biodata",
      children: [
        _buildTextField("Nama", _nameController),
        _buildTextField("Bio", _bioController, maxLines: 2),
        _buildTextField("No Handphone", _phoneController),
        _buildTextField("Alamat", _addressController, maxLines: 2),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _latitude != null ? "Lokasi Terpasang" : "Lokasi Belum Diset",
            style: TextStyle(
              fontSize: 13,
              color: _latitude != null ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: TextButton.icon(
            onPressed: _pickLocation,
            icon: const Icon(Icons.map, size: 18),
            label: const Text("Pilih di Peta"),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF23447D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: _saveProfile,
            child: const Text("Simpan Perubahan", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersSection() {
    return _buildSectionCard(
      title: "Status & Pesanan Saya",
      children: [
        _buildStatusItem(Icons.account_balance_wallet, "Belum bayar", "pending"),
        _buildStatusItem(Icons.inventory_2, "Pesanan dikemas", "packing"),
        _buildStatusItem(Icons.local_shipping, "Pesanan dikirim", "shipped"),
        _buildStatusItem(Icons.check_circle, "Pesanan diterima", "delivered"),
        _buildStatusItem(Icons.star, "Beri penilaian", "review"),
        _buildStatusItem(Icons.assignment, "Semua Pesanan", "all"),
      ],
    );
  }

  Widget _buildStatusItem(IconData icon, String label, String statusKey) {
    int count = _orderCounts[statusKey] ?? 0;
    bool isActive = count > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrdersPage(
                statusKey: statusKey == 'review' ? 'completed' : statusKey,
                onlyUnreviewed: statusKey == 'review',
              ),
            ),
          ).then((_) => _refreshData());
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF23447D).withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isActive ? const Color(0xFF23447D) : Colors.grey.shade200,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF23447D), size: 22),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF23447D),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}