import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../auth/login.dart';
import '../controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final SettingsController settingsController = Get.put(SettingsController());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        iconTheme: IconThemeData(color: Colors.white),

        title: const Text('Settings', style: TextStyle(color: Colors.white)), 
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Profile section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => Text(
                        authController.currentUser.value?.name ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Obx(
                      () => Text(
                        authController.currentUser.value?.username ?? 'Unknown',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Settings list
          Expanded(
            child: ListView(
              children: [
                 ListTile(
                  leading: const Icon(Icons.cloud_upload),
                  title: const Text('Auto Upload Sales'),
                  trailing: Obx(() => Switch(
                    value: settingsController.autoUploadEnabled.value,
                    onChanged: settingsController.toggleAutoUpload,
                  )),
                ),
                const ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Notifications'),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
                const ListTile(
                  leading: Icon(Icons.palette),
                  title: Text('Theme'),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
                const ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Language'),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
                const ListTile(
                  leading: Icon(Icons.help),
                  title: Text('Help & Support'),
                  trailing: Icon(Icons.arrow_forward_ios),
                ),
                             ],
            ),
          ),
          // Logout button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Confirm Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            authController.logout();
                            Get.offAll(() => const Login());
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
