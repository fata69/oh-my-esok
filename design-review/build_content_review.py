"""Build the offline build 19 vs. candidate review from Flutter captures."""

import argparse
import base64
import html
import json
from pathlib import Path


SCREENS = {
    'uang': ('Uang', 'Saldo, Dompet, dan Transaksi punya tingkat baca yang berbeda.'),
    'hari': ('Hari', 'Tanggal dan progres agenda mudah dipindai.'),
    'laporan': ('Laporan', 'Judul periode konsisten; grafik volume tetap.'),
    'setelan': ('Setelan', 'Opsi terkait berada dalam satu kelompok.'),
    'keuangan': ('Setelan Keuangan', 'Dompet menyimpan saldo; kategori mengelompokkan transaksi.'),
    'filter': ('Filter transaksi', 'Pilih jenis transaksi dan urutan waktu untuk riwayat.'),
    'hasil-filter': ('Hasil filter', 'Saldo dan jumlah per dompet tetap utuh.'),
    'dompet': ('Ikon dompet', 'Pilih simbol dompet atau gunakan ikon otomatis sesuai jenis.'),
    'kategori': ('Ikon kategori', 'Pilih simbol yang mudah dikenali, seperti mangkuk untuk makan.'),
    'kategori-cepat': ('Kategori di Catat', 'Pilih ikon lewat tombol kecil di dalam kolom nama.'),
}

PAGE = '''<!doctype html>
<html lang="id" data-theme="dark">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Oh My Esok · Review desain</title>
<style>
  :root{font-family:system-ui,sans-serif;color-scheme:dark;--bg:#101010;--ink:#f1f1f1;--sub:#b7b7b7;--edge:#434343;--button:#202020;--selected:#303030;--link:#a8c7ff}
  :root[data-theme="light"]{color-scheme:light;--bg:#f7f7f8;--ink:#171717;--sub:#545454;--edge:#cacacf;--button:#fff;--selected:#e6e6ea;--link:#1558b4}
  *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink)}
  main{width:min(100% - 32px,900px);margin:36px auto 50px}h1{margin:5px 0;font-size:clamp(26px,5vw,36px);letter-spacing:-.04em}
  header p,.hint,footer{color:var(--sub);font-size:14px;line-height:1.5}a{color:var(--link)}
  .eyebrow{font-weight:650;font-size:12px;color:var(--sub)}.controls{display:flex;gap:8px;flex-wrap:wrap;margin:16px 0 10px}
  button{min-height:44px;padding:8px 13px;border-radius:100px;color:var(--ink);background:var(--button);border:1px solid var(--edge);font:inherit;font-size:14px;cursor:pointer}
  button[aria-pressed="true"]{background:var(--selected);font-weight:660;border-color:var(--sub)}
  button:focus-visible,a:focus-visible{outline:2px solid var(--link);outline-offset:3px}
  .hint{margin:12px 0}.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px;max-width:820px}.pair.new-only{grid-template-columns:minmax(0,390px)}
  figure{margin:0}figure[hidden]{display:none}figcaption{font-size:13px;color:var(--sub);margin:8px 0;font-weight:650}
  img{display:block;width:100%;max-width:390px;aspect-ratio:390/844;border:1px solid var(--edge);border-radius:21px;background:#000}
  #switch{display:none}footer{margin-top:22px}
  @media(max-width:670px){main{margin-top:24px}.pair{display:block}#switch:not([hidden]){display:flex}.pair[data-front="after"] #before,.pair[data-front="before"] #after{display:none}.pair.new-only #after{display:block}}
</style>
<main>
  <header>
    <div class="eyebrow">OH MY ESOK / REVIEW 02</div>
    <h1>Review desain aplikasi</h1>
    <p>Build 19 dan kandidat lokal, dirender dari Flutter dengan data contoh pada 390 dp. <a href="dock-center.html">Coba animasi + tengah dan kanan →</a></p>
  </header>
  <div class="controls" id="theme" aria-label="Tema"></div>
  <div class="controls" id="screens" aria-label="Layar"></div>
  <p class="hint" id="hint" aria-live="polite"></p>
  <div class="controls" id="switch" aria-label="Versi" hidden></div>
  <section class="pair" id="pair" data-front="after" aria-label="Perbandingan tampilan">
    <figure id="before"><figcaption>Build 19</figcaption><img width="390" height="844" alt=""></figure>
    <figure id="after"><figcaption>Kandidat lokal</figcaption><img width="390" height="844" alt=""></figure>
  </section>
  <footer>Baseline <code>c02bce6</code> · Kandidat <code>__REV__</code> · HTML ini tidak memasang aplikasi.</footer>
</main>
<script>
const shots=__SHOTS__, screens=__SCREENS__;
let theme='dark', page='uang', front='after';
const themeNames={light:'Terang',dark:'AMOLED'};
const $=id=>document.getElementById(id);
function buttons(id, entries, current, change) {
  for(const [value,label] of entries) {
    const button=document.createElement('button');
    button.type='button'; button.value=value; button.textContent=label;
    button.setAttribute('aria-pressed',String(current===value));
    button.onclick=()=>{change(value); draw()}; $(id).append(button);
  }
}
function draw(){
  document.documentElement.dataset.theme=theme;
  const before=shots.before[page+'-'+theme];
  $('pair').classList.toggle('new-only',!before);
  $('pair').dataset.front=front;
  $('switch').hidden=!before;
  $('before').hidden=!before;
  $('hint').textContent=screens[page][1];
  for(const [id,selected] of [['theme',theme],['screens',page],['switch',front]])
    for(const button of $(id).children)
      button.setAttribute('aria-pressed',String(button.value===selected));
  for(const [side,src] of [['before',before],['after',shots.after[page+'-'+theme]]]) {
    if(!src) continue;
    const img=$(side).querySelector('img');
    img.alt=`${screens[page][0]}, ${themeNames[theme]} · ${side==='before'?'build 19':'kandidat'}`;
    img.src=src;
  }
}
buttons('theme',Object.entries(themeNames),theme,v=>theme=v);
buttons('screens',Object.entries(screens).map(([id,[title]])=>[id,title]),page,v=>{page=v;front='after'});
buttons('switch',[['after','Kandidat lokal'],['before','Build 19']],front,v=>front=v);
draw();
</script>
'''


def captures(folder, names):
    return {
        path.stem: 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode('ascii')
        for name in names
        for theme in ('light', 'dark')
        if (path := folder / f'{name}-{theme}.png').is_file()
    }


def main():
    args = argparse.ArgumentParser(description=__doc__)
    for name in ('before', 'after', 'output'):
        args.add_argument(name, type=Path)
    args.add_argument('--revision', required=True)
    opts = args.parse_args()
    baseline = ('uang', 'hari', 'laporan', 'setelan')
    shots = {'before': captures(opts.before, baseline), 'after': captures(opts.after, SCREENS)}
    for side in shots.values():
        for screen in baseline:
            for theme in ('light', 'dark'):
                if f'{screen}-{theme}' not in side:
                    args.error(f'Missing capture: {screen}-{theme}')
    screens = {
        key: value for key, value in SCREENS.items()
        if all(f'{key}-{theme}' in shots['after'] for theme in ('light', 'dark'))
    }
    opts.output.parent.mkdir(parents=True, exist_ok=True)
    opts.output.write_text(
        PAGE.replace('__REV__', html.escape(opts.revision))
        .replace('__SHOTS__', json.dumps(shots))
        .replace('__SCREENS__', json.dumps(screens, ensure_ascii=False)),
        encoding='utf-8',
    )


if __name__ == '__main__':
    main()
