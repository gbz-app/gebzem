package media

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ⚠️⚠️⚠️ TURU 181 — MEDYA REFERANS SAYIMI **TEK KAYNAK**.
//
// ═══════════ NEDEN YAZILDI: UC KOPYA VARDI VE UCU DE BOZUKTU ═══════════
//
// `medyayiKopar` UC ayri pakette (chat · kanal · social) ayri ayri
// yazilmisti ve zaman icinde AYRISMISTI. Sayilan tablolar:
//
//	tablo                        chat  kanal  social
//	messages.media_id             ✓     ✓      ✓
//	users.avatar_media_id         ✓     ✓      ✓
//	users.kapak_media_id          ✓     ✗      ✗
//	chats.avatar_media_id         ✓     ✗      ✗
//	channels.avatar_media_id      ✗     ✓      ✓
//	posts.media_ids               ✗     ✓      ✓
//	channel_posts.media_ids       ✗     ✓      ✓
//	isletmeler.kapak_medyalari    ✓     ✓      ✓
//	stories.media_id              ✗     ✗      ✗
//	isletme_urunleri.media_ids    ✗     ✗      ✗
//	ilanlar.media_ids             ✗     ✗      ✗
//	etkinlikler.media_ids         ✗     ✗      ✗
//
// Yani bir URUN fotografi ayni zamanda bir mesajda paylasilmissa, mesaj
// "herkesten silindiginde" urun fotografi da koparilacakti — GERCEK VERI
// KAYBI.
//
// ═══════════ AMA ONCE: UCU DE **HIC CALISMIYORDU** ═══════════
//
// ⚠️⚠️⚠️ CANLI POSTGRES'TE OLCULDU (turu 181):
//
//	ERROR: operator does not exist: uuid = text
//	LINE: + (SELECT count(*) FROM isletmeler WHERE $1 = ANY(kapak_medyalari))
//
//	`isletmeler.kapak_medyalari` **TEXT[]** (051), diger TUM medya sutunlari
//	**UUID**. Ayni sorguda `$1` once `messages.media_id` (uuid) ile
//	karsilastirildigi icin Postgres parametreyi UUID cikarsiyor; sonraki
//	`$1 = ANY(text[])` karsilastirmasi OPERATOR BULAMIYOR ve **TUM SORGU**
//	hata donuyor. Hata da `if err != nil { return }` ile YUTULUYORDU.
//
//	SONUC: turu 180k'da `isletmeler` satiri eklendiginden beri HICBIR
//	medya koparilmadi — `media_assets` satirlari sonsuza kadar
//	'aktif'/'bagli' kaldi, `media_delete_queue` HIC dolmadi, R2'de KALICI
//	SIZINTI olustu. Ozellik derleme temiz gecerek, log dusurmeden,
//	tamamen OLU kaldi.
//
//	⚠️ Bu, turu 113'un `favorim` hatasinin BIREBIR tekrari (ayni
//	   `uuid = text`). **DERS: ayni parametreyi FARKLI TIPTEKI sutunlarla
//	   karsilastiran her sorguda cast'i ACIKCA yaz.**
//
// ═══════════ TIP COZUMU ═══════════
//
// `$1` HER kullanimda ACIKCA cast edilir (`$1::uuid` / `$1::text`), yani
// parametrenin kendisi `unknown` kalir ve Postgres tip cikarsamasi bir
// sutundan digerine SIZMAZ.
//
// ⚠️ Dizi sorgularinda `= ANY(...)` DEGIL **`@> ARRAY[$1::uuid]`**:
//
//	`023_sosyal_index.sql:30-33` serhi bunu ACIKCA soyluyor — `= ANY()`
//	dizi TARAMASI yapar ve GIN index'i KULLANMAZ; `@>` kullanir.
//	`isletmeler.kapak_medyalari` TEXT[] ve GIN index'i YOK, orada
//	`= ANY()` kalir (dizi en fazla birkac eleman).
//
// ═══════════ DURUM SUZGECI **BILEREK YOK** ═══════════
//
// Eski kopyalar `posts`/`channel_posts` icin `AND durum='yayinda'`
// kullaniyordu. Kaldirildi:
//   - KARANTINAYA alinmis bir gonderi geri alinabilir; medyasi koparilirsa
//     geri gelen gonderi KIRIK GORSEL cizer.
//   - Yanlis tarafa dusmenin bedeli ASIMETRIK: fazladan saymak DEPOLAMA
//     maliyeti, eksik saymak VERI KAYBI. Veri kaybi her zaman daha pahali.
//
// ⚠️ YAPMA: buraya `durum='yayinda'` suzgeci geri koyma.
//
// ═══════════ KARDESI: `erisebilir()` ═══════════
//
// Bu fonksiyonun tablo kumesi `erisebilir()` (handler.go) ile AYNI olmak
// ZORUNDA: biri "kim gorebilir", oteki "hala kullaniliyor mu" sorar ama
// ikisi de AYNI medya baglantilarini tarar. `medya_kume_test.go` muhafizi
// iki listeyi KAYNAKTAN okuyup karsilastirir ve ayrisirsa KIRMIZI duser.
//
// ⚠️⚠️ YENI BIR MEDYA SUTUNU EKLERKEN UCU BIRLIKTE GUNCELLE:
//
//	`erisebilir()` dali · BU sayim · uctan uca kontrolu.
const kullanimSayimi = `
	SELECT (SELECT count(*) FROM messages          WHERE media_id = $1::uuid)
	     + (SELECT count(*) FROM users             WHERE avatar_media_id = $1::uuid
	                                                  OR kapak_media_id  = $1::uuid)
	     + (SELECT count(*) FROM chats             WHERE avatar_media_id = $1::uuid)
	     + (SELECT count(*) FROM channels          WHERE avatar_media_id = $1::uuid)
	     + (SELECT count(*) FROM stories           WHERE media_id = $1::uuid)
	     + (SELECT count(*) FROM posts             WHERE media_ids @> ARRAY[$1::uuid])
	     + (SELECT count(*) FROM channel_posts     WHERE media_ids @> ARRAY[$1::uuid])
	     + (SELECT count(*) FROM isletme_urunleri  WHERE media_ids @> ARRAY[$1::uuid])
	     + (SELECT count(*) FROM ilanlar           WHERE media_ids @> ARRAY[$1::uuid])
	     + (SELECT count(*) FROM etkinlikler       WHERE media_ids @> ARRAY[$1::uuid])
	     + (SELECT count(*) FROM isletmeler        WHERE $1::text = ANY(kapak_medyalari))`

