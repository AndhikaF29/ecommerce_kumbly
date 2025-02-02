import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class OrderController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final RxList orders = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders(); // Ambil pesanan saat controller diinisialisasi
  }

  Future<void> fetchOrders() async {
    try {
      isLoading.value = true;

      final userId = _supabase.auth.currentUser?.id; // Ambil userId dari auth
      if (userId == null) return; // Pastikan userId tidak null

      final response = await _supabase
          .from('orders')
          .select('*') // Ambil semua kolom dari tabel orders
          .eq('buyer_id', userId); // Filter berdasarkan userId

      if (response != null) {
        orders.value = response; // Simpan data pesanan
      } else {
        Get.snackbar('Error', 'Gagal memuat pesanan');
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      isLoading.value = true;
      await _supabase.from('orders').delete().eq('id', orderId);
      orders.removeWhere(
          (order) => order['id'] == orderId); // Hapus dari daftar lokal
      Get.snackbar('Sukses', 'Pesanan berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    try {
      isLoading.value = true;

      await _supabase
          .from('orders')
          .update({'status': newStatus}).eq('id', orderId);
      // Update daftar lokal jika perlu
      final index = orders.indexWhere((order) => order['id'] == orderId);
      if (index != -1) {
        orders[index]['status'] = newStatus; // Update status di daftar lokal
      }

      Get.snackbar('Sukses', 'Status pesanan berhasil diperbarui');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui status pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createOrder(Map<String, dynamic> orderData) async {
    try {
      isLoading(true);
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Siapkan data pesanan sesuai struktur tabel yang benar
      final orderPayload = {
        'buyer_id': userId,
        'payment_method_id': orderData['payment_method_id'],
        'shipping_address': orderData['shipping_address'],
        'total_amount': orderData['total_amount'],
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert ke tabel orders
      final orderResponse = await _supabase
          .from('orders')
          .insert(orderPayload)
          .select('id')
          .single();

      final orderId = orderResponse['id'];

      // Insert order items
      final orderItems = orderData['items']
          .map((item) => {
                'order_id': orderId,
                'product_id': item['products']['id'],
                'quantity': item['quantity'],
                'price': item['products']['price'],
              })
          .toList();

      await _supabase.from('order_items').insert(orderItems);

      print('Order created successfully with ID: $orderId');
    } catch (e) {
      print('Error creating order: $e');
      throw e;
    } finally {
      isLoading(false);
    }
  }

  Future<String> fetchUserAddress(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('address') // Ambil kolom address
          .eq('id', userId) // Filter berdasarkan userId
          .single(); // Ambil satu data

      return response['address'] ??
          'Alamat tidak tersedia'; // Kembalikan alamat atau pesan default
    } catch (e) {
      print('Error fetching user address: $e');
      return 'Alamat tidak tersedia'; // Kembalikan pesan default jika terjadi kesalahan
    }
  }

  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final response = await _supabase
          .from('orders') // Ganti dengan nama tabel yang sesuai
          .select()
          .eq('id', orderId)
          .single(); // Ambil satu data

      return Map<String, dynamic>.from(response); // Kembalikan data sebagai Map
    } catch (e) {
      print('Error fetching order details: $e');
      throw e; // Lempar kembali kesalahan untuk ditangani di tempat lain
    }
  }
}
