import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/buyer/home_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';
import '../../../controllers/auth_controller.dart';
import '../../../screens/home_screen.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              authController.currentUser.value?.email ?? '',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 32),

          // Menu Items
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('Beralih ke Pembeli'),
            onTap: () {
              authController.isMerchant.value = false;
              Get.offAll(() => BuyerHomeScreen());
            },
          ),

          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Alamat Toko'),
            onTap: () {},
          ),

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await authController.signOut();
                        Get.offAll(() => const HomeScreen());
                      },
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
