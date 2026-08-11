package rota

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"
)

// ⚠️⚠️ TURU 75 — ROTA KAYIT TESTI.  (turu 77:  DAN BURAYA TASINDI)
//
// ⚠️ NEDEN TASINDI:  test ikilisi TUM uygulamayi linkledigi icin
//
//	Windows "Uygulama Denetimi" ilkesi onu CALISTIRMIYOR ("Uygulama Denetimi
//	ilkesi bu dosyayi engelledi"). Diger paketlerin kucuk test ikilileri
//	sorunsuz kosuyor. Bu muhafiz PROJENIN EN DEGERLI testlerinden biri
//	(chi cakismasi sunucuyu ACILISTA oldurur) — calisamaz durumda birakmak
//	yerine kucuk bir pakete tasindi.
//
// ⚠️ Kaynak yine  DAN okunuyor: DRIFT YOK.
//
// NEDEN VAR: chi, CAKISAN yol desenlerinde **calisma aninda PANIK** atar ve bu
// `go build`/`go vet` ile YAKALANMAZ. Turu 75'te tek seferde 25+ yeni uc eklendi
// (sosyal + kanal); bir cakisma sunucuyu ACILISTA oldururdu ve ancak deploy
// sonrasi fark edilirdi.
//
// ⚠️ DRIFT YOK: test desenleri elle KOPYALAMAZ, `main.go` KAYNAGINDAN okur.
//
//	Yeni bir uc eklendiginde test onu kendiliginden kapsar.
//
// ⚠️ YAPMA: desenleri bu dosyaya elle yazma (kopya listeler drift eder — bu
//
//	projede `_onEvent`/`mesgulMu` ikilisinde tam olarak bu yasandi, turu 72b/H).
var rotaDeseni = regexp.MustCompile(`r\.(Get|Post|Put|Patch|Delete|Head|Options)\("([^"]+)"`)

func mainGoRotalari(t *testing.T) map[string][]string {
	t.Helper()
	ham, err := os.ReadFile(filepath.Join("..", "..", "cmd", "api", "main.go"))
	if err != nil {
		t.Fatalf("main.go okunamadi: %v", err)
	}
	out := map[string][]string{}
	for _, m := range rotaDeseni.FindAllStringSubmatch(string(ham), -1) {
		yontem := strings.ToUpper(m[1])
		out[yontem] = append(out[yontem], m[2])
	}
	if len(out) == 0 {
		t.Fatal("main.go icinde hic rota bulunamadi — regex bozulmus olabilir")
	}
	return out
}

// Butun desenleri TEK chi mux'ina kaydeder. Cakisma varsa chi panik atar ve
// test PATLAR — sunucu acilista olmek yerine burada olur.
func TestRotalarCakismiyor(t *testing.T) {
	rotalar := mainGoRotalari(t)
	toplam := 0

	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("ROTA CAKISMASI (chi panik): %v", r)
		}
	}()

	mux := chi.NewRouter()
	bos := func(w http.ResponseWriter, r *http.Request) {}
	for yontem, desenler := range rotalar {
		for _, d := range desenler {
			mux.Method(yontem, d, http.HandlerFunc(bos))
			toplam++
		}
	}
	t.Logf("%d rota cakismasiz kaydedildi", toplam)
}

