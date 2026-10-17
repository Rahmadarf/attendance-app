# Folder model TFLite

Letakkan file model pengenalan wajah di sini dengan nama persis:

```
assets/models/mobilefacenet.tflite
```

Spesifikasi yang harus dipenuhi model tersebut:

| Properti | Nilai |
| --- | --- |
| Input | `1 × 112 × 112 × 3`, float32, skala `[-1, 1]` |
| Output | `1 × 192`, float32 (embedding) |
| Ukuran | sekitar 5 MB |

Ini varian MobileFaceNet yang paling umum dipakai. Minta file-nya ke guru pembimbing, atau unduh dari
sumber yang Anda percaya.

Selama file ini belum ada, aplikasi tetap bisa dijalankan: layar pendaftaran wajah dan presensi akan
menampilkan pesan "Model pengenalan wajah belum terpasang" dan tidak crash. Lihat
`lib/utils/face_detection/face_embedder.dart`.

Jika model Anda punya dimensi output berbeda (misalnya 128 bukan 192), sesuaikan konstanta
`kEmbeddingLength` di `lib/utils/face_detection/face_embedder.dart`.
