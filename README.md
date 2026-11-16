# Oh My Esok

Fork pengembangan dari [Esok](https://github.com/notSeraphimXD/esok), dibuat oleh
**notSeraphimXD**. Riwayat dan kredit proyek asal dipertahankan.

Oh My Esok memiliki ID Android `io.github.fata69.ohmyesok`, sehingga dapat dipasang
berdampingan dengan Esok. Untuk memindahkan data, ekspor JSON dari Esok lalu
pilih berkas tersebut lewat **Setelan → Data → Impor** di Oh My Esok.

Catatan harian dan buku kas dalam satu aplikasi Android.
Tanpa akun; catatan dan buku kas disimpan di HP. Pindai struk bersifat opsional
dan mengirim gambar pilihan ke Gemini menggunakan API key pengguna.

Versi terbaru **1.9.4** · [Releases](../../releases)

## Fitur

- **Catatan per hari** dengan jam opsional. Geser untuk pindah hari, ketuk tanggal untuk membuka kalender bulanan.
- **Pengingat** sebelum tenggat, bisa diatur 30 menit sampai 1 hari.
- **Pindai foto** struk dan tangkapan layar M-Banking dengan AI: arah, nominal, kategori, hingga rincian barang terisi sendiri.
- **Buku kas**: pengeluaran, pemasukan, pindah dompet, saldo per dompet, dan koreksi saldo.
- **Widget** catatan dan ringkasan uang — bisa dicentang langsung dari layar utama.
- **Cadangan otomatis** ke `Download/Oh My Esok/oh-my-esok-backup.json`, terpisah dari cadangan Esok asli.
- **Tema** terang, gelap, atau ikut sistem.

## Memasang

1. Buka halaman [Releases](../../releases).
2. Unduh berkas `.apk`.
3. Buka berkasnya, lalu izinkan pemasangan bila diminta.

Update hanya menimpa Oh My Esok dengan ID dan sertifikat signing yang sama.
Jangan mencopot Esok untuk memasang fork ini. Data Esok dipindahkan lewat JSON.

## Build

```powershell
flutter pub get
flutter build apk --release --split-per-abi
```

Build release memerlukan empat variabel lingkungan: `OH_MY_ESOK_KEYSTORE`
(path absolut ke berkas keystore), `OH_MY_ESOK_STORE_PASSWORD`,
`OH_MY_ESOK_KEY_ALIAS`, dan `OH_MY_ESOK_KEY_PASSWORD`. Rahasia dan keystore
tidak disimpan di repo. Build release berhenti bila konfigurasi signing tidak
lengkap; build debug tetap menggunakan konfigurasi pengembangan Android.

Cadangan sistem Android dan transfer data otomatis dinonaktifkan untuk data
aplikasi, termasuk preferensi API key. Cadangan JSON tetap tersedia dan tidak
memuat API key.

Hasilnya ada di `build/app/outputs/flutter-apk/`.

## Struktur

```
lib/
  data/    model dan SQLite: tugas, kategori, dompet, transaksi
  state/   TaskStore, MoneyStore, SettingsStore
  ui/      layar Hari, Uang, Setelan, editor transaksi
  ai/      pindai struk dan mutasi
  backup/  ekspor, impor, cadangan otomatis
  widget/  jembatan ke widget Android
android/app/src/main/kotlin/   widget native dan receiver
assets/  font, ikon kategori, suara
```

## Catatan

- SQLite adalah sumber kebenaran. Widget menerima salinan JSON, dan centang dari widget diterapkan ke database saat aplikasi dibuka.
- Versi database 5 — menambah kolom rincian barang pada transaksi.
- Dibuat untuk pemakaian pribadi.
