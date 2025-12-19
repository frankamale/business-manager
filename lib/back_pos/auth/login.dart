import 'package:bac_pos/back_pos/pages/homepage.dart';
import 'package:bac_pos/initialise/unified_login_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../bac_monitor/lib/db/db_helper.dart';
import '../config.dart';
import '../controllers/auth_controller.dart';
import '../services/api_services.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final AuthController _authController = Get.put(AuthController());
  final PosApiService _apiService = PosApiService();
  String? selectedItem;
  bool _obscurePassword = true;
  bool _isLoading = false;
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

      // Authenticate user
      final success = await _authController.login(
        selectedItem!,
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
      });

      // Navigate to POS Screen if login successful
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        Get.off(() => const Homepage());
      }
    }
  }

  Future<void> _loadCompanyDetails() async {
    try {
      // Try to fetch company details from API
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

      // If we don't have the full structure, try to get basic company info
      final companyInfo = await _apiService.getCompanyInfo();
      if (companyInfo['companyId']?.isNotEmpty ?? false) {
        // Use company ID as fallback
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.width < 600;

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
                            // Logo
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

                            // Title
                            Text(
                              _companyName.isNotEmpty
                                  ? "$_companyName "
                                  : "${AppConfig.companyName} ",

                              style: TextStyle(
                                fontSize: isSmallScreen ? 23 : 25,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Welcome Back",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: Colors.blue.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 40),

                            Obx(
                              () => DropdownButtonFormField<String>(
                                value: selectedItem,
                                decoration: InputDecoration(
                                  labelText: 'Select Account',
                                  prefixIcon: Icon(
                                    Icons.account_circle_outlined,
                                    color: Colors.blue.shade700,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade700,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
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

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Passcode',
                                prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.blue.shade700,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.grey.shade600,
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
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade700,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
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

                            // Sign In Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: Colors.blue.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: Colors.grey.shade300,
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
                              onTap: () => {Get.to(UnifiedLoginScreen())},

                              child: Text(
                                "Login with server credentials",
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Footer
                            Text(
                              AppConfig.copyright,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
