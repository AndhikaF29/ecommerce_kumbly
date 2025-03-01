import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/cart_controller.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:kumbly_ecommerce/pages/buyer/checkout/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'dart:convert';
import 'package:kumbly_ecommerce/utils/auth_helper.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/alamat_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartController cartController = Get.put(CartController());
  final OrderController orderController = Get.put(OrderController());
  final Map<String, bool> selectedItems = {};

  @override
  void initState() {
    super.initState();
    cartController.fetchCartItems();
  }

  double calculateSelectedTotal() {
    double total = 0;
    for (var item in cartController.cartItems) {
      if (selectedItems[item['id'].toString()] == true) {
        total += (item['products']['price'] * item['quantity']);
      }
    }
    return total;
  }

  void updateCartItem(String id, int newQuantity) {
    final itemIndex =
        cartController.cartItems.indexWhere((item) => item['id'] == id);
    if (itemIndex != -1) {
      setState(() {
        cartController.cartItems[itemIndex]['quantity'] = newQuantity;
      });
      cartController.updateQuantity(id, newQuantity);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Keranjang Saya', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: AppTheme.primary,
      ),
      body: Obx(() {
        if (cartController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cartController.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Keranjang kosong', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Sort items by created_at timestamp first
        final sortedItems =
            List<Map<String, dynamic>>.from(cartController.cartItems)
              ..sort((a, b) {
                final DateTime aDate = DateTime.parse(a['created_at']);
                final DateTime bDate = DateTime.parse(b['created_at']);
                return bDate
                    .compareTo(aDate); // Descending order (newest first)
              });

        // Kelompokkan items berdasarkan merchant
        Map<String, List<dynamic>> groupedItems = {};
        for (var item in sortedItems) {
          String sellerId = item['products']['seller_id'].toString();

          if (!groupedItems.containsKey(sellerId)) {
            groupedItems[sellerId] = [];
          }
          groupedItems[sellerId]!.add(item);
        }

        // Sort the merchant groups by their newest item
        final sortedMerchants = groupedItems.keys.toList()
          ..sort((a, b) {
            final aNewestDate =
                DateTime.parse(groupedItems[a]!.first['created_at']);
            final bNewestDate =
                DateTime.parse(groupedItems[b]!.first['created_at']);
            return bNewestDate.compareTo(aNewestDate);
          });

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedMerchants.length,
                itemBuilder: (context, index) {
                  String sellerId = sortedMerchants[index];
                  List<dynamic> merchantItems = groupedItems[sellerId]!;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Merchant Header with Select All
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Checkbox(
                                value: merchantItems.every((item) =>
                                    selectedItems[item['id']] == true),
                                onChanged: (bool? value) {
                                  setState(() {
                                    for (var item in merchantItems) {
                                      selectedItems[item['id']] =
                                          value ?? false;
                                    }
                                  });
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Icon(Icons.store, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  merchantItems.first['products']['merchant']
                                          ['store_name'] ??
                                      'Toko',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    bool currentValue = merchantItems.every(
                                        (item) =>
                                            selectedItems[item['id']] == true);
                                    for (var item in merchantItems) {
                                      selectedItems[item['id']] = !currentValue;
                                    }
                                  });
                                },
                                child: Text(
                                  merchantItems.every((item) =>
                                          selectedItems[item['id']] == true)
                                      ? 'Batal Pilih Semua'
                                      : 'Pilih Semua',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1),

                        // Merchant Items
                        // In CartScreen, update the onUpdateQuantity handler
                        ...merchantItems
                            .map((item) => CartItemWidget(
                                  item: item,
                                  isSelected:
                                      selectedItems[item['id']] ?? false,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      selectedItems[item['id']] =
                                          value ?? false;
                                    });
                                  },
                                  onUpdateQuantity:
                                      (String id, int newQuantity) {
                                    // Update locally first without triggering a reload
                                    final itemIndex = cartController.cartItems
                                        .indexWhere((item) => item['id'] == id);
                                    if (itemIndex != -1) {
                                      cartController.cartItems[itemIndex]
                                          ['quantity'] = newQuantity;
                                      setState(
                                          () {}); // Update UI without reload
                                    }
                                    // Then update in backend without refreshing the list
                                    cartController.updateQuantity(
                                        id, newQuantity,
                                        shouldRefresh: false);
                                  },
                                  onRemove: cartController.removeFromCart,
                                ))
                            .toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total Pembayaran:'),
                      Text(
                        'Rp ${NumberFormat('#,###').format(calculateSelectedTotal())}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      if (!await AuthHelper.checkLoginRequired()) {
                        return;
                      }
                      try {
                        final userId =
                            cartController.supabase.auth.currentUser!.id;

                        // Ambil alamat user
                        final userResponse = await cartController.supabase
                            .from('users')
                            .select('address, address2, address3, address4')
                            .eq('id', userId)
                            .single();

                        // Cek apakah user memiliki alamat
                        bool hasAddress = userResponse['address'] != null ||
                            userResponse['address2'] != null ||
                            userResponse['address3'] != null ||
                            userResponse['address4'] != null;

                        if (!hasAddress) {
                          // Tampilkan dialog untuk menambahkan alamat
                          Get.dialog(
                            AlertDialog(
                              title: Text('Alamat Pengiriman'),
                              content: Text(
                                  'Anda belum memiliki alamat pengiriman. Tambahkan alamat terlebih dahulu untuk melanjutkan pembelian.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Get.back(),
                                  child: Text('Batal'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Get.back(); // Tutup dialog
                                    Get.to(() => AlamatScreen())?.then((value) {
                                      // Coba checkout lagi setelah kembali dari AlamatScreen
                                      if (value == true) {
                                        cartController.fetchCartItems();
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                  ),
                                  child: Text('Tambah Alamat',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // Gunakan alamat pertama yang tersedia
                        Map<String, dynamic>? selectedAddress;
                        if (userResponse['address4'] != null) {
                          selectedAddress = userResponse['address4'];
                        } else if (userResponse['address'] != null) {
                          selectedAddress = userResponse['address'];
                        } else if (userResponse['address2'] != null) {
                          selectedAddress = userResponse['address2'];
                        } else if (userResponse['address3'] != null) {
                          selectedAddress = userResponse['address3'];
                        }

                        // Format alamat
                        final formattedAddress =
                            '${selectedAddress!['street']}, '
                            '${selectedAddress['village']}, '
                            '${selectedAddress['district']}, '
                            '${selectedAddress['city']}, '
                            '${selectedAddress['province']}, '
                            '${selectedAddress['postal_code']}';

                        List<Map<String, dynamic>> selectedProducts = [];
                        List<String> selectedIds = [];

                        for (var item in cartController.cartItems) {
                          if (selectedItems[item['id'].toString()] == true) {
                            selectedProducts.add({
                              'id': item['id'],
                              'product_id': item['product_id'],
                              'quantity': item['quantity'],
                              'products': item['products'],
                            });
                            selectedIds.add(item['id'].toString());
                          }
                        }

                        final checkoutData = {
                          'buyer_id': userId,
                          'shipping_address': formattedAddress,
                          'total_amount': calculateSelectedTotal(),
                          'items': selectedProducts,
                          'payment_method': null,
                          'shipping_cost': 0,
                          'admin_fee': 0,
                          'status': 'pending',
                        };

                        // Navigasi ke CheckoutScreen dan tunggu hasilnya
                        final result = await Get.to(
                            () => CheckoutScreen(data: checkoutData));

                        // Jika checkout berhasil, hapus item yang dipilih dari keranjang
                        if (result == true) {
                          // Hapus item yang dipilih dari cart
                          for (String id in selectedIds) {
                            await cartController.removeFromCart(id);
                          }

                          // Reset selection
                          setState(() {
                            selectedItems.clear();
                          });

                          // Refresh cart items
                          cartController.fetchCartItems();

                          Get.snackbar(
                            'Sukses',
                            'Produk berhasil dicheckout',
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                          );
                        }
                      } catch (e) {
                        print('Error preparing checkout: $e');
                        Get.snackbar(
                          'Error',
                          'Terjadi kesalahan saat mempersiapkan checkout',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'Checkout (${selectedItems.values.where((v) => v).length})',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// Buat widget terpisah untuk item cart
class CartItemWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final Function(bool?) onChanged;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemove;

  const CartItemWidget({
    required this.item,
    required this.isSelected,
    required this.onChanged,
    required this.onUpdateQuantity,
    required this.onRemove,
  });
  @override
  State<CartItemWidget> createState() => _CartItemWidgetState();
}

class _CartItemWidgetState extends State<CartItemWidget> {
  late int quantity;

  @override
  void initState() {
    super.initState();
    quantity = widget.item['quantity'];
  }

  @override
  void didUpdateWidget(CartItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['quantity'] != widget.item['quantity']) {
      quantity = widget.item['quantity'];
    }
  }

  String _getFirstImageUrl(Map<String, dynamic> product) {
    List<String> imageUrls = [];
    if (product['image_url'] != null) {
      try {
        if (product['image_url'] is List) {
          imageUrls = List<String>.from(product['image_url']);
        } else if (product['image_url'] is String) {
          final List<dynamic> urls = json.decode(product['image_url']);
          imageUrls = List<String>.from(urls);
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }
    return imageUrls.isNotEmpty
        ? imageUrls.first
        : 'https://via.placeholder.com/150';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: widget.isSelected,
            onChanged: widget.onChanged,
            activeColor: AppTheme.primary,
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(_getFirstImageUrl(widget.item['products'])),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item['products']['name'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  'Rp ${NumberFormat('#,###').format(widget.item['products']['price'])}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                IntrinsicWidth(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove, size: 16),
                              onPressed: () {
                                if (quantity > 1) {
                                  setState(() {
                                    quantity--;
                                    widget.item['quantity'] = quantity;
                                  });
                                  widget.onUpdateQuantity(
                                      widget.item['id'], quantity);
                                }
                              },
                              constraints: BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              child: Center(
                                child: Text('$quantity'),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add, size: 16),
                              onPressed: () {
                                setState(() {
                                  quantity++;
                                  widget.item['quantity'] = quantity;
                                });
                                widget.onUpdateQuantity(
                                    widget.item['id'], quantity);
                              },
                              constraints: BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon:
                            Icon(Icons.delete_outline, color: Colors.red[400]),
                        onPressed: () => widget.onRemove(widget.item['id']),
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
