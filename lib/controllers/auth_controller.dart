import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:kumbly_ecommerce/pages/branch/register_branch_screen.dart';
import 'package:kumbly_ecommerce/pages/branch/home_screen.dart';

class AuthController extends GetxController {
  final supabase = Supabase.instance.client;
  final currentUser = Rxn<User>();
  final isLoading = false.obs;
  final RxString userRole = ''.obs;
  var isMerchant = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Listen untuk perubahan auth state
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          currentUser.value = session?.user;
          _getUserRole();
          break;
        case AuthChangeEvent.signedOut:
          currentUser.value = null;
          userRole.value = '';
          break;
        default:
          break;
      }
    });

    // Set initial user jika ada sesi aktif
    currentUser.value = supabase.auth.currentUser;
  }

  Future<void> _getUserRole() async {
    try {
      final userData = await supabase
          .from('users')
          .select('role')
          .eq('id', currentUser.value!.id)
          .maybeSingle();

      if (userData != null) {
        userRole.value = userData['role'] as String;
      } else {
        userRole.value = 'seller';
      }
    } catch (e) {
      print('Error getting user role: $e');
      userRole.value = 'seller';
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String role,
    required String fullName,
    required String phone,
  }) async {
    try {
      isLoading.value = true;

      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        await supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'role': role,
          'full_name': fullName,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });

        Get.snackbar(
          'Sukses',
          'Registrasi berhasil! Silakan periksa email Anda untuk verifikasi akun sebelum login.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );

        Get.offNamed('/login');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      print('Error registrasi: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        currentUser.value = response.user;

        // Ambil data user untuk cek role
        final userData = await supabase
            .from('users')
            .select('role')
            .eq('id', response.user!.id)
            .single();

        if (userData['role'] == 'branch') {
          // Cek apakah sudah terdaftar di branches
          final branchData = await supabase
              .from('branches')
              .select()
              .eq('user_id', response.user!.id)
              .maybeSingle();

          if (branchData == null) {
            Get.offAll(() => const RegisterBranchScreen());
            return true;
          } else {
            Get.offAll(() => const BranchHomeScreen());
            return true;
          }
        }
      }
      return true;
    } on AuthException catch (e) {
      String pesanError = 'Email atau password salah';

      // Terjemahkan pesan error dari Supabase
      switch (e.message) {
        case 'Invalid login credentials':
          pesanError = 'Email atau password tidak sesuai';
          break;
        case 'Email not confirmed':
          pesanError = 'Email belum diverifikasi';
          break;
        case 'Invalid email':
          pesanError = 'Format email tidak valid';
          break;
        default:
          pesanError = 'Gagal masuk ke akun';
      }

      Get.snackbar(
        'Gagal Masuk',
        pesanError,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } catch (_) {
      Get.snackbar(
        'Gagal Masuk',
        'Terjadi kesalahan, silakan coba lagi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      userRole.value = '';
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  Future<void> register(
      String email, String password, String fullName, String phone) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final AuthResponse res = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user != null) {
        await supabase.from('users').insert({
          'id': res.user!.id,
          'email': email,
          'role': 'buyer',
          'full_name': fullName,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        });

        Get.back();
        Get.snackbar(
          'Sukses',
          'Registrasi berhasil! Silakan login.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        Get.offNamed('/login');
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user != null && res.user!.confirmedAt != null) {
        final userData = await supabase
            .from('users')
            .select('role')
            .eq('id', res.user!.id)
            .single();

        Get.back();

        switch (userData['role']) {
          case 'buyer':
            Get.offAllNamed('/buyer/home_screen');
            break;
          case 'buyer_seller':
            Get.offAllNamed('/merchant/home_screen');
            break;
          case 'admin':
            Get.offAllNamed('/admin/home_screen');
            break;
          case 'courier':
            Get.offAllNamed('/courier/home_screen');
            break;
          case 'branch':
            Get.offAllNamed('/branch/home_screen');
            break;
          default:
            Get.offAllNamed('/buyer/home_screen');
        }

        Get.snackbar(
          'Sukses',
          'Login berhasil',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.back();
        Get.snackbar(
          'Perhatian',
          'Silakan verifikasi email Anda terlebih dahulu',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Email atau password salah',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> refreshUser() async {
    final userData = await supabase
        .from('users')
        .select('*')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    currentUser.value = supabase.auth.currentUser;
    userRole.value = userData['role'] ?? '';
    isMerchant.value = userData['role'] == 'seller';
  }

  Future<void> checkBranchRegistration() async {
    try {
      final branch = await supabase
          .from('branches')
          .select()
          .eq('user_id', currentUser.value!.id)
          .maybeSingle();

      if (branch == null) {
        Get.offAll(() => const RegisterBranchScreen());
      } else {
        Get.offAll(() => const BranchHomeScreen());
      }
    } catch (e) {
      print('Error checking branch registration: $e');
      Get.offAll(() => const RegisterBranchScreen());
    }
  }
}
