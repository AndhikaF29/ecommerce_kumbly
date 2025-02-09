import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'pages/buyer/home_screen.dart';
import 'controllers/auth_controller.dart';
import 'screens/home_screen.dart';
import 'pages/admin/home_screen.dart';
import 'pages/courier/home_screen.dart';
import 'pages/branch/home_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hfeolsmaqsjfueypfebj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhmZW9sc21hcXNqZnVleXBmZWJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgzOTA1MDIsImV4cCI6MjA1Mzk2NjUwMn0.fLpXoLsYY_c16kjS-pGVGRf1LSLTZn6kI3ilK-_9ktI',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
    debug: true,
  );

  Get.put(AuthController());
  // Get.put(CartController());

  runApp(GetMaterialApp(
    title: 'E-Commerce App',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      useMaterial3: true,
    ),
    home: const SplashScreen(),
    getPages: [
      GetPage(name: '/splash', page: () => SplashScreen()),
      GetPage(name: '/login', page: () => LoginPage()),
      GetPage(name: '/register', page: () => RegisterPage()),
      GetPage(name: '/buyer/home_screen', page: () => BuyerHomeScreen()),
      GetPage(name: '/admin/home_screen', page: () => AdminHomeScreen()),
      GetPage(name: '/courier/home_screen', page: () => CourierHomeScreen()),
      GetPage(name: '/branch/home_screen', page: () => BranchHomeScreen()),
    ],
  ));
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Langsung ke BuyerHomeScreen untuk semua user
        return BuyerHomeScreen();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: const AuthWrapper(),
      getPages: [
        GetPage(name: '/login', page: () => LoginPage()),
        GetPage(name: '/register', page: () => RegisterPage()),
        GetPage(name: '/buyer/home', page: () => BuyerHomeScreen()),
      ],
    );
  }
}
