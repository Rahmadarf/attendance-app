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
5. **`LocationSettings` menggantikan `desiredAccuracy`.** Modul memanggil
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

## Status verifikasi

| Perintah | Hasil |
| --- | --- |
| `flutter analyze` | Lolos, tanpa isu |
| `flutter test` | Lolos, 5 test |
| `flutter build apk` | **Belum pernah berhasil dijalankan** |

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
