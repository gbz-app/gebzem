Kaynaktan doğruladım (dosya:satır referansları aşağıda). **Keşif çıktısındaki bir bilgi eskimiş:** repo artık **turu 73**'te (`git log`: `045bc60`, `37da616`, `c5ccec7`), `mesgulMu` imzası `mesgulMu({haric, etiket, odaYayinMuaf})` oldu (`call_provider.dart:162`). Migration numarası hâlâ **013** son (`013_call_hold.sql`), yani 014 doğru.

---

# ANKET (POLL) — MÜHENDİSLİK TASARIMI

## 0. Kararlar ve gerekçeleri (özet)

| Karar | Gerekçe |
|---|---|
| **Yeni mesaj tipi `poll`** (CHECK genişletilir), `content` = **soru metni** | Eski istemci/eski binary `type` tanımasa da `_Bubble` `content`'i basar → **soru görünür**, teknik işaretçi sızmaz (turu 59 "ham `call:ended:audio:75`" hatasının tekrarı önlenir). Geri alma (rollback) hikâyesi tasarıma gömülü. |
| **`SendMessage`'ın beyaz listesine `poll` EKLENMEZ** | `handler.go:152-157` bir güvenlik sınırı (turu 59b kimlik taklidi). Anket **ayrı uçtan** ve **transaction içinde** doğar; opsiyonsuz yetim anket satırı yapısal olarak imkânsız olur. |
| **Oy = "istenen tam küme" (set semantiği), toggle DEĞİL** | Toggle idempotent değildir; ağ zaman aşımından sonra tekrar denemek oyu **ters çevirir**. Tam küme gönderimi tekrar-güvenli. |
| **`polls.vote_seq` + tam-anlık-görüntü (snapshot) WS olayı** | WS bu projede **kaybolabilir bir kanaldır**: hub kuyruk dolunca sessizce düşürür (`hub.go:99-101`) ve istemci her arka plana geçişte soketi kapatır (`ws.dart:108-121`, turu 33 gereği ZORUNLU). Turu 61'de `call.held` tam bu yüzden kaybolmuştu. Seq + snapshot → sıra bağımsız, idempotent, kendi kendini onaran. |
| **Oy için push YOK** | FCM gürültüsü + pil + arama sırasında data-push uyandırması. Yalnız anket **oluşturma** mevcut push yolunu kullanır. |
| **Yeni Flutter paketi YOK** | Anket kamera/mikrofon/dosya kullanmaz. `flutter_riverpod` + `dio` + `lucide_icons_flutter` + `intl` yeter. **APK/IPA büyümesi ~0.** Medya altyapısını BEKLEMEZ — bugün sevk edilebilir. |

---

## 1. KULLANICI AKIŞI (dokunuştan karşı tarafta görünmeye)

### 1.1 Oluşturma
1. Sohbet ekranında giriş çubuğunun **soluna** eklenen ataç düğmesi (`LucideIcons.paperclip`) — bugün `chat_screen.dart:291`'de sadece `// Faz 2: atas (medya) butonu buraya` yorumu var, oraya gelir.
2. Alttan **"Ekle" paneli** açılır. Bugün **tek** satır: `LucideIcons.chartColumnBig` + **"Anket"**. (Medya satırları yokken **gri/pasif satır GÖSTERİLMEZ** — turu 66b dersi: "olmayan özelliğin düğmesi ekranda durursa kullanıcı yanılır".)
3. **"Anket oluştur"** tam yükseklikli sayfa açılır: Soru alanı (odak otomatik), 2 boş seçenek alanı, "Seçenek ekle" satırı (`LucideIcons.plus`), "Birden fazla yanıta izin ver" anahtarı (**varsayılan AÇIK**).
4. Kullanıcı yazar. Geçerlilik canlı: soru boş değil + ≥2 dolu benzersiz seçenek → sağ üstteki **"Gönder"** etkinleşir.
5. "Gönder" → düğme kilitlenir (`_gonderiliyor`), `POST /chats/{chatID}/polls`.
6. **201** dönünce sayfa kapanır (`Navigator.of(sheetContext).pop()`), balon listede belirir, otomatik en alta kayar (`_scrollToBottom`, `chat_screen.dart:124`).
7. Hata → sayfa **KAPANMAZ**, girilen metin korunur, SnackBar'da sunucu mesajı (`apiErrorMessage`, `api.dart:80` sunucunun `error` alanını **aynen** gösterir → sunucu metinleri Türkçe yazılmak zorunda).

### 1.2 Karşı tarafta görünme
8. Sunucu commit'ten sonra `message.new` yayınlar — payload'da **`poll` nesnesi gömülü**. Karşı taraf ek REST çağrısı yapmadan balonu çizer (`chats_provider.dart:88-99` mevcut yol).
9. Sohbeti kapalıysa: FCM push **"Ad: Anket · Bu akşam nerede buluşalım?"** (`push.NotifyUsers`, mevcut yol) + sohbet listesinde `LucideIcons.chartColumnBig` + `Anket · <soru>` + okunmamış rozeti.

### 1.3 Oy verme
10. Seçeneğe dokunma → **anında yerel (iyimser) güncelleme**: işaret dolar, sayı +1, çubuk 260 ms `easeOutCubic` ile büyür.
11. **350 ms debounce**; sürede yeni dokunuş gelirse sayaç sıfırlanır (çoklu seçimde 3 kutu işaretlemek **1 istek** eder).
12. `POST /polls/{id}/vote {"option_ids":[41,43]}`. **Anket başına aynı anda TEK istek uçar**; uçarken yeni seçim yapılırsa "bekleyen küme" olarak saklanır ve mevcut istek bitince gönderilir → aynı anket için yanıtların sırası bozulamaz.
13. Sunucu: anket satırını `FOR UPDATE` ile kilitler → eski oylarımı siler → yenileri ekler → `vote_seq++` → tam sayımı hesaplar → **commit**.
14. WS `poll.vote` (tam anlık görüntü + seq) **tüm üyelere + oy verenin diğer cihazlarına** gider. Yerel istemciye hem WS olayı hem HTTP yanıtı gelir; **seq kapısı** ikinci gelen aynı seq'i sessizce yutar → çift uygulama yok.
15. Karşı tarafta çubuklar ve sayılar canlı akar.

### 1.4 Oyları görme / bitirme
16. Balonun altındaki **"Oyları gör"** (`LucideIcons.users`) → `GET /polls/{id}` → seçenek başına oy verenlerin ad listesi (avatar + isim).
17. Anketi **oluşturan** (veya grup sohbetinde `owner`/`admin`) balonda **"Anketi bitir"** (`LucideIcons.circleStop`) görür → onay diyaloğu → `POST /polls/{id}/close`.
18. Kapanınca: seçenekler tıklanamaz olur, üstte **"Anket sona erdi"** satırı çıkar, WS `poll.closed` ile herkeste aynı anda.

---

## 2. BACKEND

### 2.1 Değişecek/eklenecek dosyalar

