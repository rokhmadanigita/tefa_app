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

class Jasa {
  final String id;
  final String title;
  final int price;
  final int? originalPrice;
  final String image;
  final String category;
  final String description;

  Jasa({
    required this.id,
    required this.title,
    required this.price,
    this.originalPrice,
    required this.image,
    required this.category,
    required this.description,
  });

  factory Jasa.fromJson(Map<String, dynamic> json) {
    return Jasa(
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

class JasaCard extends StatelessWidget {
  final Jasa jasa;
  final VoidCallback onTap;

  const JasaCard({
    super.key,
    required this.jasa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: jasa.image.isNotEmpty
                    ? Image.network(
                  jasa.image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.broken_image,
                      size: 40,
                      color: Colors.grey,
                    );
                  },
                )
                    : const Icon(
                  Icons.work,
                  size: 40,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6DA0B8).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "Layanan Jasa",
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF6DA0B8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      jasa.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF23447D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (jasa.originalPrice != null && jasa.originalPrice! > 0) ...[
                          Text(
                            "Rp ${formatTitik(jasa.originalPrice!)}",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          "Rp ${formatTitik(jasa.price)}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF23447D),
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
    );
  }
}

Widget buildJasaList({
  required BuildContext context,
  required List<Jasa> jasaList,
  required Function(Jasa) onJasaTap,
}) {

  return ListView.builder(
    shrinkWrap: true,
    padding: EdgeInsets.zero,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: jasaList.length,
    itemBuilder: (context, index) {
      final jasa = jasaList[index];
      return JasaCard(
        jasa: jasa,
        onTap: () => onJasaTap(jasa),
      );
    },
  );
}