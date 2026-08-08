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
//
// ⚠️⚠️ TURU 76 — VIDEO 16 MB -> 100 MB (KULLANICI EMRI: "video dosya boyutu
// 100mb olarak duzenle").
//
//	ESKI TAVANIN GERCEK ANLAMI: iPhone 1080p30 HEVC ~8 Mbit/sn = ~1 MB/sn, yani
//	16 MB ~16 SANIYELIK video demekti. Kullanici galeriden sectigi HERHANGI bir
//	gercek videoyu gonderemiyordu; 413 "dosya çok büyük" aliyordu.
//
// ⚠️⚠️ TAVANI DEGISTIRMEK TEK BASINA YETMEZ — dort zincirleme nokta var ve
//
//	hepsi bu turda birlikte duzeltildi:
//	 (1) `PresignSuresi` tavani (asagida) — 30 dk yalniz ~34 MB'a yetiyordu,
//	 (2) istemcide MD5 dosyanin TAMAMINI RAM'e okuyordu (100 MB'da OOM/donma),
//	 (3) istemcide Dio `sendTimeout` sabit 10 dk (= 1.4 Mbit/sn zorunlu minimum),
//	 (4) indirme URL'i 600 sn (uzun video oynatilirken imza doluyordu).
//
// ⚠️ YAPMA: tavani buyutup bunlardan birini guncellemeden birakma.
var Tavanlar = map[string]int64{
	"image":    8 << 20,   // 8 MB — sikistirilmis foto ~300 KB, tavan cok genis
	"avatar":   4 << 20,   // 4 MB
	"audio":    16 << 20,  // 16 MB — ~10 dk ses notu
	"video":    100 << 20, // 100 MB (kullanici karari 8 Agu)
	"document": 32 << 20,  // 32 MB
}

// ⚠️ TURU 74b: kucuk resim TAVANI. Eskiden hic yoktu ve thumb nesnesi hicbir
// dogrulamadan gecmiyordu -> tek hesapla sinirsiz R2 faturasi.
const ThumbTavan = 512 << 10 // 512 KB

const (
	// Kullanici basina AYLIK yukleme kotasi.
	// ⚠️ Veri SILINMEDIGI icin bu deger dogrudan aylik maliyet artisidir.
	//
	// ⚠️⚠️ TURU 76 — 500 MB -> 3 GB. GEREKCE: video tavani 100 MB'a cikarildi;
	//    500 MB kota ile kullanici AYDA YALNIZ 5 VIDEO yukleyebilirdi ve 5.'den
	//    sonra 507 "aylık yükleme kotanız doldu" gorurdu. "100 MB video
	//    gonderebilirsin" deyip 5 video vermek CELISKILI bir vaat olurdu.
	//    3 GB = ayda ~30 video (ya da binlerce fotograf).
	//
	// ⚠️ MALIYET (kullanici karari geregi VERI SILINMIYOR, yani KALICI):
	//    R2 depolama $0.015/GB/ay. 1000 aktif kullanici x 3 GB = 3 TB/ay eklenir
	//    -> ilk ay ~$45, BIRIKIMLI: 12. ayda ~$540/ay. Kullanici bu buyumeyi
	//    bilerek kabul etti ("sürekli veri olacak büyüyecek, bunu Cloudflare
	//    sayacağız"). Cikis (egress) R2'de UCRETSIZ.
	// ⚠️ Deger degistirilecekse maliyet hesabini da guncelle.
	AylikKota = 3 << 30 // 3 GB

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
// ⚠️ SABIT 300sn YETMEZ: yavas hucresel hatta buyuk video 5 dakikada bitmez ve
//
//	yukleme imza suresi dolunca 403 alip BASTAN baslar (sonsuz dongu).
//	Formul: 20 KB/sn'lik kotu-durum hizina gore hesaplanir.
//
// ⚠️⚠️ TURU 76 — TAVAN 1800 -> 5400 sn (90 dk).
//
//	ESKI TAVANIN MATEMATIGI: 1800 sn x 20 KB/sn = **34.3 MB**. Yani video tavani
//	100 MB'a cikarilinca, kotu hatta yukleme 30. dakikada 403
//	SignatureDoesNotMatch/expired alir, istemci bunu "Dosya yüklenemedi (403)"
//	diye gosterir, kullanici tekrar dener ve AYNI YERDE yine takilir.
//	100 MiB / 20 KB/sn = 87.4 dk -> 90 dk tavan.
//
// ⚠️ SigV4 presigned URL ust siniri 7 GUN (604800 sn) oldugu icin bu guvenli.
// ⚠️ ZINCIRLEME: `handler.go` supurgesi 'beklemede' kayitlari belli bir yastan
//
//	sonra temizliyor — o pencere bu sureden KISA OLMAMALI, yoksa kullanici hala
//	yuklerken kaydi silinir.
func PresignSuresi(bytes int64) time.Duration {
	sn := bytes / 20000
	if sn < 300 {
		sn = 300
	}
	if sn > 5400 {
		sn = 5400
	}
	return time.Duration(sn) * time.Second
}
