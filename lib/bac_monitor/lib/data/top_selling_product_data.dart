import 'package:bac_monitor/models/product.dart';

final List<TopProduct> topSellingProductsData = [
  TopProduct(
    rank: 1,
    name: 'Rwenzori Mineral Water (500ml)',
    imageUrl: 'assets/images/water.png', // Example asset path
    unitsSold: 480,
    revenue: 960000,
  ),
  TopProduct(
    rank: 2,
    name: 'Freshly Baked Bread Loaf',
    imageUrl: 'assets/images/bread.png',
    unitsSold: 320,
    revenue: 1600000,
  ),
  TopProduct(
    rank: 3,
    name: 'Cement Bag (50kg)',
    imageUrl: 'assets/images/cement.png',
    unitsSold: 150,
    revenue: 4500000,
  ),
  TopProduct(
    rank: 4,
    name: 'Panadol Extra Tablets (Blister Pack)',
    imageUrl: 'assets/images/panadol.png',
    unitsSold: 800,
    revenue: 800000,
  ),
];