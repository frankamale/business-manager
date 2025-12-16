import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../back_pos/utils/network_helper.dart';
import 'unified_login_screen.dart';

class ConnectivityController extends GetxController {
  var isConnected = false.obs;
  var isLoading = true.obs;
  var hasError = false.obs;
  Timer? _retryTimer;

  @override
  void onInit() {
    super.onInit();
    checkConnectivity();
  }

  @override
  void onClose() {
    _retryTimer?.cancel();
    super.onClose();
  }

  Future<void> checkConnectivity() async {
    isLoading.value = true;
    hasError.value = false;
    _retryTimer?.cancel();

    try {
      bool hasConnection = await NetworkHelper.hasConnection();
      if (hasConnection) {
        isConnected.value = true;
        isLoading.value = false;
        // Wait 2 seconds then navigate
        Future.delayed(const Duration(seconds: 2), () {
          Get.offAll(() => const UnifiedLoginScreen());
        });
      } else {
        _setError();
      }
    } catch (e) {
      _setError();
    }
  }

  void _setError() {
    isConnected.value = false;
    isLoading.value = false;
    hasError.value = true;
    // Auto retry every 30 seconds
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkConnectivity();
    });
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ConnectivityController controller = Get.put(ConnectivityController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Obx(() {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width: 150, height: 150),
              const SizedBox(height: 20),
              if (controller.isLoading.value)
                const CircularProgressIndicator()
              else if (controller.hasError.value)
                Column(
                  children: [
                    const Text('No internet connection'),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: controller.checkConnectivity,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }
}