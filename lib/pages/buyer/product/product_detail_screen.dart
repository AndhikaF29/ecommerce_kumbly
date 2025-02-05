import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/cart_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/edit_address_screen.dart';
import 'dart:convert';

class ProductDetailScreen extends StatefulWidget {
  final dynamic product;
  ProductDetailScreen({super.key, required this.product}) {
    Get.put(CartController());
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final CartController cartController = Get.put(CartController());
  final supabase = Supabase.instance.client;
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Parse image URLs
    List<String> imageUrls = [];
    if (widget.product['image_url'] != null) {
      try {
        if (widget.product['image_url'] is List) {
          imageUrls = List<String>.from(widget.product['image_url']);
        } else if (widget.product['image_url'] is String) {
          final List<dynamic> urls = json.decode(widget.product['image_url']);
          imageUrls = List<String>.from(urls);
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title:
            const Text('Detail Produk', style: TextStyle(color: Colors.white)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () => Get.to(() => CartScreen()),
              ),
              Obx(() => cartController.cartItems.isNotEmpty
                  ? Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cartController.cartItems.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SizedBox()),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Produk dengan Slider
            Container(
              height: 300,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                              imageUrls.isEmpty
                                  ? 'https://via.placeholder.com/300'
                                  : imageUrls[index],
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                  if (imageUrls.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${imageUrls.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Informasi Produk
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama dan Harga
                  Text(
                    widget.product['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rp ${NumberFormat('#,###').format(widget.product['price'])}',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Terjual ${widget.product['sales'] ?? 0}',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stok
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Stok: ${widget.product['stock']}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Deskripsi
                  Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product['description'] ?? 'Tidak ada deskripsi',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Informasi Toko
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Penjual',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder(
                          future: supabase
                              .from('merchants')
                              .select('store_name, store_address')
                              .eq('id', widget.product['seller_id'])
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final merchant = snapshot.data as Map;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.store,
                                          color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        merchant['store_name'] ?? 'Nama Toko',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            try {
                                              final addressData = jsonDecode(
                                                  merchant['store_address'] ??
                                                      '{}');
                                              return Text(
                                                '${addressData['street']}, ${addressData['village']}, ${addressData['district']}, ${addressData['city']}, ${addressData['province']} ${addressData['postal_code']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            } catch (e) {
                                              return Text(
                                                'Alamat tidak valid',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return CircularProgressIndicator();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Produk Referensi
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Produk Referensi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchRelatedProducts(widget.product['category']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Tidak ada produk referensi'));
                }

                final relatedProducts = snapshot.data!;
                return SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: relatedProducts.length,
                    itemBuilder: (context, index) {
                      final relatedProduct = relatedProducts[index];
                      if (relatedProduct['id'] == widget.product['id']) {
                        return SizedBox.shrink(); // Skip produk yang sama
                      }
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                product: relatedProduct,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 160,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Gambar Produk
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          _getFirstImageUrl(relatedProduct)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                // Info Produk
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        relatedProduct['name'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Rp ${NumberFormat('#,###').format(relatedProduct['price'])}',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.shopping_bag_outlined,
                                              size: 12, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(
                                            'Terjual ${relatedProduct['sales'] ?? 0}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tombol Chat
            Container(
              width: 35,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.chat_bubble_outline, size: 28),
                onPressed: _startChat,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            // Tombol Keranjang
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () {
                    cartController.addToCart(widget.product);
                    Get.snackbar(
                      'Sukses',
                      'Produk ditambahkan ke keranjang',
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      duration: Duration(seconds: 2),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text('Keranjang', style: TextStyle(fontSize: 11)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Tombol Beli Langsung
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text('Beli Langsung', style: TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRelatedProducts(
      String? category) async {
    if (category == null) return [];

    final response = await supabase
        .from('products')
        .select()
        .eq('category', category) // Filter berdasarkan kolom category
        .neq('id', widget.product['id']) // Kecuali produk saat ini
        .order('sales', ascending: false) // Urutkan berdasarkan penjualan
        .limit(5);

    return response;
  }

  Future<void> _startChat() async {
    final buyerId = supabase.auth.currentUser?.id;
    if (buyerId == null) {
      Get.snackbar('Error', 'Silakan login terlebih dahulu');
      return;
    }

    // Cek apakah chat room sudah ada
    final existingRoom = await supabase
        .from('chat_rooms')
        .select()
        .eq('buyer_id', buyerId)
        .eq('seller_id', widget.product['seller_id'])
        .maybeSingle();

    Map<String, dynamic> chatRoom;
    Map<String, dynamic> seller;

    if (existingRoom != null) {
      chatRoom = existingRoom;
    } else {
      // Buat chat room baru
      final response = await supabase
          .from('chat_rooms')
          .insert({
            'buyer_id': buyerId,
            'seller_id': widget.product['seller_id'],
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      chatRoom = response;
    }

    // Dapatkan info seller
    seller = await supabase
        .from('merchants')
        .select()
        .eq('id', widget.product['seller_id'])
        .single();

    // Navigasi ke chat detail
    Get.to(() => ChatDetailScreen(
          chatRoom: chatRoom,
          seller: seller,
        ));
  }

  void handleCheckout() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar('Error', 'Silakan login terlebih dahulu');
      return;
    }

    try {
      // Ambil alamat user dan data merchant
      final userResponse = await supabase
          .from('users')
          .select('address')
          .eq('id', userId)
          .single();

      final merchantResponse = await supabase
          .from('merchants')
          .select()
          .eq('id', widget.product['seller_id'])
          .single();

      // Langsung ke CheckoutScreen dengan alamat dan data merchant
      Get.to(() => CheckoutScreen(
            data: {
              'items': [
                {
                  'products': {
                    ...widget.product,
                    'merchant': merchantResponse, // Tambahkan data merchant
                  },
                  'quantity': 1,
                }
              ],
              'total_amount': widget.product['price'] * 1,
              'buyer_id': userId,
              'status': 'pending',
              'shipping_address': userResponse['address'] ?? {},
            },
          ));
    } catch (e) {
      print('Error getting data: $e');
      Get.snackbar(
        'Error',
        'Terjadi kesalahan. Silakan coba lagi.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
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
}

String formatTimestamp(DateTime timestamp) {
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss',
      'id_ID'); // Format waktu dengan zona waktu Indonesia
  return dateFormat.format(timestamp);
}
