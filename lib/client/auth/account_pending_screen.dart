import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../back_pos/config.dart';
import '../../flavors/flavor_colors.dart';
import '../../initialise/unified_login_screen.dart';
import '../../shared/widgets/app_logo.dart';

class AccountPendingScreen extends StatelessWidget {
  final String? email;

  const AccountPendingScreen({super.key, this.email});

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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.hourglass_top_rounded,
                            size: 48,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Account Pending Approval",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Your account has been created and is currently under review.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email notification info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.email_outlined,
                                color: colorScheme.onPrimaryContainer,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Check your email",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email != null && email!.isNotEmpty
                                          ? "We'll send a confirmation to $email once your account has been approved."
                                          : "You will receive an email confirmation once your account has been approved.",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Help desk info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.support_agent_outlined,
                                color: colorScheme.onSecondaryContainer,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Need help?",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Contact ${AppConfig.companyName} help desk for support. Or call (+256) 705 344 416",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Back to Login button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FlavorColors.current.primaryDark,
                              foregroundColor: FlavorColors.current.onPrimary,
                              elevation: 4,
                              shadowColor: colorScheme.shadow.withValues(
                                alpha: 0.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Get.offAll(() => const UnifiedLoginScreen());
                            },
                            child: const Text(
                              "Back to Login",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

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
    );
  }
}
