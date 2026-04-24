import 'package:flutter/material.dart';

String formatTitik(int number) {
  String str = number.toString();
  String result = "";
  int count = 0;

  for (int i = str.length - 1; i >= 0; i--) {
    result = str[i] + result;
    count++;
    if (count % 3 == 0 && i != 0) {
      result = "." + result;
    }
  }
  return result;
}

class Product {
  final String id;
  final String title;
  final int price;
  final int? originalPrice;
  final String image;
  final String category;
  final String description;

  Product({
    required this.id,
    required this.title,
    required this.price,
    this.originalPrice,
    required this.image,
    required this.category,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'original_price': originalPrice,
      'image_url': image,
      'category': category,
      'description': description,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      price: json['price'] ?? 0,
      originalPrice: json['original_price'] ?? 0,
      image: (json['image_url'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    product.image,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      Text(
                        product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.originalPrice != null && product.originalPrice! > 0)
                                  Text(
                                    "Rp ${formatTitik(product.originalPrice!)}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),

                                Text(
                                  "Rp ${formatTitik(product.price)}",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF23447D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: onAddToCart,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF23447D),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_shopping_cart,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildProductGrid({
  required BuildContext context,
  required List<Product> products,
  required Function(Product) onProductTap,
  required Function(Product) onAddToCart,
}) {

  return LayoutBuilder(
    builder: (context, constraints) {
      int crossAxisCount = 2;
      double maxWidth = constraints.maxWidth;

      if (maxWidth > 1400) {
        crossAxisCount = 6;
      } else if (maxWidth > 1200) {
        crossAxisCount = 5;
      } else if (maxWidth > 900) {
        crossAxisCount = 4;
      } else if (maxWidth > 600) {
        crossAxisCount = 3;
      }

      return GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            onTap: () => onProductTap(product),
            onAddToCart: () => onAddToCart(product),
          );
        },
      );
    },
  );
}
