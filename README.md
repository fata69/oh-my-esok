# Oh My Esok

Oh My Esok adalah aplikasi Android untuk **agenda berulang, pengingat, catatan harian,
dan buku kas pribadi**. Atur pengingat absen setiap Senin–Jumat pukul 08.00, centang
agenda dari widget, atau cari transaksi lama berdasarkan catatan, kategori, dan dompet.

Agenda dan transaksi tersimpan di HP tanpa akun. Pindai struk bersifat opsional dan
mengirim gambar pilihan ke Gemini menggunakan API key pengguna.

[Unduh APK Oh My Esok untuk Android](https://github.com/fata69/oh-my-esok/releases)
· [Kode sumber build preview 23](https://github.com/fata69/oh-my-esok/tree/v0.1.0-preview.8)

Oh My Esok dikembangkan dan dikelola oleh [Fata (@fata69)](https://github.com/fata69)
sebagai fork dari [Esok](https://github.com/notSeraphimXD/esok), proyek asli karya
**notSeraphimXD**. Riwayat Git proyek asal dipertahankan.

## Fitur di rilis preview

- **Catatan per hari** dengan jam opsional. Geser untuk pindah hari, ketuk tanggal untuk membuka kalender bulanan.
- **Tutup Hari** merangkum catatan yang belum selesai dan arus kas harian, lalu membantu memindahkan catatan satu per satu.
- **Agenda berulang dan pengingat** untuk setiap hari, Senin–Jumat, mingguan, atau hari pilihan. Selesaikan atau lewati satu kejadian pada tanggalnya.
- **Pindai foto** struk dan tangkapan layar M-Banking dengan Gemini. Cek teks barang dan data yang terbaca sebelum memasukkannya ke draf transaksi.
- **Buku kas**: pengeluaran, pemasukan, pindah dompet, saldo per dompet, dan koreksi saldo.
- **Cari transaksi** di semua bulan berdasarkan catatan, kategori, atau dompet.
- **Laporan**: bandingkan arus kas enam bulan, telusuri pengeluaran per kategori, dan pilih tanggal untuk melihat nominal persis. Transfer dan koreksi saldo tidak dihitung sebagai arus kas.
- **Widget Agenda** untuk melihat progres hari ini, menambah tugas, dan membuka jadwal berikutnya. Ada juga widget ringkasan uang.
- **Cadangan otomatis** ke `Download/Oh My Esok/oh-my-esok-backup.json`, terpisah dari cadangan Esok asli.
- **Tema** terang, gelap, atau ikut sistem, dengan navbar glass mengambang dan aksi tambah dekat bagian bawah.
- **Pembaruan aplikasi** dari Setelan. Oh My Esok memeriksa APK yang diunduh dari GitHub sebelum menyerahkannya ke installer Android.

## Memasang

1. Buka halaman [Releases](https://github.com/fata69/oh-my-esok/releases).
2. Unduh APK Oh My Esok. Aplikasi mendukung Android 7.0 (API 24) ke atas.
3. Buka berkasnya, lalu izinkan pemasangan bila diminta.

Oh My Esok memiliki ID Android `io.github.fata69.ohmyesok` dan bisa dipasang
berdampingan dengan Esok. Untuk memindahkan data, ekspor JSON dari Esok lalu pilih
berkas tersebut lewat **Setelan → Data → Impor** di Oh My Esok.
Update menimpa Oh My Esok dengan ID dan sertifikat signing yang sama.
Untuk memperbarui dari aplikasi, buka **Setelan → Pembaruan aplikasi** dan aktifkan **Sertakan prarilis** bila ingin mencoba versi preview.

## Build

Untuk membangun APK dari kode yang sesuai dengan rilis, checkout tag rilis yang dipilih.

```powershell
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug
```

Untuk kandidat resmi, ikuti [panduan rilis](docs/RELEASING.md) dan gunakan
`scripts/build-android.ps1` pada host tepercaya. Skrip menghapus variabel signing
dari lingkungan kompilasi, membangun APK unsigned, lalu menandatangani dengan
Android `apksigner`. Simpan kunci di luar GitHub dan repo. Gradle hanya
menghasilkan APK release unsigned dengan `OH_MY_ESOK_UNSIGNED_BUILD=true`;
gunakan skrip untuk menghasilkan APK kandidat yang ditandatangani.

Cadangan sistem Android dan transfer data otomatis dinonaktifkan untuk data
aplikasi, termasuk preferensi API key. Cadangan JSON tetap tersedia dan tidak
memuat API key.

Hasilnya ada di `build/app/outputs/flutter-apk/`.
Lihat [alur QA dan rilis](docs/RELEASING.md) untuk menyiapkan APK kandidat.

## Struktur

```
lib/
  data/    model dan SQLite: tugas, kategori, dompet, transaksi
  state/   TaskStore, MoneyStore, SettingsStore
  ui/      layar Hari, Uang, Laporan, Setelan, editor transaksi
  ai/      pindai struk dan mutasi
  backup/  ekspor, impor, cadangan otomatis
  widget/  jembatan ke widget Android
  update/  cek rilis, unduh, dan validasi pembaruan APK
android/app/src/main/kotlin/   widget native dan receiver
assets/  font, ikon kategori, suara
```

## Catatan

- SQLite adalah sumber kebenaran. Widget menerima salinan JSON, dan centang dari widget diterapkan ke database saat aplikasi dibuka.
- Plus Jakarta Sans disertakan dengan [OFL](assets/fonts/plus-jakarta-sans/OFL.txt).
