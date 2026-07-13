package push

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/net/http2"
)

// APNs VoIP push — iOS'ta uygulama KAPALI/KILITLI iken aramayi caldirmanin TEK yolu.
//
// NEDEN FCM DEGIL: FCM, VoIP push (apns-push-type: voip) GONDEREMEZ. VoIP push dogrudan
// APNs'e (api.push.apple.com) gonderilir, konu (topic) <bundle-id>.voip olur.
// iOS 13+ KURALI: VoIP push alan uygulama CallKit'e reportNewIncomingCall cagirmak
// ZORUNDA — cagirmazsa iOS uygulamayi COKERTIR ve bir sure sonra VoIP push'lari KESER.
// (Bu yuzden istemcide flutter_callkit_incoming, push gelir gelmez arama ekranini gosterir.)

type APNs struct {
	teamID   string
	keyID    string
	bundleID string
	key      *ecdsa.PrivateKey
	host     string

	mu       sync.Mutex
	token    string
	tokenExp time.Time

	client *http.Client
	db     *pgxpool.Pool
}

// NewAPNs: APNS_KEY_PATH (.p8), APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID
// Yoksa nil doner (VoIP push kapali — uygulama acikken aramalar yine calisir).
func NewAPNs(db *pgxpool.Pool) *APNs {
	path := os.Getenv("APNS_KEY_PATH")
	keyID := os.Getenv("APNS_KEY_ID")
	teamID := os.Getenv("APNS_TEAM_ID")
	bundleID := getEnv("APNS_BUNDLE_ID", "app.gebzem")
	if path == "" || keyID == "" || teamID == "" {
		log.Println("voip push: APNS_* tanimsiz — kilit ekrani aramasi (iOS) kapali")
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		log.Printf("voip push: .p8 okunamadi (%v) — kapali", err)
		return nil
	}
	block, _ := pem.Decode(raw)
	if block == nil {
		log.Println("voip push: .p8 pem cozulemedi — kapali")
		return nil
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		log.Printf("voip push: anahtar parse (%v) — kapali", err)
		return nil
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		log.Println("voip push: anahtar ECDSA degil — kapali")
		return nil
	}

	// APNs HTTP/2 SART (HTTP/1.1 kabul etmez)
	tr := &http.Transport{}
	if err := http2.ConfigureTransport(tr); err != nil {
		log.Printf("voip push: http2 (%v) — kapali", err)
		return nil
	}

	// Ad hoc / TestFlight / App Store hepsi PRODUCTION APNs kullanir.
	// Sadece Xcode'dan debug kurulumda sandbox gerekir (APNS_SANDBOX=1).
	host := "https://api.push.apple.com"
	if os.Getenv("APNS_SANDBOX") == "1" {
		host = "https://api.sandbox.push.apple.com"
	}

	log.Printf("voip push: aktif (konu: %s.voip)", bundleID)
	return &APNs{
		teamID: teamID, keyID: keyID, bundleID: bundleID, key: key, host: host,
		client: &http.Client{Transport: tr, Timeout: 15 * time.Second},
		db:     db,
	}
}

// APNs kimlik token'i (ES256, en fazla 1 saat gecerli — 50 dk'da yenile)
func (a *APNs) jwt() (string, error) {
	a.mu.Lock()
	defer a.mu.Unlock()
	if a.token != "" && time.Now().Before(a.tokenExp) {
		return a.token, nil
	}
	t := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{
		"iss": a.teamID,
		"iat": time.Now().Unix(),
	})
	t.Header["kid"] = a.keyID
	signed, err := t.SignedString(a.key)
	if err != nil {
		return "", err
	}
	a.token = signed
	a.tokenExp = time.Now().Add(50 * time.Minute)
	return signed, nil
}

// CallInvite: iOS cihazlara VoIP push — kilit ekraninda arama ekrani acar
func (a *APNs) CallInvite(ctx context.Context, userID string, payload map[string]any) {
	if a == nil {
		return
	}
	rows, err := a.db.Query(ctx,
		`SELECT token FROM voip_tokens WHERE user_id=$1`, userID)
	if err != nil {
		log.Printf("voip push: token sorgusu: %v", err)
		return
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if rows.Scan(&t) == nil {
			tokens = append(tokens, t)
		}
	}
	if len(tokens) == 0 {
		return
	}

	body, _ := json.Marshal(payload)
	for _, tok := range tokens {
		if err := a.gonder(ctx, tok, body); err != nil {
			log.Printf("voip push: gonderim: %v", err)
		}
	}
}

// CallCancel: iOS'ta calan/asili CallKit ekranini kapatmak icin VoIP push.
// type=call.cancel -> istemci (AppDelegate) reportNewIncomingCall + hemen endCall yapar,
// boylece asili kalan arama ekrani kapanir (kullanici kapatinca karsi taraf da kapansin).
func (a *APNs) CallCancel(ctx context.Context, userID, callID string) {
	if a == nil {
		return
	}
	rows, err := a.db.Query(ctx, `SELECT token FROM voip_tokens WHERE user_id=$1`, userID)
	if err != nil {
		return
	}
	defer rows.Close()
	var tokens []string
	for rows.Next() {
		var t string
		if rows.Scan(&t) == nil {
			tokens = append(tokens, t)
		}
	}
	if len(tokens) == 0 {
		return
	}
	body, _ := json.Marshal(map[string]any{"type": "call.cancel", "call_id": callID})
	for _, tok := range tokens {
		if err := a.gonder(ctx, tok, body); err != nil {
			log.Printf("voip cancel: %v", err)
		}
	}
}

func (a *APNs) gonder(ctx context.Context, deviceToken string, body []byte) error {
	jwtTok, err := a.jwt()
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, "POST",
		a.host+"/3/device/"+deviceToken, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+jwtTok)
	req.Header.Set("apns-topic", a.bundleID+".voip") // VoIP icin .voip SART
	req.Header.Set("apns-push-type", "voip")         // iOS 13+ zorunlu
	req.Header.Set("apns-priority", "10")            // hemen ilet
	req.Header.Set("apns-expiration", fmt.Sprint(time.Now().Add(45*time.Second).Unix()))

	resp, err := a.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return nil
	}
	raw, _ := io.ReadAll(resp.Body)
	// Cihaz artik gecerli degilse token'i sil
	if resp.StatusCode == http.StatusGone || bytes.Contains(raw, []byte("BadDeviceToken")) {
		a.db.Exec(ctx, `DELETE FROM voip_tokens WHERE token=$1`, deviceToken)
	}
	return fmt.Errorf("apns %s: %s", resp.Status, string(raw))
}

func getEnv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
