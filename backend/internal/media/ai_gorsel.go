package media

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"time"
)

// ⚠️⚠️⚠️ TURU 79 — YAPAY ZEKANIN URETTIGI GORSELI KAYDEDER.
//
// Kullanici emri: "hepsi olsun" (AI ile gorsel uretme dahil).
//
// ═════════════ NEDEN BU FONKSIYON `media` PAKETINDE ═════════════
//
// AI paketi R2'ye ya da `media_assets`e DOGRUDAN DOKUNMAZ. Sebep, `Handler`
// serhinde zaten yazili olan kural: ikinci bir R2 istemcisi = ikinci bir
// imzalama yapilandirmasi = DRIFT (turu 77 denetim bulgusu C12). Nesne anahtari
// uretimi, depolama kotasi ve satir semasi ZATEN burada yasiyor; AI tarafi
// yalnizca bir geri cagirim tutar.
//
// ═════════════ NORMAL YUKLEME AKISINDAN FARKI ═════════════
//
// Normal akis: presign -> istemci PUT -> commit (HeadObject + boyut/MD5/sihirli
// bayt dogrulamasi) -> 'aktif'. Buradaki govde **SUNUCUNUN KENDISININ** OpenAI'dan
// aldigi bayttir; istemci ONA HIC DOKUNMAZ. Dolayisiyla:
//   - presign/commit adimlari YOKTUR (dogrulanacak bir "istemci beyani" yok),
//   - satir DOGRUDAN 'aktif' dogar,
//   - butunlugu `Yukle` icindeki `Content-MD5` kanitlar.
//
// ⚠️ `kind='image'` KULLANILIR, YENI BIR TUR ACILMAZ. Yeni bir `kind` degeri
//
//	(a) `media_assets.kind` CHECK'ini genisletmeyi gerektirirdi — turu 78'de
//	bu tuzaga IKI KEZ dusuldu, (b) `erisebilir()` icine YENI BIR DAL yazmayi
//	gerektirirdi ve o dal unutuldugunda **yukleyenden baska HERKESE 403**
//	donerdi (ayni sinif dort kez sahaya cikti). AI gorseli urun/ilan medyasi
//	olarak baglanacagi icin mevcut (c)/(f)/(g)/(h) dallari onu ZATEN kapsar.
//
// ⚠️ DEPOLAMA KOTASI NORMAL YOLLA ISLENIR: uretilen gorsel de kullanicinin
//
//	aylik bayt kotasindan duser. Bedava saymak, kotayi delmenin bedava yolu olurdu.
//
// ⚠️ KOTA DOLUYSA URETIM YAPILMAZ — bu kontrol CAGIRAN tarafta, OpenAI'ya
//
//	GITMEDEN ONCE yapilmali (yoksa para harcanir ve sonuc atilir).
func (h *Handler) AIGorseliKaydet(ctx context.Context,
	sahipID, mime string, govde []byte) (string, error) {
	if h.r2 == nil {
		return "", fmt.Errorf("medya kapali")
	}
	if len(govde) == 0 {
		return "", fmt.Errorf("bos govde")
	}

	// Nesne anahtari presign yolundaki desenle BIREBIR AYNI.
	// ⚠️ Anahtarda kullanici id / dosya adi YOKTUR (015 serhi).
	rastgele := make([]byte, 16)
	if _, err := rand.Read(rastgele); err != nil {
		return "", err
	}
	anahtar := fmt.Sprintf("m/%s/%s",
		time.Now().UTC().Format("2006/01"), hex.EncodeToString(rastgele))

	if err := h.r2.Yukle(ctx, anahtar, mime, govde); err != nil {
		return "", err
	}

	var id string
	err := h.db.QueryRow(ctx, `
		INSERT INTO media_assets
		  (owner_id, kind, object_key, mime, bytes, expected_bytes,
		   status, committed_at)
		VALUES ($1,'image',$2,$3,$4,$4,'aktif',now())
		RETURNING id`, sahipID, anahtar, mime, int64(len(govde))).Scan(&id)
	if err != nil {
		// ⚠️ SATIR ACILAMADIYSA NESNE R2'DE YETIM KALMASIN.
		if serr := h.r2.Sil(ctx, anahtar); serr != nil {
			h.db.Exec(ctx, `INSERT INTO media_delete_queue (object_key) VALUES ($1)`,
				anahtar)
		}
		return "", err
	}

	if _, kerr := h.kota.Ekle(ctx, sahipID, int64(len(govde))); kerr != nil {
		log.Printf("ai gorsel kota: %v", kerr)
	}
	return id, nil
}

// AIGorselIzni — uretimden ONCE depolama kotasi yeterli mi?
//
// ⚠️ ONCE sorulur: OpenAI cagrisi PARA HARCAR; kota dolu bir kullanici icin
//
//	once uretip sonra "yer yok" demek hem parayi hem kotayi bosa yakar.
func (h *Handler) AIGorselIzni(ctx context.Context, sahipID string, tahminiBayt int64) bool {
	if h.r2 == nil {
		return false
	}
	return h.kota.Kalan(ctx, sahipID) >= tahminiBayt
}
