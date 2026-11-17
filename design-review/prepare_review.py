"""Prepare final-root and native reference entries for the offline gallery."""

from html import escape
import json
from pathlib import Path
import shutil
import subprocess


CAPTURES = Path('build/design-captures')
PREVIEWS = Path('build/v17-previews')
THEMES = ('light', 'dark')
COMMIT = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD'], text=True).strip()


def save(name, rows):
    (CAPTURES / f'{name}-manifest.json').write_text(
        json.dumps(rows, ensure_ascii=False, indent=2) + '\n', encoding='utf-8',
    )


def dock_hotspots(with_add, target):
    destinations = [('Hari', 'root-hari'), ('Uang', 'root-uang'),
                    ('Laporan', 'root-laporan'), ('Setelan', 'settings-overview')]
    width = 18 if with_add else 21.3
    return [
        dict(label=label, target=page, x=7+i*width, y=91, w=width, h=6)
        for i, (label, page) in enumerate(destinations)
    ] + ([dict(label='Tambah', target=target, x=81, y=91, w=13, h=6)] if with_add else [])


def root_screens():
    rows = []
    for tab, title, features, add_target in [
        ('uang', 'Uang', ['Saldo total, arus masuk/keluar, saldo per dompet', 'Riwayat transaksi per hari', '+ membuka editor transaksi'], 'core-tx-expense'),
        ('hari', 'Hari', ['Agenda harian dan perpindahan tanggal', 'Catatan, pengingat, dan ringkasan uang', '+ membuka editor catatan'], 'core-note-new'),
        ('laporan', 'Laporan', ['Ringkasan dan volume kas', 'Pemasukan biru dan pengeluaran oranye', 'Dock kembali lebar tanpa tombol tambah'], None),
    ]:
        row = dict(id=f'root-{tab}', title=title, group=title, state='Layar utama',
                   kind='widget', features=features, hotspots=dock_hotspots(bool(add_target), add_target),
                   notes=f'Widget produksi {COMMIT}, 412 × 892 dp. Data contoh, kedua tema. Klik tab atau tombol + di render untuk melihat alurnya.')
        for theme in THEMES:
            image = f'{tab}-{theme}.png'
            row[theme] = f'root-{image}'
            shutil.copyfile(PREVIEWS / image, CAPTURES / row[theme])
        rows.append(row)
    save('root', rows)


def motion_screens():
    rows = []
    for mode, title, state, detail in [
        ('show', '+ keluar dari dock', 'Laporan → Uang', 'Kapsul menyempit sambil lingkaran + bergeser keluar dan berhenti dengan overshoot kecil.'),
        ('hide', '+ kembali ke dock', 'Uang → Laporan', 'Lingkaran mundur dan memudar, lalu kapsul memenuhi ruang yang tersedia.'),
    ]:
        frames = {theme: [f'motion-{mode}-{theme}-{i}.png' for i in range(15)] for theme in THEMES}
        rows.append(dict(id=f'motion-{mode}', title=title, group='Gerakan dock', state=state,
                         kind='widget', features=[detail, 'Perpindahan halaman memakai fade dan geser pendek.', 'Kurangi gerakan: dock berganti tanpa animasi.'],
                         notes=f'Frame hasil render widget {COMMIT} dengan data contoh. Putar untuk menilai gerak asli; simulasi tidak mengukur kelancaran di HP.',
                         light=frames['light'][-1], dark=frames['dark'][-1], motion=frames))
    save('motion', rows)


PALETTE = dict(light=('#FAF9F7', '#1A1917', '#6B6862', '#E5E2DC', '#B03A2E', '#2F7D4F', '#F2F0EA'),
               dark=('#14130F', '#F2F0EA', '#9A968C', '#2A2823', '#E07A63', '#5FAE7C', '#1F1E19'))


