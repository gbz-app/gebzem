# Şehir Rehberi — Prototip

React 18 + Vite ile şehir rehberi prototipi. **Gebzem'den bağımsız**, ayrı bir proje.

## Çalıştırma

```bash
npm install
npm run dev      # http://localhost:5173
```

## Derleme

```bash
npm run build    # -> dist/
npm run preview  # dist/ klasörünü yerelde servis eder
```

## Durum

| Parça | Durum |
|---|---|
| Vite + React 18 iskeleti | ✅ kurulu, derleme temiz |
| Renk sistemi (açık/koyu tema) | ✅ `src/index.css` tek kaynak |
| Anasayfa · kategori · mekân detayı · harita | ⏳ kapsam kararı bekliyor |

## Notlar

- `vite.config.js` içinde `base: './'` — derleme çıktısı **göreceli yol**
  kullanır, yani `dist/` herhangi bir alt dizinden servis edilebilir
  (GitHub Pages, R2, statik hosting). Kök dizin varsayımı yoktur.
- Renkler **yalnızca** `src/index.css` içindeki değişkenlerde tanımlıdır;
  bileşenlerde sabit hex yazılmaz. Tema değişikliği tek dosyadan yapılır.
- React sürümü **18.3.1'e sabitlenmiştir** (`^` yok): canlı ön izleme
  (Artifact) CDN'den aynı sürümü yükleyecek, iki ortam ayrışmasın.
