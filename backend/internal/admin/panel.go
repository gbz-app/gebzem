package admin

import (
	"embed"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
)

// ⚠️⚠️⚠️ TURU 181 — PANEL VARLIKLARI **`embed.FS` ILE**, Go ham dizesiyle
//
//	DEGIL.
//
// ═══════════ NEDEN DEGISTI ═══════════
//
// Eski panel `internal/calls/handler.go` icinde `adminHTML` adli TEK BIR
// ham dize sabitiydi (~137 satir; CSS + HTML + JS ic ice). Panel bu turda
// sekiz sekmeye ve yaklasik 1.000 satira cikiyor; onu bir Go dizesi icinde
// tutmak sunlari getirirdi:
//   - editor sozdizimi vurgulamasi ve bicimlendirme YOK,
//   - dize icinde BACKTICK yazilamaz (Go ham dizesini KAPATIR — turu 180'de
//     SQL tarafinda derlemeyi patlatti),
//   - `%` ve kacis karakterleri surekli tuzak.
//
// `//go:embed` ile varliklar AYRI DOSYALAR olarak yasar ama yine de
// **IKILIYE GOMULUR**: dagitim tek binary kalir, Dockerfile `COPY . .`
// yaptigi icin deploy akisi HIC DEGISMEZ.
//
// ⚠️ `internal/database` ZATEN bu deseni kullaniyor (`//go:embed
//
//	migrations/*.sql`) — yeni bir mekanizma degil, mevcut olanin
//	tekrari.
//
//go:embed panel/*
var panelFS embed.FS

// icerikTuru — uzantidan MIME.
//
// ⚠️⚠️ ACIKCA YAZILIR (turu 96i dersi): baslik yazilmazsa Go govdeyi koklar
//
//	ve `.js` dosyasina `text/plain` koyabilir; tarayici o zaman betigi
//	CALISTIRMAZ ve panel BOS bir sayfa olarak acilir — hata mesaji da
//	olmaz.
func icerikTuru(yol string) string {
	switch {
	case strings.HasSuffix(yol, ".html"):
		return "text/html; charset=utf-8"
	case strings.HasSuffix(yol, ".css"):
		return "text/css; charset=utf-8"
	case strings.HasSuffix(yol, ".js"):
		return "application/javascript; charset=utf-8"
	default:
		return "application/octet-stream"
	}
}

// Panel — GET /admin/izle
//
// ⚠️ HTML **HERKESE ACIK** (giris ekranini iceriyor); asil koruma veri
//
//	uclarinda. Eski panelin karari aynen korundu.
func (h *Handler) Panel(w http.ResponseWriter, r *http.Request) {
	b, err := panelFS.ReadFile("panel/index.html")
	if err != nil {
		http.Error(w, "panel bulunamadı", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", icerikTuru("index.html"))
	// ⚠️⚠️ `no-store`: panel her surumde degisiyor ve tarayici onbellegi
	//	yoneticiye ESKI arayuzu gosterirse yeni uclara istek atmayan bir
	//	sayfa ile ugrasir (indir sayfasinda turu 115c'de aynen yasandi).
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Write(b)
}

// Varlik — GET /admin/varlik/{dosya}
//
// ⚠️⚠️ YOL GECISI (path traversal) KAPISI: `chi.URLParam` bir yol PARCASI
//
//	dondurur ama yine de `/` ve `.` iceren degerler REDDEDILIR. Aksi
//	halde `../../etc/passwd` gibi bir deger `embed.FS`in disina
//	cikamaz (embed guvenlidir) ama savunma katmani ucuz.
func (h *Handler) Varlik(w http.ResponseWriter, r *http.Request) {
	ad := chi.URLParam(r, "dosya")
	if ad == "" || strings.Contains(ad, "/") || strings.Contains(ad, "..") {
		http.NotFound(w, r)
		return
	}
	b, err := panelFS.ReadFile("panel/" + ad)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", icerikTuru(ad))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Write(b)
}
