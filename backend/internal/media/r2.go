package media

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// ⚠️⚠️ TURU 74 — R2 ISTEMCISI (S3 uyumlu, harici bagimlilik YOK).
//
// TASARIM KARARI (medya-plani.md): medya API'DEN GECMEZ. Istemci presigned PUT ile
// DOGRUDAN R2'ye yukler. Sunucu yalnizca (a) imza uretir, (b) commit'te nesnenin
// GERCEKTEN beklenen sey oldugunu HeadObject + kucuk Range GET ile dogrular,
// (c) gerekirse siler. Sebep: cx33'te 4 vCPU'yu LiveKit ile paylasiyoruz; 100 MB'lik
// govdeleri proxy'lemek SFU'yu ac birakir.

type Istemci struct {
	endpoint  string
	anahtarID string
	gizli     string
	bucket    string
	hc        *http.Client
	// ⚠️ Test edilebilirlik icin saat enjekte edilir (SelfTest sabit zaman kullanir).
	simdi func() time.Time
}

// YeniIstemci — env bos ise nil DONER (cagiran `Enabled()` ile kontrol eder).
// ⚠️ FAIL-CLOSED AMA GORUNUR: yapilandirma eksikse medya uclari HIC KAYDEDILMEZ ve
//     acilista log'a yazilir. Sessizce yarim calisan bir medya katmani, sahada
//     "bazen yukleniyor bazen yuklenmiyor" olarak gorunurdu.
func YeniIstemci(endpoint, anahtarID, gizli, bucket string) *Istemci {
	if endpoint == "" || anahtarID == "" || gizli == "" || bucket == "" {
		return nil
	}
	return &Istemci{
		endpoint:  strings.TrimSuffix(endpoint, "/"),
		anahtarID: anahtarID,
		gizli:     gizli,
		bucket:    bucket,
		// ⚠️ Timeout SART: R2'ye giden istek asilirsa HTTP isleyicisi ve dolayisiyla
		//     bir Postgres baglantisi kilitli kalir.
		hc:    &http.Client{Timeout: 20 * time.Second},
		simdi: time.Now,
	}
}

// NesneBilgi — HeadObject sonucu.
type NesneBilgi struct {
	Bytes int64
	MIME  string
	ETag  string
}

// Head — nesnenin GERCEK boyutunu ve tipini R2'den okur.
// ⚠️ Commit yolunda ZORUNLU: istemcinin BEYAN ettigi boyuta GUVENILMEZ.
func (i *Istemci) Head(ctx context.Context, nesneAnahtari string) (*NesneBilgi, error) {
	u, err := i.ImzaliURL("HEAD", nesneAnahtari, 60*time.Second, nil)
	if err != nil {
		return nil, err
	}
	req, _ := http.NewRequestWithContext(ctx, http.MethodHead, u, nil)
	res, err := i.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusNotFound {
		return nil, ErrNesneYok
	}
	if res.StatusCode != http.StatusOK {
		return nil, i.hataOlarak("HEAD", res.StatusCode)
	}
	n, _ := strconv.ParseInt(res.Header.Get("Content-Length"), 10, 64)
	return &NesneBilgi{
		Bytes: n,
		MIME:  res.Header.Get("Content-Type"),
		ETag:  strings.Trim(res.Header.Get("ETag"), `"`),
	}, nil
}

// BasParcasi — nesnenin ILK [n] baytini ceker (sihirli bayt / EXIF dogrulamasi icin).
// ⚠️ Neden Range: 16 MB'lik videoyu indirip RAM'e almak cx33'te kabul edilemez.
//     Ilk 256 KB tip tespiti ve EXIF taramasi icin FAZLASIYLA yeter.
func (i *Istemci) BasParcasi(ctx context.Context, nesneAnahtari string, n int64) ([]byte, error) {
	u, err := i.ImzaliURL("GET", nesneAnahtari, 60*time.Second, nil)
	if err != nil {
		return nil, err
	}
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	req.Header.Set("Range", fmt.Sprintf("bytes=0-%d", n-1))
	res, err := i.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK && res.StatusCode != http.StatusPartialContent {
		return nil, i.hataOlarak("RANGE-GET", res.StatusCode)
	}
	// ⚠️ LimitReader SART: sunucu Range'i yok sayip TUM dosyayi gonderirse
	//     belleği koruruz.
	return io.ReadAll(io.LimitReader(res.Body, n))
}

// Sil — nesneyi R2'den kaldirir. DeleteObject R2'de UCRETSIZDIR.
// ⚠️ Idempotent: olmayan nesne icin de basarili sayilir (404 hata DEGIL).
func (i *Istemci) Sil(ctx context.Context, nesneAnahtari string) error {
	u, err := i.ImzaliURL("DELETE", nesneAnahtari, 60*time.Second, nil)
	if err != nil {
		return err
	}
	req, _ := http.NewRequestWithContext(ctx, http.MethodDelete, u, nil)
	res, err := i.hc.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	if res.StatusCode == http.StatusNoContent || res.StatusCode == http.StatusOK ||
		res.StatusCode == http.StatusNotFound {
		return nil
	}
	return i.hataOlarak("DELETE", res.StatusCode)
}

// ⚠️⚠️ 403 = imza hatasi. Bunu AYIRT ETMEK kritik cunku SigV4 hatalari sessizdir;
//     cagiran taraf 403'u GERCEK Sentry olayi olarak yazar (breadcrumb degil).
type R2Hata struct {
	Islem string
	Kod   int
}

func (e *R2Hata) Error() string { return fmt.Sprintf("R2 %s: HTTP %d", e.Islem, e.Kod) }

// ImzaHatasiMi — 403 ise SigV4 bozulmus olabilir; cagiran ALARM uretir.
func (e *R2Hata) ImzaHatasiMi() bool { return e.Kod == http.StatusForbidden }

var ErrNesneYok = fmt.Errorf("nesne yok")

func (i *Istemci) hataOlarak(islem string, kod int) error {
	if kod == http.StatusForbidden {
		// ⚠️ Sahada bu satiri gorursen: R2 anahtarlari yanlis YA DA SigV4 bozuk.
		log.Printf("⚠️ R2 %s -> 403: imza/anahtar sorunu olabilir", islem)
	}
	return &R2Hata{Islem: islem, Kod: kod}
}
