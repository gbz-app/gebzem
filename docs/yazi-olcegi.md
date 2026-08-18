# GEBZEM YAZI ÖLÇEĞİ (type scale) — KARAR

> 17 Ağustos 2026 · 11 ajanlık araştırma + 3 mercekli adversaryal denetim
> (Threads/Instagram teardown'ları · iOS Dynamic Type · Material 3 · TR
> uygulamalarının pratiği) + kod tabanındaki **362 `fontSize`** noktasının
> envanteri. Ham çıktı: `yazi-olcegi-arastirma-ham.json`.
>
> ⚠️ **UYGULAMA ZAMANI: ARAYÜZ BİTİNCE** (kullanıcı kararı, 17 Ağu).
> Arayüz her turda değiştiği için şimdi 362 noktaya dokunmak boşa iştir.
> **AMA yeni yazılan her kod bu ölçeğe göre yazılır** — son turda iş küçülsün.

## ÖLÇEK — 6 KADEME (yedinciyi eklemeden önce iki kez düşün)

| Kademe | Punto | Kalınlık | Satır | Kullanım |
|---|---|---|---|---|
| `ekranBasligi` | 20 | w700 | 1.25 | Ekranın TEK kimlik başlığı (ekran başına bir tane). Ellipsis YOK. |
| `baslik` | 17 | w600 kimlik · w700 bölüm | 1.30 | Gönderi/yorum yazar adı · bölüm başlıkları · sheet başlıkları · büyük sayı |
| `govde` | 15 | w400 metin · w600 sayaç/buton | 1.40 | Gönderi açıklaması · mesaj metni · etkileşim sayaçları · birincil buton · liste kartı adı |
| `etiket` | 14 | w600 etiket · w400 sıkışık gövde | 1.40 | Kategori/keşif kartı alt yazısı · filtre çipleri · yorum metni · bildirim gövdesi |
| `meta` | 13 | w400 bilgi · w600 çip | 1.40 | Zaman · kart meta satırı · adres/ilçe · tüm süzgeç çipleri · yardım metni |
| `rozet` | 11 | w700 | 1.45 | **YALNIZ görsel/kapsül ÜZERİNDE** duran mikro hap: CANLI/ODA, izleyici, galeri sayacı, kampanya rozeti. En fazla 2 kelime. **11'in ALTINA İNİLMEZ** (Apple mutlak minimumu). |

## DEĞİŞMEZ (kullanıcı emri — gerekçesiz dokunma)
- Gönderi yazar adı **17**, açıklama **15**, etkileşim sayaçları **15**
- Kategori / hızlı erişim kartı alt yazısı **14 / w600**
- **`letterSpacing` YASAK** — ⚠️ TEK İSTİSNA: OTP giriş kutusu (orada
  boşluk *işlevseldir*, rakamları ayırır). Denetim bunu yakaladı.
- Canlı yayın geri sayımı **140 px** (turu 16 kullanıcı emri) muaf.

## DENETİMİN BULDUĞU **BUGÜNE AİT** HATALAR (ölçekten bağımsız)
Bunlar ölçek uygulanınca kendiliğinden düzelmez; ayrıca ele alınmalı.

1. **Sayaç genişlik tavanı `maxWidth: 54` SABİT dp** — yazı ölçeği **1.21**'i
   geçince "1,3 bin" → "1,3 b…" kırpılır. Tavan `textScaler`dan türetilmeli.
   (`gonderi_karti.dart:1615`)
2. **Etkileşim çubuğundaki `FittedBox(scaleDown)` yazı ölçeğini GERİ ALIYOR:**
   kullanıcı yazıyı büyütünce satır büyümüyor, **ikonlar küçülüyor**
   (ölçek 2.0'da ikon 26 → 16.7 dp, sayaç 15 → 10.7 pt — kendi "11 taban"
   kuralımızın altı). Alt sınır gerekiyor. (`gonderi_karti.dart:916-994`)
3. **Kompakt işletme kartı** yazı ölçeği 1.3'te **bugün 1.6 dp taşıyor**
   (meta 13'e çıkarsa 6.5 dp). `childAspectRatio: 0.86` yerine
   `mainAxisExtent` textScaler'dan türetilmeli — proje bu deseni
   `hizmet_menusu.dart:380`'de zaten doğru yazıyor.
   (`isletme_listesi.dart:971`)
4. **Kategori ekranı başlığı yan düğmelerin ÜSTÜNE BİNİYOR** — 18 puntoda
   yanda 15.9 dp bindirme. Başlık `Stack`+`Center`, yan düğmeler ayrı `Align`
   katmanı olduğu için onu İTMEZLER; `FittedBox` ~2.16 yazı ölçeğinden önce
   HİÇ devreye girmez ve RenderFlex taşması olmadığı için **hiçbir uyarı
   çıkmaz**. Başlık rezervli bir kutuya alınmalı.
   (`isletme_listesi.dart:1081-1094`)
5. Gönderi başlığındaki **zaman damgası** `Row`un esnek olmayan çocuğu ve
   `maxLines`/`overflow` taşımıyor — uzun adda taşma eşiği yakın.
6. **11 puntonun altında 8 nokta** var (8.5 · 9 · 10) — erişilebilirlik
   tabanının altı, hepsi `rozet`e çıkarılmalı.

## UYGULAMA SIRASI (arayüz bitince)
1. `core/tipografi.dart` — 6 token, tek kaynak.
2. Muhafız testi: `lib/` altında **ham `fontSize:`** kullanımı yasak
   (beyaz liste: story katmanları · geri sayım · emoji glifleri · avatar harfi).
3. Yüzey yüzey geçiş: sosyal (86) → işletme (54) → chats (37) → calls →
   auth/home (kalan ~150). Her adımda 360 dp × yazı ölçeği 1.0/1.3/2.0 ölçümü.
4. Yukarıdaki 6 hata, ilgili yüzeye gelince aynı turda kapatılır.
