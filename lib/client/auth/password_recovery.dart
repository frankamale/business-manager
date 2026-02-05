import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../back_pos/config.dart';
import '../../shared/widgets/app_logo.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary,
              colorScheme.secondary,
              colorScheme.tertiary,
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
                    child: Obx(() => _buildCurrentStep(context, isSmallScreen)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, bool isSmallScreen) {
    switch (controller.currentStep.value) {
      case 0:
        return _buildIdentifierStep(context, isSmallScreen);
      case 1:
        return _buildCodeVerificationStep(context, isSmallScreen);
      case 2:
        return _buildNewPasswordStep(context, isSmallScreen);
      default:
        return _buildIdentifierStep(context, isSmallScreen);
    }
  }

  /// Step 1: Enter email or phone number
  Widget _buildIdentifierStep(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isSmallScreen),
        const SizedBox(height: 24),
        Text(
          "Recover Your Account",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email or phone number to continue",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          context,
          "Email or Phone Number",
          controller.identifierController,
          Icons.person_search_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        _buildErrorMessage(context),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          context,
          "Find Account",
          controller.isLoading.value
              ? null
              : () => controller.lookupAndSendCode(),
        ),
        const SizedBox(height: 16),
        _buildBackToLoginButton(),
        const SizedBox(height: 24),
        _buildFooter(context, isSmallScreen),
      ],
    );
  }

  /// Step 2: Enter verification code
  Widget _buildCodeVerificationStep(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isSmallScreen),
        const SizedBox(height: 24),
        Text(
          "Verify Your Identity",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the verification code sent to your email",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _buildTextField(
          context,
          "Verification Code",
          controller.challengeCodeController,
          Icons.verified_user_outlined,
          textCapitalization: TextCapitalization.characters,
        ),
        _buildErrorMessage(context),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          context,
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
        _buildFooter(context, isSmallScreen),
      ],
    );
  }

  /// Step 3: Set new password
  Widget _buildNewPasswordStep(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isSmallScreen),
        const SizedBox(height: 24),
        Text(
          "Set New Passcode",
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your new numeric passcode",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        _buildPasswordField(
          context,
          "New Passcode",
          controller.newPasswordController,
          Icons.lock_outline,
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          context,
          "Confirm Passcode",
          controller.confirmPasswordController,
          Icons.lock_outline,
        ),
        _buildErrorMessage(context),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          context,
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
        _buildFooter(context, isSmallScreen),
      ],
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Hero(
      tag: 'logo',
      child: AppLogoCircle(
        size: isSmallScreen ? 80 : 100,
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String label,
    TextEditingController textController,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: textController,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    BuildContext context,
    String label,
    TextEditingController textController,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: textController,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      if (controller.errorMessage.value.isEmpty) {
        return const SizedBox(height: 8);
      }
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          controller.errorMessage.value,
          style: TextStyle(color: colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    });
  }

  Widget _buildPrimaryButton(BuildContext context, String label, VoidCallback? onPressed) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Obx(
        () => ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 4,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          ),
          onPressed: onPressed,
          child: controller.isLoading.value
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
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

  Widget _buildFooter(BuildContext context, bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        AppLogoCircle(
          size: isSmallScreen ? 30 : 50,
        ),
        const SizedBox(width: 10),
        Text(
          AppConfig.copyright,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
