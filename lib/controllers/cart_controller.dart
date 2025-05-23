import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/utils/auth_helper.dart';

class CartController extends GetxController {
  final supabase = Supabase.instance.client;
  final cartItems = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCartItems();
  }

  // Mengambil data keranjang dari database
  Future<void> fetchCartItems() async {
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase.from('cart_items').select('''
            *,
            created_at,
            products:product_id (
              *,
              merchant:merchants!inner(
                store_name
              )
            )
          ''').eq('user_id', userId);

      cartItems.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching cart items: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat keranjang belanja',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Menambahkan produk ke keranjang
  Future<void> addToCart(Map<String, dynamic> product) async {
    if (!await AuthHelper.checkLoginRequired()) {
      return;
    }
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final existingItem = cartItems
          .firstWhereOrNull((item) => item['product_id'] == product['id']);

      if (existingItem != null) {
        final currentQuantity = (existingItem['quantity'] as num).toInt();
        await supabase.from('cart_items').update(
            {'quantity': currentQuantity + 1}).eq('id', existingItem['id']);
      } else {
        await supabase.from('cart_items').insert({
          'user_id': userId,
          'product_id': product['id'],
          'quantity': 1,
        });
      }

      await fetchCartItems();
    } catch (e) {
      print('Error adding to cart: $e');
      Get.snackbar(
        'Error',
        'Gagal menambahkan ke keranjang',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Update quantity produk di keranjang
  Future<void> updateQuantity(String cartItemId, int newQuantity,
      {bool shouldRefresh = true}) async {
    try {
      print("Update item dengan ID: $cartItemId ke jumlah: $newQuantity");

      // Pastikan jumlah tidak kurang dari 1
      if (newQuantity < 1) {
        print("Jumlah tidak boleh kurang dari 1");
        return;
      }

      // Update jumlah di database
      await supabase
          .from('cart_items')
          .update({'quantity': newQuantity}).eq('id', cartItemId);

      // Ambil ulang data cart jika diperlukan
      if (shouldRefresh) {
        await fetchCartItems();
      }
    } catch (e) {
      print('Error updating quantity: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui jumlah produk',
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  // Menghapus produk dari keranjang
  Future<void> removeFromCart(String cartItemId) async {
    try {
      print(
          "Menghapus item dengan ID: $cartItemId (Type: ${cartItemId.runtimeType})");

      isLoading(true);

      // Hapus berdasarkan UUID
      await supabase.from('cart_items').delete().eq('id', cartItemId);

      await fetchCartItems();

      Get.snackbar(
        'Sukses',
        'Produk dihapus dari keranjang',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      print('Error removing from cart: $e');
      Get.snackbar(
        'Error',
        'Gagal menghapus produk',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Menghitung total harga keranjang
  double get totalPrice {
    return cartItems.fold(0.0, (sum, item) {
      final price = (item['products']['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + (price * quantity);
    });
  }

  // Menghitung total item di keranjang
  int get totalItems {
    return cartItems.fold(0, (sum, item) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + quantity;
    });
  }

  // Mengosongkan keranjang
  Future<void> clearCart(List<dynamic> productIds) async {
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase
          .from('cart_items')
          .delete()
          .eq('user_id', userId)
          .inFilter('product_id', productIds);

      // Update local cart items
      cartItems.removeWhere((item) => productIds.contains(item['product_id']));
    } catch (e) {
      print('Error clearing cart: $e');
    } finally {
      isLoading(false);
    }
  }

  Future<void> checkout() async {
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Ambil data keranjang
      final cartItemsData = cartItems.map((item) {
        return {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        };
      }).toList();

      // Simpan pesanan ke database
      await supabase.from('orders').insert({
        'user_id': userId,
        'items': cartItemsData,
      });

      // Kosongkan keranjang setelah checkout
      await clearCart([]);

      Get.snackbar('Sukses', 'Checkout berhasil!');
    } catch (e) {
      Get.snackbar('Error', 'Gagal melakukan checkout: $e');
    } finally {
      isLoading(false);
    }
  }

  // Menambahkan metode untuk mendapatkan data checkout
  Map<String, dynamic> prepareCheckoutData(
      String courierId, String shippingAddress) {
    final userId = supabase.auth.currentUser?.id;
    double selectedTotal = cartItems
        .where((item) => item['isSelected'] == true)
        .fold(0.0, (sum, item) {
      final price = (item['products']['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      return sum + (price * quantity);
    });

    return {
      'buyer_id': userId,
      'courier_id': courierId,
      'total_amount': selectedTotal,
      'shipping_address': shippingAddress,
      'items':
          cartItems.where((item) => item['isSelected'] == true).map((item) {
        return {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        };
      }).toList(),
    };
  }
}
