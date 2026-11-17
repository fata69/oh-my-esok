# Oh My Esok

Fork pengembangan dari [Esok](https://github.com/notSeraphimXD/esok), dibuat oleh
**notSeraphimXD**. Riwayat dan kredit proyek asal dipertahankan.

Oh My Esok memiliki ID Android `io.github.fata69.ohmyesok`, sehingga dapat dipasang
berdampingan dengan Esok. Untuk memindahkan data, ekspor JSON dari Esok lalu
pilih berkas tersebut lewat **Setelan → Data → Impor** di Oh My Esok.

Catatan harian dan buku kas dalam satu aplikasi Android.
Tanpa akun; catatan dan buku kas disimpan di HP. Pindai struk bersifat opsional
dan mengirim gambar pilihan ke Gemini menggunakan API key pengguna.

[Unduh APK dan lihat catatan rilis di GitHub](../../releases)

## Fitur

- **Catatan per hari** dengan jam opsional. Geser untuk pindah hari, ketuk tanggal untuk membuka kalender bulanan.
- **Tutup Hari** merangkum catatan yang belum selesai dan arus kas harian, lalu membantu memindahkan catatan satu per satu.
- **Pengingat** sebelum tenggat, bisa diatur 30 menit sampai 1 hari.
- **Pindai foto** struk dan tangkapan layar M-Banking dengan Gemini. Cek teks barang dan data yang terbaca sebelum memasukkannya ke draf transaksi.
- **Pilih model AI** dari katalog Google dengan API key yang disimpan di perangkat. Cari nama atau ID di **Setelan → Pindai struk → Model**. Model perlu mendukung gambar untuk memindai struk.
- **Buku kas**: pengeluaran, pemasukan, pindah dompet, saldo per dompet, dan koreksi saldo.
- **Laporan**: bandingkan arus kas enam bulan, telusuri pengeluaran per kategori, dan pilih tanggal untuk melihat nominal persis. Transfer dan koreksi saldo tidak dihitung sebagai arus kas.
- **Widget** catatan dan ringkasan uang — bisa dicentang langsung dari layar utama.
- **Cadangan otomatis** ke `Download/Oh My Esok/oh-my-esok-backup.json`, terpisah dari cadangan Esok asli.
- **Tema** terang, gelap, atau ikut sistem, dengan navbar glass mengambang dan aksi tambah dekat bagian bawah.
- **Pembaruan aplikasi** dari Setelan. Oh My Esok memeriksa APK yang diunduh dari GitHub sebelum menyerahkannya ke installer Android.

## Memasang

1. Buka halaman [Releases](../../releases).
2. Unduh berkas `.apk`.
3. Buka berkasnya, lalu izinkan pemasangan bila diminta.

Update hanya menimpa Oh My Esok dengan ID dan sertifikat signing yang sama.
Jangan mencopot Esok untuk memasang fork ini. Data Esok dipindahkan lewat JSON.
Untuk memperbarui dari aplikasi, buka **Setelan → Pembaruan aplikasi** dan aktifkan **Sertakan prarilis** bila ingin mencoba versi preview.

## Build

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
- Versi database 5 — menambah kolom rincian barang pada transaksi.
- Kredit dan riwayat Esok dipertahankan. Plus Jakarta Sans disertakan dengan [OFL](assets/fonts/plus-jakarta-sans/OFL.txt).
