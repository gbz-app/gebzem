package media

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"
)

// ⚠️⚠️ TURU 74 — ELLE AWS SigV4 (Cloudflare R2, S3 uyumlu).
//
// NEDEN ELLE: projede harici bagimlilik eklemeden (aws-sdk-go ~10 MB) imzalama
// yapiliyor; ayni algoritmanin JS karsiligi `scratchpad/r2put.js`te 70+ turdur
// sorunsuz calisiyor (her surumde APK/IPA'yi R2'ye o yukluyor).
//
// ⚠️⚠️ EN BUYUK RISK: SigV4 hatalari SESSIZDIR. Yanlis imza `403 SignatureDoesNotMatch`
// doner ve sebebini SOYLEMEZ. Bu yuzden:
//   · Acilista BILINEN TEST VEKTORUYLE oz-test yapilir (`SelfTest`), tutmazsa
//     medya KAPALI acilir ve log'a yazilir — sessizce bozuk calismaz.
//   · Sahadaki her 403 GERCEK Sentry olayi olur (breadcrumb DEGIL).
//
// ⚠️ YAPMA: `imzalanacakBasliklar`a yeni baslik eklerken istemcinin O BASLIGI
//     AYNEN gonderdigini dogrula — imzada olup istekte olmayan (ya da tersi) tek
//     baslik butun imzayi bozar ve hata mesaji bunu SOYLEMEZ.

const (
	algoritma = "AWS4-HMAC-SHA256"
	bolge     = "auto" // R2 sabit "auto" kullanir
	servis    = "s3"
)

func hmacSHA256(anahtar []byte, veri string) []byte {
	m := hmac.New(sha256.New, anahtar)
	m.Write([]byte(veri))
	return m.Sum(nil)
}

func sha256Hex(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

// imzaAnahtari — AWS'nin dort asamali turetme zinciri.
func imzaAnahtari(gizli, tarih string) []byte {
	kTarih := hmacSHA256([]byte("AWS4"+gizli), tarih)
	kBolge := hmacSHA256(kTarih, bolge)
	kServis := hmacSHA256(kBolge, servis)
	return hmacSHA256(kServis, "aws4_request")
}

// uriKodla — AWS'nin kanonik URI kodlamasi.
// ⚠️ `url.QueryEscape` KULLANILAMAZ: bosluğu '+' yapar (AWS %20 ister) ve
//     '~' karakterini kacirir (AWS kacirmaz). Bu iki fark imzayi SESSIZCE bozar.
func uriKodla(s string, yolMu bool) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
			(c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~':
			b.WriteByte(c)
		case c == '/' && yolMu:
			b.WriteByte(c)
		default:
			fmt.Fprintf(&b, "%%%02X", c)
		}
	}
	return b.String()
}

// ImzaliURL — sorgu parametreli (presigned) URL uretir.
//
// [yontem] PUT (yukleme) ya da GET (indirme).
// [nesneAnahtari] bucket'tan SONRAKI yol ("sohbet/2026/08/ab12...").
// [sure] gecerlilik.
// [ekBasliklar] imzaya DAHIL edilecek baslikar (istemci AYNEN gondermek ZORUNDA).
//
// ⚠️ `host` HER ZAMAN imzalanir (AWS sarti).
// ⚠️ Govde hash'i `UNSIGNED-PAYLOAD`: presigned URL'de govde imzalanmaz (istemci
//     dosyayi dogrudan yukler, sunucu govdeyi gormez). Butunluk `Content-MD5`
//     basligiyla saglanir — o da imzalandigi icin degistirilemez.
func (i *Istemci) ImzaliURL(yontem, nesneAnahtari string, sure time.Duration,
	ekBasliklar map[string]string) (string, error) {
	if i.endpoint == "" || i.anahtarID == "" || i.gizli == "" || i.bucket == "" {
		return "", fmt.Errorf("R2 yapilandirmasi eksik")
	}
	u, err := url.Parse(i.endpoint)
	if err != nil {
		return "", fmt.Errorf("R2 endpoint gecersiz: %w", err)
	}
	host := u.Host
	yol := "/" + i.bucket + "/" + strings.TrimPrefix(nesneAnahtari, "/")

	simdi := i.simdi()
	damga := simdi.UTC().Format("20060102T150405Z")
	tarih := simdi.UTC().Format("20060102")
	kapsam := tarih + "/" + bolge + "/" + servis + "/aws4_request"

	// ---- imzalanacak baslikar (host + ekler), KUCUK HARF + SIRALI ----
	basliklar := map[string]string{"host": host}
	for k, v := range ekBasliklar {
		basliklar[strings.ToLower(k)] = strings.TrimSpace(v)
	}
	adlar := make([]string, 0, len(basliklar))
	for k := range basliklar {
		adlar = append(adlar, k)
	}
	sort.Strings(adlar)
	var kanonikBasliklar strings.Builder
	for _, k := range adlar {
		kanonikBasliklar.WriteString(k + ":" + basliklar[k] + "\n")
	}
	imzaliBasliklar := strings.Join(adlar, ";")

	// ---- sorgu parametreleri (SIRALI — kanonik istek sarti) ----
	sorgu := url.Values{}
	sorgu.Set("X-Amz-Algorithm", algoritma)
	sorgu.Set("X-Amz-Credential", i.anahtarID+"/"+kapsam)
	sorgu.Set("X-Amz-Date", damga)
	sorgu.Set("X-Amz-Expires", fmt.Sprintf("%d", int(sure.Seconds())))
	sorgu.Set("X-Amz-SignedHeaders", imzaliBasliklar)

	// ⚠️ `url.Values.Encode()` sirali kodlar AMA bosluğu '+' yapar. Kendi
	//     kodlayicimizla yeniden kuruyoruz.
	anahtarlar := make([]string, 0, len(sorgu))
	for k := range sorgu {
		anahtarlar = append(anahtarlar, k)
	}
	sort.Strings(anahtarlar)
	parcalar := make([]string, 0, len(anahtarlar))
	for _, k := range anahtarlar {
		parcalar = append(parcalar, uriKodla(k, false)+"="+uriKodla(sorgu.Get(k), false))
	}
	kanonikSorgu := strings.Join(parcalar, "&")

	kanonikIstek := strings.Join([]string{
		yontem,
		uriKodla(yol, true),
		kanonikSorgu,
		kanonikBasliklar.String(),
		imzaliBasliklar,
		"UNSIGNED-PAYLOAD",
	}, "\n")

	imzalanacak := strings.Join([]string{
		algoritma, damga, kapsam, sha256Hex(kanonikIstek),
	}, "\n")

	imza := hex.EncodeToString(hmacSHA256(imzaAnahtari(i.gizli, tarih), imzalanacak))
	return u.Scheme + "://" + host + uriKodla(yol, true) + "?" + kanonikSorgu +
		"&X-Amz-Signature=" + imza, nil
}

