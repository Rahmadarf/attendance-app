/// Spesifikasi model pengenalan wajah, dipisahkan dari kode yang memuatnya.
///
/// File ini sengaja tidak mengimpor apa pun. `face_embedder.dart` menarik
/// `tflite_flutter`, yang berarti `dart:ffi`, yang tidak ada di browser. Kalau
/// konstanta di bawah ikut tinggal di sana, implementasi web yang hanya butuh
/// angka 192 akan menyeret seluruh TFLite ke dalam kompilasi web dan
/// menggagalkannya.
library;

/// Lokasi model di dalam aset aplikasi. Lihat `assets/models/README.md`.
const String kFaceModelAsset = 'assets/models/mobilefacenet.tflite';

/// Panjang vektor keluaran model. Ganti bila model Anda mengeluarkan 128.
const int kEmbeddingLength = 192;

/// Sisi input model MobileFaceNet: 112 x 112 piksel.
const int kFaceInputSize = 112;

/// Bounding box dari ML Kit memotong terlalu rapat di dahi dan dagu, sedangkan
/// MobileFaceNet dilatih dengan potongan yang sedikit lebih longgar. Margin ini
/// melebarkan kotak 20% ke setiap arah.
const double kFaceCropMargin = 0.20;

/// Pesan yang ditampilkan ke pengguna bila file model belum disiapkan.
const String kModelMissingMessage =
    'Model pengenalan wajah belum terpasang. Letakkan file '
    'mobilefacenet.tflite di assets/models/ lalu jalankan ulang aplikasi.';
