import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../additions/colors.dart';
import '../../models/product.dart';

class TopProductsList extends StatelessWidget {
  final List<TopProduct> products;

  const TopProductsList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            'No top selling products found for this period.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    final numberFormatter = NumberFormat('#,##0');

    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final int thumbnailCacheSize = (50 * devicePixelRatio).round();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      padding: EdgeInsets.zero, // Remove default padding
      itemBuilder: (context, index) {
        final product = products[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          color: PrimaryColors.lightBlue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: PrimaryColors.darkBlue,
                  ),
                  child: Text(
                    '#${product.rank}',
                    style: const TextStyle(
                      color: PrimaryColors.brightYellow,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (product.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      product.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      cacheWidth: thumbnailCacheSize,
                      cacheHeight: thumbnailCacheSize,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white38,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white38,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${numberFormatter.format(product.unitsSold)} units • UGX ${numberFormatter.format(product.revenue)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}