| Dosya | Ne değişecek |
|---|---|
| **YENİ** `backend/internal/chat/anket.go` | 4 handler + DTO'lar + sayım/yayın yardımcıları. `chat` paketinin içinde: `h.db`, `h.hub`, `h.push`, `chatMemberIDs` (`handler.go:409`), `writeJSON`/`httpErr` (`handler.go:433,439`) hazır — **yeni paket + import döngüsü riski yok**. |
| `backend/internal/chat/handler.go:18-26` | `Handler`'a `rdb *redis.Client` alanı + `NewHandler` imzasına parametre (hız sınırı için; `chat` paketinin bugün Redis erişimi **yok**). |
| `backend/internal/chat/handler.go:152-157` | **DOKUNULMAZ.** `poll` beyaz listeye **EKLENMEZ** (bkz. §0). |
| `backend/internal/chat/handler.go:234-265` (`GetMessages`) | `msg` struct'ına `Poll *anketDTO` alanı + döngüden sonra **tek ek sorguyla** anket verisini iliştirme. `deleted_for_all` ise iliştirilmez (satır 236-237'deki maskeleme mantığıyla tutarlı). |
| `backend/internal/chat/handler.go:196-209` | `preview[:80]` **UTF-8 kesme hatası** (Türkçe karakter ortadan bölünüyor) — ortak `onizlemeKirp(s string, n int) string` (`[]rune` tabanlı) yardımcısına çevrilir; anket push'u da onu kullanır. |
| `backend/cmd/api/main.go:76` | `chat.NewHandler(db, hub, pushSender, rdb)` — `rdb` satır 64'te, `hub` 69'da oluşuyor, sıra uygun. |
| `backend/cmd/api/main.go:162` sonrası | 4 yeni rota (korumalı grubun içinde). |

```go
// main.go — satir 162'den sonra
// Anket (poll) — sohbet icindeki oylama
r.Post("/chats/{chatID}/polls", chatH.PollCreate)
r.Get("/polls/{id}", chatH.PollGet)
r.Post("/polls/{id}/vote", chatH.PollVote)
r.Post("/polls/{id}/close", chatH.PollClose)
```

### 2.2 `POST /chats/{chatID}/polls` — anket oluştur

**İstek**
```json
{ "question": "Bu akşam nerede buluşalım?",
  "options": ["Kahve dükkanı", "Sahil", "Evde"],
  "multi": true }
```

**Doğrulama sırası (hepsi 400 döner, mesajlar kullanıcıya AYNEN gösterilir)**

| Kural | Hata metni |
|---|---|
| Gövde çözülemedi | `geçersiz istek` |
| `question` trim sonrası boş | `Anket sorusu boş olamaz` |
| `question` > 300 rune | `Anket sorusu çok uzun` |
| `options` < 2 (trim + boş eleme sonrası) | `En az 2 seçenek gerekli` |
| `options` > 12 | `En fazla 12 seçenek ekleyebilirsiniz` |
| bir seçenek > 100 rune | `Seçenek metni çok uzun` |
| seçenekler trim sonrası **tekrar ediyor** | `Seçenekler birbirinden farklı olmalı` |

⚠️ Uzunluklar **rune** ile ölçülür (`utf8.RuneCountInString`) — byte ile ölçmek Türkçe'de yanlış sınır verir.

**Yetki:** `chatMemberIDs(r, chatID, userID)` hata verirse **403** `bu sohbetin üyesi değilsiniz`.

**Engel kontrolü (YENİ yüzey — fail-closed):** sohbet `direct` ise `blocks` çift yönlü sorgulanır (`CreateDirect`'teki sorgunun aynısı, `handler.go:281-284`); engelliyse **403** `bu kullanıcıyla anket paylaşılamıyor`.
> 🔴 **Dürüst not:** `SendMessage`'da bugün **engel kontrolü YOK** (`handler.go:159`'daki `// uyelik + engel kontrolu` yorumu **yanlış**) ve `blocks` tablosuna **INSERT eden hiçbir uç yok** (doğruladım: `grep "INTO blocks"` → 0 sonuç). Yani bu kontrol bugün fiilen no-op'tur; **doğru olduğu için** konuyor, mevcut açığı kapatmıyor. Mevcut açık **ayrı iş**.

**Hız sınırı (Redis):**
```
SetNX  anket:yeni:{uid}                 = 10 sn   -> 429 "Çok hızlı anket oluşturuyorsunuz"
INCR   anket:gun:{uid}:{YYYYMMDD} (TTL 24s) > 30  -> 429 "Günlük anket sınırına ulaştınız"
```
⚠️ **Redis HATASI durumunda İZİN VERİLİR (fail-open).** `streams/handler.go:445` deseni `ok, _ := SetNX(...)` ile hata durumunda **engelliyor**; anket için bu yanlış olurdu (Redis düşünce özellik tamamen ölür). Bu anti-spam, güvenlik sınırı değil. `err != nil` → geç.

**Transaction (tek `pgx.Tx`):**
```sql
INSERT INTO messages (chat_id, sender_id, type, content)
VALUES ($1,$2,'poll',$3) RETURNING id, created_at;          -- content = SORU

INSERT INTO polls (message_id, chat_id, creator_id, question, multi)
VALUES ($1,$2,$3,$4,$5) RETURNING id;

INSERT INTO poll_options (poll_id, idx, text)
SELECT $1, (i-1)::smallint, t
FROM unnest($2::text[]) WITH ORDINALITY AS a(t, i);

INSERT INTO message_receipts (message_id, user_id)
SELECT $1, user_id FROM chat_members WHERE chat_id=$2
ON CONFLICT DO NOTHING;
```
⚠️ Makbuzlar **transaction İÇİNDE**. Mevcut `SendMessage` bunları tx dışında, hatayı yutarak döngüyle yazıyor (`handler.go:179-183`) — bir alıcıda başarısız olursa okunmamış sayacı sonsuza kadar yanlış kalır. Yeni yüzeyde o hatayı tekrarlamıyoruz.

**Commit sonrası (asla önce değil):**
```go
h.hub.Publish(ctx, &Event{Type:"message.new", ChatID: chatID, Payload: payload, To: members})
go h.push.NotifyUsers(members, senderName, "Anket · "+onizlemeKirp(soru, 70), chatID)
```
`payload` = normal mesaj alanları **+ `"poll": {...}`**.

**Yanıt 201:** tam mesaj nesnesi (`id, chat_id, sender_id, type:"poll", content, created_at, poll:{...}`).
> ⚠️ `SendMessage` bugün yalnız `{id, created_at}` dönüyor ve istemci ardından **tüm listeyi yeniden çekiyor** (`chats_provider.dart:82 await load()`). Anket için tam nesne dönmek bu ekstra REST'i gereksiz kılar.

### 2.3 `POST /polls/{id}/vote` — oy ver / değiştir / geri çek

**İstek:** `{"option_ids":[41,43]}` — **istenen TAM küme**. `[]` = tüm oylarımı geri çek.

**Hız sınırı:** `SetNX anket:oy:{pollID}:{uid} = 1 sn` → 429 `Çok hızlı oy veriyorsunuz`.

