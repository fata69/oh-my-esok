# Esok

Aplikasi jadwal harian Android untuk pemakaian pribadi. Satu hari per layar,
tanpa akun, tanpa cloud.

- Paket: `com.habib.jadwal`
- Versi: **1.9.0** (build 11)
- Flutter 3.50 / Dart 3.14
- `minSdk 24`, `compileSdk 37`, `targetSdk 36`
- Target utama: Samsung Galaxy A56 5G

## Fitur

- Daftar tugas per hari dengan judul, jam, dan catatan
- Navigasi hari: panah, geser dua arah, dan kalender bulan
- Baris "besok" / jalan kembali ke hari ini
- Quick add di kolom judul: `besok`, `lusa`, `3 hari lagi`, `jam 4 sore`
- Pemilih jam roda (jam dan menit) dengan tombol "Sekarang"
- Pemilih tanggal dengan tanggal terpilih berupa outline
- Centang selesai, plus undo untuk hapus
- Notifikasi terjadwal untuk tugas yang punya jam; pengingat tidak mengubah
  status tugas
- Pengingat awal (30 menit / 1 jam / 3 jam / 1 hari) dan pengaturan alarm
  presisi serta optimasi baterai
- Widget 4x2 menampilkan tugas besok; centang di widget langsung tersinkron
- Widget uang 2×2 dan 4×1: pengeluaran hari ini dan bulan ini; tombol
  sembunyikan nominal di Setelan → Widget
- Widget mengikuti tema terang/gelap sistem Android
- Tiga tab: **Hari**, **Uang**, **Setelan**
- Tema **Terang · Sistem · Gelap**, ikut sistem secara default, tersimpan
- Buku kas: pengeluaran, pemasukan, dan pindah antar dompet; ringkasan bulanan
  serta riwayat per hari
- **Total dana** di tab Uang, saldo per dompet dihitung dari dana awal +
  transaksi; **koreksi saldo** dari Sumber dana
- Warna nominal: merah untuk keluar, hijau untuk masuk, tanda +/− selalu ada
- Ringkasan uang hari itu di tab Hari
- Kategori dengan 15 ikon SVG (fallback huruf), termasuk Minuman; sumber dana
  dengan jenis tunai/bank/e-wallet
- Form transaksi baru: grid kategori, dompet + catatan, baris jumlah, tanggal
  cepat, keypad, dan aksi bawah
- Pindai struk/mutasi dengan AI: arah otomatis, pilih baris mutasi, dan
  rincian barang
- Widget memilih hari terdekat yang punya catatan dan membuka layar yang tepat
- Ekspor JSON/CSV, impor JSON dengan pratinjau, dan hapus semua data
- **Cadangan otomatis** harian ke `Download/Esok/esok-backup.json`; hanya
  ditulis bila data berubah; pulihkan saat pasang ulang
- Efek suara untuk centang tugas, transaksi, dan widget; halaman Suara untuk
  memilih nada atau mengimpor suara sendiri
- Menu **Catatan rilis** untuk melihat versi dan changelog

## Build

```powershell
flutter pub get
flutter build apk --release --split-per-abi
```

APK per-ABI:
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (untuk A56/HP ARM64)
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk` (untuk emulator x86_64, termasuk MuMu)

Salinan siap pasang: `Esok-1.9.0-arm64-v8a.apk`, `Esok-1.9.0-armeabi-v7a.apk`, `Esok-1.9.0-x86_64.apk`.

Release memakai debug signing (cukup untuk pemakaian pribadi).

## Troubleshooting keyboard

Jika Gboard tidak muncul padahal kursor ada, itu bug proses Gboard (juga
terjadi di aplikasi lain). Mulai ulang Gboard atau HP, lalu buka editor lagi.
Aplikasi meminta ulang IME saat kolom catatan mendapat fokus sebagai jaring
pengaman. Samsung Keyboard tetap bisa dipakai sebagai alternatif. Nominal
transaksi memakai keypad sendiri.

## Struktur

```
lib/
  data/      model tugas, kategori, dompet, transaksi + SQLite/DAO
  state/     TaskStore, MoneyStore, SettingsStore
  notify/    flutter_local_notifications + timezone
  parse/     quick add
  backup/    ekspor/impor JSON dan CSV
  widget/    jembatan home_widget
  ui/        hari, uang, setelan, editor transaksi, kelola, data, tema
android/app/src/main/
  kotlin/com/habib/jadwal/   widget native + toggle receiver + channel setelan
  res/layout/                 layout widget dan preview
assets/
  brand/esok-wordmark.svg
  icons/categories/*.svg     15 ikon kategori hitam-putih
```

## Catatan teknis

- SQLite adalah sumber kebenaran. Widget mendapat salinan JSON lewat
  `home_widget`; toggle dari widget ditulis sebagai state eksplisit di
  `pending_toggles` dan diterapkan ke SQLite saat aplikasi resume.
- Database versi 3 menambah `categories.icon_id` dan kategori Minuman.
  Upgrade dari 1.2.0 mengisi ikon kategori bawaan; tugas dan transaksi lama
  tidak diubah.
- Tema disimpan di `SharedPreferences`; pilihan Sistem mengikuti tema Android.
  Warna kustom memakai palet `EsokColors` yang berganti saat tema berubah.
- `res/raw/keep.xml` menahan `ic_stat_esok` agar tidak dihapus resource
  shrinker pada build release.
- Ikon peluncur memakai `assets/icons/esok-text` yang sudah menjadi jalur
  vektor; file font Astoria tidak ikut ke APK.
- `android:allowBackup="false"` — cadangan otomatis Android sengaja dimatikan;
  gunakan ekspor JSON di Setelan → Ekspor & impor.
- `tools/glyph/make-wordmark.js` dan `make-android-icon.js` menghasilkan
  aset wordmark serta VectorDrawable Android dari glyph.
