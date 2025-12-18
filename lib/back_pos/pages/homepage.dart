import 'package:bac_pos/back_pos/pages/sales_point_details.dart';
import 'settings_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/service_point_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/service_point.dart';
import '../config.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ServicePointController _servicePointController =
      Get.find<ServicePointController>();
  final AuthController authController = Get.find();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getIconForServicePoint(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('restaurant')) return Icons.restaurant_rounded;
    if (lowerType.contains('bar')) return Icons.local_bar_rounded;
    if (lowerType.contains('cafe') || lowerType.contains('cafeteria'))
      return Icons.local_cafe_rounded;
    if (lowerType.contains('pharmacy')) return Icons.local_pharmacy_rounded;
    if (lowerType.contains('hardware')) return Icons.hardware_rounded;
    if (lowerType.contains('shop')) return Icons.shopping_bag_rounded;
    return Icons.store_rounded;
  }

  List<Color> _getGradientForServicePoint(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('restaurant'))
      return [Colors.red.shade400, Colors.red.shade700];
    if (lowerType.contains('bar'))
      return [Colors.purple.shade400, Colors.purple.shade700];
    if (lowerType.contains('cafe') || lowerType.contains('cafeteria'))
      return [Colors.brown.shade400, Colors.brown.shade700];
    if (lowerType.contains('pharmacy'))
      return [Colors.green.shade400, Colors.green.shade700];
    if (lowerType.contains('hardware'))
      return [Colors.orange.shade400, Colors.orange.shade700];
    if (lowerType.contains('shop'))
      return [Colors.blue.shade400, Colors.blue.shade700];
    return [Colors.teal.shade400, Colors.teal.shade700];
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final crossAxisCount = size.width > 1200
        ? 4
        : size.width > 800
        ? 3
        : size.width > 600
        ? 2
        : 1;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Row(
          children: [
            Container(
              width: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(100)),
              ),
              child: Image.asset("assets/images/logo.png"),
            ),
            const SizedBox(width: 12),
            Text(
              AppConfig.companyName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Get.to(() => const SettingsPage());
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await _servicePointController.refreshServicePoints();
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10),
                      Text(
                        "Select a service point",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF151b50),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Obx(() {
                    if (_servicePointController.isLoadingServicePoints.value) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final servicePoints = _servicePointController.servicePoints;

                    if (servicePoints.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.store_rounded,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'No service points available',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 5,
                        childAspectRatio: 3,
                      ),
                      itemCount: servicePoints.length,
                      itemBuilder: (context, index) {
                        final point = servicePoints[index];
                        return _buildServicePointCard(point, index);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicePointCard(ServicePoint point, int index) {
    final icon = _getIconForServicePoint(point.servicepointtype);
    final gradient = _getGradientForServicePoint(point.servicepointtype);
    final color = gradient[0];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Card(
        elevation: 4,
        shadowColor: color.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () {
            Get.to(
              () => SalesPointDetails(servicePoint: point),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 300),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Background pattern
                Positioned(
                  right: -20,
                  top: -20,
                  child: Icon(
                    icon,
                    size: 120,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            point.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            point.code,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
