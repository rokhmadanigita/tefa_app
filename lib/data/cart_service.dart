import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'product_data.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    _loadFromPrefs();
  }

  final ValueNotifier<List<Product>> items = ValueNotifier<List<Product>>([]);

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      items.value.map((product) => product.toJson()).toList(),
    );
    await prefs.setString('cart_items', encodedData);
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? encodedData = prefs.getString('cart_items');
      
      if (encodedData != null) {
        final List<dynamic> decodedData = jsonDecode(encodedData);
        items.value = decodedData.map((item) => Product.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("Error loading cart from prefs: $e");
    }
  }

  void add(Product product) {
    items.value = [...items.value, product];
    _saveToPrefs();
  }

  void remove(int index) {
    final temp = [...items.value];
    temp.removeAt(index);
    items.value = temp;
    _saveToPrefs();
  }

  void removeOne(String productId) {
    final temp = [...items.value];
    final index = temp.indexWhere((p) => p.id == productId);
    if (index != -1) {
      temp.removeAt(index);
      items.value = temp;
      _saveToPrefs();
    }
  }

  void removeAllOfProduct(String productId) {
    final temp = [...items.value];
    temp.removeWhere((p) => p.id == productId);
    items.value = temp;
    _saveToPrefs();
  }

  void clear() {
    items.value = [];
    _saveToPrefs();
  }
}
