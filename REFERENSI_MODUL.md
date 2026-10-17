# Referensi Modul — Flutter Intermediate: Smart Attendance App

Sumber: https://idnsolo.com/auth/course-attendance-app (IDN Boarding School Solo, kelas XI RPL).
Dokumen ini merangkum 15 langkah modul beserta pemetaannya ke file di repositori ini.

## Empat pilar teknologi

| Pilar | Implementasi |
| --- | --- |
| On-device AI | Google ML Kit Face Detection, inferensi lokal tanpa latensi jaringan |
| Geolocation | Geolocator, koordinat latitude/longitude akurasi tinggi |
| Reverse geocoding | Package `geocoding`, koordinat menjadi alamat terbaca manusia |
| Cloud database | Cloud Firestore, penyimpanan realtime dengan server timestamp |

## Pemetaan langkah ke file

| Step | Materi | File |
| --- | --- | --- |
| 1 | Arsitektur & struktur folder modular | struktur `lib/ui`, `lib/utils`, `assets/` |
| 2 | Dependencies & aset | `pubspec.yaml`, `assets/images/`, `assets/raw/` |
| 3 | Permission Android & minSdk | `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts` |
| 4 | Firebase & inisialisasi Firestore | `lib/main.dart` |
| 5 | HomeScreen & reusable menu card | `lib/ui/home_screen.dart` |
| 6 | Kamera depan & lifecycle controller | `lib/ui/attend/camera_screen.dart` |
| 7 | Wrapper Vision & ML Kit | `lib/utils/face_detection/vision.dart`, `lib/utils/face_detection/google_ml_kit.dart` |
| 8 | Scanner Lottie, DottedBorder, validasi wajah | `lib/ui/attend/camera_screen.dart` |
| 9 | Izin & koordinat GPS | `lib/ui/attend/attend_screen.dart` |
| 10 | Reverse geocoding alamat | `lib/ui/attend/attend_screen.dart` |
| 11 | Logika jam presensi & submit Firestore | `lib/ui/attend/attend_screen.dart` |
| 12 | Modul izin & sakit | `lib/ui/absent/absent_screen.dart` |
| 13 | Riwayat realtime StreamBuilder | `lib/ui/attendance_history/attendance_history_screen.dart` |
| 14 | Avatar color hash & CRUD edit/delete | `lib/ui/attendance_history/attendance_history_screen.dart` |
| 11 | Aturan jam presensi (fungsi murni, teruji) | `lib/utils/attendance_status.dart` |
| 15 | Security rules, debugging, build APK | bagian "Build & deploy" di bawah |

## Skema dokumen Firestore

Koleksi: `attendance`.

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `name` | string | Nama siswa |
| `address` | string | Alamat hasil reverse geocoding, `-` untuk pengajuan izin |
| `description` | string | `Attend` / `Late` / `Leave` untuk presensi; kategori izin untuk perizinan |
| `datetime` | string | Waktu presensi, atau rentang `from - until` untuk perizinan |
| `latitude` | double | Hanya pada dokumen presensi |
| `longitude` | double | Hanya pada dokumen presensi |
| `type` | string | `attendance` atau `permission` |
| `created_at` | timestamp | `FieldValue.serverTimestamp()` |

## Aturan status kehadiran (Step 11)

- Sebelum atau tepat pukul 08:30 → `Attend`
- 08:31 sampai 18:00 → `Late`
- Di luar jam tersebut → `Leave`

## Security rules Firestore (Step 15)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /attendance/{document} {
      allow read, write: if true; // Mode belajar sekolah
    }
  }
}
```

Rules ini membuka baca-tulis untuk siapa pun. Modul memakainya demi kemudahan belajar; jangan dipakai di
aplikasi produksi.

## Build & deploy (Step 15)

```bash
# Opsi 1: APK split per arsitektur CPU (~18 MB, direkomendasikan)
flutter build apk --split-per-abi

