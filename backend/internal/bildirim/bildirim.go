// Package bildirim — SOSYAL BILDIRIMLERIN TEK KAYNAGI (begeni, yorum, takip,
// takip istegi, takip onayi, bahsetme).
//
// ⚠️⚠️⚠️ TURU 76 — NEDEN VAR: bu paket gelmeden once `social`, `users` ve `kanal`
// paketleri `chat.Hub`i ve `push.Sender`i **IMPORT BILE ETMIYORDU** (main.go'da
// yalniz `chat.NewHandler` hub+push aliyordu). Bes ayri yerde `INSERT INTO
// bildirimler` yapiliyor, yaninda TEK BIR `Publish`/`NotifyUsers` cagrisi
// bulunmuyordu. Sonuc: biri gonderiyi begendiginde/yorum yaptiginda/takip
// ettiginde kullaniciya NE anlik WS olayi NE telefon bildirimi gidiyordu;
// bildirim yalnizca Bildirimler sayfasi ELLE acilinca goruluyordu.
// Kullanicinin "bildirimler anlik gelmiyor" sikayetinin dogrudan karsiligi.
//
// ⚠️ TEK KAYNAK OLMASI SART: yazma (DB) + duyurma (WS+push) AYNI fonksiyonda.
// Bes cagri yerine dagitilsaydi zamanla ayrisirdi — bu projede ayni sinif
// (turu 72b/H, turu 75b engel yuklemi) iki kez yasandi.
// ⚠️ YAPMA: cagri yerlerine duz `INSERT INTO bildirimler` yazma; buradan gec.
package bildirim

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/push"
)

// Sorgulayici — hem `*pgxpool.Pool` hem `pgx.Tx` bu arayuze uyar.
// ⚠️ Bildirim satiri, tetikleyen islemle AYNI TRANSACTION'da yazilabilsin diye
//
//	arayuz kullaniliyor (or. takip + sayac + bildirim tek transaction).
type Sorgulayici interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Servis — main.go'da BIR KEZ kurulur, paketlere gecirilir.
type Servis struct {
	db   *pgxpool.Pool
	hub  *chat.Hub
	push *push.Sender
}

func Yeni(db *pgxpool.Pool, hub *chat.Hub, p *push.Sender) *Servis {
	return &Servis{db: db, hub: hub, push: p}
}

// Bildir — bildirimi YAZAR ve DUYURUR.
//
// [q] transaction icinde cagriliyorsa tx, degilse nil (havuz kullanilir).
// ⚠️ tx verilirse WS/push COMMIT'TEN SONRA gonderilmelidir; bu yuzden tx'li
//
//	cagrilarda once `Yaz`, commit sonrasi `Duyur` kullan (asagidaki ikili).
//	`Bildir` yalnizca transaction DISINDA kullanilmalidir.
func (s *Servis) Bildir(ctx context.Context, alici, aktor, tur, hedefTur, hedefID string) {
	if !s.Yaz(ctx, s.db, alici, aktor, tur, hedefTur, hedefID) {
		return // yeni satir acilmadi (kendi kendine ya da tekrar) -> duyurma
	}
	s.Duyur(ctx, alici, aktor, tur, hedefTur, hedefID)
}

// Yaz — bildirim satirini yazar. Doner: YENI satir acildi mi.
//
// ⚠️⚠️ TEKRAR BASTIRMA (1 saat): begeni/geri-al dongusu sinirsiz bildirim satiri
//
//	uretebiliyordu. WS + push eklendigi AN bu, kullanicinin telefonunu titreten
//	GERCEK BIR TACIZ ARACINA donusurdu (birinin gonderisini 50 kez begenip geri
//	almak = 50 bildirim). Ayni (alici,aktor,tur,hedef) dortlusu icin son 1 saatte
//	kayit varsa YENI SATIR ACILMAZ.
//
// ⚠️ YAPMA: bu pencereyi kaldirma.
// ⚠️ KENDINE BILDIRIM YOK: kendi gonderini begenmek/yorumlamak bildirim uretmez.
func (s *Servis) Yaz(ctx context.Context, q Sorgulayici,
	alici, aktor, tur, hedefTur, hedefID string) bool {
	if alici == "" || alici == aktor {
		return false
	}
	tag, err := q.Exec(ctx, `
		INSERT INTO bildirimler (user_id, aktor_id, tur, hedef_tur, hedef_id)
		SELECT $1,$2,$3,$4,$5
		 WHERE NOT EXISTS (
		   SELECT 1 FROM bildirimler
		    WHERE user_id=$1 AND aktor_id=$2 AND tur=$3 AND hedef_id=$5
		      AND created_at > now() - interval '1 hour')`,
		alici, aktor, tur, hedefTur, hedefID)
	if err != nil {
		log.Printf("bildirim yaz: %v", err)
		return false
	}
	return tag.RowsAffected() == 1
}

