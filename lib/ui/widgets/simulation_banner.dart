import 'package:flutter/material.dart';

/// Penanda bahwa lapisan AI sedang digantikan mode simulasi.
///
/// Sengaja mencolok dan tidak bisa ditutup. Aplikasi ini dipakai untuk demo
/// penilaian, jadi tidak boleh ada kemungkinan mode simulasi tertukar dengan
/// pengenalan wajah sungguhan — baik oleh penguji maupun oleh yang membuatnya.
class SimulationBanner extends StatelessWidget {
  final String message;

  const SimulationBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.science_outlined,
                size: 18,
                color: Colors.black87,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
