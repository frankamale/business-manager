import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../auth/login.dart';
import '../services/api_services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final ApiService _apiService = ApiService();

  String _statusMessage = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _authenticateApp();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
  }

  Future<void> _authenticateApp() async {
    try {
      print('\n');
      print('╔════════════════════════════════════════════════════╗');
      print('║          SPLASH SCREEN - AUTHENTICATION            ║');
      print('╚════════════════════════════════════════════════════╝');
      print('🚀 Starting app authentication process...');

      setState(() {
        _statusMessage = 'Connecting to server...';
      });

      print('📡 Updating UI: Connecting to server...');
      print('🔄 Calling API Service signin method...');

      // Authenticate using the provided credentials
      final authResponse = await _apiService.signIn(
        'test.account123@qc.com',
        'Ba@123456',
      );

      print('✅ Received auth response from API');
      print('👤 User ID: ${authResponse.id}');
      print('📧 Username: ${authResponse.username}');
      print('🎭 Roles: ${authResponse.roles}');
      print('🔑 Token received: ${authResponse.accessToken.substring(0, 20)}...');

      setState(() {
        _statusMessage = 'Authentication successful';
      });

      print('📡 Updating UI: Authentication successful');
      print('⏳ Waiting 800ms before navigation...');

      // Wait a moment before navigating
      await Future.delayed(const Duration(milliseconds: 800));

      print('🚀 Navigating to Login page...');

      // Navigate to login page
      if (mounted) {
        Get.off(() => const Login());
        print('✅ Navigation complete');
      }

      print('╔════════════════════════════════════════════════════╗');
      print('║        AUTHENTICATION COMPLETED SUCCESSFULLY       ║');
      print('╚════════════════════════════════════════════════════╝');
      print('\n');
    } catch (e) {
      print('╔════════════════════════════════════════════════════╗');
      print('║           AUTHENTICATION ERROR OCCURRED            ║');
      print('╚════════════════════════════════════════════════════╝');
      print('💥 Error caught in splash screen');
      print('❌ Error: $e');

      setState(() {
        _hasError = true;
        _statusMessage = 'Connection failed';
      });

      print('📡 Updating UI: Connection failed');

      // Show error snackbar
      Get.snackbar(
        'Connection Error',
        'Failed to connect to server. Please check your internet connection.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        duration: const Duration(seconds: 4),
      );

      print('🔄 Retrying in 3 seconds...');

      // Retry after a delay
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        print('🔁 Initiating retry...\n');
        _authenticateApp();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade400,
              Colors.cyan.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with animations
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        "assets/images/logo.png",
                        width: 120,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.storefront_rounded,
                            size: 120,
                            color: Colors.blue.shade700,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // App Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'BAC POS',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Company Name
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    'Komusoft Solutions',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 60),

                // Loading Indicator
                if (!_hasError)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  )
                else
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.red.shade200,
                  ),
                const SizedBox(height: 20),

                // Status Message
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Retrying...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),

                // Footer
                const Spacer(),
                const Text(
                  'Uganda Edition',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '© 2024 Komusoft Solutions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
