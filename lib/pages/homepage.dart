import 'package:bac_pos/pages/sales_point_details.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<ServicePoint> servicePoints = [
    ServicePoint(
      name: "Cafeteria",
      icon: Icons.local_cafe_rounded,
      color: Colors.brown,
      gradient: [Colors.brown.shade400, Colors.brown.shade700],
    ),
    ServicePoint(
      name: "Pharmacy",
      icon: Icons.local_pharmacy_rounded,
      color: Colors.green,
      gradient: [Colors.green.shade400, Colors.green.shade700],
    ),
    ServicePoint(
      name: "Hardware",
      icon: Icons.hardware_rounded,
      color: Colors.orange,
      gradient: [Colors.orange.shade400, Colors.orange.shade700],
    ),
    ServicePoint(
      name: "Restaurant",
      icon: Icons.restaurant_rounded,
      color: Colors.red,
      gradient: [Colors.red.shade400, Colors.red.shade700],
    ),
    ServicePoint(
      name: "Bar",
      icon: Icons.local_bar_rounded,
      color: Colors.purple,
      gradient: [Colors.purple.shade400, Colors.purple.shade700],
    ),
  ];

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
        title: Row(
          children: [
            Container(
              width: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(100))
                ),
                child: Image.asset("assets/images/logo.png")
            ),
            const SizedBox(width: 12),
            const Text(
              "Testing Company LTD",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
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

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 5,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: servicePoints.length,
                  itemBuilder: (context, index) {
                    final point = servicePoints[index];
                    return _buildServicePointCard(point, index);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServicePointCard(ServicePoint point, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Card(
        elevation: 4,
        shadowColor: point.color.withOpacity(0.4),
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
                colors: point.gradient,
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
                    point.icon,
                    size: 120,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text(
                                "Open",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
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

class ServicePoint {
  final String name;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  ServicePoint({
    required this.name,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}