# Opsi 2: APK universal
flutter build apk
```

Output: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## Catatan penyimpangan dari modul

1. **Namespace.** Modul memakai `com.example.attendance_app`. Proyek ini sudah dibuat dengan
   `com.kumar.attendance_app` dan nilai tersebut dipertahankan.
2. **Gradle Kotlin DSL.** Modul menulis contoh `android/app/build.gradle` bergaya Groovy, sedangkan proyek
   ini memakai `build.gradle.kts`. Isi konfigurasi disesuaikan, maksudnya sama.
3. **Kredensial Firebase.** `lib/main.dart` memakai `FirebaseOptions` persis seperti contoh modul, yang
   menunjuk project `idn-attendance-app-6ceac` milik modul. Karena opsi diisi eksplisit, `google-services.json`
   tidak wajib ada. Jika ingin database sendiri, buat project di Firebase Console lalu ganti nilainya.
4. **Aset placeholder.** File `assets/images/*.png` dan `assets/raw/face_id_ring.json` di repositori ini
   adalah placeholder yang dibuat sendiri, bukan aset resmi dari modul. Ganti dengan aset dari guru bila ada.
5. **`minSdk` dinaikkan ke 26.** Modul menetapkan 21 (syarat ML Kit dan camera), tetapi `tflite_flutter`
   menuntut API 26. Lihat bagian "Modifikasi besar: pengenalan wajah siswa" di bawah.
6. **`LocationSettings` menggantikan `desiredAccuracy`.** Modul memanggil
   `Geolocator.getCurrentPosition(desiredAccuracy: ...)`. Parameter itu sudah usang pada geolocator 13, jadi
   dipakai `locationSettings: LocationSettings(accuracy: LocationAccuracy.high)` yang setara.

## Tambahan di luar modul

Modul hanya menampilkan potongan kode kunci, jadi beberapa hal berikut ditambahkan supaya aplikasinya utuh
dan tidak mudah rusak saat dipakai:

- **Izin iOS** di `ios/Runner/Info.plist` (`NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`,
  `NSPhotoLibraryUsageDescription`). Modul hanya membahas sisi Android.
- **Lifecycle kamera** di `camera_screen.dart`: `WidgetsBindingObserver` melepas dan menginisialisasi ulang
  `CameraController` saat aplikasi berpindah ke background, mencegah preview beku saat kembali.
- **Guard submit ganda** di `attend_screen.dart` dan `absent_screen.dart`, agar satu ketukan tidak membuat
  dua dokumen Firestore.
- **Validasi rentang tanggal** pada pengajuan izin: tanggal selesai tidak boleh mendahului tanggal mulai.
- **Badge status berwarna** serta **filter Semua / Presensi / Izin** pada layar riwayat.
- **Layar kosong dan layar error** yang eksplisit, bukan hanya `CircularProgressIndicator` tanpa akhir.
- **`lib/utils/attendance_status.dart`**: aturan jam Step 11 dipisah jadi fungsi murni sehingga bisa diuji.
  Lihat `test/attendance_status_test.dart`.

## Modifikasi besar: pengenalan wajah siswa

Modul aslinya hanya melakukan **face detection** — ML Kit memastikan ada wajah, lalu siswa mengetik namanya
sendiri. Aplikasi ini sudah ditingkatkan menjadi **face recognition**: siswa mendaftarkan wajahnya sekali,
lalu saat presensi cukup menekan satu tombol dan aplikasi menentukan sendiri siapa yang hadir. Tidak ada
input nama lagi di layar presensi.

ML Kit tidak bisa melakukan identifikasi; dia menjawab "ada wajah di koordinat ini", bukan "ini Rahmad".
Karena itu ditambahkan satu lapisan baru:

```
wajah terdeteksi (ML Kit)
  → potong area wajah, ubah ke 112×112
  → MobileFaceNet (TFLite) → vektor 192 angka  ["embedding"]
  → cocokkan ke embedding semua siswa (cosine similarity)
  → skor tertinggi ≥ ambang batas ? itu siswanya : tolak
```

### Alur baru

```
Pendaftaran (sekali per siswa)
  HomeScreen → Data Wajah Siswa → Daftarkan Wajah
    → 3 pose (depan, kiri, kanan) → 3 embedding + 1 thumbnail → koleksi `students`

Presensi harian
  HomeScreen → Attendance Record (langsung kamera)
    → tekan "Absen Sekarang"
    → cocok   : layar konfirmasi dengan nama terisi otomatis → koleksi `attendance`
    → tidak   : dialog "Wajah Tidak Dikenali", presensi dibatalkan
```

### Koleksi `students`

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `name` | string | Nama siswa |
| `nis` | string | Nomor induk, pembeda bila ada nama yang sama |
| `photo_base64` | string | Thumbnail 112×112 pose depan |
| `templates` | array of map | `[{ pose: "front", vector: [192 double] }, ...]` |
| `created_at` | timestamp | `FieldValue.serverTimestamp()` |

Dua keputusan desain yang layak disebut saat presentasi:

- **`templates` berupa array berisi map, bukan array berisi array.** Firestore menolak array yang langsung
  memuat array. Membungkus setiap vektor dalam map adalah jalan resminya, sekaligus memberi tempat untuk
  label `pose`.
- **Foto disimpan base64 di Firestore, bukan di Firebase Storage.** Thumbnail 112×112 hanya sekitar 8 KB dan
  tiga embedding sekitar 4,6 KB, sementara batas satu dokumen Firestore 1 MiB. Jadi semuanya muat dengan
  lega tanpa perlu mengaktifkan Firebase Storage yang menuntut upgrade billing.

### Field tambahan pada koleksi `attendance`

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `student_id` | string | ID dokumen siswa hasil pengenalan |
| `nis` | string | Disalin dari dokumen siswa |
| `face_similarity` | double | Skor kemiripan saat presensi, sebagai bukti |

Dokumen riwayat lama yang belum punya field ini tetap terbaca — semuanya dibaca sebagai opsional.

### File baru

| File | Isi |
| --- | --- |
| `lib/models/student.dart` | `Student`, `FaceTemplate`, `FacePose` |
| `lib/services/student_repository.dart` | Akses koleksi `students` |
| `lib/utils/face_detection/face_matcher.dart` | `l2Normalize`, `cosineSimilarity`, `identify` — Dart murni |
| `lib/utils/face_detection/face_cropper.dart` | JPEG → crop → 112×112 → tensor ternormalisasi |
| `lib/utils/face_detection/face_embedder.dart` | Pembungkus TFLite, singleton, lazy load |
| `lib/utils/face_detection/face_pipeline.dart` | Rangkaian lengkap foto → embedding, dipakai dua layar |
| `lib/ui/widgets/face_camera_view.dart` | Widget kamera yang dipakai ulang layar presensi dan pendaftaran |
| `lib/ui/students/student_list_screen.dart` | Daftar siswa terdaftar |
| `lib/ui/students/student_enroll_screen.dart` | Wizard 3 pose |
| `test/face_matcher_test.dart` | 12 test untuk logika pencocokan |

### Ambang batas kemiripan

`kFaceMatchThreshold` di `lib/utils/face_detection/face_matcher.dart` bernilai **0.70**. Skor asli
ditampilkan di layar konfirmasi dan di dialog penolakan, jadi penyetelannya punya dasar data:

- Wajah orang lain ikut lolos → naikkan.
- Wajah yang sah sering ditolak → turunkan.

### Detail teknis yang mudah terlewat

- **`img.bakeOrientation`** di `face_cropper.dart` menerapkan rotasi EXIF. Tanpa ini, foto dari sebagian
  perangkat Android masuk ke model dalam keadaan miring 90° dan skornya selalu rendah tanpa sebab yang jelas.
- **Margin crop 20%** melebarkan bounding box ML Kit, yang memotong terlalu rapat di dahi dan dagu
  dibandingkan data latih MobileFaceNet.
- **Skor siswa diambil nilai tertinggi di antara 3 template, bukan rata-rata.** Cukup satu pose yang cocok
  untuk membuktikan identitas; pose lain yang berbeda jauh justru menyeret rata-rata ke bawah tanpa alasan.
- **`IsolateInterpreter`** menjalankan inferensi di isolate terpisah agar preview kamera tidak tersendat.
- **Pendaftaran dan presensi memakai `face_pipeline.dart` yang sama.** Kalau keduanya memotong wajah dengan
  cara berbeda, embedding-nya tidak akan pernah cocok.
- **Nama tidak bisa diedit di riwayat.** Nilainya terikat ke `student_id`; pengeditan bebas akan membuat
  dokumen presensi menunjuk siswa yang berbeda dari namanya.

## Uji keaktifan wajah (liveness)

Pengenalan wajah saja masih bisa ditipu: sodorkan foto cetak atau foto di layar ponsel lain, dan sistem akan
mengenalinya dengan senang hati. Karena itu presensi sekarang didahului **uji keaktifan**.

Pengguna harus menyelesaikan dua tantangan sebelum fotonya diambil:

| Tantangan | Yang harus terjadi | Isyarat ML Kit |
| --- | --- | --- |
| Kedipan | mata terbuka → terpejam → terbuka lagi | `leftEyeOpenProbability`, `rightEyeOpenProbability` |
| Gerakan kepala | menoleh melewati 22° → kembali ke bawah 10° | `headEulerAngleY` |

Urutan kedua tantangan **diacak** tiap percobaan, supaya rekaman video satu sesi tidak bisa diputar ulang
pada sesi berikutnya. Setiap tantangan punya batas waktu 12 detik; habis waktu berarti sesi gagal dan harus
dimulai ulang.

Foto baru diambil otomatis setelah kedua tantangan lulus — pengguna hanya menekan satu tombol di awal. Uji
keaktifan dijalankan **sebelum** pengenalan identitas, karena tidak ada gunanya mengenali wajah dari foto
cetak.

### Kenapa butuh stream frame, bukan satu foto

`takePicture()` hanya memberi satu gambar diam, sedangkan kedipan dan gerakan kepala adalah perubahan antar
waktu. Jadi selama sesi berlangsung, `startImageStream` dinyalakan dan setiap frame diperiksa ML Kit.

Tiga hal teknis yang menyertainya:

- **Format frame.** ML Kit hanya menerima `nv21` di Android dan `bgra8888` di iOS, jadi `imageFormatGroup`
  pada `CameraController` disesuaikan per platform. `takePicture()` tetap menghasilkan JPEG.
- **Rotasi.** Orientasi sensor harus dikompensasi dengan orientasi perangkat, dan arah kompensasinya berbeda
  antara kamera depan dan belakang karena citra kamera depan tercermin. Tanpa ini, ML Kit mencari wajah pada
  citra miring dan sering tidak menemukan apa pun. Lihat `camera_image_converter.dart`.
- **Pembatasan laju.** ML Kit lebih lambat daripada laju frame kamera, jadi frame yang datang saat deteksi
  masih berjalan dilewati. Tanpa ini preview tersendat dan frame menumpuk di memori.

Stream juga wajib dimatikan sebelum `takePicture()`, karena plugin camera tidak bisa melakukan keduanya
bersamaan.

### File baru untuk uji keaktifan

| File | Isi |
| --- | --- |
| `lib/utils/face_detection/liveness_session.dart` | State machine tantangan — Dart murni, tanpa kamera |
| `lib/utils/face_detection/camera_image_converter.dart` | `CameraImage` → `InputImage` + ekstraksi isyarat wajah |
| `lib/ui/widgets/liveness_face_scanner.dart` | Tampilan panduan, progres, dan pemicu foto otomatis |
| `test/liveness_session_test.dart` | 13 test, termasuk kasus foto mata tertutup dan batas waktu |

`LivenessSession` sengaja dibuat Dart murni: masuk `FaceSignals`, keluar `LivenessUpdate`. Waktu pun
diterima sebagai parameter, bukan dibaca dari `DateTime.now()` di dalam, sehingga batas waktu bisa diuji
tanpa benar-benar menunggu 12 detik.

### Detail yang layak disorot saat presentasi

- **Kedipan diperiksa tiga tahap, bukan satu.** Kalau yang diperiksa hanya "mata terpejam", foto orang
  dengan mata tertutup akan langsung lolos. Ada test khusus untuk celah ini.
- **Gerakan kepala menuntut kembali ke tengah.** Tanpa syarat itu, foto yang dimiringkan bisa memenuhi
  tantangan tanpa gerakan apa pun.
- **Arah tolehan tidak dipersoalkan, hanya besarnya.** Tanda `headEulerAngleY` bergantung pada orientasi
  sensor kamera depan tiap perangkat, jadi menuntut arah tertentu akan menolak pengguna pada sebagian ponsel.
- **Detektor terpisah untuk mode stream.** `Vision.livenessDetector()` memakai `FaceDetectorMode.fast` tanpa
  landmark, karena di sini yang dibutuhkan hanya peluang mata dan sudut kepala. Mode `accurate` terlalu berat
  untuk tiap frame.

### Kenapa pendaftaran tidak memakai uji keaktifan

Pendaftaran wajah dilakukan sekali dan diawasi guru, sedangkan presensi terjadi setiap hari tanpa pengawasan.
Selain itu wizard pendaftaran sudah menuntut tiga pose berbeda yang diverifikasi lewat `headEulerAngleY`,
yang dengan sendirinya tidak bisa dipenuhi satu foto cetak.

### Batasan yang perlu disebut saat presentasi

| Batasan | Keterangan |
| --- | --- |
| Video rekaman orang asli masih berpeluang lolos | Uji keaktifan menutup serangan foto diam, bukan serangan video. Pengacakan urutan tantangan mempersulitnya, tapi tidak menutupnya. Anti-spoofing sungguhan butuh model khusus, misalnya deteksi tekstur kulit atau kamera kedalaman. |
| Masker wajah realistis tidak terdeteksi | Di luar jangkauan ML Kit. |
| Wajah sangat mirip, misalnya saudara kembar | Cosine similarity bisa keliru. Ambang lebih tinggi menurunkan risiko tapi menaikkan penolakan wajah yang sah. |
| Pencahayaan buruk menurunkan skor | Pendaftaran 3 pose membantu, tidak menghilangkan. Daftarkan wajah pada pencahayaan yang mirip ruang kelas. |
| Data wajah adalah data biometrik | Yang tersimpan vektor angka, bukan foto utuh, dan vektor itu tidak bisa dibalik menjadi foto. Tapi security rules modul masih `allow read, write: if true`, jadi koleksi `students` terbuka bagi siapa pun yang punya konfigurasi Firebase-nya. |
| Menu pendaftaran terbuka untuk siapa saja | **Sudah ditangani** — menu Data Wajah Siswa dikunci PIN admin. Lihat bagian "Kunci PIN untuk menu Data Wajah Siswa" beserta batasannya. |

## Kunci PIN untuk menu Data Wajah Siswa

Siapa pun yang bisa mendaftarkan wajah bisa mengabsenkan dirinya sebagai orang lain. Karena itu menu Data
Wajah Siswa — tempat pendaftaran dan penghapusan wajah — dikunci PIN admin.

Menu lain tidak dikunci: presensi, pengajuan izin, dan riwayat tetap bebas dipakai siswa.

### Cara kerjanya

```
HomeScreen → Data Wajah Siswa (ikon gembok)
  → AdminGate
      PIN belum pernah dibuat  → layar "Buat PIN Admin"
      sudah ada PIN            → layar "Masukkan PIN Admin"
      sesi masih terbuka       → langsung ke StudentListScreen
```

Dokumen `settings/admin` di Firestore:

| Field | Tipe | Keterangan |
| --- | --- | --- |
| `pin_salt` | string | 32 karakter heksadesimal, acak per pemasangan |
| `pin_hash` | string | SHA-256 PIN yang sudah di-salt, diulang 50.000 kali |
| `updated_at` | timestamp | `FieldValue.serverTimestamp()` |

PIN aslinya tidak pernah ditulis ke mana pun.

### Keputusan desain yang layak dijelaskan

- **Tidak ada PIN bawaan di dalam kode.** Saat pertama dipakai, aplikasi menawarkan pembuatan PIN. PIN yang
  ditanam di source akan ikut terbaca siapa pun yang membuka repositori ini.
- **Salt per pemasangan.** Dua sekolah yang kebetulan memakai PIN sama menghasilkan hash berbeda, sehingga
  tabel tebakan yang sudah jadi tidak bisa dipakai ulang.
- **Hash diulang 50.000 kali.** PIN enam digit hanya punya satu juta kemungkinan; satu kali SHA-256 terlalu
  cepat ditebak habis. Pengulangan membuat tiap percobaan jauh lebih mahal, tapi tidak terasa bagi pengguna
  yang hanya menebak sekali.
- **Perbandingan waktu tetap.** Operator `==` pada String berhenti di karakter pertama yang berbeda,
  sehingga lama perbandingannya membocorkan seberapa banyak awalan yang sudah benar. `_constantTimeEquals`
  selalu memeriksa seluruh karakter.
- **Jeda setelah 5 kali salah.** Tombolnya dikunci 30 detik, agar PIN tidak bisa ditebak satu per satu
  tanpa henti.
- **Sesi kedaluwarsa 10 menit**, dan diperpanjang tiap kali kembali dari layar pendaftaran. Cukup panjang
  untuk mendaftarkan sekelas siswa berturut-turut, cukup pendek agar HP yang ditinggal di meja tidak terus
  terbuka. Ada juga tombol gembok di AppBar untuk mengunci seketika.
- **PIN disimpan di Firestore, bukan di perangkat**, supaya PIN yang dibuat guru di satu HP berlaku juga di
  HP lain.

### Batasan yang harus disebut jujur

Security rules Firestore masih `allow read, write: if true` mengikuti modul. Artinya siapa pun yang memegang
konfigurasi Firebase aplikasi ini bisa membaca `pin_hash` dan `pin_salt`, lalu menebak satu juta kemungkinan
PIN secara offline tanpa terkena jeda 30 detik. Jadi kunci ini **mencegah orang iseng yang memegang HP**,
bukan penyerang yang punya akses database.

Untuk dipakai sungguhan, rules harus diperketat sehingga `settings/admin` tidak bisa dibaca klien, dan
verifikasi PIN dipindahkan ke server, misalnya lewat Cloud Functions.

### File terkait

| File | Isi |
| --- | --- |
| `lib/utils/admin_pin.dart` | Hash, salt, verifikasi, perbandingan waktu tetap — Dart murni |
| `lib/services/admin_session.dart` | Status terbuka beserta kedaluwarsanya |
| `lib/services/admin_repository.dart` | Baca dan tulis `settings/admin` |
| `lib/ui/admin/admin_gate.dart` | Layar kunci, pembuatan PIN pertama, jeda percobaan |
| `test/admin_pin_test.dart` | 20 test untuk hash dan sesi |

## Menjalankan di Chrome (mode simulasi)

Aplikasi ini bisa dijalankan di browser untuk menguji UI, alur navigasi, webcam, GPS, dan Cloud Firestore
tanpa perlu HP Android.

```bash
flutter run -d chrome
```

Kamera butuh *secure context*, dan `localhost` termasuk aman, jadi webcam bekerja normal. Chrome akan
meminta izin kamera saat layar pendaftaran atau presensi dibuka.

### Apa yang jalan dan apa yang tidak

| Bagian | Di Chrome |
| --- | --- |
| UI, navigasi, seluruh layar | Jalan |
| Webcam, ambil foto | Jalan lewat `camera_web` |
| GPS / geolocation | Jalan |
| Cloud Firestore, baca dan tulis | Jalan |
| ML Kit face detection | **Tidak ada implementasi web** |
| MobileFaceNet / TFLite | **Mustahil** — butuh `dart:ffi` |
| Uji keaktifan wajah | Dilewati, karena butuh ML Kit |

### Bagaimana itu bisa dikompilasi

`tflite_flutter` mengimpor `dart:ffi`, dan keberadaannya saja sudah menggagalkan `flutter build web` dengan
pesan `Dart library 'dart:ffi' is not available on this platform`. Jadi tidak cukup menghindari
memanggilnya — paketnya harus benar-benar lenyap dari graph kompilasi web.

Caranya dengan **conditional import**:

```dart
// lib/utils/face_detection/face_recognition.dart
import 'face_recognition_web.dart'
    if (dart.library.io) 'face_recognition_io.dart' as impl;
```

Web tidak punya `dart.library.io`, jadi mendapat versi simulasi; Android dan iOS mendapat versi sungguhan.

Agar itu bekerja, tidak boleh ada tipe milik ML Kit atau `dart:io` yang menembus sampai lapisan UI. Karena
itu dibuat antarmuka `FaceRecognitionBackend` di `face_recognition_types.dart`, dan seluruh layar presensi
memanggil antarmuka itu saja. Ada tiga perubahan pendukung:

- `kEmbeddingLength` dan konstanta model lain dipindah ke `face_model_spec.dart` yang tidak mengimpor apa
  pun. Sebelumnya konstanta itu tinggal di `face_embedder.dart`, sehingga implementasi web yang hanya butuh
  angka 192 ikut menyeret seluruh TFLite.
- `face_camera_view.dart` memakai `defaultTargetPlatform`, bukan `Platform.isAndroid`, karena `dart:io`
  tidak ada di web.
- Pembacaan file memakai `XFile.readAsBytes()`, bukan `File(path).readAsBytes()`, dengan alasan yang sama.

### Apa yang disimulasikan

| Hal | Di Chrome |
| --- | --- |
| Foto siswa | **Asli** — diambil dari webcam, dipotong tengah dan diperkecil ke 112×112 dengan package `image` |
| Embedding | Angka acak sepanjang 192 yang sudah dinormalisasi. Bentuk dokumennya sama persis dengan versi Android, isinya tidak berarti |
| Pencocokan | Diganti dialog pemilih siswa. Embedding acak tidak akan pernah cocok, jadi lebih jujur meminta penguji memilih daripada memunculkan nama hasil kebetulan |
| Uji keaktifan | Dilewati. Tombolnya berbunyi "Absen Tanpa Uji Keaktifan" |

Setiap layar yang terdampak menampilkan `SimulationBanner` berwarna kuning yang tidak bisa ditutup, dan
dokumen presensi hasil simulasi ditandai dua kali di Firestore: `is_simulation: true` dan
`face_similarity: -1.0`. Nilai negatif dipilih, bukan angka yang tampak masuk akal seperti 0,93, supaya
data uji gampang dikenali dan dibersihkan.

### Yang sudah diverifikasi di browser

`flutter build web` berhasil, aplikasi terbuka, keempat menu tampil, dan layar Data Wajah Siswa berhasil
terhubung ke Firestore — muncul empty state, bukan pesan error. Banner mode simulasi dan progres tiga pose
tampil benar. Penolakan izin kamera ditangani dengan layar error dan tombol "Coba Lagi", bukan crash.

## Status verifikasi

| Perintah | Hasil |
| --- | --- |
| `flutter analyze` | Lolos, tanpa isu |
| `flutter test` | Lolos, 53 test |
| `flutter build web` | Berhasil, dan aplikasinya sudah dibuka di browser |
| `flutter build apk` | **Belum pernah berhasil dijalankan** |

Pengenalan wajah belum pernah diuji ujung-ke-ujung, karena kamera dan TFLite tidak tersedia di emulator web
maupun macOS. Uji berikut harus dijalankan di HP Android:

1. Daftarkan 2–3 orang berbeda lewat menu Data Wajah Siswa.
2. Presensi sebagai orang pertama, pastikan namanya benar, catat skornya.
3. Presensi sebagai orang kedua, pastikan tidak tertukar dengan orang pertama.
4. Coba wajah yang belum terdaftar, harus ditolak.
5. Periksa Firestore Console: dokumen `attendance` baru punya `student_id` dan `face_similarity`.

Khusus uji keaktifan wajah:

6. Sodorkan foto cetak atau foto di layar ponsel lain — tantangan kedipan tidak boleh pernah lulus.
7. Diamkan wajah tanpa berkedip sampai 12 detik — sesi harus gagal dan menawarkan "Coba Lagi".
8. Keluar dari bingkai di tengah sesi — instruksi harus berubah menjadi "Wajah tidak terlihat".
9. Jalankan sesi beberapa kali dan perhatikan urutan tantangan, harus berganti-ganti.
10. Tekan tombol home saat sesi berjalan lalu kembali — preview harus hidup lagi, tidak hitam.

### Kenapa build APK belum bisa

Mesin ini belum punya Android SDK yang lengkap. `android/local.properties` menunjuk
`sdk.dir=/opt/homebrew/Caskroom/android-platform-tools/37.0.1`, dan isi direktori itu hanya `platform-tools/`
(sekadar `adb`). Tidak ada `cmdline-tools`, `platforms`, `build-tools`, maupun `ndk`, sehingga perintah
`sdkmanager` pun belum tersedia dan lisensi NDK tidak pernah bisa disetujui.

Langkah perbaikan, dijalankan sendiri oleh pemilik mesin karena melibatkan persetujuan lisensi Android SDK:

```bash
brew install --cask android-commandlinetools
sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;28.2.13676358"
```

Setelah itu arahkan `sdk.dir` di `android/local.properties` ke SDK root yang baru, lalu jalankan
`flutter doctor` untuk memastikan baris "Android toolchain" sudah hijau.
