package main

import (
	"context"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/getsentry/sentry-go"
	sentryhttp "github.com/getsentry/sentry-go/http"
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/redis/go-redis/v9"

	"github.com/gbz-app/gebzem/backend/internal/ai"
	"github.com/gbz-app/gebzem/backend/internal/auth"
	"github.com/gbz-app/gebzem/backend/internal/bildirim"
	"github.com/gbz-app/gebzem/backend/internal/calls"
	"github.com/gbz-app/gebzem/backend/internal/chat"
	"github.com/gbz-app/gebzem/backend/internal/config"
	"github.com/gbz-app/gebzem/backend/internal/database"
	"github.com/gbz-app/gebzem/backend/internal/diyet"
	"github.com/gbz-app/gebzem/backend/internal/etkinlik"
	"github.com/gbz-app/gebzem/backend/internal/ilan"
	"github.com/gbz-app/gebzem/backend/internal/isletme"
	"github.com/gbz-app/gebzem/backend/internal/kanal"
	"github.com/gbz-app/gebzem/backend/internal/media"
	"github.com/gbz-app/gebzem/backend/internal/push"
	"github.com/gbz-app/gebzem/backend/internal/randevu"
	"github.com/gbz-app/gebzem/backend/internal/rooms"
	"github.com/gbz-app/gebzem/backend/internal/sms"
	"github.com/gbz-app/gebzem/backend/internal/social"
	"github.com/gbz-app/gebzem/backend/internal/streams"
	"github.com/gbz-app/gebzem/backend/internal/udid"
	"github.com/gbz-app/gebzem/backend/internal/users"
	"github.com/gbz-app/gebzem/backend/internal/vitrin"
	"github.com/gbz-app/gebzem/backend/internal/yolbul"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	cfg := config.Load()

	// Hata telemetrisi: panik/hatalar dosya+satir+istek bilgisiyle Sentry'e duser
	if cfg.SentryDSN != "" {
		if err := sentry.Init(sentry.ClientOptions{
			Dsn:              cfg.SentryDSN,
			Environment:      "prototype",
			EnableTracing:    true,
			TracesSampleRate: 0.2,
		}); err != nil {
			log.Printf("sentry baslatilamadi: %v", err)
		} else {
			log.Println("sentry: aktif")
			defer sentry.Flush(2 * time.Second)
		}
	}

	db, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("veritabani: %v", err)
	}
	defer db.Close()
	if err := database.Migrate(ctx, db); err != nil {
		log.Fatalf("migration: %v", err)
	}

	redisOpts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		log.Fatalf("redis url: %v", err)
	}
	rdb := redis.NewClient(redisOpts)
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis: %v", err)
	}

	hub := chat.NewHub(rdb)
	go hub.Run(ctx)

	pushSender := push.New(db)
	apnsSender := push.NewAPNs(db) // iOS kilit ekrani aramasi (VoIP)
	smsSender := sms.New()
	authH := auth.NewHandler(db, cfg, smsSender)
	chatH := chat.NewHandler(db, hub, pushSender)
	// TURU 76: sosyal bildirimlerin TEK KAYNAGI (DB satiri + WS + push).
	// ⚠️ Bu servis gelmeden once social/users paketleri hub'i ve push'u IMPORT
	//    BILE ETMIYORDU -> begeni/yorum/takip bildirimi HIC gitmiyordu.
	bildirimS := bildirim.Yeni(db, hub, pushSender)
	usersH := users.NewHandler(db, bildirimS)
	socialH := social.NewHandler(db, bildirimS) // turu 75: gonderi + akis + etkilesim

	// ⚠️⚠️⚠️ TURU 83 — GONDERI ANKETI: IKI PAKETIN KARSILIKLI BAGI.
	//
	//	`social` anketi YAZAR/OKUR ama anket mantigi `chat`te;
	//	`chat` anketin yetkisini sorar ama gonderi gorunurlugu `social`da.
	//	Ikisini birbirine IMPORT etmek DERLEME DONGUSU riski demekti —
	//	bunun yerine bag BURADA, tek yerde kuruluyor.
	//
	// ⚠️⚠️ **BU UC SATIR UNUTULURSA OZELLIK OLU DOGAR** (ve bu projede
	//
	//	"sutun/servis var ama baglayan yol yok" hatasi DOKUZ kez yasandi):
	//	  · `SetAnket` yoksa  -> anketli gonderi **500** doner,
	//	  · `SetGonderiGorunur` yoksa -> gonderi anketine oy **403** (fail-closed).
	//	Ikisi de SESSIZ degil, GORUNUR sekilde basarisiz olur — bilincli tercih.
	// ⚠️ YAPMA: bu satirlari silme ya da `nil` gecme.
	socialH.SetAnket(chatH.GonderiAnketiYaz, chatH.GonderiAnketleri)
	chatH.SetGonderiGorunur(socialH.GorunurMu)
	kanalH := kanal.NewHandler(db) // turu 75: kanal (tek yonlu yayin)
	isletmeH := isletme.NewHandler(db, bildirimS)
	adresH := isletme.NewAdresHandler(db)
	vitrinH := vitrin.NewHandler(db)
	randevuH := randevu.NewHandler(db, bildirimS)
	etkinlikH := etkinlik.NewHandler(db)
	ilanH := ilan.NewHandler(db, bildirimS)
	// ⚠️ TURU 91 — DIYET TAKIBI. `bildirimS` NIL GECILMEZ: bag istegi ve
	//    diyetisyenden gelen liste bildirim URETIR; nil gecilseydi ozellik
	//    sessizce yarim calisirdi.
	diyetH := diyet.NewHandler(db, bildirimS)
	// TURU 74 — MEDYA. R2 env eksikse Enabled()=false doner ve uclar KAYDEDILMEZ
	// (fail-closed ama GORUNUR: acilista log yazar).
	mediaH := media.NewHandler(db, rdb, cfg.R2Endpoint, cfg.R2AccessKeyID,
		cfg.R2SecretKey, cfg.R2Bucket, func(msg string) { sentry.CaptureMessage(msg) })
	// ⚠️ TURU 77 — AI: MEVCUT medya istemcisini PAYLASIR (ikinci bir R2
	//    istemcisi KURULMADI — ayri istemci = ayri imzalama yapilandirmasi =
	//    drift). `mediaH` KURULDUKTAN SONRA olusturulmali.
	// ⚠️ TURU 79 — gorsel uretimi icin IKI geri cagirim daha: AI paketi R2'ye ve
	//    `media_assets`e DOGRUDAN dokunmaz (ikinci istemci = drift, turu 77/Ç12).
	aiH := ai.NewHandler(db, mediaH.ImzaliAdres,
		mediaH.AIGorseliKaydet, mediaH.AIGorselIzni, mediaH.Enabled,
		mediaH.AIGorseliVazgec)
	usersH.MedyaDurumu(mediaH.Enabled()) // istemci atac dugmesini buna gore gizler

	// TURU 152 — adres arama (Places) + yaya rotasi (Routes) VEKILI.
	// ⚠️ Anahtar YALNIZ sunucuda: bu iki uc birer WEB SERVISI ve anahtari
	//    uygulama kimligiyle kisitlanamiyor (yalniz IP). Repo PUBLIC.
	yolbulH := yolbul.NewHandler(rdb)
	yolbul.LogDurum()
	if mediaH.Enabled() {
		mediaH.StartSweeper(ctx)
	}
	callsH := calls.NewHandler(db, hub, pushSender, apnsSender)
	if callsH.Enabled() {
		log.Println("arama (LiveKit): aktif")
		callsH.StartSweeper(ctx) // takili kalan aramalari kapat (cevapsiz/mesgul hatasi)
	} else {
		log.Println("arama: LIVEKIT_API_KEY yok — kapali")
	}
	roomsH := rooms.NewHandler(db, hub, rdb, pushSender) // Spaces (sesli oda) — in-app, CallKit/zil yok
	if roomsH.Enabled() {
		log.Println("odalar (Spaces): aktif")
		roomsH.StartSweeper(ctx) // host kopmasi / bos oda / 8 saat emniyet
	}
	streamsH := streams.NewHandler(db, rdb, hub, pushSender) // canli yayin (saf WebRTC, izleyici Redis'te)
	if streamsH.Enabled() {
		log.Println("canli yayin: aktif")
		streamsH.StartSweeper(ctx) // olu izleyici / yayinci nabzi / kalp toplama / 12h emniyet
	}

	r := chi.NewRouter()
	r.Use(middleware.RequestID, middleware.RealIP, middleware.Logger)
	if cfg.SentryDSN != "" {
		// Panikleri Sentry'e bildirir, sonra Recoverer sunucuyu ayakta tutar
		r.Use(sentryhttp.New(sentryhttp.Options{Repanic: true}).Handle)
	}
	r.Use(middleware.Recoverer)

	r.Get("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})

	// Admin dashboard (login + kullanicilar + aramalar; ?key= korumali, WS ile anlik)
	// Kolaylik: /admin ve /admin/ -> /admin/izle (kullanici kisa yaziyor)
	adminYonlendir := func(w http.ResponseWriter, req *http.Request) {
		http.Redirect(w, req, "/admin/izle", http.StatusFound)
	}
	r.Get("/admin", adminYonlendir)
	r.Get("/admin/", adminYonlendir)
	r.Get("/admin/izle", callsH.AdminPanel)
	r.Post("/admin/login", callsH.AdminLogin)
	r.Get("/admin/stats", callsH.AdminStats)
	r.Get("/admin/users", callsH.AdminUsers)
	r.Get("/admin/user/{id}", callsH.AdminUserDetail)
	r.Get("/admin/calls", callsH.AdminCalls)
	r.Get("/admin/audio", callsH.AdminAudio) // canli ses teshis
	r.Get("/admin/ws", callsH.AdminWS)
	// Canli yayin moderasyonu (5651: uzaktan bitirme) — ?key= korumali
	r.Get("/admin/streams", streamsH.AdminList)
	r.Post("/admin/streams/{id}/end", streamsH.AdminEnd)

	// iOS test cihazi kaydi (Over-The-Air) — profil yukleyen iPhone UDID'sini buraya yollar
	r.Post("/udid", udid.Handle)

	// TEST TURU 19 — LIVEKIT WEBHOOK: oda bosalinca arama/yayin satiri ANINDA kapanir
	// (uygulama zorla kapatilsa bile). Kimlik: LiveKit'in imzaladigi JWT (Authorization),
	// govde ozeti dogrulanir — bu yuzden auth middleware'i DISINDA.
	r.Post("/livekit/webhook", callsH.LiveKitWebhook)

	// acik uclar
	r.Route("/auth", func(r chi.Router) {
		r.Post("/register", authH.Register)
		r.Post("/verify", authH.Verify)
		// ⚠️⚠️ TURU 84 — ADIMLI KAYIT (telefon -> OTP -> kisisel bilgiler).
		//    Kullanici emri. Eski `/register` + `/verify` ciftine
		//    **DOKUNULMADI**: sahadaki eski surumler onlari kullaniyor ve
		//    yayindaki bir kayit akisini kirmak, kullanicinin uygulamaya HIC
		//    girememesi demektir.
		// ⚠️ YAPMA: eski ikisini silme (once sahada eski surum kalmadigini dogrula).
		r.Post("/kayit/telefon", authH.KayitTelefon)
		r.Post("/kayit/dogrula", authH.KayitDogrula)
		r.Post("/kayit/tamamla", authH.KayitTamamla)
		r.Post("/login", authH.Login)
		r.Post("/forgot", authH.Forgot)
		r.Post("/reset", authH.Reset)
	})

	// korumali uclar
	r.Group(func(r chi.Router) {
		r.Use(auth.Middleware(cfg.JWTSecret, db))
		r.Get("/users/me", usersH.Me)
		r.Patch("/users/me", usersH.UpdateMe)
		r.Post("/users/me/username", usersH.SetUsername)
		r.Post("/users/me/fcm-token", usersH.SaveFCMToken)
		r.Delete("/users/me/fcm-token", usersH.DeleteFCMToken) // cikista bu cihazin token'ini sil
		r.Post("/users/me/voip-token", usersH.SaveVoIPToken)   // iOS kilit ekrani aramasi
		r.Get("/users/search", usersH.Search)
		r.Get("/users/by-phone", usersH.ByPhone)
		// TEST TURU 17: karsi tarafin ARAMA DURUMU (sohbet basliginda "Sesli/Goruntulu aramada")
		r.Get("/users/ozet", usersH.Ozet) // turu 76: kimlik -> ad+avatar (coklu)
		r.Get("/users/{id}/presence", usersH.Presence)
		// ⚠️ TURU 74 — MODERASYON (App Store 1.2 sarti: engelle + sikayet + kaldir).
		//    `blocks` tablosu 001'den beri VARDI ama ucu YOKTU -> engelleme hic calismiyordu.
		r.Post("/users/{id}/block", usersH.Block)
		r.Delete("/users/{id}/block", usersH.Unblock)
		r.Get("/users/me/blocks", usersH.ListBlocks)
		r.Post("/reports", usersH.Report)
		// ⚠️ TURU 75 — SOSYAL KATMAN: takip, profil, bildirimler.
		r.Post("/users/{id}/follow", usersH.Follow)
		r.Delete("/users/{id}/follow", usersH.Unfollow)
		r.Post("/users/{id}/follow/approve", usersH.FollowApprove)
		r.Delete("/users/{id}/follow/approve", usersH.FollowReject)
		r.Get("/users/{id}/{tur:followers|following}", usersH.FollowList)
		r.Get("/users/me/follow-requests", usersH.FollowRequests)
		r.Get("/users/{id}/profile", usersH.Profile)
		r.Patch("/users/me/privacy", usersH.SetPrivacy)
		r.Get("/notifications", usersH.Notifications)
		r.Get("/notifications/count", usersH.NotificationsCount)
		r.Post("/notifications/read", usersH.NotificationsRead)
		// ⚠️ TURU 75 — GONDERI + AKIS + ETKILESIM.
		r.Post("/posts", socialH.Create)
		r.Delete("/posts/{id}", socialH.Delete)
		r.Patch("/posts/{id}", socialH.Update)              // turu 76: gonderi duzenleme
		r.Get("/posts/{id}/istatistik", socialH.Istatistik) // turu 76: yazara ozel
		r.Get("/feed", socialH.Akis)
		r.Get("/kesfet", socialH.Kesfet) // turu 76: arama sekmesi izgarasi
		// ⚠️ TURU 114 — akistaki ucuncu bolme ("Mahalle"): konuma gore gonderi.
		//    `/feed`e bayrak olarak EKLENMEDI (o ucun yanitindaki `kesfet`
		//    bayragi baska bir anlam tasiyor) — gerekce `mahalle.go` serhinde.
		r.Get("/mahalle", socialH.Mahalle)
		// ⚠️ TURU 115 — TikTok tarzi arama: gonderi metni + konum adi.
		r.Get("/ara", socialH.Ara)
		// TURU 77 — ISLETME PROFILLERI
		r.Put("/users/me/isletme", isletmeH.Kaydet)
		r.Delete("/users/me/isletme", isletmeH.KisiselYap)
		r.Get("/users/{id}/isletme", isletmeH.Detay)
		// TURU 78 — kategori inis sayfasinin ust slider'i (ORGANIK vitrin).
		r.Get("/vitrin", vitrinH.Liste)
		r.Get("/isletmeler", isletmeH.Liste)
		// TURU 85 - konuma gore isletme listesi (ustte harita, altta kartlar).
		// STATIK yol PARAMETRELI olandan ONCE gelmeli; chi geri donus yapiyor
		// ama rota_test.go bu ayrimi ayrica dogruluyor.
		r.Get("/isletmeler/yakinimda", isletmeH.Yakinimda)
		r.Get("/isletme-kategorileri", isletmeH.KategoriListesi)
		// TURU 92 - kategori kesif verisi (alt kategoriler + slayt metinleri).
		// Tek uc, iki veri: ayri iki uc acilis anindaki istek sayisini artirirdi.
		r.Get("/isletme-kesif", isletmeH.Kesif)
		// ⚠️ TURU 94 — FAVORI ISLETMELER. Kategori ekraninin sag ustundeki
		//    kalp buraya gider; favorileme kartin uzerindeki kalpten yapilir.
		//    Ikisi BIRLIKTE yazildi (uc var, cagiran yol yok sinifi).
		r.Post("/isletmeler/{id}/favori", isletmeH.FavoriEkle)
		r.Delete("/isletmeler/{id}/favori", isletmeH.FavoriCikar)
		r.Get("/users/me/favori-isletmeler", isletmeH.Favorilerim)

		// ⚠️⚠️ TURU 96h — KAYITLI KONUMLAR (migration 048). Arayuz bunlari
		//    turu 96fde CIHAZDA tutuyordu; telefon degisince kayboluyorlardi.
		// ⚠️ Rotalar `/users/me/...` altinda: adresler KISIYE OZEL ve
		//    kimlik JWT'den geliyor — id URL'de tasinmaz.
		r.Get("/users/me/adresler", adresH.Liste)
		r.Post("/users/me/adresler", adresH.Ekle)
		r.Post("/users/me/adresler/{id}/sec", adresH.Sec)
		r.Delete("/users/me/adresler/{id}", adresH.Sil)
		// TURU 89 - kategoriye ozel katalog modulleri (otel->oda, doktor->hizmet).
		// Istemci bir kez cekip onbellekler; yeni alan eklemek ISTEMCI
		// GUNCELLEMESI GEREKTIRMEZ (ilan.Agac ucuyla ayni gerekce).
		r.Get("/isletme-modulleri", isletmeH.Moduller)

		// ⚠️⚠️ TURU 91 — DIYET (9 uc). HEPSI auth grubunun ICINDE.
		//    Saglik verisi; kimliksiz erisim OLAMAZ.
		// ⚠️ `/diyet/besinler` de korumali: gomulu liste kucuk ama kimliksiz
		//    bir uc acmak, ileride buyuyecek bir yuzeyi bedavaya acardi.
		r.Post("/diyet/bag", diyetH.BagIste)
		r.Patch("/diyet/bag/{id}", diyetH.BagDurum)
		r.Get("/diyet/baglarim", diyetH.Baglarim)
		r.Get("/diyet/danisanlarim", diyetH.Danisanlarim)
		r.Post("/diyet/kayit", diyetH.KayitEkle)
		r.Patch("/diyet/kayit/{id}", diyetH.KayitGuncelle)
		r.Get("/diyet/kayitlar", diyetH.Kayitlar)
		r.Get("/diyet/ozet", diyetH.Ozet)
		r.Get("/diyet/besinler", diyetH.Besinler)
		// TURU 77 — ETKINLIKLER
		r.Post("/etkinlikler", etkinlikH.Olustur)
		r.Get("/etkinlikler", etkinlikH.Liste)
		r.Get("/etkinlik-kategorileri", etkinlikH.KategoriListesi)
		r.Get("/etkinlikler/{id}", etkinlikH.Detay)
		r.Post("/etkinlikler/{id}/katil", etkinlikH.Katil)
		r.Get("/etkinlikler/{id}/katilimcilar", etkinlikH.Katilimcilar)
		// TURU 78 — etkinlik DUZENLEME + KADRO (oyuncu/sarkici).
		r.Patch("/etkinlikler/{id}", etkinlikH.Guncelle)
		r.Get("/etkinlikler/{id}/kadro", etkinlikH.KadroListe)
		r.Post("/etkinlikler/{id}/kadro", etkinlikH.KadroEkle)
		r.Delete("/etkinlikler/{id}/kadro/{kadroId}", etkinlikH.KadroSil)
		r.Delete("/etkinlikler/{id}", etkinlikH.Sil)
		// TURU 77 — ILANLAR (+ HIZMETLER)
		r.Post("/ilanlar", ilanH.Olustur)
		r.Get("/ilanlar", ilanH.Liste)
		r.Get("/ilan-kategoriler", ilanH.Agac)
		r.Get("/ilanlar/{id}", ilanH.Detay)
		r.Patch("/ilanlar/{id}", ilanH.Guncelle)
		// TURU 78 — ILAN HAKKINDA saticiya mesaj (ilan bagalamli sohbet).
		r.Post("/ilanlar/{id}/sohbet", ilanH.SohbetAc)
		r.Post("/ilanlar/{id}/favori", ilanH.FavoriEkle)
		r.Delete("/ilanlar/{id}/favori", ilanH.FavoriSil)
		// TURU 90 - IS ILANI BASVURUSU (kullanici emri).
		// Basvuru YALNIZ tur=is ilanlara yapilir; kapi handler icinde.
		r.Post("/ilanlar/{id}/basvuru", ilanH.BasvuruYap)
		r.Delete("/ilanlar/{id}/basvuru", ilanH.BasvuruGeriCek)
		r.Get("/ilanlar/{id}/basvurular", ilanH.Basvurular)
		r.Patch("/ilanlar/{id}/basvurular/{basvuruID}", ilanH.BasvuruDurum)
		r.Get("/users/me/basvurular", ilanH.Basvurularim)
		// TURU 77 — ISLETME URUNLERI / MENU
		r.Post("/isletme/urunler", isletmeH.UrunEkle)
		r.Patch("/isletme/urunler/{id}", isletmeH.UrunGuncelle)
		r.Delete("/isletme/urunler/{id}", isletmeH.UrunSil)
		r.Get("/users/{id}/urunler", isletmeH.UrunListesi)

		// TURU 152 — ADRES ARAMA + YAYA ROTASI (GOOGLE_SERVIS_KEY yoksa 503;
		// istemci /yolbul/durum ile sorar ve ozelligi HIC CIZMEZ).
		// ⚠️ Korumali grupta: bu uclar PARA HARCIYOR, kimliksiz cagrilamaz.
		r.Get("/yolbul/durum", yolbulH.Durum)
		r.Get("/yolbul/adres", yolbulH.Adres)
		r.Post("/yolbul/yaya", yolbulH.Yaya)

		// TURU 77 — AI (OPENAI_API_KEY yoksa 503; istemci /ai/durum ile sorar)
		r.Get("/ai/durum", aiH.Durum)
		r.Post("/ai/menu", aiH.Menu)
		// ⚠️ TURU 91 — kalori tahmini METIN kotasindan duser
		//    (`tur="kalori"`). Turu 79b'de yanlis etiket SEVK ENGELI olmustu:
		//    "gorsel" yazan bir metin ucu, turun manset ozelligi olan gorsel
		//    uretiminden hak yiyordu.
		r.Post("/ai/kalori", aiH.Kalori)
		r.Post("/ai/urun-metni", aiH.UrunMetni)
		r.Post("/ai/danisma", aiH.Danisma)
		// ⚠️ TURU 79 — metinden URUN GORSELI uretir; AYRI ve DUSUK kota
		//    (bir gorsel ~40 metin cagrisina bedel). Sonuc `media_id` doner ve
		//    HICBIR YERE otomatik baglanmaz — kullanici onaylar.
		r.Post("/ai/gorsel", aiH.Gorsel)
		// ⚠️ TURU 79b — reddedilen uretimi siler (DEPOLAMA kotasini geri verir).
		//    AI hakki iade EDILMEZ: uretim gercekten para harcadi.
		r.Delete("/ai/gorsel/{id}", aiH.GorselVazgec)

		// ⚠️ TURU 80 — REZERVASYON (restoran) + RANDEVU (doktor vb.). TEK tablo,
		//    TEK gecis tablosu: `internal/randevu`.
		r.Get("/isletmeler/{id}/uygun-saatler", randevuH.UygunSaatler)
		r.Post("/isletmeler/{id}/randevu", randevuH.Olustur)
		r.Post("/randevular/{id}/durum", randevuH.DurumDegistir)
		r.Get("/randevularim", randevuH.Randevularim)
		r.Get("/isletme/randevular", randevuH.IsletmeRandevulari)
		r.Get("/isletme/randevu-ayar", randevuH.AyarGetir)
		r.Put("/isletme/randevu-ayar", randevuH.AyarKaydet)
		r.Get("/isletme/randevu-kapali", randevuH.KapaliGunler)
		r.Post("/isletme/randevu-kapali", randevuH.KapaliGun)
		// TURU 76b — HIKAYE (story). 24 saat GORUNURLUK; veri SILINMEZ.
		r.Post("/stories", socialH.StoryOlustur)
		r.Get("/stories", socialH.StoryAkis)
		r.Get("/stories/{userId}", socialH.StoryKullanici)
		r.Post("/stories/{id}/view", socialH.StoryIzlendi)
		r.Get("/stories/{id}/viewers", socialH.StoryIzleyenler)
		r.Delete("/stories/{id}", socialH.StorySil)
		r.Get("/reels", socialH.Reels)
		r.Get("/posts/{id}", socialH.Detay)
		r.Get("/users/{id}/posts", socialH.UserPosts)
		r.Post("/posts/{id}/like", socialH.Like)
		r.Delete("/posts/{id}/like", socialH.Unlike)
		r.Get("/posts/{id}/likes", socialH.Likes)
		r.Post("/posts/{id}/comments", socialH.Comment)
		r.Get("/posts/{id}/comments", socialH.Comments)
		r.Delete("/comments/{id}", socialH.CommentDelete)
		r.Post("/posts/{id}/save", socialH.Save)
		r.Delete("/posts/{id}/save", socialH.Unsave)
		r.Get("/users/me/saved", socialH.Kaydedilenler)

		// ⚠️ TURU 75 — KANAL. Mesaj hattindan AYRI (bkz. internal/kanal serhi:
		//    `chat.SendMessage` uye basina receipt INSERT ediyor; 10.000 aboneli
		//    kanalda tek gonderi 10.000 sorgu demek olurdu).
		// ⚠️ SIRA ONEMLI: "/channels/kesfet" STATIK yol, "/channels/{id}"
		//    parametreli. chi statigi once dener ama okuyan icin acik olsun diye
		//    statik olan USTE yazildi.
		r.Post("/channels", kanalH.Create)
		r.Get("/channels", kanalH.Listem)
		r.Get("/channels/kesfet", kanalH.Kesfet)
		r.Get("/channels/{id}", kanalH.Detay)
		r.Patch("/channels/{id}", kanalH.Update)
		r.Delete("/channels/{id}", kanalH.Delete)
		r.Post("/channels/{id}/subscribe", kanalH.Subscribe)
		r.Delete("/channels/{id}/subscribe", kanalH.Unsubscribe)
		r.Patch("/channels/{id}/mute", kanalH.Mute)
		r.Post("/channels/{id}/read", kanalH.Read)
		r.Post("/channels/{id}/posts", kanalH.PostOlustur)
		r.Get("/channels/{id}/posts", kanalH.Postlar)
		r.Delete("/channel-posts/{id}", kanalH.PostSil)
		r.Get("/channel-posts/{id}/istatistik", kanalH.PostIstatistik) // turu 76b
		r.Post("/channel-posts/{id}/like", kanalH.Like)
		r.Delete("/channel-posts/{id}/like", kanalH.Unlike)
		r.Get("/ws", chatH.WebSocket)
		r.Get("/chats", chatH.ListChats)
		r.Post("/chats/direct", chatH.CreateDirect)
		// TURU 76 — GRUP SOHBETI + sohbet yonetimi (dort olu sutun canlandi).
		r.Post("/chats/group", chatH.CreateGroup)
		r.Get("/chats/{chatID}/members", chatH.GroupMembers)
		r.Post("/chats/{chatID}/members", chatH.GroupAddMember)
		r.Delete("/chats/{chatID}/members/{userID}", chatH.GroupRemoveMember)
		r.Patch("/chats/{chatID}", chatH.UpdateChatSettings)
		r.Delete("/chats/{chatID}", chatH.ClearChat)
		r.Get("/chats/{chatID}/messages", chatH.GetMessages)
		r.Post("/chats/{chatID}/messages", chatH.SendMessage)
		// ⚠️ TURU 74 — herkesten silme. `deleted_for_all` sutunu 001'den beri VARDI ve
		//    listeleme sorgulari onu OKUYORDU, ama SILME UCU YOKTU (sutun olu duruyordu).
		r.Delete("/chats/{chatID}/messages/{msgID}", chatH.DeleteMessage)
		// ⚠️⚠️ TURU 81 — SOHBET ICI ANKET (migration 040).
		//    `messages.type='poll'` 015'ten beri CHECK'te VARDI ama beyaz
		//    liste onu reddediyordu ve hicbir uc yoktu (olu tip).
		// ⚠️ `/polls/{id}` STATIK degil PARAMETRELI; `/chats/{chatID}/polls`
		//    ile ayni seviyede DEGIL — rota_test.go cozumlemeyi dogruluyor.
		r.Post("/chats/{chatID}/polls", chatH.AnketOlustur)
		r.Get("/polls/{id}", chatH.AnketGetir)
		r.Post("/polls/{id}/vote", chatH.AnketOyVer)
		r.Post("/polls/{id}/close", chatH.AnketKapat)
		// TURU 74 — MEDYA UCLARI (yalniz R2 yapilandirilmissa).
		// ⚠️ YAPMA: /media/ yolunu api.dart 401 muafiyet listesine EKLEME —
		//    bayat token bu uclarda oturumu SILMELI (turu 34-36 muafiyeti AYRI konu).
		if mediaH.Enabled() {
			r.Post("/media/upload", mediaH.Presign)
			r.Post("/media/{id}/commit", mediaH.Commit)
			r.Get("/media/{id}/url", mediaH.URL)
		}
		r.Post("/chats/{chatID}/read", chatH.MarkRead)
		// Aramalar (LiveKit)
		r.Get("/calls", callsH.History)
		r.Get("/calls/active", callsH.Active)      // calan arama var mi (uygulama on plana donunce)
		r.Get("/calls/{id}/status", callsH.Status) // arayan: aramam cevaplandi mi/bitti mi (kurtarma)
		r.Post("/calls", callsH.Start)
		r.Post("/calls/{id}/add", callsH.Add) // aktif aramaya kisi ekle (1:1 -> grup yukseltme)
		r.Post("/calls/{id}/answer", callsH.Answer)
		r.Post("/calls/{id}/end", callsH.End)
		r.Post("/calls/{id}/hold", callsH.Hold)            // test turu 18: beklet/geri al (karsi tarafa bilgi)
		r.Post("/calls/{id}/audio-stat", callsH.AudioStat) // CANLI eszamanli ses takibi (api log)
		// Odalar (Spaces — sesli oda; in-app, arama sisteminden BAGIMSIZ)
		r.Get("/rooms", roomsH.List)
		r.Post("/rooms", roomsH.Create)
		r.Get("/rooms/{id}", roomsH.Get)
		r.Post("/rooms/{id}/join", roomsH.Join)
		r.Post("/rooms/{id}/leave", roomsH.Leave)
		r.Post("/rooms/{id}/raise-hand", roomsH.RaiseHand)
		r.Post("/rooms/{id}/promote", roomsH.Promote)
		r.Post("/rooms/{id}/demote", roomsH.Demote)
		r.Post("/rooms/{id}/mute", roomsH.Mute)
		r.Post("/rooms/{id}/remove", roomsH.Remove)
		r.Post("/rooms/{id}/end", roomsH.End)
		r.Post("/rooms/{id}/invite", roomsH.Invite) // odaya davet (in-app bildirim)
		// Canli yayin (saf WebRTC; sinyaller LiveKit SendData'dan — WS hub kullanilmaz)
		r.Get("/streams", streamsH.List)
		r.Get("/streams/gifts", streamsH.Gifts)
		r.Post("/streams", streamsH.Start)
		r.Post("/streams/{id}/watch", streamsH.Watch)
		r.Post("/streams/{id}/heartbeat", streamsH.Heartbeat)
		r.Post("/streams/{id}/leave", streamsH.Leave)
		r.Post("/streams/{id}/end", streamsH.End)
		r.Post("/streams/{id}/chat", streamsH.Chat)
		r.Post("/streams/{id}/heart", streamsH.Heart)
		r.Post("/streams/{id}/gift", streamsH.Gift)
		r.Post("/streams/{id}/report", streamsH.Report)
		r.Post("/streams/{id}/kick", streamsH.Kick)
		r.Post("/streams/{id}/invite", streamsH.Invite) // yayina davet (in-app bildirim)
		// Konuk sistemi + listeler (Bolum 6)
		r.Get("/streams/{id}/viewers", streamsH.Viewers)
		r.Get("/streams/{id}/gifts", streamsH.GiftLeaderboard)
		r.Post("/streams/{id}/join-request", streamsH.JoinRequest)
		r.Get("/streams/{id}/join-requests", streamsH.JoinRequests)
		r.Post("/streams/{id}/guest/accept", streamsH.GuestAccept)
		r.Post("/streams/{id}/guest/decline", streamsH.GuestDecline)
		r.Post("/streams/{id}/guest/leave", streamsH.GuestLeave)
		r.Post("/streams/{id}/guest/remove", streamsH.GuestRemove)
		r.Post("/streams/{id}/guest/refresh", streamsH.GuestRefresh)
	})

	srv := &http.Server{Addr: ":" + cfg.Port, Handler: r}
	go func() {
		<-ctx.Done()
		srv.Shutdown(context.Background())
	}()

	log.Printf("gebzem api :%s (dev_mode=%v)", cfg.Port, cfg.DevMode)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
