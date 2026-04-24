import 'package:flutter/material.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  final String? initialChatId;
  final Function(bool)? onToggleNavbar;

  const ChatPage({super.key, this.initialChatId, this.onToggleNavbar});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Map<String, dynamic>? _selectedChat;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedService;
  String? _customerName;
  String? _customerPhone;
  String? _bookingDate;

  String _conversationState = 'greeting';

  final Map<String, List<Map<String, dynamic>>> _allMessages = {
    "RPL": [], "TKI": [], "TEI": [], "TKR": [], "TAV": [],
  };

  final Map<String, String> _adminWhatsApp = {
    "RPL": "6285733458516",
    "TKI": "6282345678901",
    "TEI": "6285707421889",
    "TKR": "6284567890123",
    "TAV": "6288803577671",
  };

  final List<Map<String, dynamic>> _chatList = [
    {"id": "RPL", "name": "Rekayasa Perangkat Lunak", "image": "assets/chat/rpl.jpeg", "isOnline": true},
    {"id": "TKI", "name": "Teknik Kimia Industri", "image": "assets/chat/tki.jpeg", "isOnline": true},
    {"id": "TEI", "name": "Teknik Elektronika Industri", "image": "assets/chat/tei.jpeg", "isOnline": true},
    {"id": "TKR", "name": "Teknik Kendaraan Ringan", "image": "assets/chat/tkr.jpeg", "isOnline": true},
    {"id": "TAV", "name": "Teknik Audio Video", "image": "assets/chat/tav.jpeg", "isOnline": true},
  ];

  Future<List<dynamic>> _getServicesForChat(String categoryId) async {
    if (categoryId == 'RPL') {
      final response = await Supabase.instance.client
          .from('services')
          .select()
          .or('category.eq.RPL,category.eq.Rekomendasi')
          .order('created_at', ascending: false);
      return response;
    } else {
      final response = await Supabase.instance.client
          .from('services')
          .select()
          .eq('category', categoryId)
          .order('created_at', ascending: false);
      return response;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialChatId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chat = _chatList.firstWhere(
              (c) => c['id'] == widget.initialChatId,
          orElse: () => _chatList[0],
        );
        setState(() {
          _selectedChat = chat;
        });
        if (widget.onToggleNavbar != null) {
          widget.onToggleNavbar!(false);
        }

        Timer(const Duration(milliseconds: 500), () {
          if (mounted) {
            _sendGreeting();
          }
        });
      });
    }
  }

  void _sendGreeting() {
    String id = _selectedChat!['id'];
    setState(() {
      _allMessages[id]!.add({
        "text": "Halo! Terima kasih telah menghubungi kami. Ada yang bisa saya bantu?",
        "isMe": false,
        "time": _getCurrentTime(),
        "hasOptions": true,
        "options": [
          {"text": "📦 Booking / Pesan Jasa", "action": "booking"},
          {"text": "💰 Lihat Harga", "action": "price"},
          {"text": "📋 Info Layanan", "action": "services"},
          {"text": "📞 Kontak Admin", "action": "contact"},
        ]
      });
      _conversationState = 'menu';
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getCurrentTime() {
    DateTime now = DateTime.now();
    String hour = now.hour.toString().padLeft(2, '0');
    String minute = now.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String _getLastMessage(String id) {
    if (_allMessages[id]!.isEmpty) return "Belum ada pesan baru...";
    return _allMessages[id]!.last['text'];
  }

  String _getLastMessageTime(String id) {
    if (_allMessages[id]!.isEmpty) return _getCurrentTime();
    return _allMessages[id]!.last['time'];
  }

  void _handleOptionTap(String action, String displayText) {
    String id = _selectedChat!['id'];

    setState(() {
      _allMessages[id]!.add({
        "text": displayText,
        "isMe": true,
        "time": _getCurrentTime()
      });
    });
    _scrollToBottom();

    _showTypingIndicator(id);

    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _removeTypingIndicator(id);
        _handleAction(action, id);
      }
    });
  }

  void _handleAction(String action, String id) {
    switch (action) {
      case 'booking':
        _startBookingFlow(id);
        break;
      case 'price':
        _showPrices(id);
        break;
      case 'services':
        _showServices(id);
        break;
      case 'contact':
        _launchWhatsApp(id);
        break;
      default:
        _showMainMenu(id);
    }
  }

  Future<void> _launchWhatsApp(String id) async {
    final String phoneNumber = _adminWhatsApp[id] ?? "6285733458516";
    final String message = "Halo Admin ${_selectedChat!['name']}, saya ingin bertanya tentang layanan Anda.";
    final Uri url = Uri.parse("https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak dapat membuka WhatsApp")),
      );
    }
  }

  void _startBookingFlow(String id) async {
    final jasaList = await _getServicesForChat(id);

    if (jasaList.isEmpty) {
      setState(() {
        _allMessages[id]!.add({
          "text": "Mohon maaf, saat ini belum ada layanan untuk kategori ini.",
          "isMe": false,
          "time": _getCurrentTime(),
          "hasOptions": true,
          "options": [
            {"text": "🔙 Kembali ke Menu", "action": "menu"}
          ]
        });
      });
      _scrollToBottom();
      return;
    }

    List<Map<String, String>> serviceOptions = [];

    for (var jasa in jasaList) {
      serviceOptions.add({
        "text": "${jasa['title']}\nRp ${jasa['price']}",
        "action": "select_service:${jasa['id']}"
      });
    }

    serviceOptions.add({"text": "🔙 Kembali", "action": "menu"});

    setState(() {
      _allMessages[id]!.add({
        "text": "Silakan pilih layanan yang Anda inginkan:",
        "isMe": false,
        "time": _getCurrentTime(),
        "hasOptions": true,
        "options": serviceOptions
      });
      _conversationState = 'booking_service';
    });

    _scrollToBottom();
  }

  void _handleServiceSelection(String serviceId, String id) async {
    final response = await Supabase.instance.client
        .from('services')
        .select()
        .eq('id', serviceId)
        .single();

    _selectedService = response['title'];

    setState(() {
      _allMessages[id]!.add({
        "text": "Baik! Anda memilih:\n${response['title']}\n\nSilakan masukkan nama Anda:",
        "isMe": false,
        "time": _getCurrentTime(),
        "needsInput": true,
        "inputType": "name"
      });
      _conversationState = 'booking_name';
    });

    _scrollToBottom();
  }

  void _handleTextInput(String text, String id) {
    setState(() {
      _allMessages[id]!.add({
        "text": text,
        "isMe": true,
        "time": _getCurrentTime()
      });
    });
    _scrollToBottom();

    _showTypingIndicator(id);

    Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _removeTypingIndicator(id);
        _processInput(text, id);
      }
    });
  }

  void _processInput(String text, String id) {
    switch (_conversationState) {
      case 'booking_name':
        _customerName = text;
        setState(() {
          _allMessages[id]!.add({
            "text": "Terima kasih, $text!\n\nSilakan masukkan nomor telepon Anda:",
            "isMe": false,
            "time": _getCurrentTime(),
            "needsInput": true,
            "inputType": "phone"
          });
          _conversationState = 'booking_phone';
        });
        break;

      case 'booking_phone':
        _customerPhone = text;
        setState(() {
          _allMessages[id]!.add({
            "text": "Nomor telepon: $text tersimpan.\n\nPilih tanggal booking:",
            "isMe": false,
            "time": _getCurrentTime(),
            "hasOptions": true,
            "options": [
              {"text": "📅 Hari Ini", "action": "date:today"},
              {"text": "📅 Besok", "action": "date:tomorrow"},
              {"text": "📅 Pilih Tanggal Lain", "action": "date:custom"},
            ]
          });
          _conversationState = 'booking_date';
        });
        break;

      case 'booking_date_custom':
        _bookingDate = text;
        _showBookingConfirmation(id);
        break;
    }
    _scrollToBottom();
  }

  void _handleDateSelection(String dateType, String id) {
    DateTime now = DateTime.now();
    String date;

    switch (dateType) {
      case 'today':
        date = "${now.day}/${now.month}/${now.year}";
        _bookingDate = date;
        _showBookingConfirmation(id);
        break;
      case 'tomorrow':
        DateTime tomorrow = now.add(const Duration(days: 1));
        date = "${tomorrow.day}/${tomorrow.month}/${tomorrow.year}";
        _bookingDate = date;
        _showBookingConfirmation(id);
        break;
      case 'custom':
        setState(() {
          _allMessages[id]!.add({
            "text": "Masukkan tanggal (format: DD/MM/YYYY):",
            "isMe": false,
            "time": _getCurrentTime(),
            "needsInput": true,
            "inputType": "date"
          });
          _conversationState = 'booking_date_custom';
        });
        break;
    }
    _scrollToBottom();
  }

  void _showBookingConfirmation(String id) {
    setState(() {
      _allMessages[id]!.add({
        "text": "📋 Ringkasan Booking:\n\n"
            "Layanan: $_selectedService\n"
            "Nama: $_customerName\n"
            "Telepon: $_customerPhone\n"
            "Tanggal: $_bookingDate\n\n"
            "Apakah data sudah benar?",
        "isMe": false,
        "time": _getCurrentTime(),
        "hasOptions": true,
        "options": [
          {"text": "✅ Ya, Konfirmasi", "action": "confirm_booking"},
          {"text": "✏️ Edit Data", "action": "edit_booking"},
          {"text": "❌ Batal", "action": "cancel_booking"},
        ]
      });
      _conversationState = 'booking_confirm';
    });
    _scrollToBottom();
  }

  Future<void> _saveBookingToSupabase(String id) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from('bookings').insert({
        'user_id': user?.id ?? 'guest',
        'category': id,
        'service_name': _selectedService,
        'customer_name': _customerName,
        'customer_phone': _customerPhone,
        'booking_date': _bookingDate,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _allMessages[id]!.add({
          "text": "🎉 Booking berhasil!\n\n"
              "Nomor booking Anda telah tersimpan.\n"
              "Admin kami akan menghubungi Anda segera melalui nomor $_customerPhone\n\n"
              "Terima kasih telah mempercayai layanan kami! 😊",
          "isMe": false,
          "time": _getCurrentTime(),
          "hasOptions": true,
          "options": [
            {"text": "🏠 Kembali ke Menu", "action": "menu"},
            {"text": "📦 Booking Lagi", "action": "booking"},
          ]
        });
      });

      _selectedService = null;
      _customerName = null;
      _customerPhone = null;
      _bookingDate = null;
      _conversationState = 'menu';

    } catch (e) {
      setState(() {
        _allMessages[id]!.add({
          "text": "❌ Maaf, terjadi kesalahan saat menyimpan booking.\n\n"
              "Error: ${e.toString()}\n\n"
              "Silakan coba lagi atau hubungi admin.",
          "isMe": false,
          "time": _getCurrentTime(),
          "hasOptions": true,
          "options": [
            {"text": "🔄 Coba Lagi", "action": "booking"},
            {"text": "🏠 Kembali ke Menu", "action": "menu"},
          ]
        });
      });
    }
    _scrollToBottom();
  }

  void _showPrices(String id) async {
    final jasaList = await _getServicesForChat(id);

    if (jasaList.isEmpty) {
      setState(() {
        _allMessages[id]!.add({
          "text": "Belum ada daftar harga untuk kategori ini.",
          "isMe": false,
          "time": _getCurrentTime(),
          "hasOptions": true,
          "options": [{"text": "🔙 Kembali", "action": "menu"}]
        });
      });
      _scrollToBottom();
      return;
    }

    String priceInfo = "💰 Daftar Harga:\n\n";

    for (var jasa in jasaList) {
      priceInfo += "• ${jasa['title']}\n  Rp ${jasa['price']}\n\n";
    }

    setState(() {
      _allMessages[id]!.add({
        "text": priceInfo,
        "isMe": false,
        "time": _getCurrentTime(),
        "hasOptions": true,
        "options": [
          {"text": "📦 Booking Sekarang", "action": "booking"},
          {"text": "🔙 Kembali ke Menu", "action": "menu"}
        ]
      });
    });

    _scrollToBottom();
  }

  void _showServices(String id) async {
    final jasaList = await _getServicesForChat(id);

    if (jasaList.isEmpty) {
      setState(() {
        _allMessages[id]!.add({
          "text": "Belum ada layanan untuk kategori ini.",
          "isMe": false,
          "time": _getCurrentTime(),
          "hasOptions": true,
          "options": [
            {"text": "🔙 Kembali", "action": "menu"}
          ]
        });
      });
      _scrollToBottom();
      return;
    }

    String serviceInfo = "📋 Layanan Kami:\n\n";

    for (var jasa in jasaList) {
      serviceInfo +=
      "✓ ${jasa['title']}\n  ${jasa['description'] ?? '-'}\n\n";
    }

    setState(() {
      _allMessages[id]!.add({
        "text": serviceInfo,
        "isMe": false,
        "time": _getCurrentTime(),
        "hasOptions": true,
        "options": [
          {"text": "📦 Booking Sekarang", "action": "booking"},
          {"text": "🔙 Kembali ke Menu", "action": "menu"}
        ]
      });
    });

    _scrollToBottom();
  }

  void _showMainMenu(String id) {
    setState(() {
      _allMessages[id]!.add({
        "text": "Silakan pilih menu:",
        "isMe": false,
        "time": _getCurrentTime(),
        "hasOptions": true,
        "options": [
          {"text": "📦 Booking / Pesan Jasa", "action": "booking"},
          {"text": "💰 Lihat Harga", "action": "price"},
          {"text": "📋 Info Layanan", "action": "services"},
          {"text": "📞 Kontak Admin", "action": "contact"},
        ]
      });
      _conversationState = 'menu';
    });
    _scrollToBottom();
  }

  void _showTypingIndicator(String id) {
    setState(() {
      _allMessages[id]!.add({
        "text": "typing...",
        "isMe": false,
        "time": _getCurrentTime(),
        "isTyping": true
      });
    });
    _scrollToBottom();
  }

  void _removeTypingIndicator(String id) {
    setState(() {
      _allMessages[id]!.removeWhere((msg) => msg['isTyping'] == true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _selectedChat == null ? _buildHomeChat() : _buildChatRoom(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    bool canPop = Navigator.canPop(context);
    
    return AppBar(
      elevation: 0,
      toolbarHeight: 70,
      backgroundColor: const Color(0xFF1E3A8A),
      leading: (_selectedChat != null || canPop)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                if (_selectedChat != null) {
                  if (widget.initialChatId != null && canPop) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _selectedChat = null);
                    if (widget.onToggleNavbar != null) {
                      widget.onToggleNavbar!(true);
                    }
                  }
                } else if (canPop) {
                  Navigator.pop(context);
                }
              },
            )
          : null,
      title: _selectedChat == null
          ? const Text("Messages", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: 1.2))
          : Row(
        children: [
          CircleAvatar(radius: 20, backgroundImage: AssetImage(_selectedChat!['image']), backgroundColor: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_selectedChat!['id'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Text("Online - Fast Response", style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeChat() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 100),
      itemCount: _chatList.length,
      itemBuilder: (context, index) {
        final chat = _chatList[index];
        return _buildChatTile(chat);
      },
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        onTap: () {
          setState(() => _selectedChat = chat);
          if (widget.onToggleNavbar != null) {
            widget.onToggleNavbar!(false);
          }
          _sendGreeting();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Stack(
          children: [
            CircleAvatar(radius: 30, backgroundImage: AssetImage(chat['image']), backgroundColor: Colors.grey[100]),
            if (chat['isOnline'])
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(_getLastMessage(chat['id']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ),
      ),
    );
  }

  Widget _buildChatRoom() {
    String id = _selectedChat!['id'];
    bool needsInput = _allMessages[id]!.isNotEmpty &&
        _allMessages[id]!.last['needsInput'] == true;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        image: DecorationImage(
          image: NetworkImage("https://www.transparenttextures.com/patterns/cubes.png"),
          opacity: 0.05,
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              itemCount: _allMessages[id]!.length,
              itemBuilder: (context, index) {
                final m = _allMessages[id]![index];
                if (m['isTyping'] == true) {
                  return _buildTypingIndicator();
                }
                return Column(
                  children: [
                    _buildMessageBubble(m['text'], m['isMe'], m['time']),
                    if (m['hasOptions'] == true)
                      _buildOptionsButtons(m['options'], id),
                  ],
                );
              },
            ),
          ),
          if (needsInput)
            _buildTextInput(id),
        ],
      ),
    );
  }

  Widget _buildOptionsButtons(List<dynamic> options, String id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15, left: 10, right: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          return GestureDetector(
            onTap: () {
              String action = option['action'];
              String displayText = option['text'];

              if (action.startsWith('select_service:')) {
                String serviceId = action.split(':')[1];
                _handleServiceSelection(serviceId, id);
              } else if (action.startsWith('date:')) {
                String dateType = action.split(':')[1];
                _handleDateSelection(dateType, id);
              } else if (action == 'confirm_booking') {
                _saveBookingToSupabase(id);
              } else if (action == 'edit_booking') {
                _startBookingFlow(id);
              } else if (action == 'cancel_booking') {
                _showMainMenu(id);
              } else {
                _handleOptionTap(action, displayText);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                option['text'],
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextInput(String id) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: "Ketik di sini...",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                if (_controller.text.trim().isNotEmpty) {
                  _handleTextInput(_controller.text.trim(), id);
                  _controller.clear();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(),
            const SizedBox(width: 4),
            _buildDot(delay: 200),
            const SizedBox(width: 4),
            _buildDot(delay: 400),
          ],
        ),
      ),
    );
  }

  Widget _buildDot({int delay = 0}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, double value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[400]!.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF2563EB) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isMe ? 22 : 5),
                bottomRight: Radius.circular(isMe ? 5 : 22),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
            child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
