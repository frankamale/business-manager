import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../back_pos/config.dart';
import '../../flavors/flavor_colors.dart';
import '../../shared/widgets/app_logo.dart';
import '../controllers/register_controller.dart';
import 'set_passcode.dart';

class Register extends StatelessWidget {
  Register({super.key});

  final RegisterController controller = Get.put(RegisterController());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FlavorColors.current.primaryDark,
              FlavorColors.current.secondary,
              FlavorColors.current.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
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
                  shadowColor: colorScheme.shadow.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 32.0 : 48.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Hero(
                            tag: 'logo',
                            child: AppLogoCircle(
                              size: isSmallScreen ? 100 : 120,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            textAlign: TextAlign.center,
                            "Register Account",
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),

                          const SizedBox(height: 15),
                          _buildTextField(
                            context,
                            "Full Name *",
                            controller.nameController,
                            Icons.person_outline,
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: _buildNumberField(
                                  context,
                                  "Phone Number *",
                                  controller.phoneController,
                                  Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildTextField(
                            context,
                            "Email *",
                            controller.emailController,
                            Icons.email_outlined,
                          ),

                          const SizedBox(height: 15),

                          // Advanced toggle
                          Obx(
                            () => InkWell(
                              onTap: () {
                                controller.showAdvanced.value =
                                    !controller.showAdvanced.value;
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Advanced",
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    controller.showAdvanced.value
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Advanced fields
                          Obx(
                            () => controller.showAdvanced.value
                                ? Column(
                                    children: [
                                      const SizedBox(height: 15),
                                      _buildTextField(
                                        context,
                                        "Address",
                                        controller.addressController,
                                        Icons.location_on_outlined,
                                      ),
                                      const SizedBox(height: 15),
                                      SizedBox(
                                        width: double.infinity,
                                        child: DropdownButtonFormField<String>(
                                          value:
                                              controller.selectedGender.value,
                                          decoration: InputDecoration(
                                            labelText: "Gender",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colorScheme.outline,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colorScheme.outline,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: colorScheme.primary,
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
                                      const SizedBox(height: 15),
                                      _buildTextField(
                                        context,
                                        "TIN",
                                        controller.tinController,
                                        Icons.numbers_rounded,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 15),
                          Obx(
                            () => Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    context,
                                    "Challenge Code",
                                    controller.challengeCodeController,
                                    Icons.qr_code_sharp,
                                    enabled: controller.isCodeSent.value,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FlavorColors.current.primaryDark,
                                    foregroundColor: FlavorColors.current.onPrimary,
                                  ),
                                  onPressed: controller.isGettingCode.value
                                      ? null
                                      : () =>
                                            controller.generateChallengeCode(),
                                  child: controller.isGettingCode.value
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : const Text("Get Code"),
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
                                  backgroundColor: FlavorColors.current.primaryDark,
                                  foregroundColor: FlavorColors.current.onPrimary,
                                  elevation: 4,
                                  shadowColor: colorScheme.shadow.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                ),
                                onPressed: controller.isRegistering.value
                                    ? null
                                    : () async {
                                        final success = await controller
                                            .registerAccount();
                                        if (success) {
                                          Get.to(() => SetPasscode());
                                        }
                                      },
                                child: controller.isRegistering.value
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: FlavorColors.current.primaryDark,
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
                                child: AppLogoCircle(
                                  size: isSmallScreen ? 30 : 50,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                AppConfig.copyright,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
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
    );
  }

  Widget _buildTextField(
    BuildContext context,
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
        prefixIcon: Icon(icon, color: FlavorColors.current.primaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
      ),
    );
  }

  Widget _buildNumberField(
    BuildContext context,
    String label,
    TextEditingController textController,
    IconData icon,
  ) {
    return TextFormField(
      controller: textController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: FlavorColors.current.primaryDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: FlavorColors.current.primaryDark),
        ),
      ),
    );
  }
}
