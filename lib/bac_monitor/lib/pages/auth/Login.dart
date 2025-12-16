// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../../additions/colors.dart';
// import '../../controllers/auth_controller.dart';
//
// class LoginPage extends StatelessWidget {
//   const LoginPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final LoginController controller = Get.put(LoginController());
//
//     return Scaffold(
//       backgroundColor: PrimaryColors.darkBlue,
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 24.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               const Icon(
//                 Icons.storefront,
//                 size: 80,
//                 color: PrimaryColors.brightYellow,
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 "Welcome Back",
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 26,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 48),
//               _buildEmailTextField(
//                 controller: controller.emailController,
//                 hintText: 'Email',
//                 icon: Icons.email_outlined,
//               ),
//               const SizedBox(height: 16),
//               Obx(
//                 () => _buildPasswordTextField(
//                   controller: controller.passwordController,
//                   hintText: 'Password',
//                   icon: Icons.lock_outline,
//                   obscureText: !controller.isPasswordVisible.value,
//                   onToggleVisibility: controller.togglePasswordVisibility,
//                   isPasswordVisible: controller.isPasswordVisible.value,
//                 ),
//               ),
//               const SizedBox(height: 24),
//               Obx(() {
//                 if (controller.errorMessage.value.isNotEmpty) {
//                   return Padding(
//                     padding: const EdgeInsets.only(bottom: 16.0),
//                     child: Text(
//                       controller.errorMessage.value,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         color: Colors.redAccent,
//                         fontSize: 14,
//                       ),
//                     ),
//                   );
//                 }
//                 return const SizedBox.shrink();
//               }),
//               Obx(() {
//                 return controller.isLoading.value
//                     ? const Center(child: CircularProgressIndicator())
//                     : ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: PrimaryColors.brightYellow,
//                           foregroundColor: PrimaryColors.darkBlue,
//                           padding: const EdgeInsets.symmetric(vertical: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                         onPressed: controller.performLogin,
//                         child: const Text(
//                           'Login',
//                           style: TextStyle(
//                             fontSize: 18,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       );
//               }),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // Generic TextField for email
//   Widget _buildEmailTextField({
//     required TextEditingController controller,
//     required String hintText,
//     required IconData icon,
//   }) {
//     return TextField(
//       controller: controller,
//       style: const TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         hintText: hintText,
//         hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//         prefixIcon: Icon(icon, color: PrimaryColors.brightYellow),
//         filled: true,
//         fillColor: PrimaryColors.lightBlue,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide.none,
//         ),
//       ),
//     );
//   }
//
//   // --- ADDED A DEDICATED PASSWORD TEXTFIELD WIDGET ---
//   // It includes the logic for the visibility toggle icon
//   Widget _buildPasswordTextField({
//     required TextEditingController controller,
//     required String hintText,
//     required IconData icon,
//     required bool obscureText,
//     required VoidCallback onToggleVisibility,
//     required bool isPasswordVisible,
//   }) {
//     return TextField(
//       controller: controller,
//       obscureText: obscureText,
//       style: const TextStyle(color: Colors.white),
//       decoration: InputDecoration(
//         hintText: hintText,
//         hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//         prefixIcon: Icon(icon, color: PrimaryColors.brightYellow),
//         // Suffix icon to toggle password visibility
//         suffixIcon: IconButton(
//           icon: Icon(
//             isPasswordVisible ? Icons.visibility : Icons.visibility_off,
//             color: PrimaryColors.brightYellow,
//           ),
//           onPressed: onToggleVisibility,
//         ),
//         filled: true,
//         fillColor: PrimaryColors.lightBlue,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide.none,
//         ),
//       ),
//     );
//   }
// }
