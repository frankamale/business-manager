import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../back_pos/config.dart';
import '../controllers/password_recovery_controller.dart';

class PasswordRecovery extends StatelessWidget {
  PasswordRecovery({super.key});

  final PasswordRecoveryController controller = Get.put(
    PasswordRecoveryController(),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

    return Scaffold(
      body: Container(
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
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 32.0 : 48.0),
                    child: Obx(() => _buildCurrentStep(isSmallScreen)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(bool isSmallScreen) {
    switch (controller.currentStep.value) {
      case 0:
        return _buildIdentifierStep(isSmallScreen);
      case 1:
        return _buildCodeVerificationStep(isSmallScreen);
      case 2:
        return _buildNewPasswordStep(isSmallScreen);
      default:
        return _buildIdentifierStep(isSmallScreen);
    }
  }

  /// Step 1: Enter email or phone number
  Widget _buildIdentifierStep(bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isSmallScreen),
        const SizedBox(height: 24),
        Text(
          "Recover Your Account",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email or phone number to find your account",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          "Email or Phone Number",
          controller.identifierController,
          Icons.person_search_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildErrorMessage(),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          "Find Account",
          controller.isLoading.value
              ? null
              : () => controller.lookupAndSendCode(),
        ),
        const SizedBox(height: 16),
        _buildBackToLoginButton(),
        const SizedBox(height: 24),
        _buildFooter(isSmallScreen),
      ],
    );
  }

  /// Step 2: Enter verification code
  Widget _buildCodeVerificationStep(bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isSmallScreen),
        const SizedBox(height: 24),
        Text(
          "Verify Your Identity",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the verification code sent to your email",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          "Verification Code",
          controller.challengeCodeController,
          Icons.verified_user_outlined,
          textCapitalization: TextCapitalization.characters,
        ),
        _buildErrorMessage(),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          "Verify Code",
          controller.isLoading.value
              ? null
              : () {
                  if (controller.verifyChallengeCode()) {
                    // Code verified, controller will move to next step
                  }
                },
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => controller.goBack(),
              icon: const Icon(Icons.arrow_back),
              label: const Text("Back"),
            ),
            TextButton(
              onPressed: controller.isLoading.value
                  ? null
                  : () => controller.lookupAndSendCode(),
              child: const Text("Resend Code"),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildFooter(isSmallScreen),
      ],
    );
  }

  /// Step 3: Set new password
  Widget _buildNewPasswordStep(bool isSmallScreen) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isSmallScreen),
        const SizedBox(height: 24),
        Text(
          "Set New Passcode",
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your new numeric passcode",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _buildPasswordField(
          "New Passcode",
          controller.newPasswordController,
          Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          "Confirm Passcode",
          controller.confirmPasswordController,
          Icons.lock_outline,
        ),
        _buildErrorMessage(),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          "Reset Passcode",
          controller.isLoading.value
              ? null
              : () async {
                  final success = await controller.resetPassword();
                  print("reset passcode success : $success");
                  if (success) {
                    Get.to(UnifiedLoginScreen());
                  }
                },
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => controller.goBack(),
          icon: const Icon(Icons.arrow_back),
          label: const Text("Back"),
        ),
        const SizedBox(height: 24),
        _buildFooter(isSmallScreen),
      ],
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Hero(
      tag: 'logo',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          "assets/images/logo.png",
          width: isSmallScreen ? 80 : 100,
          height: isSmallScreen ? 80 : 100,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.storefront_rounded,
              size: isSmallScreen ? 80 : 100,
              color: Colors.blue.shade700,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController textController,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: textController,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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

  Widget _buildPasswordField(
    String label,
    TextEditingController textController,
    IconData icon,
  ) {
    return TextFormField(
      controller: textController,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

  Widget _buildErrorMessage() {
    return Obx(() {
      if (controller.errorMessage.value.isEmpty) {
        return const SizedBox(height: 8);
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          controller.errorMessage.value,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    });
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: Obx(
        () => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.blue.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          onPressed: onPressed,
          child: controller.isLoading.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBackToLoginButton() {
    return TextButton.icon(
      onPressed: () => Get.back(),
      icon: const Icon(Icons.arrow_back),
      label: const Text("Back to Login"),
    );
  }

  Widget _buildFooter(bool isSmallScreen) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Image.asset(
            "assets/images/logo.png",
            width: isSmallScreen ? 30 : 50,
            height: isSmallScreen ? 30 : 50,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.storefront_rounded,
                size: isSmallScreen ? 30 : 50,
                color: Colors.blue.shade700,
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Text(
          AppConfig.copyright,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