**Transaction:**
```sql
-- 1) ANKETI KILITLE — ayni ankete es zamanli oylar SIRALANIR (linearizable sayim)
SELECT chat_id, multi, closed_at FROM polls WHERE id=$1 FOR UPDATE;      -- yoksa 404

-- 2) uyelik: chatMemberIDs(chat_id, userID)                              -- yoksa 403
-- 3) kapali mi                                                            -- ise 409
-- 4) multi=false ve len(option_ids)>1                                     -- ise 400
-- 5) secenekler bu ankete mi ait
SELECT count(*) FROM poll_options WHERE poll_id=$1 AND id = ANY($2::bigint[]);
--    sonuc != len(option_ids)                                             -- ise 400

-- 6) istenen kumede OLMAYAN eski oylarimi sil  (bos dizi -> HEPSI silinir)
DELETE FROM poll_votes
WHERE poll_id=$1 AND user_id=$2 AND option_id <> ALL($3::bigint[]);

-- 7) eksikleri ekle (idempotent)
INSERT INTO poll_votes (poll_id, option_id, user_id)
SELECT $1, o, $2 FROM unnest($3::bigint[]) AS o
ON CONFLICT DO NOTHING;

-- 8) surum
UPDATE polls SET vote_seq = vote_seq + 1 WHERE id=$1 RETURNING vote_seq;
```
⚠️ `option_id <> ALL('{}')` boş dizide **TRUE** döner → tüm oylarım silinir. Geri çekme davranışı budur, bilerek.
⚠️ Adım 1'deki `FOR UPDATE` **zorunlu**: sayım aynı kilidin altında okunduğu için iki eşzamanlı oy asla birbirinin sayımını ezemez ve `vote_seq` **monoton** kalır. Seq monotonluğu istemcideki tüm bayat-olay kapısının dayanağı.

