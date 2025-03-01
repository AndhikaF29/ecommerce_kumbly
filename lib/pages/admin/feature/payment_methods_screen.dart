import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class PaymentMethodsScreen extends StatefulWidget {
  @override
  _PaymentMethodsScreenState createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> paymentMethods = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPaymentMethods();
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final response = await supabase
          .from('payment_methods')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        paymentMethods =
            (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching payment methods: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> deletePaymentMethod(int id) async {
    try {
      await supabase.from('payment_methods').delete().eq('id', id);
      fetchPaymentMethods();
      Get.snackbar('Sukses', 'Metode pembayaran berhasil dihapus');
    } catch (e) {
      print('Error deleting payment method: $e');
      Get.snackbar('Error', 'Gagal menghapus metode pembayaran');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Metode Pembayaran'),
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => AddEditPaymentMethodScreen())
            ?.then((_) => fetchPaymentMethods()),
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primary,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : paymentMethods.isEmpty
              ? Center(child: Text('Tidak ada metode pembayaran'))
              : ListView.builder(
                  itemCount: paymentMethods.length,
                  itemBuilder: (context, index) {
                    final method = paymentMethods[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(method['name']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (method['account_number'] != null)
                              Text('No. Rekening: ${method['account_number']}'),
                            if (method['account_name'] != null)
                              Text('Atas Nama: ${method['account_name']}'),
                            if (method['admin'] != null)
                              Text('Biaya Admin: Rp ${method['admin']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: method['is_active'] ?? false,
                              onChanged: (bool value) async {
                                if (!value) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Konfirmasi'),
                                      content: Text(
                                          'Yakin ingin menonaktifkan metode pembayaran ini?'),
                                      actions: [
                                        TextButton(
                                          child: Text('Batal'),
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                        ),
                                        TextButton(
                                          child: Text('Ya'),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                }
                                await supabase
                                    .from('payment_methods')
                                    .update({'is_active': value}).eq(
                                        'id', method['id']);
                                fetchPaymentMethods();
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => Get.to(
                                () =>
                                    AddEditPaymentMethodScreen(method: method),
                              )?.then((_) => fetchPaymentMethods()),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Konfirmasi'),
                                  content: Text(
                                      'Yakin ingin menghapus metode pembayaran ini?'),
                                  actions: [
                                    TextButton(
                                      child: Text('Batal'),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    TextButton(
                                      child: Text('Hapus'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        deletePaymentMethod(method['id']);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}

class AddEditPaymentMethodScreen extends StatefulWidget {
  final Map<String, dynamic>? method;

  AddEditPaymentMethodScreen({this.method});

  @override
  _AddEditPaymentMethodScreenState createState() =>
      _AddEditPaymentMethodScreenState();
}

class _AddEditPaymentMethodScreenState
    extends State<AddEditPaymentMethodScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final accountNumberController = TextEditingController();
  final accountNameController = TextEditingController();
  final descriptionController = TextEditingController();
  final adminController = TextEditingController();
  bool isActive = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.method != null) {
      nameController.text = widget.method!['name'] ?? '';
      accountNumberController.text = widget.method!['account_number'] ?? '';
      accountNameController.text = widget.method!['account_name'] ?? '';
      descriptionController.text = widget.method!['description'] ?? '';
      adminController.text = widget.method!['admin']?.toString() ?? '';
      isActive = widget.method!['is_active'] ?? true;
    }
  }

  Future<void> _savePaymentMethod() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final data = {
        'name': nameController.text,
        'account_number': accountNumberController.text,
        'account_name': accountNameController.text,
        'description': descriptionController.text,
        'admin': adminController.text.isNotEmpty
            ? double.parse(adminController.text)
            : null,
        'is_active': isActive,
      };

      if (widget.method != null) {
        await supabase
            .from('payment_methods')
            .update(data)
            .eq('id', widget.method!['id']);
      } else {
        await supabase.from('payment_methods').insert(data);
      }

      Get.back();
      Get.snackbar('Sukses', 'Metode pembayaran berhasil disimpan');
    } catch (e) {
      print('Error saving payment method: $e');
      Get.snackbar('Error', 'Gagal menyimpan metode pembayaran');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.method != null
            ? 'Edit Metode Pembayaran'
            : 'Tambah Metode Pembayaran'),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Dasar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Metode Pembayaran',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      validator: (value) => value?.isEmpty == true
                          ? 'Nama tidak boleh kosong'
                          : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: accountNumberController,
                      decoration: InputDecoration(
                        labelText: 'Nomor Rekening',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.credit_card),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: accountNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Pemilik Rekening',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pengaturan Biaya',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: adminController,
                      decoration: InputDecoration(
                        labelText: 'Biaya Admin',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.monetization_on),
                        prefixText: 'Rp ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text('Status Aktif'),
                subtitle: Text(
                  isActive
                      ? 'Metode pembayaran aktif'
                      : 'Metode pembayaran nonaktif',
                ),
                value: isActive,
                onChanged: (bool value) {
                  setState(() => isActive = value);
                },
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _savePaymentMethod,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Simpan',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
