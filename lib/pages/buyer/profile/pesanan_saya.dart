import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../pages/buyer/profile/detail_pesanan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PesananSayaScreen extends StatefulWidget {
  const PesananSayaScreen({super.key});

  @override
  State<PesananSayaScreen> createState() => _PesananSayaScreenState();
}

class _PesananSayaScreenState extends State<PesananSayaScreen>
    with SingleTickerProviderStateMixin {
  final OrderController orderController = Get.put(OrderController());
  late TabController _tabController;
  RxString selectedFilter = 'all'.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    orderController.fetchOrders();
    orderController.fetchHotelBookings();
  }

  String formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);
    } catch (e) {
      print('Error formatting currency: $e');
      return 'Rp 0';
    }
  }

  double calculateTotalPayment(Map<String, dynamic> order) {
    try {
      final totalAmount =
          double.tryParse(order['total_amount'].toString()) ?? 0.0;
      final shippingCost =
          double.tryParse(order['shipping_cost'].toString()) ?? 0.0;
      return totalAmount + shippingCost;
    } catch (e) {
      print('Error calculating total payment: $e');
      return 0.0;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_cancellation':
        return Colors.orange.shade700;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.green;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatOrderId(String orderId) {
    if (orderId.length > 6) {
      return '#${orderId.substring(orderId.length - 6)}';
    }
    return '#$orderId';
  }

  void _showCancelDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Batalkan Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan pesanan ini?',
              style: AppTheme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pembatalan akan diproses setelah mendapat persetujuan admin.',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
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
            onPressed: () => _requestCancellation(order['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCancellation(String orderId) async {
    try {
      // 1. Insert ke order_cancellations dengan status pending
      await supabase.from('order_cancellations').insert({
        'order_id': orderId,
        'status': 'pending', // Menunggu persetujuan admin
        'requested_at': DateTime.now().toIso8601String(),
        'requested_by': supabase.auth.currentUser!.id,
      });

      // 2. Update status order menjadi pending_cancellation
      await supabase
          .from('orders')
          .update({'status': 'pending_cancellation'}).eq('id', orderId);

      Get.back(); // Tutup dialog
      Get.snackbar(
        'Berhasil',
        'Permintaan pembatalan telah dikirim dan menunggu persetujuan admin',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // 3. Refresh data pesanan
      orderController.fetchOrders();
    } catch (e) {
      print('Error requesting cancellation: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat memproses permintaan pembatalan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Tambahkan fungsi untuk menghapus pesanan
  void _showDeleteDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Hapus Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pesanan ini?',
          style: AppTheme.textTheme.bodyMedium,
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
            onPressed: () => _deleteOrder(order['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(String orderId) async {
    try {
      // Hapus order_items terlebih dahulu
      await supabase.from('order_items').delete().eq('order_id', orderId);

      // Hapus order_cancellations jika ada
      await supabase
          .from('order_cancellations')
          .delete()
          .eq('order_id', orderId);

      // Setelah semua dependensi dihapus, baru hapus order
      await supabase.from('orders').delete().eq('id', orderId);

      // Beri notifikasi sukses
      Get.back();
      Get.snackbar(
        'Berhasil',
        'Pesanan telah dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh daftar pesanan
      orderController.fetchOrders();
    } catch (e) {
      print('Error deleting order: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat menghapus pesanan: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Di dalam ListView.builder, tambahkan tombol batalkan jika status pending
  Widget _buildCancelButton(Map<String, dynamic> order) {
    if (order['status'].toString().toLowerCase() != 'pending') {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () => _showCancelDialog(order),
      icon: const Icon(
        Icons.cancel_outlined,
        color: Colors.red,
        size: 18,
      ),
      label: Text(
        'Batalkan Pesanan',
        style: AppTheme.textTheme.bodySmall?.copyWith(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Update fungsi untuk build action buttons
  Widget _buildOrderActions(Map<String, dynamic> order) {
    final status = order['status'].toString().toLowerCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (status == 'pending')
          _buildCancelButton(order)
        else if (status == 'pending_cancellation')
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Menunggu Persetujuan Admin',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (status == 'cancelled')
          TextButton.icon(
            onPressed: () => _showDeleteDialog(order),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: 18,
            ),
            label: Text(
              'Hapus Pesanan',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TextButton(
          onPressed: () {
            Get.to(() => DetailPesananScreen(order: order));
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
          child: Row(
            children: [
              Text(
                'Lihat Detail',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: Text(
          'Pesanan Saya',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Produk'),
            Tab(text: 'Hotel'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductOrders(),
                _buildHotelBookings(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Obx(() => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _filterChip('Semua', 'all'),
              _filterChip('Menunggu Pembayaran', 'pending'),
              _filterChip('Dikonfirmasi', 'confirmed'),
              _filterChip('Selesai', 'completed'),
              _filterChip('Dibatalkan', 'cancelled'),
            ],
          ),
        ));
  }

  Widget _filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selectedFilter.value == value,
        label: Text(label),
        onSelected: (bool selected) {
          selectedFilter.value = value;
          orderController.filterOrders(value);
          orderController.filterHotelBookings(value);
        },
      ),
    );
  }

  Widget _buildProductOrders() {
    return Obx(() {
      if (orderController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (orderController.orders.isEmpty) {
        return _buildEmptyState('Belum ada pesanan');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orderController.orders.length,
        itemBuilder: (context, index) {
          final order = orderController.orders[index];
          final totalPayment = calculateTotalPayment(order);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Order ${formatOrderId(order['id'])}',
                            style: AppTheme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              getStatusColor(order['status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order['status'].toUpperCase(),
                          style: AppTheme.textTheme.bodySmall?.copyWith(
                            color: getStatusColor(order['status']),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        Icons.calendar_today_outlined,
                        'Tanggal Pesanan',
                        formatDate(order['created_at']),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow(
                        Icons.payments_outlined,
                        'Total Pembayaran',
                        formatCurrency(totalPayment),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'Alamat Pengiriman',
                        order['shipping_address'],
                      ),
                    ],
                  ),
                ),

                // Tombol Detail
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.grey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _buildOrderActions(order),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildHotelBookings() {
    return Obx(() {
      if (orderController.isLoadingHotel.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final filteredBookings = orderController.hotelBookings.where((booking) {
        return selectedFilter.value == 'all' ||
            booking['status'] == selectedFilter.value;
      }).toList();

      if (filteredBookings.isEmpty) {
        return _buildEmptyState('Belum ada booking hotel');
      }

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = filteredBookings[index];
          return _buildHotelBookingCard(booking);
        },
      );
    });
  }

  Widget _buildHotelBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Booking ID: ${formatOrderId(booking['id'])}',
              style: AppTheme.textTheme.titleMedium,
            ),
            trailing: _buildStatusChip(booking['status']),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  Icons.hotel,
                  'Hotel',
                  booking['hotel_name'] ?? 'Unknown Hotel',
                ),
                _buildInfoRow(
                  Icons.person,
                  'Tamu',
                  booking['guest_name'],
                ),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Check-in',
                  DateFormat('dd MMM yyyy')
                      .format(DateTime.parse(booking['check_in'])),
                ),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Check-out',
                  DateFormat('dd MMM yyyy')
                      .format(DateTime.parse(booking['check_out'])),
                ),
                _buildInfoRow(
                  Icons.attach_money,
                  'Total Pembayaran',
                  formatCurrency(booking['total_price']),
                ),
              ],
            ),
          ),
          if (booking['status'] == 'pending') _buildBookingActions(booking),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: getStatusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBookingActions(Map<String, dynamic> booking) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => _showCancelBookingDialog(booking),
            child: const Text('Batalkan Booking'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // Navigate to payment page
            },
            child: const Text('Bayar Sekarang'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yuk mulai belanja!',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCancelBookingDialog(Map<String, dynamic> booking) {
    Get.dialog(
      AlertDialog(
        title: const Text('Batalkan Booking'),
        content: const Text('Apakah Anda yakin ingin membatalkan booking ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Tidak'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('hotel_bookings')
                    .update({'status': 'cancelled'}).eq('id', booking['id']);
                Get.back();
                orderController.fetchHotelBookings();
                Get.snackbar(
                  'Sukses',
                  'Booking berhasil dibatalkan',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'Error',
                  'Gagal membatalkan booking',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }
}