**Sayım sorgusu (commit'ten önce, aynı tx):**
```sql
SELECT o.id, o.idx, o.text,
       COUNT(v.user_id)                                   AS oy,
       COUNT(*) FILTER (WHERE v.user_id = $2)             AS benim
FROM poll_options o
LEFT JOIN poll_votes v ON v.option_id = o.id
WHERE o.poll_id = $1
GROUP BY o.id, o.idx, o.text
ORDER BY o.idx;

SELECT COUNT(*), COUNT(DISTINCT user_id) FROM poll_votes WHERE poll_id=$1;
```

**Hatalar:** 400 `geçersiz seçenek` / `Bu ankette yalnızca bir seçenek işaretlenebilir` · 403 `bu sohbetin üyesi değilsiniz` · 404 `anket bulunamadı` · **409 `Bu anket kapatıldı`** · 429.

**Yanıt 200:** `{"poll": {...tam DTO, mine bayrakları BENİM için...}}`

**WS yayını (commit sonrası):** `poll.vote`, **`To` = diğer üyeler + KENDİM**.
> ⚠️ `chatMemberIDs` çağıranın kendisini listeden **çıkarır** (`handler.go:421-425`). Anket olaylarında oy verenin **diğer cihazları** güncellenmek zorunda → `To = append(members, userID)`. **`chatMemberIDs`'in davranışını DEĞİŞTİRME** — `message.new`/`typing`/`receipt.read` ona bağlı, dokunmak regresyon üretir.

### 2.4 `POST /polls/{id}/close` — anketi bitir

```sql
UPDATE polls p SET closed_at = now(), vote_seq = vote_seq + 1
WHERE p.id=$1 AND p.closed_at IS NULL
  AND ( p.creator_id = $2
        OR EXISTS (SELECT 1 FROM chat_members cm
                   WHERE cm.chat_id = p.chat_id AND cm.user_id = $2
                     AND cm.role IN ('owner','admin')) )
RETURNING closed_at, vote_seq;
```
- `RowsAffected == 0` → anket zaten kapalıysa **200** (idempotent, olay yayınlanmaz); yetki yoksa **403** `Bu anketi yalnızca oluşturan kapatabilir`; yoksa **404**.
- Rol kapısı bugün no-op (`chat_members.role` hiçbir yerde yazılmıyor — doğruladım, hepsi varsayılan `member`), **grup sohbeti geldiğinde hazır olsun diye** konuyor.
- Başarıda WS `poll.closed`.

### 2.5 `GET /polls/{id}` — tam durum + oy verenler

Kullanımı: (a) "Oyları gör" ekranı, (b) WS yeniden bağlandıktan sonra kendini onarma, (c) uygulama öldürülüp dönüldüğünde.

**Yanıt 200**
```json
{ "id": 12, "message_id": 908, "chat_id": "…", "creator_id": "…",
  "question": "Bu akşam nerede buluşalım?", "multi": true,
  "closed": false, "closed_at": null, "seq": 8,
  "voter_count": 3, "total_votes": 4,
  "options": [
    { "id": 41, "idx": 0, "text": "Kahve dükkanı", "votes": 2, "mine": true,
      "voters": [ {"user_id":"…","name":"Ayşe","avatar_url":""},
                  {"user_id":"…","name":"Mehmet","avatar_url":""} ],
      "voters_more": 0 }
  ] }
}
```
`voters` seçenek başına **en fazla 100** kayıt (`ORDER BY created_at`), fazlası `voters_more` sayısı olarak. 1:1'de zaten en fazla 2.
**Anonim DEĞİL** — ürün kararı, WhatsApp ile aynı. Balon üstünde "Oylar herkese açıktır" ipucu satırı gösterilir (dürüstlük).

---

## 3. VERİTABANI — `014_anket.sql`

> ⚠️ **Numara çakışması:** medya/moderasyon tasarımları da 014 istiyor. Hangisi önce sevk edilirse 014'ü alır; diğeri 015'e kayar. Migrate adı-bazlı çalışır (`database.go:43-63`, `sort.Strings` + `schema_migrations.name`), aynı numaralı iki FARKLI ad ikisini de uygular — ama karışıklık yaratır, **sevk sırasında yeniden numaralandır**.

```sql
-- 014_anket.sql — SOHBET ICI ANKET (poll)
--
-- NEDEN AYRI TABLOLAR: oy sayisi mesaj satirinda tutulamaz (her oy bir UPDATE
-- olur, mesaj satirini kilitler ve `ORDER BY id DESC` indeksini surekli sisirir).
-- Oylar kendi tablosunda; sayim indeksli COUNT ile alinir.
--
-- ⚠️ ADDITIVE: mevcut hicbir sutun/veri degismez. Tek istisna `messages.type`
-- CHECK'inin GENISLETILMESI (mevcut degerlerin USTKUMESI -> hicbir satir ihlal
-- edemez). Rollback: eski binary 'poll' satirlarini metin gibi okur, `content`
-- SORU METNI oldugu icin ekranda anlamli bir balon cikar (teknik isaretci sizmaz).

-- 1) messages.type CHECK genisletmesi -----------------------------------------
-- ⚠️ Kisitin adi 001_init.sql:55'te SATIR ICI yazildigi icin Postgres tarafindan
--    uretilir (`messages_type_check`). ADI VARSAYMAK TEHLIKELI: yanlis adla
--    DROP ederiz, ADD basarili olur, ESKI kisit yerinde kalir ve 'poll' SESSIZCE
--    reddedilir. Bu yuzden kisit TANIMDAN bulunur.
DO $$
DECLARE ad TEXT;
BEGIN
  SELECT con.conname INTO ad
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  WHERE c.relname = 'messages' AND con.contype = 'c'
    AND pg_get_constraintdef(con.oid) LIKE '%''location''%'
  LIMIT 1;
  IF ad IS NOT NULL THEN
    EXECUTE format('ALTER TABLE messages DROP CONSTRAINT %I', ad);
  END IF;
END $$;

ALTER TABLE messages ADD CONSTRAINT messages_type_check
  CHECK (type IN ('text','image','video','audio','location','system','poll'));

-- 2) anketler -----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS polls (
    id         BIGSERIAL PRIMARY KEY,
    -- Mesaj SILINIRSE anket de gider (bugun mesaj silme ucu YOK; geldiginde
    -- temizlik KENDILIGINDEN calisir — tasarima gomulu kanca).
    message_id BIGINT NOT NULL UNIQUE REFERENCES messages(id) ON DELETE CASCADE,
    -- chat_id denormalize: uyelik/engel kontrolu icin messages'a JOIN gerekmesin.
    -- ⚠️ messages.chat_id ile AYNI olmak zorunda; tek yazan biz oldugumuz icin
    --    trigger konmadi (yazan tek uc: POST /chats/{chatID}/polls).
    chat_id    UUID   NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
    creator_id UUID   NOT NULL REFERENCES users(id),
    question   TEXT   NOT NULL,
    multi      BOOLEAN NOT NULL DEFAULT FALSE,   -- birden fazla yanit
    closed_at  TIMESTAMPTZ,                      -- NULL = acik
    -- ⚠️ vote_seq: HER oy/kapatma islemi bunu 1 artirir. WS olaylari bu degeri
    --    tasir; istemci `yeniSeq <= mevcutSeq` ise olayi YOK SAYAR. WS bu projede
    --    KAYBOLABILIR (hub.go:99-101 kuyruk dolunca DUSURUR; ws.dart:108 arka
    --    plana gecince soket KAPANIR) — turu 61'de `call.held` boyle kaybolmustu.
    -- ⚠️ YAPMA: bu sutunu kaldirip "son yazan kazanir" davranisina donme.
    vote_seq   BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_polls_chat ON polls (chat_id, id DESC);

-- 3) secenekler ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS poll_options (
    id      BIGSERIAL PRIMARY KEY,
    poll_id BIGINT   NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    idx     SMALLINT NOT NULL,     -- 0..11, GORUNTULEME SIRASI
    text    TEXT     NOT NULL,
    UNIQUE (poll_id, idx)
);
CREATE INDEX IF NOT EXISTS idx_poll_options_poll ON poll_options (poll_id, idx);

-- 4) oylar --------------------------------------------------------------------
-- PK = (poll_id, option_id, user_id): ayni oy iki kez atilamaz (ON CONFLICT DO
-- NOTHING ile idempotent). Coklu secimde ayni kullanici birden cok satir tutar.
CREATE TABLE IF NOT EXISTS poll_votes (
    poll_id    BIGINT NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_id  BIGINT NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
    user_id    UUID   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (poll_id, option_id, user_id)
);
-- "benim oylarim" + oy degistirmede kullanilan DELETE icin
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_user ON poll_votes (poll_id, user_id);
-- secenek basina sayim icin
CREATE INDEX IF NOT EXISTS idx_poll_votes_option ON poll_votes (option_id);
```

**Deploy sırası güvenli mi? EVET, kanıtla:** `database.Migrate` `main.go:56`'da, router kurulumu `main.go:96`'da → migration **HTTP servisi başlamadan** biter. Tek API instance (docker compose) olduğu için "yeni binary + eski şema" penceresi **yoktur**.

**`messages` tablosuna nasıl bağlanır:** `polls.message_id → messages.id` (UNIQUE, CASCADE). Mesaj akışında sıralama/sayfalama tamamen mevcut `idx_messages_chat (chat_id, id DESC)` üzerinden yürür; anket tablolarının akış performansına etkisi yok.

**Reddedilen alternatif (dürüstlük için):** anketi `type='text'` olarak yazıp CHECK'e hiç dokunmamak. Migration riski sıfır olurdu **ama** `ListChats` (`handler.go:326-349`) `last_type`'a bakıyor; 'text' dönerse sohbet listesinde anket ikonu/önizlemesi **üretilemez** ve ileride "sohbetteki anketler" filtresi imkânsız olur. Ayrıca `type='system'` kullanmak da reddedildi: 'system' bu projede "sunucu üretimi, gönderen kimliği yok" anlamına geliyor ve `arama_kaydi.dart` sözleşmesine bağlı (`chat_screen.dart:251`, `chats_screen.dart:248`) — anketin göndereni **gerçek bir kullanıcıdır**.

---

## 4. WS OLAY SÖZLEŞMESİ

Taşıyıcı değişmiyor: `Event{Type, ChatID, Payload, To}` (`hub.go:30-36`) → Redis `events` → `deliver`. **`hub.go`'da tek satır değişiklik yok.**

### 4.1 `message.new` (mevcut olay, payload genişledi)
```json
{ "type":"message.new", "chat_id":"…",
  "payload": { "id":908, "chat_id":"…", "sender_id":"…", "type":"poll",
    "content":"Bu akşam nerede buluşalım?", "media_url":"", "reply_to_id":null,
    "created_at":"2026-08-07T21:04:11Z",
    "poll": { "id":12, "question":"Bu akşam nerede buluşalım?", "multi":true,
      "closed":false, "seq":0, "voter_count":0, "total_votes":0,
      "options":[ {"id":41,"idx":0,"text":"Kahve dükkanı","votes":0,"mine":false},
                  {"id":42,"idx":1,"text":"Sahil","votes":0,"mine":false} ] } } }
```
⚠️ `mine` burada **her zaman false** (yayın herkese aynı gider; yeni ankette kimse oy vermemiştir — sorun yok).

### 4.2 `poll.vote` (YENİ) — **tam anlık görüntü**
```json
{ "type":"poll.vote", "chat_id":"…",
  "payload": { "poll_id":12, "message_id":908, "seq":5, "closed":false,
    "voter_count":2, "total_votes":3,
    "options":[ {"id":41,"votes":2}, {"id":42,"votes":1} ],
    "voter_id":"<oy veren uuid>", "voter_option_ids":[41] } }
```
- **Neden tam anlık görüntü, delta değil:** delta uygulamak sıra ve kayıp toleransı ister; anlık görüntü **sıra bağımsız + idempotent**. 12 seçenekli payload ~250 bayt.
- `mine` **yok** — her istemci `voter_id == benimId` ise `voter_option_ids`'ten kendi seçimini günceller. Bu aynı zamanda **çok cihaz senkronunu** çözer.
- `To` = diğer üyeler **+ oy veren** (§2.3 uyarısı).

### 4.3 `poll.closed` (YENİ)
```json
{ "type":"poll.closed", "chat_id":"…",
  "payload": { "poll_id":12, "message_id":908, "seq":6, "closed":true,
    "closed_at":"…", "voter_count":2, "total_votes":3,
    "options":[ {"id":41,"votes":2}, {"id":42,"votes":1} ] } }
```
İstemcide `poll.vote` ile **aynı uygulayıcıdan** geçer (tek kod yolu), yalnız ek olarak "Anket sona erdi" bilgi satırı görünür.

### 4.4 İstemciden sunucuya WS olayı — **YOK**
Oy `POST` ile gider. Sunucu WS okuyucusu yalnız `bg` ve `typing` işliyor (`handler.go:105-121`); oraya yeni bir `case` **eklenmez** — o yol kimlik doğrulaması dışında hiçbir yetki/hız kontrolü çalıştırmıyor ve yanıt/hata kanalı yok.

### 4.5 ⚠️ Çok kritik kural — sohbet listesi tazelenmesi
`chats_provider.dart:32` bugün `message.new` **veya** `receipt.read` gelince **tüm `/chats` listesini yeniden çekiyor**. `poll.vote` yeni bir ad olduğu için o koşula **düşmez** (doğruladım: satır 32 iki ada birebir bakıyor).
> ⚠️⚠️ **YAPMA:** `poll.vote`/`poll.closed`'i o koşula ekleme. Hareketli bir ankette saniyede birkaç oy = saniyede birkaç `/chats` REST çağrısı; hücresel ağda ve **arama sürerken** tam olarak kaçınmamız gereken yük. Anketin son mesajı zaten değişmiyor, listenin tazelenmesine **gerek yok**.

### 4.6 `ws.acildi` — yerel sentetik olay (kendini onarma tetikleyicisi)
`ws.dart` bugün "yeniden bağlandım" sinyali üretmiyor. `_open()` içinde `_connected = true;` satırından hemen sonra:
```dart
_controller.add({'type': 'ws.acildi'});   // YEREL sentetik olay — sunucudan GELMEZ
```
**Güvenlik doğrulaması (yaptım):** tüm dinleyiciler tipe göre filtreliyor —
`call_provider.dart:200-202` (`payload is! Map` → erken `return`, bu olayda payload yok),
`chats_provider.dart:32` ve `:87` (ada bakıyor), `davet_provider.dart:31` (ada bakıyor),
`live_tab.dart:35`, `rooms_tab.dart:32`, `room_screen.dart:149`. **Çarpışma yok.**
⚠️ Ad Türkçe seçildi ki sunucunun İngilizce noktalı adlarıyla asla çakışmasın.

---

## 5. FLUTTER

### 5.1 Dosya planı

| Dosya | Durum |
|---|---|
| `mobile/lib/features/chats/anket.dart` | **YENİ** — `Anket`, `AnketSecenek` modelleri + snapshot uygulayıcı. `arama_kaydi.dart` gibi **tek ayrıştırma kaynağı** (balon + liste önizlemesi aynı yerden okur). |
| `mobile/lib/features/chats/anket_balonu.dart` | **YENİ** — `AnketBalonu` widget'ı. |
| `mobile/lib/features/chats/anket_olustur_sayfasi.dart` | **YENİ** — oluşturma sayfası (modal bottom sheet, `isScrollControlled: true`). |
| `mobile/lib/features/chats/anket_oylar_sayfasi.dart` | **YENİ** — "Oyları gör". |
| `mobile/lib/features/chats/models.dart:52-85` | `Message`'a `Anket? anket` (mutable, `read` gibi) + `fromJson`'da `j['poll']`. |
| `mobile/lib/features/chats/chats_provider.dart` | `poll.vote`/`poll.closed`/`ws.acildi` işleme + `anketOlustur`/`anketOyVer`/`anketKapat` + uçuş kuyruğu. |
| `mobile/lib/features/chats/chat_screen.dart:251-261` | Balon dallanmasına anket dalı. |
| `mobile/lib/features/chats/chat_screen.dart:269-303` | Ataç düğmesi + "Ekle" paneli. |
| `mobile/lib/features/chats/chats_screen.dart:219-260` | `_previewIkon()` ve `_preview()`'a `case 'poll'`. |
| `mobile/lib/core/ws.dart:69` | `ws.acildi` sentetik olayı (§4.6). |
| `mobile/pubspec.yaml` | **DEĞİŞMEZ — yeni paket yok.** |

### 5.2 Model (`anket.dart`)

```dart
class AnketSecenek {
  const AnketSecenek({required this.id, required this.sira,
      required this.metin, required this.oy, required this.benim});
  final int id, sira, oy;
  final String metin;
  final bool benim;
  AnketSecenek kopya({int? oy, bool? benim}) => ...;
}

class Anket {
  const Anket({required this.id, required this.mesajId, required this.soru,
      required this.coklu, required this.kapali, required this.seq,
      required this.oyVeren, required this.toplamOy,
      required this.secenekler, this.bekliyor = false});

  final int id, mesajId, seq, oyVeren, toplamOy;
  final String soru;
  final bool coklu, kapali, bekliyor;   // bekliyor: benim oyum ucusta
  final List<AnketSecenek> secenekler;

  List<int> get benimSecimlerim =>
      [for (final s in secenekler) if (s.benim) s.id];

  /// Yuzde paydasi OY VEREN KISI sayisi (coklu secimde toplam %100'u ASABILIR —
  /// dogrusu budur: "3 kisinin 2'si bunu secti").
  double oran(AnketSecenek s) => oyVeren == 0 ? 0 : s.oy / oyVeren;

  /// WS/REST anlik goruntusunu uygular. `seq` GERI GIDIYORSA (bayat olay) null
  /// doner ve cagiran HICBIR SEY yapmaz.
  /// ⚠️ YAPMA: bu kapiyi kaldirma — WS bu projede sirasiz/kayipli bir kanaldir.
  Anket? anlikGoruntuUygula(Map<String, dynamic> p, String? benimId) { ... }

  /// SOHBET LISTESI onizlemesi — ham `content` BASILMAZ (turu 59 dersi).
  static String onizleme(String soru) =>
      soru.isEmpty ? 'Anket' : 'Anket · $soru';
}
```

### 5.3 Durum yönetimi (Riverpod) — mevcut mimariye oturur

**Yeni provider AÇILMAZ.** Anket durumu `Message.anket` içinde yaşar; `messagesProvider` (`chats_provider.dart:121-123`, `family.autoDispose`) zaten tek sahip. Mevcut `m.read = true` deseniyle (satır 103-105) birebir tutarlı.

`MessagesNotifier` eklentileri:
```dart
// anket basina TEK ucus + bekleyen kume (ayni ankete ait yanitlarin sirasi bozulamaz)
final Map<int, bool> _ucusta = {};
final Map<int, List<int>> _bekleyen = {};
final Map<int, Timer> _debounce = {};

Future<void> anketOyVer(int pollId, List<int> istenen) async {
  _debounce[pollId]?.cancel();
  _yerelIyimserUygula(pollId, istenen);            // ANINDA gorunum
  _debounce[pollId] = Timer(const Duration(milliseconds: 350),
      () => _oyGonder(pollId, istenen));
}

Future<void> _oyGonder(int pollId, List<int> istenen) async {
  if (_ucusta[pollId] == true) { _bekleyen[pollId] = istenen; return; }
  _ucusta[pollId] = true;
  try {
    final res = await _ref.read(apiProvider)
        .post('/polls/$pollId/vote', data: {'option_ids': istenen});
    _anlikGoruntu(pollId, (res.data as Map)['poll'] as Map<String, dynamic>);
  } catch (e) {
    await _anketiTazele(pollId);                   // SUNUCU OTORITEDIR — geri sar
    _hataBildir(apiErrorMessage(e));
  } finally {
    _ucusta[pollId] = false;
    final b = _bekleyen.remove(pollId);
    if (b != null) unawaited(_oyGonder(pollId, b));
  }
}
```
⚠️ **Neden "nesil jetonu" yerine tek-uçuş:** seq kapısı sıra sorununu zaten çözer, ama **iyimser yerel durum** seq taşımaz; iki yanıt sıra dışı gelirse kullanıcı seçiminin bir an geri sekmesini görür. Tek-uçuş + debounce bunu **yapısal olarak** imkânsız kılar.

WS işleme (`_onEvent` içine, mevcut `switch`'e iki `case`):
```dart
case 'poll.vote':
case 'poll.closed':
  final p = ev['payload'] as Map<String, dynamic>;
  _anlikGoruntu(p['poll_id'] as int, p);   // seq kapisi anket.dart icinde
case 'ws.acildi':
  _acikAnketleriTazele();  // WS kapaliyken kacan oylari GET /polls/{id} ile onar
```
⚠️ `ws.acildi` `if (ev['chat_id'] != chatId) return;` (satır 86) kapısına takılır — o satır **`chat_id` yoksa da erken döner**. Bu yüzden `ws.acildi` kontrolü **o kapının ÜSTÜNE** konur. Bunu atlamak sessiz ölü kod üretir (turu 48 dersi).

### 5.4 Balon görünümü (`anket_balonu.dart`) — Lucide, **EMOJİ YOK**

```
┌──────────────────────────────────────────┐   maxWidth: ekran * 0.78
│ ▤ Anket · Birden fazla yanıt             │   chartColumnBig 14px + outline renk
│                                          │
│ Bu akşam nerede buluşalım?               │   15.5 / w700
│                                          │
│ ◉ Kahve dükkanı                       2  │   circleDot | circle   (tekli)
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░         │   AnimatedFractionallySizedBox 260ms
│ ○ Sahil                               1  │
│ ▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░         │
│ ○ Evde                                0  │
│                                          │
│ 3 kişi oy verdi · Oylar herkese açık     │   12.5 / outline
│ ─────────────────────────────────────    │
│ 👥 Oyları gör          ⏹ Anketi bitir     │   users / circleStop  (ikinci: yalniz sahibi)
│                                21:04 ✓✓  │   mevcut _Bubble alt satiri
└──────────────────────────────────────────┘
```
- Çoklu seçimde işaret: `LucideIcons.squareCheck` / `LucideIcons.square`. Tekli: `LucideIcons.circleDot` / `LucideIcons.circle`. **Hepsi paket içinde doğrulandı** (`lucide_icons_flutter-3.1.15`).
- Kapalı anket: seçenekler `IgnorePointer`, işaret ikonları soluk, üstte `LucideIcons.lock` + **"Anket sona erdi"**.
- `bekliyor == true` iken sağ üstte 12px `SizedBox(CircularProgressIndicator(strokeWidth:1.6))` (düğmeler kilitlenmez — dokunuş kuyruğa girer).
- Renkler: kendi balonum `scheme.bubbleMine`, karşınınki `scheme.bubbleOther` — mevcut `_Bubble` (`chat_screen.dart:629`) ile aynı; dolgu çubuğu `scheme.primary.withValues(alpha: 0.18)`.
- ⚠️ **Emoji yok, Material ikon yok** (turu 62 emri). Yüzde metni yok — WhatsApp gibi **oy sayısı** yazılır (Türkçe'de "%67" 3 kişilik ankette yanıltıcı).

`chat_screen.dart:251-261` dallanması:
```dart
if (msg.type == 'system')
  _CallLogChip(...)
else if (msg.type == 'poll' && msg.anket != null)
  AnketBalonu(mesaj: msg, benimMi: mine)
else
  _Bubble(message: msg, mine: mine)   // anket==null -> content=SORU, zarif dususs
```
⚠️ `itemCount: list.length + 1` ve son elemanın `_AktifAramaBalonu` olması (satır 241-243) **değişmez** — indeks matematiğine dokunulmaz.

### 5.5 Oluşturma sayfası
- `showModalBottomSheet(context: context, isScrollControlled: true, useSafeArea: true, ...)` — **`useRootNavigator` VARSAYILAN (false) bırakılır.**
- Kapanış **yalnız** `Navigator.of(sheetContext).pop()`. ⚠️ **YAPMA:** `rootNavigatorKey` üzerinden pop etme — turu 59b dersi: `pop()` en üstteki route'u kapatır, "beni" değil; araya giren arama ekranını öldürür.
- Alanlar: `TextEditingController` listesi; seçenek silme yalnız >2 iken (`LucideIcons.trash2`); ekleme 12'de kilitlenir (`LucideIcons.plus`).
- Sürükle-bırak yeniden sıralama **YOK** (dürüst kapsam notu; `gripVertical` ikonu paket içinde var ama V1'de kullanılmıyor).
- Klavye: `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))`.

### 5.6 Sohbet listesi (`chats_screen.dart`)
```dart
// _previewIkon()  (satir 219)
case 'poll':
  return LucideIcons.chartColumnBig;

// _preview()      (satir 238)
case 'poll':
  return Anket.onizleme(chat.lastMessage);   // "Anket · Bu akşam nerede buluşalım?"
```
⚠️ Bu **zorunlu**: `default` dalı (satır 258) `chat.lastMessage`'ı HAM basar. `content`=soru olduğu için felaket değil ama "Anket" bağlamı kaybolur.

---

## 6. KENAR DURUMLAR

| Durum | Davranış |
|---|---|
| **Ağ koptu — anket oluştururken** | POST hata verir → sayfa **kapanmaz**, girilen soru/seçenekler durur, SnackBar `Sunucuya ulaşılamıyor...` (`api.dart:83`). Kullanıcı "Gönder"e tekrar basar. **Taslak diske yazılmaz** (V1). |
| **Ağ koptu — oy verirken** | İyimser görünüm anında geri sarılır (`_anketiTazele` → `GET /polls/{id}` de patlarsa **eldeki son durum** korunur, seçim geri alınır) + SnackBar. Yeniden dokunuş yeni istek. |
| **Uygulama arka plana geçti** | `ws.dart:108 goOffline()` soketi **kapatır** (kilit ekranı araması için ZORUNLU, turu 33). O sürede gelen `poll.vote` **KAYBOLUR**. Dönüşte `resume()` → `_open()` → **`ws.acildi`** → açık anketler `GET /polls/{id}` ile tazelenir. Bu, turu 61 `call.held` kaybının aynısıdır ve aynı reçeteyle çözülür. |
| **Uygulama ÖLDÜRÜLDÜ** | Hiçbir yerel durum kaybolmaz — anket **sunucuda**. Sohbet açılışında `GET /chats/{id}/messages` gömülü anketleri getirir. Uçuşta olup gitmemiş oy **kaybolur** (kuyruk diske yazılmaz — V1 kararı, dürüst sınır). |
| **İzin reddedildi** | **Uygulanmaz.** Anket hiçbir izin istemez (kamera/mikrofon/galeri/konum/rehber yok). Ataç panelindeki **anket satırı izin kapısı taşımaz**. |
| **Dosya çok büyük** | **Uygulanmaz** (dosya yok). Karşılığı: soru >300 rune / seçenek >100 rune / >12 seçenek → **istemcide `maxLength` ile önlenir**, sunucuda ayrıca reddedilir (fail-closed, istemci kurcalanabilir). |
| **Aynı dosya iki kez** karşılığı: **aynı oy iki kez** | `poll_votes` PK `(poll_id, option_id, user_id)` + `ON CONFLICT DO NOTHING` → idempotent. Çift dokunuş, ağ tekrarı, iki cihazdan aynı anda oy — hepsi tek satır. |
| **Aynı seçenek metni iki kez girildi** | Oluşturmada 400 `Seçenekler birbirinden farklı olmalı` (trim sonrası birebir karşılaştırma). |
| **Gönderim sırasında sohbetten çıkıldı** | `messagesProvider` `autoDispose` → notifier dispose olur, `_sub?.cancel()` (satır 116). Uçan POST **iptal edilmez**, anket **sunucuda oluşur** ve doğrudur; yalnız yerel yanıt işlenmez. Yeniden girişte görünür. ⚠️ `_debounce` timer'ları `dispose()` içinde **iptal edilmeli** (yoksa dispose sonrası `state=` yazımı → `Bad state` — turu 67'nin `ref after dispose` sınıfı). |
| **Alıcı engelledi** | Oluşturmada 403 `bu kullanıcıyla anket paylaşılamıyor`. **Bugün no-op** (blocks tablosuna yazan uç yok — doğruladım). Oy vermede engel kontrolü **yok** (aşırı olurdu). |
| **Anket kapalıyken oy** | 409 `Bu anket kapatıldı`. İstemci ayrıca kapalı ankette dokunuşu `IgnorePointer` ile engeller (iki katman). |
| **Anketi olmayan `poll` mesajı** (veri tutarsızlığı / eski önbellek) | `msg.anket == null` → `_Bubble`'a düşer, `content`=soru görünür. **Ham teknik işaretçi asla basılmaz.** |
| **İki kişi aynı anda oy verdi** | `SELECT ... FOR UPDATE` işlemleri sıraya dizer; `vote_seq` monoton artar; her iki istemci de doğru son sayımı görür. |
| **Sıra dışı WS teslimi** | seq kapısı (`yeniSeq <= mevcutSeq` → yok say). Tam anlık görüntü olduğu için tek bir geç olay bile eksik bilgi bırakmaz. |
| **Eski sürüm istemci** | `type='poll'` tanımaz → `_Bubble` → soru metni. Oy veremez. Bozulma yok. |
| **Eski binary'ye rollback** | Şemadaki 'poll' değeri üstküme olduğu için sorun çıkarmaz; `GetMessages` `poll` alanını döndürmez, istemci `anket==null` → metin balonu. |

---

## 7. ⚠️⚠️ BU PROJEYE ÖZEL ÇAKIŞMA RİSKLERİ (arama / sesli oda / canlı yayın)

### 7.1 Kamera ve mikrofon: **kullanılmıyor — kanıtla**
Anket akışının tamamı metin girişi + REST + WS'tir. Eklenen paket yok (`pubspec.yaml` değişmiyor), `AVAudioSession`/`RTCAudioSession`'a dokunan tek satır yok, `flutter_webrtc`'nin paylaşılan `videoCapturer`'ına (`AppDelegate.swift:668/737/905`) erişim yok. Dolayısıyla:
- iOS'ta proses genelinde tek olan ses birimiyle (`AppDelegate.swift:32-33 useManualAudio=true`) **çakışma yapısal olarak imkânsız**.
- Turu 64 (`!pri` / `InsufficientPriority`) ve turu 50/67 (iki capture oturumu birbirini çalıyor) hata sınıflarının hiçbiri bu tasarımda **üretilemez**.
- **Aktif arama/oda/yayın sırasında anket oluşturmak ve oy vermek SERBESTTİR** — engellemek gereksiz kısıtlama olurdu (kullanıcı aramadayken sohbete mesaj da yazabiliyor).

### 7.2 Ama ataç panelini **bugünden `mesgulMu()` kapısıyla** kur
Ataç paneli ileride **Kamera / Galeri / Sesli mesaj** satırlarını taşıyacak ve o satırlar iOS'ta `UIImagePickerController` / `AVAudioRecorder` açacak → **paylaşılan capture oturumunu ve ses birimini çalar**.
**Şimdi yapılacak somut şey:** panel öğesi modeli `bool mesgulKapisi` alanı taşır; anket öğesi `false`, ileride eklenecek medya öğeleri `true` olur ve `true` olan öğe tıklanınca:
```dart
if (ref.read(callServiceProvider.notifier)
        .mesgulMu(etiket: 'ek-medya')) {          // call_provider.dart:162 — TEK KAYNAK
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Görüşme sürerken bu işlem yapılamaz')));
  return;
}
```
⚠️ **YAPMA:** bu mantığı panele **kopyalama** — CLAUDE.md hükmü: "`mesgulMu`'yu çağıran yerlere kopyalama, drift eder" (turu 56'da `rooms_tab`/`live_tab` ham `aramadaMi`ye bakıp self-heal'den yararlanamamıştı).
⚠️ `odaYayinMuaf` **geçilmez** (varsayılan `false`, fail-closed): oda/yayın duraklatma yolu (turu 72/73) medya çekimi için yazılmadı.

### 7.3 WS gürültüsü — arama sürerken REST fırtınası riski (**gerçek risk**)
`chats_provider.dart:32`'deki `load()` tetiği anket olaylarına **bağlanmamalı** (§4.5). Aksi halde: kullanıcı aramadayken sohbet ekranı açık + karşı taraf 12 seçenekli ankette hızlı hızlı seçim değiştiriyor → saniyede birkaç `GET /chats` → hücresel bağlantıda medya paketleriyle yarış. Bu, LiveKit'in aynı hattı kullandığı bir üründe **ölçülebilir zarar**dır.
**Kural:** `poll.vote`/`poll.closed` **hiçbir liste tazelemesi tetiklemez**; yalnız açık sohbetteki tek balonu günceller. Sohbet ekranı kapalıysa `messagesProvider` `autoDispose` olduğu için **dinleyici bile yoktur** → sıfır iş.

### 7.4 Push kanalına dokunma
Oy için **hiçbir push yolu** (`NotifyUsers`, `DataNotify`, `CallInvite`, APNs VoIP) kullanılmaz. Gerekçe: (a) iOS'ta VoIP push = **hayalet gelen arama ekranı** (CLAUDE.md "reportNewIncomingCall KOŞULSUZ" kuralı), (b) Android data-push arka plandaki süreci uyandırır ve arama sırasında gereksiz iş yaratır, (c) turu 60'ta "hold için push yedeği" tam bu gerekçeyle **elenmişti** — aynı hatayı anket için yapmayalım.

### 7.5 Navigator / route çakışması
Anket sayfası açıkken arama gelirse: gelen arama katmanı `MaterialApp.builder` içinde çizilir (**Navigator'ın DIŞINDA**, CLAUDE.md hükmü) → sayfayı etkilemez. Kabul edilirse arama ekranı **üstüne** push edilir; arama bitince turu 59b fix'i kendi route'unu `ModalRoute.of(context)` + `removeRoute` ile kaldırır → **anket sayfası hayatta kalır**.
⚠️ **YAPMA:** anket sayfasını `rootNavigatorKey` ile kapatma; `useRootNavigator: true` verme; `whenComplete` içinde koşulsuz `pop()` çağırma.

### 7.6 Ses/titreşim
Anket olayları **hiçbir ses veya titreşim üretmez** (`CallSounds`/`Vibration`'a dokunulmaz). Zil sesi mantığıyla çakışma yok.

### 7.7 Özet tablo

| Paylaşılan kaynak | Anketin kullanımı | Sonuç |
|---|---|---|
| iOS `RTCAudioSession` / ses birimi | Yok | Çakışma imkânsız |
| `flutter_webrtc` paylaşılan `videoCapturer` | Yok | Çakışma imkânsız |
| Android AudioFocus / `AudioSwitchManager` | Yok | Çakışma imkânsız |
| WS soketi | Paylaşılıyor (olay tüketicisi) | Yeni olay adları; mevcut `case`'lere dokunulmuyor |
| REST hattı | Küçük istekler (<1 KB) | 1 sn/anket throttle + 350 ms debounce + tek-uçuş |
| Push kanalı | Yalnız oluşturmada, mevcut mesaj yolu | Oy için sıfır push |
| Navigator yığını | Bottom sheet | Kendi context'iyle pop; root pop yasak |
| `mesgulMu` muhafızı | Kullanmıyor (ama panel altyapısı taşıyor) | Medya geldiğinde kapı hazır |

---

## 8. TEST SENARYOLARI (iki telefonla elle)

**Temel akış**
1. A, sohbette ataç → **Anket** → soru + 3 seçenek + çoklu KAPALI → Gönder. **Beklenen:** A'da balon anında; B'de **1 saniyeden kısa** sürede balon; B'nin sohbet listesinde `Anket · <soru>` + 2B grafik ikonu + okunmamış rozeti.
2. B uygulamayı kapalı tutarken A anket gönderir. **Beklenen:** B'ye push `A: Anket · <soru>`. Push'ta emoji/teknik metin **YOK**.
3. B oy verir. **Beklenen:** B'de anında dolgu; A'da ~1 sn içinde sayı ve çubuk güncellenir; **A'nın sohbet listesi TAZELENMEZ** (sıralama zıplamaz).
4. B başka bir seçeneğe basar (tekli anket). **Beklenen:** eski işaret kalkar, yeni işaret gelir; toplam "1 kişi oy verdi" kalır (2 olmaz).
5. B kendi işaretli seçeneğine tekrar basar. **Beklenen:** oy geri çekilir, "0 kişi oy verdi".

**Çoklu seçim**
6. Çoklu AÇIK anket; B üç seçeneği **hızlıca** işaretler. **Beklenen:** üçü de işaretli, tek istek gitmiş gibi tek seferde güncellenir, sayaç yanıp sönmez, hiçbir işaret geri sekmez.
7. A ve B **aynı anda** aynı seçeneğe basar. **Beklenen:** iki cihazda da "2 kişi oy verdi" ve o seçenekte 2 — hiçbirinde 1'de takılı kalmaz.

**Kapatma / yetki**
8. A "Anketi bitir" → onay. **Beklenen:** iki cihazda da kilit ikonu + "Anket sona erdi"; seçenekler tıklanmaz.
9. B'de "Anketi bitir" düğmesi **görünmez**.
10. Kapatıldıktan sonra B eski ekranda seçeneğe basmayı denerse (yarış): SnackBar **"Bu anket kapatıldı"** + balon kapalıya döner.

**Ağ / yaşam döngüsü — en kritik grup**
11. B uçak modunu açar, oy verir. **Beklenen:** işaret bir an dolar, sonra geri sarar + `Sunucuya ulaşılamıyor...`. Uçak modu kapanınca tekrar basınca çalışır.
12. **B uygulamayı arka plana alır** (WS kapanır), o sırada A birkaç kez oy değiştirir, B geri döner. **Beklenen:** B'nin balonu **A'nın son durumuyla birebir** (kendini onarma çalıştı). Bu madde `ws.acildi` yolunu test eder — **atlanmasın**.
13. B uygulamayı app switcher'dan **öldürür**, tekrar açar, sohbete girer. **Beklenen:** anket ve kendi oyu **aynen** yerinde.
14. B telefonu kilitler, A oy verir, B kilidi açar. **Beklenen:** güncel durum (12 ile aynı yol).

**Arama ile birlikte (§7)**
15. A ile B **sesli aramadayken**, arama küçültülüp sohbete girilir; B oy verir. **Beklenen:** ses **kesilmez**, ne cızırtı ne kopma; balon güncellenir; arama süresi sayacı bozulmaz.
16. **Görüntülü aramada** aynısı. **Beklenen:** video donmaz, kamera kapanmaz.
17. Anket oluşturma sayfası **açıkken** A'dan arama gelir; B kabul eder, konuşur, kapatır. **Beklenen:** arama ekranı kapanınca **anket sayfası hâlâ açık ve yazılan metin duruyor** (turu 59b `removeRoute` kuralı).
18. B **sesli odadayken** (veya canlı yayındayken) sohbetten oy verir. **Beklenen:** oda/yayın sesi etkilenmez.

**Doğrulama / sınırlar**
19. Soru boş + Gönder → düğme zaten pasif. Tek seçenek → `En az 2 seçenek gerekli`. 13. seçenek eklenemez.
20. İki seçeneğe aynı metin → `Seçenekler birbirinden farklı olmalı`.
21. 10 saniye içinde iki anket → `Çok hızlı anket oluşturuyorsunuz`.
22. Türkçe karakterli uzun soru ("Şşğüöçİ..." 300 karakter) → kesilmiyor, push bildiriminde **bozuk karakter yok** (rune kesme fix'i).

**Oyları gör**
23. "Oyları gör" → seçenek başına gerçek isimler; oy vermemiş seçenek "Henüz oy yok".

**Geriye uyumluluk**
24. (Varsa) eski sürüm kurulu bir cihaza anket gönder. **Beklenen:** düz metin balonunda **soru** görünür; `call:` benzeri hiçbir teknik işaretçi ekranda yok.

---

### Bilmediklerim / dürüst sınırlar
- **Grup sohbeti UI'si YOK.** Doğruladım: `INSERT INTO chats` üç yerde de `'direct'` (`chat/handler.go:306`, `calls/handler.go:1635`, `calls/grup_sohbet.go:84`) ve `chat_members.role` hiçbir yerde yazılmıyor. Yani anket bugün **yalnız 1:1'de** yaşar (2 oy verenli anket). Tasarım N-üyeli çalışacak şekilde yazıldı (üye listesi `chat_members`'tan, oy veren listesi kapaklı, kapatma yetkisinde rol dalı hazır) ama **anketin asıl değeri grup sohbeti gelince ortaya çıkar** — bu, özelliğin bugünkü faydasını sınırlayan gerçek bir kısıttır.
- **Anket düzenleme yok** (WhatsApp'ta da yok). Seçenek ekleme/çıkarma/sıralama yok.
- **Oy kuyruğu diske yazılmıyor**: uygulama tam POST anında öldürülürse o oy kaybolur.
- `messages` tablosunda CHECK yeniden kurulumu **ACCESS EXCLUSIVE kilit + tam tarama** yapar. Bu projede DB her sürümde `TRUNCATE users CASCADE` ile boşaltıldığı için pratikte milisaniyeler sürer; **büyük bir üretim tablosunda** `NOT VALID` + ayrı `VALIDATE CONSTRAINT` yolu tercih edilmelidir.
- Anket sayısı/oy hacmi için **ölçüm yok**; `poll_votes` üzerindeki iki indeksin yeterliliği 50K ölçekte **varsayımdır (TAHMİN)**, sayım sorgusu ölçülmeden "yeterli" denemez.