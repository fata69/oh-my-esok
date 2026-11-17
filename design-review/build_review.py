"""Bundle production-widget captures into a portable, offline design review."""

import argparse
import base64
from datetime import datetime
import json
from pathlib import Path
import subprocess
from tempfile import NamedTemporaryFile


TEMPLATE = r'''<!doctype html>
<html lang="id"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Oh My Esok — Design review</title>
<style>
:root{color-scheme:dark;--bg:#101113;--panel:#181a1e;--surface:#22252a;--line:#34383f;--ink:#f1f2f4;--muted:#a1a8b3;--blue:#8db3ff;--orange:#ff8836;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink)}button,input,select,textarea{font:inherit}button,a,input,select{outline-offset:4px}button{cursor:pointer;color:inherit}button:focus-visible,a:focus-visible,input:focus-visible{outline:2px solid var(--blue)}button:disabled{opacity:.35;cursor:default}
header{height:70px;display:flex;align-items:center;gap:22px;padding:0 24px;border-bottom:1px solid var(--line);background:var(--panel);position:sticky;top:0;z-index:5}.brand{font-weight:750;font-size:18px;letter-spacing:-.5px}.brand span{font-weight:400;color:var(--muted);margin-left:12px;font-size:13px;letter-spacing:0}.pill{font-size:11px;border:1px solid var(--line);padding:3px 8px;border-radius:6px;color:var(--muted)}.spacer{flex:1}.subtle{color:var(--muted)}.button{border:1px solid var(--line);background:transparent;padding:7px 12px;border-radius:8px;text-decoration:none;color:var(--ink);white-space:nowrap}.button:hover{background:var(--surface)}.button.active{background:var(--surface);border-color:#63718a;color:var(--blue)}
.layout{display:grid;grid-template-columns:264px minmax(0,1fr) 290px;min-height:calc(100vh - 70px)}aside{background:var(--panel);padding:20px 14px;height:calc(100vh - 70px);position:sticky;top:70px;overflow:auto}.left{border-right:1px solid var(--line)}.right{border-left:1px solid var(--line);padding:22px}.eyebrow{font-size:10px;text-transform:uppercase;letter-spacing:1.4px;font-weight:700;color:var(--muted);margin:0 0 10px}h1,h2,h3,p{margin-top:0}h1{font-size:22px;font-weight:650;letter-spacing:-.5px;margin-bottom:4px}h2{font-size:17px}h3{font-size:13px;font-weight:600;margin-bottom:8px}.search{width:100%;padding:10px 12px;background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:8px;margin-bottom:18px}details.group{margin-bottom:13px}summary{cursor:pointer;font-size:12px;font-weight:650;margin:8px 4px 7px}.screen-link{display:block;width:100%;text-align:left;border:0;background:transparent;border-radius:7px;padding:8px 10px;margin:2px 0;line-height:1.35}.screen-link small{display:block;color:var(--muted);font-size:10px;margin-top:3px}.screen-link:hover{background:var(--surface)}.screen-link.selected{background:#253044;color:#c9dcff}.screen-link.selected small{color:#a7bddb}
main{min-width:0}.toolbar{display:flex;gap:8px;align-items:center;padding:18px 24px;flex-wrap:wrap;border-bottom:1px solid var(--line)}.segmented{display:flex;gap:2px;padding:3px;background:var(--panel);border:1px solid var(--line);border-radius:10px}.segmented button{border:0;border-radius:6px;background:transparent;color:var(--muted);padding:5px 10px}.segmented button[aria-pressed=true]{background:var(--surface);color:var(--ink)}.scene-head{padding:20px 24px 10px}.scene-head p{font-size:12px;color:var(--muted);margin-bottom:10px}.stage{display:flex;gap:32px;justify-content:center;align-items:flex-start;padding:12px 28px 44px;min-height:500px;background-image:radial-gradient(#5558 0.6px,transparent .6px);background-size:16px 16px}.artboard{min-width:0;width:min(100%,390px);position:relative}.artboard>p{font-size:11px;color:var(--muted);text-align:center;margin-bottom:10px}.phone{position:relative;background:#111;border:1px solid #555;border-radius:25px;padding:6px;box-shadow:0 16px 46px #0004;overflow:hidden}.phone img{width:100%;display:block;border-radius:19px}.phone button.hotspot{position:absolute;border:0;background:transparent;opacity:0;color:transparent;min-width:24px;min-height:24px;border-radius:6px}.phone button.hotspot:hover,.phone button.hotspot:focus-visible{opacity:1;background:#528dff25;outline:1px solid #80aaff;color:transparent}.missing{padding:36px 20px;background:var(--panel);color:var(--muted);border:1px dashed var(--line);border-radius:12px}.reference{background:var(--panel);padding:24px;border:1px dashed #6c5d43;border-radius:12px}.reference ul{padding-left:18px;color:var(--muted)}
.right p,.right li{font-size:12px;color:var(--muted)}.right ul{padding-left:16px}.right textarea{width:100%;min-height:140px;resize:vertical;padding:10px;background:var(--bg);color:var(--ink);border:1px solid var(--line);border-radius:8px}.right .button{display:inline-block;margin-top:9px;font-size:12px}.note-status{font-size:11px;margin-top:9px;color:var(--muted)}.rule{height:1px;background:var(--line);margin:20px 0}.badge{display:inline-block;padding:3px 7px;background:#24362b;border:1px solid #3c5140;border-radius:5px;font-size:10px;color:#c7e7ce;margin-bottom:12px}.badge.ref{background:#372d21;border-color:#675137;color:#efd1a5}.metadata{overflow-wrap:anywhere;font:10px/1.6 ui-monospace,monospace}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:22px;padding:24px}.tile{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:12px;text-align:left}.tile:hover{border-color:#7585a0}.tile img{width:100%;height:290px;object-fit:contain;object-position:top;background:#111;border-radius:6px}.tile strong{display:block;margin-top:10px;font-size:12px}.tile small{color:var(--muted);font-size:10px}.coverage{padding:24px}.coverage table{border-collapse:collapse;width:100%;font-size:12px}.coverage td,.coverage th{padding:12px 8px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top}.coverage th{color:var(--muted)}.coverage code{font-size:10px}.coverage button{color:var(--blue);border:0;background:none;text-align:left;padding:0}.hide{display:none!important}.notice{margin:0 24px 12px;padding:9px 12px;background:var(--panel);border-left:2px solid #667287;color:var(--muted);font-size:11px}.switches{display:flex;gap:7px;flex-wrap:wrap}.switches .button{font-size:11px}.arrow{width:32px;padding:6px 0}.native-title{font-size:20px}.native-body{max-width:480px;margin:16px auto;padding:28px}.native-body section{border-top:1px solid var(--line);padding:18px 0}.native-body section h3{font-size:15px}.native-body.light{--panel:#fff;--ink:#202020;--muted:#646464;--line:#ddd;color:var(--ink);background:var(--panel)}dialog{padding:0;border:1px solid var(--line);max-width:90vw;max-height:94vh;background:#141518;color:var(--ink);border-radius:12px}dialog::backdrop{background:#000c}dialog img{max-width:86vw;max-height:88vh;display:block;object-fit:contain}dialog .button{position:sticky;top:8px;float:right;margin:8px;background:#181a1e}.k{border:1px solid var(--line);padding:1px 5px;border-radius:4px;font-size:10px}
@media(min-width:1600px){.layout{grid-template-columns:280px minmax(0,1fr) 320px}.artboard{width:410px}}@media(max-width:1100px){.layout{grid-template-columns:230px minmax(0,1fr)}.right{position:relative;top:0;height:auto;grid-column:1/-1;border-top:1px solid var(--line)}.stage{gap:16px;padding:14px}.brand span{display:none}}@media(max-width:680px){header{padding:0 12px;gap:8px}.pill{display:none}.layout{display:block}.left{height:auto;position:relative;top:0;max-height:260px;border-bottom:1px solid var(--line)}.toolbar{padding:12px}.stage{flex-wrap:wrap}.artboard{width:min(100%,390px)}.scene-head{padding:16px}.notice{margin:0 16px 12px}.brand{font-size:16px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));padding:14px;gap:12px}.tile img{height:230px}.coverage{overflow:auto}}
header{height:52px}.layout{min-height:calc(100vh - 52px)}aside{height:calc(100vh - 52px);top:52px}.toolbar{padding:10px 18px}.scene-head{padding:12px 18px 2px}.scene-head h1{font-size:19px;margin-bottom:3px}.scene-head p{margin-bottom:4px}.stage{min-height:0;padding:8px 16px 20px;gap:20px}.artboard>p{margin-bottom:5px}.artboard{width:min(100%,390px,var(--fit,390px))}.preview-actions{display:flex;flex-wrap:wrap;justify-content:center;gap:6px;margin-top:7px}.preview-actions button{font-size:11px}.intro{font-size:12px;margin:0 0 14px;color:var(--muted)}.left summary{padding:5px 0}.tile:focus-visible{outline:2px solid var(--blue)}
@media(max-width:1100px){.right{top:0;height:auto}}
#mobileMenu{display:none}
@media(max-width:680px){#mobileMenu{display:block}.left{display:none;top:0;height:auto}.left.open{display:block}.stage{padding:8px 14px 18px}.artboard{width:min(100%,390px,var(--fit,390px))}.segmented button{padding:4px 8px}.toolbar{gap:7px;padding:8px 12px}.toolbar .spacer{display:none}}
@media(prefers-reduced-motion:no-preference){button{transition:background-color .12s,border-color .12s}}
</style></head><body>
<header><div class="brand">Oh My Esok<span>Design review</span></div><span class="pill">Local / offline</span><div class="spacer"></div><button class="button" id="export">Ekspor catatan</button></header>
<div class="layout"><aside class="left"><p class="eyebrow">Halaman dan state</p><input id="search" class="search" type="search" placeholder="Cari layar, fitur, atau state…" aria-label="Cari desain"><p class="intro">Pilih halaman untuk melihat variasinya.</p><nav id="screens"></nav></aside>
<main><div class="toolbar"><button class="button" id="mobileMenu" aria-expanded="false">Daftar layar</button><div class="segmented" aria-label="Mode review"><button id="single" aria-pressed="true">Preview</button><button id="overview" aria-pressed="false">Semua layar</button><button id="coverage" aria-pressed="false">Cakupan</button></div><div class="spacer"></div><div class="segmented" aria-label="Tema"><button data-theme="light" aria-pressed="false">Terang</button><button data-theme="dark" aria-pressed="true">Gelap</button><button data-theme="both" aria-pressed="false">Bandingkan</button></div><button class="button arrow" id="prev" aria-label="State sebelumnya">←</button><button class="button arrow" id="next" aria-label="State berikutnya">→</button></div>
<section id="detail"><div class="scene-head"><h1 id="title"></h1><p id="subtitle"></p></div><div class="stage" id="stage"></div></section><section id="board" class="grid hide"></section><section id="matrix" class="coverage hide"></section></main>
<aside class="right"><p class="eyebrow">Inspektor</p><span id="kind" class="badge"></span><h2 id="inspector-title"></h2><h3>State</h3><p id="state"></p><h3>Fitur</h3><div id="features"></div><p id="notes"></p><div class="rule"></div><label for="comment"><h3>Catatan review kamu</h3></label><textarea id="comment" placeholder="Contoh: jarak navbar, ukuran teks, warna, atau state yang kurang…"></textarea><p class="note-status" id="note-status"></p><div class="rule"></div><h3>Jelajahi alur</h3><div class="switches" id="related"></div><div class="rule"></div><p class="eyebrow">Tentang file</p><p id="summary"></p><p class="metadata" id="provenance"></p><p>Rilis APK ditahan sampai review desain. Gambar dialog sistem atau panel bertanda Referensi tidak membuktikan perilaku Android di HP.</p></aside></div>
<dialog id="zoom"><button class="button" id="closeZoom">Tutup</button><img alt="Preview diperbesar" id="zoomImage"></dialog>
<script id="payload" type="application/json">__PAYLOAD__</script>
<script>
'use strict';const DATA=JSON.parse(document.getElementById('payload').textContent);const $=id=>document.getElementById(id);const screens=DATA.screens;let selected=0,theme='dark',view='single',query='';let feedback={};try{feedback=JSON.parse(localStorage.getItem('oh-my-esok-design-notes-v3')||'{}')}catch(e){};
const el=(tag,txt,cls)=>{let a=document.createElement(tag);if(txt!==undefined)a.textContent=txt;if(cls)a.className=cls;return a};
const visible=()=>screens.map((s,i)=>({s,i})).filter(({s})=>[s.title,s.group,s.state,...(s.features||[])].join(' ').toLowerCase().includes(query));
function choose(i){selected=i;view='single';location.hash=encodeURIComponent(screens[i].id);render();if(window.matchMedia('(max-width: 680px)').matches){document.querySelector('.left').classList.remove('open');$('mobileMenu').setAttribute('aria-expanded','false');window.scrollTo(0,0)}}
function nav(){const host=$('screens');host.replaceChildren();const groups=[...new Set(visible().map(x=>x.s.group))];if(!groups.length)host.append(el('p','Tidak ada layar yang cocok.','intro'));groups.forEach(group=>{const d=el('details',undefined,'group');d.open=!!query||group===screens[selected].group;d.append(el('summary',group));visible().filter(x=>x.s.group===group).forEach(({s,i})=>{const b=el('button',undefined,'screen-link'+(selected===i?' selected':''));b.append(el('span',s.title),el('small',s.state));b.onclick=()=>choose(i);d.append(b)});host.append(d)})}
function addImage(host,s,t){const a=el('div',undefined,'artboard');a.append(el('p',t==='dark'?'GELAP':'TERANG'));if(s.images[t]){const phone=el('div',undefined,'phone');const img=el('img');img.onload=()=>{if(img.naturalHeight>img.naturalWidth)a.style.setProperty('--fit','calc(max(180px,(100svh - 204px) * '+(img.naturalWidth/img.naturalHeight)+'))')};img.src=s.images[t];img.alt=s.title+' — '+s.state+' — '+t;img.onclick=()=>{$('zoomImage').src=img.src;$('zoom').showModal()};phone.append(img);const spots=s.hotspots||[];spots.forEach(h=>{const target=screens.findIndex(x=>x.id===h.target);if(target<0)return;const b=el('button',undefined,'hotspot');b.title=h.label;b.setAttribute('aria-label',h.label);Object.assign(b.style,{left:h.x+'%',top:h.y+'%',width:h.w+'%',height:h.h+'%'});b.onclick=()=>choose(target);phone.append(b)});a.append(phone);const actions=el('div',undefined,'preview-actions');const zoom=el('button','Perbesar','button');zoom.onclick=img.onclick;actions.append(zoom);a.append(actions);if(s.motion&&s.motion[t]){const frames=s.motion[t].map(src=>{const f=new Image();f.src=src;return f});const button=el('button','Putar animasi · 0,46 detik','button');button.onclick=async()=>{button.disabled=true;await Promise.all(frames.map(f=>f.decode().catch(()=>{})));const start=performance.now();function step(now){if(!img.isConnected)return;const frame=Math.min(frames.length-1,Math.floor((now-start)/33));img.src=frames[frame].src;if(frame<frames.length-1)requestAnimationFrame(step);else button.disabled=false}requestAnimationFrame(step)};actions.prepend(button)}}else if(s.reference){const r=el('div',undefined,'reference');r.append(el('p','REFERENSI / BATAS SISTEM','eyebrow'),el('h2',s.title));s.reference.forEach(x=>r.append(el('p',x)));a.append(r)}else a.append(el('div','Render tema ini belum tersedia.','missing'));host.append(a)}
function detail(){const s=screens[selected];$('title').textContent=s.title;$('subtitle').textContent=s.group+' / '+s.state;$('stage').replaceChildren();(theme==='both'?['light','dark']:[theme]).forEach(t=>addImage($('stage'),s,t));$('kind').textContent=s.kind==='widget'?'RENDER WIDGET APLIKASI':'REFERENSI / BATAS SISTEM';$('kind').className='badge'+(s.kind==='widget'?'':' ref');$('inspector-title').textContent=s.title;$('state').textContent=s.state;$('features').replaceChildren();const ul=el('ul');s.features.forEach(f=>ul.append(el('li',f)));$('features').append(ul);$('notes').textContent=s.notes||'';$('comment').value=feedback[s.id]||'';$('note-status').textContent='Tersimpan lokal di browser ini. Ekspor untuk dibagikan.';$('related').replaceChildren();const related=(s.related||[]).map(id=>screens.findIndex(r=>r.id===id)).filter(i=>i>=0);for(const i of (related.length?related:screens.map((r,i)=>r.group===s.group&&i!==selected?i:-1).filter(i=>i>=0).slice(0,5))){const b=el('button',screens[i].title,'button');b.onclick=()=>choose(i);$('related').append(b)}$('prev').disabled=selected===0;$('next').disabled=selected===screens.length-1}
function board(){const b=$('board');b.replaceChildren();visible().forEach(({s,i})=>{const tile=el('button',undefined,'tile');const t=theme==='light'?'light':'dark';if(s.images[t]||s.images.light||s.images.dark){const img=el('img');img.src=s.images[t]||s.images.light||s.images.dark;img.alt=s.title;img.loading='lazy';tile.append(img)}else tile.append(el('div','Referensi sistem','missing'));tile.append(el('strong',s.title),el('small',s.group+' · '+s.state));tile.onclick=()=>choose(i);b.append(tile)})}
function matrix(){const m=$('matrix');m.replaceChildren();m.append(el('h1','Cakupan halaman dan state'),el('p','Setiap baris menunjuk satu desain yang dapat dinilai. Referensi sistem dipisahkan dari hasil render aplikasi.','subtle'));const table=el('table');const head=el('tr');['Fitur / layar','State','Terang','Gelap','Bukti'].forEach(t=>head.append(el('th',t)));table.append(head);visible().forEach(({s,i})=>{const r=el('tr');let c=el('td');const b=el('button',s.group+' / '+s.title);b.onclick=()=>choose(i);c.append(b);r.append(c,el('td',s.state),el('td',s.images.light?'Ada':'—'),el('td',s.images.dark?'Ada':'—'),el('td',s.kind==='widget'?'Widget produksi':'Referensi sistem'));table.append(r)});m.append(table);DATA.limitations.forEach(x=>m.append(el('p',x,'subtle')))}
function render(){nav();$('detail').classList.toggle('hide',view!=='single');$('board').classList.toggle('hide',view!=='overview');$('matrix').classList.toggle('hide',view!=='coverage');['single','overview','coverage'].forEach(v=>$(v).setAttribute('aria-pressed',String(view===v)));document.querySelectorAll('[data-theme]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.theme===theme)));detail();if(view==='overview')board();if(view==='coverage')matrix()}
$('mobileMenu').onclick=()=>{const opened=document.querySelector('.left').classList.toggle('open');$('mobileMenu').setAttribute('aria-expanded',String(opened));if(opened)$('search').focus({preventScroll:true})};$('search').oninput=e=>{query=e.target.value.toLowerCase();nav();if(view==='overview')board();if(view==='coverage')matrix()};document.querySelectorAll('[data-theme]').forEach(b=>b.onclick=()=>{theme=b.dataset.theme;render()});['single','overview','coverage'].forEach(v=>$(v).onclick=()=>{view=v;render()});$('prev').onclick=()=>choose(Math.max(0,selected-1));$('next').onclick=()=>choose(Math.min(screens.length-1,selected+1));$('comment').oninput=e=>{feedback[screens[selected].id]=e.target.value;try{localStorage.setItem('oh-my-esok-design-notes-v3',JSON.stringify(feedback))}catch(err){$('note-status').textContent='Browser tidak mengizinkan simpan. Gunakan Ekspor catatan.'}};$('export').onclick=()=>{const blob=new Blob([JSON.stringify({source:DATA.commit,date:new Date().toISOString(),notes:feedback},null,2)],{type:'application/json'});const a=el('a');a.href=URL.createObjectURL(blob);a.download='oh-my-esok-design-notes.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)};$('closeZoom').onclick=()=>$('zoom').close();document.addEventListener('keydown',e=>{if(['INPUT','TEXTAREA'].includes(e.target.tagName))return;if(e.key==='ArrowRight'&&selected<screens.length-1)choose(selected+1);if(e.key==='ArrowLeft'&&selected>0)choose(selected-1)});$('summary').textContent=screens.length+' desain/state · '+screens.filter(s=>s.kind==='widget').length+' render widget · 2 tema';$('provenance').textContent='Sumber '+DATA.commit+' · '+DATA.created;const start=screens.findIndex(s=>s.id===decodeURIComponent(location.hash.slice(1)));if(start>=0)selected=start;window.addEventListener('hashchange',()=>{const index=screens.findIndex(s=>s.id===decodeURIComponent(location.hash.slice(1)));if(index>=0&&index!==selected){selected=index;view='single';render()}});render();
</script></body></html>'''


