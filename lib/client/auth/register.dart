import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../back_pos/config.dart';
import '../controllers/register_controller.dart';

class Register extends StatelessWidget {
  Register({super.key});

  final RegisterController controller = Get.put(RegisterController());

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue.shade700,
                  Colors.blue.shade400,
                  Colors.blue.shade300,
                ],
              ),
            ),
            child: Center(
              widthFactor: double.infinity,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10.0 : 20.0,
                  vertical: 24.0,
                ),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? 400 : 480,
                  ),
                  child: Card(
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 32.0 : 48.0),
                      child: Form(
                        key: controller.formKey,
                        child: Column(
                          children: [
                            Hero(
                              tag: 'logo',
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  "assets/images/logo.png",
                                  width: isSmallScreen ? 100 : 120,
                                  height: isSmallScreen ? 100 : 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.storefront_rounded,
                                      size: isSmallScreen ? 100 : 120,
                                      color: Colors.blue.shade700,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              "Register Customer Account",
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _TextField(
                              "Full Name",
                              controller.nameController,
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 15),
                            _TextField(
                              "Address",
                              controller.addressController,
                              Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    "Phone Number",
                                    controller.phoneController,
                                    Icons.phone_outlined,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 130,
                                  child: Obx(
                                    () => DropdownButtonFormField<String>(
                                      value: controller.selectedGender.value,
                                      decoration: InputDecoration(
                                        labelText: "Gender",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.blueGrey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 16,
                                            ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Male',
                                          child: Text('Male'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Female',
                                          child: Text('Female'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          controller.selectedGender.value =
                                              value;
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            _TextField(
                              "Email",
                              controller.emailController,
                              Icons.email_outlined,
                            ),
                            const SizedBox(height: 15),
                            _TextField(
                              "TIN",
                              controller.tinController,
                              Icons.numbers_rounded,
                            ),
                            const SizedBox(height: 15),
                            _PasswordField(
                              "Password",
                              controller.passwordController,
                              Icons.lock_outline,
                            ),
                            const SizedBox(height: 15),
                            _PasswordField(
                              "Confirm Password",
                              controller.confirmPasswordController,
                              Icons.lock_outline,
                            ),
                            const SizedBox(height: 15),
                            Obx(
                              () => Row(
                                children: [
                                  Expanded(
                                    child: _TextField(
                                      "Challenge Code",
                                      controller.challengeCodeController,
                                      Icons.qr_code_sharp,
                                      enabled: controller.isCodeSent.value,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,

                                    ),
                                    onPressed: controller.isLoading.value
                                        ? null
                                        : () => controller
                                              .generateChallengeCode(),
                                    child: controller.isLoading.value
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            "Get Code",
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),
                            Obx(
                              () => SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: Colors.blue.withValues(
                                      alpha: 0.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                  ),
                                  onPressed: controller.isLoading.value
                                      ? null
                                      : () async {
                                          final success = await controller
                                              .registerAccount();
                                          if (success) {
                                            Get.back();
                                          }
                                        },
                                  child: controller.isLoading.value
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text("Register Account"),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Footer
                            Row(
                              children: [
                                Hero(
                                  tag: 'footer_logo',
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Image.asset(
                                      "assets/images/logo.png",
                                      width: isSmallScreen ? 30 : 50,
                                      height: isSmallScreen ? 30 : 50,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Icon(
                                              Icons.storefront_rounded,
                                              size: isSmallScreen ? 30 : 50,
                                              color: Colors.blue.shade700,
                                            );
                                          },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  AppConfig.copyright,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _TextField(
    String label,
    TextEditingController textController,
    IconData icon, {
    bool enabled = true,
  }) {
    return TextFormField(
      controller: textController,
      enabled: enabled,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _NumberField(
    String label,
    TextEditingController textController,
    IconData icon,
  ) {
    return TextFormField(
      controller: textController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700),
        ),
      ),
    );
  }

  Widget _PasswordField(
    String label,
    TextEditingController textController,
    IconData icon,
  ) {
    return TextFormField(
      controller: textController,
      keyboardType: TextInputType.number,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blueGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700),
        ),
      ),
    );
  }
}
