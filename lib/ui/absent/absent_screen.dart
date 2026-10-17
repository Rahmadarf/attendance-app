import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 12 — formulir pengajuan izin dan sakit.
class AbsentScreen extends StatefulWidget {
  const AbsentScreen({super.key});

  @override
  State<AbsentScreen> createState() => _AbsentScreenState();
}

class _AbsentScreenState extends State<AbsentScreen> {
  final CollectionReference dataCollection =
      FirebaseFirestore.instance.collection('attendance');

  final TextEditingController nameController = TextEditingController();
  final TextEditingController fromController = TextEditingController();
  final TextEditingController untilController = TextEditingController();

  static const List<String> categories = ["Izin", "Sakit", "Dinas Luar"];
  String selectedCategory = categories.first;

  DateTime? fromDate;
  DateTime? untilDate;
  bool isSubmitting = false;

  @override
  void dispose() {
    nameController.dispose();
    fromController.dispose();
    untilController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final bool isFromField = identical(controller, fromController);
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: (isFromField ? fromDate : untilDate) ?? DateTime.now(),
      firstDate: isFromField ? DateTime(2020) : (fromDate ?? DateTime(2020)),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
        if (isFromField) {
          fromDate = pickedDate;
          // Rentang yang jadi terbalik dikosongkan agar tidak tersimpan diam-diam.
          if (untilDate != null && untilDate!.isBefore(pickedDate)) {
            untilDate = null;
            untilController.clear();
          }
        } else {
          untilDate = pickedDate;
        }
      });
    }
  }

  Future<void> submitPermission(
    String nama,
    String keterangan,
    String from,
    String until,
  ) async {
    await dataCollection.add({
      'name': nama.trim(),
      'address': '-',
      'description': keterangan,
      'datetime': '$from - $until',
      'type': 'permission',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _onSubmitPressed() async {
    if (isSubmitting) return;

    if (nameController.text.trim().isEmpty ||
        fromDate == null ||
        untilDate == null) {
      _showSnackBar(
        "Nama, tanggal mulai, dan tanggal selesai wajib diisi.",
        Icons.warning_amber_rounded,
      );
      return;
    }

    if (untilDate!.isBefore(fromDate!)) {
      _showSnackBar(
        "Tanggal selesai tidak boleh lebih awal dari tanggal mulai.",
        Icons.warning_amber_rounded,
      );
      return;
    }

    setState(() => isSubmitting = true);
    _showLoaderDialog();
    try {
      await submitPermission(
        nameController.text,
        selectedCategory,
        fromController.text,
        untilController.text,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => isSubmitting = false);
      _showSnackBar("Gagal mengirim pengajuan: $e", Icons.error_outline);
    }
  }

  void _showLoaderDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Mengirim pengajuan...")),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF1A008F),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Permission / Leave")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Lengkap",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Kategori",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),
              _buildDateField(
                controller: fromController,
                label: "Tanggal Mulai",
              ),
              const SizedBox(height: 16),
              _buildDateField(
                controller: untilController,
                label: "Tanggal Selesai",
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : _onSubmitPressed,
                icon: const Icon(Icons.send),
                label: Text(
                  isSubmitting ? "Mengirim..." : "Kirim Pengajuan",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A008F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () => _pickDate(controller),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
        hintText: "dd/MM/yyyy",
      ),
    );
  }
}