def build(captures: Path, output: Path):
    screens = []
    missing = []
    for source in sorted(captures.glob('*-manifest.json')):
        rows = json.loads(source.read_text(encoding='utf-8-sig'))
        if isinstance(rows, dict):
            rows = rows.get('screens', rows.get('items', []))
        for row in rows:
            item = dict(row)
            item.setdefault('group', 'Lainnya')
            item.setdefault('state', 'Utama')
            item.setdefault('kind', 'widget')
            features = item.pop('feature', item.get('features', []))
            item['features'] = [features] if isinstance(features, str) else features
            item['images'] = {}
            def embed(name):
                path = (captures / name).resolve()
                if not path.is_relative_to(captures.resolve()):
                    raise ValueError(f'Capture outside root: {name}')
                if not path.is_file():
                    missing.append(name)
                    return ''
                mime = 'image/svg+xml' if path.suffix == '.svg' else 'image/png'
                return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode()

            for theme in ('light', 'dark'):
                name = item.pop(theme, None)
                if not name:
                    continue
                item['images'][theme] = embed(name)
            if item.get('motion'):
                item['motion'] = {theme: [embed(name) for name in names] for theme, names in item['motion'].items()}
            if item['kind'] == 'widget' and item['images'].keys() != {'light', 'dark'}:
                raise ValueError(f'Expected both rendered themes: {item["id"]}')
            screens.append(item)
    if missing:
        raise ValueError(f'Missing images: {missing}')
    ids = [row['id'] for row in screens]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate design identifiers')
    if not screens:
        raise ValueError('No manifests found')
    # Open the gallery on the final dock rather than an arbitrary editor.
    priority = ['root-uang', 'root-hari', 'root-laporan', 'settings-overview', 'motion-show', 'motion-hide']
    screens.sort(key=lambda row: priority.index(row['id']) if row['id'] in priority else len(priority))
    related = {
        'root-uang': ['motion-show', 'core-tx-expense', 'core-tx-inline-category', 'ocr-source'],
        'root-hari': ['motion-show', 'core-note-new', 'core-calendar', 'core-day-review'],
        'root-laporan': ['motion-hide', 'report-monthly', 'report-daily-selected', 'report-categories'],
        'core-tx-expense': ['core-tx-inline-category', 'ocr-source', 'core-tx-expense-ready'],
        'core-tx-inline-category': ['core-tx-duplicate-category', 'core-tx-expense', 'ocr-source'],
        'ocr-source': ['ocr-photo-confirm', 'ocr-scanning', 'ocr-review', 'ocr-review-uncertain', 'ocr-draft'],
        'motion-show': ['motion-hide', 'root-hari', 'root-uang'],
        'motion-hide': ['motion-show', 'root-laporan', 'settings-overview'],
        'settings-overview': ['settings-model', 'settings-privacy-about', 'data-overview', 'ota-idle'],
    }
    for item in screens:
        if item['id'] in related:
            item['related'] = related[item['id']]
        if item['id'].startswith('settings-'):
            item['group'] = 'Setelan'
        elif item['id'].startswith('ota-'):
            item['group'] = 'Pembaruan'
        elif item['id'].startswith('data-'):
            item['group'] = 'Cadangan dan data'
    commit = subprocess.check_output(['git', 'log', '-1', '--format=%H', '--', 'lib'], text=True).strip()
    payload = {
        'commit': commit,
        'created': datetime.now().isoformat(timespec='minutes'),
        'screens': screens,
        'limitations': [
            'Kombinasi data dan ukuran perangkat tidak seluruhnya diwakili satu galeri. State yang dirender disebutkan per layar.',
            'Data contoh hanya untuk review. Kamera, galeri, pemilih berkas, izin dan installer adalah milik Android; referensinya tidak menggantikan uji HP.',
            'Interaksi di HTML berpindah antarstate hasil render. Belum ada transaksi, API, atau pemasangan APK yang dijalankan dari file ini.',
            'Variasi yang belum punya frame tersendiri antara lain urungkan hapus catatan, status cadangan otomatis, detail arsip kategori, hasil ekspor di penyimpanan Android, dan variasi kegagalan installer. Layar dan alur utamanya tetap dapat ditinjau.',
        ],
    }
    encoded = json.dumps(payload, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')
    output.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=output.parent, mode='w', encoding='utf-8', delete=False) as temporary:
        temporary.write(TEMPLATE.replace('__PAYLOAD__', encoded))
    Path(temporary.name).replace(output)
    summary = [{'id': row['id'], 'title': row['title'], 'group': row['group'], 'state': row['state'], 'kind': row['kind'], 'themes': list(row['images'])} for row in screens]
    (output.parent / 'coverage.json').write_text(json.dumps({'source': commit, 'screens': summary, 'limitations': payload['limitations']}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Built {output}: {len(screens)} states, {output.stat().st_size:,} bytes')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--captures', type=Path, default=Path('build/design-captures'))
    parser.add_argument('--output', type=Path, default=Path('design-review/oh-my-esok-design.html'))
    args = parser.parse_args()
    build(args.captures, args.output)