// Duyur — WS olayi + telefon bildirimi. DB'ye YAZMAZ.
// ⚠️ Transaction icinde CAGIRMA: geri alinan bir islem icin bildirim gonderilir.
func (s *Servis) Duyur(ctx context.Context, alici, aktor, tur, hedefTur, hedefID string) {
	// Aktorun adi — bildirim metni icin. Tek sorgu; bildirimler yuksek frekansli
	// degil (mesaj degil), bu maliyet kabul edilebilir.
	var ad string
	s.db.QueryRow(ctx, `SELECT name FROM users WHERE id=$1`, aktor).Scan(&ad)
	if ad == "" {
		ad = "Birisi"
	}
	metin := Metin(tur, ad)

	// ---- (1) ANLIK: WS. Uygulama ACIKSA rozet aninda artar.
	if s.hub != nil {
		yuk := []byte(`{"tur":"` + kacir(tur) + `","aktor_id":"` + kacir(aktor) +
			`","aktor_ad":"` + kacir(ad) + `","hedef_tur":"` + kacir(hedefTur) +
			`","hedef_id":"` + kacir(hedefID) + `","metin":"` + kacir(metin) + `"}`)
		s.hub.Publish(ctx, &chat.Event{
			Type:    "bildirim.yeni",
			Payload: yuk,
			To:      []string{alici},
		})
	}

	// ---- (2) UYGULAMA KAPALIYSA: telefon bildirimi.
	// ⚠️ `DataNotify` kullaniliyor (`NotifyUsers` DEGIL): `NotifyUsers` yuke
	//    `chat_id` koyar ve istemci ona dokununca SOHBET acar — sosyal bildirimde
	//    yanlis ekran acilirdi.
	if s.push != nil {
		s.push.DataNotify([]string{alici}, "Gebzem", metin, map[string]string{
			"tur":       "bildirim",
			"bildirim":  tur,
			"hedef_tur": hedefTur,
			"hedef_id":  hedefID,
			"aktor_id":  aktor,
		})
	}
}

// Metin — bildirim turunun Turkce karsiligi.
// ⚠️ ISTEMCIDEKI `bildirimler_sayfasi.dart` `_tur()` switch'i ile AYNI turleri
//
//	taniyor olmali; yeni tur eklenirse IKISI de guncellenir.
func Metin(tur, ad string) string {
	switch tur {
	case "begeni":
		return ad + " gönderini beğendi"
	case "yorum":
		return ad + " gönderine yorum yaptı"
	case "takip":
		return ad + " seni takip etmeye başladı"
	case "takip_istegi":
		return ad + " takip isteği gönderdi"
	case "takip_onaylandi":
		return ad + " takip isteğini onayladı"
	case "bahsetme":
		return ad + " senden bahsetti"
	// ⚠️ TURU 80 — REZERVASYON/RANDEVU. Metinler SAAT/KISI ICERMEZ: `Metin`
	//    imzasi YALNIZCA aktor adini aliyor ve bu imza bes cagri yerinde
	//    kullaniliyor; saat basmak icin imzayi genisletmek kozmetik kazanc
	//    karsiliginda DRIFT davet eden bir refactor olurdu. Dokunus randevu
	//    detayina gidiyor, ayrinti orada yaziyor.
	// ⚠️ 'geldi'/'gelmedi' icin bildirim YOK (bkz. `randevu.Gecisler`).
	case "randevu_yeni":
		return ad + " randevu talebi gönderdi"
	case "randevu_onaylandi":
		return ad + " randevunu onayladı"
	case "randevu_reddedildi":
		return ad + " randevunu reddetti"
	case "randevu_iptal":
		return ad + " randevuyu iptal etti"
	default:
		return ad + " bir işlem yaptı"
	}
}

// kacir — JSON dize kacisi (elle yuk kuruyoruz; ad kullanici girdisi).
// ⚠️ ZORUNLU: kullanici adinda cift tirnak ya da ters bolu varsa yuk BOZULUR ve
//
//	istemcide `jsonDecode` patlar (olay SESSIZCE kaybolur).
func kacir(s string) string {
	out := make([]rune, 0, len(s)+8)
	for _, r := range s {
		switch r {
		case '"':
			out = append(out, '\\', '"')
		case '\\':
			out = append(out, '\\', '\\')
		case '\n', '\r', '\t':
			out = append(out, ' ')
		default:
			if r < 0x20 {
				continue
			}
			out = append(out, r)
		}
	}
	return string(out)
}
