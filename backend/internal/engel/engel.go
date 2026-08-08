// Package engel — ENGELLEME KONTROLUNUN TEK KAYNAGI.
//
// ⚠️⚠️⚠️ TURU 76 — NEDEN VAR: engelleme turu 74'te eklendi ama kapi YALNIZ
// "aksiyon" uclarina konuldu (mesaj gonderme, arama baslatma, sohbet acma,
// gonderi begenme). "GORME" uclarinin cogu KAPISIZ kaldi ve kullanici sikayeti
// tam olarak buydu: *"engellediğimde karşı taraf beni HİÇ görememeli"*.
//
// Kapisiz kalan yuzeyler (denetimle bulundu, hepsi bu turda kapatildi):
//   - sesli ODAYA katilim  -> engellenen kisi engelleyenin ODASINA GIRIP SESINI
//     CANLI DINLIYORDU. Canli yayinda ayni kapi VARDI, odada YOKTU: "ayni kuralin
//     iki kopyasi drift eder" sinifinin (turu 72b/H) birebir tekrari.
//   - profil, presence (15 sn'de bir aktivite izleme), takipci/takip listeleri,
//     WS "yaziyor...", kanal katmaninin TAMAMI, yorum ve begenenler listeleri,
//     kesfet listeleri (oda/yayin), /users/by-phone, bildirim listesi.
//
// ⚠️ TASARIM: iki kullanim bicimi var ve IKISI DE buradan gelir —
//  1. `Var(...)` : Go tarafinda tek kontrol (uc girisinde 404 dondurmek icin).
//  2. SQL yuklemi sabitleri: listeleri SUZMEK icin (satirin icinden elemek).
//
// ⚠️ KURAL CIFT YONLU: hangi taraf digerini engellediyse iki yon de kapanir.
// ⚠️ KURAL FAIL-CLOSED: sorgu patlarsa ENGELLI kabul edilir (icerik sizmasin).
// ⚠️ KURAL IFSA ETME: engel yuzunden reddedilen istekte 403 + "seni engelledi"
//
//	DEMEZ; 404 "bulunamadi" ya da NOTR bos veri doner. WhatsApp/Instagram da
//	engellemeyi gizler; 403 baslibasina bir SINYALDIR.
package engel

import (
	"context"

	"github.com/jackc/pgx/v5"
)

// Sorgulayici — `*pgxpool.Pool` ve `pgx.Tx` bu arayuze uyar.
type Sorgulayici interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Var — a ile b arasinda (HER IKI YONDE) engel var mi.
//
// ⚠️ FAIL-CLOSED: hata durumunda `true` doner. Engelleme bir GIZLILIK kontrolu;
//
//	suphede kalinca ICERIK GOSTERILMEZ.
func Var(ctx context.Context, q Sorgulayici, a, b string) bool {
	if a == "" || b == "" || a == b {
		return false
	}
	var v bool
	if err := q.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM blocks
		 WHERE (blocker_id=$1 AND blocked_id=$2)
		    OR (blocker_id=$2 AND blocked_id=$1))`, a, b).Scan(&v); err != nil {
		return true
	}
	return v
}

// Yuklem — bir SORGU ICINDE kullanilacak SQL parcasi.
//
// [okuyan] okuyan kullanicinin parametre yer tutucusu (or. "$1"),
// [hedef]  karsi tarafin SUTUNU (or. "p.author_id", "c.owner_id", "u.id").
//
// ⚠️ Uretilen metin bir SQL PARCASIDIR ama iki argumani da KOD SABITIDIR
//
//	(kullanici girdisi DEGIL) — enjeksiyon yolu yoktur. Cagiranlar bu iki degeri
//	ASLA istekten almamalidir.
//
// ⚠️ YAPMA: bu yuklemi sorgulara elle kopyalama; drift eder.
func Yuklem(okuyan, hedef string) string {
	return ` AND NOT EXISTS(SELECT 1 FROM blocks b
	         WHERE (b.blocker_id=` + okuyan + ` AND b.blocked_id=` + hedef + `)
	            OR (b.blocker_id=` + hedef + ` AND b.blocked_id=` + okuyan + `))`
}
