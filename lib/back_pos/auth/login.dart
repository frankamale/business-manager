import 'package:bac_pos/bac_monitor/lib/additions/colors.dart';
import 'package:bac_pos/back_pos/pages/homepage.dart';
import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../bac_monitor/lib/controllers/profile_controller.dart';
import '../../shared/database/unified_db_helper.dart';
import '../../bac_monitor/lib/services/api_services.dart' as monitor;
import '../../bac_monitor/lib/services/account_manager.dart';
import '../../shared/widgets/app_logo.dart';
import '../config.dart';
import '../controllers/auth_controller.dart';
import '../services/api_services.dart';
import '../../flavors/flavor_colors.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.put(AuthController());
  final PosApiService _apiService = Get.find<PosApiService>();
  final ProfileController controller = Get.find();

  String? selectedItem;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLoading2 = false;
  String _companyName = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    _loadCompanyDetails();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final success = await _authController.login(
        selectedItem!,
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        Get.off(() => const Homepage());
      }
    }
  }

  Future<void> _loadCompanyDetails() async {
    try {
      final companyDetails = await _apiService.fetchAndStoreCompanyInfo();

      if (companyDetails.containsKey('activeBranch') &&
          companyDetails['activeBranch'] is Map &&
          (companyDetails['activeBranch'] as Map).containsKey('company') &&
          (companyDetails['activeBranch']['company'] as Map).containsKey(
            'name',
          )) {
        final companyName =
            (companyDetails['activeBranch']['company'] as Map)['name']
                as String?;

        if (companyName != null && companyName.isNotEmpty) {
          setState(() {
            _companyName = companyName;
          });
          return;
        }
      }

      final companyInfo = await _apiService.getCompanyInfo();
      if (companyInfo['companyId']?.isNotEmpty ?? false) {
        setState(() {
          _companyName = companyInfo['companyId']!;
        });
      }
    } catch (e) {
      setState(() {
        _companyName = AppConfig.companyName;
      });
    }
  }

  Future<void> _logoutAndGoToServerLogin() async {
    try {
      setState(() {
        _isLoading2 = true;
      });
      controller.signOut();
      print('DEBUG: Login._logoutAndGoToServerLogin() - Starting logout');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final Color inputFillColor = isDark ? const Color(0xFF2A2A3C) : Colors.grey.shade50;
    final Color inputTextColor = isDark ? Colors.white : Colors.black87;
    final Color labelColor = isDark ? Colors.white70 : Colors.black;
    final Color iconColor = isDark ? Colors.white70 : Colors.black87;
    final Color borderColor = isDark ? Colors.white24 : Colors.grey.shade500;
    final Color footerTextColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final Color welcomeTextColor = isDark ? Colors.white70 : FlavorColors.current.primaryDark;
    final Color titleTextColor = isDark ? Colors.white : (FlavorColors.current.primaryPlus ?? const Color(0xFF222222));
    final Color linkColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    final Color disabledBgColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlavorColors.current.primary,
              // FlavorColors.current.light,
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
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isSmallScreen ? 400 : 480,
                  ),
                  child: Card(
                    color: cardColor,
                    elevation: 12,
                    shadowColor: Colors.black.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 32.0 : 48.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Hero(
                              tag: 'logo',
                              child: AppLogoCircle(
                                size: isSmallScreen ? 100 : 120,
                              ),
                            ),
                            const SizedBox(height: 15),

                            Text(
                              _companyName.isNotEmpty
                                  ? "$_companyName "
                                  : "${AppConfig.companyName} ",

                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 25 : 29,
                                fontWeight: FontWeight.bold,
                                color: titleTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: welcomeTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 40),

                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: selectedItem,
                                borderRadius: BorderRadius.circular(8),
                                dropdownColor: cardColor,
                                style: TextStyle(
                                  color: inputTextColor,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Select Account',
                                  labelStyle: TextStyle(color: labelColor),
                                  prefixIcon: Icon(
                                    Icons.account_circle_outlined,
                                    color: iconColor,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: borderColor,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: FlavorColors.current.primaryDark,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: inputFillColor,
                                ),
                                hint: const Text('Select your account'),
                                items: _authController.userRoles.map((
                                  String item,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(),
                                onChanged: (String? value) {
                                  setState(() {
                                    selectedItem = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select an account';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _passwordController,
                              style: TextStyle(
                                color: inputTextColor,
                                fontSize: 16,
                              ),
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Passcode',
                                labelStyle: TextStyle(color: labelColor),
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: FlavorColors.current.primaryDark,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: borderColor,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: FlavorColors.current.primaryDark,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: inputFillColor,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 4) {
                                  return 'Password must be at least 4 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  foregroundColor:
                                      FlavorColors.current.onPrimary,
                                  elevation: 4,
                                  shadowColor: FlavorColors.current.primaryDark
                                      .withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: disabledBgColor,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Sign In',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            GestureDetector(
                              onTap: _isLoading2
                                  ? null
                                  : _logoutAndGoToServerLogin,
                              child: Text(
                                "Login with server credentials",
                                style: TextStyle(
                                  color: _isLoading2
                                      ? FlavorColors.current.primary
                                      : linkColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Text(
                              AppConfig.copyright,
                              style: TextStyle(
                                fontSize: 12,
                                color: footerTextColor,
                              ),
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
}
