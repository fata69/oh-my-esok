# Review desain Oh My Esok

Buka `oh-my-esok-design.html` langsung di browser. File berisi gambar dan JavaScript lokal. Gunakan **Bandingkan**, **Semua layar**, dan **Cakupan** untuk meninjau variasi; pada **Gerakan dock**, pilih **Putar animasi**. Catatan review tersedia per state dan dapat diekspor sebagai JSON.

Galeri dihasilkan dari tangkapan widget Flutter dengan data sintetis. Widget launcher digambar berdasarkan XML Android dan diberi label referensi. Dialog sistem memiliki referensi alur karena tampilannya mengikuti Android pengguna.

Setelah tangkapan tim tersedia di `build/design-captures/` dan preview root di `build/v17-previews/`, jalankan dari root repo:

```powershell
python design-review/prepare_review.py
python design-review/build_review.py
```

Setiap input manifest memberi identitas, kelompok, state, tema, dan catatan asal render. Setelah perubahan UI, ganti semua gambar yang menampilkan bagian tersebut, termasuk bagian yang tampak di belakang sheet. HTML dan indeks cakupan adalah artefak lokal; rilis APK menunggu hasil review.