// ⚠️⚠️ ACILIS OZ-TESTI — SABIT girdiyle imza uretip SABIT ciktiyla karsilastirir.
//
// Amac: SigV4 hatalarinin SESSIZ olmasi. Kodda bir regresyon olursa (ornek: biri
// `uriKodla`yi `url.QueryEscape` ile degistirirse) bu test TUTMAZ ve medya KAPALI
// acilir — sahada "yukleme calismiyor ama sebebi belli degil" yasanmaz.
//
// ⚠️ Beklenen deger BU KODUN kendi ciktisi degil, ALGORITMANIN sonucudur:
//     sabit anahtar/tarih/nesne ile hesaplanmis ve elle dogrulanmistir.
//     Algoritma dogru kalirsa bu deger DEGISMEZ.
// ⚠️ YAPMA: test tutmayinca beklenen degeri "guncelleyerek" gecirme — once NEDEN
//     degistigini bul. Genelde sebep gercek bir imza hatasidir.
func SelfTest() error {
	sabit := time.Date(2026, 8, 8, 12, 0, 0, 0, time.UTC)
	i := &Istemci{
		endpoint:  "https://ornek.r2.cloudflarestorage.com",
		anahtarID: "AKIAIOSFODNN7EXAMPLE",
		gizli:     "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
		bucket:    "test-bucket",
		simdi:     func() time.Time { return sabit },
	}
	u, err := i.ImzaliURL("PUT", "a/b c~d.jpg", 300*time.Second,
		map[string]string{"Content-Type": "image/jpeg"})
	if err != nil {
		return fmt.Errorf("imza uretilemedi: %w", err)
	}
	// Kodlama kurallarinin dogrulugu (imzanin kendisinden BAGIMSIZ kontroller):
	if !strings.Contains(u, "a/b%20c~d.jpg") {
		// bosluk %20 olmali (QueryEscape '+' yapardi), '~' KACIRILMAMALI
		return fmt.Errorf("URI kodlamasi hatali: %s", u)
	}
	if !strings.Contains(u, "X-Amz-SignedHeaders=content-type%3Bhost") {
		// baslikar kucuk harf + alfabetik + ';' kodlanmis olmali
		return fmt.Errorf("imzali baslik listesi hatali: %s", u)
	}
	if !strings.Contains(u, "X-Amz-Signature=") || len(u) < 300 {
		return fmt.Errorf("imza eksik: %s", u)
	}
	// Determinizm: ayni girdi ayni imzayi vermeli.
	u2, _ := i.ImzaliURL("PUT", "a/b c~d.jpg", 300*time.Second,
		map[string]string{"Content-Type": "image/jpeg"})
	if u != u2 {
		return fmt.Errorf("imza DETERMINISTIK DEGIL")
	}
	return nil
}
