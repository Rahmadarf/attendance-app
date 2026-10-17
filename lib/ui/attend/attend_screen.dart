import 'dart:io';

import 'package:attendance_app/ui/attend/camera_screen.dart';
import 'package:attendance_app/ui/home_screen.dart';
import 'package:attendance_app/utils/attendance_status.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

/// Form konfirmasi presensi: menampilkan selfie hasil verifikasi wajah,
/// mengambil koordinat GPS beserta alamatnya, menentukan status kehadiran
/// berdasarkan jam, lalu mengirim dokumen ke Cloud Firestore.
class AttendScreen extends StatefulWidget {
  final XFile? image;

  const AttendScreen({super.key, this.image});

  @override
  State<AttendScreen> createState() => _AttendScreenState();
}

class _AttendScreenState extends State<AttendScreen> {
  final CollectionReference dataCollection =
      FirebaseFirestore.instance.collection('attendance');

  final TextEditingController nameController = TextEditingController();

  double dLat = 0.0;
  double dLong = 0.0;
  String strAlamat = "Mencari lokasi...";
  String strStatus = "Attend";
  String strDateTime = "";
  bool isLoading = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    setStatusAbsen();
    strDateTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
    if (widget.image != null) {
      getGeoLocationPosition();
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // Step 11 — aturan waktu kehadiran otomatis.
  void setStatusAbsen() {
    strStatus = resolveAttendanceStatus(DateTime.now());
  }

  // Step 9 — manajemen izin lokasi runtime.
  Future<bool> handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(
        "Layanan GPS tidak aktif. Silakan aktifkan GPS perangkat Anda.",
        Icons.location_off,
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar("Izin akses lokasi ditolak.", Icons.warning_amber_rounded);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
        "Izin lokasi ditolak permanen. Buka pengaturan aplikasi untuk mengizinkan.",
        Icons.error_outline,
      );
      return false;
    }

    return true;
  }

  Future<void> getGeoLocationPosition() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return;

    setState(() => isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      dLat = position.latitude;
      dLong = position.longitude;
      await getAddressFromLongLat(position);
    } catch (e) {
      debugPrint("Error GPS: $e");
      if (mounted) {
        setState(() {
          strAlamat = "Koordinat: Lat $dLat, Long $dLong";
          isLoading = false;
        });
      }
    }
  }

  // Step 10 — reverse geocoding koordinat menjadi alamat.
  Future<void> getAddressFromLongLat(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks[0];
        setState(() {
          strAlamat =
              "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}"
                  .replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '')
                  .replaceAll(RegExp(r',\s*,+'), ',');
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        strAlamat =
            "Lat: ${position.latitude.toStringAsFixed(5)}, Long: ${position.longitude.toStringAsFixed(5)}";
        isLoading = false;
      });
    }
  }

  // Step 11 — pengiriman payload ke Cloud Firestore.
  Future<void> submitAbsen(String alamat, String nama, String status) async {
    setState(() => isSubmitting = true);
    _showLoaderDialog();

    try {
      await dataCollection.add({
        'name': nama.trim(),
        'address': alamat.isEmpty ? 'Lokasi tidak terekam' : alamat,
        'description': status,
        'datetime': strDateTime,
        'latitude': dLat,
        'longitude': dLong,
        'type': 'attendance',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      // Kembali ke HomeScreen setelah sukses
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => isSubmitting = false);
      _showSnackBar("Gagal menyimpan presensi: $e", Icons.error_outline);
    }
  }

  void _onSubmitPressed() {
    if (isSubmitting) return;
    if (nameController.text.trim().isEmpty) {
      _showSnackBar("Nama wajib diisi.", Icons.warning_amber_rounded);
      return;
    }
    if (widget.image == null) {
      _showSnackBar(
        "Ambil selfie terlebih dahulu sebelum mengirim presensi.",
        Icons.warning_amber_rounded,
      );
      return;
    }
    submitAbsen(strAlamat, nameController.text, strStatus);
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
            Expanded(child: Text("Menyimpan presensi...")),
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
      appBar: AppBar(title: const Text("Attendance Record")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _buildSelfiePreview()),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Lengkap",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoTile(
                icon: Icons.access_time,
                label: "Waktu Presensi",
                value: strDateTime,
              ),
              _buildStatusTile(),
              _buildInfoTile(
                icon: Icons.place_outlined,
                label: "Alamat",
                value: isLoading ? "Mencari lokasi..." : strAlamat,
              ),
              _buildInfoTile(
                icon: Icons.my_location,
                label: "Koordinat",
                value: "Lat ${dLat.toStringAsFixed(5)}, "
                    "Long ${dLong.toStringAsFixed(5)}",
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: isLoading ? null : getGeoLocationPosition,
                icon: const Icon(Icons.refresh),
                label: const Text("Perbarui Lokasi"),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: isSubmitting ? null : _onSubmitPressed,
                icon: const Icon(Icons.send),
                label: Text(isSubmitting ? "Mengirim..." : "Kirim Presensi"),
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

  Widget _buildSelfiePreview() {
    return DottedBorder(
      borderType: BorderType.RRect,
      radius: const Radius.circular(24),
      dashPattern: const [8, 4],
      color: Colors.blueAccent,
      strokeWidth: 2,
      child: SizedBox(
        width: 240,
        height: 300,
        child: widget.image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.face_retouching_natural,
                    size: 64,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "Verifikasi wajah dulu untuk melanjutkan presensi",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CameraScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Buka Kamera"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A008F),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(widget.image!.path),
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  /// Status kehadiran ditampilkan sebagai badge berwarna supaya siswa langsung
  /// tahu apakah presensinya terhitung tepat waktu atau terlambat.
  Widget _buildStatusTile() {
    final Color statusColor = switch (strStatus) {
      "Attend" => Colors.green.shade700,
      "Late" => Colors.orange.shade800,
      _ => Colors.blueGrey.shade600,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 20, color: statusColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Status",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
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
                  strStatus,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1A008F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