// KullanimVar — medya HERHANGI bir yerde hala kullaniliyor mu?
//
// ⚠️⚠️ HATA **FAIL-CLOSED**: sorgu patlarsa `true` doner, yani medya
//
//	KOPARILMAZ. Eski kopyalar da hatada donuyor ama SESSIZCE — bu
//	fonksiyon hatayi DA dondurur ki cagiran loglayabilsin.
//	Yanlis tarafa dusmenin bedeli asimetrik: fazla koruma depolama,
//	eksik koruma VERI KAYBI.
func KullanimVar(ctx context.Context, db *pgxpool.Pool, mediaID string) (bool, error) {
	if mediaID == "" {
		return true, nil // bos kimlik: DOKUNMA
	}
	var kalan int
	if err := db.QueryRow(ctx, kullanimSayimi, mediaID).Scan(&kalan); err != nil {
		return true, err // FAIL-CLOSED
	}
	return kalan > 0, nil
}

// Kopar — medya artik HICBIR yerde kullanilmiyorsa 'silindi' isaretler ve
// R2 nesnelerini silme kuyruguna yazar.
//
// ⚠️ R2 silme KUYRUGA yazilir (`media_delete_queue`, 015): istek yolunda
//
//	ag cagrisi yapilmaz.
//
// ⚠️ Donen hata YALNIZ TESHIS ICINDIR; cagiran onu loglayip devam eder.
//
//	Medya koparilamamasi kullanicinin islemini (mesaj silme, gonderi
//	silme) BASARISIZ YAPMAMALI.
func Kopar(ctx context.Context, db *pgxpool.Pool, mediaID string) error {
	varMi, err := KullanimVar(ctx, db, mediaID)
	if err != nil {
		return err
	}
	if varMi {
		return nil // baska bir yerde hala kullaniliyor
	}
	var anahtar, thumb string
	if err := db.QueryRow(ctx, `
		UPDATE media_assets SET status='silindi', deleted_at=now()
		 WHERE id=$1::uuid AND status IN ('aktif','bagli')
		 RETURNING object_key, thumb_key`, mediaID).Scan(&anahtar, &thumb); err != nil {
		// Satir yoksa ya da zaten silinmisse buraya duser — hata DEGIL.
		return nil
	}
	for _, a := range []string{anahtar, thumb} {
		if a != "" {
			db.Exec(ctx,
				`INSERT INTO media_delete_queue (object_key) VALUES ($1)`, a)
		}
	}
	return nil
}