def native_widget(layout, theme, variant):
    bg, ink, muted, line, negative, positive, soft = PALETTE[theme]
    sizes = {'task': (340, 184), 'square': (164, 164), 'bar': (340, 74)}
    width, height = sizes[layout]
    svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" font-family="sans-serif">',
           f'<rect x=".5" y=".5" width="{width-1}" height="{height-1}" rx="16" fill="{bg}" stroke="{line}"/>']

    def label(x, y, value, color, size, bold=False):
        svg.append(f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" font-weight="{700 if bold else 400}">{escape(value)}</text>')

    if layout == 'task':
        label(16, 33, {'empty': 'TIDAK ADA CATATAN', 'filled': 'HARI INI', 'done': '✓ Semua selesai'}[variant], positive if variant == 'done' else muted, 12, True)
        if variant != 'empty':
            label(299, 33, '2/2' if variant == 'done' else '1/3', muted, 13)
            items = ['Tinjau agenda', 'Kirim catatan rapat', 'Belanja rumah'][:2 if variant == 'done' else 3]
            for i, title in enumerate(items):
                y = 47 + i * 44
                checked = variant == 'done' or i == 0
                label(16, y + 24, title, muted if checked else ink, 16)
                if i == 1:
                    label(251, y + 24, '14:30', muted, 12.5)
                svg.append(f'<rect x="300" y="{y+9}" width="24" height="24" rx="7" fill="{positive if checked else soft}" stroke="{line}"/>')
                if checked:
                    svg.append(f'<path d="M306 {y+21}l4 4 8 -8" fill="none" stroke="{bg}" stroke-width="2"/>')
                svg.append(f'<path d="M16 {y+39}h308" stroke="{line}"/>')
    else:
        today, month = {'visible': ('Rp 78.000', 'Rp 2.473.000'), 'masked': ('•••••', '•••••'), 'zero': ('Rp 0', 'Rp 0')}[variant]
        label(16, 29, 'HARI INI', muted, 9.5, True)
        label(16, 53, today, negative, 25 if layout == 'square' else 18, True)
        if layout == 'square':
            label(16, 126, 'BULAN INI', muted, 9, True)
            label(16, 145, month, negative, 12)
            cx, cy = 134, 134
        else:
            label(169, 29, 'BULAN INI', muted, 9, True)
            label(169, 52, month, negative, 12)
            cx, cy = 312, 37
        svg.append(f'<circle cx="{cx}" cy="{cy}" r="14" fill="{soft}"/>')
        svg.append(f'<path d="M{cx-6} {cy}h12 M{cx} {cy-6}v12" stroke="{ink}" stroke-width="1.5"/>')
    return ''.join(svg) + '</svg>'


def native_screens():
    rows = []
    for layout, title, states in [
        ('task', 'Widget Catatan 4 × 2', {'filled': 'Agenda terisi', 'empty': 'Kosong', 'done': 'Semua selesai'}),
        ('square', 'Widget Uang 2 × 2', {'visible': 'Nominal tampil', 'masked': 'Nominal disembunyikan', 'zero': 'Belum ada pengeluaran'}),
        ('bar', 'Widget Uang 4 × 1', {'visible': 'Nominal tampil', 'masked': 'Nominal disembunyikan', 'zero': 'Belum ada pengeluaran'}),
    ]:
        for variant, state in states.items():
            identity = f'native-{layout}-{variant}'
            row = dict(id=identity, title=title, group='Widget Android', state=state, kind='reference',
                       notes='Ilustrasi berdasarkan layout XML dan provider RemoteViews, dengan data contoh. Ukuran, font, dan tampilan launcher sebenarnya mengikuti perangkat.',
                       features=['Buka agenda dan tandai catatan' if layout == 'task' else 'Total hari ini dan bulan ini; + membuka editor transaksi'])
            for theme in THEMES:
                row[theme] = f'{identity}-{theme}.svg'
                (CAPTURES / row[theme]).write_text(native_widget(layout, theme, variant), encoding='utf-8')
            rows.append(row)

    system = [
        ('camera', 'Kamera dan galeri', 'Pilih sumber → pilih foto → konfirmasi', 'Android menangani pemilihan foto dan izin kamera jika diminta. Setelah foto kembali, aplikasi menampilkan konfirmasi sebelum mengirim ke Gemini.'),
        ('files', 'Pemilih berkas', 'Impor / simpan cadangan dan pilih audio', 'Nama folder, lokasi yang ditawarkan, dan tombol pemilih berkas mengikuti Android. Aplikasi menampilkan pemeriksaan impor setelah JSON dipilih.'),
        ('share', 'Bagikan cadangan', 'Ekspor lalu buka panel bagikan Android', 'Daftar target berbagi berasal dari aplikasi terpasang. Data contoh di galeri tidak membuat atau membagikan berkas sungguhan.'),
        ('notifications', 'Izin dan notifikasi', 'Izinkan atau tolak notifikasi catatan', 'Dialog izin dan panel notifikasi mengikuti Android. Bunyi dan getar mengikuti preferensi aplikasi dan pengaturan sistem.'),
        ('exact', 'Pengingat tepat waktu', 'Buka akses alarm tepat waktu', 'Android menyediakan sakelar izin alarm tepat waktu jika dibutuhkan perangkat. Kembali ke Oh My Esok untuk melihat statusnya.'),
        ('battery', 'Pengaturan baterai', 'Buka pengaturan baterai aplikasi', 'Android menampilkan pengaturan baterai yang berbeda menurut produsen; pengguna memilih sendiri opsi yang tersedia.'),
        ('installer', 'Izin dan installer APK', 'Siap dipasang → izin pemasangan → installer', 'Android meminta izin pemasangan dari sumber ini bila perlu. Pengguna memilih Pasang atau Batal di installer. Galeri tidak memulai instalasi.'),
        ('keyboard', 'Keyboard sistem', 'Fokus editor nama, catatan, atau API key', 'IME dan gesture inset dipasok oleh Android. Preview widget memperlihatkan bidang fokus dan respons layout; rupa keyboard tergantung IME pengguna.'),
    ]
    rows.extend(dict(id=f'native-{identity}', title=title, group='Permukaan sistem', state=state,
                     kind='reference', features=[state], reference=[detail],
                     notes='Referensi alur native; belum dirender dari perangkat.')
                for identity, title, state, detail in system)
    save('native', rows)


if __name__ == '__main__':
    root_screens()
    motion_screens()
    native_screens()
