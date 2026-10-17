import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Step 13 & 14 — riwayat presensi realtime, avatar color hash deterministik,
/// serta operasi edit dan hapus dokumen Firestore.
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

/// Filter tipe dokumen yang ditampilkan pada daftar riwayat.
enum _HistoryFilter { all, attendance, permission }

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final CollectionReference dataCollection =
      FirebaseFirestore.instance.collection('attendance');

  _HistoryFilter filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance History")),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: dataCollection.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildMessage(
                      Icons.cloud_off,
                      "Gagal memuat data: ${snapshot.error}",
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildMessage(
                      Icons.inbox_outlined,
                      "Belum ada riwayat presensi",
                    );
                  }

                  // Urutkan data berdasarkan created_at secara aman di memori
                  final docs =
                      List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                  docs.sort((a, b) {
                    final dataA = a.data() as Map<String, dynamic>? ?? {};
                    final dataB = b.data() as Map<String, dynamic>? ?? {};
                    final timeA = dataA['created_at'] as Timestamp?;
                    final timeB = dataB['created_at'] as Timestamp?;
                    if (timeA != null && timeB != null) {
                      return timeB.compareTo(timeA);
                    }
                    return 0;
                  });

                  final visibleDocs = docs.where(_matchesFilter).toList();
                  if (visibleDocs.isEmpty) {
                    return _buildMessage(
                      Icons.filter_alt_off_outlined,
                      "Tidak ada data untuk filter ini",
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: visibleDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          visibleDocs[index].data() as Map<String, dynamic>? ??
                              {};
                      final docId = visibleDocs[index].id;
                      final name = data['name']?.toString() ?? 'Unknown';
                      final address = data['address']?.toString() ?? '-';
                      final description = data['description']?.toString() ?? '-';
                      final datetime = data['datetime']?.toString() ?? '-';
                      final type = data['type']?.toString() ?? 'attendance';
                      // Dokumen lama, sebelum pengenalan wajah ada, tidak
                      // punya dua field ini. Keduanya dibaca sebagai opsional.
                      final nis = data['nis']?.toString() ?? '';
                      final similarity = data['face_similarity'];

                      return _buildAttendanceCard(
                        docId: docId,
                        name: name,
                        nis: nis,
                        address: address,
                        description: description,
                        datetime: datetime,
                        type: type,
                        similarity:
                            similarity is num ? similarity.toDouble() : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesFilter(QueryDocumentSnapshot doc) {
    if (filter == _HistoryFilter.all) return true;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final type = data['type']?.toString() ?? 'attendance';
    return filter == _HistoryFilter.attendance
        ? type == 'attendance'
        : type == 'permission';
  }

  Widget _buildFilterBar() {
    const labels = {
      _HistoryFilter.all: "Semua",
      _HistoryFilter.attendance: "Presensi",
      _HistoryFilter.permission: "Izin",
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: _HistoryFilter.values.map((value) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[value]!),
              selected: filter == value,
              onSelected: (_) => setState(() => filter = value),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessage(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // Step 14 — warna avatar deterministik dari kode karakter nama.
  Color _getAvatarColor(String name) {
    if (name.trim().isEmpty) return Colors.blueGrey;
    final int hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return Colors.primaries[hash % Colors.primaries.length];
  }

  /// Warna badge mengikuti status presensi (Step 11) maupun kategori izin
  /// (Step 12) sehingga guru bisa memindai daftar dengan cepat.
  Color _getStatusColor(String description) {
    switch (description.toLowerCase()) {
      case 'attend':
        return Colors.green.shade700;
      case 'late':
        return Colors.orange.shade800;
      case 'leave':
        return Colors.blueGrey.shade600;
      case 'sakit':
        return Colors.redAccent.shade700;
      case 'izin':
      case 'dinas luar':
        return Colors.indigo.shade600;
      default:
        return const Color(0xFF1A008F);
    }
  }

  Widget _buildAttendanceCard({
    required String docId,
    required String name,
    required String nis,
    required String address,
    required String description,
    required String datetime,
    required String type,
    required double? similarity,
  }) {
    final statusColor = _getStatusColor(description);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _getAvatarColor(name),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        type == 'permission'
                            ? Icons.event_busy_outlined
                            : Icons.how_to_reg_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  if (nis.isNotEmpty)
                    Text(
                      "NIS $nis",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (similarity != null) ...[
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.face_outlined,
                              size: 12,
                              color: Colors.black45,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "${(similarity * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          datetime,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: Colors.black45,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  tooltip: "Edit",
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _showEditDialog(
                    docId,
                    name,
                    address,
                    description,
                    datetime,
                  ),
                ),
                IconButton(
                  tooltip: "Hapus",
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _showDeleteDialog(docId, name),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(
    String docId,
    String name,
    String address,
    String description,
    String datetime,
  ) async {
    final addressController = TextEditingController(text: address);
    final descriptionController = TextEditingController(text: description);
    final datetimeController = TextEditingController(text: datetime);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Data Presensi"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama sengaja tidak bisa diubah. Nilainya berasal dari
              // pengenalan wajah dan terikat ke `student_id`; mengizinkan
              // pengeditan bebas akan membuat dokumen presensi menunjuk ke
              // siswa yang berbeda dari namanya.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline, size: 20),
                title: Text(name),
                subtitle: const Text(
                  "Nama berasal dari pengenalan wajah dan tidak bisa diubah",
                  style: TextStyle(fontSize: 11),
                ),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Alamat"),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Keterangan"),
              ),
              TextField(
                controller: datetimeController,
                decoration: const InputDecoration(labelText: "Waktu"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              await dataCollection.doc(docId).update({
                'address': addressController.text.trim(),
                'description': descriptionController.text.trim(),
                'datetime': datetimeController.text.trim(),
              });
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );

    addressController.dispose();
    descriptionController.dispose();
    datetimeController.dispose();
  }

  Future<void> _showDeleteDialog(String docId, String name) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Data"),
        content: Text(
          "Hapus data presensi atas nama \"$name\"? Tindakan ini tidak bisa dibatalkan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await dataCollection.doc(docId).delete();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }
}
