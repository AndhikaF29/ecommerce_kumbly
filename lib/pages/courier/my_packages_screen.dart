import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class MyPackagesScreen extends StatefulWidget {
  const MyPackagesScreen({Key? key}) : super(key: key);

  @override
  State<MyPackagesScreen> createState() => _MyPackagesScreenState();
}

class _MyPackagesScreenState extends State<MyPackagesScreen> {
  final _supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> packages = <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> branches = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  final RxDouble totalCODAmount = 0.0.obs;

  @override
  void initState() {
    super.initState();
    _fetchMyPackages();
    _fetchBranches();
  }

  Future<void> _fetchMyPackages() async {
    try {
      isLoading.value = true;
      final courierId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('orders')
          .select('''
            *,
            buyer:users!buyer_id (
              full_name,
              phone
              
            ),
            payment_method:payment_methods (
              id,
              name,
              account_number,
              account_name,
              admin
            )
          ''')
          .eq('courier_id', courierId)
          .inFilter('status', ['processing', 'shipping', 'delivered'])
          .order('created_at', ascending: false);

      packages.value = List<Map<String, dynamic>>.from(response);

      // Debugging: Print untuk melihat data yang diterima
      print('Packages response: ${packages.value}');
      packages.forEach((package) {
        print('Order ID: ${package['id']}');
        print('Payment Method: ${package['payment_method']}');
      });

      // Hitung total COD setelah mendapatkan data
      _calculateTotalCOD();
    } catch (e) {
      print('Error fetching packages: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data paket',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _calculateTotalCOD() {
    double total = 0.0;
    for (var package in packages) {
      // Debug print untuk melihat nilai
      print('Status: ${package['status']}');
      print('Payment Method: ${package['payment_method']?['name']}');
      print('Total Amount: ${package['total_amount']}');
      print('Shipping Cost: ${package['shipping_cost']}');
      print('Admin Fee: ${package['payment_method']?['admin']}');

      if (package['status'] == 'delivered' &&
          package['payment_method']?['name']?.toString().toUpperCase() ==
              'COD') {
        // Hitung total dari total_amount, shipping_cost, dan admin fee
        final totalAmount = package['total_amount'] is String
            ? double.tryParse(package['total_amount']) ?? 0.0
            : (package['total_amount'] ?? 0.0).toDouble();

        final shippingCost = package['shipping_cost'] is String
            ? double.tryParse(package['shipping_cost']) ?? 0.0
            : (package['shipping_cost'] ?? 0.0).toDouble();

        final adminFee = package['payment_method']?['admin'] is String
            ? double.tryParse(package['payment_method']?['admin']) ?? 0.0
            : (package['payment_method']?['admin'] ?? 0.0).toDouble();

        // Jumlahkan semua biaya
        total += totalAmount + shippingCost + adminFee;
      }
    }
    totalCODAmount.value = total;
    print('Total COD calculated: $total'); // Debug print
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await _supabase
          .from('branches')
          .select('id, name, address, phone')
          .order('name');
      branches.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching branches: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: const Text(
            'Paket Saya',
            style: TextStyle(fontWeight: FontWeight.normal),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Total COD Card
                  Obx(() => Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total COD',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(totalCODAmount.value),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                  TabBar(
                    indicatorColor: Theme.of(context).primaryColor,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    tabs: const [
                      Tab(text: 'Aktif'),
                      Tab(text: 'Selesai'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Obx(() {
          if (isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter packages berdasarkan status
          final activePackages = packages
              .where((p) =>
                  p['status'] == 'processing' || p['status'] == 'shipping')
              .toList();

          final completedPackages = packages
              .where(
                  (p) => p['status'] == 'delivered') // Hanya status delivered
              .toList();

          return TabBarView(
            children: [
              // Tab Aktif
              _buildPackagesList(activePackages),

              // Tab Selesai
              _buildPackagesList(completedPackages),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPackagesList(List<Map<String, dynamic>> packagesList) {
    if (packagesList.isEmpty) {
      return const Center(
        child: Text('Tidak ada paket'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyPackages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: packagesList.length,
        itemBuilder: (context, index) {
          final package = packagesList[index];
          final buyer = package['buyer'] as Map<String, dynamic>;
          final paymentMethod =
              package['payment_method'] as Map<String, dynamic>?;

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${package['id'].toString().substring(0, 8)}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusChip(package['status']),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRowWithIcon(
                    Icons.person,
                    'Pembeli',
                    buyer['full_name'] ?? 'N/A',
                  ),
                  _buildInfoRowWithIcon(
                    Icons.phone,
                    'Telepon',
                    buyer['phone'] ?? 'N/A',
                  ),
                  _buildInfoRowWithIcon(
                    Icons.location_on,
                    'Alamat',
                    package['shipping_address'],
                  ),
                  _buildInfoRowWithIcon(
                    Icons.payments,
                    'Produk',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(package['total_amount']),
                  ),
                  _buildInfoRowWithIcon(
                    Icons.local_shipping,
                    'Ongkir',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(package['shipping_cost'] ?? 0),
                  ),
                  _buildInfoRowWithIcon(
                    Icons.admin_panel_settings,
                    'Admin Fee',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(package['payment_method']?['admin'] ?? 0),
                  ),
                  _buildInfoRowWithIcon(
                    Icons.payment,
                    'Payment',
                    paymentMethod?['name'] ?? 'N/A',
                  ),
                  _buildInfoRowWithIcon(
                    Icons.attach_money,
                    'Total',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(calculateTotal(package)),
                  ),
                  _buildInfoRowWithIcon(
                    Icons.store,
                    'Informasi Toko',
                    package['information_merchant'] ??
                        'Tidak ada informasi toko',
                  ),
                  const SizedBox(height: 16),
                  if (package['status'] == 'processing' ||
                      package['status'] == 'shipping') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _uploadHandoverPhoto(package['id']),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text(
                              'Upload Bukti',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _markAsDeliveredToBuyer(package['id']),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Diterima Pembeli',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _markAsDeliveredToBranch(package['id']),
                            icon: const Icon(Icons.store),
                            label: const Text('Diterima Cabang',
                                style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'processing':
        color = Colors.orange;
        text = 'Diproses';
        break;
      case 'shipping':
        color = Colors.blue;
        text = 'Dikirim';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoRowWithIcon(IconData icon, String label, String value) {
    // Fungsi untuk membuka WhatsApp
    void _openWhatsApp(String phone) {
      String cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '62' + cleanPhone.substring(1);
      } else if (!cleanPhone.startsWith('62')) {
        cleanPhone = '62' + cleanPhone;
      }
      final url = 'https://wa.me/$cleanPhone';
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    // Fungsi untuk membuka Google Maps
    void _openMaps(String address) {
      final url =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: label == 'Informasi Toko' &&
                    value != 'Tidak ada informasi toko'
                ? Builder(
                    builder: (context) {
                      // Cari bagian JSON dalam string
                      final jsonStart = value.indexOf('{');
                      final jsonEnd = value.lastIndexOf('}') + 1;
                      final jsonString = value.substring(jsonStart, jsonEnd);

                      // Parsing JSON
                      final info = jsonDecode(jsonString);
                      final address = info['street'];
                      final phone = value.split('Telepon Toko: ').last.trim();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _openMaps(address),
                            child: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _openWhatsApp(phone),
                            child: Text(
                              phone,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : label == 'Telepon' && value != 'N/A'
                    ? InkWell(
                        onTap: () => _openWhatsApp(value),
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : label == 'Alamat' && value != 'N/A'
                        ? InkWell(
                            onTap: () => _openMaps(value),
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadHandoverPhoto(String orderId) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );

      if (image == null) return;

      final String path = 'shipping-proofs/$orderId.jpg';
      final file = File(image.path);

      // Upload ke bucket 'products'
      await _supabase.storage
          .from('products')
          .upload(path, file, fileOptions: const FileOptions(upsert: true));

      // Dapatkan URL foto dari bucket 'products'
      final String photoUrl =
          _supabase.storage.from('products').getPublicUrl(path);

      // Update hanya kolom shipping_proofs
      await _supabase.from('orders').update({
        'shipping_proofs': photoUrl,
      }).eq('id', orderId);

      await _fetchMyPackages();

      Get.snackbar(
        'Sukses',
        'Foto bukti serah terima berhasil diupload',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error uploading photo: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupload foto. Silakan coba lagi.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _markAsDeliveredToBuyer(String orderId) async {
    try {
      // Cek apakah sudah ada foto bukti
      final order = await _supabase
          .from('orders')
          .select('shipping_proofs')
          .eq('id', orderId)
          .single();

      if (order['shipping_proofs'] == null) {
        Get.snackbar(
          'Error',
          'Harap upload foto bukti serah terima terlebih dahulu',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Update status order
      await _supabase
          .from('orders')
          .update({'status': 'delivered'}).eq('id', orderId);

      await _fetchMyPackages();

      Get.snackbar(
        'Sukses',
        'Status pengiriman telah diupdate',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error marking as delivered: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupdate status pengiriman',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _markAsDeliveredToBranch(String orderId) async {
    String? selectedBranchId;

    await Get.dialog(
      AlertDialog(
        title: const Text('Pilih Cabang'),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pilih cabang tujuan pengiriman paket',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                hint: const Text('Pilih cabang'),
                isExpanded: true,
                items: branches.map<DropdownMenuItem<String>>((branch) {
                  final address = Map<String, dynamic>.from(branch['address']);
                  final formattedAddress =
                      '${address['street']}, ${address['city']}';

                  return DropdownMenuItem<String>(
                    value: branch['id'],
                    child: Text(
                      '${branch['name']} - $formattedAddress',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedBranchId = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedBranchId == null) {
                Get.snackbar(
                  'Error',
                  'Silakan pilih cabang terlebih dahulu',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
                return;
              }
              Get.back();
              await _processBranchDelivery(orderId, selectedBranchId!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _processBranchDelivery(String orderId, String branchId) async {
    try {
      // Update status order menjadi delivered
      await _supabase
          .from('orders')
          .update({'status': 'transit'}).eq('id', orderId);

      // Ambil detail order items
      final orderDetails = await _supabase.from('order_items').select('''
            *,
            product:products (*)
          ''').eq('order_id', orderId);

      // Insert ke branch_products
      for (var item in orderDetails) {
        await _supabase.from('branch_products').insert({
          'branch_id': branchId,
          'product_id': item['product_id'],
          'order_id': orderId,
          'quantity': item['quantity'],
        });
      }

      await _fetchMyPackages();

      Get.snackbar(
        'Sukses',
        'Paket telah diterima cabang dan produk telah ditambahkan ke inventori',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error marking as delivered to branch: $e');
      Get.snackbar(
        'Error',
        'Gagal memproses penerimaan di cabang',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  double calculateTotal(Map<String, dynamic> package) {
    final totalAmount = package['total_amount'] ?? 0.0;
    final shippingCost = package['shipping_cost'] ?? 0.0;
    final adminFee = package['payment_method']?['admin'] ?? 0.0;

    return totalAmount + shippingCost + adminFee;
  }
}
