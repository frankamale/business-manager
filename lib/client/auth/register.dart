import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../back_pos/config.dart';

class Register extends StatefulWidget {
  Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController challengeCodeController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController tinController = TextEditingController();

  bool _loading = false;
  String _generatedCode = '';
  String _userId = '';

  String _generateRandomCode() {
    final random = Random();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const digits = '0123456789';

    String letterPart = List.generate(3, (_) => letters[random.nextInt(letters.length)]).join();
    String numberPart = List.generate(6, (_) => digits[random.nextInt(digits.length)]).join();

    return '$letterPart-$numberPart';
  }

  Future<void> _generateChallengeCode() async {
    if (emailController.text.isEmpty || nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name and email first')),
      );
      return;
    }

    setState(() => _loading = true);

    _generatedCode = _generateRandomCode();
    _userId = const Uuid().v4();

    // Prefill the input with the letter prefix
    final prefix = _generatedCode.substring(0, 4); // "ABC-"
    challengeCodeController.text = prefix;

    final uri = Uri.parse(
      '${AppConfig.baseUrl}/getchallengecode/'
      '?e=${Uri.encodeComponent(emailController.text)}'
      '&f=${Uri.encodeComponent(nameController.text)}'
      '&p=${Uri.encodeComponent(_generatedCode)}'
      '&s=Account verification'
      '&id=$_userId',
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge code sent to your email')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    void _registerAccount() {}

    final bool isSmallScreen = size.width < 600;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
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
                    shadowColor: Colors.black.withOpacity(0.3),
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
                            SizedBox(height: 15),
                            _TextField(
                              "Full Name",
                              nameController,
                              Icons.person_outline,
                            ),
                            SizedBox(height: 15),
                            _TextField(
                              "Address",
                              addressController,
                              Icons.location_on_outlined,
                            ),
                            SizedBox(height: 15),

                            _NumberField(
                              "Phone Number",
                              phoneController,
                              Icons.phone_outlined,
                            ),
                            SizedBox(height: 15),
                            _TextField(
                              "Email",
                              emailController,
                              Icons.email_outlined,
                            ),
                            SizedBox(height: 15),
                            _TextField(
                              "TIN",
                              tinController,
                              Icons.numbers_rounded,
                            ),
                            SizedBox(height: 15),

                            //
                            // _NumberField("Passcode", passwordController, Icons.lock_outline),
                            // SizedBox(height: 15),
                            //
                            // _NumberField(
                            //   "Confirm Passcode",
                            //   confirmPasswordController,
                            //   Icons.lock_outline,
                            // ),
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    "Challenge Code",
                                    challengeCodeController,
                                    Icons.qr_code_sharp,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _loading ? null : _generateChallengeCode,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text("Get Code"),
                                ),
                              ],
                            ),
                            SizedBox(height: 25),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
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
                                onPressed: _loading ? null : _registerAccount,
                                child: Text("Register Account"),
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
    TextEditingController controller,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey),
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

  Widget _NumberField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade900),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blueGrey),
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