// Turu 75'te eklenen uclarin GERCEKTEN cozuldugunu dogrular.
//
// ⚠️ ASIL RISK: `/users/me/follow-requests` (STATIK "me") ile `/users/{id}/profile`
//
//	(PARAMETRE) ayni seviyede. chi once statik dugumu dener; statik altinda
//	eslesme bulamazsa PARAMETREYE GERI DONER. Bu geri donus davranisina
//	guveniyoruz — test onu KANITLIYOR. Kirilirsa profil ekrani 404 alir.
func TestYeniUclarCozuluyor(t *testing.T) {
	rotalar := mainGoRotalari(t)
	mux := chi.NewRouter()
	for yontem, desenler := range rotalar {
		for _, d := range desenler {
			desen := d
			mux.Method(yontem, desen, http.HandlerFunc(
				func(w http.ResponseWriter, r *http.Request) {
					w.Header().Set("X-Desen", desen)
					w.WriteHeader(200)
				}))
		}
	}

	const uid = "11111111-1111-1111-1111-111111111111"
	vakalar := []struct{ yontem, yol, beklenen string }{
		// --- sosyal
		{"POST", "/posts", "/posts"},
		{"GET", "/feed", "/feed"},
		{"GET", "/reels", "/reels"},
		{"GET", "/posts/" + uid, "/posts/{id}"},
		{"POST", "/posts/" + uid + "/like", "/posts/{id}/like"},
		{"GET", "/posts/" + uid + "/comments", "/posts/{id}/comments"},
		{"DELETE", "/comments/42", "/comments/{id}"},
		// --- takip / profil  (statik "me" vs parametre {id} geri donusu)
		{"GET", "/users/me/follow-requests", "/users/me/follow-requests"},
		{"GET", "/users/" + uid + "/profile", "/users/{id}/profile"},
		{"GET", "/users/" + uid + "/posts", "/users/{id}/posts"},
		{"GET", "/users/" + uid + "/followers", "/users/{id}/{tur:followers|following}"},
		{"GET", "/users/" + uid + "/following", "/users/{id}/{tur:followers|following}"},
		{"POST", "/users/" + uid + "/follow", "/users/{id}/follow"},
		{"POST", "/users/" + uid + "/follow/approve", "/users/{id}/follow/approve"},
		{"GET", "/notifications", "/notifications"},
		// --- kanal  (statik "kesfet" vs parametre {id})
		{"GET", "/channels", "/channels"},
		{"GET", "/channels/kesfet", "/channels/kesfet"},
		{"GET", "/channels/" + uid, "/channels/{id}"},
		{"GET", "/channels/" + uid + "/posts", "/channels/{id}/posts"},
		{"POST", "/channels/" + uid + "/subscribe", "/channels/{id}/subscribe"},
		{"POST", "/channel-posts/7/like", "/channel-posts/{id}/like"},
		{"DELETE", "/channel-posts/7", "/channel-posts/{id}"},

		// --- TURU 77 DIKEYLERI ---------------------------------------------
		// ⚠️⚠️ EN RISKLI CIFT: `/users/{id}/urunler` ile `/users/{id}/isletme`,
		//    zaten var olan `/users/{id}/{tur:followers|following}` ile AYNI
		//    SEVIYEDE duruyor. chi'nin GERI DONUS (backtracking) davranisi
		//    yanlis anlasilsaydi bu yollar birbirine karisirdi ve
		//    `go build`/`go vet` bunu YAKALAMAZDI (chi CALISMA ANINDA panikler
		//    ya da sessizce yanlis handler'a gider).
		{"GET", "/users/" + uid + "/isletme", "/users/{id}/isletme"},
		{"GET", "/users/" + uid + "/urunler", "/users/{id}/urunler"},
		{"PUT", "/users/me/isletme", "/users/me/isletme"},
		{"DELETE", "/users/me/isletme", "/users/me/isletme"},
		{"GET", "/users/ozet", "/users/ozet"},
		// --- isletme + urun (statik "urunler" vs {id})
		{"GET", "/isletmeler", "/isletmeler"},
		{"GET", "/isletme-kategorileri", "/isletme-kategorileri"},
		{"POST", "/isletme/urunler", "/isletme/urunler"},
		{"PATCH", "/isletme/urunler/" + uid, "/isletme/urunler/{id}"},
		{"DELETE", "/isletme/urunler/" + uid, "/isletme/urunler/{id}"},
		// --- etkinlik (statik "-kategorileri" ayri yol, cakisma yok)
		{"GET", "/etkinlikler", "/etkinlikler"},
		{"GET", "/etkinlik-kategorileri", "/etkinlik-kategorileri"},
		{"GET", "/etkinlikler/" + uid, "/etkinlikler/{id}"},
		{"POST", "/etkinlikler/" + uid + "/katil", "/etkinlikler/{id}/katil"},
		{"GET", "/etkinlikler/" + uid + "/katilimcilar", "/etkinlikler/{id}/katilimcilar"},
		{"DELETE", "/etkinlikler/" + uid, "/etkinlikler/{id}"},
		// ⚠️ TURU 78 — EN RISKLI YENI CIFT: `/etkinlikler/{id}` (PATCH/DELETE) ile
		//    `/etkinlikler/{id}/kadro/{kadroId}` IC ICE gecmis desenler.
		//    chi bunlari karistirirsa `go build` YAKALAMAZ (calisma aninda panik
		//    ya da sessizce yanlis handler).
		{"PATCH", "/etkinlikler/" + uid, "/etkinlikler/{id}"},
		{"GET", "/etkinlikler/" + uid + "/kadro", "/etkinlikler/{id}/kadro"},
		{"POST", "/etkinlikler/" + uid + "/kadro", "/etkinlikler/{id}/kadro"},
		{
			"DELETE", "/etkinlikler/" + uid + "/kadro/" + uid,
			"/etkinlikler/{id}/kadro/{kadroId}",
		},
		// --- ilan
		{"GET", "/ilanlar", "/ilanlar"},
		{"GET", "/ilan-kategoriler", "/ilan-kategoriler"},
		{"GET", "/ilanlar/" + uid, "/ilanlar/{id}"},
		{"PATCH", "/ilanlar/" + uid, "/ilanlar/{id}"},
		// ⚠️ TURU 78: `/ilanlar/{id}/sohbet` ile `/ilanlar/{id}/favori` AYNI
		//    seviyede; chi'nin bunlari karistirmadigini kanitliyoruz.
		{"POST", "/ilanlar/" + uid + "/sohbet", "/ilanlar/{id}/sohbet"},
		{"POST", "/ilanlar/" + uid + "/favori", "/ilanlar/{id}/favori"},
		{"DELETE", "/ilanlar/" + uid + "/favori", "/ilanlar/{id}/favori"},
		// --- ai
		{"GET", "/ai/durum", "/ai/durum"},
		{"POST", "/ai/menu", "/ai/menu"},
		{"POST", "/ai/urun-metni", "/ai/urun-metni"},
		{"POST", "/ai/danisma", "/ai/danisma"},
		// --- hikaye (statik {userId} vs {id}/... ayrimi)
		{"GET", "/stories", "/stories"},
		{"GET", "/stories/" + uid, "/stories/{userId}"},
		{"POST", "/stories/" + uid + "/view", "/stories/{id}/view"},
		{"GET", "/stories/" + uid + "/viewers", "/stories/{id}/viewers"},
		{"DELETE", "/stories/" + uid, "/stories/{id}"},
		// --- TURU 80: randevu/rezervasyon
		//
		// ⚠️⚠️ EN RISKLI AYRIM BURADA: `/isletme/...` (STATIK, tekil) ile
		//    `/isletmeler/{id}/...` (PARAMETRELI, cogul) YAN YANA yasiyor ve
		//    ustelik `/isletmeler` (liste) + `/isletme-kategorileri` de var.
		//    chi'nin geri donus davranisi yanlis calissaydi, isletmenin kendi
		//    ayar ucu musteri ucuna DUSER ve isletme kendi randevu ayarlarini
		//    baska bir isletmenin id'siyle okumaya calisirdi.
		{"GET", "/isletmeler", "/isletmeler"},
		{"GET", "/isletme-kategorileri", "/isletme-kategorileri"},
		{"GET", "/users/" + uid + "/isletme", "/users/{id}/isletme"},
		{
			"GET", "/isletmeler/" + uid + "/uygun-saatler",
			"/isletmeler/{id}/uygun-saatler",
		},
		{"POST", "/isletmeler/" + uid + "/randevu", "/isletmeler/{id}/randevu"},
		{"POST", "/randevular/" + uid + "/durum", "/randevular/{id}/durum"},
		{"GET", "/randevularim", "/randevularim"},
		{"GET", "/isletme/randevular", "/isletme/randevular"},
		{"GET", "/isletme/randevu-ayar", "/isletme/randevu-ayar"},
		{"PUT", "/isletme/randevu-ayar", "/isletme/randevu-ayar"},
		{"GET", "/isletme/randevu-kapali", "/isletme/randevu-kapali"},
		{"POST", "/isletme/randevu-kapali", "/isletme/randevu-kapali"},
		// ⚠️ `/isletme/urunler` de ayni STATIK grupta — birlikte cozulmeli.
		{"POST", "/isletme/urunler", "/isletme/urunler"},
		{"PATCH", "/isletme/urunler/" + uid, "/isletme/urunler/{id}"},

		// --- TURU 91: DIYET (9 uc)
		// ⚠️ EN RISKLI AYRIM: `/diyet/bag` (STATIK, POST) ile
		//    `/diyet/bag/{id}` (PARAMETRELI, PATCH). chi bunlari dogru
		//    cozer ama cakisan bir desen eklenirse CALISMA ANINDA PANIK
		//    atar ve `go build` bunu YAKALAMAZ — testin var olus sebebi bu.
		{"POST", "/diyet/bag", "/diyet/bag"},
		{"PATCH", "/diyet/bag/" + uid, "/diyet/bag/{id}"},
		{"GET", "/diyet/baglarim", "/diyet/baglarim"},
		{"GET", "/diyet/danisanlarim", "/diyet/danisanlarim"},
		// ⚠️ `/diyet/kayit` (POST) vs `/diyet/kayitlar` (GET): AYRI yollar,
		//    biri otekinin oneki DEGIL — ama harf farki tek "lar" oldugu
		//    icin gozden kacabilir.
		{"POST", "/diyet/kayit", "/diyet/kayit"},
		{"PATCH", "/diyet/kayit/" + uid, "/diyet/kayit/{id}"},
		{"GET", "/diyet/kayitlar", "/diyet/kayitlar"},
		{"GET", "/diyet/ozet", "/diyet/ozet"},
		{"GET", "/diyet/besinler", "/diyet/besinler"},

		// --- TURU 91: TEKLIF (yeni rota YOK — mevcut basvuru uclari
		//     `tur='talep'` ilanlarda da calisir; burada YENIDEN dogrulanir
		//     ki ileride biri onlari bolmeye kalkarsa test uyarsin.)
		{"POST", "/ilanlar/" + uid + "/basvuru", "/ilanlar/{id}/basvuru"},
		{"GET", "/ilanlar/" + uid + "/basvurular", "/ilanlar/{id}/basvurular"},
	}

	for _, v := range vakalar {
		req := httptest.NewRequest(v.yontem, v.yol, nil)
		rec := httptest.NewRecorder()
		mux.ServeHTTP(rec, req)
		if rec.Code != 200 {
			t.Errorf("%s %s -> HTTP %d (rota COZULMEDI)", v.yontem, v.yol, rec.Code)
			continue
		}
		if got := rec.Header().Get("X-Desen"); got != v.beklenen {
			t.Errorf("%s %s -> %q desenine dustu, beklenen %q",
				v.yontem, v.yol, got, v.beklenen)
		}
	}
}
