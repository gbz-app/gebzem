package sms

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// SMS gonderici — kendi sunucumuzdan (Firebase Phone Auth KULLANILMIYOR:
// magaza disi kurulumlarda iOS'ta cokuyor, Android'de tarayiciya atiyordu).
//
// Netgsm (Turk saglayici) destekli. Kimlik bilgileri yoksa "dev modu":
// SMS gonderilmez, kod API yanitinda doner (prototip testi icin).

type Sender struct {
	usercode string
	password string
	header   string // onayli gonderici basligi (mesaj basligi)
	client   *http.Client
}

// New: NETGSM_USERCODE / NETGSM_PASSWORD / NETGSM_HEADER varsa gercek SMS gonderir
func New() *Sender {
	user := os.Getenv("NETGSM_USERCODE")
	pass := os.Getenv("NETGSM_PASSWORD")
	header := os.Getenv("NETGSM_HEADER")
	if user == "" || pass == "" || header == "" {
		log.Println("sms: saglayici tanimsiz — TEST MODU (kod API yanitinda doner)")
		return nil
	}
	log.Printf("sms: Netgsm aktif (baslik: %s)", header)
	return &Sender{
		usercode: user,
		password: pass,
		header:   header,
		client:   &http.Client{Timeout: 15 * time.Second},
	}
}

// Enabled: gercek SMS gonderiliyor mu
func (s *Sender) Enabled() bool { return s != nil }

// SendOTP: dogrulama kodunu SMS ile yollar
func (s *Sender) SendOTP(phone, code string) error {
	if s == nil {
		return nil // test modu — SMS yok
	}

	// Netgsm numarayi 90'siz/+'siz bekler: +905551112233 -> 5551112233
	no := strings.TrimPrefix(phone, "+")
	no = strings.TrimPrefix(no, "90")

	msg := fmt.Sprintf("Gebzem dogrulama kodunuz: %s", code)

	params := url.Values{
		"usercode": {s.usercode},
		"password": {s.password},
		"gsmno":    {no},
		"message":  {msg},
		"msgheader": {s.header},
		"dil":      {"TR"},
	}

	resp, err := s.client.PostForm("https://api.netgsm.com.tr/sms/send/get", params)
	if err != nil {
		return fmt.Errorf("sms gonderilemedi: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	result := strings.TrimSpace(string(body))

	// Netgsm: "00 <mesajid>" veya "01 <mesajid>" = basarili; digerleri hata kodu
	if strings.HasPrefix(result, "00") || strings.HasPrefix(result, "01") {
		return nil
	}
	return fmt.Errorf("netgsm hatasi: %s (%s)", result, netgsmError(result))
}

// netgsmError: hata kodunu Turkce aciklamaya cevirir (loglarda anlasilir olsun)
func netgsmError(code string) string {
	switch strings.Fields(code)[0] {
	case "20":
		return "mesaj metni hatali veya cok uzun"
	case "30":
		return "kullanici adi/sifre hatali ya da API erisimi kapali"
	case "40":
		return "mesaj basligi (header) sistemde tanimli degil"
	case "50":
		return "abonelik/IYS izni sorunu"
	case "51":
		return "IYS marka bilgisi eksik"
	case "70":
		return "parametre hatasi"
	case "80":
		return "gonderim sinir asimi"
	case "85":
		return "ayni numaraya cok fazla istek"
	default:
		return "bilinmeyen hata"
	}
}
