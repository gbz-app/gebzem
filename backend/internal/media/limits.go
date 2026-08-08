package media

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// ⚠️⚠️ TURU 74 — BOYUT TAVANLARI + KOTA + HIZ SINIRI.
//
// NEDEN: kayit UCRETSIZ. Kota olmadan bir kisi tek gecede terabaytlarca yukleyip
// faturayi patlatabilir. Kullanici karari geregi VERI SILINMIYOR, yani her yuklenen
// bayt KALICI maliyettir — sinirlar bu yuzden sadece kotuye kullanim degil, MALIYET
// kontrolu.

// Tip basina TAVAN (bayt). Istemci zaten sikistirir; bunlar SON savunma.
var Tavanlar = map[string]int64{
	"image":    8 << 20,  // 8 MB — sikistirilmis foto ~300 KB, tavan cok genis
	"avatar":   4 << 20,  // 4 MB
	"audio":    16 << 20, // 16 MB — ~10 dk ses notu
	"video":    16 << 20, // 16 MB / 60 sn (kullaniciya sorulan S4; oneri 16 MB)
	"document": 32 << 20, // 32 MB
}

// ⚠️ TURU 74b: kucuk resim TAVANI. Eskiden hic yoktu ve thumb nesnesi hicbir
// dogrulamadan gecmiyordu -> tek hesapla sinirsiz R2 faturasi.
const ThumbTavan = 512 << 10 // 512 KB

const (
	// Kullanici basina AYLIK yukleme kotasi.
	// ⚠️ Veri SILINMEDIGI icin bu deger dogrudan aylik maliyet artisidir.
	AylikKota = 500 << 20 // 500 MB

	// Presign hiz siniri: dakikada kac yukleme baslatilabilir.
	// ⚠️ Kota TEK BASINA yetmez: saldirgan presign alip HIC yuklemeyebilir
	//     (kota commit'te dusulur) -> imza uretimi bedava DDoS olurdu.
	PresignDakikaLimit = 60
)

// KotaAsildi — kullanicinin bu ayki toplamini kontrol eder.
// ⚠️ REZERVASYON DEGIL: presign'da BEYAN EDILEN boyut "gecici" olarak eklenir,
//
//	commit'te GERCEK boyutla uzlastirilir. Boylece hem beyan sisirmesi hem
//	yuklenmeyen presign'lar kotayi kalici kilitlemez.
type Kota struct {
	rdb *redis.Client
	// TURU 74b: son Redis hatasi (fail-open GORUNUR olsun diye).
	Hata error
}

func YeniKota(rdb *redis.Client) *Kota { return &Kota{rdb: rdb} }

func (k *Kota) anahtar(userID string) string {
	// Aylik pencere. ⚠️ UTC kullaniliyor — sunucu saati degisse bile pencere kaymaz.
	return fmt.Sprintf("medya:kota:%s:%s", userID, time.Now().UTC().Format("2006-01"))
}

// Ekle — kotaya bayt ekler ve YENI TOPLAMI doner. Negatif deger duser (uzlastirma).
// ⚠️ TTL yalnizca ilk yazimda kurulur; her INCR'de yenilenirse pencere KAYAR.
func (k *Kota) Ekle(ctx context.Context, userID string, bytes int64) (int64, error) {
	if k.rdb == nil {
		return 0, nil // Redis yoksa kota UYGULANMAZ (fail-open — bilincli: mesajlasma calismali)
	}
	a := k.anahtar(userID)
	n, err := k.rdb.IncrBy(ctx, a, bytes).Result()
	if err != nil {
		return 0, err
	}
	if n == bytes { // ilk yazim
		k.rdb.Expire(ctx, a, 35*24*time.Hour)
	}
	return n, nil
}

// Kalan — bu ay kalan bayt.
// ⚠️⚠️ TURU 74b (DENETIM BULGUSU): Redis dusunce kota ve hiz siniri SESSIZCE
//
//	tamamen kalkiyordu. Redis ayni kutuda; bir OOM/restart penceresinde medya
//	katmani SINIRSIZ olur ve kimse fark etmez. Artik fail-open KALIR (mesajlasma
//	durmasin) ama GORUNUR: cagiran taraf Sentry gercek olayi yazar.
//
// ⚠️ YAPMA: hatayi tekrar sessizce yutma.
func (k *Kota) Kalan(ctx context.Context, userID string) int64 {
	if k.rdb == nil {
		return AylikKota
	}
	n, err := k.rdb.Get(ctx, k.anahtar(userID)).Int64()
	if err != nil && err != redis.Nil {
		k.Hata = err // cagiran okur ve olcum yazar
		return AylikKota
	}
	if err != nil {
		return AylikKota
	}
	if kalan := AylikKota - n; kalan > 0 {
		return kalan
	}
	return 0
}

// PresignIzni — dakikalik hiz siniri. false donerse 429.
// ⚠️ Sabit pencere (kayan degil) — basit ve Redis'te tek anahtar. Pencere sinirinda
//
//	iki kat istek gecebilir; kabul edilebilir cunku asil koruma KOTA.
func (k *Kota) PresignIzni(ctx context.Context, userID string) bool {
	if k.rdb == nil {
		return true
	}
	a := fmt.Sprintf("medya:presign:%s:%d", userID, time.Now().Unix()/60)
	n, err := k.rdb.Incr(ctx, a).Result()
	if err != nil {
		return true // Redis hatasi mesajlasmayi durdurmasin
	}
	if n == 1 {
		k.rdb.Expire(ctx, a, 2*time.Minute)
	}
	return n <= PresignDakikaLimit
}

// PresignSuresi — dosya buyudukce imza omru uzar.
// ⚠️ SABIT 300sn YETMEZ: yavas hucresel hatta 16 MB video 5 dakikada bitmez ve
//
//	yukleme imza suresi dolunca 403 alip BASTAN baslar (sonsuz dongu).
//	Formul: 20 KB/sn'lik kotu-durum hizina gore, 5 dk ile 30 dk arasinda.
func PresignSuresi(bytes int64) time.Duration {
	sn := bytes / 20000
	if sn < 300 {
		sn = 300
	}
	if sn > 1800 {
		sn = 1800
	}
	return time.Duration(sn) * time.Second
}
