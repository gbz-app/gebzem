# Gebzem Projesi — Claude Kuralları

WhatsApp + Twitter Spaces + TikTok Live karışımı sosyal uygulama. Hedef: ~50K kullanıcı, Türkiye pazarı. Domain: gebzem.app

## ZORUNLU KURALLAR (kullanıcı emri)
0. **BUILD ALMADAN ÖNCE SOR** (31 Tem emri) — kod hazır olsa bile derlemeyi/yayını
   kullanıcı "al" demeden başlatma. Kod yaz, analiz et, commit+push et, sonra SOR.
1. **Her oturumda `oturum.md` güncellenir** — yapılanlar, denenenler (oldu/olmadı), kararlar, devir notları. Oturum başında OKU, her önemli adımdan sonra GÜNCELLE (sadece oturum sonunda değil!).
2. **Bu dosya (CLAUDE.md) da güncel tutulur** — proje durumu/komutlar/uçlar değiştikçe.
3. **Her adımda git push** — her anlamlı değişiklik commit + push edilir; başarı `git rev-parse origin/main` karşılaştırmasıyla doğrulanır.
4. **Onaysız işlem yok** — kullanıcı "yap" demeden kurulum/silme/deploy yapma. Önce öner, onay gelince uygula.
5. **Kısa yaz** — uzun tablolar yok; net cevap + gereken aksiyon.
6. **`.env.infra` ve `backend/.env` ASLA git'e girmez** (.gitignore'da — değiştirme!)
7. Türkçe konuş.
8. **"Devam eden iş" izlenebilirliği (18 Tem):** aktif iş sürerken oturum.md'deki adım listesi
   ([ ]→[x]) HER ADIMDAN SONRA güncellenip push'lanır; aşağıdaki ŞU AN DEVAM EDEN İŞ bloğu da
   senkron tutulur. Amaç: pencere kapansa bile tam kalınan yerden devam edilebilmesi.

9. ⛔⛔⛔ **ARAYÜZ BİTMEDEN BACKEND'E GİRME** (21 Ağu emri — İKİNCİ ihlal).
   Kullanıcı: *"ben sana sadece HIZLI BİR ŞEKİLDE ARAYÜZ DEĞİŞİKLİĞİ
   yapmamız gerekiyor diyorum, sen beni dinlemiyorsun... bize SAATLER
   kaybettiriyorsun. Bundan sonra ARAYÜZ BİTMEDEN ASLA BACKEND'E GİRME."*

   **Arayüz turunda YASAK:** migration yazmak · `backend/` altında dosya
   değiştirmek · sunucuya deploy · `tools/uctan_uca.js` koşturmak ·
   muhafız testi yazıp bozarak kanıtlamak · piksel ölçüm betiği ·
   `oturum.md`/`CLAUDE.md` güncellemek.
   **Yapılacak:** kodu değiştir -> `flutter run` -> ekran görüntüsü -> "bak" de.

   ⚠️⚠️ **SUNUCUDA KARŞILIĞI OLMAYAN BİR FORM İSTENİRSE** (ör. *"kayıtta
   yaş, ilgi alanları, takım sor"*): arayüzü YAP, değeri EKRANDA TUT,
   sunucuya GÖNDERME ve bekleyen işi aşağıdaki listeye YAZ. Kullanıcı
   "arayüz bitti" deyince ya da build turunda TEK SEFERDE bağla.
   ⚠️ *"Ölü form olmasın"* diye migration AÇMA. O endişe doğru ama
      kullanıcının kararı **SIRALAMADIR**; ölü kalma riski LİSTEYE
      yazılarak kapatılır, sırayı bozarak değil.

   📌 **İHLAL KAYDI:** 15 Ağu (turu 96m) muhafız testi + bozma kanıtı ->
      *"emülatörü hızlı arayüz için yaptık, 1 saat oldu"*. 21 Ağu (turu 120)
      migration 049 + `internal/profil` + deploy + 390 e2e -> *"saatler
      kaybettiriyorsun"*. **Üçüncüsü olmayacak.**

## ŞU AN DEVAM EDEN İŞ (canlı — her adımda güncelle, iş bitince "YOK" yaz)
- **KALDIGIMIZ YER (3 Eyl 14:30): TURU 163b YAYINLANDI — SADECE iOS.**
  ios **33748924292** (**ab673a1**), R2 ipa=31141483 (md5 20a74a15),
  purge OK, **CDN BIREBIR**, iOS min 16.0, MapsApiKey ENJEKTE, debug imza YOK.
  ✅ **BACKEND DEPLOY** (ab673a1) + health ok.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260903-1430

- 🛡️ ⚠️⚠️⚠️ **TURU 163b — DENETIM: 89 AJAN, 76 HAM BULGU -> 45 AYAKTA,
  UC SEVK ENGELI (11 kok-neden · 7 yuksek).** Build ALINMISTI, denetim
  sonrasi YENIDEN alindi — *"Build ALMAK yayinlamak DEGILDIR"* dersinin
  **ONUNCU** dogrulanmasi.

- ⚠️⚠️⚠️ **(1) BAYAT SABIT TAVAN, TURU 162 FIXINI IPTAL EDIYORDU.**
  `_seferleriYenidenSec` hala duz `varis - suAn > kToplamSureTavani`
  (150) kullaniyordu. Yani zenginlestirmeden SONRA, mesafeye gore
  hesaplanan tavan SESSIZCE 150ye geri dusuyordu. Ovacik icin kapidan
  kapiya **198 dk** -> aday **BURADA** dusuyordu ve turu 162/163in
  duzeltmesi sahada **HIC gorunmezdi**.
  ⚠️ **DERS: bir esigi TEK KAYNAGA alirken TUM cagri yerlerini GREPLE.**
     Bu kopya iki fonksiyon otede sessizce hayatta kalmisti.

- ⚠️⚠️⚠️ **(2) SEKIL COKMESI 25 GUN ONBELLEKLENIYORDU.**
  Denetim canli sunucuda olctu: **54,62 km**lik bir hat snap sonrasi
  **0,00 km**ye dustu; makulluk kapisi **YALNIZ UST SINIRI** olctugu icin
  `oturtuldu=true` dondu ve sonuc **25 GUN** onbelleklendi. Kullanici o
  hattin cizgisini HIC goremez, yeniden denenmezdi bile.
  **FIX:** `sekilUzunlukTabani` (0,5) alt siniri.
  ⚠️ **DERS: bir "makulluk kapisi" tek yonlu olamaz** — yola oturtmak
     cizgiyi uzatabilir de KISALTABILIR de.

- ⚠️⚠️ **(3) BASARISIZLIK ONBELLEKLENMIYORDU -> HER CIZIMDE N GERCEK
  ROADS CAGRISI.** `guzergah()` aday dongusunun ICINDEN cagrildigi icin
  fail-open donen bir sekil TEK ARAMADA onlarca kez yeniden isteniyordu
  (denetim: *"9-40 kat carpan"*, *"72 seri HTTP istegi"*).
  **FIX:** sunucuda **6 saatlik** basarisizlik onbellegi + istemcide
  oturum omurlu ham-kod onbellegi.
  ⚠️ Bu ayni zamanda *"maliyet kullanici sayisiyla olcekleniyor"* bulgusunu
     da kapatir — `sekil.go` serhi TERSINI iddia ediyordu.

- 📌 **TURU 163b — DENETIMIN DOGRULADIGI / DUZELTTIGI ESKI NOTLAR:**
  · Turu 161in *"SEFER GERCEK, bozuk olan yalniz SEKIL"* hukmu **CURUDU**:
    olcum tam tersini gosterdi — sekil DOGRUYDU (o yuzden Cumakoyde
    bitiyor), bozuk olan **SEFERDI**. Turu 162de zaten oyle duzeltildi.
  · CLAUDE.mddeki *"KM58 165 dk"* YANLIS; olculen **179 dk** (tum hat) ve
    kullanicinin bindigi bacak **160/169 dk**.
  · KM58 yon-1 tarifesi **kaynakta bozuk**: sehir ici duraklar arasi
    **7-13 SANIYE**, kirsal kisim sisirilmis. Ayni koridor ters yonde
    **72 dk**. Yani varis saatleri yaklasiktir.
  · **Feed genelinde 136/765 (hat,yon) ciftinde ortalama hiz < 15 km/h**
    — ara durak saatleri buyuk olcude interpolasyon.

- ⏳ **TURU 163b — HENUZ YAPILMADI (denetimden devreden):**
  · **Parca ICINDEKI 489 adet >100 m bosluk**: Roads ~1 km arali ham
    noktalar arasini INTERPOLE ETMIYOR, 900 me varan yol disi kirisler
    kaliyor. Nobetci yalniz 643 DIKISE bakiyor.
  · **SEKER SOKAK 2 (41989)** koordinati 8,45 km yanlis; 3 hatta bagli,
    muhafiz yalnizca birini yakaladi.
  · **Mukerrer adli duraklar**: 6 cift >300 m, biri 25,6 km apart
    (kutu genislemesiyle YENI dogan belirsizlik).
  · **1,04 milyon polyline noktasi/arama** (kazanan insa dongusu).
  · **OSRM/Valhalla kendi sunucumuzda**: maliyet 0 USD ve 30 gunluk
    onbellek sinirI KALKAR (denetim fizibil buldu — AYRI TUR).
  · Vapur/tramvay ARAYUZDE hala otobus gibi ciziliyor.
- **KALDIGIMIZ YER (3 Eyl 14:00): TURU 163 YAYINLANDI — SADECE iOS.**
  ios **33746325377** (**c1e0101**), R2 ipa=31142198 (md5 bc186cf9)
  index=7967 surum.json=45, purge OK, **CDN BIREBIR**, iOS min **16.0**,
  `MapsApiKey` ENJEKTE, `get-task-allow: false`.
  IPA varliginda: **8.502 durak · 411 hat** · "Vapur" dizesi VAR.
  ⚠️ **BACKEND DEGISMEDI** (cdae708 canlida).
  ✅ analyze **0/0** · test **82/82**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260903-1400

- 🎯 ⚠️⚠️⚠️ **TURU 163 — "OVACIK BULUNMUYOR / PELITLIDE 2 OTOBUS":
  KOK NEDEN TEK SATIRDI (`adet: 12`).**
  Kullanici: *"ovacik dedigimde rota bulunmuyor"* + *"pelitliyi aradim,
  en yakinimdaki durakta 2 otobus yapiyor; bak yandex ALTTAKI DURAGA
  gonderip TEK SEFERDE goturuyor"*.
  `rotaAra` en yakin **12** duragi aliyordu.
  📊 **OLCULDU** (kullanicinin konumu, 800 m yaricap): **24 durak** var;
     kritik durak **GUZELLER OSB KAVSAGI 22. SIRADA** (692 m) ve **8 hat**
     tasiyor (423 · 430 · 510 · 515 · 510B · 515B · KM58 · PS-G1).
       Ovacik  : dogrudan rotalarin **1/1**i kayboluyordu -> "bulunamadi"
       Pelitli : dogrudan rotalarin **2/2**si kayboluyordu -> 2 otobus
  ⚠️⚠️ **SORUN MESAFE DEGIL SIRALAMA**: yakindaki duraklarin cogu AYNI
     birkac hatti tasiyor; hat cesitliligi 12. siradan SONRA geliyor.
     Yaricabi buyutmek COZMEZ — daha cok AYNI hattin duragini getirir.
  **FIX — `_hatCesitliDuraklar`:** her (hat,yon) icin **EN YAKIN** durak
  secilir (liste mesafe sirali oldugu icin ilk gorulen O hattin en
  yakinidir). En yakin **8** durak KOSULSUZ kalir (aktarma komsu
  duraklara bakiyor). Tavan durak sayisina degil **HAT CESITLILIGINE**
  bakar -> aday sayisi durak degil HAT sayisiyla olceklenir.
  📊 **300 rastgele cift:** dogrudan rota kapsamasi **%8,0 -> %21,0**
     (2,6 kat) · **GERILEME 0** · sure medyan 0 ms, maks 4 -> 16 ms.
  📊 **Kullanicinin iki vakasi (13:36):**
     Ovacik  **0 -> 1** rota (KM58, Guzeller OSB 14:31 -> varis 16:54)
     Pelitli **0 -> 2** rota (**423 TEK OTOBUSLE varis 14:52**) —
     Yandexin yaptiginin AYNISI.

- ⚠️⚠️ **TURU 163 — `kTestSaati` KAPATILDI (`null`).**
  Gece testi icin konulan bayrak uygulamayi **12:00da sabitliyordu**;
  kullanici 13:34te test ederken ekranda **12:32 varis** yaziyordu ve
  "sonraki otobus" hesabi TAMAMEN yanlisti. Nobetci hala gecerli:
  `grep -rn "GECICI-TEST" lib/`.

- ⚠️ **TURU 163 — SUREC: ARKA PLANDA KOSAN DENETIM AJANLARI DEPOYA
  YAZDI.** `.gotmp/bench/rss.dart` ve `mobile/test/zz_olcum_test.dart`
  bir commite YANLISLIKLA girdi. Ikisi de silindi, `.gotmp/`
  `.gitignore`a eklendi.
  ⚠️ **DERS: ajan kosarken `git add -A` yapmadan once `git status`e BAK.**

- **KALDIGIMIZ YER (3 Eyl): TURU 162 KODU BITTI, BACKEND DEPLOY (cdae708).**

- 🗺️ ⚠️⚠️⚠️ **TURU 162 — TUM KOCAELI** (kullanici emri: *"butun izmit
  kocaeli duragini verdim sana hepsini koymadin mi mahalle sokak sokak
  hepsi olmasi gerekiyor"*). Kullanici HAKLIYDI: ham GTFS 8.511 durak /
  418 hat tasiyor, biz **2.071 / 105** paketliyorduk (%75i disarida).
  Dogu siniri 29,60 oldugu icin **Izmit · Korfez · Derince · Kandira**
  TAMAMEN yoktu.
  📊 **BEDELI OLCULDU — NEREDEYSE BEDAVA:**

  | | durak | hat | sekil | gzip | JSON.parse | Roads/ay |
  |---|---|---|---|---|---|---|
  | eski | 2.071 | 105 | 202 | 0,34 MB | 9 ms | 845 |
  | **yeni** | **8.502** | **411** | **779** | **1,23 MB** | **17 ms** | **2.896** |

  Aktarma indeksi kurulumu **10,4 -> 43,7 ms**, komsu cifti
  **3.964 -> 16.492** (izgara sayesinde DOGRUSAL, kareli DEGIL).
  Roads ucretsiz kotasi 5.000 -> **aylik maliyet HALA 0 USD** (ustelik
  sekiller TALEP UZERINE cekiliyor).
  ⚠️ `KUTU` artik veri elemek icin DEGIL, yanlis koordinatli kayitlari
     (0,0 / baska il) disarida tutmak icin var.

- ⚠️⚠️⚠️ **TURU 162 — "OVACIKA GITMIYOR": BELEDIYE VERISINDE GERCEK HATA.**
  Kullanici: *"yandexte var K ile basliyor direk oraya giden otobusu
  gosteriyor ama sen CUMA KOYE giden otobusu gosteriyorsun"*.
  **KOK NEDEN ARAMA DEGIL VERI.** 423 hattinin sefer dizisi:

  | sira | saat | durak | sekle izdusum |
  |---|---|---|---|
  | 57 | 07:40 | 3326. SOKAK 1 | 11 m ✅ |
  | 58 | 07:41 | **OVACIK KOYU CIKIS 1** | **6.990 m** ❌ |
  | 59 | 07:43 | GAZI MUSTAFA KEMAL CD 5 | 4 m ✅ |

  1 dakikada 7 km = **436 km/h**. FIZIKSEL OLARAK IMKANSIZ — durak
  yanlislikla 423e atanmis. **423 Ovacika HIC GITMIYOR.**
  Ovacika giden GERCEK hat **KM58** (ULASIM PARK, 120 ugrama, kendi
  sekli Ovacika ULASIYOR) — Yandexteki "K ile baslayan" hat budur.
  **FIX — URETICIDE IKI KOSULLU MUHAFIZ** (`tools/ulasim_uret.js`):
  bir durak (hat,yon) atamasindan DUSER ancak **(1)** hattin KENDI
  sekline **500 m**den uzaksa **VE (2)** komsusuyla ima edilen hiz
  **90 km/h**i asiyorsa.
  📊 **OLCULDU: 40.887 atamanin 7si (%0,017)** dusuyor, yedisi de
     tartisilmaz (436-1.490 km/h): KM58/YAYLADERE (40,4 km) ·
     645/GAYRAN GULU (16,0) · 504/SEKER SOKAK 2 (7,2) · **423/OVACIK
     (6,99)** · KM55 (5,9) · 753 (5,6) · 797 (2,0).
  ⚠️⚠️ **IKI KOSUL DA GEREKLI**: yalniz hiz kosulu **394 sicrama /
     317 atama** isaretliyor ve cogu KABA SEKIL ya da ekspres bacak,
     yani YANLIS POZITIF olurdu. Yalniz sekil kosulu ise ciftin HANGI
     ucunun bozuk oldugunu SOYLEYEMEZ.
  ⚠️ YAPMA: esikleri gevsetme. 90 km/h zaten cok comert — kus ucusu
     ALT SINIRDIR, gercek yol daha uzundur.

- ⏱️ ⚠️⚠️ **TURU 162 — SURE TAVANI IKIYE BOLUNDU + MESAFEYE GORE.**
  Eski olcut `varis - suAn` idi, yani **ILK OTOBUSU BEKLEMEYI DE**
  sayiyordu. Koy hatlarinda (KM58 gunde **5 sefer**) bekleme tek basina
  2 saat -> rota, YOLCULUGUN KENDISI makul olmasina ragmen eleniyordu.
  **YENI:** `yolculuk <= clamp(kus_km * 12, 150, 300)` **VE**
  `bekleme <= 180`.
  📊 Kullanicinin 12:19 aramasi: tavan **182 dk**, yolculuk 152,
     bekleme 123 -> **KM58 Guzeller OSB 14:31 -> Ovacik 16:54**.
     **Yandexin gosterdigiyle BIREBIR AYNI** (Yandex de KM58/Guzeller
     OSB gosteriyordu). Yani rotamiz Yandexten KOTU degil — 12:19da
     dogru cevap ZATEN 510B->423 aktarmasiyla 12:50 idi.
  📊 300 rastgele cift: **gerileme 0**, kazanc +1, sure medyan 0 /
     maks 4 ms.
  ⚠️ Kural ASLA bugunkunden siki degil (clamp tabani 150) -> turu 157nin
     "984 dakikalik rota birinci sirada" hatasi GERI GELMEZ.

- 🚢 ⚠️⚠️⚠️ **TURU 162 — VERIDE DORT MOD VAR, HEPSINI OTOBUS SANIYORDUK.**
  `route_type` ZATEN varlikta tasiniyordu (`hatlar.json` -> `t`) ama
  istemci onu **HIC OKUMUYORDU**.
  📊 tramvay **3** (T1/T2/T3 Akcaray) · otobus **404** · **vapur 10**
     (IZMIT · GOLCUK · D.DERE · KARAMURSEL · DERINCE · TUTUNCIFTLIK ·
     HEREKE Iskele Hatlari) · funikuler **1** (Derbent-Kuzuyayla).
  Vapur sekilleri **2-7 nokta / 12-63 km**, yani korfezi gecen DUZ
  CIZGILER — bir feribot icin DOGRU. Biz onlari otobus diye cizip
  **yola oturtmaya** calisiyorduk; *"halen yoldan cikan shapeler var"*
  sikayetinin bir parcasi buydu.
  **FIX:** `UlasimModu` enum + `Hat.mod`; `guzergah()` yalniz
  `yolaOturur` modlari snap eder; adim metni otobus DISINDAKI modlarda
  modu YAZAR ("IZMIT (Vapur) ile gidin").
  ⚠️ **TRAMVAY BILEREK DISARIDA**: cadde uzerinde ama KENDI RAYINDA
     gider; en yakin yola oturtmak PARALEL serite kaydirabilir.
  ⚠️ Bilinmeyen `route_type` OTOBUS SAYILMAZ (sessizce yanlis cizmek
     yerine `bilinmiyor`).

- 🧵 ⚠️⚠️ **TURU 162 — DIKIS KESIMINDE GEOMETRIK EMNIYET AGI.**
  📊 CANLI OLCULDU (15 dikis, gercek Google cagrisi): turu 161in
     `originalIndex` kesimi **13 dikiste TAM 0,0 m** tutturuyor —
     mekanizma DOGRU. Ama 2 dikiste iki parca AYNI girdi noktasini
     FARKLI yollara oturtuyor (kavsak belirsizligi) ve kiris 18,5 /
     74,5 m cikiyor. Turu 161in 100 mlik nobetcisi o vakalarda **TUM
     sekli reddedip HAM cizgiye dusuruyordu** (30 seklin 2si).
  **FIX:** indeks kesimi BIRINCIL kalir; kiris tavani asarsa yeni
  parcanin BAS BOLGESINDE (`sekilAraPencere` 140) en yakin nokta aranir.
  📊 SONUC: fail-open **2/30 -> 0/30 (%100 basari)**, uzunluk sismesi
     medyan **+%0,7** (maks +%2,5), segment medyani **40-90 m -> 8 m**.
  ⚠️ **ARAMA PENCERESI ZORUNLU**: serbest birakilsaydi ilmekli hatlarda
     (sekillerin %17,3u) yolun ILERISINDEKI gecise kilitlenip guzergahin
     bir bolumunu TUMDEN atlardi — cift-cizimden DAHA KOTU.
  ⚠️ Onbellek oneki **v2 -> v3** (birlestirme mantigi degisti).

- ⚠️⚠️ **TURU 162 — OLCUM YONTEMI DERSLERI:**
  · **Gecerli cifti suzmeden oran hesaplama**: ilk olcumum TUM (i,j)
    durak ciftlerini sayip %48,6 gibi anlamsiz bir oran verdi —
    yarisi GECERSIZ (inis, binisten ONCE gelen durak).
  · **"En uzun segment" ham GTFSte yanlis metriktir** (kendi segmentleri
    4 kmye kadar cikiyor); uydurma baglayici BAS/SON segmentle olculur.
  · **Bir sikayetin kok nedenini VERIDE ara**: "Ovacika gitmiyor"un
    cevabi kodda degil, belediyenin `stop_times` dosyasindaydi.

- ⏳ **TURU 162 — DURUST SINIRLAR:**
  · **Tramvay/vapur/funikuler ARAYUZDE HALA OTOBUS GIBI CIZILIYOR**
    (yesil cizgi, otobus ikonu); yalniz adim METNI modu soyluyor.
    Renk/ikon ayrimi AYRI TUR.
  · **Marmaray/TCDD verisi YOK** — bu GTFS yalniz Kocaeli Buyuksehir
    (KentKart) hatlarini iceriyor.
  · `UlasimVeri.kTestSaati = 720` **HALA ACIK** (gece testi, kullanici
    emri). Nobetci: `grep -rn "GECICI-TEST" lib/`.
  · `otos/taksi/taksi_duraklar.json` repoda YOK; uretici artik o adimi
    ATLIYOR ve mevcut `taksi.json` KORUNUYOR (eskiden son adimda
    patlayip varliklarin yarisini yenilenmis birakiyordu).
- **KALDIGIMIZ YER (3 Eyl): TURU 161 KODU BITTI, BACKEND DEPLOY (81afa68),
  iOS BUILD ALINIYOR.**

- 🧵 ⚠️⚠️⚠️ **TURU 161 — "FAZLADAN CIZGILER": KOK NEDEN TURU 160IN KENDI
  BIRLESTIRME HATASIYDI.**
  Kullanici sekiz ekran goruntusu: *"rotalarda fazladan cizdiler var alakasiz...
  Bu fazladan cizgiler eski cizimlermi"*.
  ⚠️ **CEVAP: HAYIR, ESKI CIZIM DEGIL.** `_cizgiler()` her `build`de SIFIRDAN
     bir `Set` uretir, kimlikler deterministiktir ve `GoogleMap.polylines` tam
     kume degisimi yapar -> bayat polyline BIRIKEMEZ. Fazladan cizgiler
     **TEK polylinein nokta listesinin ICINDE**.
  **KOK NEDEN:** `sekil.go` sekli 100erlik parcalara **10 nokta ORTUSMEYLE**
  boluyor (`adim = 90`) ama birlestirme ortusmeyi ATMIYORDU.
  📊 **OLCULDU (202 gercek sekil):** **643 dikis**; dikis basina medyan
     **640 m** yol IKI KEZ cizilmis, aralarinda yolda karsiligi OLMAYAN bir
     **geri sicrama kirisi** (medyan **591 m**, min **70 m**, maks **10,3 km**).
     Toplam **521 km** (agin **%8,9**u). Sekil uzunlugu medyan **+%15,3**,
     maks **+%47**. Ekranda kiris/yol oranina gore UC belirti: halka + icinden
     DIAGONAL · IKIZ PARALEL cizgi · uzun INCE ILMEK.
  ⚠️⚠️ **TURU 160IN 1 mLIK DEDUP KAPISI FIILEN OLUYDU: 643 dikisin 0inda
     tetiklendi.** Kapi girdi ile cikti arasinda 1:1 nokta eslemesi
     varsayiyordu; **`interpolate=true` o varsayimi YIKIYOR**.
  ⚠️⚠️ **`sekilUzunlukTavani` (1,5) BU SINIFI GORMEZ**: 196 seklin **0**i
     takildi (en kotu sisme %47). Toplam uzunluk olcen bir kapi, yolun bir
     bolumunu IKI KEZ cizen bir hatayi YAPISAL OLARAK goremez — koruma degil
     **KOR NOKTA** olarak calisti.
  **FIX:** `originalIndex` OKUNUYOR ve ortusme **INDEKSLE** kesiliyor.
  ⚠️⚠️ Alan **`*int` OLMAK ZORUNDA**: interpolasyonla eklenen noktalarda HIC
     YOKTUR; duz `int` hepsini 0 yapar ve kesim her parcada 0a kilitlenir.
  ⚠️⚠️ Kesim **`== sekilOrtusme-1`** ile yapilir, `>= sekilOrtusme` ILE DEGIL:
     oyle alinirsa yerel 9 ile 10 arasindaki INTERPOLE noktalar da atilir ve
     orada tek parcalik **duz bir kiris** kalir.
  ⚠️ **ORTUSMEYI KALDIRMA** (`adim = sekilParca`): ortusme eslestiricinin
     dikis baglamini korumasi icin ZORUNLU.
  + **`sekilDikisTavani` (100 m) DIKIS NOBETCISI**: kesim calismazsa TUM
    islem basarisiz sayilir ve fail-open ile ORIJINAL sekil doner. Turu 160in
    hatasi tam da SESSIZ oldugu icin sahaya cikti.
    ⚠️ YAPMA: bu esigi "gercekci" bir sayiya (600 m) cikarma — nobetci susar.
  + **ONBELLEK ONEKI `v2`**: 25 gunluk onbellekteki BOZUK sekiller gecersiz;
    onek degismeseydi duzeltme sahada 25 gun boyunca HIC gorunmezdi.
    ⚠️ Birlestirme mantigi her degistiginde bu surum ARTIRILIR.
  ✅ **CANLI SUNUCUDA GERCEK GOOGLE CAGRISIYLA DOGRULANDI** (kullanicinin
     fotografladigi hatlar): 510B/y0 iki kez cizilen **1.908 m -> 0 m**,
     426/y0 **752 m -> 0 m**, 430 **0 m**, 510/y1 **321 m -> 0 m**.
     Uzunluk sismesi medyan **+%15,3 -> +%1,6**.

- 📐 ⚠️⚠️⚠️ **TURU 161 — DURAKTAN YOLA 90 DERECELIK CIKIS.**
  Kullanici (Yandex referansi): *"otobus duraklari icerden 90 derece dik
  cikip devam etmiyor"*.
  **KOK NEDEN:** `_enYakinIz` izdusum noktasini **ZATEN HESAPLIYORDU ama
  DISARI CIKARMIYORDU**; `_guzergahDilimi` elinde yalniz segment indeksi
  kaldigi icin duragi bir **SONRAKI KOSEYE** (`yol[a+1]`) bagliyordu -> cizgi
  duraktan cikip yola EGIK giriyor ve kayarak karisiyordu.
  📊 **OLCULDU (11.432 hat-yon x durak):** baglayici acisi medyan
     **44,7 -> 90,0 derece** · dik (>=70) **%18,8 -> %99,2** · yola kayarak
     giren (<30) **%28,6 -> %0,5**.
  ⚠️ **MUKERRER NOKTA KAPISI ZORUNLU**: `t` `clamp(0,1)` ile kirpilinca q tam
     bir KOSENIN uzerine duser (olculdu: **%4,9**) ve ayni nokta iki kez girer
     ya da dilim bir adim GERI gider. `kUcEsikM` (0,5 m) TEK KAYNAK —
     `_uclariBagla` da onu okur.
  ⚠️⚠️ **TERS DILIMDE UCLAR TAKASLANMAZ**: ters cevrilen yalniz KOSE
     SIRASIDIR; izdusumler kendi duraklarina bagli kalir. Her iki dalda da
     **q_a BASTA, q_b SONDA**. Yardimciya "uclari takasla" parametresi KOYMA.
  ⚠️ Izdusum **DERECE UZAYINDA** kurulur: `t` afin oldugu icin iki uzayda
     AYNIDIR; metrikte kurup `kx` ile geri cevirmek yuvarlama kaymasi uretir.
  ⏳ **DURUST SINIR:** dik cikisin boyu = izdusum mesafesi, **medyan 5,7 m**
     (p25 3,3 m). z18de ~12,6 dp (cizgi 8 dp) — **SINIRDA**; **z19da net**.

- ⚠️⚠️⚠️ **TURU 161 — UYDURMA BAGLAYICI: SEKIL DURAGI KAPSAMIYORSA O UC
  ARTIK CIZILMEZ.**
  Bu deligi **BU TURDA KOYLERI EKLERKEN KENDIM ACTIM**: `423`un GTFS sekli
  **Ovacika HIC ULASMIYOR** (durak seklin en kuzey noktasindan **6.989 m**
  uzakta) ama `stop_times` oraya **74 trip** ile gittigini soyluyor. Yani
  SEFER GERCEK, bozuk olan yalniz SEKIL. Dilimin sonuna **7.001 m** uzunlugunda
  uydurma bir baglayici ekleniyordu (y0da ise **19.264 m** duz cizgi).
  ⚠️⚠️ **TURU 158 MUHAFIZI BUNU YAPISAL OLARAK YAKALAYAMAZ**: kurtarma sarti
     `bG.uz * 3 < bIz.uz`; burada global izdusum de ayni degeri veriyor
     (`6989*3 < 6989` FALSE) -> kurtarma dalina HIC girilmiyor.
  ⚠️⚠️ **SEFER SILINMEZ, YALNIZ CIZGI KESILIR.** Cift elenirse Gebze merkez ->
     Ovacik icin dogrudan rota KALMIYOR (KM58 165 dk ile 150 dk tavanina
     takiliyor) ve turu 161de kullanicinin ACIKCA istedigi sey geri giderdi.
  ⚠️⚠️ **KAPSAM SORUSU `b <= a` DALINDA GLOBAL, NORMAL DALDA PENCERELIDIR.**
     `b <= a` dalinda pencereli olcu kullanilsaydi ILMEKLI hatlarda (sekillerin
     %17,3u ilmekli) SIRADAN vakalarda tetiklenir ve cizgi yanlis yerde
     kesilirdi. Normal dalda ise pencereli olcu DOGRUDUR: buyuk cikmasi
     "seklin ILERI kismi bu duragi icermiyor" demektir. `min()` ile
     yumusatmak OLCULDU: 2 km+ uydurma baglayici **%0,73te KALIYORDU**.
  📊 **OLCULDU (1.187.752 GECERLI durak cifti — sefer sutunuyla filtreli):**
     bas/son baglayici medyan **81 -> 8 m** · p95 **355 -> 32** · p99
     **1.106 -> 165** · 2 km+ uydurma **%0,791 -> %0,183** (4,3 kat az).
     Ornek: `315/y1 DOGA SOKAK 1 -> DUDAYEV PARKI` **16,99 km -> 0,05 km**.
  ⚠️⚠️ **OLCUM YONTEMI DERSI:** ilk olcumum TUM (i,j) ciftlerini sayiyordu ve
     %48,6 gibi anlamsiz bir oran veriyordu — ciftlerin YARISI GECERSIZ
     (inis, binisten ONCE gelen durak). Gecerlilik `_seferBul` olcutuyle
     (ayni sefer sutununda binis < inis) suzulmeli.
  ⚠️ **"EN UZUN SEGMENT" YANLIS METRIKTIR**: ham GTFSin KENDI segmentleri
     4 kmye kadar cikiyor. Uydurma baglayici **BAS/SON segmentle** olculur.

- 📍 **TURU 161 — AKTARMALI ROTADA IKINCI BACAGIN DURAKLARI ISARETSIZDI.**
  `_rotaUcIsaretleri` ilk otobus bacagindan sonra `break` ediyor ve marker
  kimlikleri SABITTI. Aktarmali sonuclarin **%64u 7 bacak** tasiyor -> ikinci
  hattin binis/inis duraklari **%100 gorunmuyordu**. Turu 155 bu deligi
  AKTARMASIZ rotalar icin kapatmisti; aktarmali hali ACIK kalmisti.
  ⚠️ `break` KALDIRMAK TEK BASINA YETMEZ: sabit kimlikle ikinci bacak
     birincinin USTUNE yazardi (marker `Set`i kimlikle tekiller).
  ⚠️ Aktarmalarin **%36si AYNI DURAKTA** -> `kUcPinTekilM` (5 m).

- ⏳ **TURU 161 — DURUST SINIRLAR:**
  · Kalan **%0,18** cift hala 2 km+ uydurma baglayici cizer (seklin ne ileri
    ne geri kisminda durak var); o vakalar icin "guzergah yaklasik" ibaresi
    HENUZ YOK (turu 158den devreden borc).
  · Dik cikis **z18de sinirda** gorunur; Yandexteki netlik **z19dan itibaren**.
  · `UlasimVeri.kTestSaati = 720` **HALA ACIK** (kullanici emri: gece test).
    ⚠️ Gercek yayin oncesi KALDIRILACAK; nobetci `grep -rn "GECICI-TEST" lib/`.
  · `tools/ulasim_uret.js` sefer kimligini ATIYOR -> `_seferBul` sutun
    eslestirmesi bacaklarin **%4,4**unde saati uydurabiliyor (AYRI TUR).
- **KALDIGIMIZ YER (2 Eyl): TURU 158 KODU BITTI — BUILD ALINMADI (kural 0).**
  Kullanici turu 157'yi gercek iPhone'da test etti, dort ekran goruntusu ve
  **alti sikayet** gonderdi. Arayuz/istemci turu: **BACKEND DEGISMEDI**,
  migration YOK, deploy YOK, e2e YOK.
  ✅ analyze **0 hata 0 uyari** · test **77/77** · gecici olcum dosyalari SILINDI.

- 🧮 **TURU 158 — EKRAN GORUNTUSUNDEN CIKAN CELISKI (turun basligi):**
  ayni bacak icin rota OZETI *"5 dk yuru"*, ADIM ekrani *"9 dk · 677 m kaldı"*
  (oran **~1,74**). Kok neden: `adres_servisi.yayaRotasi` sunucunun donen
  **`mesafe_m`/`sure_sn`** alanlarini ATIYORDU (yalniz `noktalar` okunuyordu);
  sunucu bunlari `yolbul/handler.go` FieldMask'te ZATEN donduruyor — duzeltme
  TAMAMEN ISTEMCIDE. (Turu 154-157 boyunca "durust sinir" diye tasinan borc.)

- ⚠️⚠️⚠️ **TURU 158 — YARIM FIX ACIKCA IMKANSIZ BIR PLAN URETIYORDU
  (denetim yakaladi, EN AGIR bulgu).**
  Yurume sayilari gerceklestikten sonra **sefer secimi ESKI kus ucusu
  tahmininde kaliyordu**: ekran *"9 dk yuru"* deyip **fiziksel olarak
  yetisilemeyecek** bir kalkis oneriyordu. Sessizce iyimser bir plan, ACIKCA
  imkansiz bir plana donusmustu.
  **FIX — `_seferleriYenidenSec`:** `SeferKaydi` ile kalkis sutunlari adayda
  tasinir; zenginlestirmeden SONRA sefer YENIDEN secilir, bekleme/otobus
  bacaklarinin `dakika` ve saat metinleri yeniden kurulur,
  `kToplamSureTavani` yeniden uygulanir, liste yeniden siralanir.
  ⚠️⚠️ **TAMAMEN YEREL — EK AG ISTEGI YOK** (turu 152 kota dersi: ucretli
     servisi DONGU ICINDEN cagirma). Aktarmalida zincirleme; olmuyorsa
     aday DUSER.
  ⚠️ **`sure_sn` KULLANILMIYOR**: `_bacakDakika` sureyi HER ZAMAN
     `kalanM / kYayaHizi` ile hesapliyor; Google'in hiz modeli alinsaydi ozet
     8, adim 9 der ve **celiski KAPANMAZDI**. `kYayaHizi` TEK KAYNAK kalir.
  ⚠️ `altBaslik` da gercek olcumden yazilir: *"390 m · yaklaşık"* ile *"9 dk"*
     ayni satirda birbirini yalanliyordu (ceil(390/1,3/60) = **5**).
  📊 OLCULDU (59 cift): kapsama **%96,6 KORUNDU** · **YETISEMEZ 0** ·
     **metre/dakika CELISKISI 0** · medyan 4 ms, maks 79 ms.

- ⚠️⚠️⚠️ **TURU 158 — YESIL DUZ CIZGI: TURU 155'IN FIX'I HATAYI TASIMISTI.**
  `_guzergahDilimi` dilimi kosulsuz `[binis, ...sublist(a+1, b+1), inis]`
  kuruyor ve **SON BAGLAYICININ UZUNLUGUNU HIC OLCMUYORDU**. `basSegment`
  sayesinde eski `b <= a` duz-cizgi dali artik neredeyse hic tetiklenmiyor;
  onun yerine dilimin **SONUNA kilometrelerce uydurma duz cizgi** ekleniyor.
  Ekranda tek duz cizgi degil, **makul guzergah + sonunda dev diagonal**.
  ⚠️⚠️ **TURU 155'IN "%4,10 -> ~0" SERHI YANILTICIYDI**: o sayi `b <= a`
     SAYACINI olcuyor, **cizginin dogrulugunu DEGIL**. Serh duzeltildi.
  **FIX:** `_enYakinIz` izdusum mesafesini de dondurur; zorlanan inis
  izdusumu **300 m**'den uzaksa global aramaya bakilir, global belirgin daha
  iyiyse ve sekil TERS yondeyse dilim `[bG..a]` alinip **TERS CEVRILIR**.
  ⚠️ `basSegment` KALDIRILMADI — iki koruma BIRLIKTE gerekir.
  📊 OLCULDU (3438 cift): izdusum >300 m **%0,99 -> %0,06** · p99
     **289 m -> 41 m** · maks **16.649 m -> 4.267 m** · 32 dilim ters cevrildi.

- ⚠️⚠️⚠️ **TURU 158 — OLCUM YONTEMI DERSI (UC ADIMDA IKI KEZ YANILDIM):**
  1. "Sekil eksik" sanildi -> **CURUDU**: 203 hat-yonun yalniz **1**'inde
     `yonSekil` girisi yok.
  2. Baglayici **KOSE** mesafesiyle olculdu -> %4,09 cikti ve arastirmanin
     onerdigi fix simule edilince **0 cift duzeldi**.
     ⚠️⚠️ Onerilen `bG > a` kosulu **YAPISAL OLARAK BOSTU**: `bG > a` ise `bG`
        zaten pencerenin ICINDE ve pencereli arama onu ZATEN buluyor.
  3. **IZDUSUM** ile olculunce tablo TERSINE dondu: kotu vaka **%1,05** ve
     bunlarin **%86,5'i duzeltilebilir** (global izdusum medyan **8 m**).
  ⚠️ **KURAL: egri bir cizgiye uzakligi KOSEDEN olcme, IZDUSUMDEN olc.**
     GTFS sekillerinde 400 m'yi asan segmentler var; durak yolun TAM USTUNDE
     olsa bile kose mesafesi buyuk cikar ve teshisi TERSINE cevirir.

- ⚠️⚠️ **TURU 158 — "SUREKLI YENIDEN DENE": CIFT KONUM ISTEGI (iOS TEK SLOT).**
  `initState` hem `_yukle()` hem (menuden Durak ile gelindiginde) `_durakAc()`
  ile **12 saniyelik IKI bagimsiz fix istegi** aciyordu. geolocator iOS'ta
  **TEK SLOTLU** sonuc isleyicisi tutar: ikinci istek birincinin blogunu EZER,
  birincinin future'i HIC tamamlanmaz ve 12 sn sonra hata seridi cikar.
  ⚠️⚠️ `konumIzni` ZATEN tek-ucus desenini kullaniyordu (`_izinIsi`), fix
     istegi kullanmiyordu — **ASIMETRININ KENDISI HATAYDI.**
  **FIX:** `_fixIsi` tek-ucus onbellegi.
  ⚠️⚠️ **`sessiz` PAYLASILAN GOVDEYE GIRMEZ**: govde yalniz SEBEBI dondurur,
     uyariyi **CAGRI YERI** gosterir; yoksa ilk cagiran `sessiz: true` ise
     gurultulu cagiran HICBIR SEY gormezdi.
  + `_yukle` artik `sessiz: true` — sebep panel seridinde ZATEN yaziliyordu,
    SnackBar MUKERRERDI ve rota ekraninin USTUNDE cikiyordu.

- ⚠️⚠️ **TURU 158 — ROTA SESSIZCE SILINIYORDU (iki bagimsiz yol):**
  · `_durakAc` konum icin 12 sn bekliyor; kullanici X ile ciktiktan SONRA
    ucustaki cagri tamamlanip `_durakModu = true` yazarak ekrani
    **KENDILIGINDEN GERI ACIYORDU** -> `_durakNesli` bayatlik kapisi.
    ⚠️ Turu 157 denetiminde bu iddia "curuk" sayilmisti; curutme yalnizca
       `_durakModu`nun await ONCESI acildigini gosteriyor, **IPTAL YOLUNU**
       hic degerlendirmiyordu.
  · `_rotaAra` ilk is olarak `_rota = null` yaziyordu; sonuc sayfasi
    `showDragHandle`li bir sheet ve kullanici SECIM YAPMADAN kapatirsa `_rota`
    null KALIYOR: cizgi ve ozet karti **MESAJSIZ** kayboluyor, geri getirme
    yolu YOK. Rota artik YALNIZ `rotaSec` icinde yazilir; `catch` de eklendi
    (arama patlarsa ne sheet aciliyordu ne mesaj).
  · `_durakYukleniyor` spinner'i **OLU KODDU**: `_durakPaneli` yalniz
    `_durakModu` true iken ciziliyor, o da bekleme boyunca false idi ->
    `_durakModu` await'ten ONCE acilir.

- ⚠️⚠️⚠️ **TURU 158 — "HAREKET ETMIYOR": DORT BAGIMSIZ KATKI.**
  1. **BEKLEMEDE IMLEC GERCEKTEN DONUYOR** (en gorunur mekanizma): bekleme
     bacaginin `noktalar`i BOS ve `ilerlet` iki noktadan az bacaklari ATLIYOR;
     imlec bekleme dilimini ANINDA gecip otobus diliminin basinda
     `aktifOran = 0` ile park ediyor ve beklemenin TAMAMI boyunca (ekran
     goruntusunde ~20 dk) kipirdamiyordu.
     FIX: `_imlecBacak`/`_imlecOran` — bekleme **SAATLE** ilerler (bekleme bir
     YER degil bir SURE; GPS ile olculemez).
     ⚠️ Kalkis dakikasi **METINDEN AYRISTIRILMAZ**, `varisDakika`dan sonraki
        bacaklarin sureleri cikarilarak turetilir -> bicimlendirmeden BAGIMSIZ.
     ⚠️⚠️ Yarim kalirdi: ekran YALNIZ GPS olayinda yeniden ciziliyor ve
        kullanici durakta DURUYORKEN (`distanceFilter: 5`) olay GELMEZ ->
        **30 sn'lik `_bekleTik`**; `_takipDurdur` ve `dispose` birakir.
  2. **KAMERA KAPISI YOKTU**: takip acikken `merkez` izdusume bagli ve her GPS
     duzeltmesinde degisiyor; kamerayi suren son dal `_takipKamera`yi HIC
     okumuyordu -> kullanici haritayi kaydirsa da kamera GERI ZIPLIYOR ve
     **"Merkeze dön" FIILEN ISLEVSIZ** kaliyordu. FIX: `kameraSerbest`.
  3. **KALAN MESAFE GERI BUYUYORDU**: `segment` monotondu ama `kalanM` HAM
     izdusumden geliyordu; segment ICINDE `t` geri gidince ekranin EN BUYUK
     sayisi yururken BUYUYOR ve imlec GERI kayiyordu. Dosyanin KENDI serhi
     *"cizilen kalan yol geri UZAMAZ"* diyordu, govdede koruma YOKTU.
     FIX: `TakipDurumu.t` (monoton oran); izdusum noktasi ve kalan mesafe
     ONDAN kurulur.
     ⚠️⚠️ Yalniz `kalanM`i kirpmak YETMEZ: `izEnlem/izBoylam` ham kalirsa
        **cizginin BASI** geri oynar ve "sayi sabit, cizgi geri gidiyor"
        seklinde YENI bir tutarsizlik dogar.
     ⚠️ **BACAK BITTI kapisi HAM `kalan` ile KALIR** (monotona baglanirsa
        bitis erken tetiklenir).
     📊 **BOZARAK KANITLANDI:** `tMono = iz.t` yapilinca 26 gercek guzergahta
        5278 GPS duzeltmesinin 7'sinde artis (**maks +77,6 m**), test KIRMIZI;
        duzeltmeyle **0**.
  4. **SILINMIS BACAKLAR GERI GELIYORDU**: GPS izni kaybi ya da ust uste ag
     hatasiyla takip YOL ORTASINDA durunca `takipBacak` null oluyor ve
     gecilmis her sey ANINDA tam renkle geri geliyordu — kullanici HALA
     yururken ("shape siliniyor mu" sorusunun ikinci yarisi). FIX: `_sonBacak`.
  + `rotaDisi` dalinda segment DONMUS ama izdusum GUNCEL oldugu icin cizgi
    **geri kiris** ciziyordu -> o dalda bacagin TAMAMI cizilir.
  + **ZOOM DUGMELERI takip kamerasini BIRAKMIYORDU** (programatik olduklari
    icin "elle kaydirdi" jesti tetiklenmiyor) -> yakinlastirma birkac saniyede
    SESSIZCE geri aliniyordu.

- 📌 **TURU 158 — CURUTULEN 8 (bir daha arastirilmasin):** `_enYakinSegment`
  izdusum noktalarinin atilmasi (gorsel sapma medyan 5 m) · GTFS sekillerinin
  kaba olmasi (>400 m segmentlerin **%94,8**'i yoldan <=50 m) ·
  `yonSekil[1 - yon]` ters yon yedegi (202/202 kendi seklini buluyor) ·
  `_uclariBagla`ya ust sinir koymak (hata yonu TERS) · `rotaSec`te pusula
  sizintisi (ULASILAMAZ) · `_dogrulukM`/`_yon`un setState disinda olmasi ·
  `_durakAc`ta `finally` eksikligi · "Tekrar dene" dugmesinin kendi hatasini
  yeniden uretmesi (o dugme durak/rota modunda HIC cizilmiyor).

- ⏳ **TURU 158 — DURUST SINIRLAR:**
  · ⚠️⚠️ **YURUME CIZGISININ YAPI ADASINI DOLANMASI KOD TARAFINDA
    COZULEMEZ.** Polyline cozucu, istek (`travelMode: WALK`,
    `polylineQuality: HIGH_QUALITY`, `routingPreference` VERILMIYOR) ve cizim
    (1:1, basitlestirme yok) UCU DE dogru; dolanan geometri **Google Routes'un
    KENDI ciktisi**. Kok neden VERI: Gebze'de **9.647 yolda 99 kaldirim, 40
    isaretli gecit** (turu 152 canli Overpass olcumu). Kullanicinin *"karsidan
    gecirip direk hedefe gitsin"* istegi **KARSILANAMAZ**.
  · **ELENMIS DAHA IYI BIR ADAY GERI GELEMEZ**: zenginlestirme kota nedeniyle
    yalniz KAZANANLAR icin kosuyor; kus ucusuyla elenmis bir aday gercekte
    daha iyi olabilir. "1 durak fazla asagida" sikayetinin kalan kismi budur.
  · **AKTARMA YURUMESI ZENGINLESTIRILMIYOR** (kota kapisi): erisim/varis
    yurumeleri GERCEK, aktarma yurumesi KUS UCUSU — ayni kartta iki olcum
    dili. En kotu eksik 2 dk, `kAktarmaTampon` da 2 dk: nominal olarak
    ortuluyor ama tamponun KENDI amaci (otobus 1 dk gec kalirsa aktarma
    kacmasin) icin kalan pay **SIFIR**.
    ⚠️ `kAktarmaYaricapM` ya da `kAktarmaTampon` degisirse bu hesap YENIDEN.
  · Kalan **%0,06** dilimde durak seklin uzerinde gercekten YOK; o vakalar
    icin "guzergah yaklasik" ibaresi henuz YOK.
  · **GERCEK BIR "DONMA" (freeze) ACIKLANAMADI**: iki aday da "geri donme /
    kaybolma"; ana is parcacigini kilitleyen bir donma BULUNAMADI. Sahada
    tekrarlarsa ayri teshis (1,7 MB'lik `seferler.json`un ilk cozumu ilk
    aktarma aramasinda ~200-400 ms donma yapabilir — **OLCULMEDI**).
  · **iOS TEK-SLOT MEKANIZMASI SAHADA DOGRULANMADI**: Dart tarafindaki cift
    cagri KESIN (kod okundu), eklenti ic davranisi ajan okumasina dayaniyor.
  · **KAMERA/IMLEC DUZELTMELERI EKRAN GORUNTUSUYLE KANITLANAMAZ** (iki goruntu
    ayni anin iki zoom'u); kod duzeyinde kanitlandi, **gercek cihazda yururken**
    dogrulanmali.

- **KALDIGIMIZ YER (2 Eyl 14:13): TURU 157 YAYINLANDI — SADECE iOS.**
  ios **33622413864** (**e82e5e7**), R2 ipa=30178205 (md5 6db8dabd)
  index=7967 (md5 47f8714e) surum.json=45 (md5 133b8c26),
  purge OK, **CDN UCU DE BIREBIR**, `get-task-allow: false`, profil ad hoc,
  `MapsApiKey` ENJEKTE, iOS min **16.0**.
  IPAda turu 157 dizeleri VAR: `Aktarma için yürüyün` (latin1) ·
  `Uygun rota bulunamadı` (utf16le) · `aktarmayla bile uygun bir ` (utf16le) ·
  ` aktarma` (utf8) · `Yakındaki taksi durağı` (utf16le) · `Hava durumu` (utf8);
  turu 156 dizeleri KALDI (`rota-kilif-` · `Merkeze dön` · ` kaldı`) ve
  KALDIRILANLAR YOK (`Aktarmalı rota henüz eklenmedi` ·
  `Aktarmasız hat bulunamadı`).
  ⚠️ Kontrol dizesi `Yakınımda` (utf16le) VAR — yontem dogrulandi.
  ⚠️⚠️ **BACKEND DEGISMEDI** -> deploy YOK, migration YOK, DB TRUNCATE
     EDILMEDI, e2e KOSULMADI (arayuz/istemci turu, kural 9).
  ⚠️ **APK ALINMADI** — R2deki apk turu 121 surumunde (21 Agu).
  ✅ analyze **0 hata 0 uyari** · test **77/77** · emulatorde
     (360 dp x yazi olcegi 1.3) tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260902-1413
- 🛡️ ⚠️⚠️⚠️ **TURU 157 — DENETIM: 44 AJAN, 36 HAM BULGU -> 16 ONAY,
  8 CURUTULDU.** Build ALINDI, **IPTAL EDILDI**, duzeltilip YENIDEN alindi —
  *"Build ALMAK yayinlamak DEGILDIR"* dersinin **DOKUZUNCU** dogrulanmasi.

- ⚠️⚠️⚠️ **TURU 157 — SEVK ENGELI: OZET KARTI AKTARMAYLA TASIYORDU.**
  OLCULDU (gercek Google Sans yuklu widget testi, kart ic genisligi 304 dp):
  tek rozetle **266,1 dp SIGIYOR**; ikinci rozet + ok ile **320,9 dp** ->
  **+16,9 dp tasma**, olcek 1.3'te **+79,3**.
  ⚠️⚠️ **KIRPAN SEY `RenderFlex` DEGIL** — o boyama `assert` blogunda ve
     release'te SILINIR. Kirpan **`Material(clipBehavior: Clip.antiAlias)`**.
     Sonuc: olcek 1.0'da **"Başla"nin 4,9 dp'si** kesiliyor, **olcek 1.3'te
     dugme TAMAMEN gorunmez** oluyordu = aktarmali rotayi baslatan TEK YOL.
  ⚠️ 411 dp test cihazinda SIGIYOR (turu 70b/90b/98c dersi).
  FIX: `Spacer` KALDIRILDI, metinler `Flexible`+`ellipsis`; rozet ve dugme
  SABIT kalir. + **"N aktarma"** etiketi (iki rozet + ok yalnizca IMA ediyordu).

- ⚠️⚠️⚠️ **TURU 157 — `_rotaOzetBoy` BACAK SATIRINI SABIT 15 dp SAYIYORDU.**
  OLCULDU: gercek **20 / 25 / 37 dp** (panel M3 `bodyMedium` **1,43** uyguluyor,
  metinler `height` vermiyordu). `.take(4)` kalkinca 7 bacakta ayrisma
  **35 / 70 / 154 dp**.
  ⚠️⚠️ Ayni ifadedeki `ust` ve `taksi` olcek TASIYORDU — **asimetrinin
     KENDISI hataydi.**
  IKI CANLI tuketici: `GoogleMap.padding` (varis ucu panelin ARKASINDA) ve
  `_havaSigar` (dugme panelin ALTINDA: hem gorunmez hem DOKUNULAMAZ).
  FIX: **`_ozetSatirBoy` TEK KAYNAK** + metinlere ACIK `height: 1.3`.
  ⚠️ YAPMA: bir yukseklik formulunde bazi terimleri olcekleyip bazilarini
     sabit birakma.

- ⚠️⚠️⚠️ **TURU 157 — `_seferBul` KAPISI VAAT ETTIGI KORUMAYI SAGLAMIYOR.**
  OLCULDU: kapi cift havuzunun **%0,12**'sini eliyor (eski serhteki sayi BUYDU
  ve YANILTICIYDI) ama **kapidan GECENLERIN %2,6**'sini hicbir gercek sefer
  saglamiyor; **secilen bacaklarin %4,4**'unde varis saati **UYDURMA** ve
  **hatalarin TAMAMI varisi ERKEN** gosterdigi icin o rota siralamada HAKSIZ
  YERE ONE gecer. Bacaklar cografi olarak GERCEK; yanlis olan yalnizca SAAT.
  ⚠️⚠️ **KOK NEDEN VARLIK URETICISINDE**: `tools/ulasim_uret.js` kalkislari
     durak basina AYRI siraliyor ve **sefer kimligini ATIYOR**.
  ⏳ Kalici cozum (`kalkislar` -> `[dakika, seferIndeksi]`) **AYRI TUR**;
     varlik yeniden uretimi + yeni surum ister.
  ⚠️ YAPMA: `_seferBul`a "ayni seferden mi" kontrolu eklemeye calisma —
     **mevcut varlik o bilgiyi TASIMIYOR.**

- ⚠️⚠️ **TURU 157 — VARIS TARAFINDAKI `.take(7)` SAF ZARARDI.**
  Gerekcesi KENDI ICINDE curuktu: serh *"kucultmek ic dongu maliyetini
  DUSURMEZ"* diyordu, yani kazanc olmadigini kendisi yaziyordu.
  OLCULDU (kaldirilinca): birinci sira kotulesmesi **%22,8 -> %4,0**,
  bos ekran **9 -> 1**, maliyet p99 **203 -> 192 ms** — DAHA IYI ve DAHA UCUZ.
  ⚠️ KALKIS tarafindaki tavan KALIR; asil maliyet orada.

- ⚠️⚠️ **TURU 157 — AKTARMA YURUMESI `noktalar: const []` IDI** ->
  haritada **0-150 m CIZGISIZ BOSLUK** (turu 157'yi baslatan *"kopmalar"*
  sikayetinin YENI ORNEGI) **ve** `ilerlet` bos bacaklari atladigi icin
  *"Aktarma icin yuruyun"* adimi takipte **HIC AKTIF OLMUYORDU**.
  Artik IKI GERCEK NOKTA; kota **`RotaBacagi.aktarmaYurumesi`** bayragiyla
  korunuyor (Routes cagrisi **6'da KALIR**).

- ⚠️⚠️ **TURU 157 — AKTARMA HAT CIFTI BASINA ILK BULUNANI KILITLIYORDU**,
  EN ERKEN VARANI degil (duraklar mesafeye gore sirali oldugu icin ilk bulunan
  EN YAKIN duraktir). OLCULDU: sonuclarin **%38-43**'unde en ustteki rota AYNI
  iki hatti kullanan daha erken varan bir yolculuktan **6-123 dakika** gec
  variyordu. Artik en-erken secilir; pahali insa donguden CIKTI (maliyet DUSTU).
  ⚠️ Anahtara **YON de girer** (ayni hattin iki yonu farkli yolculuktur).

- ⚠️⚠️ **TURU 157 — TAKIPTE BACAK DEGISINCE IZDUSUM ONCEKI BACAGA AITTI.**
  Turu 157 cizimi ve puck'i o alanlara bagladigi icin sonuc GORUNUR oldu:
  aktarmadan sonra 2. hat **0-175 m** kayik basliyor ve arasi binalarin
  ustunden DUZ cizgiyle geciliyordu (turu 155 gorunumunun AYNISI); puck da
  ~100 m geride goruluyordu. `rotaDisi` dalinda BAYAT nokta yayiliyordu.
  ⚠️ Kural: `bacak`, `segment` ve `iz` UCU DE AYNI bacaga ait olmali.

- ⚠️⚠️ **TURU 157 — TOPLAM SURE TAVANI YALNIZ AKTARMALIYA UYGULANIYORDU:**
  151 dakikalik aktarmali rota SESSIZCE atilirken **984 dakikalik (16 saat)**
  aktarmasiz bir rota *"en iyi secenek"* diye BIRINCI sirada gosteriliyordu.
  Tavan artik IKI dala da uygulanir (son olcumde en uzun rota **135 dk**).

- ⚠️⚠️ **TURU 157 — `_rotaAra` YENIDEN-GIRME KILIDI + IC DONGU KESITI.**
  Kilit yoktu: ikinci dokunus **IKI TAM ARAMA + UST USTE IKI sheet** acardi.
  Kesit onbellegi OLCULDU: **9.804.508 -> 69.114** islem, **234,5 -> 42,4 ms**,
  uretilen aday sayisi UC senaryoda da **BIREBIR AYNI** — yani hizlandirma,
  davranis degisikligi DEGIL.

- 📊 **TURU 157 — SON OLCUM (59 cift, hafta ici 12:00):** kapsama
  **%39,5 -> %96,6** · aktarma onerilen **46** · 15 km+ **4/4** · en uzun rota
  **135 dk** (tavan 150) · sure medyan **4 ms** / maks **115 ms**.
  20 aktarmali rotanin yapisi dogrulandi (7 bacak, iki AYRI hat, aktarma
  yurumesi IKI NOKTA ile CIZILEBILIR).

- 📌 **TURU 157 — CURUTULEN 8 (bir daha arastirilmasin):** rota secim karti
  aktarmayi gizliyor · `_durakYukleniyor` carki olu (IKI ayri iddia) · en dar
  dilim kesik desenini kaybediyor · ozet kartindaki puntolar olcek disi ·
  `_rotaTaksi` bayat kaliyor · `_durakAc`ta re-entrancy yok · `_durakAc`
  istisnaya karsi korumasiz.

- ⚠️⚠️⚠️ **TURU 157 — SUREC: KAYNAK KODDA TANIMLAYICI DEGISTIREN REGEX YAZMA.**
  `y` degiskenini niteleyen desen `"yürü"` dizesini **`"k.yürü"`** yapti
  (`ü` ASCII sinifi disinda oldugu icin sinir kontrolu TUTTU). `\p{L}`
  denemesi de JS dize kacisi yuzunden calismadi. **Blok ELLE yazildi.**
  ⚠️⚠️ **BU DOSYALAR KARISIK SATIR SONU TASIYOR** (ayni dosyada hem CRLF
     hem LF): yamalayici her cift icin ONCE CRLF sonra LF denemeli
     (turu 89/117/119'un DORDUNCU tekrari).
  ⚠️⚠️ **`dart format` KOSTURMA**: HEAD zaten format-temiz DEGIL; tek
     dosyayi formatlamak **2769 satir** alakasiz gurultu uretiyor.
- ⚠️⚠️⚠️ **TURU 157 — "KOPMA" NORMAL DEGILDI, KOKU CIZIM KODUYDU.**
  Kullanici: *"bazen boyle KOPMALAR yasanabiliyor bu normal mi"*.
  `_cizgiler` her karede `takip.yapistir(...)`i **ADSIZ** cagiriyordu, yani
  `basSegment: 0, pencere: 40`. Kardes `ilerlet` ise `basSegment:
  onceki.segment` geciyor. **OLCULDU: 202 GTFS sekli min 74 / medyan 314 /
  maks 924 nokta — HEPSI 40'i asiyor.** 40. segment gecilince cizim dogru
  segmenti arama penceresinde BULAMIYOR. Sekil 414301 (hat 430) sapmasi:
  segment 45 -> **877 m**, 150 -> **3.145 m**, 250 -> **4.581 m**.
  FIX: cizim IKINCI ARAMA YAPMAZ, `TakipDurumu`daki segment+izdusumu OKUR
  (`kalanYolNoktadan`).
  ⚠️⚠️ YAPMA: cizim tarafina `pencere: yol.length` kolu koyma — o
     pencere GPS MONOTONLUGU icin; acilirsa ilmekli hatlarda cizgi GERIYE
     SICRAR. YAPMA: iki dogruluk kaynagi birakma (yine ayrisirlar).

- ⚠️⚠️ **TURU 157 — PUCK ARTIK CIZGIYE YAPISTIRILIYOR** (Google/Yandex/
  Mapbox deseni). Ikinci bosluk buydu: cizgi izdusumden basliyor, puck HAM
  GPS'te kaliyordu; fark 60 m'ye kadar hos goruluyor = zoom 17'de **66 dp**.
  ⚠️⚠️ `rotaDisi` KAPISI ZORUNLU: o dalda `ilerlet` izdusumu ONCEKI
     durumdan tasiyor; kapisiz yapistirma rotadan cikmis kullaniciyi BAYAT
     bir noktada DONMUS gosterirdi — bosluktan DAHA KOTU.
  ⚠️ `_konum`un KENDISI degismez (yakin durak sorgulari ham GPS'te).

- ⚠️⚠️ **TURU 157 — IZIN YARISI: ANDROID AYNI ANDA TEK DIYALOG KABUL EDER.**
  `locationWhenInUse.request()` UC yerden cagriliyordu (onboarding ·
  `konumAl` · `konumAkisi`); ikinci istek diyalog gostermeden **SENKRON BOS
  SONUCLA** duser ve `isGranted` **false** doner. Ekran acilisi ile "Başla"
  yarisinca takip **daha baslamadan** *"konum izni gerekiyor"* deyip
  kapaniyordu — kullanici izni AZ ONCE VERMIS OLSA BILE.
  FIX: **`KonumServisi.konumIzni()` TEK KAPI** (ucustaki istek PAYLASILIR).
  ⚠️ Turu 85c CallKit izin carpismasinin BIREBIR tekrari.
  ⚠️ YAPMA: `request()`i cagri yerlerine geri dagitma.

- ⚠️⚠️ **TURU 157 — DURAK KISAYOLU %100 OLUYDU** (*"anasayfada duraga
  tikladigimda duraklar gelmiyor"*). `initState -> addPostFrameCallback ->
  `_durakAc()` **ILK KAREDE** kosuyor; `_konum` HENUZ null ve metot mesaj
  basip CIKIYORDU. Artik konumu BEKLIYOR (+cark).
  ⚠️ Turu 150'deki *"Nereye dugmesi hicbir sey yapmiyordu"* hatasinin
     AYNISI — o gun `_rotaPlanla` duzeltilmis, **`_durakAc` ATLANMISTI**.
  ⚠️ Harita merkezi yedegi BILEREK konmadi; sabit Gebze koordinati
     baska sehirdeki kullaniciya YANLIS liste gosterirdi (turu 140).

- ⚠️⚠️⚠️ **TURU 157 — `w800` EKRANDA HICBIR SEY YAPMIYOR.**
  `pubspec.yaml` Google Sans icin yalniz **400/500/600/700** yuzunu
  kaydediyor; Flutter w800'i sessizce **700**'e duşurur. Yani "kalinlik
  hiyerarsisi" diye yazilan sey FIILEN YOKTU.
  ⚠️ YAPMA: w800/w900 yazma — once fontu pubspec'e ekle.

- ⚠️⚠️⚠️ **TURU 157 — `SizedBox(height: N)` DOKUNMA HEDEFINI KIRPAR.**
  Adim karti dugmelerinin gercek render kutusu UC OLCEKTE DE **148x34 dp**
  cikti (Material 48'in %71'i). SDK koku: `ButtonStyleButton` govdeyi
  `_InputPadding` ile 48'e cikarmak ister ama `_RenderInputPadding
  ._computeSize` sonda `constraints.constrain(...)` cagirir; disaridaki
  TIGHT dikey kisit 48'i **34'e KIRPAR** — `tapTargetSize: padded` FIILEN
  ETKISIZ. Dugme boyu artik `kAdimDugmeBoy` (>=48, olcekle buyur).
  ⚠️⚠️ **`FittedBox` DUGMENIN TAMAMINI SARMAMALI**: "Merkeze dön"
     VARSAYILAN olcekte bile **0,708 kat** kuculup punto **9,2 dp** oluyordu
     ve kullanici yaziyi BUYUTTUKCE dugme KUCULUYORDU. Yalniz ETIKETI sar.

- ⚠️⚠️⚠️ **TURU 157 — `Color.lerp` ALFAYI DA KARISTIRIR.**
  Ilerleme cubugundaki *"acik yesil"*in koku: soluklastirma hedefi
  `onSurface.withValues(alpha: 0.16)` — yani **%16 SAYDAM**. Sonuc alfa
  lerp(1.00, 0.16, 0.45) = **0,62** ve renk beyaza dogru %45 -> pastel.
  Hemen ustundeki serh *"Alfa yerine notr griye KARISTIRMA"* diyordu ama
  **HEDEF RENGIN KENDISI SAYDAMDI**.
  ⚠️ YAPMA: `Color.lerp` hedefine saydam renk verme; OPAK zemin ver.

- ⚠️⚠️ **TURU 157 — CUBUK DILIMLERI: ESIT/ORANTILI KARISIMI (0,45/0,55).**
  Ham sure oraniyla [1,24,38,4] dagiliminda en dar dilim **3,6 dp** idi
  (tek kesik bile sigmiyor). Karisimin toplami **tam 1** oldugu icin
  yinelemeli kirpma ve sinir durumu YOK; siralama KORUNUR.
  ⚠️⚠️ AYNI liste HEM cizime HEM IMLECE gider (`_CubukCizer` serhi).
  ⚠️ DURUST SINIR: cubuk artik sureyle DOGRUSAL DEGIL; gercek sure
     cubugun HEMEN USTUNDE yaziyor.
  ⚠️ **BEKLEME kendi rengini aldi** (arduvaz): 24 dk bekleme 1 dk
     yurumeyle BIREBIR ayni dilde ciziliyordu.

- ⚠️⚠️ **TURU 157 — BEKLEME KARTINDA DURAK ADI IKI KEZ YAZIYORDU** ve bu
  RASTLANTI DEGILDI: `ilerlet` bos bacaklari (bekleme) HER ZAMAN atladigi
  icin `d.bacak` HICBIR ZAMAN bekleme bacagini gostermez -> `bu` daima
  false -> bu, o kartin **TEK davranisiydi**. Ucuncu satir artik HAT KIMLIGI.
  ⚠️ `rota_bul.dart`taki `altBaslik` DEGISTIRILMEDI (iki tuketicisi var).

- 📏 **TURU 157 — DURAK ADI KOSULLU IKI SATIR** (esik yazi olcegi **1.4**).
  OLCULDU (2032 ad, Google Sans 17, sutun ~229 dp): tek satirda kirpilan
  oran **%12,5 / %35,0 / %79,9**; iki satirda **%0,4 / %3,3 / %27,6**.
  ⚠️⚠️ KOSULSUZ ACILAMAZ: olcek 2.0'da 640 dp ekranda panel 463 dp'ye
     cikip haritaya yalniz **177 dp (%28)** birakiyordu.
  ⚠️ `_adimKartBoy` AYNI esigi okur (`kAdimIkiSatirEsigi`).
  ⚠️ "i/N" sayaci metnin sagindan IKON SUTUNUNA tasindi (metne SIFIR
     maliyet); KALDIRILMADI cunku `PageView` kaydirilabilir.

- 🔀 ⚠️⚠️⚠️ **TURU 157 — AKTARMALI ROTA** (kullanici emri).
  **OLCULDU (200 cift):** aktarmasiz motor **%39,5** cozuyordu ve mesafeyle
  COKUYORDU — 0-3 km %61 · 6-10 km %27 · 10-15 km %24 · **15 km+ %8**.
  **GERCEK KODDA OLCULDU (59 cift):** cozulen **%96,6** · 15 km+ **4/4** ·
  sure medyan **9 ms** / ort 24 / p95 92 / **maks 103 ms** · yapi 7 bacak,
  iki AYRI hat (440 -> 423), guzergah dilimleri 94 ve 318 nokta.
  ⚠️ Olcum MASAUSTU + JIT. **Gercek cihazda AOT ile TEKRAR OLCULMELI.**
  **ALGORITMA OLCULEREK SECILDI:** (a) kaba kuvvet ~687k islem/sorgu ->
  200 ms butcesine SIGMAZ · (b) hat-cifti kesisimi **HICBIR SEY ELEMIYOR**
  (hat ciftlerinin **%72,4**'unde zaten ortak aktarma noktasi var) —
  ⚠️ **bu secenegi bir daha arastirma** · (c) IKI TURLU (RAPTOR benzeri).
  **YENI INDEKSLER** (tembel, servis basina, acilista KURULMAZ):
  `hatDuraklari` · `durakHatIndeksi` · `komsuDuraklar` (IZGARA, 150 m).
  ⚠️ Yaricap **150 m OLCULDU**: 250/400 m kapsamaya HICBIR SEY
     EKLEMIYOR ama komsu cifti 3.880 -> 22.657. Aktarmalarin **%36'si AYNI
     DURAKTA**; yuruyerek aktarmada medyan 1 dk, maks 2 dk.
  ⚠️⚠️ **KOTA KORUNDU**: aktarma yurumesi icin Google Routes CAGRILMAZ;
     bacak `noktalar`i BOS oldugu icin `_yurumeleriZenginlestir` ona HIC
     ugramaz -> kota **6'da KALIR** (turu 152).
  ⚠️⚠️ Siralama: tek liste + **8 dk AKTARMA CEZASI**. Ayri bolum YOK —
     ciftlerin **%61'inde aktarmasiz cozum HIC YOK**, "Aktarmasız" basligi
     cogu aramada BOS kalirdi. Tekilleme anahtari **HAT ZINCIRI**
     (`hat.id` tek basina ilk hattin BUTUN aktarmalarini SESSIZCE elerdi).
  ⚠️ Toplam sure tavani **150 dk**; **IKI AKTARMA YAPILMADI** (kazanc
     en fazla ~%1, maliyet katlaniyor).

- ⚠️⚠️⚠️ **TURU 157 — SEFER SUTUNU `min(a.length, b.length)` GIZLI BIR
  VARSAYIMDI.** Iki duragin kalkis listelerinin **INDEKS INDEKS ayni seferi**
  gosterdigini varsayiyordu. **OLCULDU: 200 hat-yonun 8'i saglamiyor** ve
  fark TAM 2 KAT (ilmekli hatta ayni durak ayni seferde IKI KEZ geciliyor).
  Aktarmada IKI otobus bacagi oldugu icin maruziyet IKIYE KATLANIRDI.
  Artik uzunluklar ESIT DEGILSE cift **ATLANIR** (`_seferBul` TEK KAYNAK).

- ⚠️⚠️⚠️ **TURU 157 — `_yurumeleriZenginlestir` TRY/CATCH'SIZDI.**
  Serhi *"ozellik COKMEZ, yalnizca kabalasir"* diyordu ama govdede koruma
  YOKTU: `AdresServisi.i` firlatinca hata `Future.wait`e, oradan `rotaAra`ya
  cikip **TUM ARAMAYI dusuruyordu** — kullanici kabalasmis degil **HIC**
  sonuc gormuyordu. Olcum testinde yakalandi.
  ⚠️ **DERS (kacinci kez): serhin anlattigi kontrolun GOVDEDE gercekten
     olup olmadigini DOGRULA.**

- 🎨 **TURU 157 — AKTARMA ARAYUZU:** `_rotaOzeti`deki **`.take(4)` KALDIRILDI**
  (aktarmali rota **6 bacak %36 / 7 bacak %64**; son UC bacak SESSIZCE
  cizilmiyordu) · ozet basliginda HER otobus bacaginin rozeti + ok ·
  **IKINCI otobus bacagi TURKUAZ** (`#37B6C4`).
  ⚠️⚠️ Hattin KENDI rengi kullanilmadi — turu 156 gerekcesi (GTFS
     renkleri birbirine yakin camgobegi) AYNEN gecerli. Harita · cubuk ·
     adim karti ikonu AYNI ayrimi yapar (`_bacakRenkleri` TEK KAYNAK).
  ⚠️ `_rotaOzetBoy` bacak sayisindan TURETILIR (eskiden `4 * 15` SABIT).

- 🌤️ **TURU 157 — HAVA DUGMESI ("-" altinda) + 🚕 TAKSI KARTI.**
  ⚠️⚠️ Hava **ORNEK** ve deger DUGMEDE YAZMAZ: haritada isaretsiz ciplak
     bir "24°" menudeki seritten DAHA TEHLIKELI (harita katmani gibi okunur).
     51 dp kare kutuya "Örnek" SIGMAZ -> YALNIZ IKON, durustluk cumlesi
     SHEET'te; `kHavaDovizOnizleme` kapisinda.
  ⚠️⚠️ **CAKISMA KAPISI** (`_panelBoy` tabanli): dugme sutunu UST-CAPALI
     ve panelin ALTINDA cizilir; dorduncu dugmenin alt kenari 266 dp,
     360x640'ta panel ust kenari 249 dp -> **17 dp ortusme** (jest
     gezinmede ~41 dp) ve orasi hem gorunmez hem DOKUNULAMAZ olurdu.
  ⚠️⚠️ **TAKSIDE TELEFON NUMARASI VERIDE YOK** (53/53 olculdu) -> kart
     *"Taksi cagir"* DEMEZ, **"Yakındaki taksi durağı"** der, "Ara" CIZILMEZ.
  ⚠️ `yakinTaksiler` YARICAP ELEMIYOR -> **5 km kapisi ZORUNLU**, yoksa
     "yakininda taksi var" YALANI uretir.
  ⚠️ Olcut TOPLAM yurume (rotada TANIM GEREGI iki yurume bacagi var).
  ⏳ DURUST SINIR: `metre` KUS UCUSU -> 2 km esigi gercekte ~2,4-2,8 km'de
     tetikler (GEC, guvenli taraf).

- ⚠️⚠️⚠️ **TURU 157 — SUREC: BU REPODA `dart format` KOSTURMA.**
  Yamalardan sonra `dart format --line-length 80` kosuldu ve diff **3346
  satira** cikti. OLCULDU: **HEAD ZATEN format-temiz DEGIL** (bozulmamis
  HEAD dosyasi formatlaninca **2769 satir** degisiyor). Dosya `git checkout`
  ile geri alinip yamalar formatlanmadan tekrar oynatildi -> diff **696/103**.
  ⚠️ Tek dosyayi formatlamak incelenemez bir diff uretir.

- ⏳ **TURU 157 — DURUST SINIRLAR (devir):**
  · **Adim karti ve rota ozeti EMULATORDE GORULEMEDI** (o ekranlar GPS fix'i
    ve secili rota istiyor; emulatore fix HIC gelmiyor). Tasma 0 olcumu
    YALNIZCA ulasilabilen ekranlar icin gecerli.
  · **Yurume ucu ile durak arasindaki boslugun KESIN koku KANITLANMADI.**
    Geometri saglam olculdu (azami ~5 m). En guclu aciklama: veride
    **20,3 m arayla AYNI ADLI IKI durak** var ve cevredeki 25 durak takipte
    ekranda kalip binis duragiyla AYNI mavi pinle ciziliyor. Gercek cihazda
    bosluk hala goruluyorsa sebep BASKA yerdedir.
  · Aktarma suresi **masaustu + JIT**; cihazda AOT ile tekrar olculmeli.
  · **Yurume mesafesi/suresi HALA kus ucusu**: sunucu `mesafe_m`/`sure_sn`
    donduruyor, istemci yalniz `noktalar`i okuyup ATIYOR (turu 155'ten devir).
  · Hava durumu GERCEK DEGIL (tablo/uc/anahtar YOK) — AYRI IS.
  · **Menudeki "Taksi" kisayolu HALA `kategori: 'hizmet'` aciyor** (gercek
    duraklari degil). Turu 150'de "Durak" icin duzeltilen ayni hata.
  · Olcek 2.0'da durak adlarinin ~%67'si kirpilmaya DEVAM eder.
  · Kalan ~%1,5 rota cozulmez; ciftlerin ~%5,5'inde 800 m icinde HIC durak yok.
- **KALDIGIMIZ YER (2 Eyl 11:01): TURU 156 YAYINLANDI — SADECE iOS.**
  ios **33605554396** (**dd1bdf3**), R2 ipa=30154150 (md5 1dac6c94)
  index=7967 (md5 fd1aa734) surum.json=45 (md5 75eb2f45),
  purge OK, **CDN UCU DE BIREBIR**.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **77/77** · emulatorde tasma **0**.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260902-1101

- 🎨 **TURU 156 — CIZGIYE KILIF (border)** (kullanici: *"yurume adim shape
  ARKASINDA RENK var, BORDERLAR var"*).
  ⚠️⚠️ **`Polyline`de `strokeColor` YOKTUR** (paket kaynagindan: yalniz
     `color`, `width`, `patterns`). Cerceve ancak **IKI POLYLINE** ile olur:
     altta genis+koyu kilif, ustte dar+renkli cizgi.
  ⚠️⚠️ **KILIF DUZ, USTTEKI KESIK**: kesiklerin ARASI koyu bant olarak
     gorunur. Kilif da kesik olsaydi aralar HARITA ZEMINI kalir ve
     "arkasinda renk var" tarifi KARSILANMAZDI.
  ⚠️⚠️ **zIndex SIRASI KRITIK**: TUM kiliflar TUM cizgilerin ALTINDA
     (kilif 1/2, cizgi 3/4). Bacaklar durakta birlestigi icin bir bacagin
     kilifi otekinin CIZGISINI ortebilirdi.

- ⚠️⚠️⚠️ **TURU 156 — "SIKLASTIRDIM" YANILGISI (denetim yakaladi).**
  Ilk deneme 18/10 -> 9/5: periyot 28 dp'den 14 dp'ye indi (**siklik iki
  kat**) ama **IKI SAYI DA yariya bolundugu icin ORAN 1,80'de AYNEN KALDI**.
  Kullanicinin sikayeti ise SEKILLE ilgiliydi (*"dolu ile bosluk neredeyse
  esit"*). FIX: **8/6 = 1,33**, periyot 14 dp'de KALIR.
  ⚠️ **DERS: dash ve gap'i AYNI ORANDA bolmek ORANI DEGISTIRMEZ.**

- 🚌 **TURU 156 — OTOBUS CIZGISI YESIL + AYAK IZI KUSURU.**
  Kullanici: *"otobus shape YESIL olsun, hafif kapali, hafif SIYAH BORDER,
  yolu TAM KAVRASIN TASMASIN"*.
  · Renk: hattin kendi rengi -> **`kOtobusRengi` #2FA85C** (mat yesil).
    ⚠️ Hat kimligi KAYBOLMADI: rozet hala hattin KENDI renginde. Gebze GTFS
       renklerinin cogu birbirine yakin camgobegi.
  ⚠️⚠️ **AYAK IZI KUSURU (denetim yakaladi):** kilifli toplam genislik
     `taban + 2*kKilifPay` = 7+2 = **9 dp** idi — turu 150'deki KILIFSIZ ve
     SIKAYET EDILEN cizgi de 9 dp. Yani sorun GORSEL OLARAK geri gelmisti.
     FIX: `kOtobusEn` 7 -> **6** (toplam 8 dp).
  ⚠️ Dogru kol `kKilifPay` DEGIL: **`Polyline.width` bir `int`**, ara deger
     YOK — en ince kilif +2 dp.
  ⚠️ OLCULDU: 12 m'lik yerel yol z16'da ~6,6 dp, z17'de ~13,3 dp.
  ⏳ **DURUST SINIR:** yol genisligi zoom'la DEGISIR, `width` SABIT —
     "tam kavrama" hicbir sabit degerde her zoom'da saglanamaz.

- 🧭 **TURU 156 — ADIM EKRANI REFERANS DUZENE GECTI** (kullanici: *"step
  adimini BOYLE yapmaliyiz"*).
  · **Baslik ortali IKI satir**: buyuk "5 dk · 373 m kaldı" (BU BACAGIN
    kalani) + soluk "Tüm rota: 8 dk · 07:29".
    ⚠️⚠️ **`FittedBox(scaleDown)` ZORUNLU — OLCULDU:** kart ic genisligi
       360 dp ekranda **304 dp**; "7 dk · 620 m kaldı" yazi olcegi 2.0'da
       **~306 dp** ister -> TASAR. `Expanded` ortalamak icin kalkinca
       ellipsis korumasi da gitmisti. `ellipsis` DEGIL `scaleDown`:
       ekranin EN ONEMLI sayisi kirpilamaz.
    ⚠️ `CrossAxisAlignment.stretch` ZORUNLU: `start` olsaydi metinler kendi
       genisliklerine buzulur ve `textAlign: center` HICBIR SEY YAPMAZDI.
  · **Ilerleme cubugu `CustomPainter`a gecti** (`_CubukCizer`): yurume
    KESIK, otobus DUZ, bacak sinirlarinda DURAK DAIRESI, solda beyaz halkali
    KIRMIZI IMLEC, sonda hat rozeti.
    ⚠️⚠️ Onceki `Row + Expanded + ColoredBox` yapisi imlec TASIYAMAZ: her
       dilim kendi `Expanded` kutusuna hapsedilmis, sinir gecemez.
    ⚠️⚠️⚠️ **YENI 0-BOYUT TUZAGI**: cocuksuz `CustomPaint`in varsayilan
       `size`i **`Size.zero`** ve `Row`un dikey kisiti GEVSEK gelir -> cubuk
       0 yukseklige duser ve **HIC CIZILMEZ**. **`size: Size.infinite`**
       ZORUNLU. (turu 136'nin "cocuksuz `ColoredBox` `constraints.smallest`
       alir" tuzaginin BASKA BIR WIDGET'taki ayni sinifi.)
    ⚠️ Imlec: bacaklar ARASI konum **SURE** ile (dilimlerle AYNI agirlik
       listesinden), bacak ICI ilerleme **MESAFE** ile (`_bacakOrani`).
       Ayrisirlarsa imlec bacak sinirlarini YANLIS yerde gecerdi.
    ⚠️ `shouldRepaint` listeleri **`listEquals`** ile karsilastirir: listeler
       her `build`de sifirdan uretiliyor, `!=` DAIMA true doner. (Turu 62'de
       TERSI yasandi: `_DalgaCizer` yerinde buyuyen ayni listeyi tuttugu icin
       karsilastirma daima false donuyor ve canli dalga HIC cizilmiyordu.)
    ⚠️ Eski `_dilim`/`_eskiIlerlemeCubugu` SILINMEDI (`unused_element`): bu
       dosyada ayni sinif silme BES kez komsu uyeyi de goturdu.
    ⚠️ Cubuktaki kesik olculeri (10/5) HARITADAKI desenden (8/6) **AYRI**
       sabitler: cubuk ~300 dp, harita metrelerce. Ayni sayilar kullanilsaydi
       cubuk NOKTA DIZISI olurdu (emulatorde goruldu).
    ⚠️ Gecilmemis dilimler **BACAGIN KENDI RENGINDE** (notr griye %45
       karistirilmis) cizilir; notr gri cizildiginde cubuk bastan sona ayni
       renkte durup yurume/otobus ayrimi KAYBOLUYORDU.
  · **Adim satiri: raduslu KARE ikon kutusu + eylem/yer sirasi DUZELDI.**
    Bugune kadar TERSTI (ust satir buyuk EYLEM, alt satir kucuk). Referansta
    ust KUCUK eylem, alt BUYUK yer adi.
    `RotaBacagi`ya **`eylem`** ve **`yer`** eklendi; `baslik`/`altBaslik`
    DOKUNULMADI (iki tuketicileri daha var).
    ⚠️ `_yurumeleriZenginlestir` yeni alanlari da KOPYALIYOR — unutulsaydi
       tam da kullanicinin gordugu yurume adimlarinda eylem/yer BOS kalirdi.
    ⚠️ `rotaAra`ya `varisAd` eklendi: varis ADI ekranda vardi ama fonksiyona
       GECMIYORDU.

- ⚠️⚠️ **TURU 156 — `startCap`/`endCap` iOS'TA HICBIR SEY YAPMIYOR.**
  Paket kaynagindan dogrulandi (google_maps_flutter_ios 2.18.4): pigeon
  mesajinda **cap alanlari HIC YOK**; `jointType` gonderiliyor ama
  `FGMPolylineController.m` govdesinde UYGULANMIYOR. Android'de ucu de
  GERCEK ve **ZORUNLU** (kilifa `buttCap` verilseydi ustteki cizginin
  yuvarlak ucu kilifin DISINA tasardi; `jointType` varsayilani `mitered`,
  keskin donuslerde miter SIVRISI firlardi).
  ⚠️ YAPMA: iOS'ta calismiyor diye bu satirlari silme.

- 🔎 **TURU 156 — FIZIBILITE (kullanici sordu, HICBIRI UYGULANMADI):**
  · **"Sokak/bina goster-gizle mumkun mu?"** ⚠️⚠️ **`buildingsEnabled`
    ANDROID'DE SESSIZ NO-OP** (kaynaktan dogrulandi):
    `GoogleMapController.java:829-831` yalnizca alani sakliyor, haritaya
    SADECE `onMapReady`de bir kez uygulaniyor (:207); kardesi
    `setTrafficEnabled` ise `googleMap`i cagiriyor (:826). Yani dugme
    iPhone'da calisir, **Android'de HICBIR SEY YAPMAZ** — derleme temiz,
    log yok. Cift platform tek yol **stil JSON'u**, o da
    `harita_stili_test.dart` muhafiziyla CAKISIYOR. Yapilabilir ama muhafiz
    IKIYE bolunmeli: kalici stiller SIKI kalir, **kullanicinin acip
    kapattigi** katman stilleri ayri kurala girer.
  · **3B/egim**: `CameraPosition.tilt` ile mumkun, canli degisir. ⚠️ Ust
    sinir ZOOM'A BAGLI ve asan deger SESSIZCE kirpilir. Ama bu turu
    150'deki **"kus bakisi"** kararini GERI ALMAK demek.
  · **Katman dugmesi (uydu/trafik)**: `mapType` ve `trafficEnabled` iki
    platformda da CANLI calisir, muhafizla CAKISMAZ, ucuz. ⚠️ Uyduya
    gecilince ozel stil Google tarafindan YOK SAYILIR (yalniz `normal`).
  · **Hava durumu ikonu**: konulabilir ama ⚠️ **VERI GERCEK DEGIL** —
    projede hicbir hava servisi/ucu/anahtari YOK; `'24°'` koda gomulu sabit
    ve kaynagin kendi serhi *"DEGERLER ORNEKTIR"* diyor. "Örnek" etiketi
    ZORUNLU olur; gercek veri AYRI TUR.
  📌 Yeni dugme maliyeti ucuz (`_haritaDugmesi` tek kaynak) ama OLCULDU:
     dorduncu dugme 360x640'ta yakinimda panelinde ~9 dp payla SINIRDA.

- ⏳ **TURU 156 — DURUST SINIRLAR:**
  · Harita karolari emulatorde cizilmiyor: **kilif, kesik orani ve yesil
    otobus cizgisi GERCEK CIHAZDA gorulecek.**
  · Yurume mesafe/suresi HALA kus ucusu tahmininden (turu 155'ten devrediyor;
    sunucu `mesafe_m`/`sure_sn` donduruyor, istemci ATIYOR).
- **KALDIGIMIZ YER (2 Eyl 09:30): TURU 155 YAYINLANDI — SADECE iOS.**
  ios **33598386941** (**0b87b96**), R2 ipa=30150502 (md5 c2cc198a)
  index=7967 (md5 fb99fd50) surum.json=45 (md5 3b0ee958),
  purge OK, **CDN UCU DE BIREBIR**, `get-task-allow: false`, profil ad hoc,
  `MapsApiKey` ENJEKTE, `NSLocationWhenInUse` VAR.
  IPA'da turu 155 dizeleri VAR: `landscape.man_made` ·
  `landscape.natural.landcover` · `konum-yon` · `konum-dogruluk` ·
  `rota-varis` · `rota-binis` · `rota-inis`; kontrol dizesi "Yakınımda"
  (utf16le) VAR. iOS pusula ikilide: `GebzemPusula` · `startUpdatingHeading`
  · `magneticHeading`.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **77/77** · emulatorde tasma **0**.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260902-0930

- 🗺️ **TURU 155 — HARITA ZEMINI YESILDI** (kullanici: *"yaklastikca haritada
  boyle yesilimsi bir renk oluyor"*, ekran goruntusu gonderdi).
  ⚠️⚠️ **KOK NEDEN:** `landscape.natural` Google stil semasinda YALNIZ
     parklari degil **YAPILASMAMIS HER ZEMINI** kapsar (`landcover` +
     `terrain` alt turleri rengi MIRAS ALIR). Sehir olceginde ustunu
     `landscape.man_made` karolari ortuyordu ve hata GORUNMUYORDU;
     **yakinlastikca** man_made seyrelince altindaki yesil ekrani kapliyordu.
  FIX: landscape/natural/landcover/terrain **zemin rengine** cekildi,
  `landscape.man_made` ACIKCA tanimlandi.
  ⚠️ **YESIL ARTIK YALNIZ `poi.park`** (Yandex referansinda da parklar yesil).
     `#26402f` IPA'da hala var — o **park** rengi, zemin degil.
  ⚠️ YAPMA: `landscape` ya da `landscape.natural` altina yesil renk koyma.

- 📏 **TURU 155 — KESIK DESEN: IKI AYRI KOK NEDEN.**
  Kullanici: *"Yandexte kesik cizgiler yaklassam da uzaklassam da AYNI"*.
  · **iOS**: desen YALNIZ `onCameraIdle`de ve yalniz **0.4 zoom** farkinda
    guncelleniyordu = **%32 olcek hatasi**; parmak ekrandayken HIC
    guncellenmiyor, kalkinca ANIDEN yerine oturuyordu.
    FIX: `onCameraMove` zoom'u BEDAVA verir (`p.zoom`); esik
    **`kZoomEsigi = 0.15`** (%11) ve **YALNIZ iOS**'ta `setState`.
  · **Android**: ⚠️⚠️ eklenti kaynagindan DOGRULANDI
    (`PolylineController.java`): `setWidth(width * density)` ama
    `setPattern(pattern)` **density'siz**. 3x telefonda cizgi 15 px dogru
    cizilirken kesik **18 FIZIKSEL PIKSEL = 6 dp**: cizgiye gore UC KAT
    kisa, uzaktan neredeyse DUZ. FIX: dash/gap `devicePixelRatio` ile carpilir.
  ⚠️ Birim farki kaynaktan: Android `Convert.java` -> `new Dash(length)` =
     **PIKSEL**; iOS `FGMPolylineController.m` -> `GMSStyleSpans(...,
     kGMSLengthRhumb)` = **METRE**.

- 🧭 **TURU 155 — YURUME SHAPE'I: GOOGLE UCLARI YOLA SNAP EDIYOR.**
  Kullanici: *"rota cizdiginde mesela EVDEN DISARIYA shape cizmiyor"* +
  *"Yandex'te kesikler TAM YOLUN ICINDE"*.
  ⚠️⚠️ Donen polyline kullanicinin GERCEK koordinatindan degil ona en yakin
     YOL noktasindan baslar, duragin da tam ustunde bitmez. O bosluklarda
     hicbir sey cizilmedigi icin cizgi "evden cikmiyor", duraga "degmiyor".
  FIX: **`_uclariBagla`** — gercek baslangic/varis 5 m'den uzaksa cizginin
  basina/sonuna geri konur (Yandex ve Google Maps de boyle yapar).
  ⚠️ Otobus bacaginda GEREKMEZ: `_guzergahDilimi` duraklari ZATEN basa/sona
     koyuyor.
  ⚠️ 5 m esigi ZORUNLU: Google zaten uca oturmussa ayni nokta IKI KEZ girer.

- 🔁 **TURU 155 — ILMEKLI HATLARDA OTOBUS CIZGISI DUZ GIDIYORDU.**
  Kullanici: *"bizimki DIREK USTUNDE"* (binalarin uzerinden).
  ⚠️⚠️ **KOK NEDEN:** `_guzergahDilimi` binis VE inis duraklarinin ikisini de
     **GLOBAL** ariyordu. Kucuk sehirde hatlar kendi uzerine doner; inis
     duragi ayni caddenin **IKINCI GECISINE** kilitlenince `b <= a` cikiyor
     ve fonksiyon iki durak arasi **DUZ 2 NOKTALI cizgi** donduruyordu.
  ✅ **ON KOSUL BAGIMSIZ OLCULDU: 202 GTFS seklinin 35'i (%17,3) ILMEKLI**
     (>=30 nokta sonra kendine 60 m'den yakin donuyor) — ve "en kotu" denen
     **300** hattinin sekli (413000) o listede DE VAR.
  FIX: `_enYakinSegment`e **`basSegment`**; inis duragi BINISTEN SONRA aranir
  -> `b <= a` YAPISAL OLARAK imkansiz.
  ⚠️⚠️ Kardes dosya `rota_takip.dart` bu tuzagi ZATEN kapatmisti ve serhinde
     aynen uyariyordu; ders `rota_bul.dart`a UYGULANMAMISTI.
  ⚠️ Duz-cizgi dali SILINMEDI — artik ULASILMASI ZOR bir emniyet agi.
  ⚠️ **PENCERE YOK** (tum kalan cizgi taranir): `rota_takip`teki 40 segmentlik
     pencere GPS monotonlugu icindir; burada inis duragi pencerenin DISINDA
     kalir ve sonuc DAHA KOTU olurdu.

- 🧭 **TURU 155 — KONUM ISARETI: PUSULA (KENDI KANALIMIZ).**
  Kullanici: *"Konum yandextedki gibi DAIRE + YON OKU olsun, telefonu
  oynattikca yonu gostersin, cevresinde hafif beyaz daire var"*.
  ⚠️⚠️⚠️ **`geolocator.Position.heading` PUSULA DEGIL**: GPS *gidis yonu*
     (course over ground) ve cihaz **DURUYORKEN GECERSIZ** (Android 0.0,
     iOS negatif). Kullanicinin istedigi sey GPS ile YAPISAL OLARAK
     karsilanamaz. ⚠️ Bunu bir daha `heading` ile cozmeye calisma.
  ⚠️⚠️ **UC PAKET DE ELENDI (gerekceleriyle):**
     · `flutter_compass`: son surum ~2 yil once, 44 acik issue, bilinen
       ***"Compass doesn't move on iPhone 12 or above"*** — kullanici
       iPhone'da test ediyor. iOS'ta `trueHeading` konum akisi yoksa
       **SESSIZCE -1** doner, pakette `magneticHeading` yedegi YOK.
     · `flutter_rotation_sensor` 0.4.0: `intl ^0.20.3` istiyor, Flutter SDK
       `flutter_localizations` uzerinden `intl 0.20.2`'ye SABITLIYOR ->
       **`pub get` COZULEMIYOR** (denendi).
  **KARAR: projenin KENDI kanal deseniyle** (`GebzemPip`/`TelefonDurumu`
  idiomu) — ucuncu parti riski YOK ve iOS'un -1 tuzagi KENDIMIZ ele alindi.
  · `gebzem/pusula` kanali · Android `Pusula.kt` (TYPE_ROTATION_VECTOR, yoksa
    GEOMAGNETIC; 100 ms kisma; olaylar **ANA IS PARCACIGINDA** — kanal
    cagrisi baska parcacikta PATLAR) · iOS `GebzemPusula`
    (**AppDelegate.swift ICINDE** — pbxproj'a ayri dosya eklemek BOM tuzagi),
    `trueHeading` negatifse **`magneticHeading` yedegi**.
  · Dart `pusula_servisi.dart`: ⚠️⚠️ acilar **DOGRUDAN ORTALANAMAZ** (358 ile
    0'in 0.5 ortalamasi **179** = TAM TERS YON) -> sin/cos alaninda filtre +
    `atan2`; DAIRESEL olu bolge 1.5°.
  · **Kaynak sirasi:** pusula -> GPS gidis yonu -> hicbiri ise **OK CIZILMEZ**.
    ⚠️ Pusula bir kez deger verdiyse GPS yonu YOK SAYILIR; karisik
       kullanilsaydi yurumeye baslayinca ok ZIPLARDI.
  ✅ **EMULATORDE UCTAN UCA KANITLANDI** (`dumpsys sensorservice`):
     `06:17:58 + 0x5f726f76 ... package=app.gebzem.Pusula samplingPeriod=66667us`
     `06:18:45 - 0x5f726f76 ... package=app.gebzem.Pusula`
     Yani Dart -> kanal -> MainActivity -> SensorManager zinciri CALISIYOR ve
     "Bitir"de sensor BIRAKILIYOR. Kanal adlari uyusmasaydi kayit HIC
     olusmazdi — bu ayni zamanda kanal adi dogrulamasidir (turu 65b).
     ⚠️ Analiz ajani *"emulatorde pusula yok"* demisti; OLCULDU ve YANLIS
        cikti: AVD'de `android.sensor.rotation_vector` VAR.

- 🎯 **TURU 155 — YON KONISI AYRI MARKER, PUCK'IN ICINDE DEGIL.**
  ⚠️⚠️ `Marker.rotation` **MARKERIN TAMAMINI** dondurur. Koni puck ile ayni
     bitmap'te olsaydi kullanici donunce **PROFIL FOTOGRAFI DA TERS DONERDI**.
     Alta donen koni (`flat: true`), uste sabit fotograf.
  ⚠️ Dogruluk halkasi `Circle`; `radius` **METRE** oldugu icin zoom'la dogru
     olceklenir ve GERCEK belirsizligi gosterir (sabit piksel daire SUS olurdu).
     10-120 m kirpma: mukemmel GPS'te de gorunsun, kapali alanda ekrani kaplamasin.

- 📍 **TURU 155 — VARIS UCUNDA HICBIR ISARET YOKTU.**
  Kullanici: *"varis noktasinda DURAK GORUNMUYOR"*.
  ⚠️⚠️ **KOK NEDEN:** haritadaki duraklar `widget.duraklar`, yani
     **KULLANICININ CEVRESINDEKI** duraklar. Inilecek durak kilometrelerce
     uzakta oldugu icin o listede DEGIL.
  FIX: `_rotaUcIsaretleri()` — binis duragi · inis duragi · varis noktasi.
  ⚠️ Duraklar **ROTADAN TURETILIR** (otobus bacaginin ilk/son noktasi); ayri
     bir parametre IKINCI KAYNAK olur ve DRIFT ederdi.

- 📐 **TURU 155 — "15240 m kaldı" (kullanicinin ekran goruntusunde).**
  Bicimleyici (`_mesafeMetni`) **ZATEN VARDI** ama `private` oldugu icin adim
  karti onu KULLANAMIYOR, kendi ham `${m.round()} m` ifadesini yaziyordu.
  `mesafeMetni` olarak acildi; UC cagri yeri ayni kaynaga baglandi
  (`rota_sayfalari`daki km kopyasi da kaldirildi).

- ⚠️⚠️ **TURU 155 — DOGRULAMA YONTEMI TUZAGI (kayda deger).**
  IPA'da `gebzem/pusula` kanal adi **BULUNAMADI** ve bir an "kanal kurulmamis"
  sanildi. **KONTROL:** calistigi KANITLI ses kanalinin registrar anahtari
  `gebzem.audio` **DE bulunamiyor** (Swift <=15 baytlik dizeleri komut akisina
  gomer). Bulunan `gebzem/audio` aslinda uzun bir **NSLog** dizesinin parcasi.
  ⚠️ **KISA SWIFT DIZELERIYLE ARTIFACT DOGRULAMASI YAPMA** — sinif adi
     (`GebzemPusula`) ve SDK simgeleri (`startUpdatingHeading`) kullan.

- ⏳ **TURU 155 — DURUST SINIRLAR:**
  · **Harita karolari emulatorde cizilmiyor** (Play Services): yesil zemin,
    kesik desen, yon konisi, dogruluk halkasi ve varis/durak isaretleri
    **GERCEK CIHAZDA** gorulecek.
  · **Yurume mesafesi/suresi HALA kus ucusu tahmininden.** `_uclariBagla`
    cizgiyi gercek uclara bagladi ama sayi degismedi; ic celiski bu turda
    **BUYUDU**. ⚠️ Sunucu `mesafe_m` ve `sure_sn` alanlarini ZATEN donduruyor
    (`handler.go` FieldMask'te var), **ISTEMCI ONLARI ATIYOR**
    (`adres_servisi.dart` `yayaRotasi` yalniz `noktalar` okuyor). Duzeltmek
    bacak suresini, dolayisiyla **otobuse yetisme hesabini** degistirir.
  · **KUZEY AYRISMASI:** Android manyetik kuzey (deklinasyon UYGULANMIYOR),
    iOS gercek kuzey. Gebze'de fark ~5-6°; yaya navigasyonu icin onemsiz
    kabul edildi ama iki telefon yan yana konursa AYRI gosterir.
  · Yon konisinin gorsel bicimi (yarim aci ~26°, yaricap 15/27 dp) referans
    gorselden piksel ornekleme ile DEGIL tahminle secildi.
- **KALDIGIMIZ YER (2 Eyl 01:30): TURU 154 YAYINLANDI — SADECE iOS.**
  ios **33565389617** (**b82aac8**), R2 ipa=30147740 (md5 ebf88f27)
  index=7967 (md5 71cf1e9d) surum.json=45 (md5 7cb7ef62),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE,
  `get-task-allow: false` (debug imza YOK), profil ad hoc.
  IPA'da turu 154 dizeleri VAR (Burayı seç · Başlangıcı seç · Varışı seç ·
  Adres alınıyor… · " dk kaldı" · Merkeze dön · Yol tarifi · Vazgeç) ve turu
  153'un **"Haritaya dokunarak noktayı seç."** dizesi YOK.
  ⚠️ Kontrol dizesi "Yakınımda" **utf16le** olarak bulundu — yontem dogru.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **77/77** · emulatorde tasma **0**
     (360 dp + buyutulmus yazi olcegi, dort adimin dordu de kaydirildi).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260902-0130

- 🧭 **TURU 154 — HARITA NOKTA SECICI** (kullanici emri: *"harita nokta
  secerken ekranda bir PIN olsun, biraktigi yerin ustune ONAY ISARETI olsun,
  BURASININ ADRESI YAZSIN"*).
  ⚠️⚠️ **SABIT MERKEZ PIN** (Uber/Google "set location on map"): pin ekranin
     ORTASINDA DURUR, kullanici HARITAYI kaydirir. Dokunulan yere pin
     birakmak SECILMEDI — parmak dokundugu noktayi KAPATIR ve kullanici tam
     nereye bastigini goremez.
  ⚠️⚠️ **`Marker` DEGIL `Stack` katmani**: marker haritayla BIRLIKTE kayar,
     oysa secici pinin EKRANDA SABIT kalmasi gerekiyor. `IgnorePointer`
     ZORUNLU (pin dokunuslari yutarsa harita tam ortasindan kaydirilamaz) ve
     pinin **UCU** merkeze oturur (ikon ortasi merkeze gelseydi 22 dp yanlis
     nokta secilirdi).
  ⚠️ Adres YALNIZ **kamera DURUNCA** cozulur (ters geocoding bir AG istegi;
     her karede cagrilsaydi cihaz geocoder'i bogulur ve SESSIZCE bos donerdi)
     + bayat yanit kapisi (`_noktaNesli`).
  ⚠️ Onay karti UC HALDE de bir sey yazar: "Adres alınıyor…" / adres /
     koordinat. Bos birakmak "burasi gecersiz" gibi gorunurdu.
  ⚠️ Dokunus artik SECMEZ, kamerayi o noktaya TASIR; secimi **ONAY dugmesi**
     yapar — kullanici neyi sectigini ONCE gorur.

- 🧭 **TURU 154 — ADIM (STEP) EKRANI YENIDEN KURULDU** (kullanici emri:
  *"sana rota baslat ve step gorsellerini de attim, ALAKASI YOK, arayuzu daha
  MODERN hale getir diyorum yapmiyorsun"* + *"steplere tikladigimda hangi
  stepleri SOL SAG yapinca harita o NOKTALARA gidiyor"*).
  Duzen: kalan sure (ekranin en buyuk sayisi) + varis saati / **bacak bacak**
  ilerleme cubugu + hat rozeti / **kaydirilabilir** adim karti (`PageView`) /
  Bitir · (takip birakilmissa) Merkeze don.
  ⚠️⚠️ Kaydirma haritayi o bacaga sigdirir ve **takip kamerasini BIRAKIR**:
     birakilmasaydi bir sonraki GPS olayi kamerayi ANINDA kullanicinin
     uzerine geri ceker ve kaydirma HICBIR ISE YARAMAZDI. Geri donus yolu
     **"Merkeze dön"** (Mapbox deseni: `FOLLOWING`de dugme GONE).
  ⚠️⚠️ **`_adimProgramatik` ZORUNLU**: `PageView.onPageChanged` kullanici
     kaydirmasi ile programatik gecisi **AYIRT ETMEZ**. Bayrak olmasaydi takip
     bir sonraki bacaga gectiginde kamera kullanicidan KOPAR ve "Merkeze dön"
     dugmesi kendiliginden belirirdi.
  ⚠️⚠️ **TAKIP ACIKKEN panelde "Nereden/Nereye" ve "Duraklar" CIZILMEZ**:
     yururken adres degistirmek istenmez, rotayi dusuren dugme en kotu anda
     basilabilir; ~74 dp haritaya kaliyor. **`_panelBoy` AYNI kosulu okur** —
     ayrisirsa haritanin alt dolgusu ve yuzen serit kayar (UC KEZ yasandi).
  ⚠️ `_kalanDakika` **ROTANIN TAMAMINDAN** kalani verir (aktif bacagin kalani
     + sonrakilerin tamami); yalniz aktif bacak yazilsaydi kullanici "3 dk"
     gorup 25 dakika sonra varirdi.
  ⚠️ Bekleme bacaginda kamera TASINMAZ (polyline YOK) — sessizce yerinde
     kalir, bu DOGRU davranis.

- ⚠️⚠️⚠️ **TURU 154 — ILERLEME CUBUGUNDA UC SEY BILEREK KULLANILMADI.**
  · **`LinearProgressIndicator` YOK**: Material 3'un yeni surumu cubugun
    ucuna bir "stop indicator" noktasi ve dolu/bos arasina bosluk koyuyor;
    dort minik dilimde bu suslemeler cubugu OKUNAMAZ yapardi.
  · **`Stack`/`FractionallySizedBox` YOK**: oran 0 iken cocuk 0 genislige
    duser ve `RenderStack` boyutunu YALNIZ positioned OLMAYAN cocuklarindan
    hesapladigi icin dilim **0x0**'a coker (turu 136'da EKRANIN TAMAMINI
    silen hata). Iki `Expanded` ile bu YAPISAL OLARAK imkansiz.
  · **`CrossAxisAlignment.stretch` ZORUNLU**: cocuksuz `ColoredBox` gevsek
    kisitta `constraints.smallest` alir, yuksekligi **0** olur ve cubuk HIC
    gorunmezdi.
  ⚠️ `flex` tam sayi olmak zorunda; 1000'lik olcek 0,1% cozunurluk verir ve
     `if (p > 0)` / `if (p < 1000)` kapilari sayesinde flex ASLA 0 olmaz.

- 🛡️ **TURU 154 — TAKIP ACIKKEN ROTAYI DUSUREN IKI YOL KAPATILDI.**
  `_durakAc` ve `_rotaAra` `_rota`yi null yapiyor ama `_takip`e DOKUNMUYORDU.
  `_takip != null && _rota == null` durumunda panel durak kartlarini cizerken
  `_panelBoy` ADIM KARTI yuksekligini donduruyor olurdu ve GPS akisi SAHIPSIZ
  surerdi. Ikisi de artik basta `_takipDurdur()` cagiriyor.
  ⚠️ Bugun ikisi de pratikte ulasilamiyor (takipte o dugmeler cizilmiyor) —
     kapi YAPISAL olsun diye kondu.

- ⏳ **TURU 154 — DURUST SINIRLAR (kullaniciya soylendi):**
  · **Yurume MESAFESI/SURESI hala kus ucusu tahmininden** geliyor; cizilen yol
    GERCEK ama sayilar "yaklaşık" etiketiyle veriliyor. Gercek uzunlugu yazmak
    bacak suresini, dolayisiyla **otobuse yetisme hesabini** da degistirir —
    AYRI BIR TUR. ⚠️ Yalniz mesafeyi guncelleyip sureyi birakma: "4 dk · 340 m"
    ic celiski olur.
  · **Egim/donme (Yandex'teki "karsiya donen" gorunum) YAPILMADI**: kullanici
    turu 150'de acikca **kus bakisi** demisti. Istenirse `tilt`/`bearing`.
  · Google **Autocomplete en fazla 5 oneri** dondurur (parametresi YOK);
    Google Maps'teki 7 satirlik liste o uygulamanin KENDI ic servisi.
  · Gebze'de OSM yaya verisi fiilen YOK (canli olculdu: 9.647 yol, **99
    kaldirim**, 40 isaretli gecit) — **hicbir motor** gecit-farkindalikli yaya
    rotasi garanti edemez; Google WALK beta uyarisini gostermeyi ZORUNLU kilar.
  · `rota_sayfalari.dart` bos-sonuc metnindeki *"cihaz geocoder'i"* serhi
    **BAYAT** (artik Google Autocomplete) — sonraki turda duzeltilecek.
- 🔑 **TURU 152 — GOOGLE PLACES + ROUTES BAGLANDI (kullanici onayiyla).**
  Kullanici: *"bizde google admin var zaten bunlari tokenleri, direk baglanip
  yapmadin mi?"* — **OLCULDU ve cevap ilginc cikti:** projede ACIK olan tek
  Google servisi **Maps SDK (android + ios)** idi; `places.googleapis.com` ve
  `routes.googleapis.com` **ACIK DEGILDI**, ustelik mevcut "Gebzem Maps mobil"
  anahtarinin **API hedefi yalniz o iki Maps SDK**'ydi. Yani "token vardi" ama
  o tokenin konusabilecegi servis YOKTU.
  · Iki servis ACILDI (`gcloud services enable`).
  · Yeni anahtar: **yalniz bu iki servise + YALNIZ sunucunun IPv4 VE IPv6
    adresine** kisitli. `.env.infra` + sunucu `.env` + compose'ta; **REPOYA
    GIRMEZ**.
  ⚠️⚠️⚠️ **ANAHTAR ISTEMCIYE KONULMADI — YAPMA.** Places ve Routes birer
     **WEB SERVISI** ve Google bu grup icin **yalniz IP kisitlamasi**
     destekliyor (Maps SDK'daki paket/bundle kisiti YOK — resmi guvenlik
     dokumanindan dogrulandi). Repo **PUBLIC** oldugu icin ikiliye gomulen
     anahtar cikarilip BIZIM faturamiza harcanirdi.
  ⚠️ **IPv6 TUZAGI (canlida yasandi):** anahtar once yalniz IPv4'e kisitlandi
     ve sunucu **IPv6'dan** cikinca `API_KEY_IP_ADDRESS_BLOCKED` aldi. Iki
     adres de izin listesinde OLMAK ZORUNDA.
  📌 **YENI UCLAR** (korumali grupta — PARA HARCIYOR, kimliksiz cagrilamaz):
     `GET /yolbul/durum` · `GET /yolbul/adres` · `POST /yolbul/yaya`
  ⚠️ `docker-compose.yml`in **`environment:` blogu DA** guncellendi — turu
     75'te R2 anahtarlari yalniz `.env`e yazilmis ve medya **SESSIZCE KAPALI**
     kalmisti (`/health` "ok" donuyordu). Acilis logu: `yolbul: aktif`.

- ⚠️⚠️⚠️ **TURU 152 — SUNUCU LOGUNDA OLCULEN MALIYET HATASI.**
  `yayaRotasi` ic ice aday dongusunun **ICINDEYDI**: tek arama **90+ Google
  istegi** uretiyordu (sunucu logunda sayildi). Aylik **10.000 ucretsiz** kota
  ~110 aramada biterdi ve sonrasi **para**.
  FIX: cagri **SONUC LISTESI HAZIR OLDUKTAN SONRA** ve yalniz **KAZANAN**
  adaylar icin -> **90+ -> 6** (emulator + sunucu logu ile dogrulandi).
  ⚠️ **DERS: ucretli bir dis servisi bir DONGU ICINDEN cagirirken, o dongunun
     kac kez donduguni SAY.** Ekranda 3 sonuc gorunmesi 3 cagri yapildigi
     anlamina GELMEZ.
  ⚠️ YAPMA: `yayaRotasi`yi tekrar `rotaAra`nin ic dongusune tasima.

- 📌 **TURU 152 — MALIYET KORUMALARI (ucu de KALIR):**
  · **Redis onbellegi** (adres 7 gun, rota 1 gun) — ayni sorgu tekrar
    FATURALANMAZ.
  · **DAR FieldMask** — Routes'ta istenen alan kumesi SKU'yu belirliyor;
    genis maske **Enterprise** katmanina atlatir. ⚠️ YAPMA: maskeye
    `routes.travelAdvisory.tollInfo` gibi alan ekleme.
  · **Kapilar** — NaN / (0,0) / 30 km ustu **ISTEK ATILMADAN** 400 doner.
  ⚠️ `routingPreference` VERILMEZ: dokumanda *"only for DRIVE or
     TWO_WHEELER"*; yaya modunda gonderilirse istek REDDEDILIR.
  ⚠️ `searchText` kullanilir, `autocomplete` DEGIL: autocomplete oturum
     jetonu ister ve jeton yanlis tasinirsa **her tus AYRI faturalanir**.

- 🔎 **TURU 152 — ADRES ARAMASI ARTIK GERCEKTEN SOKAGI BULUYOR (olculdu).**
  Turu 151'de cihazin kendi geocoder'i kullaniliyordu; **emulatorde olculdu:**
  `"1711 sokak"` -> *"Şehit Erdem Demir Caddesi No:49"* (**YANLIS**),
  `"adliye"` -> *"1209. Sokak"* (**YANLIS**).
  Google Places ile ayni sorgu: **"1711. Sokak · Gaziler, 1711. Sk., 41400
  Gebze/Kocaeli"** (hem sunucudan hem UYGULAMADAN dogrulandi).
  ⚠️ **CIHAZ GEOCODER'I SILINMEDI, YEDEK**: sunucu/ag yoksa ya da anahtar
     tanimsizsa (uc 503) arama yine calisir, yalnizca kabalasir.
  ⚠️ **TERS GEOCODING (koordinat -> adres) BILEREK CIHAZDA KALDI**: o yonde
     iyi (olculdu: *"İbrahim Ağa Caddesi No:35"*), UCRETSIZ ve onbellekli.
     Google'a vermek **her harita dokunusunu faturaya** cevirirdi.

- 🚶 **TURU 152 — YURUME BACAKLARI ARTIK SOKAKTAN GIDIYOR.**
  Kullanici: *"shape guzel ciziyor ama bizim yurume EVLERIN UZERINDEN gidiyor,
  sokak cadde guzel cizmiyor"*. Artik `/yolbul/yaya` gercek yol agi cizgisi
  donduruyor (olculdu: **38 nokta**, 7 adim, *"Muammer Aksoy Cd. yonunde hafif
  sola donun"*).
  ⚠️ **Rota alinamazsa DUZ CIZGIYE DUSULUR** — ozellik COKMEZ, kabalasir.
  ⚠️⚠️ **DURUST SINIR — YAYA GECIDI GARANTI EDILEMEZ.** Overpass ile CANLI
     olculdu (1 Eyl 2026, Gebze): **9.647 yolda yalnizca 99 kaldirim, 40
     isaretli gecit, `sidewalk=*` etiketli 1 yol.** Yani Gebze'de yaya verisi
     FIILEN YOK ve **hicbir motor** (Google/Mapbox/OSRM/Valhalla) bunu
     veremez; hepsi "sokak agindan en kisa yol" verir.
  ⚠️ **SOZLESME GEREGI UYARI**: Google WALK'i **BETA** ilan ediyor ve
     *"You must display this warning to the user"* diyor. Metin **sunucudan**
     geliyor (`uyari` alani) ki tek yerden degistirilebilsin.
     ⚠️ YAPMA: bu alani istemciden kaldirma.

- 🛡️ **TURU 152 — UCTAN UCA 391 -> 402.** En degerli iki kontrol:
  · *"adres aramasi TAM SOKAGI buluyor (1711)"* — cihaz geocoder'ine geri
    dusulurse KIRMIZI duser.
  · *"yaya rotasi DUZ CIZGI DEGIL (>2 nokta)"* — olculdu 38; vekil bozulup
    duz cizgiye dusulurse KIRMIZI duser.
  ⚠️ Kontroller Google'a **EN AZ** istek atacak sekilde kuruldu: tek gercek
     arama + tek gercek rota; gerisi kapi kontrolu.
  ⚠️ Anahtar yoksa (`/yolbul/durum` `acik=false`) gercek cagri yapan
     kontroller **ATLANIR** — anahtarsiz kurulumda e2e haksiz yere kirmizi
     dusmesin.

- ⚠️⚠️ **TURU 152 — `AdresServisi` BIR SINGLETON: `Ref` DISARIDAN BAGLANIR.**
  `main.dart` acilista `AdresServisi.i.baglaApi(() => ref.read(apiProvider))`
  cagirir. **BAGLANMAZSA sunucu dali SESSIZCE atlanir** ve arama cihaz
  geocoder'ina duser — yani ozellik "calisiyor gibi" gorunup KOTU sonuc
  verirdi ("servis yazildi, CAGIRAN yol yazilmadi" sinifi bu projede **DOKUZ**
  kez sahaya cikti).
  ⚠️ **`Ref` DEGIL FONKSIYON alinir**: `ConsumerState`teki `ref` bir
     **`WidgetRef`**, `Ref` DEGIL — dogrudan gecmek DERLENMEZ.

- 📌 **TURU 152 — ANAHTAR ENVANTERI (gcloud ile okundu):**
  · **Gebzem Maps mobil** — API hedefi: Maps SDK android+ios.
    ⚠️ **UYGULAMA KISITI YOK** (paket adi / bundle ID tanimsiz). `.env.infra`
       notu *"Kisit: yalniz Maps SDK"* diyor — o **API** kisiti, ki VAR.
       Zarar harita kotasiyla sinirli ama **duzeltilmesi gerekiyor**.
       ⏳ Duzeltme icin **release SHA-1** lazim ve keystore yalnizca GitHub
          secrets'ta; yerelde YOK. Tek anahtar tek uygulama kisiti alabildigi
          icin Android/iOS **AYRI anahtara bolunmeli** + CI enjeksiyonu
          guncellenmeli. **KULLANICI ONAYLADI, HENUZ YAPILMADI.**
  · **Gebzem sunucu Places Routes** — IP kisitli (v4+v6), yalniz places+routes.
  · Firebase'in ureттigi uc anahtar (android/ios/browser) — Firebase
    servisleriyle sinirli, DOKUNULMADI.

- **KALDIGIMIZ YER (1 Eyl 21:19): TURU 150 YAYINLANDI — SADECE iOS.**
  ios **33541630455** (**caebd7f**), R2 ipa=30100765 (md5 1f61c1a4)
  index=7967 (md5 7d4ee90a) surum.json=45 (md5 b570b403),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 150 dizeleri VAR (Yakındaki duraklar · Nereye gidiyorsun ·
  Gebzem AI · Aktarmasız hat bulunamadı · Durak adı ara · Rotayı bul).
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **61/61** · 360 dp x **1.0 / 1.3 / 2.0**
     emulatorde tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260901-2119

- 🚏 **TURU 150 — DURAK MODU** (kullanici emri: *"durak dedigimde alt kisimda
  EN YAKIN DURAKLAR ayni yemek kartlari gibi gorunmeli, o duraktan gecenler
  yaklasanlar; kartlarin ustunde NEREDEN / NEREYE iki buton olacak, sistem
  uzaklasacak shape cizecek, o duraktaki 3 buton ust uste gelecek otobuslerin
  numarasi gorunecek; ekranda duraklardan BASKA SEYLER GORUNMEMELI"*).
  · `_durakModu` acikken panelde YALNIZ [Nereden]/[Nereye] + yatay durak
    kartlari; cip seridi · arama · kisayollar · isletme seridi GIZLI ve
    haritada **isletme pinleri CIZILMEZ**.
  · Menudeki "Durak" girisi artik `YakinimdaEkrani(durakla: true)`.
    ⚠️ ONCEDEN `kategori: 'hizmet'` ACIYORDU — "Durak"a dokunan kullanici
       TEMIZLIK/NAKLIYAT isletmelerini goruyordu.
  · **`_duragiSec` TEK KAYNAK**: pin dokunusu da kart dokunusu da ayni
    yoldan gecer, serit secili karta KAYAR, kamera durak uzerine oturur.
  ⚠️ **CIKIS YOLU ZORUNLU**: baslikta X (+ rota varken "Duraklar"). Mod cip
     seridini/aramayi/kisayollari gizledigi icin cikis olmasa ekran
     KILITLENMIS gibi gorunurdu.

- 🧭 **TURU 150 — ROTA** (`features/ulasim/rota_bul.dart` +
  `rota_sayfalari.dart`, IKISI DE YENI).
  ⚠️⚠️ **GOOGLE'A ISTEK YOK**: hangi otobuse binilecegi, nerede inilecegi ve
     kac dakika surdugu KENDI GTFS verimizden. Fatura YOK, cevrimdisi calisir.
  ⚠️⚠️ **GECERLILIK SIRADAN DEGIL SEFER SUTUNUNDAN**: `stop_sequence` veride
     YOK ve zaman siralamasi dongusel hatlarda yaniltiyor (olculdu: en kotu
     grupta **%65,8 ters cift**). Dogru olcut: AYNI SEFERDE binis saati inis
     saatinden ONCE mi?
  ⚠️ **AKTARMA YOK (V1)**: olculdu, 800 m yurume yaricapiyla durak
     ciftlerinin **%41'i** aktarmasiz cozuluyor. Aday yoksa ekran DURUSTCE
     soyler, sahte rota URETMEZ.
  ⚠️ **YURUME BACAKLARI KUS UCUSU** (durust sinir): projede yol tarifi
     (routing) kaynagi YOK; ekranda "yaklasik" yazar.
  · Haritada **IKI RENK**: yurume KESIK gri, otobus KALIN hat renginde.
    ⚠️⚠️ `PatternItem.dash(n)` **Android'de PIKSEL, iOS'ta METRE**
       (kaynaktan dogrulandi: `Convert.java` `new Dash(length)` vs
       `FGMPolylineController.m` `kGMSLengthRhumb`). Sabit sayi yazilsaydi
       iOS'ta kesikler **18 METRE** olur, sehir olceginde cizgi DUZ gorunur
       ve yurume/otobus ayrimi SESSIZCE kaybolurdu. iOS'ta desen zoom'dan
       turetilir (`onCameraIdle` ile guncellenir).
  · Rota bulununca kamera dikdortgene SIGAR (`_sigdir`, **nesil sayacli** —
    ayni rota tekrar secilirse deger degismez ve kamera TASINMAZDI).
  · Kullanici emri: rota bulununca **alttaki durak kartlari GIDER**, yerini
    rota ozeti alir.

- 🤖 **TURU 150 — YAPAY ZEKA YORUM ALANI** (kullanici emri: *"tum
  isletmelerde alttaki temizlik nakliyat MENU GOSTERIMI yerine YAPAY ZEKA
  YORUM ALANI koy, hepsine oylesine bir yorum yaz, MOCKUP gibi dusun"*).
  · `_aiYorum` (15 dal) + `_bosYorum` yedegi; kart basina KAYDIRILIR
    (turu 141 dersi: imza `IsletmeOzet` almasaydi bir daldaki DORT kart da
    AYNI yorumu gosterirdi).
  · Fiyat ANLAMLI olan dallarda **vitrin KALIR** (yemek · kafe · akaryakit ·
    otel — kullanici turu 143'te bunu ACIKCA istemisti).
  · Yukseklik `_altSatirBoy` ILE AYNI; kartlar dallar arasi ESIT kalir.
  ⚠️ **YALNIZ `demo-` KAYITLARDA**: gercek bir isletmenin altina uydurma bir
     "yapay zeka yorumu" yazmak kullaniciya YANLIS BILGI olurdu.
  ⚠️ Bunlar GERCEK BIR MODELIN CIKTISI DEGIL; yayin oncesi
     `kHaritaOnizleme = false` ile ornek kayitlarla BIRLIKTE paketten cikar.

- 🧹 **TURU 150 — YUZEN SUZGEC SERIDI KALDIRILDI** (kullanici emri: *"ilk
  ekrandaki 5 km icinde vs ANA KARTIN USTUNDEKI yeri de KALDIR"*).
  ⚠️ Kod SILINMEDI (`_yuzenCipler` / `_filtreSatiri` / `_yuzenCip`
     `// ignore: unused_element` ile duruyor): bu dosyada ayni sinif silme
     **BES kez** komsu uyeyi de goturdu (turu 127/138/140/141).
  ⚠️ Suzgeclerin KENDISI OLU DEGIL: `isletmeFiltreAc` ekrani ve
     `_fKm`/`_fPuan`/`_fKampanya`/`_fOnayli` DURUYOR.

- ⚠️⚠️⚠️ **TURU 150 — EMULATORDE OLCULEN DORT TASMA:**
  · **Durak karti 2.2 dp**: `Container.decoration` kenarligi DOLGUNUN DISINA
    konur ve cocugun kisitindan **2 x 1.6 = 3.2 dp DUSER**; `_durakKartBoy`
    bunu gormuyordu. FIX: **`foregroundDecoration`** — yerlesimi DEGISTIRMEZ
    ve secili/secili-degil kartlar AYNI boyda kalir (yoksa serit her secimde
    3.2 dp ZIPLARDI).
  · **Isletme karti 1.5 dp**: `_kartUstBoy` **PAYSIZDI**, kardesi `_seritBoy`
    ise +1 dp tasiyordu. **Asimetrinin kendisi hataydi** (turu 121/123/137/141
    ile ayni sinif). FIX: `ceil + 2` (iki metin satiri + meta = UC yuvarlama).
  · **Hat satirlari SABIT 22 dp** idi; yazi olcegi 2.0'da harfler UST ALT
    KIRPILIYORDU -> **`_hatSatirBoy` TEK KAYNAK** (`_durakKartBoy` da okur).
  · **Durak karti `kPanelKartEn` (372)** ile 360 dp ekranda tasip kartin EN
    ONEMLI bilgisini (**"N dk"**) kirpiyordu -> genislik EKRANDAN turetiliyor
    (44 dp pay: sonraki kart KENARDAN gorunur).

- ⚠️⚠️ **TURU 150 — SESSIZ OLU ARAYUZ (emulatorde goruldu):** "Nereye"
  dugmesi `if (_konum == null) return;` yuzunden HICBIR SEY YAPMIYORDU;
  konum iznini reddeden kullanici sebebini de ogrenemiyordu. Konum artik
  ZORUNLU DEGIL — baslangic haritadan ya da durak aramasindan da secilebilir;
  konum yalnizca "Konumum" kisayolunu VARSAYILAN yapmak icin kullanilir.

- ⚠️ **TURU 150 — GECICI OLCUM SATIRLARI** `GECICI-OLCUM` isaretiyle konuldu
  (emulatorde GPS fix'i HIC gelmiyor, ornek kartlar ve durak modu baska turlu
  gorulemiyor) ve commit oncesi `grep -rn "GECICI-OLCUM" lib/` **SIFIR**
  dondurdu (turu 140 dersi: olcum icin konulan her gecici satir ARANIR).

- **KALDIGIMIZ YER (30 Agu 18:41): TURU 141 YAYINLANDI — SADECE iOS.**
  ios **33319539549** (**ed7840a**), R2 ipa=29847119 (md5 5f516b5e)
  index=7982 (md5 c71a12e1) surum.json=48 (md5 a9620c27),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 141 dizeleri VAR (Nöbetçi Eczane · Benzin İstasyonu · Motorin ·
  Aile Odası · Ev Temizliği · "Durak bilgisi henüz bağlı değil.") ve turu
  140'in kaldirilan `m.uber.com` dizesi YOK. `assets/marka` 7/7 pakette.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0/0** · test **52/52** · 360 dp x **1.0 / 1.3 / 2.0** -> tasma **0**
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260830-1841

- 🌿 **TURU 141 — `_dal` (GORUNUM DALI) `_kategori`DEN AYRILDI.**
  ⚠️⚠️ **SUNUCU BILINMEYEN KATEGORIYE 400 DONER** (`yakinimda.go:103`
     *"geçersiz kategori"*). "Benzin İstasyonu" gibi sunucuda KARSILIGI
     OLMAYAN bir kisayol icin ekranin GOSTERDIGI dal ile sunucuya GIDEN
     kategori ayri tutulmak ZORUNDA:
       `_dal = 'akaryakit'`  ->  `_kategori = 'oto'`
  ⚠️ Esleme ICAT DEGIL: menudeki hizli erisim (`hizmet_menusu.dart`) ayni
     eslemeyi ve ayni `LucideIcons.fuel` ikonunu IKI yerde zaten kullaniyor
     (turu 124/128).
  ⚠️⚠️ `_dal` **`widget.kategori` ile BASLATILIR** (`late String _dal =
     widget.kategori`): menuden kategoriyle gelindiginde bos kalsaydi cip
     seridi hicbir cipi secili gostermez, serit CIZILMEZ ve vitrin varyanti
     SECILMEZDI — ekran kategoriyle acildiginda OLU gorunurdu.

- 🪟 **TURU 141 — IKI YENI POPUP** (kullanici emri).
  · **%95 PROFIL** — kart govdesine dokunus. `sekmeModu: true` (sheet'te
    `canPop` true oldugu icin `AppBar` OTOMATIK geri oku cizerdi) +
    `MediaQuery.removePadding(removeTop: true)` (`AppBar` `primary` oldugu
    icin sheet tepesinde ~44-59 dp OLU BOSLUK birakiyordu) +
    `enableDrag: false` (profil govdesindeki asagi-cek yenileme ile sheet'in
    surukleme jesti AYNI arenada yarisir) + `ScaffoldMessenger` sarmali.
  · **%70 LISTE** — cipe/kisayola dokunus. Ustte arama (ipucu SECILI
    kategoriden), altinda filtre cipleri, altta DIKEY isletme kartlari.
  ⚠️⚠️⚠️ **SEVK ENGELI (denetim yakaladi):** popup ONCEKI dalin
     listesiyle aciliyor ve KENDINI ONARMIYORDU. `_dalCipi` `_yukle`yi
     BASLATIR ama BEKLEMEZ; popup bir sonraki karede acilir ve ekranin
     `setState`i AYRI route'taki o agaci YENIDEN CIZMEZ.
     FIX: **`_listeNesli` (`ValueNotifier`) + `ValueListenableBuilder`**.
     ⚠️ Sayac **UC DALDA DA** artar (basari · hata · konum-yok); ilk yazimda
        yalniz basari dalindaydi ve serh "her sonucta" diyordu — bu projenin
        en sik hata sinifi, bu turda KENDI kodumda tekrarlandi.
     ⚠️ Popupun `setState`ini bir alanda SAKLAMA: sheet kapanirken OLU bir
        `State`e `setState` cagirilabilir. `ValueListenableBuilder` dispose'ta
        aboneligi KENDISI birakir.
  ⚠️ `StatefulBuilder` DE KALIR: filtre/arama dokunusunu ANINDA yansitan
     odur (nesil yalniz AG yanitinda artar).

- 🔎 **TURU 141 — ARAMA ALANI (panel + popup) VE `_AramaAlani`.**
  ⚠️⚠️ **SUZGEC ISTEMCIDE**: `/isletmeler/yakinimda` `q` parametresi
     ALMIYOR (backend dogrulandi) ve liste TEK ISTEKTE (60 kayit) geliyor —
     suzulen kume kullanicinin gordugu kumenin TAMAMI (turu 122 gerekcesi).
  ⚠️⚠️ **AYRI `StatefulWidget` ZORUNLU**: ilk yazimda kutu `build` icinde
     `TextEditingController(text: _q)` yaratiyordu. Uc hata birden:
     (a) her karede YENI denetleyici, eskisi HIC dispose edilmez;
     (b) IME bilesimi SIFIRLANIR (Turkce klavye bozulur);
     (c) `key`i metin bos<->dolu ile degistirmek ILK HARFTE elemani yeniden
         kurar ve **KLAVYE KAPANIR**.
  ⚠️⚠️ **`suffixIconConstraints` ZORUNLU** (OLCULDU): verilmezse
     `InputDecorator` `kMinInteractiveDimension` (48 dp) dayatir ve kutu
     ILK HARFTE 43 -> 48 dp SICRAR; `_panelBoy` o sicramayi goremedigi icin
     yuzen filtre seridi 7 dp kayardi.
     ⚠️ Bedeli: X'in dokunma hedefi 36 dp (Material 48'in altinda) —
        BILINCLI; temizlemenin ikinci yolu var ve panelin her harfte
        ziplamasi daha kotu.
  ⚠️ Ipucu **DEGER DEGIL**: kullanici *"inputun icinde cafe yazsin"* dedi;
     deger yazilsaydi suzgec isletme adlarinda "Kafe" arar ve liste ANINDA
     BOSALIRDI.

- 🚕 **TURU 141 — DORT KISAYOL: Nöbetçi Eczane · Durak · Benzin İstasyonu ·
  Taksi** (kullanici emri: *"cizginin altina 4 tane kart koy"*).
  ⚠️⚠️ Kartlar artik **SERIT ILE BIRLIKTE** cizilir. Turu 137 bunu bilerek
     yapmiyordu (ikisi birden 360x640'ta paneli ~330 dp'ye cikariyordu);
     karar KULLANICININ. **OLCULDU: panel ekranin ~%57'si, haritaya ~%43.**
  ⚠️⚠️ **DURUST SINIRLAR (turu 89/96t'de yazili, DEGISMEDI):**
     · **Nobetci eczane NOBET VERISI YOK** — kart eczaneleri MESAFEYE gore
       listeler.
     · **DURAK verisi YOK** — kart durustce soyler, sahte liste CIZMEZ.
     · **AKARYAKIT FIYATI HICBIR YERDE YOK** — kart `oto` kategorisini acar;
       fiyatlar YALNIZ ornek kayitlarda ve "Örnek" etiketiyle.
       ⚠️ Bu yuzden "Benzin İstasyonu" listesinde GERCEK oto servis
          kayitlari da cikar (denetim bulgusu, kullaniciya bildirildi).
     · **TAKSI** kayitli `hizmet` isletmelerini gosterir (temizlik/nakliyat
       da o kategoride — durust sinir, kullaniciya bildirildi).
  ⚠️ Kisayol `_dalSec` DEGIL `_kisayol` cagirir: zaten secili bir dalda
     `_dalSec` SESSIZCE donerdi ve kullanici "dokundum, olmadi" derdi.

- 🍔 **TURU 141 — VITRIN: GORSEL + AD + FIYAT** (`_ornekVitrin`).
  · **yemek** gorselli (Big Mac 229 ₺ · McChicken 199 ₺ · Cheeseburger
    259 ₺ · Patates 79 ₺)
  · **akaryakit** (Benzin 44,15 ₺/lt · Motorin 45,80 · LPG 22,40) ·
    **otel** (Tek/Cift/Aile Odası) · **hizmet** (Ev Temizliği 900 ₺ ...) —
    hepsi GORSELSIZ.
  ⚠️⚠️ **KAFE GORSELSIZ** (emulatorde goruldu): elimizdeki dort fotograf
     McDonald's MENU gorselleri ve *"Filtre Kahve"*nin yaninda **PATATES**
     cikiyordu. **Yanlis gorsel, gorselsizden KOTUDUR.**
  ⚠️⚠️ **KALEMLER KAYITTAN KAYITA KAYDIRILIR** (denetim bulgusu): imza
     `IsletmeOzet` almadan yazilmisti ve bir daldaki DORT ornek kart da AYNI
     kalemleri gosteriyordu — **Burger King kartinin altinda "Big Mac"**.
  ⚠️ `Row` + `Expanded`, ic ice yatay `ListView` DEGIL: kartin alt yarisindaki
     surukleme ICTEKI listeye gider ve DIS serit kaymazdi (turu 140 dersi).
  ⚠️ Ornek adlari KISALTILDI: gorselli ogede metne **95 dp** kaliyor
     (olculdu); "Tavuk Burger Menü" ILK OLCEKTEN itibaren kirpiliyordu.

- 📏 **TURU 141 — UC OLCU FORMULU OLCULEREK DUZELTILDI** (denetim, gecici
  widget testleri):
  · `_aramaBoy` gercek kutudan **2-7 dp KISA** idi.
  · `hataBoy` **13 dp EKSIK** — serh *"48 dp: TextButton'un buyugu"* diyordu
    ama formul yalniz METNI olcuyordu; `TextButton` Material'in 48 dp'lik
    dokunma tabanini dayatiyor. -> `math.max(48.0, ...)`.
  · `ulasim` **0,4-0,8 dp eksik** -> `_seritBoy`daki **+1 dp pay** dersi
    buraya da uygulandi.
  · `_altSatirBoy` paysizdi -> olcek **1.875 ustunde** metin dali baglayici
    olup RenderFlex tasmasi uretirdi.
  ⚠️ `_panelBoy` IKI yeri besliyor: haritanin `altDolgu`su ve yuzen filtre
     seridinin konumu (`_panelBoy + 10`). Ayrisirsa IKISI DE bozulur.

- ⚡ **TURU 141 — `_menuluKume` ARTIK O(1).** Govdesi `_gorunen.any(...)` idi;
  `_gorunen` bir GETTER ve her okumada 60 kaydi bastan suzup DORT YENI
  `IsletmeOzet` uretiyor. Kart basina cagrildigi icin dikey listede **O(n²)**
  oluyordu. Olcut esdeger: `_menuluSerit && kHaritaOnizleme && _konum != null`.

- 📣 **TURU 141 — SNACKBAR'LAR ARTIK `rootMessengerKey` ILE.**
  `ScaffoldMessenger.of(context)` EKRANIN messenger'ini bulur ve SnackBar
  acik %70/%95 popupun **ARKASINDA** cizilirdi — kullanici hicbir sey
  gormezdi (telefon dugmesi ve "örnek kayıt" uyarilari dahil).

- 🔘 **TURU 141 — KUCUK AMA GORUNUR:** sag ust navigator **DOLU** (Material
  `Icons.navigation`; **Lucide bir CIZGI ikon setidir, dolu varyanti YOKTUR**
  — kaynaktan dogrulandi, turu 98'deki "dolu kalp" karariyla ayni sinif) ·
  yuzen filtre ciplerine **checkbox** + zemin **%62 -> %82** (`kYuzenCipAlfa`
  AYRI sabit; `kHaritaDugmeAlfa` dort harita dugmesini besliyor ve serhi
  tek-kaynak olmayi sart kosuyor) · popuptaki "Haritada göster" artik once
  SHEET'I KAPATIR (yoksa kamera tasinir ama kullanici goremezdi) ·
  `_popupBos` artik **yukleme** ve **hata** durumlarini AYIRT EDER.

- ⚠️⚠️⚠️ **TURU 141 — SILME SINIRI IKI KEZ KOMSU UYEYI GOTURDU.**
  `_cipSeridiBoy` silinirken **`_kategoriSec`**, `_ornekMenu` silinirken
  **`_ornekVitrin`** de gitti. Ikisini de `flutter analyze` yakaladi ve HEAD
  ile geri kondu. Turu 127/138/140'in **DORDUNCU ve BESINCI** tekrari.
  ⚠️ **KURAL (tekrar): bir uyeyi betikle silerken araligin SONRAKI SINIRI
     bir SONRAKI UYE OLMAK ZORUNDA — arada baska uye kalmadigini KESITI
     YAZDIRARAK dogrula.**

- **KALDIGIMIZ YER (30 Agu 16:46): TURU 140 YAYINLANDI — SADECE iOS.**
  ios **33314669971** (**e79460f**), R2 ipa=29848559 (md5 f3136ab1)
  index=7982 (md5 f1e74762) surum.json=48 (md5 4e5a5620),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 140 dizeleri VAR (Kategori ara · Kategoriler · Filtreleme · eşleşen kategori yok) ve turu 139'un pin karti dizesi "Örnek kayıt" YOK; assets/marka altindaki YEDI marka gorseli de IPA'da BIREBIR).
  ⚠️ **IPA 29.576.642 -> 29.848.559 (+271.917 B)** — bu fark eklenen marka
     varliklarinin pakete GERCEKTEN girdiginin ilk kanitidir.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0/0** · test **52/52** · 360 dp x **1.0 / 1.3 / 2.0** -> tasma **0**
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260830-1646

- 🍔 **TURU 140 — YEMEK ORNEKLERI GERCEK MARKALAR + MENU GORSELLERI.**
  Kullanici emri: *"Yemek ornek olarak McDonald's, Burger King, Domino's
  Pizza, Popeyes olsun, ben logolari klasore koyacagim"* + *"yemekte
  isletmenin orada MENULER gorunsun, KARE resim alanlari kategori radus
  mantiginda"*.
  · `assets/marka/` — 3 logo + 4 McDonald's menu fotografi, **280 KB**.
  · `_ornekLogo` (ad -> varlik yolu) · `_ornekMenu` (4 kare gorsel).
  ⚠️⚠️ **POPEYES LOGOSU YOK** (kullanici klasore koymadi) — o kayit kategori
     ikonuna duser, sahte logo URETILMEDI. Dosya gelince `_ornekLogo` +
     pubspec'e BIRER satir.
  ⚠️⚠️ **pubspec'te TEK TEK DOSYA** (`- assets/marka/` DEGIL): turu 116b'de
     olculen 1,27 MiB olu varlik dersinin birebir tekrari olurdu.
  ⚠️⚠️ **VARLIKLAR GIT'E EKLENMEZSE CI TEMIZ KLONDA BULAMAZ** — denetim bunu
     SEVK ENGELI olarak yakaladi: dosyalar diskte vardi, `git status`ta
     `??` idi. `git ls-files mobile/assets/marka | wc -l` = **7** ile
     dogrulandi; IPA icinde de yedisi de BIREBIR bulundu.
  ⚠️ **MARKA HAKKI (durust not):** bunlar tescilli markalar. Ekranda "Örnek"
     etiketi ve profilde *"gerçek işletme değil"* uyarisi DURUYOR, ama bu
     varliklar **YAYIN ONCESI** `kHaritaOnizleme = false` ile BIRLIKTE
     paketten CIKARILMALI.
  ⚠️ Logo `BoxFit.contain` — `cover` DEGIL: burgerking **500x545** (kare
     DEGIL) ve `cover` onu ustten/alttan KIRPIYORDU (olculdu). Kare olan
     ikisi `contain` ile de daireyi tam doldurur.
  ⚠️ `cacheWidth` ZORUNLU: ham 720x720 logo 46 dp'lik kutu icin ~2,1 MB
     gecici RAM demekti (turu 91 dersi).

- 📞 **TURU 140 — KARTTA TELEFON DUGMESI** (kullanici emri: *"haritanin
  soluna telefon ikonu koy"*), kart **300 -> 348 dp**.
  ⚠️⚠️ **NUMARA LISTEDE YOK:** `IsletmeOzet`te `telefon` alani HIC yok ve
     `/isletmeler/yakinimda` SELECT'i `i.telefon` sutununu SECMIYOR (sunucu
     kaynagindan dogrulandi). Kart basina onceden cekmek seritte **12 EK
     ISTEK** olurdu (turu 17 N+1). Bu yuzden numara YALNIZ dokunuldugunda
     `GET /users/{id}/isletme` ile cozuluyor — o uc `telefon` donduruyor ve
     HERHANGI bir kullanici kimligini kabul ediyor.
  ⏳ **BEKLEYEN (sunucu isi):** `/yakinimda` yanitina `telefon` eklenirse ek
     istek kalkar (SELECT + Scan + yanit haritasi UCU BIRLIKTE).
  ⚠️ Ornek kayitta ARAMA YAPILMAZ (uydurma numara cevirmek yanlis birine
     baglardi). Yeniden-girme kapisi (`_araMesgul`) VAR: cift dokunus iki
     istek + iki cevirici acilisi uretirdi.

- 🗑️ **TURU 140 — HARITA PIN KARTI (`_secilenKart`) VE TUM ZINCIRI SILINDI**
  (kullanici emri: *"alttaki isletme kartlarina tikladiginda popup
  cikariyor, onlari kaldir, gereksiz; filtrenin uzerinde popup cikiyor onu
  kaldir"*).
  Silinenler: `_secilenKart` · `_secilen` · `_yukle` sifirlamasi · yigin
  cocugu · `acildi` (turu 136'dan beri OLU) · `secildi` · `secimKapandi` ·
  `_cipSeridiBoy` · `GoogleMap.onTap` · `MedyaGorsel` importu.
  ⚠️⚠️ **PIN DOKUNUSU OLU KALMADI:** `InfoWindow` turu 136'da kaldirilmisti,
     geriye tek eylem karti acmakti. Artik pin dokunusu **KAMERAYI ODAKLAR**
     (`_harita?.animateCamera`) — ekrana geri cagirim gerekmedi.
  ⚠️⚠️ **SILME SINIRI YINE UYE ADIYLA DOGRULANMALI:** `_cipSeridiBoy` silme
     araligi `_kategoriIkonu`a kadar alindi ve ARADAKI **`_kategoriSec`**
     metodunu da GOTURDU. `flutter analyze` yakaladi, git HEAD'den geri
     kondu. Turu 127/138'in **UCUNCU** tekrari.
  ⚠️ `_haritadaGoster` BUDANDI (silinmedi): `_odak` KALDI — turu 139'un
     *"karta dokununca navigator ona gitsin"* emri ona bagli.
  ⚠️⚠️ `_odak` artik **NESIL SAYACI** tasir: yalniz koordinattan olussaydi
     kullanici haritayi elle kaydirip AYNI karta tekrar dokundugunda deger
     degismez ve kamera TASINMAZDI (turu 138'deki `_zoom` deseni).

- 🧭 **TURU 140 — KATEGORI POPUPU ANASAYFA MENUSUYLE BIREBIR + ARAMA.**
  Kullanici emri: *"haritada kategorilere tikladigimda YUKSEKLIKLERI
  ANASAYFADAKI KATEGORILERIN YUKSEKLIKLERI ILE AYNI DEGIL ve IKONLARI
  KALDIR, oradaki gibi yap"* + *"kategoriye tikladiginda orada ARAMA ALANI
  olacak"*.
  · kutu 64 -> **`kKesifKutu` (78)** · ara 6 -> **5** · etiket
    `scale(12)*1.2*2` -> **`scale(14)*1.15*2`** · kutunun ICI **BOS**.
  · Sabitler `isletme_listesi.dart`tan IMPORT edilir, kopyalanmaz.
  · Arama Turkce duyarsiz (`_sadelestir`): `toLowerCase()` "İ" harfini
    birlesik noktaya cevirir ve "İSTANBUL" -> "istanbul"u BULAMAZ.
  ⚠️⚠️ **`_KategoriPopup` AYRI BIR `StatefulWidget` OLMAK ZORUNDA**:
     `TextEditingController`in `dispose`i sheet'in KENDI agacinda olmali.
     Disaridan dispose edilseydi route'un CIKIS ANIMASYONU sirasinda
     *"used after being disposed"* -> **ErrorWidget EKRANI KIRMIZI** boyardi
     (turu 96i, sahada yasandi).
  ⚠️⚠️ Popup kardesleriyle **AYNI SIYAHA** alindi (`kAiZemin` + zorla koyu
     tema + `Builder`) **VE `Material` sarmali** — `Theme` tek basina renk
     BELIRTMEYEN `Text`leri beyaza cevirmez; sarmalsiz haliyle siyah
     popupta kategori adlari SILIK GRI cikiyordu (emulatorde olculdu,
     turu 129 dersi).

- 🖤 **TURU 140 — FILTRE EKRANI TAM SIYAH + CHECKBOX** (kullanici emri).
  `isletme_filtre.dart` -> `isletmeFiltreAc` (projedeki TEK gercek filtre
  ekrani; basligi zaten "Filtreleme").
  ⚠️⚠️ **IKI AYRI ZEMIN KAYNAGI VAR**: sheet `backgroundColor` VE
     `_altDugme`nin kendi `BoxDecoration`i. Yalniz biri degistirilseydi
     ekranin dibinde uyumsuz acik gri bir band kalirdi.
  ⚠️⚠️ **ZORLA KOYU TEMA + `Builder` ZORUNLU**: panelde temadan beslenen ON
     DOKUZ renk var; yalniz zemini siyaha boyasaydik ACIK temada siyah
     zemine `#1A1A1A` yazi (**~1,2:1**) cikardi — turu 135c (1,056:1) ve
     turu 138'in UCUNCU tekrari.
  ⚠️ Checkbox `kYaricap` KULLANMAZ: clamp tabani **8** ve 18 dp'lik kutuyu
     DAIREYE cevirip radio gibi gosteriyordu (emulatorde olculdu) -> 5 dp.
  ⚠️ `ThemeData.dark()` uygulamanin **"dokunma dairesi YOK"** kararini
     (turu 7 kullanici emri) SIFIRLIYOR — `splashFactory`/`splashColor`/
     `highlightColor` ACIKCA geri konur. Ayni ekleme `_altPanel` ve
     kategori popupunda da yapildi.
  📌 "Temizle" dugmesi 360 dp'de **IKI SATIRA sariyordu** ("Temizl / e"):
     `OutlinedButton`un varsayilan 2x24 dp dolgusu 106 dp'lik dugmeye
     sigmiyordu -> dolgu 8 + `maxLines: 1`.

- 🗺️ **TURU 140 — GOOGLE LOGOSU PANELIN ALTINA** (kullanici emri: *"Google
  Maps yazisi gorunuyor, onu kartin altina al — kaldirmak yasak ama kartin
  altina al"*).
  ⚠️⚠️ **KOK NEDEN BIZDIK:** `GoogleMap.padding` hem KAMERAYI hem TUM harita
     UI'ini (logo, pusula, konum dugmesi) "gorunur bolgenin" icine tasir
     (paket kaynagi: Android `googleMap.setPadding`, iOS `_mapView.padding`).
     `altDolgu` = panel boyu oldugu icin logo tam panelin UST KENARINA
     oturuyordu.
  ⚠️ **`EdgeInsets.zero` YAPILMADI** — turu 132'nin UC hatasini geri
     getirirdi. Dolgu yalnizca **`kLogoPay` (30 dp)** kadar KISALTILDI.
  ⚠️ Android/iOS logo olculeri birebir ayni DEGIL — **GERCEK CIHAZDA**
     dogrulanmali.
  ⚠️ **UYUM NOTU:** Google Maps Platform sartlari logoyu ortmeyi yasaklar.
     Karar KULLANICININ; bilerek uygulandi.

- 🔘 **TURU 140 — CIP SERIDI: ARALIK · SAG KENAR · AKTIF HAL.**
  Kullanici emri: *"kategoriler sol sag scrollda SAGDA DIVIN DISINA
  CIKIYOR onu duzelt, aralarini biraz ac, AKTIF OLANDA ikon arkasi BEYAZ,
  ikon arka kare daire rengi olsun"*.
  · aralik cipin `Padding`inden `separatorBuilder`a tasindi: 8 -> **14**
    (cipte kalsaydi son ogeye de uygulanip sag nefesle CIFT SAYILIRDI)
  · **`ShaderMask` ile SAG KENARA SOLMA** — ⚠️⚠️ OLCULDU: sag dolgu TEK
    BASINA YETMEDI, cunku kaydirilabilir listede `padding.right` yalnizca
    SON OGEDEN SONRA yer acar; kaydirirken ortadaki cipler viewport'un tam
    kenarinda YARIDAN kesilmeye devam ediyordu.
  · aktif cipte kutu **BEYAZ**, ikon **kutunun EKRANDA CIZILEN rengi**
    (`Color.alphaBlend(kAiKartYuzey, kAiZemin)`).
    ⚠️⚠️ Ciplak `colorScheme.primary` beyaz uzerinde **1,70:1** ile
       GORUNMUYORDU (denetimde olculdu): panel zorla koyu tema kuruyor ve
       oradaki `primary` M3 tone-80, yani ACIK lavanta.
  · yazi kalinligi **SABIT w700** (secili w800/pasif w600 idi): kalinlik
    degisimi metnin genisligini degistirir ve serit her secimde KAYARDI.

- ⚠️⚠️⚠️ **TURU 140 — YUZEN FILTRE CIPINDE BEYAZ USTUNE BEYAZ (1,00:1).**
  Turu 139'dan kalma: `_yuzenCip` secili dalda zemini `kVurgu` ile
  dolduruyor ama yazi/ikonu **SABIT `Colors.white`** birakiyordu. `kVurgu`
  KOYU temada `Colors.white` dondurur -> uygulama koyu temadayken secili
  cip **TAMAMEN OKUNMAZ**.
  FIX: on plan DOLGUDAN turetilir (`ThemeData.estimateBrightnessForColor`).
  ⚠️ YAPMA: buraya sabit renk yazma.

- ⚠️⚠️⚠️ **TURU 140 — GECICI OLCUM HACK'I KODDA KALMISTI (denetim yakaladi).**
  Emulatorde GPS fix'i hic gelmedigi icin ornek kayitlari gorebilmek adina
  `final k = _konum ?? (enlem: 40.8028, boylam: 29.4307);` konuldu ve
  KALDIRILMASI UNUTULDU. Hemen ustundeki serh *"Konum YOKSA ornek de YOK"*
  diyor, iki satir yukarisi *"sabit Gebze koordinati yazilsaydi baska
  sehirdeki kullanici pinleri HIC goremezdi"* diyordu.
  ETKI: konum izni reddeden Ankara'daki bir kullanici HARITASIZ bir ekranda
  adresi "Gebze, Kocaeli" olan dort isletmeyi **"250 m"** mesafeyle gorurdu.
  ⚠️ **KURAL: olcum icin konulan her gecici satir, commit ONCESI `grep` ile
     ARANIR.** Bu turda `GECICI-OLCUM` isareti kullanildi ve nobetci
     `grep -rn "GECICI-OLCUM" lib/` ile kosuldu.

- 📌 **TURU 140 — DENETIM: 39 AJAN (6 mercek + her bulguya AYRI curutucu),
  33 HAM BULGU -> 18 ONAY, 10 CURUTULDU.** Curutulenlerin cogu, denetim
  kosarken ONLARI ZATEN DUZELTMIS oldugum icin curudu (curutuculer CANLI
  dosyayi okuyor). ⚠️ Bir curutucu, bulgunun "ek kanit" diye sundugu
  `flutter analyze` uyarisinin UYDURMA oldugunu gosterdi ama bulgunun
  cekirdegi (`??` semantigi) ayakta kaldi — **destekleyici delil yanlis
  olabilir, cekirdek iddiayi AYRICA dogrula.**

- **KALDIGIMIZ YER (31 Agu 12:53): TURU 144 YAYINLANDI — SADECE iOS.**
  ios **33378987279** (**816b0e2**), R2 ipa=29679150 (md5 06a293a6)
  index=7982 (md5 6c94f8af) surum.json=48 (md5 04573949),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 144 dizeleri VAR ("Durak ve sefer verisi henüz bağlı değil" ·
  "Merkez – Sanayi" · Benzinlik · Yakınımda).
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **52/52** · emulatorde tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260831-1253

- 🔀 **TURU 144 — PANEL SIRASI DEGISTI + "Yakınımda" CIPI.**
  Yeni sira: **arama -> cip seridi -> kisayollar -> [ayrac] -> isletme
  kartlari** (kullanici: *"arama kategorilerin uzerinde olsun"* + *"eczane
  durak vs ... o yukarida olsun"*).
  · Cip seridinin BASINDA **"Yakınımda"** (bos anahtar): kategori suzgeci
    YOK demek. Kullanici emri: *"hicbir sey aktif olmadiginda HEP
    YAKINDAKILER gorunecek"*.
    ⚠️ `_dalCipi('')` **TOGGLE DEGIL**: bos dal zaten seciliyken dokunus
       yalnizca listeyi acar (toggle olsaydi `_dalSec('')` -> yine bos).
  · `seritVar` kosulundan `_dal.isEmpty` CIKTI. Turu 137'nin *"Tümü'de
    17 kategorinin karisimi anlamsiz"* gerekcesi kullanicinin yeni
    karariyla GECERSIZ.
  ⚠️⚠️ **AYRAC SERITLE BIRLIKTE girer/cikar**: serit yokken panelin dibinde
     ayracin ALTINDA bos siyah band kaliyordu (emulatorde goruldu).

- ⚡ **TURU 144 — KATEGORI GECISI: **KATEGORI BASINA ONBELLEK**.**
  Kullanici: *"haritada kategori secerken cok sert geciyor"*. Kok neden:
  her cip dokunusu `_yukleniyor = true` yapiyor, serit AGACTAN KALKIYOR,
  panel kisalip ag yaniti gelince tekrar UZUYORDU.
  · Yeni `_onbellek` (Map) + `_onbellekAnahtari` (`'$_kategori|$_km'`).
    Onbellek varsa spinner GOSTERILMEZ, liste ANINDA cizilir, istek yine
    atilir ve yanit sessizce guncellenir.
  ⚠️⚠️ **`!_yukleniyor` KAPISI KALDI** (denetim bulgusu): ilk yazimda
     kaldirilmisti ve onbellek ISKALADIGINDA serit + harita pinleri
     **ONCEKI KATEGORIYI** cizmeye devam ediyordu — cip "Kafe" seciliyken
     ekranda market kayitlari duruyordu. `_yukleniyor` artik YALNIZCA
     onbellek iskaladiginda true, yani ziplama geri GELMEZ.
  ⚠️⚠️ **KONUM DEGISINCE ONBELLEK COPE** (denetim bulgusu): baska sehre
     gidip asagi ceken kullanici baska bir cipe dokununca ESKI SEHRIN
     isletmelerini **eski mesafeleriyle** ("250 m") goruyordu.
     Esik ~200 m (0,002 derece) — GPS gurultusu onbellegi bosaltmasin.

- 🎨 **TURU 144 — KISAYOLLAR SADELESTI, KART OLCULERI ESITLENDI.**
  · Kisayollarin renkli **raduslu zemini KALKTI** (kullanici emri); renk
    kimligi artik YAZIDA. `_kisayolBoy` tabani 57 -> **38**.
  · `_altSatirBoy` artik **TUM DALLARDA AYNI** (kullanici: *"yemekte yuksek
    ama hizmetlerde alcak, hepsi esit olsun"*). Onceden vitrinli dallarda
    `kMenuKare`, digerlerinde ~25 dp idi.
    ⚠️⚠️ `_urunSeridi`ndeki **IC ICE IKI `Center`** cipi 56 dp'ye
       GERIYORDU (olculdu): distaki `ListView`in TIGHT kisitini LOOSE'a
       cevirir ama **`Center` loose-bounded kisitta EN BUYUGU ALIR**.
       Icteki kaldirildi, dikey olcu DOLGUDAN geliyor.
  · `kPanelKartEn` 348 -> **372**.
  · **Kart ici menu seridi kartin GERCEK kenarina kadar kayiyor**
    (kullanici: *"menu scroll sagda divine takiliyor"*): yatay dolgu
    kolondan CIKARILDI, ust satir kendi `Padding`ini aldi, seritler kendi
    `padding`ini kullaniyor.

- 🚏 **TURU 144 — DURAK SAYFASI** (kullanici: *"birde durak ekle, otobus
  hatti vs saat SANA BIRAKIYORUM"*). %70 sheet, UC ornek hat + sure.
  ⚠️⚠️ **GERCEK DURAK/SEFER VERISI YOK VE UYDURULMADI**: hat adlari
     JENERIK ("Merkez – Sanayi"), GERCEK bir Gebze hat numarasi YAZILMADI;
     her satirda "Örnek", en ustte *"Durak ve sefer verisi henüz bağlı
     değil"*. Sureler SABIT (5/12/24 dk) — saatten turetilseydi ekranda
     "canli" gorunur ve kullanici GERCEK sanirdi.

- 🔎 **TURU 144 — METINLE ARAMA KATEGORIYI BIRAKIR** (`_metinAra`).
  Kullanici: *"bir sey aradigimda altta ornegin MARKET AKTIF KALIYOR"*.
  ⚠️ `_dalSec('')` KULLANILAMAZ: o metot `_q`yu SIFIRLIYOR — burada TAM
     TERSI gerekiyor.
  📌 Market ikonu `shoppingCart` -> **`store`** (kullanici emri).

- ⚠️⚠️⚠️ **TURU 144 — DENETIM (6 mercek + her bulguya AYRI curutucu, 34
  ajan): 28 HAM BULGU -> 22 ONAY.** En agiri:
  · **YUKSEK — `_panelBoy` govdeden 12 dp KISA**: panelin ALT DOLGUSU
    formulden dusmustu. OLCULDU (gecici widget testi): gercek **600** /
    formul **588** (seritli), gercek **215** / formul **203** (seritsiz).
    Sonucu: yuzen filtre seridi panelin 10 dp USTUNDE degil, yuvarlak ust
    kenarinin **2 dp ICINDE**; ayrica `GoogleMap.padding` 12 dp eksik.
    FIX: **`kPanelAltDolgu` TEK KAYNAK** — govde ve formul ayni sabitten
    besleniyor, ayrisma yapisal olarak imkansiz.
  ⚠️ **DERS (bu turda UCUNCU kez):** panel sirasini degistiren her
     duzenlemede `_panelBoy` formulunu govdeyle **TERIM TERIM** yeniden
     yuru; en kolay dusen terim DIS `Padding`in kendisi.

- **KALDIGIMIZ YER (31 Agu 01:57): TURU 143 YAYINLANDI — SADECE iOS.**
  ios **33340070569** (**fa9fa3e**), R2 ipa=29676621 (md5 878be22b)
  index=7982 (md5 8a682250) surum.json=48 (md5 e109ee90),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 143 dizeleri VAR (Benzinlik · Eczane) ve turu 142'nin
  **"Benzin İstasyonu"** ile menudeki **"Alışveriş"** dizeleri YOK.
  `assets/marka` altinda artik **UC logo** var (dort menu gorseli CIKTI).
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **52/52** · emulatorde 360 dp'de
     tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260831-0157

- ⚠️⚠️⚠️ **TURU 143 — SEVK ENGELI: HARITAYI OYNATAN ASIL YOL `Scaffold`IN
  KLAVYEYLE KUCULMESIYDI** (kullanici: *"aramaya tikladigimda arkada
  haritada oynuyor"*).
  Ilk teshisim `MediaQuery.padding` idi (`padding = viewPadding -
  viewInsets`; klavye acilinca `padding.bottom` SIFIRA duser ve
  `_panelBoy` ~34 dp kisalir). **DOGRUYDU AMA KUCUK OLANI**.
  ⚠️⚠️ Arama sayfasi bir **`PopupRoute`** (`opaque = false`,
     `maintainState = true`) — yani ALTTAKI Scaffold klavye acikken de
     YERLESIME GIRIYOR. Varsayilan `resizeToAvoidBottomInset: true` govdeyi
     klavye kadar (~300 dp) kisaltiyor; harita `Positioned.fill` oldugu
     icin gorunur bolgenin merkezi **~150 dp** yukari kayiyor ve sayfa
     kapaninca GERI ZIPLIYOR.
  FIX: `Scaffold(resizeToAvoidBottomInset: false)` **+** `viewPaddingOf`
  (ikisi AYRI yolu kapatiyor, ikisi de KALIR).
  ⚠️ **GUVENLI**: bu route'ta odaklanabilir HICBIR girdi yok —
     `_panelArama` turu 142'den beri bir `InkWell` DUGMESI; dosyadaki UC
     `TextField` de AYRI sheet route'larinda ve klavyeyi kendileri
     karsiliyor.
  ⚠️ **DERS:** bir "harita/ekran kayiyor" sikayetinde ILK bakilacak yer
     `Scaffold.resizeToAvoidBottomInset`; `MediaQuery` farklari IKINCIL.

- 🔁 **TURU 143 — TURU 142'DE YANLIS ANLASILAN EMIR DUZELTILDI.**
  Kullanici turu 142'de *"kategorileri kaldir, arama butonu tikladiginda
  kategoriler popup acilsin"* demisti; ben CIP SERIDININ TAMAMINI
  kaldirmistim. Kullanici: *"ben o KATEGORI KELIMESINI kaldir dedim, GERI
  GETIR onlari"*. Serit panele geri kondu; kaldirilan yalniz seridin
  basindaki **"Kategori" DUGMESI** (`_kategoriDugmesi`, govdesi
  `// ignore: unused_element` ile DURUYOR). `_panelBoy`a `40 + 12` terimi
  geri eklendi.

- 🧾 **TURU 143 — KART VE MENU SADELESTI** (kullanici emri):
  · isletme kartindaki **MARKA LOGOSU KALKTI** -> kategori ikonu.
    ⚠️ `_ornekLogo` tablosu SILINMEDI: haritadaki **marka logolu pinler**
       (`_markaPinUret`) hala onu okuyor.
  · menu kalemlerinden **GORSEL KALKTI**; `_ornekVitrin` kayit tipinden
    `gorsel` alani TAMAMEN cikarildi. Her kalem artik `kAiKartYuzey`
    zeminli, `kYaricap` radusunde bir **KUTU** icinde [ad / fiyat]
    (kullanici: *"telefon ve harita gibi bir kategori radus mantiginda bir
    karenin icine al"*). Oge genisligi 128, aralik **14 -> 8**.
  · Dort menu fotografi (`menu_*.png`, ~170 KB) artik okunmadigi icin
    **pubspec'ten CIKARILDI** (turu 116b olu-varlik dersi). Dosyalar diskte
    ve git'te DURUYOR.

- 🎨 **TURU 143 — KISAYOL KARTLARI: IKONSUZ, %40 BUYUK, YENI ADLAR.**
  41 -> **57** dp; ikonun tasidigi RENK KIMLIGI kartin KENDI zeminine
  tasindi (`renk.withValues(alpha: 0.14)`), yazi **BEYAZ**.
  Etiketler: *"Nöbetçi Eczane" -> **Eczane***, *"Benzin İstasyonu" ->
  **Benzinlik*** (nobet verisi HALA YOK — kisa ad ustelik daha DURUST).
  ⚠️⚠️ **KELIME ORTASINDAN BOLUNME** (denetim gercek fontla olctu): 360
     dp'de karta 76, metne 64 dp kaliyor; "Benzinlik" olcek 1.3'te 74,9 dp
     istiyor ve Flutter tek kelimeyi **ORTADAN BOLUYOR** — ekranda
     *"Benzinli / k"* cikiyordu (olcek 2.0'da DORDU birden).
     FIX: `maxLines: 1` + `softWrap: false` + **`FittedBox(scaleDown)`**.
     ⚠️ Bedeli BILINIYOR (docs/yazi-olcegi.md): `FittedBox` yazi olceginin
        bir kismini geri alir — kelimeyi bolmekten iyidir, bilincli secim.
  ⚠️ `_kisayolBoy` **TEK KAYNAK** (`_panelBoy` de okur).
  📌 Menudeki ŞEHİR REHBERİ seridinde **"Nöbetçi Eczane" DURUYOR** — orasi
     BASKA bir ekran, kullanici oradan bahsetmedi.

- 🗑️ **TURU 143 — MENUDEN "Alışveriş" KARTI KALDIRILDI** (kullanici emri).
  ⚠️ Kart `kategori: 'market'` aciyordu; o kategori SUNUCUDA ve
     `isletmeKategorileri`nde DURUYOR ve haritadaki cip seridinden
     ("Market") hala ULASILABILIR — veri OLU KALMADI.

- 📌 **TURU 143 — DENETIM (6 mercek + her bulguya AYRI curutucu, 33 ajan):
  27 HAM BULGU -> 19 ONAY, 8 CURUTULDU.** SEVK ENGELI disinda duzeltilen
  UC ORTA bulgu:
  · `_panelBoy`da **`+ 8` HAYALET TERIM** — ikonlu surumdeki
    `vertical: 4` dolgusunun kalintisiydi; dolgu bu turda kaldirilmis ama
    formuldeki karsiligi BIRAKILMISTI (formul govdeden 8 dp UZUN).
  · **`hataBoy` 6 dp KISA** (olculdu: gercek 54,0 dp @1.0-1.3 ve 80,0 @2.0;
    formul 48,0 / 51,6 / 76,2) — blogun altindaki `SizedBox(height: 6)`
    formulde YOKTU. Bu, turu 141'den beri duran bir ayrisma.
  · `_panelArama` DUGMESININ yuksekligi artik `_aramaBoy` ILE AYNI
    KAYNAKTAN (`SizedBox(height: _aramaBoy(c))`): turu 142'de kutu
    `TextField`ken olculen formul, dugmeye cevrilince govdeden ~4 dp
    ayrismisti ve yuzen serit 10 degil ~14 dp yukaridaydi.

- **KALDIGIMIZ YER (31 Agu 00:13): TURU 142 YAYINLANDI — SADECE iOS.**
  ios **33335303325** (**dbce57d**), R2 ipa=29852395 (md5 f1231511)
  index=7982 (md5 d7f8225b) surum.json=48 (md5 f341c7c9),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 142 dizeleri VAR (İşletme veya kategori ara · KATEGORİLER ·
  GEÇMİŞ · İşletme ara) ve 7 marka gorseli `flutter_assets/assets/marka`
  altinda DURUYOR.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** (38 info) · test **52/52** · emulatorde
     360 dp'de tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260831-0013

- 🔎 **TURU 142 — KATEGORI CIP SERIDI KALKTI, GIRIS "ARAMA SAYFASI"NA GECTI.**
  Kullanici emri: *"kategorileri kaldir, ARAMA BUTONU tikladiginda kategoriler
  popup acilsin"* + *"kategori aramasi yerine NORMAL ARAMA olacak, altinda
  KATEGORILER ve GECMIS yazacak"* + *"kategorilerde kartlar %20 kucult"*.
  · `_panelArama` artik DUZENLENEBILIR KUTU DEGIL, **dugme**: uzerinde
    secili kategori/arama metni, sagda temizleme (X).
  · `_AramaSayfasi` (%95): ustte odaklanan normal `TextField` ->
    **GEÇMİŞ** (oturum omurlu, en fazla 8, yazarken GIZLENIR) ->
    **KATEGORİLER** (4 sutun, kutu `kKesifKutu` 78 -> **`kAramaKutu` 62**).
  · Sonuc bir KAYIT: `('dal', anahtar)` ya da `('metin', q)`.
  ⚠️⚠️ **BASLIKLARDA `toUpperCase()` KULLANILMADI** — Dart 'i' harfini 'I'ya
     cevirir ve ekranda **"KATEGORILER"** cikiyordu (emulatorde goruldu).
     Basliklar cagri yerinde BUYUK yazilir.
  ⚠️ `_hizliCipler` **SILINMEDI**, `// ignore: unused_element` ile duruyor:
     bu projede ayni sinif silme DORT kez komsu uyeyi de goturdu.

- 🏷️ **TURU 142 — HARITADA MARKA LOGOLU PINLER** (kullanici emri: *"haritada
  mesela yemek dedigimde IKONLAR DEGIL LOGOLAR gorunmeli, onlarin rengine
  yakin"*).
  · `_markaPinUret()`: `_ornekLogo`daki her varlik `ResizeImage` ile
    26 dp'ye cozulur ve `daireIsaret(foto:, fotoAnahtar:)` ile pine cizilir.
  · Ic dolgu **`_markaRenk`** (McDonald's #DA291C · Burger King #D62300 ·
    Domino's #006491) — saydam PNG'de bu renk gorunur, logo cozulemezse pin
    yine markanin renginde kalir.
  ⚠️ **YALNIZ `demo-` KAYITLARDA**: marka adini tasiyan GERCEK bir isletmeye
     logo basmak kullaniciya YANLIS BILGI olurdu.
  ⚠️ Halka **BEYAZ KALDI** (`daireIsaret` sozlesmesi): harita zemini her
     renkte olabilir, renkli halka acik zeminde kaybolurdu (turu 138).
  ⚠️ FAIL-SAFE: bir logo cozulemezse o marka atlanir, kaydi normal pinle
     cizilir; harita isaretsiz KALMAZ.
  ⏳ **EMULATORDE DOGRULANAMADI**: `adb emu geo fix` verilmesine ragmen
     uygulamaya GPS fix'i GELMIYOR, ornek kayitlar kullanicinin konumundan
     turetildigi icin pinler HIC cizilmedi. **GERCEK CIHAZDA bakilacak.**

- 📋 **TURU 142 — DIGER (kullanicinin tek mesajdaki maddeleri):**
  · navigator ikonu **45° saga** (`Transform.rotate`; ikonun kendisi degil
    CIZIMI donduruldu)
  · kisayol kartlari **%20 buyuk** (34->41 · ikon 17->20 · yazi 11.5->13.5)
  · karttan **PROFIL dugmesi kalkti** (profil zaten KART GOVDESINDEN acilir)
  · menu ogeleri **YATAY KAYDIRILIR** (`ListView.separated`, 14 dp aralik,
    gorselli 168 / gorselsiz 118 dp), ad+fiyat **12 -> 13**
    ⚠️ Bedeli BILINIYOR: ic ice yatay kaydirma, kartin ALT yarisindaki
       suruklemeyi ICTEKI listeye verir (turu 140'ta olculmustu). Kullanici
       kaydirmayi ACIKCA istedi.
  · **%70 liste popupunda perde %54 -> %18**: arkadaki harita GORUNUYOR
    (kullanici: *"isletme listesi cikarken arkadaki harita gorunmesi
    gerekiyor, siyahlasiyor"*) — emulatorde dogrulandi.
  · panel ust dolgusu 12 -> 10 (yuzen serit ile aciklik esitlendi)

- 🧹 **TURU 142 — MENUDEKI "YAKINIMDA" KARTLARI** (kullanici emri: *"yakinimdaki
  ikonlari kaldir, alttaki renkleri de beyaz yap"*).
  `hizmet_menusu.dart` `_yakinKart`: ikon dairesi (34 dp kutu + `KalinIkon`)
  KALDIRILDI, alt satir (mesafe / "Konumu aç") **beyaz**; durum metni yalniz
  OPAKLIKLA (%62) ayriliyor.
  ⚠️ Renk artik TEMADAN gelmiyor. Bu GUVENLI, cunku serit YALNIZ menude
     (`kAiZemin`, sabit siyah) ciziliyor. ⚠️ Serit acik zeminli bir ekrana
     tasinirsa yazi GORUNMEZ olur — o gun renk yine temadan turetilmeli
     (turu 115b dersi).
  ⚠️ `b.ikon` modelde DURUYOR (sehir rehberi seridi onu kullaniyor).

- **KALDIGIMIZ YER (30 Agu 03:04): TURU 139 YAYINLANDI — SADECE iOS.**
  ios **33282108280** (**f6b2730**), R2 ipa=29576642 (md5 02025da7)
  index=7982 (md5 c5694820) surum.json=48 (md5 e52376f9),
  purge OK, **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 139 dizeleri VAR (Kategori · Kategoriler · Haritada göster · Ev temizliği · Nakliyat · en uygun) ve turu 138'in "10 km içinde" dizesi YOK (build gercekten yeni).
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0/0** · test **52/52** · 360 dp x **1.0 / 1.3 / 2.0** -> tasma **0**
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260830-0304

- 🗺️ **TURU 139 — HARITA RENKLERI KULLANICININ VERDIGI EKRAN GORUNTUSUNDEN.**
  Kullanici bir **Yandex Navigator koyu tema** ekran goruntusu gonderip
  *"harita rengini sana verdigim resimdeki gibi yap, harita renkler baska
  renkler degil"* dedi. `_haritaNavigator` stili o gorselden turetildi ve
  **VARSAYILAN dal** oldu (`haritaStiliSec`).
  ⚠️⚠️ **ACIK/KOYU TEMADAN BAGIMSIZ**: kullanici TEK bir harita gorunumu
     istedi, temaya gore renk degistirmesini DEGIL. Ayarlar > Harita'daki
     `gri`/`gece` secenekleri DURUYOR (geri donus yolu kapanmadi).
  ⚠️ `_haritaStili` (Google varsayilani + yalniz `poi.business` kapali)
     artik hicbir daldan cagrilmiyor ama SILINMEDI — "sade Google haritasi"
     bir daha istenirse tek satirla geri gelir (`// ignore: unused_element`).
  ⚠️ Muhafiz (`test/harita_stili_test.dart`) YESIL: yeni stilde
     `poi.business` disinda `visibility: off` YOK ve tum renkler gecerli
     `#RRGGBB`. ⚠️ Gecersiz hex'i Google **SESSIZCE DUSURUR** — ilk yazimda
     `#2e3category` ve 8 haneli `#44528097` yazilmisti, muhafiz yakaladi.

- 🔘 **TURU 139 — HARITA USTU DUGMELERI TEK KAYNAKTAN** (`_haritaDugmesi`).
  Kullanici emri: *"geri navigator + − bunlarin raduslerini KATEGORI RADUS
  MANTIGINI yap, %15 BUYUT, ikonlari 1 TIK KALINLASTIR"* + *"bu siyahi biraz
  daha KAPA, arkasi cok gorunuyor"*.
  · `CircleBorder` **DEGIL** `kYaricap` (kategori kartlariyla ayni dil;
    referans Yandex'te de dugmeler squircle)
  · 48 -> **55**, zoom 44 -> **51** (%15)
  · ikon **`KalinIkon`** — Lucide bir FONT'tur, `strokeWidth` YOKTUR;
    kalinlik ayni renkte ±0.4 px **dort golge** ile simule edilir (turu 93)
  · zemin siyah **%45 -> %62** (`kHaritaDugmeAlfa`)
  ⚠️ Dort dugme de AYNI yardimciyi kullanir; ayri ayri yazilsaydi biri
     degisince oteki geride kalirdi (bu ekranda ayni sinif IKI KEZ oldu).

- 🪪 **TURU 139 — SERIT KARTI YENIDEN KURULDU** (kullanici tarifi birebir):
  solda **kategori dairesi** (radüslü, `kAiKartYuzey`) · saginda **ad** ·
  altinda **yildiz · mesafe** · sagda **profil + harita** ikonlari (radüslü
  daire zemin) · en altta **URUNLER** · kart **230 -> 300 dp**.
  ⚠️⚠️ **KAPAK GORSELI KALDIRILDI**: kullanicinin tarif ettigi duzende yok,
     ustelik ornek kayitlarin (ve gercek kayitlarin cogunun) kapagi bos
     oldugu icin serit BOS GRI KUTULARLA doluyordu.
  ⚠️⚠️ **KART GOVDESI ARTIK HARITAYA ODAKLANIR** (kullanici emri: *"alttaki
     isletme kartina dokununca navigator ona gitsin"*). Profil SAGDAKI
     dugmeden acilir — iki eylem AYRI.
  ⚠️⚠️ **DURUST SINIR — GERCEK KAYITTA URUN ADI YOK.** `/yakinimda` yaniti
     yalniz `urunSayisi` + `minFiyatKurus` tasir; kart basina
     `/users/{id}/urunler` cagirmak seritte **12 EK ISTEK** olurdu (turu
     17'de kapatilan N+1). Bu yuzden: **ornek** kayitta (`demo-`) ornek urun
     adlari · **gercek** kayitta sunucunun VERDIGI bilgi ("N ürün" · "en
     uygun X TL") · ikisi de yoksa **ilce**.
     ⚠️ YAPMA: gercek kayda uydurma urun adi yazma.
  ⚠️ **YEDI KATEGORI notr `store` ikonuna dusuyordu** (giyim · diyetisyen ·
     emlak · spor · teknoloji · eglence · hizmet). Kartin sol dairesi ARTIK
     bu ikona dayandigi icin ayni ekranda yedi ayni daire cikiyordu —
     hepsine ayri ikon verildi (popupta OLCULDU).

- 🧭 **TURU 139 — "Filtre" -> "Kategori" + %95 POPUP; YUZEN FILTRE SERIDI GERI.**
  Kullanici emri: *"filtre yerine KATEGORI koy, tikladiginda popup acilsin
  %95 kategoriler olsun · filtreleri yine getir alttaki ana kartin ustune
  10 px yukarda ESKISI GIBI"*.
  ⚠️⚠️ Turu 138'in **%50'lik filtre paneli SILINDI** — girisi "Kategori"ye
     devredildigi icin ULASILAMAZ kalirdi ve bu projede olu arayuz yasak.
  ⚠️⚠️ Yuzen cip **PANELDEKI `_cip` OLAMAZ**: o cipin ZEMINI YOK (siyah
     panelin ustunde duruyor). Yuzen serit HARITANIN ustunde ve harita her
     renkte olabilir -> her cipin KENDI koyu hapi var, zemin ust bardaki
     dugmelerle AYNI sabitten (`kHaritaDugmeAlfa`).
  ⚠️ `_yuzenCipler` **`Widget?` DONER**: kategorisiz acilista
     `SizedBox.shrink()` donmek yigini **0x0**'a dusurup EKRANIN TAMAMINI
     beyaz birakiyordu (turu 136'da olculdu). Cagri yerindeki
     `if (cipler != null)` kapisini KALDIRMA.

- 📍 **TURU 139 — KENDI KONUM PININDE PROFIL FOTOGRAFI** (kullanici emri:
  *"bizim kendi navigasyonumuz yerine de resmimiz olsun, mevcut profildeki
  resmi koy"*) + beyaz halka **2.0 -> 1.5 dp**.
  · `daireIsaret(foto:, fotoAnahtar:)` — fotograf **ic daireye kirpilir**
    (`clipPath`), `BoxFit.cover` mantigi ELLE (kaynagin KISA kenarindan
    kare parca) — tam gorseli vermek dikdortgen avatari EZERDI.
  · `_avatariCoz` **`myProfileProvider.future`** kullanir, `valueOrNull`
    DEGIL: `initState`te profil HENUZ yuklenmemis olur ve fotograf HIC
    cizilmezdi (bu projede "olu ozellik" sinifinin en sik koku).
  · `ResizeImage` + `thumb_url` + **8 sn zaman asimi**: pin 26 dp, ham
    1600x1600 cozum ~10 MB gecici RAM demekti (turu 91 dersi).
  ⚠️⚠️ **ONBELLEK ANAHTARI FOTOGRAFI DA ICERIR** (`fotoAnahtar` = media id):
     `ui.Image` her cozumde YENI nesnedir, anahtar olamaz; olmasaydi
     kullanici avatarini degistirince pin ESKI fotografta kalirdi.
  ⚠️ Cozulemezse pin ESKI haline (mor daire + navigasyon ikonu) duser —
     kullanici konumunu HER DURUMDA gorur.
  ⚠️ **EMULATORDE DOGRULANAMADI**: test hesabinda avatar YOK ve emulatorde
     GPS fix'i hic gelmiyor. Gercek cihazda bakilacak.

- ⚠️⚠️ **TURU 139 — INDIR SAYFASI SAATI: SUNUCU YINE DOGRU CIKTI (YEDINCI KEZ).**
  Kullanici *"indir sitesinde saat yazmiyor, goremiyorum"* dedi; canli sayfa
  OLCULDU: `text/html` + `no-cache, no-store, must-revalidate` +
  `cf-cache-status: DYNAMIC`, saat **5 yerde**, en ustte `buyuksaat`
  (`id="surumsaat"`) ve `surum.json` ile BIREBIR ayni deger.
  ⚠️ Yani govde onbellekten gelse bile kullanicinin OKUDUGU saat DOGRU olur
     (turu 115c nobetcisi calisiyor). Kalan tek aciklama, kullanicinin
     ana ekrana eklenmis ESKI bir kisayoldan girmesidir — bu yuzden adres
     HER YAYINDA `?v=` ile verilir.
  ⚠️ YAPMA: sayfaya sekizinci bir saat ogesi ekleme; sorun sunucu tarafinda
     DEGIL.

- **KALDIGIMIZ YER (29 Agu 23:48): TURU 138 YAYINLANDI — SADECE iOS.**
  ios **33273957218** (**032e567d**), R2 ipa=29568389 (md5 4298835f)
  index=7982 (md5 6110f929) surum.json=48 (md5 1eee2ac9), purge OK,
  **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 138 dizeleri VAR (Filtre · Mesafe · 10 km içinde · Listele ·
  Yakınlaştır · Uzaklaştır) ve "Mekân ve adres ara" YOK.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0/0** · test **52/52** · 411 dp x1.0 ve 360 dp x1.3/x2.0
     emulatorde tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260829-2348

- 🖤 **TURU 138 — HARITA PANELI SIYAH + CIPLER YENIDEN** (kullanici emri).
  · Zemin **`kAiZemin`** (menu/GebzemAI ile TEK KAYNAK).
  · ⚠️⚠️⚠️ **`Builder` TEK BASINA YETMEDI** (turu 136 dersinin DEVAMI):
    `_cip` · `_filtreDugmesi` · `_panelSeridi` · `_panelKarti` ·
    `_kartDugmesi` · `_ulasimKartlari` `context`i STATE'ten okuyordu ve
    koyu temayi HIC gormuyordu -> emulatorde **SIYAH ZEMINDE KOYU GRI YAZI**.
    Alti metoda da `BuildContext c` parametresi eklendi.
    ⚠️ **KURAL: bir alt agaci `Theme` ile sarmak yetmez — o agaci CIZEN
       metotlar da `Theme`in ALTINDAKI context'i ALMALI.**
  · Cipler: **kenarlik YOK** · ikon `kYaricap`li daire icinde · daire zemini
    **`kAiKartYuzey`** (menudeki kategori kartinin TA KENDISI) · yazi 13->14.
  · **"Tümü" cipi ve turu 137'nin %95 popupu KALDIRILDI**; secili cipe
    TEKRAR dokunmak kategoriyi birakir (TEK yol, serhte yazili).
  · **Yuzen suzgec seridi KALDIRILDI**; serit basinda **Filtre** dugmesi
    (aktif suzgecte NOKTA) -> **%50 yukseklikte filtre paneli**
    (Mesafe · Puan · Diğer + Listele/Temizle).
    ⚠️⚠️ **`Container` `alignment` VERILINCE EN BUYUK BOYUTU ALIR** —
       filtre cipleri TAM GENISLIK kaplayip alt alta diziliyordu
       (emulatorde goruldu). `alignment` kaldirilip `Row(mainAxisSize.min)`.
  · Serit kartlari 200 -> **230 dp**, kapak 100 -> **112 dp**.

- 📍 **TURU 138 — PIN YENIDEN CIZILDI** (`harita_daire_pin.dart`):
  halka **3 -> 2 dp** · **GOLGE KALDIRILDI** · cap 22 -> **26** (ikon icin) ·
  ic renk marka morunun ACIK varyanti (`Color.lerp(morLogo, beyaz, 0.22)`,
  sabit hex YOK) · **ICINE KATEGORI IKONU**.
  ⚠️ Ikon bir FONT glifi: `TextPainter` + **`fontFamily` VE `fontPackage`
     BIRLIKTE** verilmezse "tofu" (bos kare) cizilir.
  ⚠️ Ikon SECILI KATEGORIDEN gelir; kategori degisince `didUpdateWidget`
     ile YENIDEN URETILIR (uretim onbellekli).
  ⚠️ Kendi konum isareti KOYU mor + `navigation` ikonu — isletme pinleriyle
     ayni renk+ikon olsaydi kullanici kendini isletme sanardi.
  ⏳ **DURUST SINIR: emulatorde Google Maps KAROLARI cizilmiyor** (Play
     Services 400) — yeni pin gorunumu GERCEK CIHAZDA dogrulanmali.

- ➕ **TURU 138 — HARITA ZOOM DUGMELERI** ust bardaki "konumuma dön"un
  ALTINDA. ⚠️ Google'in `zoomControlsEnabled` dugmeleri KULLANILMADI (sag
  altta cizilir, orasi panelin altinda kalir). ⚠️ Istek bir **SAYAC**
  (`_zoom`): bayrak olsaydi ayni yone IKINCI dokunus "deger degismedi"
  sayilip SESSIZCE yok sayilirdi.

- ⚠️⚠️⚠️ **TURU 138 — SUREC HATASI (turu 127'nin BIREBIR TEKRARI).**
  `_filtreSatiri`i silen betik serh sinirlarini yanlis buldu ve ARADAKI
  `_ustDugmeler` · `_kategoriSec` · `_kategoriIkonu` · `_cip` metotlarini da
  GOTURDU. `flutter analyze` yakaladi; metotlar git HEAD'den geri kondu,
  olusan iki KOPYA tanim ayri adimda temizlendi.
  ⚠️ **KURAL: bir metodu betikle silerken sinirlari SERH ISARETIYLE degil,
     ONCEKI VE SONRAKI UYE ADIYLA dogrula; silmeden once kesiti YAZDIR.**

- **ONCEKI (29 Agu 19:26): TURU 137 YAYINLANDI — SADECE iOS.**
  ios **33262397311** (**d21ab275**), R2 ipa=29562109 (md5 00d85398)
  index=7982 (md5 f8ef41f9) surum.json=48 (md5 51f6f5ca), purge OK,
  **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE.
  IPA'da turu 137 dizeleri VAR (Marmara Otel · Gebze Palas · Anadolu Sofrası ·
  Form Spor Salonu · Bowling Merkezi · Otel & Konaklama · Kategoriler · Profil)
  ve KALDIRILANLAR YOK (Mekân ve adres ara · İşletmen mi var? ·
  Türkiye 1 - 0 Almanya).
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **52/52** · 411 dp x1.0 ve 360 dp
     x1.3/x2.0 emulatorde tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260829-1926

- 🗺️ **TURU 137 — HARITA ALT PANELI YENIDEN KURULDU** (kullanici emri).
  · **MEKAN ARAMA KALDIRILDI**: kutu + `AramaPaneli` (`yakinimda_arama.dart`
    SILINDI) + `_arama` + `_q` + yalnizca onun kullandigi `_kucult`.
  · **CIPLER = TUM ISLETME KATEGORILERI** (`isletmeKategorileri` TEK
    KAYNAGINDAN, `diger` elenir). Otel · Emlak · Spor · Teknoloji · Eglence ·
    Kuafor · Guzellik · Egitim · Giyim haritada ILK KEZ gorunuyor.
    ⚠️ **"Etkinlik" KONMADI (DURUST SINIR)**: etkinlik bir ISLETME KATEGORISI
       degil, `/yakinimda` onu tanimaz; cip konsaydi DAIMA BOS liste gelirdi.
  · **"Tümü" -> POPUP, ekranin %95'i** (`isScrollControlled` +
    `FractionallySizedBox(0.95)`; varsayilan sheet tavani 9/16 ve izgara
    KIRPILIRDI — turu 90b/115c). Icinde 4 sutunlu kategori KARTLARI.
    ⚠️ Kategoriyi birakma yolu KAYBOLMADI: popuptaki "Tümü" karti.
  · **PANELDE YATAY ISLETME SERIDI** (yalniz kategori seciliyken):
    kapak/kategori-ikonu + ad + onay tiki + "4,8 ★ · 250 m · Örnek" +
    **[Profil]** ve **[harita]** dugmeleri. Harita dugmesi kamerayi o
    isletmeye tasir (`_odak`) ve pin kartini acar.
    ⚠️ **EN YAKIN ONCE**; mesafesi BILINMEYEN kayit DAIMA SONA (turu 122'de
       ilan fiyatinda birebir ayni tuzak).
    ⚠️ `kPanelSeritTavan = 12` — 60 kart yan yana kapak COZERDI (turu 91).
    ⚠️⚠️ **SERIT VARKEN ULASIM KARTLARI CIZILMEZ**: ikisi birden 360x640'ta
       paneli ~330 dp'ye cikariyor ve haritaya ~240 dp kaliyordu. Kategori
       birakilinca ulasim geri gelir. ⚠️ YAPMA: ikisini ayni anda cizmeye
       donme — once 360 dp'de OLC.
  · **ORNEK ISLETMELER ARTIK HER KATEGORI ICIN** (17 x 4 tablo, YALNIZ
    secili kategori uretilir). Onceden bes sabit kayit vardi ve "Otel"e
    dokunan kullanici BOS harita goruyordu.
  ⚠️⚠️ **OLCULEN TASMA: 0.8 px.** Serit yuksekligi paysiz hesaplaninca
     *"RenderFlex overflowed by 0.800 pixels"* cikti — Flutter satir kutusunu
     YUKARI yuvarlar, `fontSize * height` carpimi TAM vermez.
     `ceilToDouble() + 1` payi eklendi (turu 121/123'un ayni dersi).

- **ONCEKI (29 Agu 16:49): TURU 136 YAYINLANDI — SADECE iOS.**
  ios **33255555906** (**7779204**), R2 ipa=29566036 (md5 e70347da)
  index=7982 (md5 6ab92617) surum.json=48 (md5 ea6e8457), purge OK,
  **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE,
  `plugins.flutter.dev/google_maps` IPA'da VAR.
  IPA'da turu 136 dizeleri VAR (Köşe Fırın · Bahar Market · Marmara Kuaför ·
  Yıldız Eczanesi · Teknik Oto Servis · Örnek kayıt · "Bu bir örnek kayıt —
  gerçek işletme değil.") ve turu 135'in CTA karti YOK (İşletmen mi var? ·
  Ücretsiz ekle... · Bilgilerini, saatlerini...).
  Turu 135 temizligi de duruyor: PİYASA ve "Türkiye 1 - 0 Almanya" YOK,
  "Yeni Restoran" VAR.
  ⚠️ **APK ALINMADI** — R2'deki apk turu 121 surumunde (21 Agu).
     📌 Indir sayfasindaki Android dugmesi sayfanin saatini gosterdigi icin
        APK'yi OLDUGUNDAN YENI gosteriyor.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **52/52** · emulatorde tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260829-1649

- 🏪 **TURU 136 — ISLETME KARTLARI FILTRENIN USTUNDE YATAY SERIT**
  (kullanici DUZELTMESI: *"yemege tikladigimda mesela ISLETMELER kart
  seklinde filtrenin uzerinde cikmasi gerekiyordu, sol sag scroll"*).
  ⚠️⚠️ **TURU 135 YANLIS ANLAMISTI**: oraya "İşletmen mi var?" diye bir
     ISLETME HESABI kisayolu konmustu. Kullanici hesabi degil
     **ISLETMELERIN KENDISINI** kart olarak istiyormus. O kart KALDIRILDI
     (hesap girisi Ayarlar ve profilde DURUYOR).
  · `_isletmeSeridi` + `_seritKarti`: kapak + kampanya rozetleri + ad +
    onay tiki + `vitrinSatiri(kompakt)`. Parcalar izgara kartiyla ORTAK.
  · Veri **listenin beslendigi AYNI kumeden** (`_gosterilen`): ayri istek
    YOK, suzgecler seride de uygular, seritte gorulen listede de bulunur.
  · `kSeritTavan = 10` — sinirsiz olsaydi 60 kart yan yana kapak COZERDI.
  · ⚠️ **TASMAYA KAPALI**: kapak `Expanded`, metinler SABIT -> yazi olcegi
    buyudukce KAPAK kuculur, kart boyu DEGISMEZ. 360 dp x 1.0/1.3/2.0
    emulatorde olculdu, tasma 0.

- 🗺️ **TURU 136 — HARITADA ORNEK ISLETMELER + PINE DOKUNUNCA KART.**
  · `kHaritaOnizleme` (⚠️ **YAYIN ONCESI `false`**) bes ornek isletme
    uretir; koordinatlar **KULLANICININ KONUMUNA GORE** turetilir (sabit
    Gebze koordinati yazilsaydi baska sehirdeki kullanici pin goremezdi).
  · Kimlikler **`demo-` onekli**: karta dokunmak profil ACMAZ ("Bu bir
    ornek kayit"), ayrica kartin ICINDE "Örnek kayıt" ibaresi VAR.
  · Ornekler suzgeclerin ONUNE eklenip AYNI suzgecten gecer (turu 121d:
    demo ilanlar suzgeci atlayip listede kaliyordu).
  · `InfoWindow` KALDIRILDI; pin dokunusu yalnizca KARTI acar, profile
    gitmek icin KARTA dokunmak gerekir (turu 85b'nin "gezinme ONAYLI eylem
    olmali" gerekcesi KORUNDU).
  · Kart yuzen cip seridinin USTUNE konumlanir; secim `_yukle`de sifirlanir
    **ve** `_gorunen`de yoksa YAPISAL OLARAK cizilmez (suzgecler `_yukle`
    cagirmiyor).

- ⚠️⚠️⚠️ **TURU 136 — `Stack`E 0x0 NON-POSITIONED COCUK KOYMAK EKRANIN
  TAMAMINI SILER (emulatorde olculdu, BISECT ile bulundu).**
  Kart ilk yazimda yigina KOSULSUZ ekleniyor, secim yokken
  `SizedBox.shrink()` donuyordu. `Yakinimda` yigininin diger cocuklarinin
  HEPSI `Positioned`; **`RenderStack` boyutunu YALNIZCA positioned OLMAYAN
  cocuklarindan hesaplar** -> tek 0x0 cocuk yigini **0x0**'a dusurdu ve
  harita, dugmeler, cipler, panel HICBIRI cizilmedi.
  ⚠️ **HATA SESSIZDI**: `flutter analyze` temiz, `flutter test` 52/52,
     logcat'te TEK istisna yok. Yalnizca EKRANA BAKINCA gorunur.
  FIX: `_secilenKart()` **`Widget?`** doner, yigina `if (kart != null)`
  ile girer.
  ⚠️⚠️ **AYNI SINIFTAN ONCEDEN VAR OLAN MAYIN DA KAPATILDI:**
     `_yuzenCipler()` `_kategori` bosken `SizedBox.shrink()` donuyordu —
     kategorisiz acilista (`const YakinimdaEkrani()`) ekran komple beyaz
     kalirdi. O da `Widget?` yapildi. (O giris bugun menude cizilmiyor,
     yani sahaya cikmamisti; mayin YERINDE duruyordu.)
  ⚠️ **KURAL: bir `Stack`in cocuklarindan biri kosullu ise, bos dalda
     `SizedBox.shrink()` DEGIL `null` don ve cagri yerinde `if (x != null)`
     ile ekle** — hele diger cocuklarin hepsi `Positioned` ise.

- ⏳ **TURU 136 — DURUST SINIR:** emulatorde Google Maps **KAROLARI
  CIZILMIYOR** (Play Services `AppCertManager 400`) ve GPS fix'i gelmiyor;
  pinlerin haritadaki gorunumu **GERCEK CIHAZDA** dogrulanmali. Kart ve
  veri katmani olculdu (`gorunen=5 ornek=5` + kart ekran goruntusunde).

- **ONCEKI (29 Agu 14:31): TURU 135 YAYINLANDI — SADECE iOS.**
  ios **33249806065** (**44b04f3a**), R2 ipa=29561605 (md5 4705fbdb)
  index=7982 (md5 50afeea1) surum.json=48 (md5 668ecf3f), purge OK,
  **CDN UCU DE BIREBIR**, iOS min **16.0**, `MapsApiKey` ENJEKTE
  (`GMSServices` + `plugins.flutter.dev/google_maps` iki ikilide de VAR),
  IPA'da turu 135 dizeleri VAR (İşletmen mi var? · İşletmeni yönet ·
  Ücretsiz ekle, müşterilerin seni burada bulsun · Yeni Restoran) ve
  KALDIRILANLAR YOK (Türkiye 1 - 0 Almanya · Arda Turan · PİYASA ·
  Bitcoin · Cumhuriyet · ÇEVİR · Yeni Restourant).
  ⚠️ **APK ALINMADI** (kullanici emri: *"ios build al"*) — R2'deki apk
     turu 121 surumunde. 📌 Indir sayfasindaki Android dugmesi sayfanin
     saatini gosteriyor, yani APK'yi OLDUGUNDAN YENI gosteriyor.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI, e2e KOSULMADI.
  ✅ analyze **0 hata 0 uyari** · test **52/52** · emulatorde tasma **0**
     (360 dp x olcek 1.0/1.3/2.0).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260829-1431

- 🧹 **TURU 135 — UYDURMA VERI TASIYAN IKI EKRAN SILINDI** (kullanici emri:
  *"piyasa verilerini kaldiralim gerek yok · sliderdeki mac olayini da
  kaldir, slider bos olsun, sol sag scroll, 1-2 tane daha ekle"*).
  · `kur_serit.dart` (1457 satir) — dolar/euro/altin/bitcoin seridi + grafik
    paneli. **Her sayisi uydurmaydi**; projede kur/emtia verisi ne tabloda
    ne bir ucta ne de bir dis servis anahtarinda var.
  · `skor_detay.dart` (573 satir) + menudeki mac karti + `assets/vitrin/re1.jpg`
    (156.911 B, pubspec girdisiyle birlikte).
  ✅ Boylece **"yayin oncesi `kKurOnizleme`/`kSkorOnizleme` false yapilacak"**
     borclarinin IKISI DE kapandi. Kalan TEK onizleme bayragi
     `kYakinOnizleme` (YAKINIMDA kartlarindaki uydurma isletme adi/mesafe).
  ⚠️ `kIkonKutusu` + `KalinIkon` `kur_serit.dart`TA tanimliydi ve YAKINIMDA
     kartlari onlari kullaniyor -> dosya silininde menu DERLENMEDI;
     ikisi de `hizmet_menusu.dart`a tasindi.
  ⚠️ **SLAYT SAYISI ARTIK SUNUCUDAN GELMIYOR** (`kMenuSlaytAdedi = 3`):
     eski `_menuSlaytProvider` `/isletme-kesif` cagiriyordu ve istek
     patlarsa slider **TAMAMEN KAYBOLUYORDU**. Icerigi olmayan bir yer
     tutucu icin kabul edilemez. Turu 77 kurali burada gecerli DEGIL:
     bu sayi hicbir sorguyu/yetkiyi/siralamayi beslemiyor.

- 🏪 **TURU 135 — FILTRE SERIDININ USTUNE ISLETME KARTI** (`IsletmeListesiEkrani`;
  kullanici emri: *"filtrelemenin uzerine kart ekle, isletme ile ilgili"*).
  Hesap isletme DEGILSE **"İşletmen mi var?"** (3 adimli sihirbaz), isletmeyse
  **"İşletmeni yönet"** — `IsletmeDuzenleEkrani`nin kendi `_sihirbaz` ayrimiyla
  BIREBIR.
  ⚠️ **"One cikan isletme" YAPILMADI**: sunucuda one cikarma/sponsorluk/
     siralama olcutu YOK; rastgele bir kaydi oyle gostermek yanlis bilgi olurdu.
  ⚠️ `hesap_turu` bilinmiyorsa kart CIZILMEZ (null) — yoksa isletme sahibine
     bir kare boyunca "isletmeni ekle" denirdi. Kart ustundeki bosluk da bu
     karara bagli oldugu icin `build`de TEK KEZ hesaplanip tasiniyor.
  📌 **PARITE NOTU (denetimde soruldu, CURUTULDU):** kart yalniz bu ekranda;
     Ilan/Etkinlik'te zaten `FloatingActionButton.extended` ("İlan ver" /
     "Etkinlik oluştur") var, Talep ekraninda kullanici TALEP EDEN taraf.
     Kapisi OLMAYAN tek ekran Isletme'ydi. Paylasilan slot listesinde tek
     dp degismedi.

- ⚠️⚠️⚠️ **TURU 135c — DENETIM (22 ajan, 6 mercek + her bulguya AYRI curutucu):
  16 ham bulgu -> 2 ONAY, 14 CURUTULDU.** En agiri:
  · **MENU SLIDERI ACIK TEMADA GORUNMUYORDU (1.056:1).**
    `_slider`/`_kart`/`_yakinKart`/`_selamlama` `build`in KENDI `context`ini
    aliyordu; ekranin koyu `Theme`i o `build`in DONDURDUGU agacta, yani
    context'in **ALTINDA**. `Theme.of` yalniz ATA elemanlari gezer ->
    `kAiKartYuzey(context)` UYGULAMANIN temasini cozuyordu.
    Hata turu 129'dan beri LATENT'ti; turu 130-134 boyunca o slot OPAK bir
    fotograftı (mac karti), turu 135 fotografi kaldirinca acik temada
    200 dp'lik BOS blok kaldi -> turun MANSET EMRI olu dogacakti.
    **FIX: `SafeArea` altina `Builder`** (dort cagri yeri birden duzeldi)
    + slaytin ICI BOS oldugu icin opaklik YALNIZ sliderda 0.12 -> **0.20**
    (`kSlaytAlfa`; `kAiKartYuzey`e `alfa` parametresi eklendi, varsayilan
    DEGISMEDI — kartlarin 0.12'si GebzemAI balonuyla ayni kalmali).
    ✅ **OLCULDU (ekran goruntusunun GERCEK pikselleri):** slayt `#2E2839`,
       zemin `#050308`, **1.446:1** ve deger acik/koyu UYGULAMA temasinda
       BIREBIR AYNI (tema bagimliligi yapisal olarak bitti).
    ⚠️ YAPMA: `Builder`i kaldirip `build`in context'ini asagi gecirme.
  · **`myProfileProvider` hatasi SUREC OMRU BOYUNCA onbellekleniyor** ->
    isletme karti sebep soylemeden kayboluyordu; `_tazele` (asagi-cek)
    profile HIC dokunmuyordu, yani tam gerektigi anda no-op oluyordu.
    FIX: `_tazele` artik `ref.invalidate(myProfileProvider)` de yapiyor.
    (Saglayicinin KENDISI degistirilmedi: 15+ tuketici, arayuz turu.)

- ⚠️⚠️⚠️ **TURU 135b — `TextPainter` OLCUMU YAZI TIPINI TASIMIYORDU**
  (emulatorde goruldu: 360 dp + olcek 1.3 -> *"BOTTOM OVERFLOWED BY 20
  PIXELS"*, yani TAM BIR SATIR).
  `_altKategoriSeridi` yukseklik olcumunu CIPLAK bir `TextStyle` ile
  yapiyordu; `fontFamily` yoksa `TextPainter` platform varsayilanina
  (**Roboto**) duser, cizilen `Text` ise temadan **Google Sans** alir.
  Google Sans ayni puntoda DAHA GENIS: "Lahmacun" Roboto'da tek satira
  siger, Google Sans'ta IKI satira sarar -> olcum BIR SATIR EKSIK cikardi.
  Olcek 1.0'da gorunmuyordu. **Repodaki TEK `TextPainter` kullanimi burasi.**
  FIX: olcum stili `Text`in yaptigi seyin AYNISI ile uretilir —
  `DefaultTextStyle.of(context).style.merge(...)`. Elle `fontFamily`
  YAZILMADI (tema ailesi degisirse olcum yine geride kalirdi).
  ⚠️ **KURAL: `TextPainter` ile bir sey olcerken stili DAIMA ortamdaki
     `DefaultTextStyle`den turet.** (Turu 121'in *"uygulamanin fontu
     Roboto DEGIL"* dersinin OLCUM tarafindaki karsiligi.)

- 📌 **TURU 135 — "Yeni Restourant" -> "Yeni Restoran"** (turu 121d'den beri
  bekleyen yazim hatasi). Etiket YALNIZ ekranda; suzgec anahtari `f.puansiz`
  oldugu icin sunucu sozlesmesine dokunulmadi.
  ⏳ **HALA BEKLIYOR (kullanici karari):** hizli erisim kartlari (Gece Kuşu ·
     Yeni Restoran · 4+ · Şimşek) ve Teslimat/Min. tutar filtreleri YEMEGE
     OZEL ama TUM `IsletmeListesiEkrani` kategorilerinde gorunuyor.

- 📌 **TURU 135 — ARTIFACT DOGRULAMASINDA "YOK" CIKAN DIZE HER ZAMAN HATA
  DEGIL.** IPA'da `Her gün sıfırlanır.` / `Bugün kalan hakkın` arandi ve
  YOK cikti; kaynakta ISE VARDI. Kok neden: `_kalanHakKarti` **turu 127'de
  kullanici emriyle cagri yerinden cikarilmis**, govdesi
  `// ignore: unused_element` ile BILEREK birakilmis -> Dart AOT onu
  agactan budadi. Yani "YOK" dogru cevapti.
  ⚠️ **DERS: bir dize eksik cikinca once `git log -S` ile CAGRI YERINI ara**;
     ayni dosyadan cagrilan baska bir dize (`GebzemAI’a sorun`) VAR cikiyorsa
     yontem saglamdir, eksik olan KODUN KENDISIDIR.

- **ONCEKI (21 Agu 13:24): TURU 123 YAYINLANDI — SADECE iOS.**
  ios **32471646528** (**b475bac**), R2 ipa=29542814 (md5 827f2616)
  index=16637 (md5 0477a095) surum.json=48 (md5 74a4561b), purge OK,
  **CDN UCU DE BIREBIR**, debug imza YOK, HARITA=true, IPA de turu 123
  dizeleri VAR (Eğitim & Atölye · İş & Networking · Sanat & Sergi).
  ⚠️ **APK ALINMADI** (kullanici emri) — R2 deki apk turu 121 surumunde.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI.
  ✅ analyze **0/0** · test **52/52** · emulatorde tasma **0**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260821-1324

- 🧩🧩 **TURU 123 — BUTUN KATEGORILER YEMEGIN BIREBIR AYNI SLOT LISTESINDE.**
  Kullanici **BES KEZ** soyledi ve her seferinde eksik yapildi.
  Yemek`in slot listesi (REFERANS):
    header -> arama -> SLIDER -> (BASLIKSIZ) 4x2 KUTU IZGARASI ->
    serit basligi + 60x60 SERIT -> **TEK** cip seridi -> "X (N)" +
    gorunum secici -> liste
  ⚠️⚠️ **"AYNI" DEMEK: Yemek`te OLMAYAN hicbir sey OLMAYACAK.** Onceki
     turlarda yalniz EKLEME yapildi, KALDIRMA yapilmadi — hata buydu.

  **ILAN**: slider GERI GELDI · "Kategoriler" bolum basligi KALDIRILDI.
  ⚠️ Turu 106 slideri kaldirmisti ve GEREKCESI HAKLIYDI: o zaman
     `VitrinSlider(dikey: _tur)` vardi ve sunucu emlak icin ISLETME,
     digerleri icin ETKINLIK donduruyordu. **BILESEN DEGISTI**: artik
     Yemek`in kullandigi `KategoriSlider` + `/isletme-kesif`
     (kategoriye ozel METIN slaytlari) — icerik ILGILI.

  **HIZMET / DUGUN / ORGANIZASYON**: "Hangi hizmeti almak istiyorsun?"
  baslik blogu ve "NASIL CALISIR 1-2-3" blogu **KALDIRILDI** (Yemek`te YOK)
  · "Kategoriler" basligi KALDIRILDI · SLIDER eklendi (aramanin ALTINA).
  ⚠️ Kartlara dokununca SIHIRBAZ acilmasi AYNEN duruyor (kullanici emri:
     *"hizmet karti koyarsin tiklayinca step step olur"*).

  **ETKINLIK**: kategoriler CIP degil **KUTU IZGARASI** (Yemek`teki kesif
  izgarasinin yeri) · **UC AYRI cip seridi -> TEK serit**.
  ⚠️ Onceki serh *"bu ekranda kategori GORSELI yok, kutu bos kalirdi"*
     diyordu — ama Yemek/Ilan/Hizmet`te de kutular GRI ve altlarinda yazi
     var. Ayni dil. Serh GECERSIZDI.

  ⚠️⚠️ **OLCULDU: 0.1 px TASMA.** Kutu adlari iki satira sigmayinca
     ("Eğitim & Atölye", "Yemek & İçecek") sari-siyah serit cikiyordu.
     `TextPainter` satir yuksekligini YUKARI yuvarlar -> **DORT izgaranin
     dordune de +1 dp pay**. Emulatorde logcat tasma sayisi **0**.

  📌 Menudeki TUM kategoriler tarandi: yalniz **DORT** ekran var —
     `IsletmeListesiEkrani` (REFERANS: Yemek·Restoran·Cafe·Alisveris·
     Egitim·Saglik·Otel·Kuafor·Guzellik·Emlak·Spor·Teknoloji·Eglence) ·
     `IlanListesiEkrani` (Ilan·Is Ilanlari) · `TalepAkisiEkrani`
     (Hizmet·Dugun·Organizasyon) · `EtkinlikListesiEkrani`. Dordu de hizali.
     (`YakinimdaEkrani` harita ekrani — tasarimi BEKLENIYOR.
     `GebzemAiEkrani` sohbet ekrani, kategori DEGIL.)

- ⏳ **TURU 123 — BEKLEYEN (kullanici karari):** hizli erisim kartlari
  (**Gece Kuşu · Yeni Restourant · 4+ · Şimşek**) ve **Teslimat / Min. tutar**
  filtreleri YEMEGE OZEL ama TUM `IsletmeListesiEkrani` kategorilerinde
  gorunuyor — Egitim/Otel/Saglik`ta ANLAMSIZ. Kartlarin yalniz ETIKETI degil
  **ISLEVI** de yemege ozel (`isletme_filtre.dart`: `teslimatTavanDk`,
  `minTutarTavanKurus`, `geceAcik`, `puansiz`) — kategoriye gore
  kart/filtre kumesi gerekiyor. 📌 "Yeni Restourant" YAZIM HATASI (Restoran).

- **KALDIGIMIZ YER (21 Agu 12:36): TURU 122 YAYINLANDI — SADECE iOS**
  (kullanici emri: *"sadece iosa cikart android gerekli degil"*).
  ios **32467883403** (**820d72d**), R2 ipa=29543078 (md5 3b9785e9)
  index=16444 (md5 93d9393f) **surum.json=48 (md5 43fb97fb)**, purge OK,
  **CDN UCU DE BIREBIR**, debug imza YOK, `HARITA=true` logda, IPA de turu
  122 dizeleri VAR (Taleplerim ( · Anlaşıldı · Pahalıdan ucuza · Ucuzdan
  pahalıya · Henüz talebin yok.).
  ⚠️ **APK ALINMADI** — R2 deki `gebzem.apk` turu 121 (11:32) surumunde KALDI.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, DB TRUNCATE EDILMEDI.
  ✅ analyze **0/0** · test **52/52**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260821-1236

- 🧩 **TURU 122 — HIZMET EKRANI DA AYNI ISKELETE GECTI.**
  Kullanici: *"butun kategoriler AYNI OLACAK ayni mantik, ILAN VE HIZMETLER
  AYNI DEGIL; hizmetlerde hizmet karti koyarsin tiklayinca STEP STEP olur"*.
  Kategori kartlari + sihirbaz ZATEN vardi; eksik olan ekranin GERI KALANIYDI
  (ne cip ne liste). Eklendi: **cip seridi** (Tümü · Açık · Anlaşıldı) +
  **Taleplerim (N)** + talep listesi + asagi-cek + hata dalinda Tekrar dene.
  ⚠️ Cip degerleri SUNUCUNUN `ilanlar.durum` kumesinden (`yayinda`/`satildi`);
     UYDURMA durum YOK. Suzgec ISTEMCIDE: uc `durum` parametresi ALMIYOR ve
     liste tek istekte geliyor (60 tavani, sayfalama yok) — durust.
  ⚠️ Bos durum IKI DALLI: suzgec bosalttiysa sebebini soyler + Filtreleri
     temizle; hic talep yoksa OGRETICI metin ("yukaridaki kartlardan birine
     dokun").
  ⚠️ Sag ustteki "Taleplerim" girisi KALDIRILMADI (kapanmis talepler orada).

- 🔀 **TURU 122 — ILANA SIRALAMA** (Yemekteki "Sıralama" cipinin ILAN
  karsiligi): Yeniden eskiye · Ucuzdan pahaliya · Pahalidan ucuza.
  ⚠️⚠️ Yemekteki Puan / Teslimat suresi / Min. tutar ilanda **KARSILIKSIZ**
     (o alanlar ilanda YOK) — uydurulmadi. Ilanin olculebilir tek alani FIYAT.
  ⚠️⚠️ **SUNUCUDA SIRALAMA PARAMETRESI YOK** (`/ilanlar` sabit
     `ORDER BY i.created_at DESC`) -> siralama **ISTEMCIDE**. Durust cunku
     liste TEK ISTEKTE geliyor: siralanan kume kullanicinin gordugu kumenin
     TAMAMI.
  ⚠️⚠️ **FIYATI GIZLI/BELIRSIZ ILANLAR DAIMA SONA.** Aksi halde "ucuzdan
     pahaliya" listesi 0 TL gorunenlerle baslar ve "en ucuzlar" gibi okunurdu
     — kullaniciya YANLIS BILGI.
  ⚠️ Kopya liste uzerinde siralanir: gelen liste yerinde degistirilseydi
     siralamayi kapatmak eski sirayi GERI GETIREMEZDI.

- **KALDIGIMIZ YER (21 Agu 11:32): TURU 121 YAYINLANDI** — android
  **32462458270** + ios **32462461406** (**7c7afdc**), R2 apk=121287562
  (md5 5c17c0fa) ipa=29536904 (md5 6ce92718) index=17250 (md5 1fd67ebf)
  **surum.json=48 (md5 cf9c4c74)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, `HARITA=true` iki logda da, iki artifactte de turu 121
  dizeleri VAR (Fiyat aralığı · En az (TL) · TL üstü · Ücretsiz · Büyük/Küçük
  kartlar · Filtreleri temizle · Alanlar · Bölümler · Reyonlar).
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, **DB TRUNCATE EDILMEDI** (hesaplar durur).
  ✅ `flutter analyze` **0/0** · `flutter test` **52/52**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260821-1132

- 🎨 **TURU 121 — TUM KATEGORILER TEK KABUKTA** (kullanici emri: *"yemek
  kategorisini REFERANS yaptik, diger tum kategoriler AYNI MANTIKTA olacak,
  sadece icerik farkli"*). Yeni `features/isletme/kategori_kabuk.dart`:
  `KategoriKabugu` (44 dp header + AltMenu + CustomScrollView) · `kabukArama`
  · `kabukBolumBasligi` · `KabukCip`/`kabukCipSeridi` · `KabukGorunumSecici`
  · `kabukIzgaraOlcu` · `kabukBosluk`. Ilan, Etkinlik, Dugun/Hizmet (talep)
  bu kabuga gecti.
  ⚠️ **OLCULER KOPYALANMAZ, IMPORT EDILIR** (`isletme_listesi.dart` /
     `isletme_kart.dart`) — biri degisince hepsi birlikte doner.
  ⚠️ Menuden **Isletmeler · Topluluklar · Diyet** KALDIRILDI (kullanici emri).
     Topluluklara giris Mesajlar "+" menusunde DURUYOR. Diyet TAKIBI istemcide
     TAMAMEN yok; `diyetisyen` ISLETME KATEGORISI kaldi (o bir meslek).

- ⚠️⚠️⚠️ **TURU 121d — YAYIN ONCESI DENETIM 37 GERCEK HATA BULDU** (52 ajan,
  6 mercek + her bulguya AYRI curutucu; 46 ham -> 37 ONAY, 9 CURUTULDU).
  Build ALINMISTI ve YAYINLANMADI; duzeltilip YENIDEN alindi. *"Build ALMAK
  yayinlamak DEGILDIR"* dersinin **SEKIZINCI** dogrulanmasi. En agirlari:
  · ⚠️⚠️ **FIYAT/ILCE SUZGECI ORNEK ILANLARA HIC UYGULANMIYORDU.**
    `kDemoAkis` acik oldugu icin listedeki ilanlarin cogu ornek;
    "1.000 TL alti" cipi acikken **985.000 TL luk ornek daire listede
    KALIYORDU** -> turun MANSET ozelligi BOZUK gorunecekti. Ustelik liste hic
    bosalmadigi icin ayni turda eklenen "Filtreleri temizle" dali da HIC
    cizilmiyordu.
    ⚠️ `demo_ilan.dart` serhi ZATEN *"suzgecler SUNUCUDAKIYLE AYNI
       mantikta uygulanir"* diyordu — serh vardi, GOVDE UYMUYORDU.
    ⚠️⚠️ **KURAL: `_yukle` icinde sunucuya giden HER suzgec AYNI cagride
       demo dalina da gecer**, yoksa her yeni suzgec demo uzerinde SESSIZCE
       olur.
    ✅ **OLCULDU: 22 ilan -> 3** (kalan uc "Fiyat belirtilmemiş" =
       sunucudaki `fiyat_gizli` yukleminin birebir karsiligi).
  · ⚠️⚠️ **ILAN KUTU IZGARASI/SERIDI REFERANSTAN DRIFT ETMISTI**: kenarlik
    **2 dp `scheme.primary`** (referans 1.6 dp `kVurgu`), yazi
    **11/w500-w800** (referans 13/w600). Ayni ekranda kutular MOR, cipler
    SIYAH kenarlikliydi.
    ⚠️ `kVurgu` serhi (`isletme_kart.dart`) bu ekranlarda `primary`
       kullanmayi ACIKCA yasakliyor.
    ⚠️ Kalinlik SABIT olmali: w500<->w800 metni genisletir ve serit KAYAR.
  · ⚠️⚠️ **ETKINLIKTE `_gecmis` SUZGEC SAYILIYORDU** — o bir SEKME.
    Sonuc: *"Geçmiş etkinlik yok."* dali **ULASILAMAZ OLU KOD**, "Filtreleri
    temizle" kullaniciyi HABERSIZCE Yaklasan sekmesine atiyordu. Ayrica
    `_arama` ve `_benim` GORUNMEZ SUZGECTI. Gecmis e gecerken `_zaman`
    SIFIRLANIR (cizilmeyen bir cip ASLA suzmemeli).
  · **KABUKTAKI `KabukKutuIzgara`/`KabukKutuSerit` HICBIR YERDEN
    CAGRILMIYORDU** -> SILINDI. ⚠️ Olu bir "tek kaynak" drift i ONLEMEZ,
    yalnizca serhi YALANCI yapar. Gerekce dosyada YAZILI (uc cagri yeri
    yapisal olarak farkli: box vs sliver).
  · **`kabukCipSeridi` de `Center` YOKTU** -> cipler 32 degil **40 dp**
    ciziliyordu (turu 96 da olculerek duzeltilen hatanin tekrari). `ListView`
    cocuguna DIKEYDE TIGHT kisit verir; dokunma alani 40 dp KALIR.
  · **Fiyat paneli dugmeleri jest cubugunun ALTINDA**: `viewInsets` YALNIZ
    klavyeyi olcer. `SafeArea(top: false)` eklendi.
    ⚠️ `showModalBottomSheet(useSafeArea: true)` COZMEZ — SDK da o bayrak
       `SafeArea(bottom: false)` uretir.
  · **ILAN bos-liste sirasi**: `_favori`/`_benim` dallari ONDEYDI ->
    *"Henüz favori ilanın yok"* YALANI. `_suzgecVar` artik **ACILIS TURUNE
    GORE** (`_tur != widget.tur`): "İş İlanları" ekraninda kullanici hicbir
    sey secmeden "filtrelere uyan ilan yok" yaziyordu.
  · Kucuk karttan silinen kayit listede kaliyordu -> `_detayAc` TEK KAYNAK.
  · `ilanAgaciProvider` hatasi SUREC BOYU onbellekleniyordu (keepAlive) ->
    "Tekrar dene" (kardes Talep ekraninda ZATEN vardi).

- ⚠️⚠️ **TURU 121d — "MUTFAKLAR" BASLIGI 17 KATEGORIDE DE SABITTI.**
  Egitim ekraninda *"Dershane · Kurs · Dil"* seridinin USTUNDE de
  **"Mutfaklar"** yaziyordu (emulatorde goruldu). Kullanici emri YEMEK
  ekrani icin verilmisti; bu ekran 17 kategoriye hizmet ediyor.
  FIX: `_altBaslik` — yemek/kafe **Mutfaklar** · saglik/guzellik/diyetisyen
  **Bölümler** · egitim **Alanlar** · kuafor/oto/hizmet **Hizmetler** ·
  market/giyim/teknoloji/eczane **Reyonlar** · digerleri notr **Türler**.
  ⚠️ Sunucu bu basligi DONDURMUYOR ve bu tur ARAYUZ TURU oldugu icin uca
     dokunulmadi. Turu 77 kurali BURADA GECERLI DEGIL: yalnizca GORUNEN bir
     etiket, hicbir sorguyu/yetkiyi/siralamayi beslemiyor.

- ⚠️⚠️ **TURU 121 — IZGARA HUCRE YUKSEKLIGI ORANDAN DEGIL ICERIKTEN.**
  Yemek teki `childAspectRatio: 0.86` kopyalanmisti ama orada ad altinda
  **IKI** bilgi satiri var, ilan/etkinlikte **BIR** -> hucrenin altinda
  **~58 dp BOSLUK** kaliyordu. `kabukIzgaraOlcu` icerikten turetiyor.
  ⚠️⚠️ ILK YAZIMDA CARPANLAR TAHMINDI (1.25/1.30) ve emulatorde
     **"BOTTOM OVERFLOWED BY 3.9 PIXELS"** cikti: uygulamanin fontu Roboto
     DEGIL. Artik hem kart hem olcu AYNI sabiti okuyor
     (`kKucukKartAdStili` / `kKucukKartBilgiStili` / `kKucukKartSatir`)
     + **1 dp pay** (`TextPainter` yukari yuvarlar). Olcek **1.0 ve 1.3 te**
     emulatorde dogrulandi.
  ⚠️ YAPMA: kartta `height:` vermeden bu olcuyu kullanma.

- ⚠️⚠️⚠️ **TURU 121 — ARTIFACT DIZE ARAMASINDA UCUNCU KODLAMA: LATIN-1.**
  Dart AOT dizeleri UC bicimde saklar: saf ASCII -> UTF-8 · **Latin-1 e SIGAN
  dize -> OneByteString (LATIN-1 baytlari)** · sigmayan -> UTF-16LE.
  `Ücretsiz` · `TL üstü` · `Büyük kartlar` (tek Turkce harfi **ü**,
  Latin-1 de VAR) ilk aramada **"YOK"** dondu ve build ESKI SANILDI.
  `Yakınımda` (**ı** Latin-1 de YOK -> UTF-16) kontrol dizesi sayesinde
  yakalandi.
  ⚠️ Arama betigi UC KODLAMAYI DA denemeli (turu 90b nin UTF-16 dersinin
     devami). ⚠️ Kontrol dizesi OLMADAN dogrulama yapma.

- ⏳ **TURU 121 — BEKLEYEN (kullanici karari):** hizli erisim kartlari
  (**Gece Kuşu · Yeni Restourant · 4+**) ve **Teslimat / Min. tutar**
  filtreleri YEMEGE OZEL ama 17 kategoride de ayni gorunuyor —
  Egitim/Otel/Saglik ta ANLAMSIZ. "Mutfaklar" basligiyla AYNI SINIF ama daha
  buyuk: kartlarin yalniz ETIKETI degil **ISLEVI** de yemege ozel
  (`isletme_filtre.dart`: `teslimatTavanDk`, `minTutarTavanKurus`,
  `geceAcik`, `puansiz`). 📌 "Yeni Restourant" ayrica YAZIM HATASI
  (Restoran).

- **KALDIGIMIZ YER (21 Agu 00:00): TURU 120 YAYINLANDI** — android
  **32415748368** + ios **32415760198** (**1fdfb7c**), R2 apk=121469022
  (md5 e2d49533) ipa=29563764 (md5 c98ad8fd) index=16388 (md5 b9d3976f)
  **surum.json=48 (md5 001261e3)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK (iki logda da 0), `HARITA=true` iki logda da, iOS
  `MinimumOSVersion` + `MapsApiKey` ENJEKTE, iki artifactte de turu 120
  dizeleri VAR (Biraz da senden · Kaç yaşındasın? · Tuttuğun takım ·
  Kocaelispor · Gebzespor · Tanıtımı yeniden göster · Akse Digital).
  ✅ **BACKEND DEPLOY** (36e7c77) + migration **049** canlida + health ok +
  **CANLIDA 390/390 UCTAN UCA** (turu 120 kontrollerinin 8i de KOSTU ve
  gercek degerlerle gecti: dogum_yili=1998 · ilgi tekrarsiz · takim ·
  profil ucu · kismi PATCH koruyor · bos dizi temizler · sacma yil duser ·
  tavan 12). `flutter analyze` **0/0** · `flutter test` **52/52** ·
  go build+vet+test temiz.
  ⚠️ **SEMA ADDITIVE (049 yalniz sutun ekliyor) -> DB TRUNCATE EDILMEDI**
     (hesaplar ve profiller duruyor).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260821-0000
  ⚠️⚠️ **IPA'DA HAM ZIP ARAMASI YANLIS YONTEM** (bu turda ogrenildi):
     kontrol dizesi *"Yakınımda"* bile YOK donuyordu. IPA icindeki
     `App.framework/App` **DEFLATE** ile sikistirilmis; APK'da `libapp.so`
     **Stored** oldugu icin ham arama ORADA calisiyor. Dogrulama IPA
     **ACILARAK** yapilir. (Turu 90b'nin *"once BILINEN bir dizeyle
     yontemi sina"* dersi tam da bunu yakaladi.)

- ⚠️⚠️⚠️ **TURU 120 — KAYIT AVATARI SESSIZCE KAYBOLUYORDU (bu sinifin
  **ONUNCU** tekrari; ONCE OLCUM koyularak bulundu).**
  Emulatorde kayit tamamlandi, hesap acildi, profil goruldu — AVATAR YOKTU.
  Sunucuda `avatar_media_id` BOS, `media_assets`te yeni satir YOK: yani
  `POST /media/presign` **HIC CAGRILMAMIS**. Uc adim da `return`le sessizce
  cikiyor, disarida tek `catch (_) {}` vardi — HANGI adimda kirildigini
  soyleyen HICBIR IZ yoktu.
  ✅ `_avatarHatasi()` (debugPrint + **GERCEK Sentry olayi**) eklendi ve kok
     neden TEK SATIRDA cikti:
     *"Bad state: Cannot use \"ref\" after the widget was disposed."*
  **KOK NEDEN:** `kayitTamamla` OTURUM ACAR; oturum degisince router yeniden
  cozer ve ekranin `ConsumerState`i SOKULUR. Sonraki `ref.read(...)`
  `StateError` firlatir, `catch` yutar, fotograf kaybolur.
  ⚠️ **FIX (uc katman):** (a) `medyaServisi`/`api`/`auth` ILK await`ten ONCE
     yakalanir — is artik `ref`e degil parametreye bagli, ekran gitse bile
     TAMAMLANIR; (b) **kirpilmis kare de hesaptan ONCE** yakalanir
     (`toImage()` CANLI bir `RenderRepaintBoundary` ister); (c) yukleme
     oncesindeki `if (!mounted) return;` KALDIRILDI — o kapi tam bu
     senaryoda fotografi atardi.
  ⚠️ Sikistirma artik **EN IYI CABA**: `gorseliHazirla` null donerse PNG ham
     yuklenir (`image/png` beyaz listede VAR; yakalanan kare Flutter uretimi
     oldugu icin **EXIF/GPS TASIMAZ**, temizlige gerek yok).
  ⚠️ **DERS (turu 50/56/60/63/64 ortak koku):** *"bu patlarsa TELEMETRIDE
     gorur muyum? Cevap hayirsa ONCE olcumu koy."*

- ⚠️⚠️⚠️ **TURU 120 — ONBOARDING ANIMASYONLARI UYGULAMAYI DONDURUYORDU (ANR).**
  Emulatorde olculdu: `app_time_stats avg=500 ms` (~2 FPS), ardindan
  *"ANR in app.gebzem — Input dispatching timed out ... waited 5026 ms for
  KeyEvent"*. **Dart istisnasi YOKTU**, hata tamamen sessizdi.
  KOK NEDEN: uc animasyon da agaci `AnimatedBuilder`in **GOVDESINDE**
  kuruyordu — `_KartAkisi` 14 karti (golge + gradyan + ikon + iki metin)
  HER KAREDE yeniden insa ediyordu; golge `saveLayer` acar.
  FIX: degismeyen agac **`child:`** ile BIR KEZ kurulur, builder yalnizca
  `Transform.translate` / sahne icerigi / pin katmanini yeniler.
  ✅ **OLCULDU: 500 ms -> 88 ms** (kare sayisi 2-3 -> 10-14).
  ⚠️ YAPMA: bu agaclari tekrar `builder` govdesine tasima.

- ⚠️⚠️ **TURU 120 — `AuthTelefonAlani` DURUMSUZDU, HATA GIRISTE HIC
  GORUNMUYORDU.** Bicim hatasi (`5 ile baslamali`) `build`de
  `controller.text`ten hesaplaniyordu ama widget `StatelessWidget`ti:
  yeniden cizim **EBEVEYNIN `setState`ine** bagliydi.
  · kayit ekrani her tusta KOSULSUZ `setState` cagirdigi icin ORADA
    calisiyordu (emulatorde goruldu),
  · giriste `_temizle()` **yalnizca temizlenecek bir sey varsa** `setState`
    cagiriyor -> temiz formda ILK tusta hicbir sey cizilmiyor ve hata satiri
    **HIC GORUNMUYORDU**.
  FIX: `StatefulWidget` + `controller.addListener` (`didUpdateWidget`te
  denetleyici degisimi; `dispose`ta YALNIZ dinleyici kaldirilir —
  denetleyici CAGIRANA ait).

- 📞 **TURU 120 — `+90` ARTIK METNIN PARCASI DEGIL** (kullanici emri:
  *"+90 SILINMESIN"*). Denetleyici YALNIZ 10 haneyi tutar; on ek
  `prefixText` ile CIZILIR ve silinmesi YAPISAL OLARAK imkansiz.
  ⚠️⚠️ **`floatingLabelBehavior: always` ZORUNLU** (SDK kaynagindan
     dogrulandi, `input_decorator.dart`): `labelShouldWithdraw =
     _labelShouldWithdraw || behavior == always` ve `_AffixText` opakligi
     `labelIsFloating ? 1.0 : 0.0`. Aksi halde **alan bos ve odaksizken
     `+90` GORUNMEZDI**.
  ⚠️ Sunucuya giden numara **YALNIZ `authTamNumara()`** ile uretilir;
     `authNumaraGoster()` SADECE ekran icindir (boslukla gruplar).
  ⚠️ BILINEN SINIR: kullanici basina `90` da yapistirirsa ilk 10 hane alinir
     ve alan ANINDA kirmiziya doner (hata SESSIZ DEGIL).

- ⚠️⚠️ **TURU 120 — `hintStyle` TABAN STILI MIRAS ALIR (emulatorde goruldu).**
  Sifre alani gizliyken `letterSpacing: 5` kullaniyor (daireler ayri
  okunsun) ve o deger IPUCUNA siziyordu: ekranda
  **"E n  a z  6  k a r a k t e r"** yaziyordu. Flutter `hintStyle`i
  `TextField.style` UZERINE **merge** eder; verilmeyen alan TABANDAN gelir.
  FIX: `authAlan` `hintStyle`inda `letterSpacing: 0` ACIKCA.
  ⚠️ `obscuringCharacter: ●` + aralik, `letterSpacing` yasaginin **OTP ile
     ayni sinifta** bilincli istisnasi (kullanici emri).

- ⚠️⚠️⚠️ **TURU 120 — FOTOGRAF KIRPMA "KESIYORDU" (kullanici bildirdi).**
  Turu 119`da cocuk `Image.file(240,240, fit: cover)` idi; `cover` **LAYOUT
  ANINDA** kirpar, yani `InteractiveViewer`in cocugu ZATEN kirpilmis bir
  kareydi. Suruklemek gorselin daha fazlasini GOSTERMIYOR, o kareyi
  kaydiriyordu -> daire kenarinda **BOS ALAN**. Ustelik
  `boundaryMargin: all(120)` buna ACIKCA izin veriyordu.
  FIX: `constrained: false` + cocuk **cover OLCUSUNDE** + `boundaryMargin`
  **ZERO** -> daire HER ZAMAN dolu (yapisal garanti). Baslangic donusumu
  gorseli ORTALAR (`constrained:false` cocugu sol ust koseye koyar).
  + ucte-bir IZGARA cizgileri **`RepaintBoundary`in DISINDA** (icinde
    olsaydi YUKLENEN fotografa da cizilirdi).

- 🎂 **TURU 120 — KAYIT 5 ADIM: "Biraz da senden" (yas · ilgi · takim).**
  migration **049**: `users.dogum_yili` · `ilgi_alanlari TEXT[]` · `takim`.
  ⚠️⚠️ **YAS DEGIL DOGUM YILI**: yas her yil degisir ve onbelleklenmis bir
     profil yil doneminde YANLIS gosterirdi. Yasi ISTEMCI turetir.
     ⚠️ DURUST SINIR: gun/ay sorulmadigi icin yas **±1 yil** hatalidir —
        arayuzde "28 yasinda" DEGIL sadece "28" yazilir.
  ⚠️⚠️ `ilgi_alanlari` **NOT NULL DEFAULT `{}`** ve `profil.TemizIlgi`
     **ASLA nil DONMEZ**: nil dilim SQL NULL`a cevrilir ve NOT NULL sutunda
     `23502` verir — turu 75b`de `posts.media_ids` uzerinde YASANMIS bir
     sevk engeli ("HER yazi gonderisi 500 donuyordu").
  ⚠️⚠️ **`internal/profil` TEK DOGRULAMA KAYNAGI**: ayni kurallar hem
     `/auth/kayit/tamamla` hem `PATCH /users/me` icin gecerli. `users`
     paketi ZATEN `auth`u import ediyor; yardimcilari oraya koymak
     **IMPORT DONGUSU** olurdu.
  ⚠️ `PATCH /users/me`de ucu de **ISARETCI**: "alan gelmedi" ile "bosaltildi"
     ayrimi. Duz tiplerle yazilsaydi yalniz adini degistiren bir istek
     yas/ilgi/takimi SIFIRA EZERDI (turu 85b `isletme_duzenle` sinifi).
  ⚠️ Yas tekerleginin **ILK OGESI BOS ("—") ve VARSAYILAN ODUR**: bir yasla
     baslasaydik, tekerlege HIC dokunmayan kullanicida o deger sunucuya
     GERCEKMIS gibi giderdi.
  ⚠️ Ilgi/takim listeleri **ISTEMCIDE** (turu 77 kurali BURADA GECERLI
     DEGIL: bu alanlar hicbir sorguyu/yetkiyi/siralamayi beslemiyor).
     Sunucu beyaz listeye BAKMAZ, yalniz uzunluk/adet tavani uygular.
  ✅ Veri **PROFILDE GORUNUYOR** (`_profilEtiketleri`) — yoksa form OLU
     olurdu (bu projede o sinif DOKUZ kez sahaya cikti).

- 🎨 **TURU 120 — UYGULAMA IKONU YENI LOGODAN** (`tool/ikon_uret.dart`
  yeniden yazildi, **FAIL-CLOSED**: dort kapinin biri dusse HICBIR DOSYA
  YAZILMAZ).
  · Kaynak artik `assets/icon/logo.png` — uygulama ici logoyla **AYNI
    DOSYA**; onceden `kaynak.jpg`ten uretiliyordu ve iki farkli marka
    gorseli tasiniyordu.
  · `icon.png` = dairenin **IC TEGET KARESI** (kenar = cap/√2): koseden
    koseye gradyan, **%100 opak**. Daireyi oldugu gibi koymak iOS squircle
    maskesi icinde "cikartma" gorunumu verirdi.
  · Ok, **satir bazli zemin renginden EN KUCUK KARELER** ile ayristirildi
    (gradyan dikey; sabit "beyaza yakin" esigi alt uctaki lavantada yanlis
    pozitif verirdi). Olculdu: **bg satir ici en buyuk sapma = 1**.
  · adaptive **arka katman artik GORSEL** (saf gradyan), on katman yalniz
    ok, kanvasin **%40**`i.
  ⚠️⚠️ **`adaptive_icon_foreground_inset: 0` ZORUNLU** — varsayilan 16 idi
     ve `ic_launcher.xml`e `<inset 16%>` yaziyordu; ok kanvasin
     %40 x 0.68 = **%27**`sine dusuyordu. **18 TEM`DEN BERI SESSIZCE BOYLEYDI.**
  🛡️ `test/ikon_varlik_test.dart` (4 kontrol) — inset 0 hem pubspec`te hem
     URETILEN XML`de; **BOZULARAK KANITLANDI**.
  ⚠️ `flutter_launcher_icons` sonrasi pbxproj
     `GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` bozulmasi `git checkout` ile
     geri alinir (arac hatasi).

- 🛡️ **TURU 120 — ACILIS KATMANI EMULATORDE DOGRULANAMADI, TESTLE OLCULDU.**
  Android 12+ kendi acilis ekranini (**siyah zemin + ORTADA UYGULAMA IKONU**)
  uygulamanin ILK KARESINE kadar tutar; debug derlemede `am start -W`
  **14,5 sn** olctu. Iki katman birbirine COK BENZIYOR (siyah + ortada logo),
  yani ekran goruntusu HANGISININ cizildigini **KANITLAMAZ** — "Akse Digital
  yok" diye bakip KOD HATASI sanmak cok kolaydi.
  ⚠️ **DERS:** yanlis yuzeyi olcme; katmani DOGRUDAN kuran testle olc
     (`test/acilis_test.dart`: metin VAR · 23 px · `TextScaler.noScaling` ·
     logo varligi `kAcilisLogo` ile AYNI · katman SOLUYOR).

- 📌 **TURU 120 — KUCUK AMA GORUNUR:** acilis imzasi 13 -> **23 px**
  (`textScaler.noScaling` — marka ogesi her cihazda AYNI durmali) ·
  giriste kucuk **"Tanıtımı yeniden göster"** (`onboardingSifirla` —
  `setBool(false)` DEGIL **`remove`**, temiz kurulumla birebir ayni durum) ·
  baslik 26->28 / aciklama 14.5->16.5 / etiket 13.5->15.5 / deger 16->20 ·
  onboarding gorsel alani %60 -> **%66** (yazi ile noktalar arasinda
  ekranin ~%17`si BOS kaliyordu, 1080x2400`de olculdu) · onboarding "Devam"
  dugmesi **radius 0** (giris/kayit turu 119`da duz koseye gecmisti, burasi
  ATLANMISTI — asimetrinin kendisi hataydi).

- 📌 **MIGRATION NUMARALARI (guncel):** 049 = `users.dogum_yili` +
  `ilgi_alanlari` + `takim`. Sonraki **050**`den.

- **KALDIGIMIZ YER (20 Agu 18:21): TURU 118+119 YAYINLANDI** — android
  **32384092303** + ios **32384110047** (**b9e3e13**), R2 apk=121335022
  (md5 fa423c46) ipa=30301875 (md5 8812d6cb) index=15615 (md5 559cc41f)
  **surum.json=48 (md5 382ad2bc)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, `HARITA=true` iki logda da, iOS min **16.0**,
  `MapsApiKey` enjekte, `acilisZemin` kaynagi APK`de VAR.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, **DB TRUNCATE EDILMEDI**.
  ✅ flutter analyze **0/0** · flutter test **44/44**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260820-1821

- 🎬 **TURU 118 — ONBOARDING ANIMASYONLU** (kullanici emri: *"ekran
  yuksekliginden %60 alanda ornegin yemek alanindaki firmalar KART
  seklinde ASAGIDAN YUKARI gelsin ... diger onboardingde CEKIN IPHONE
  olsun, yapay zekaya soru soruyoruz o da cevapliyor"*).
  · `_KartAkisi` — kategoriler asagidan yukari akar, kenarlarda `ShaderMask`
    ile solma. ⚠️⚠️ Liste **IKI KEZ** cizilir: tek kopyayla dongu sonunda
    liste bir anda asagi ZIPLARDI.
  · `_Telefon` — dynamic island`li cerceve; AI sahnesi (soru -> "yaziyor"
    -> yanit) ve kilit ekraninda gelen arama sahnesi. Tek
    `AnimationController`, her parca kendi araligini `_oran()` ile okur.
  ⚠️⚠️ **`OverflowBox` ZORUNLU** (emulatorde gorundu): liste iki kez
     cizildigi icin `Column` kutudan UZUN; ebeveyn SINIRLI yukseklik
     verdiginden Flutter *"RenderFlex overflowed by 664 pixels"* atip
     SARI-SIYAH serit ciziyordu. Tasma KASITLI, `ClipRect` zaten kirpiyor.
  ⚠️ Alan yuksekligi EKRANDAN turetilir (`maxHeight * 0.6`), sabit dp DEGIL.
  ⚠️ Kartlarda **UYDURMA VERI YOK**: uygulamanin GERCEK kategorileri.

- 🌑 **TURU 119 — ACILIS (SPLASH) EKRANI** `features/auth/acilis_ekrani.dart`
  Siyah zemin · logo ortadan 30 dp yukarida · "Akse Digital" altta ortada
  100 dp yukarida, hafif gri/saydam.
  ⚠️ Bir ROUTE DEGIL, `MaterialApp.router` `builder`inda KATMAN: route
     olsaydi yonlendirme mantigina (oturum/onboarding) karismasi gerekirdi.
  ⚠️⚠️ **EMULATORDE IKI HATA GORULDU:**
     · **Yazi MONOSPACE + SARI ALT CIZGI cikti** — katman
       `Navigator`/`Scaffold` DISINDA yasiyor, orada `DefaultTextStyle`
       YOK ve Flutter metni HATA BICIMIYLE cizer. FIX: `Material` sarmali.
       ⚠️ YAPMA: `Material`i kaldirip yalniz `ColoredBox` birakma.
     · **LOGO GORUNMUYORDU** — sayac `addPostFrameCallback` ile basliyordu;
       ama Flutter ILK KAREYI **Android kendi acilis ekranini HALA
       gosterirken** cizer, yani sure katman GORUNMEDEN akiyordu.
       FIX: `precacheImage` -> gorsel COZULUR, **sonra** sayac baslar.
       ⚠️ `catchError` ile: gorsel yuklenemezse bile sayac baslar, katman
          KILITLENEMEZ.
  ⚠️⚠️ Android`de **GERCEKTE CALISAN DOSYA `drawable-v21/`** — API 21+`de
     `drawable/`i EZER. Yalniz digerini duzeltmek hicbir modern cihazda
     etki etmezdi. `values/colors_acilis.xml` -> `acilisZemin #0B0B0F`;
     Flutter katmaniyla BIREBIR ayni renk olmak ZORUNDA, yoksa acilis
     "yanip soner". iOS `LaunchScreen.storyboard` zemini de siyah.

- 📝 **TURU 119 — KIMLIK EKRANLARI: ALT CIZGILI ALAN** (`auth_stil.dart`)
  `UnderlineInputBorder` **2 px** · etiket **DAIMA USTTE**
  (`floatingLabelBehavior: always`) · odakta MOR, hatada KIRMIZI.
  ⚠️ `always` OLMADAN etiket bos alanda ipucuyla UST USTE binerdi.
  ⚠️ Kalinlik UC HALDE DE 2 px: degisseydi alanin ic yuksekligi oynar ve
     yazi 1 px ZIPLARDI.
  ⚠️ `errorText` KULLANILMADI: kullanici yalniz "input kirmizi olsun" dedi;
     ayrica alan yuksekligi degisip form ziplardi (mesaj SnackBar`da).
  ⚠️⚠️ **IKI ALAN BIRDEN kirmizi olur**: sunucu "telefon veya sifre hatali"
     der, HANGISI oldugunu SOYLEMEZ (numaranin kayitli olup olmadigini
     sizdirmamak icin). Yalniz sifreyi kirmizi yapmak sunucunun SOYLEMEDIGI
     bir sey iddia etmek olurdu. Yazmaya baslayinca temizlenir.
  📌 Dugmelerde **radius 0**. ⚠️ `RoundedRectangleBorder` KALDIRILMADI,
     yaricapi SIFIRLANDI: kaldirilirsa `FilledButton` TEMA yaricapina duser
     (M3: tam hap) ve degisiklik SESSIZCE geri alinir.
  ⚠️⚠️ `kayit_akisi.dart` KENDI `_alan()` kopyasini tasiyordu; giris
     degisince kayit ESKI HALINDE KALDI. `authAlan`a devredildi —
     `auth_stil.dart`in varlik sebebi TAM BUDUR.

- 📷 **TURU 119 — KAYIT DORT ADIM + PROFIL FOTOGRAFI (KIRPMALI)**
  0 telefon · 1 kod · 2 bilgiler · **3 fotograf**. Ilerleme cubugu 3 -> 4.
  ⚠️ Kirpma `InteractiveViewer`: surukleme + iki parmakla yakinlastirma
     hazir gelir; elle `Matrix4` yazmak sinir durumlarini (fling, olcek
     siniri) elde birakirdi. `clipBehavior: none` + `ClipOval` -> DAIRE.
  ⚠️⚠️ Sonuc `RepaintBoundary.toImage()` ile YAKALANIR: kullanicinin
     EKRANDA GORDUGU kare ne ise yuklenen O olur. Matrisi elle cozup ikinci
     bir hesapla kirpmak "gordugum kirpim bu degil" uretirdi.
  ⚠️ Halka `IgnorePointer`: dokunuslar ALTTAKI `InteractiveViewer`a gecmeli,
     yoksa surukleme HIC calismaz.
  ⚠️⚠️ **SIRA ZORUNLU: fotograf HESAPTAN SONRA yuklenir** — `presign`
     OTURUM ister, once denenirse 401 doner.
  ⚠️⚠️ **FOTOGRAF HATASI KAYDI BOZMAZ**: hesap ZATEN kuruldu; istisna
     disaridaki `catch`e duserse kullanici "kayit basarisiz" sanardi.
  ⚠️ `gorseliHazirla` (EXIF/GPS temizligi — sunucu GPS bulursa 422) +
     `MedyaKapisi` kapilari (arama/oda/yayinda galeri acmak cakisir).

- 🎨 **TURU 119b — LOGO HALKASI IKI KEZ DUZELTILDI.**
  Turu 117`de halkaya `kHikayeHalkaGradient` (mor->kirmizi->**TURUNCU**)
  verilmisti; kullanici *"halen turuncu"* dedi ve HAKLIYDI.
  ⚠️⚠️ **IKI FARKLI HIKAYE GRADYANI VAR, KARISTIRMA:**
     · `kHikayePaylasGradient` — kendi "Hikâyen" dairesi, **SIYAH -> MOR**
     · `kHikayeHalkaGradient`  — BASKASININ hikayesi, mor->kirmizi->turuncu
     Logo halkasi BIRINCISINI kullanir; ikisi de `core/theme.dart`ta.
  ✅ **OLCULEREK dogrulandi** (gecici widget testi CIZILEN gradyani okudu):
     `[#14101C, #8B3FFF]`. Eski turuncu/pembe sabitler repoda KALMADI.

- ⚠️⚠️ **TURU 119 — CRLF TUZAGI (turu 89/117`nin ucuncu tekrari).**
  `gebzem_ai.dart` ve `kayit_akisi.dart` **CRLF**; LF ile birlestirilmis
  arama dizeleri ESLESMEDI. **Bu repoda dosyalar KARISIK** — metin
  degistiren her betik satir sonunu **DOSYADAN ALGILAMALI**.

- **KALDIGIMIZ YER (20 Agu 15:16): TURU 117 YAYINLANDI** — android
  **32366701529** + ios **32366715201** (**8fe3f9a**), R2 apk=121169858
  (md5 27864787) ipa=30294476 (md5 cfac1974) index=15834 (md5 b3b43223)
  **surum.json=48 (md5 a455f267)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, iOS min **16.0**, `MapsApiKey` enjekte, IPA da turu 117
  dizeleri VAR (Her gün sıfırlanır. · Bugünlük hakkın doldu · Bir şey sor…),
  `logo.png` MD5 yerelle BIREBIR, olu varliklar HALA pakette DEGIL.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, **DB TRUNCATE EDILMEDI**.
  ✅ flutter analyze **0/0** · flutter test **44/44**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260820-1516

- 🎨 **TURU 117 — LOGO HALKASI = HIKAYE GRADYANI (TEK KAYNAK).**
  Kullanici emri: *"border rengini logo icin STORYDEKI bizim story
  gradient yap"*. Alt menu halkasi AYRI bir uclu kullaniyordu (turuncu
  `#FF9A3C` -> pembe `#FF5E7A` -> mor `#8B3FFF`); hikaye seridi BASKA bir
  uclu (mor -> kirmizi `#FF3B5C` -> turuncu `#FFB03A`). Yani ayni ekranda
  **IKI FARKLI marka gradyani** duruyordu. Ikisi de artik
  `core/theme.dart` -> **`kHikayeHalkaGradient`** okur.
  ⚠️ SIRA ONEMLI (topLeft -> bottomRight): ters cevrilirse logo, hikaye
     seridinin AYNASI olur ve yan yana uyumsuz gorunur.
  ⚠️ YAPMA: renkleri cagri yerlerine kopyalama — zaten TAM BU yuzden
     ayrismislardi.

- 🔍 **TURU 117 — "LOGO UZERINDE SAYDAM CIZGI" ARANDI, YOK.**
  Kullanici *"VARSA kaldir"* dedi; oldugunu VARSAYIP bir sey silmek yerine
  UC YONTEMLE olculdu:
  · kaynak PNG: daire icinde alfa YALNIZ **254 ve 255** (%0,4 fark,
    gorunmez) ve 254ler satir profilinde DAGINIK -> bant DEGIL, PNG
    kodlayici yuvarlamasi
  · cihazda **8x buyutme**: yuzeyde kesinti YOK
  · piksel taramasi (logo merkezinden dikey): 12den buyuk her sicrama TEK
    TEK aciklandi (beyaz ok girisi/cikisi, halka, siyah cubuk) —
    **aciklanamayan gecis YOK**
  📌 Muhtemel sebep ONCEKI halkaydi: sol ustte TURUNCU basliyordu ve mor
     logonun kenarinda cizgi gibi okunuyordu.
  ⚠️ DERS: "varsa kaldir" denen bir sey once **OLCULUR**; olmayan bir seyi
     "duzeltmek" gercek bir seyi bozar.

- 📱 **TURU 117 — GEBZEMAI EKRANI YENIDEN KURULDU.**
  · geri tusu **`arrowLeft`** (gonder `arrowUp`un sola cevrilmisi).
    ⚠️ Varsayilan `BackButton` KULLANILMADI: platforma gore degisir
       (Android ok / iOS chevron) ve "gonder gibi" olmazdi.
  · baslik ORTADA, **20 px** (22den 2 kucuk), **w700**.
    ⚠️ `centerTitle: true` ACIKCA veriliyor — tema geneli `false`.
  · **GIRIS ALANI TEK KUTU**: ustte yazi, ALTINDA eylem satiri (solda
    `imageUp`, sagda gonder).
    ⚠️⚠️ `prefixIcon`/`suffixIcon` KULLANILMADI: metinle AYNI SATIRDA
       durur ve cok satirli girdide DIKEY ORTALANIR — 5 satirlik soruda
       ikonlar ortada asili kalirdi. Kullanici ACIKCA *"yazi YUKARIDA,
       ikonlar ALTINDA"* dedi.
    ⚠️ `TextField` KENDI cercevesini cizmez (`InputBorder.none`) — yoksa
       CIFT cerceve olurdu.
    ⚠️ Kenarlik ODAKTA marka rengine doner; **kalinlik 1.5te SABIT** —
       1 -> 2 gecisi kutunun IC olcusunu degistirir ve yazi 1 px ZIPLARDI.
    ⚠️ `FocusNode` dinleyicisi `dispose`ta KALDIRILIR + node birakilir.
  · **KALAN HAK KARTI**: 17 px w800 sayi + ilerleme cubugu + "Her gün
    sıfırlanır." Hak bitince kart `scheme.error` rengine doner.
    ⚠️ Eskiden %45 saydam 12,5 px gri bir satirdi — ekrandaki EN ONEMLI
       sayi EN SILIK ogeydi.
    ⚠️ Sayi UYDURULMAZ: `ai` null ise kart HIC cizilmez.
  ⚠️⚠️ `Expanded`/`Spacer` KULLANILMADI: govde `ListView`, dikey kisit
     SINIRSIZ -> *"BoxConstraints forces an infinite height"* ve ekran
     BOMBOS acilirdi (turu 115bde olustur menusunde birebir yasandi).

- ⚠️⚠️ **TURU 117 — CRLF TUZAGI (turu 89un tekrari).** `gebzem_ai.dart`
  **CRLF** satir sonu kullaniyor; LF ile birlestirilmis arama dizeleri
  ESLESMEDI ve betik "YOK" dedi. **Bu repoda dosyalar KARISIK** (bazi LF,
  bazi CRLF) — metin degistiren her betik satir sonunu **DOSYADAN
  ALGILAMALI**.

- **KALDIGIMIZ YER (20 Agu 14:29): TURU 116 YAYINLANDI (YENI LOGO)** —
  android **32362818658** + ios **32362833143** (**acffd73**), R2
  apk=121169134 (md5 c2cbf981) ipa=30282405 (md5 35f54828) index=15553
  (md5 82dd1025) **surum.json=48 (md5 35062ce5)**, purge OK,
  **CDN DORDU DE BIREBIR**, debug imza YOK, `HARITA=true` iki logda da,
  iOS min **16.0**, `MapsApiKey` enjekte, IPA'da turu 116 dizeleri VAR.
  ⚠️ **BACKEND DEGISMEDI** -> deploy YOK, **DB TRUNCATE EDILMEDI**.
  ✅ flutter analyze **0/0** · flutter test **44/44** (40 -> 44).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260820-1429

- 🎨 **TURU 116 — UYGULAMA ICI LOGO DEGISTI** (kullanici verdi: `logo2.png`,
  1600x1600 RGBA, mor gradyanli TAM DAIRE + beyaz gonder oku).
  Eski `logo.png` renkli bir **Threads yer tutucusuydu** ve mor markayla
  celisiyordu. Logo **TEK YERDE** cizilir: `alt_menu.dart` -> `_logo`.
  ⚠️ **KOD DEGISMEDI** — yalnizca DOSYA.
  📌 **YENI ARAC `mobile/tool/logo_uret.dart`** (⚠️ `ikon_uret.dart` ILE
     KARISTIRMA: o UYGULAMA IKONU, bu UYGULAMA ICI LOGO).
  ⚠️⚠️ **SOZLESME: DAIRE KANVASA IC TEGET OLMALI.** Cizim
     `BoxShape.circle` + `BoxFit.cover`; kaynakta saydam kenar dolgusu
     varsa `cover` onu da cizer, arkadaki GRADIENT HALKA gorunur ->
     halka KALIN, isaret KUCUK (turu 96m: *"logonun koseleri sikintili"*).
  ✅ OLCULDU: 512x512 RGBA · kenar dolgusu **0/0/0/0** · saydam **%21.3**
     (ic-teget dairenin teorigi %21.46) · orta satirda **512/512 px opak**
     · dpr 4'te gereken 232 px -> 512 YETERLI · 329 KB -> **199 KB**.

- ⚠️⚠️⚠️ **TURU 116b — YAZDIGIM ARAC FAIL-OPEN'DI (41 ajanlik denetim).**
  `logo_uret.dart` kenar boslugunu bulunca UYARIYOR ama `exitCode` SET
  ETMIYOR, `return` YOK -> **BOZUK LOGOYU YINE DE YAZIYOR**, surec 0 ile
  bitiyordu. Kardes dallar `exitCode = 1; return;` yapiyordu —
  **ASIMETRININ KENDISI HATAYDI** (bir tur once `isScrollControlled` ile
  birebir ayni sinif yasandi).
  ⚠️⚠️ IKINCI KUSUR: kapi **HICBIR SEY OLCEMIYORDU** — `image` paketi
     `numChannels <= 3` icin `pixel.a`yi **literal 255** dondurur ve
     `decodeImage` bicimi KOKLADIGI icin bir JPEG sessizce kabul edilir;
     dolgu DAIMA 0 cikardi. Ayrica yuvarlatilmis KARE de "dolgu 0" verir.
  FIX: fail-closed (alfa yoksa / dolgu > %1 / saydam oran %21.46 disinda
  -> HATA, **DOSYA YAZILMAZ**). ✅ Bozularak kanitlandi: iyi dosyanin MD5'i
  iki bozma denemesinde de DEGISMEDI.

- 🛡️ **TURU 116b — `mobile/test/logo_varlik_test.dart`** (4 kontrol).
  ⚠️⚠️ NEDEN AYRI: `alt_menu_test.dart` bir **YERLESIM** muhafizi —
     `shape`/`fit`/54-58 dp olcer, yani WIDGET AGACINA bakar, **DOSYANIN
     ICERIGINE BAKMAZ**. 8 px saydam dolgulu bozuk bir `logo.png` o
     testlerin **HEPSINI GECER** (denetim olcup gosterdi).
  ✅ **DORT BICIMDE bozularak KANITLANDI**: dolgu · kare · alfasiz · 256px.
  ⚠️⚠️ Ilk bozma denemesi UYGULANMAMISTI ve test yesil kalmisti: betik
     `/tmp/...` kullaniyordu, **Dart (Windows ikilisi) Git Bash'in `/tmp`
     yolunu COZEMEZ**. MD5 karsilastirmasi yakaladi (turu 93b dersi).
  ⚠️ DURUST SINIR: `.github/workflows/*.yml` icinde `flutter test` YOK —
     muhafiz CI'da KOSMAZ; degeri surum rutinindeki elle `flutter test`.

- 📦 **TURU 116b — 1,27 MiB OLU VARLIK PAKETTEN CIKTI** (olculdu).
  `pubspec.yaml` `- assets/icon/` ile KLASORU toptan gomuyordu; calisma
  aninda okunan TEK dosya `logo.png`. Digerleri DERLEME-ZAMANI girdisi
  (`icon.png` 631.844 + `icon-adaptive-fg.png` 403.131 + `web-512.png`
  217.332 + `kaynak.jpg` 81.082) ve APK'da **`Stored` (%0 sikistirma)**
  ile duruyorlardi -> maliyet ham boyutun TAMAMI.
  ✅ SONUC: **APK -1,40 MB · IPA -1,39 MB** (artifactten dogrulandi:
     dordu de pakette YOK, `logo.png` MD5 yerelle BIREBIR).
  ⚠️ RISK YOK: `flutter_launcher_icons` ve `tool/*.dart` bu dosyalari
     `dart:io File` ile DISKTEN okur. ⚠️ YAPMA: tekrar `- assets/icon/`.

- ⚠️⚠️ **TURU 116b — `alt_menu.dart` SERHLERI GOVDEYLE CELISIYORDU (10 blok).**
  · *"kaldirma `min(15,...)` ile TURETILIR, tasma YAPISAL OLARAK imkansiz"*
    -> `min` govdede YOK (turu 96z SILDI), `dart:math` import bile EDILMEMIS.
    Kaldirma SABIT **17 dp**, ust tasma **KASITLI 13 dp**.
  · *"66 eksi 52 boluu 2 = 7 dp"* -> cap 112de **58**, dogrusu **4 dp**
  · *"tasan ~10 / kalan ~42"* -> **13 / 45** · *"daire 47 dp"* -> **54 dp**
  · *"47 dp = 123 px, 4.2 kat"* -> dpr 3'te **162 px, ~3,2 kat**
  · ⚠️⚠️ **SDK ILE CURUTULEN TEORI**: *"daire SEKIL olarak cizilir,
    yumusatmayi GPU'nun daire cizimi yapar"* — `box_decoration.dart`
    `Path()..addOval` + `decoration_image.dart` `canvas.clipPath(...,AA)`:
    `BoxShape.circle` ile `ClipOval` **AYNI ILKELI** kullanir. Tirtigin
    kok nedeni CLAUDE.md turu 96n'de zaten yaziliydi: **EMULATOR OLCEGI**.
    ⚠️ `ClipOval` yine kullanilmaz — sebebi anti-alias DEGIL, fazladan
       katman + hit-test yuzeyi.
  ⚠️ Sayilar artik ELLE degil **SABITIN ADIYLA** yaziliyor.

- ⏳ **TURU 116 — YAPILMADI (bilincli, KULLANICI KARARI BEKLIYOR):**
  · **UYGULAMA IKONU DEGISMEDI** — ana ekranda hala eski "kivrim" marka,
    uygulama icinde "gonder oku". Kullanici "logo" dedi; bu projede "logo"
    = `assets/icon/logo.png` ve "ayni boyut" = 512x512. Ikon AYRI bir
    varlik ve disa donuk bir marka degisikligi olurdu.
    ⚠️ Denetim notu: turu 116 tutarsizligi YARATMADI, **AZALTTI** (onceki
       logo cok renkli bir Threads yer tutucusuydu, renk ailesi bile ortak
       degildi). Istenirse `ikon_uret.dart` kaynagi `logo2.png` yapilir +
       `remove_alpha_ios` icin `background_color_ios` ACIKCA yazilmali.
  · **Android adaptive ikon icerigi %45'te** (ORTA, 18 Tem'den beri):
    `ic_launcher.xml` `android:inset="16%"` (arac VARSAYILANI) x
    `ikon_uret.dart` %66 = %45 -> mark kardeslerinden kucuk gorunuyor.
    Duzeltmesi `adaptive_icon_foreground_inset: 0` + yeniden uretim.
  · **TURUNCU-MOR HALKA** kullanicinin turu 112 emri — dokunulmadi.

- **KALDIGIMIZ YER (19 Agu 20:33): TURU 115 + 115b + 115c YAYINLANDI** —
  android **32280884494** + ios **32280900129** (**4956cc0**), R2
  apk=122633515 (md5 0f889c34) ipa=31738738 (md5 73fb63f8) index=16043
  (md5 4f36c454) **surum.json=48 (md5 1747374c)**, purge OK,
  **CDN DORDU DE BIREBIR**, debug imza YOK, `HARITA=true` iki logda da,
  harita anahtari **IKI ARTIFACT'TE DE** enjekte (APK manifest UTF-16 +
  iOS `MapsApiKey`), iOS min **16.0**, **IKI ARTIFACT'TE DE turu 115c kodu
  VAR** (dizeler UTF-16 arandi: "Zamanlandı" · "Sık görüştüklerin").
  **BACKEND DEPLOY** (4956cc0) + health ok.
  ✅ **CANLIDA 382/382 UCTAN UCA** · flutter analyze **0/0** ·
     flutter test **40/40** · go build+vet+test temiz (9 paket).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260819-2033

- 🧹 **19 Agu — E2E ARTIKLARI TEMIZLENDI (gercek hesaplara DOKUNULMADI).**
  Uctan uca aracini defalarca kosturdugum icin canli DB'de **244 `E2E`
  onekli hesap** ve 147 sahte isletme birikmisti; kullanici uygulamayi
  acsa kategori listesinde ve Yakinimda'da bunlari gorurdu.
  ⚠️ `TRUNCATE users` **YAPILMADI**: kullanicinin 16 Agu emri *"profiller
     kalsin"*. Yalniz `name LIKE 'E2E%'` hesaplari ve onlara bagli TUM
     kayitlar (52 tablo, FK zincirine gore siralanmis) silindi.
  ⚠️ Sutun adlari **FK KATALOGUNDAN OKUNDU, TAHMIN EDILMEDI** — ilk
     denemede `post_comments.user_id` varsayilmisti; gercek ad `author_id`.
  ✅ SONUC: **32 gercek hesap** duruyor; icerik tam da kullanicinin test
     ettigi hale dondu (isletme 14 · ilan 3 · etkinlik 2 · randevu 17).
  📌 Bu yuzden `tools/tohum.js` KOSULMADI — kosulsaydi mevcut 14 isletmenin
     USTUNE kopya eklerdi.

- ⚠️⚠️⚠️ **TURU 115c — INDIR SAYFASI: SAAT ARTIK SUNUCUDAN YAZILIYOR.**
  Kullanici **ALTI TURDUR** *"saati goremiyorum"* diyor; sunucu tarafi ALTI
  KEZ DE dogru cikti (bu turda da olculdu: `text/html` + `no-store` +
  `cf-cache-status: DYNAMIC` + saat **7 yerde** + `surum.json` gomulu
  surumle BIREBIR). Kalan tek aciklama TARAYICI/WEBVIEW ONBELLEGI.
  ⚠️⚠️ **Onceki IKI nobetci bu durumu yalniz HABER VERIYORDU** (kirmizi
     serit) — kullanicidan hala bir DOKUNUS bekliyordu.
     ARTIK: `surum.json` `no-store` ile cekilip **GORUNEN SAATIN KENDISI**
     (+ sayfa basligi) onunla degistiriliyor. Govde onbellekten gelse bile
     kullanicinin OKUDUGU saat DOGRU olur.
  🛡️ Uretici muhafizi IKI YENI KONTROL (`id="surumsaat"` + `d.saat`) —
     **IKISI DE BOZULARAK KANITLANDI**.
     ⚠️ Ilk bozma denemesi UYGULANMAMISTI (regex tutmadi) ve test YESIL
        kaldi; "uygulanmadiysa PATLA" kapisiyla tekrarlandi (turu 93b dersi).
  ⚠️ `<meta http-equiv="Cache-Control">` de eklendi (sunucu basligini soyan
     uygulama-ici tarayicilara karsi EK katman, YERINE gecmez).

- ⚠️⚠️⚠️ **TURU 115c — BUILD ALINDI, IPTAL EDILDI, YENIDEN ALINDI.**
  Ilk build (`183c2e6`) tetiklendikten SONRA kosulan denetim **IKI SEVK
  ENGELI** buldu; build iptal edilip kod duzeltildi.
  *"Build ALMAK yayinlamak DEGILDIR"* dersinin **YEDINCI** dogrulanmasi.
  · **"+" penceresi (mesajlar) TASIYORDU**: `isScrollControlled` vardi ama
    `SingleChildScrollView` YOKTU. 320x568 · olcek 2.0 -> **149 px tasma**,
    son madde EKRAN DISINDA. **Turu 114'un birebir tekrari**: o bayrak
    yalnizca TAVANI kaldirir, icerigi KAYDIRILABILIR YAPMAZ. Kardes
    `olustur_menusu.dart` IKI parcayi da tasiyordu — **ASIMETRININ KENDISI
    HATAYDI.**
  · **Sohbet listesi sag sutunu TASIYORDU**: SDK kaynagindan dogrulandi —
    `ListTile` `trailing`e **SABIT 56 dp TAVAN** dayatir. `mainAxisSize.max`
    ile olcek 1.8'de 6,0 / 2.0'da 11,8 dp tasma. Ustelik turu 115b'de
    ekledigim `Visibility(maintainSize)` tasmayi **HER SATIRA** yaymisti.

- ⚠️⚠️ **TURU 115b/c — ACIK TEMADA GORUNMEYEN UC YER** (hepsi emulatorde
  gorundu, hicbiri `flutter analyze`in yakalayabilecegi sinif degil):
  · sohbet arama kutusu `fillColor: 0xFF232326` -> **SIMSIYAH** (ekranin
    en ustundeki bilesen)
  · "Sık görüştüklerin" isimleri `Colors.white70` -> **1,09:1** (fiilen
    gorunmuyordu), basligi `0xFF9A9AA0` -> 2,51:1
  · ses notu dalga formu **YESIL** kalmisti (balon mora donmustu) ->
    mor balonun icinde yesil dalga + acik temada 4,29:1
  ⚠️ **DERS: bir zemin rengini degistirirken, o zemine gore secilmis ON
     PLAN renklerini de ARA** — zemin `ChatColors`ta TEK yerdeydi, ona gore
     ayarlanmis renkler BASKA DOSYADAYDI.
  ⚠️ **DERS 2: bir dosyada bir sabit rengi duzeltmek o dosyanin
     TEMIZLENDIGI anlamina GELMEZ** (`chats_screen`de biri duzeltildi,
     otekisi ATLANDI).

- 📌 **TURU 115b — MARKA RENGI: `primary` ARTIK LOGONUN TAM RENGI.**
  `ColorScheme.fromSeed` tohumu tonal palete ceviriyor ve cikan `primary`
  logodan belirgin DAHA SOLUKTU (~#65558F). Ayni ekranda FAB (canli mor)
  ile secili sekme hapi (soluk mor) **IKI FARKLI MOR** gibi duruyordu.
  Acik temada `primary = morLogo (#6C2BD9)`, `onPrimary` beyaz (7,9:1).
  ⚠️⚠️ **KOYU TEMA DEGISTIRILMEDI**: M3'te koyu temanin `primary`si ACIK
     ton olmali (uzerine KOYU yazi gelir); #6C2BD9 yazilsaydi koyu zeminde
     koyu mor dugme cikar ve yazi OKUNMAZDI.
  ⚠️ Mesaj balonu da mor: acik `#EDE4FF` (15,5:1), koyu `#3B2A63` (9,8:1).
  ⚠️ **YESIL KALAN YERLER BILINCLI**: "Açık/Kapalı" gostergesi ve onay/red
     ikonlari DURUM isaretidir (trafik isigi), marka aksani DEGIL. Mora
     cevirmek "acik" ile "kapali"yi ayirt edilemez yapardi.

- 🛡️ **TURU 115c — IKI YENI MUHAFIZ:**
  · `internal/isletme/sutun_test.go` -> **`TestYakinimdaSelectVeScanHizali`**.
    `Yakinimda` repodaki EN YENI ve EN BUYUK isletme sorgusu (18 sutun) ve
    **KORUMASIZDI**; turu 115'te bes sutun eklendi, hicbir muhafiz gormedi.
    ✅ **BOZULARAK KANITLANDI** (17≠18 -> KIRMIZI).
    ⚠️ Kardeslerinden farki: SIRA olculmuyor — gerekce dosyada YAZILI.
  · `tools/uctan_uca.js` **375 -> 382**: `/ara` ucunun kapsami **SIFIRDI**
    (uc turu 115'te yazildi, istemcinin BES arama sekmesinden DORDU ona
    bagli). ✅ Yeni kontrol **GERCEK BIR SEY YAKALADI**: `tur=konum`
    kirmizi dustu ve **SUNUCU HAKLIYDI** (yuklem `enlem<>0 OR boylam<>0`,
    yani "Yerler" = koordinati OLAN gonderi). Test duzeltildi, urun DEGIL.

- ⏳ **BEKLEYEN (kullanici soyledi, HENUZ GELMEDI):** *"sana yakinda icin
  arayuz atiyorum"* — Yakinimda ekrani icin referans gorsel bekleniyor.
  Bu turda o ekrana **BILEREK DOKUNULMADI** (daire pin disinda).

- 📐 **YAZI OLCEGI KARARI (17 Agu): `docs/yazi-olcegi.md`** — 6 kademe
  (20/17/15/14/13/11). 11 ajanlik arastirma + 3 mercekli denetim sonucu.
  ⚠️ **UYGULAMA ARAYUZ BITINCE** (kullanici karari); AMA **yeni yazilan her
     kod bu olcege gore yazilir**.
  ⚠️ Denetim BUGUNE AIT 6 hata buldu (sayac tavani sabit dp · FittedBox yazi
     olcegini geri aliyor · kompakt kart 1.3'te tasiyor · kategori basligi yan
     dugmelere biniyor · zaman damgasinda overflow yok · 11 altinda 8 nokta).
     Hepsi belgede olculmus haliyle yazili.
- **KALDIGIMIZ YER (19 Agu 17:27): TURU 114 YAYINLANDI** — android
  **32262794755** + ios **32262799196** (**c0e1bca**), R2 apk=122568143
  (md5 580dcb70) ipa=31718718 (md5 627ef9b6) index=14914 (md5 c6e99595)
  **surum.json=48 (md5 ea37d99c)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, `HARITA=true` iki logda da dogrulandi, iki artifact'te de
  turu 114 dizeleri VAR (Mahalle · Topluluk oluştur · Düğün & Organizasyon ·
  İşletme hesabını aç).
  ✅ **BACKEND DEPLOY** (40bac75) + health ok + **CANLIDA 375/375 UCTAN UCA**.
  `flutter analyze` **0 hata 0 uyari** · `flutter test` **40/40** ·
  go build+vet+test temiz.
  ⚠️ **SEMA DEGISMEDI -> DB TRUNCATE EDILMEDI** (hesaplar/isletmeler duruyor).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260819-1727
- ⚠️⚠️⚠️ **TURU 114 DENETIMI (38 ajan: 6 mercek + her bulguya AYRI curutucu) —
  32 ham bulgu, 19 ONAY, 13 CURUTULDU. EN AGIRI:**
  · **TURU 113'UN "FAB KALDIRILDI" IDDIASI GOVDEDE YAPILMAMISTI.** O commit
    `live_tab.dart`ta yalnizca 3 satir ekleyip 1 satir silmis (bos durum
    metni); "Yayın başlat" FAB'i OLDUGU GIBI duruyordu ve kullanicinin 5.
    maddesi YARIM kalmisti. **DERS: bir degisikligin yapildigini COMMIT
    MESAJINDAN DEGIL, GOVDEDEN dogrula.**
  · **Mesajlar "+" sheet'i tasiyordu** (`isScrollControlled` yok): 360x640'ta
    olcek 1.5'te **94 px**, son madde ekran disinda ve `tester.tap` ISKALIYOR.
    411x896 test cihazinda TASMIYOR. (Turu 90b'de `olustur_menusu.dart`ta
    olculup duzeltilen hatanin aynisi; bu sheet dersi almamisti.)
  · **Olusturulan topluluk KAYBOLUYORDU**: `KanalOlustur` id donduruyor ama
    atiliyordu; kanallar AYRI `channels` tablosunda ve `ListChats` yalniz
    `chats`ten okuyor -> topluluk mesaj listesinde YAPISAL OLARAK gorunemez.
    Kullanici tekrar tekrar deniyor, her deneme GERCEK kanal aciyor, 10.
    denemede kota hatasi -> arkada 10 YETIM topluluk.
  · Mahalle'de konum reddedilince **izin IKI KEZ soruluyordu**
    (`_bolmeYukle` iki turlu, durma olcutu `_bolmeYuklendi` isaretlenmiyordu).
  · Talep izgarasi 411 dp/olcek 1.5'te **21.36 dp**, sihirbaz alt cubugu
    360 dp/olcek 1.3'te dugmenin **yalnizca 121 dp'si goruntudeydi**.
  · Basvuru ozet seridi acik temada **~1.9:1** (amber yazi/zemin ayni renkti).
  · Sihirbazda geri tusu ekrani KAPATIYORDU (adim adim degil) -> `PopScope`.
  · Demoda liste sonundaki yukleme gostergesi **sonsuza kadar donuyordu**.
  · Terminoloji iki dildeydi ("Topluluk" menude, "Kanal" ekranlarda) -> 18
    gorunen dize cevrildi; sinif/uc/tablo adlari DOKUNULMADI.
- ⚠️⚠️⚠️ **TURU 114 — AKIS SECICISI GERI GELDI: `Arkadaş · Keşfet · Mahalle`.**
  Turu 113 seciciyi kullanicinin ONCEKI emriyle kaldirmisti; kullanici bu turda
  GERI istedi ve ucuncu ogeye YENI BIR ANLAM verdi.
  ⚠️ **MAHALLE GERCEK BIR BOLME** (eskiden "Canlı Yayın" bir KISAYOLDU):
     `GET /mahalle?lat&lng&km` — cevredeki KONUMLU gonderiler.
  ⚠️ **YENI TABLO/MIGRATION YOK**: `posts.konum_ad/enlem/boylam` 044'ten beri
     VAR ve ortak sutun sabitinde (`medyaTurleri`) zaten donuyor.
  ⚠️ `/feed`E BAYRAK OLARAK EKLENMEDI: o ucun yanitindaki `kesfet` bayragi
     "takip etmiyorsun" anlamini tasiyor; iki anlam ayni ucta karisirdi.
  ⚠️⚠️ **BOYLAM BOLENI `111 * cos(enlem)`** — duz `111.0` kutuyu Gebze
     enleminde **%24 DAR** yapar (turu 85b'de isletme tarafinda SAHAYA CIKTI).
  ⚠️ Diziler IKI -> **UC** elemana cikarildi (`_listeler`, `_dahaVarlar`,
     `_kesfetler`, `_bolmeYuklendi`, `_bolmeKaydirma`).
  ⚠️ Konum BIR KEZ alinir; **asagi-cek TAZELER** (baska semte gidince ve izni
     SONRADAN verince tekrar denemenin tek yolu).
- ⚠️⚠️ **TURU 114 — UCTAN UCA MEKANSAL SUZGECI GERCEKTEN OLCUYOR** (375 kontrol):
  yakina ve uzaga birer gonderi atilir; yalniz yakindaki doner, yaricap
  buyutulunce uzak da gelir (elemenin sebebi MESAFE), konumsuz gonderi HIC
  gorunmez, koordinatsiz istek 400, **NaN koordinat da 400**.
  ⚠️ Ilk yazimda uzak gonderi ~122 km konmustu; sunucu tavani 100 km oldugu
     icin "genis yaricap" kontrolu YAPISAL OLARAK gecemiyordu — test HAKLI
     olarak kirmizi dustu ve mesafe 55 km'ye cekildi.
- ⚠️⚠️⚠️ **TURU 114 — `favorim` EXISTS'INDE `::text` CAST'I TUM LISTEYI 500
  YAPIYORDU.** `engel.Yuklem` ayni `$1`i `blocks.blocker_id` (uuid) ile
  karsilastirdigi icin Postgres parametreyi UUID cikarsiyor ->
  *"operator does not exist: uuid = text"*. `go build`, `go vet` ve
  `sutun_test.go` UCU DE YESILDI; hatayi YALNIZ canli e2e gordu (14 kontrol
  birden dustu). ⚠️ **DERS: paylasilan bir parametreye cast eklemeden once o
  parametrenin BASKA hangi sutunla karsilastirildigina bak.**
- 🛡️ **TURU 114 — MUHAFIZ KAPSAMI GENISLETILDI:** `social/sutun_test.go` ve
  `yayin_test.go` yalniz `handler.go`+`etkilesim.go` tariyordu; `mahalle.go`
  HIC olculmuyordu. **BOZULARAK KANITLANDI** (`yayindaOlan` cikarildi -> test
  kirmizi: *"Mahalle icindeki gonderi sorgusunda ZAMANLANMIS GONDERI YUKLEMI
  YOK"*). ⚠️ Yeni bir gonderi sorgusu yazarken bu iki listeye EKLE.
- 📌 **TURU 114 — KULLANICININ 17 MADDESININ TAMAMI:**
  · **10·11·12·16** Dugun ve Hizmet **"yemek" duzeninde + ADIM ADIM**.
    ⚠️⚠️ "Yemek gibi" = *"dugun isletmelerini listele"* DEGIL: `isletme.
       Kategoriler` haritasinda `dugun`/`organizasyon` anahtari YOK, boyle bir
       liste **HER ZAMAN BOS** donerdi. GORSEL DIL alindi, hucreler TALEP
       KATEGORILERI ve dokununca sihirbaz aciliyor.
    ⚠️⚠️ **"Hizmet" karti YANLIS YONE gidiyordu** (`IlanListesiEkrani`):
       kullanicinin istedigi TERS YON (hizmet ARAYAN form doldurur). O akis
       vardi ama YALNIZCA Dugun kartindan ulasilabiliyordu.
  · **13** randevular **AJANDA** (gun basliklari + saat + sure), basvurularda
    **durum ozeti** (sayilar yuklenen listeden TURETILIR, ek istek YOK).
    ⚠️ AY IZGARASI CIZILMEDI: sunucu "musait gunler" dondurmuyor, izgaranin
       cogu SAHTE olurdu.
  · **8** profilde sekmeler arasi **yatay kaydirma**. ⚠️ `PageView` DEGIL:
    sekme icerikleri farkli yukseklikte ve `PageView` hepsini agacta CANLI
    tutar (on sekmenin izgarasi ayni anda medya cozerdi). Jest + 120 px/sn
    hiz esigi. Sekme degistirmenin **TEK KAPISI** `_sekmeyeGec`.
  · **6** mesajlarda **topluluk** = **KANAL** (`chats.type=channel`); yeni
    tip ACILMADI, sorun KESFEDILEBILIRLIKTI.
  · **9** ilan kartinda **sahibi satiri** (avatar + ad + tik + "İşletme").
    Sunucuda `u.hesap_turu`+`u.onayli`: SELECT + Scan + yanit haritasi UCU
    BIRLIKTE; e2e canlida dogruluyor.
  · **14** isletme hesabi **UC ADIM**. ⚠️ Sihirbaz YALNIZ yeni hesapta; veri
    **TEK ISTEKTE** gider (adim basina kaydetseydik yarim hesap olusurdu).
  · **15** etkinlik karti yemek dilinde + **tarih rozeti** (kapak her renkte
    olabilir -> rozet koyu zemin/beyaz yazi, temaya baglanamaz).
- ⚠️⚠️ **TURU 114 — DENETIMIN OLCTUGU UC TASMA (hepsi duzeltildi):**
  · talep izgarasi `childAspectRatio: 0.78` ile 411 dp/olcek 1.5'te **21.36 dp**
    tasiyordu -> `mainAxisExtent` yazi olceginden TURETILIYOR (menudeki formul).
  · sihirbaz alt cubugu 360 dp/olcek 1.3'te dugmenin sag kenari **441.9 dp**
    (ekran 360) — *"İşletme hesabını aç"* dugmesinin yalnizca **121 dp**'si
    goruntudeydi. Adim adi KENDI SATIRINA alindi + `FittedBox`.
  · demoda liste sonundaki yukleme gostergesi **sonsuza kadar donuyordu**
    (`_dahaGetir` demoda hemen doner ama `_dahaVarlar` true kaliyordu).
    Mahalle'de tek gonderi oldugu icin EKRANIN ORTASINDA gorunur oldu.
- ⏳ **TURU 114 — DURUST SINIRLAR:** Mahalle yalniz KONUM PAYLASILMIS gonderileri
  gosterir · `/mahalle` yanitindaki `km` istemcide OKUNMUYOR ("15 km icinde"
  yazilmiyor) · `posts(enlem,boylam)` uzerinde INDEX YOK (bu olcekte sorun
  degil) · randevuda ay izgarasi yok · demo ilanlarda "İşletme" rozeti CIKMAZ
  (demo veri `sahibi_hesap_turu` tasimiyor).
- **KALDIGIMIZ YER (19 Agu 14:47): TURU 99-113 YAYINLANDI** — android
  **32248225046** + ios **32248227938** (**cc418fd**), R2 apk=122404307
  (md5 355953f2) ipa=31700278 (md5 48a69b97) index=14423 (md5 432d6d61)
  **surum.json=48 (md5 699a0cc5)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, `HARITA=true` iki logda da dogrulandi, iki artifact'te de
  turu 113 dizeleri VAR (UTF-16 arandi).
  ✅ **BACKEND DEPLOY** (cc418fd) + health ok + **CANLIDA 367/367 UCTAN UCA**.
  `flutter analyze` **0 hata 0 uyari** · `flutter test` **40/40** ·
  go build+vet+test temiz.
  ⚠️ **SEMA DEGISMEDI -> DB TRUNCATE EDILMEDI** (hesaplar/isletmeler duruyor).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260819-1447
- ⚠️⚠️⚠️ **TURU 113 — UCTAN UCA TESTI SEVK ENGELI YAKALADI (yine).**
  `favorim` icin eklenen `EXISTS(... f2.user_id::text = $1 ...)` **TUM
  /isletmeler LISTESINI 500** yapiyordu: `engel.Yuklem` AYNI `$1`i
  `blocks.blocker_id` (uuid) ile karsilastirdigi icin Postgres parametreyi
  UUID cikarsiyor -> *"operator does not exist: uuid = text"*. `go build`,
  `go vet` ve `sutun_test.go` UCU DE YESILDI; hatayi yalniz canli e2e gordu
  (14 kontrol birden dustu). ⚠️ **DERS: paylasilan bir parametreye cast
  eklemeden once o parametrenin BASKA hangi sutunla karsilastirildigina bak.**
- ⚠️⚠️ **TURU 113 — `favorim` ARTIK HER LISTEDE DONER** (`isletmeSutunlari`).
  Onceden yalniz `Favorilerim` donduruyordu; kategori ekraninda kalp DAIMA
  BOS goruluyor ve favoriden cikarmak IMKANSIZDI (yerel durum "favori degil"
  oldugu icin dokunus DELETE degil TEKRAR POST atiyordu).
  ⚠️ **SQL ICINE `--` YORUMU YAZMA**: `sutun_test.go` sutunlari VIRGULLE
     boluyor ve virgullu bir yorum SUTUN sayiliyor (muhafiz kirmizi dustu).
- ⚠️⚠️⚠️ **TURU 113 — DEMO GONDERI KIMLIKLERI `demo-` ONEKI TASIMIYORDU.**
  Yalniz `yazarId` onekliydi, yani **`demoKimlik(gonderi.id)` DAIMA false**:
  en dogal yazim SESSIZCE FAIL-OPEN idi ve kapilarin calismasinin tek sebebi
  tesadufen `yazarId` kullanmalariydi. Onek eklendi; `demo_yorum.dart`
  matrisinin anahtarlari da (`demo-foto` ...) guncellendi.
- ⚠️⚠️ **TURU 113 — SES NOTU, KART EKRANDAN GITTIKTEN SONRA CALMAYA
  BASLIYORDU.** `adres()` await'i sonrasi canlilik kapisi yoktu; `dispose`
  `_calanId != widget.mediaId` oldugu icin oynaticiyi durdurmuyor, ardindan
  `play()` kosuyordu -> **ekranda oynatici yokken ses** ve durdurma yolu YOK.
  Uc abonelik de dispose'tan SONRA kuruldugu icin HIC iptal edilmiyordu.
  ⚠️ YAPMA: `if (!mounted) return;` kapisini kaldirma.
- ⚠️⚠️ **TURU 113 — PROFILDE ASAGI-CEK ACIK SEKMEYI KALICI BOSALTIYORDU.**
  `_yukle` tum sekme onbellegini temizliyor ama aktif sekmeyi YENIDEN
  YUKLEMIYORDU: spinner yok, tekrar-dene yok, liste bos -> ekran **"Henüz
  ilanın yok"** diyordu (kullanicinin KENDI verisi hakkinda yalan). Ayni yol
  takip · engelle · profil duzenlemeden donusle de tetikleniyordu.
- ⚠️⚠️ **TURU 113 — DEMO SERIDI GERCEK HIKAYEYI EZIYORDU.** `yukle()` demo
  dalinda basta kisa devre yapiyordu; paylasilan gercek hikaye seritte HIC
  gorunmuyor, kendi halkasina dokununca "tasarim demosu" uyarisi cikiyordu
  ("paylastim sandim, gitmemis"). Artik sunucu cevabi ONCE alinir ve kendi
  gercek hikayem demo kullanicilarin ONUNE konur.
  ⚠️ Demoda `benim: true` kaydi KALDIRILDI ki **paylasma dairesi** (siyah-mor
     halka, kullanici emri) ekranda gorunsun.
- ⚠️⚠️ **TURU 113 — AYARLAR'DA TEK AG HATASI "Gizlilik" BOLUMUNU YOK
  EDIYORDU.** `keepAlive` saglayicida `AsyncError` surec boyunca saklaniyor,
  `valueOrNull` null kalinca satir cizilmiyor ve `AyarBolumu` bos listede
  hicbir sey cizmedigi icin BASLIK DAHIL kayboluyordu (turu 78b
  `aiDurumProvider` hatasinin birebir tekrari). FIX: `invalidateSelf`.
- ⚠️ **TURU 113 — YERLESIM (olculdu):** sohbette anket basligi 360 dp'de
  **29.9 dp** tasiyordu (`Spacer` + ciplak `Text`) · yorum eylem satirinda
  tasma korumasi HIC yoktu (dort sayac "1,2 bin" olursa 100 dp; **demo
  sayaclari bunu gizliyordu**) · koyu temada ses dalgasi 1.46:1 / 2.90:1 ile
  GORUNMUYORDU · "Kaydedilenler" 13.5 dp, "Rezervasyon" 20 dp kirpiliyordu ·
  "Anketi bitir" hedefi 20.3 dp idi (GERI ALINAMAZ eylem).
- ⚠️ **TURU 113 — `letterSpacing` ALTI EKRANDAN KALDIRILDI** (kullanici emri;
  izin verilenler dokunulmadi: OTP hane araligi ve hikaye metni).
- 📌 **TURU 113 — INDIR SAYFASI: saat artik YEDI yerde** + **AG GEREKTIRMEYEN
  ikinci nobetci**: adresteki `?v=` ile sayfaya gomulu surum karsilastirilir.
  `surum.json` nobetcisi bir `fetch` gerektiriyor ve WhatsApp/Instagram ic
  tarayicisinda HIC tamamlanmayabilir; yeni blok yalniz `location.search`
  okur. ⚠️ Ikisi FARKLI arizalari yakalar, biri otekinin yerine KONMAZ.
- 📌 **TURU 113 — MADDE MADDE (kullanicinin 17 maddelik listesi):**
  · **1** menude geri oku + alt aciklama YOK · **2** uygulama acilinca menu
    KENDILIGINDEN acilir (surec omurlu bayrak; geri tusu akisa doner) ·
  · **3** akistaki "Arkadaslar · Kesfet · Canli Yayin" SECICISI KALDIRILDI
    (ikisi de alt menude ZATEN var; ona bagli ALTI olu metot da silindi) ·
  · **4** hikaye paylasma dairesi halkali + siyah-mor gradient, dis cap
    kardesleriyle BIREBIR · **5** Canli sekmesinde "Yayin baslat" FAB YOK
    (giris "+" menusunde DURUYOR) · **7** Reels'te kaydet eklendi ·
  · **17** alt menu logosu turuncu-mor gradient halka, gorunen logo +2 dp
    (dis cap 54 -> 58; ilk denemede halka ICERIDEN alinmis ve logo
    KUCULMUSTU — plan yakaladi).
  ⏳ **YAPILMAYANLAR (durust):** 6 (topluluk) · 8 (profilde yatay kaydirma) ·
    10-11-12 (dugun/hizmet adim adim) · 13 (randevu takvimi) · 14 (isletme
    hesabi adim adim) · 15-16 (etkinlik/kategori sablonlari).
- ⏳ **DURUST SINIRLAR (turu 111-113):** GebzemAI'da **akan yazi yok**, sohbet
  **kaydedilmiyor** (uygulama kapaninca gider), durdurma dugmesi yok ·
  sohbete eklenen fotograf R2'de YETIM kalir (`gorselVazgec` karsiligi yok) ·
  yorum begenisi YALNIZ ekranda artar (`comment_likes` var, uc YOK) ·
  `Favorilerim` LIMIT 100, sayfalama yok · konum kartinda gercek harita yok.
- **KALDIGIMIZ YER (16 Agu 20:11): TURU 98e-98i YAYINLANDI** — android
  **31960110991** + ios **31960112573** (**142a630**), R2 apk=121992523
  (md5 168c36fb) ipa=31636527 (md5 679375ff) index=12167 (md5 5e9313fc)
  **surum.json=48 (md5 175444c0)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, harita anahtari enjekte. **BACKEND DEGISMEDI.**
  flutter analyze 0/0 · flutter test **40/40** · emulatorde 0 tasma.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260816-2011
- 📌 **TURU 98e-98i — ARAYUZ (kullanici emirleri + Threads referansi):**
  · bolme secici **APPBAR ORTASINDA** (+ ile bildirim arasi).
    ⚠️ `titleSpacing: 0` ZORUNLU — varsayilan 16+16 dp "Canlı Yayın"in son
       harfini KIRPIYORDU (ekranda olculdu).
    ⚠️ Ortalama `Align` ILE OLMAZ: `SingleChildScrollView` cocuguna
       kaydirma ekseninde SINIRSIZ genislik verir. Dogrusu `LayoutBuilder`
       + `ConstrainedBox(minWidth: alan)` + `MainAxisAlignment.center`.
  · ust cubuk ikonlari `kAltMenuIkonBoy` (alt menuyle TEK KAYNAK, import).
  · hikaye daireleri **65 dp** ve **HEPSI ESIT** (ekleme dairesi dahil);
    aralik **9 dp** (`kAralik`), serit -> ilk gonderi **20 dp**.
    ⚠️ Kapsulun GORUNEN genisligi zaten `cap + kayma + 9`; kutu buna ESIT
       yapilirsa aradaki bosluk **0** olur (bir kez oyle yazildi, canli ile
       oda BITISIK cikti). Kutu = gorunen + `kAralik`.
    ⚠️ Halkasiz (kendi) daire `_cember` dolgusunu KULLANIR, yoksa gorunen
       cap kardeslerinden 9 dp kucuk kalir.
  · canli/oda kapsulunde **iki profil UST USTE** (98d ayirmisti, 98e geri
    aldi — SON SOZ KULLANICIDA) + zemin renginde ayrac + izleyici sayisi.
  · gonderi basligi `ListTile`dan CIKARILDI: ad avatarin UST kenariyla
    hizali, aciklama AYNI kolonda; **ad->aciklama** ve **aciklama->medya**
    bosluklari TEK SABITTEN (`kIcBosluk`) gelir, yani YAPISAL OLARAK esit.
  · begenilince **DOLU KIRMIZI KALP**: Lucide 3.1.14 dolu kalp ICERMIYOR
    (kontrol edildi) -> YALNIZ o durumda Material `Icons.favorite`.
    Sayi da KIRMIZI + degisince YUKARI kayan gecis.
  · sayilar ikon boyunda (13 -> 15); paylas ikonu 24 -> 23; repost `redo2`.
  · **GONDERI DETAYI Threads duzeni**: "Yazışma" + goruntulenme · Başlıca /
    Hareketi gör · threadli mockup yorumlar (mavi tik · yazar begenisi ·
    "Gönderi sahibi" rozeti · "Yanıtları göster" · bagli alt yanit).
  · akista bazi gonderilerin ALTINDA tek yanit · **SPONSORLU** gonderi
    (zaman yerine "Sponsorlu" + alan adi/CTA karti).
    ⚠️ **DURUST SINIR:** sponsorlu kart TIKLANMAZ (reklam altyapisi yok);
       yorumlar/izleyici sayilari DEMO verisidir.
- ⚠️⚠️ **TURU 98i — OLCULEN UC HATA:**
  · `DemoYorumSatiri`daki thread cizgisi `Expanded` ile SINIRSIZ yukseklik
    kisiti aliyordu -> *"RenderBox was not laid out"* -> **DETAY EKRANI
    BOMBOS aciliyordu**. FIX: `IntrinsicHeight`. ⚠️ YAPMA: kaldirma.
  · Demo acikken **SAYFALAMA sunucudan cekmeye DEVAM EDIYORDU**: demo
    kartlarin altina GERCEK gonderiler ekleniyordu (`_dahaGetir` kapisi).
  · Sahte yanit **GERCEK gonderilerin altinda da** ciziliyordu
    (`demoKimlik` kapisi).
- ⚠️ **TURU 98h — ALT MENU KOSELERINDE BEYAZLIK** (kullanici sahada gordu):
  radius disi ucgenler SAYDAM oldugu icin sayfa gecisinde arkadaki BEYAZ
  sayfa goruluyordu. FIX: cubugun ARKASINA uygulama zemini boyandi.
  ⚠️ Radius KALDIRILMADI. ⚠️ Muhafiz testi iki `ColoredBox` gorunce
     patliyordu; olcut artik `ClipRRect` ICINDEKI cubuk zemini.
- **KALDIGIMIZ YER (16 Agu 16:56): TURU 98 + 98b/c/d YAYINLANDI** — android
  **31950598996** + ios **31950603733** (**2067a50**), R2 apk=121992539
  (md5 3371f917) ipa=31634251 (md5 044db861) index=11863 (md5 013246d1)
  **surum.json=48 (md5 3c479e25)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, harita anahtari IKI ARTIFACT'TE DE enjekte,
  **IKI ARTIFACT'TE DE turu 98d kodu VAR** (dizeler UTF-16 arandi).
  **BACKEND DEGISMEDI** (health ok) — bu tur salt Flutter.
  ✅ `flutter analyze` **0 hata 0 uyari** · `flutter test` **40/40** ·
  go build+vet temiz · **emulatorde 360 dp + yazi olcegi 1.3'te 0 TASMA**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260816-1656
- ⚠️⚠️⚠️ **TURU 98 — TASARIM DEMOSU ACIK (`kDemoAkis = true`).**
  Kullanici emri: *"icerikleri sil, gri icerikler olsun, story atmis biri
  olsun, canli yayinda biri olsun — demo gibi dusun"*.
  `mobile/lib/features/sosyal/demo_veri.dart` TEK KAYNAK; akis + serit demo
  dallari YALNIZ bu bayraga bagli.
  ⚠️⚠️ **GERCEK YAYIN ONCESI `kDemoAkis = false` YAPILACAK.** Bayrak acikken
     akista SAHTE gonderiler ve sahte izleyici sayilari gorunur.
  ⚠️ Demo icerigi SUNUCUYA GITMEZ: `demoKimlik()` kapisi begeni/kaydet/yorum/
     istatistik/menu/paylas/profil/story yollarinin HEPSINDE. Kapi olmadan
     begeni "gonderilemedi" uyarisi veriyor, yorum/profil BOS aciliyordu ve
     kullanici bunlari GERCEK HATA sanardi.
- 🗑️ **16 Agu — KULLANICI EMRIYLE ICERIK SILINDI** (*"kayitli kullanicilara
  dair her seyi sil, profiller kalsin"*): `posts` · `post_likes` ·
  `post_saves` · `post_comments` · `comment_likes` · `stories` ·
  `story_views` · `polls`+`poll_options`+`poll_votes` · `messages` ·
  `message_receipts` · `chats` · `chat_members` · `channels` (+alt tablolar)
  · `bildirimler` **TRUNCATE**. **KALDI:** `users` (22) · `isletmeler` (14) ·
  `ilanlar` (3) · `etkinlikler` (2) · `randevular` (17).
  ⚠️ Kullanicilar YENIDEN KAYIT OLMAZ; hesaplar ve isletme verisi duruyor.
- ⚠️⚠️⚠️ **TURU 98c — ETKILESIM SATIRI 360 dp'DE 9.3 PIKSEL TASIYORDU
  (EMULATORDE OLCULDU, 411 dp'de GORUNMUYORDU).**
  98b'de dorduncu sayi (repost) eklenince turu 82b'nin **UC sayiya gore**
  kurulmus sabit butcesi (`5*(5+26+5) + 3*(6+40) = 318dp`) gecersiz kaldi;
  **KAYDET IKONU EKRAN DISINDA** kaliyordu.
  FIX: sol grup `Expanded` + **`FittedBox(scaleDown)`** — yalniz gerektiginde
  kuculur (411 dp'de olcek 1.0, 360 dp'de ~%97), her genislik ve yazi
  olceginde tasma **YAPISAL OLARAK imkansiz**.
  ⚠️ **DERS (turu 70b/90b'nin ucuncu tekrari): dar ekranda OLCMEDEN
     "sigiyor" deme.** Test cihazi 411 dp; en yaygin dar telefon 360 dp.
  ⚠️ YAPMA: `FittedBox`i kaldirip sabit butce hesabina donme.
- ⚠️⚠️ **TURU 98c — ALT MENUDEKI LOGONUN TASAN USTU YANLIS EYLEM TETIKLIYORDU.**
  Logo cubuktan ~10 dp yukari tasiyor (96z kullanici emri) ve Flutter
  ebeveyn kutusunun DISINI hit-test ETMEZ; dokunus **ALTTAKI AKISA** dusuyor,
  kor bir dokunusta gonderinin **paylas sayfasi** aciliyordu.
  FIX: cubugun ICINDEKI yer tutucu hucre de ayni menuyu acar (hedef 42 ->
  66 dp). Tasan serit hala tiklanmaz — cubugu uzatmak/logoyu kucultmek
  kullanici tarafindan ACIKCA reddedildi (96p/96z).
- 📌 **TURU 98c/d — GONDERI KARTI OLCULERI (kullanici emri):**
  · aciklama metni **KULLANICI ADININ ALTINDA** hizali; sol dolgu
    `kBaslikYanDolgu + 38 + kBaslikAra` ile **TURETILIR** (sabit sayi YOK).
  · `kKartYanDolgu` **6 -> `kYanBosluk` (16)**: kart artik kategori
    ("yemek") ekraniyla AYNI yan olcuyu kullanir. Turu 82b'nin *"yanda
    bosluk olmasin"* karari BILEREK geri alindi (gerekce serhte yazili).
  · ad 16 -> **17**; ••• kartin **SAG KENARINA** hizalandi (IconButton
    kutusu 48 -> 40, sag dolgu 8 eksik).
  · akista **video ilerleme cubugu YOK** (`kontrolGoster` kapisi) — yalniz
    ses ac/kapa; cubuk TAM EKRANDA duruyor.
  · paylas artik SAYI gosterir + yanina **repost** (`repeat2`).
    ⚠️ **DURUST SINIR: sunucuda paylasim/repost sayaci YOK** — alanlar 0
       varsayilan, `_eylem` sifiri hic yazmaz, yani gercek akista SAHTE sayi
       CIKMAZ. Repost dokununca paylasma sayfasini acar (altyapi yok).
- 📌 **TURU 98b/c/d — HIKAYE SERIDI:** canli yayin **KIRMIZI**, sesli oda
  **MOR**; ikisi de **KAPSUL** icinde **IKI KISI** gosterir (bindirme YOK,
  arada `kIkiliAra`=4 dp) + sag ustte izleyici sayisi + altta **ikonlu
  CANLI/ODA rozeti** (renk TEK BASINA renk korlugu olana hicbir sey
  anlatmaz). Fotografsiz her daire **duz gri** — **HARF YOK**
  (`_seritAvatar` TEK KAYNAK).
  ⚠️ Yayin durumu ve izleyici sayisi **SUNUCUDAN GELMIYOR** (demo verisi);
     gercek ozellikte serit yaniti `durum` + katilimci + izleyici dondurmeli.
- **ONCEKI (16 Agu 13:33): TURU 96u YAYINLANDI** — android
  **31941390675** + ios **31941392713** (**1446820**), R2 apk=121959543
  (md5 a6ba51e7) ipa=31621462 (md5 dc51e60e) index=11845 (md5 da111310)
  surum.json=48 (md5 f56871ff), purge OK, **CDN DORDU DE BIREBIR**, debug
  imza YOK, `HARITA=true` iki logda da dogrulandi.
  ⚠️ **BACKEND DEGISMEDI** → deploy YOK, **DB TRUNCATE EDILMEDI**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260816-1333
  · **96p** alt menu radius + 66dp yukseklik GERI (96o'da yanlislikla
    kaldirilmisti); logo cubugun ICINDE, kaldirma `min(15, (66-52)/2)` ile
    TURETILIR — tasma yapisal olarak imkansiz.
  · **96q-96u** menu: 4 sutun · kartlar kategori ekraniyla **BIREBIR**
    (gri kutu + altinda 14/w600 yazi, sabitler oradan IMPORT) · hizli erisim
    **tek satir yatay kaydirma** (Yakinimda · Nobetci Eczane · Durak · Taksi ·
    Akaryakit) + "HIZLI ERISIM" basligi · kategori sirasi kullanicidan
    (Yemek·Restoran·Cafe·Alisveris·Hizmet·Ilan·Dugun·Egitim·Saglik·Otel) ·
    Dugun/Organizasyon ayri · baslik altina slider · aramada TEMIZLE (X).
  ⚠️ **HARF ARALIGI (`letterSpacing`) YASAK** (kullanici emri): "Kategoriler"
     gibi basliklarda ozel bosluk kullanma.
- ⚠️⚠️⚠️ **TURU 96n-96p — "LOGONUN CEVRESINDE TIRTIKLAR" KOD DEGILDI (UC KEZ
  BILDIRILDI).** Kullanici sonunda *"profil dairesinde de ayni cizgi var"*
  dedi — o daire DUZ bir `BoxDecoration` dairesi. Denenen DORT sey de
  **piksel piksel AYNI** cikti: `cacheWidth`+`FilterQuality.medium` ·
  `Clip.antiAliasWithSaveLayer` · kirpmayi kaldirip daireyi SEKIL olarak
  cizme · **Skia** ile derleme. 6 kat buyutulunce kenar PURUZSUZ.
  **KOK NEDEN: emulator penceresinin ~2.5 kat kucultmesi.** Telefonda YOK
  (kullanici dogruladi).
  ⚠️⚠️ **OLCUM DERSI:** daire kenarini TAM SOL UCUNDAN olcup "anti-alias yok"
     dedim — orada kenar DIKEYDIR. "21px basamak" da dairenin KENDI
     geometrisiydi. **Egri kenari tek pikselden olcme — BUYUT VE BAK.**
  ⚠️ `--enable-impeller=false` HATALI; dogrusu **`--no-enable-impeller`**.
- ⚠️⚠️ **IKI YERLESIM TUZAGI (turu 96o/96t):**
  · **`suffixIcon`e KALAN GENISLIGIN TAMAMI verilir.** Aramadaki X ilk
    yazimda yalniz `height` + `Center` ile kuruldu -> X **inputun ORTASINDA**
    cikti ve **metne yer kalmadigi icin yazi GORUNMEDI**. Genislik ACIKCA
    verilir (44).
  · **`KategoriSlider` TAM EKRAN genisliginde cizilmek ZORUNDA** (yan boslugu
    kendi `viewportFraction`indan uretir). Menude dis dolgunun icindeydi ve
    bosluk IKI KEZ uygulaniyordu -> ilk slaytin solunda fazladan bosluk.
- ⏳ **DURUST SINIRLAR (turu 96t):** Durak/Taksi/Akaryakit kartlari YALNIZ
  kayitli isletmeyi gosterir (belediye/POI verisi YOK; arama kisayolu) ·
  "Nobetci Eczane" nobet verisi olmadan eczaneleri mesafeye gore listeler ·
  Restoran ve Cafe DB'de tek `kafe` kategorisi · menudeki slider BOS
  (reklam/kampanya verisi yok).
- **ONCEKI (15 Agu 22:09): TURU 96n YAYINLANDI** — android
  **31902434942** + ios **31902436964** (**33bb07b**), R2 apk=121959543
  (md5 1e4e6bf7) ipa=31627019 (md5 92282752) index=12077 (md5 e0970e6f)
  surum.json=48 (md5 e9e05839), purge OK, **CDN DORDU DE BIREBIR**, debug
  imza YOK, `HARITA=true` iki logda da dogrulandi.
  ⚠️ **BACKEND DEGISMEDI** → deploy YOK, **DB TRUNCATE EDILMEDI** (sema
     degismedigi icin kullanicinin oturumu/verisi KORUNDU, tohum atilmadi).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260815-2209
  **KULLANICI TELEFONDA TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 96n — "LOGONUN CEVRESINDE TIRTIKLAR" KOD DEGILDI (UC KEZ
  BILDIRILDI).** Kullanici sonunda *"profil dairesinde de ayni cizgi var"*
  dedi — o daire DUZ bir `BoxDecoration` dairesi (gorsel/kirpma/kenarlik YOK).
  Denenen DORT sey de **piksel piksel AYNI** cikti: (1) `cacheWidth` +
  `FilterQuality.medium`, (2) `Clip.antiAliasWithSaveLayer`, (3) kirpmayi
  TAMAMEN kaldirip daireyi `BoxShape.circle`+`DecorationImage` ile SEKIL
  olarak cizme, (4) **Impeller yerine Skia** ile derleme.
  Ekran belleginden alinan daire **6 kat buyutulunce PURUZSUZ**.
  **KOK NEDEN: emulator penceresinin ~2.5 kat kucultmesi** — her egri kenari
  basamakli gosterir. Telefonda yok.
  ⚠️⚠️ **OLCUM DERSI (iki kez yanildim):** daire kenarini TAM SOL UCUNDAN
     olcup "anti-alias yok" dedim — orada kenar DIKEYDIR, yumusatma zaten
     gorunmez. "En buyuk basamak 21px" olcumu de dairenin KENDI geometrisiydi.
     **Egri kenar kalitesini tek pikselden olcme — BUYUT VE BAK.**
  ⚠️ `flutter run --enable-impeller=false` **HATALI SOZDIZIMI** (komut hic
     kurulmaz, "Flag option should not be given a value" der). Dogrusu
     **`--no-enable-impeller`**.
- ⚠️⚠️ **SUREC (kullanici uyarisi 15 Agu):** *"emulatoru hizli arayuz icin
  yaptik, 1 saat oldu"* + *"sana soylediklerimi iki dk yapsana"*.
  **ARAYUZ TURLARINDA muhafiz testi / olcum betigi / bozma kaniti YAPILMAZ;**
  kod degistirilir, `flutter run` edilir, ekran gosterilir. Sertlestirme
  BUILD TURUNA biriktirilir.
- **ONCEKI (15 Agu): TURU 96j·96k·96l·96m KODU** — `flutter analyze` **0/0** ·
  `flutter test` **40/40** · calisma agaci temiz, `origin/main` senkron.
  · **96j** gorunum secici + meta satiri kalinligi (referans: filtre cipi) + kalpler 28
  · **96k** BOSLUK OLCEGI **8/12/16** (baslik↔kartlar · izgara ici · bolumler arasi)
  · **96l** ALT MENU kategori ekraninda da (`home/alt_menu.dart` TEK KAYNAK)
  · **96m** ALT MENU **SIYAH + YAZISIZ**, aktif beyaz / pasif `0xFF7A7A7E`,
    ikonlar 5dp yukari, **logo TAM DAIRE 52dp**, fotografsiz profilde
    **HARF DEGIL** `circleUserRound`, sistem gezinme cubugu ikonlari ACIK.
  ⚠️⚠️ **ALT MENU RENKLERI TEMADAN BAGIMSIZ SABIT** (`kAltMenuZemin` /
     `kAltMenuAktifIkon` / `kAltMenuPasifIkon`, `core/theme.dart`). Zemin
     sabit siyahken renk `onSurface`e baglanirsa **acik temada SIYAH ikon
     SIYAH zemine** cizilir ve **menu tamamen kaybolur**.
  ⚠️ **LOGO DAIRESINE IC DOLGU KOYMA**: 48'lik dairede 3px dolgu kirpmanin
     yalniz koseleri yemesine yol aciyordu -> ekranda **yuvarlatilmis KARE**
     (turu 96m'de olculdu). Gorsel daireyi TAM DOLDURUR (`cover`).
  ⚠️ Alt menude `etiket` parametresi **A11Y ICIN DURUYOR** (gorunur yazi yok);
     "kullanilmiyor" diye silme.
  🛡️ `mobile/test/alt_menu_test.dart` — **15 kontrol**, **DOKUZ BICIMDE bozularak
     KANITLANDI**. ⚠️ Silme.
- **ONCEKI (14 Agu 01:07): TURU 96i YAYINLANDI** — android
  **31748701025** + ios **31748703520** (**c2d6282**), R2 apk=121959483
  (md5 46fbcc66) ipa=31620789 (md5 66bb8661) index=12530 (md5 1199835d)
  **surum.json=48 (md5 ed2ac45e — YENI)**, purge OK, **CDN DORDU DE BIREBIR**,
  debug imza YOK, iOS min 16.0, HARITA=true, **IKI ARTIFACT'TE DE turu 96i
  kodu VAR**, **BACKEND DEPLOY** (c2d6282) + health ok.
  ✅ **CANLIDA 367/367 UCTAN UCA** · `flutter analyze` **0 hata 0 uyari** ·
  `flutter test` **19/19** · go build+vet+test temiz.
  🌱 DB TEMIZ + TOHUM (14 isletme · 2 kullanici · 14/14 randevu · dugun talebi
  + 3 teklif · dolu diyet gunu).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260814-0107
- ⚠️⚠️⚠️ **TURU 96i — TAM EKRAN KIRMIZI (KULLANICI SAHADA BILDIRDI).**
  Yerel `TextEditingController` diyalog KAPANIR KAPANMAZ dispose ediliyordu:

      final ctrl = TextEditingController();
      final x = await showDialog(... TextField(controller: ctrl) ...);
      ctrl.dispose();            // <-- COK ERKEN

  `showDialog`/`showModalBottomSheet` future'i **`pop` aninda** cozulur;
  route'un **CIKIS ANIMASYONU** (~150-250ms) surerken alt agac CIZILMEYE DEVAM
  EDER ve `EditableText` denetleyiciye dokunur -> *"A TextEditingController
  was used after being disposed."* -> `build` istisnasi -> `ErrorWidget`
  **EKRANIN TAMAMINI** kirmizi boyar (ardindan "RenderFlex overflowed by
  99750 pixels" ve `_dependents.isEmpty` cokuntuleri gelir).
  ⚠️⚠️ **HATA SESSIZDIR:** `flutter analyze` TEMIZ, uygulama COKMEZ, geri
     tusuna basilinca ekran **KENDILIGINDEN DUZELIR** -> "bazen oluyor" gibi
     gorunur ve tek bir ekrana baglanamaz. **KULLANICI SAHADA YAKALADI.**
  ⚠️ **TESHIS (kayda deger):** logcat'e HICBIR SEY dusmuyordu ve
     `uiautomator dump` TEK DUGUM veriyordu. Ekran duz **135,0,0** idi;
     Flutter kaynagi okundu: `RenderErrorBox.backgroundColor = 0xF0900000`
     -> siyah ustunde 144*240/255 = **135**, TAM ESLESME.
     Istisna ancak **`sleep 900 | flutter run`** (stdin ACIK tutularak)
     goruldu — etkilesimsiz `flutter run` stdin kapaninca CIKIYOR.
  **ALTI YERDE VARDI**: konum_secici · etkinlik (2 denetleyici) · urun ×2 ·
  randevu · gonderi_karti. FIX: **`core/denetleyici_sahibi.dart`** (TEK
  KAYNAK) — denetleyici diyalogun KENDI agacinda yasar, route gercekten
  sokuldugunde birakilir. Metin `await`ten hemen sonra **SENKRON** okunur.
  🛡️ **`mobile/test/denetleyici_test.dart`** — bozularak KANITLANDI
     (yesil -> kirmizi -> yesil).
  ⚠️ YAPMA: cagri yerlerine tekrar `ctrl.dispose()` koyma.
- ⚠️⚠️⚠️ **TURU 96i — KONUM PANELI SUNUCUDA ADRES VARKEN "yok" DIYORDU.**
  `internal/isletme/adres.go` paketin kendi **`yaz()` yardimcisini ATLAYIP**
  ciplak `json.NewEncoder(w).Encode` kullaniyordu -> **Content-Type YAZILMAZ**
  -> Go govdeyi koklayip `text/plain; charset=utf-8` koyar -> **Dio
  AYRISTIRMAZ**, `response.data` bir **String** olur -> `data['adresler']` ->
  *"type 'String' is not a subtype of type 'int' of 'index'"* -> istemcideki
  `catch (_)` **YUTAR** -> panel "Kayitli konumun yok" der.
  ⚠️⚠️ **UCTAN UCA BILE GECIYORDU (365/365)**: Node tarafinda `JSON.parse`
     **BASLIGA BAKMAZ**. Yani yesildi ve ozellik yine de OLU DOGDU.
     **DERS: bir yanitin DOGRU olmasi, ISTEMCININ onu OKUYABILECEGI anlamina
     GELMEZ — BASLIK DA SOZLESMENIN PARCASIDIR.**
  🛡️ **`internal/sutunkontrol/icerik_turu_test.go`**: `internal/` ve `cmd/`
     altinda `json.NewEncoder(w)` iceren HER fonksiyon
     `Header().Set("Content-Type"` de icermeli. Bozularak KANITLANDI.
  🛡️ E2E `j()` artik `tur` (Content-Type) donduruyor + `jsonMu()` kontrolleri
     (**365 -> 367**).
  ⚠️ Sessiz `catch` artik `debugPrint` + Sentry (teshis emulatorde ELLE
     arandi — bir daha aranmasin).
- ⚠️ **TURU 96i — HER SOGUK ACILISTA ASSERTION:** `ref.invalidate`
  `initState` GOVDESINDE cagriliyordu (`live_tab` + `rooms_tab`). Riverpod
  kapsayiciya `dependOnInheritedWidgetOfExactType` ile ulasir ve `initState`
  bitmedigi icin Flutter assertion atar; `home_screen`deki `IndexedStack` tum
  sekmeleri acilista kurdugu icin **HER SOGUK ACILISTA** dusuyordu.
  FIX: `addPostFrameCallback`. ⚠️ YAPMA: govdeye geri tasima.
- ⚠️⚠️ **INDIR SAYFASI — "SAATI GOREMIYORUM" BESINCI KEZ; ARTIK SAYFA KENDINI
  KONTROL EDIYOR.** Sunucu YINE dogru cikti (OLCULDU): `text/html; charset=utf-8`
  + `no-cache, no-store, must-revalidate` + `cf-cache-status: DYNAMIC` + saat
  **5 yerde** + akan canli saat + **ciplak alan adi BIREBIR ayni govdeyi
  veriyor** (10346 = 10346). Kalan tek aciklama TARAYICI ONBELLEGI — o durumda
  sayfaya "saat yaz" demek **ISE YARAMAZ** (kullanici ZATEN eski sayfaya
  bakiyor, orada eski saat yazar).
  FIX: her yayinda **`surum.json`**; sayfa acilista onu `cache: 'no-store'` +
  `?t=` ile ceker, GOMULU surumuyle karsilastirir, farkliysa **EN USTTE
  KIRMIZI SERIT** + tek dokunusla taze adres. Ag hatasinda SESSIZ.
  ⚠️ `surum.json` `index.html` ile **AYNI KOSUDA** yazilir ve
     **`node tools/indir/r2yukle.js tools/indir/surum.json surum.json` ile
     BIRLIKTE YUKLENIR** (ayrisirsa sayfa kendini sonsuza kadar "eski" sanip
     surekli "YENI SAYFAYI AC" gosterir).
  ⚠️ Uretici muhafizi bu blogun varligini ZORUNLU kilar.
- **KALDIGIMIZ YER (12 Agu): TURU 93 + 93b KODU BITTI, BACKEND DEPLOY**
  + health ok. ✅ **CANLIDA 349/349 UCTAN UCA** · **213 ROTA CAKISMASIZ** ·
  `flutter analyze` **0 hata 0 uyari** · `flutter test` **11/11** ·
  `go build`+`go vet`+`go test` temiz. 🌱 DB TEMIZ + TOHUM (10 isletme,
  **5'inde KAPAK**, 10/10 randevu, dugun talebi + 3 teklif, dolu diyet gunu).
- ⚠️⚠️⚠️ **TURU 93b — ALT KATEGORI KARTLARININ HEPSI BOS SONUC DONDURUYORDU
  (SEVK ENGELI).** Turu 92'nin MANSET OZELLIGI olu dogacakti. Kart bir arama
  kisayolu ("Saç Kesim" -> `q=saç`) ama yuklem YALNIZ `u.name`/`u.username`e
  bakiyordu; eslesmesi gereken metin (`Saç kesimi`) **URUN KATALOGUNDA**.
  Isletme adi "Kuaför Serkan" ve icinde "saç" GECMEZ. Tohum verisiyle bire bir
  sayildi: veri bulunan bes kategoride **25 kartin 25'i de BOS**.
  ⚠️ `altkategori.go` serhi *"ad/aciklama uzerinde arama BUGUN calisir"*
     diyordu — `isletmeler` tablosunda **`aciklama` SUTUNU YOK**. Ustelik
     serh reddettigi alternatifi *"kartlarin HEPSINI BOS dondururdu"* diye
     eliyordu: **SECILEN YOL DA TAM BUNU YAPIYORDU.**
  ⚠️⚠️ **DERS: muhafiz bunu GOREMEZ.** `altkategori_test.go` yalniz `Ara`
     alaninin DOLU oldugunu olcer. **Hicbir seyle eslesmeyen dolu bir `Ara`,
     kullanici acisindan BOS `Ara` ile BIREBIR AYNIDIR.** "Alan var mi"
     olcmek, "is goruyor mu" olcmek DEGILDIR.
  FIX: yuklem urun katalogunu da tarar.
  ⚠️ `EXISTS` ZORUNLU, `JOIN` DEGIL: JOIN ile uc urunu eslesen isletme
     listede **UC KEZ** cikardi.
  ⚠️ `lower()` KULLANILMADI: `ILIKE` zaten harf duyarsiz ve `lower()`
     Turkce'de "İ" icin YANLIS sonuc verir.
  ✅ CANLI: kuafor/saç=2 · saglik/dahiliye=1 · diyetisyen/sporcu=1 ·
     guzellik/cilt=1 (duzeltmeden ONCE **hepsi 0**).
- ⚠️⚠️ **TURU 93b — KART + YAZI BIRLIKTE KULLANILINCA LISTE KALICI BOSALIYORDU.**
  Istemci iki terimi bosluklu birlestirip tek `q` gonderiyor; yuklem bunu
  **TEK BITISIK ALT DIZE** ariyordu: `q="saç serkan"` -> `ILIKE '%saç serkan%'`.
  "Kuaför Serkan" eslesmez, **"Serkan Saç" bile eslesmez** (sira ters).
  FIX: `q` kelimelere bolunur, HER KELIME bir alanda gecmelidir (**AND**).
  ⚠️ E2E bunu `saç zurafa` -> 0 ile dogruluyor (OR degil AND kaniti).
- ⚠️⚠️⚠️ **TURU 93b — KATEGORI EKRANINDA ISLETME LISTESI GORUNMUYORDU
  (IKINCI SEVK ENGELI).** `Expanded`in USTUNDEKI sabit bloklar olculdu:
  48 + 10 + **350** + 58 + 92 + 56 = **614px**.
  · 360x800 (en yaygin modern Android): listeye **162px** kaliyor, bir kart
    ~250px -> **AD VE META HIC GORUNMUYOR**
  · 360x640 + 3 tus navigasyon: `Expanded` NEGATIF alan alir ->
    **RenderFlex overflowed**
  · 414x896 (TEST CIHAZI): 238px — yine tek kart bile sigmiyor
  FIX: govde **`CustomScrollView`**; slider/arama/60x60 serit/filtre artik
  **LISTENIN PARCASI** (Yemeksepeti/Getir deseni).
  ⚠️ **Slider 350px KORUNDU** (kullanici olcusu) — sorun yukseklik DEGIL,
     SABIT bir dikey butceyi listeden CALMASIYDI.
  ⚠️ `AlwaysScrollableScrollPhysics` ZORUNLU (bos listede asagi-cek).
  ⚠️ YAPMA: tekrar `Column` + `Expanded`e cevirme.
- 📌 **TURU 93 — KATEGORI EKRANI INCE AYAR (kullanicinin 11 maddesi).**
  Kart ici harf YOK · arama odak kenarligi `0xFF1A1A1A` · ikon bir tik kalin ·
  ikon-yazi boslugu az · slider %100 DEGIL · header `arrow-left` + harita,
  **daire YOK**, altinda 10px · filtrelerde **YESIL YOK** · **hepsi tek yatay
  dolguda** (`kYanBosluk`) · gri bir kat koyu · alt metin 16 · kartlar
  **Getir/Yemeksepeti** duzeni (16:9 kapak + ad + rozet + meta).
  ⚠️⚠️ **`strokeWidth` YOKTUR**: `lucide_icons_flutter` ikonlari bir **FONT**
     olarak sunar (glif), SVG DEGIL. Kalinlik ayni renkte ±0.4px kaydirilmis
     **DORT GOLGE** ile simule edilir. `Icon`a `strokeWidth` yazarsan DERLENMEZ.
  ⚠️⚠️ **PUAN / TESLIMAT SURESI / MIN. TUTAR UYDURULMADI**: referans ekranda
     var ama bu projede o verilerin **HICBIRI YOK**. Sahte deger kullaniciya
     YANLIS BILGI olurdu. ⚠️ YAPMA: yer tutucu puan/sure/mesafe ekleme.
  📌 Sunucu: liste sorgusuna `u.kapak_media_id` (SELECT + Scan + yanit
     haritasi **UCU BIRLIKTE**). Gorsel sirasi: kapak -> avatar -> gradyan
     yer tutucu (KIRIK GORSEL CIZILMEZ).
- ⚠️⚠️⚠️ **TURU 93b — MUHAFIZ YALANCI-YESILDI (turu 89 dersinin TEKRARI).**
  `internal/isletme/sutun_test.go` YALNIZ `Detay` ve `Urun` sorgularini
  kapsiyordu. Turu 93'te `kapak_media_id` **Liste** sorgusuna eklendi;
  yanit haritasindan CIKARILIP test kosuldu ve **YESIL GECTI**.
  ⚠️ **DERS: bir muhafizin yesil olmasi, DEGISTIRDIGIN YUZEYI olctugu
     anlamina GELMEZ.** Yeni sutun eklerken once "bu sorgu muhafizin
     KAPSAMINDA mi" diye SOR.
  Artik SELECT/Scan sayisi + **SIRA** + yanit haritasi olculuyor.
  ✅ UC BICIMDE kirmizi dusuruldu: (a) yanittan sutun cikarma, (b) SELECT'ten
     sutun cikarma, (c) `i.il` <-> `i.ilce` TAKASI.
  ⚠️⚠️ **(c)'nin ILK denemesi YANLIS KURULMUSTU**: desen dosyada ONCE gecen
     `Detay`in haritasini vurdu ve `-run TestListe` suzgeci yuzunden test
     YESIL kaldi. **Bozma kanitinin DOGRU YERI bozdugunu da DOGRULA.**
- 🎯 **TURU 93b — "HER KATEGORI AYRI" (kullanici emri).**
  7 kategori (`giyim`,`eczane`,`emlak`,`teknoloji`,`eglence`,`hizmet`)
  `sliderVarsayilan`a dusuyor ve **BIREBIR AYNI** uc slaydi gosteriyordu.
  ⚠️ Muhafiz ASIMETRIKTI: `altKategoriler` icin ILERI YON zorlaniyor,
     `kategoriSlider` icin YALNIZ TERS YON olculuyordu — ayni testte, ayni
     amac icin IKI FARKLI sikilik.
  FIX: alti kategoriye ozel metin + muhafiza **ileri yon kapsama** +
  **slayt basligi TEKRARI YASAGI**. ✅ Iki bicimde kirmizi dusuruldu.
  ⚠️ `diger` BILINCLI MUAF (`sliderMuaf`, gerekcesi yazili).
  ⚠️ YAPMA: yeni kategori eklerken slider girisini yazmadan gecme.
- ⚠️⚠️⚠️ **TURU 93b — DIYETISYEN BAGLANTISI %100 OLUYDU (SEVK ENGELI).**
  `DiyetServisi.bagIste()` yazilmisti ama **HICBIR YERDEN CAGRILMIYORDU**
  (`grep -rn "bagIste" lib/` -> yalniz TANIMIN KENDISI). Hicbir kullanici
  `diyet_bag` satiri OLUSTURAMIYORDU: `Danışanlarım` DAIMA bos · `Diyetim`
  *"bir diyetisyen bul ve istek gonder"* diyor ama **oyle bir dugme YOKTU** ·
  liste yazma / danisan detayi ULASILAMAZ · `diyet_istek`/`diyet_liste`
  bildirimleri HIC dogmaz. Kullanicinin manset emri sahada TAMAMEN oluydu.
  FIX: diyetisyen PROFILINE **"Diyetisyenim ol"** (dogru yer: bir diyetisyene
  ulasmanin gercek yolu onun profilidir). ⚠️ YAPMA: bu girisi kaldirma.
- ⚠️⚠️ **TURU 93b — DIYET LISTESI YALNIZ YAZILDIGI GUN GORUNUYORDU.**
  Gun seridiyle AYNI tarih araligindan suzuluyordu; diyetisyen listeyi YAZDIGI
  gune kaydeder. Pazartesi gonderilen liste SALI **YOK**. Kullanicinin
  istedigi **KALICI BIR PLAN**, gunluk kayit degil.
  FIX: liste icin AYRI, TARIHSIZ cagri (`kayitlar(tur:'liste')`); gun seridi
  yalniz ogun/olcum bolumunu surer.
- 💰 **TURU 93b — PARA HATASI: `_kurusOku("85.000")` = 85 ₺ IDI.**
  Nokta ONDALIK sayiliyordu. Teklif listesi **FIYATA GORE** siralandigi icin
  bu isletme listenin **BASINA** cikiyor ve "en ucuz" diye seciliyordu.
  ⚠️ `flutter analyze` bunu GORMEZ, sunucu da goremez (100 kurus da gecerli).
  FIX + **`mobile/test/kurus_test.dart`** (11 vaka). ✅ Kaynaktan dal
  cikarilip KIRMIZI dusuruldu. ⚠️ YAPMA: bu testi silme.
- ⚠️⚠️ **TURU 93b — DIGER ONAYLI BULGULAR (hepsi duzeltildi):**
  · **HIZMET TALEBI SORANIN KARSISINA DUGUN FORMU CIKIYORDU** ("Temizlik"
    talebinde *Gelinlik · Gelin arabası · Kır düğünü*). Alanlar artik
    **SUNUCUDA** kategoriye gore suzuluyor (`GET /ilan-kategoriler?kategori=`);
    hizmet/ders/diyet dallarina KENDI sorulari yazildi.
    ⚠️ Istemciye sabit EKLENMEDI (turu 77 kurali). ⚠️ Bos `Kategoriler` =
       HER kategoride gorunur -> mevcut TUM turler DEGISMEDEN calisir.
    ⚠️ `dugunKategorileri` SABIT LISTE, "dugun_" ONEKI DEGIL: `gelinlik`,
       `sac_makyaj`, `davetiye`, `gelin_arabasi` o oneki TASIMAZ ve onek
       kontrolu bu dordunu SESSIZCE hizmet dalina dusururdu.
  · **KISISEL HESAP "Teklif ver" DUGMESINI GORUYORDU** ve sunucunun
    ACIKLAYICI 403'u ("işletme hesabına geçmelisin") jenerik metne
    cevriliyordu -> kullanici sebebini ogrenemeden TEKRAR TEKRAR deniyordu.
    Dugme yerine SEBEP yaziliyor (sessizce kaybolan dugme "ozellik yok" gibi
    gorunur) + `apiErrorMessage(e)`.
  · **KAZANAN TEKLIFINI GERI CEKEBILIYORDU** -> talep `satildi` KILITLI,
    kazanan YOK, digerleri elendi ve talebi YENIDEN ACAN HICBIR YOL YOK.
    Kapi: `AND durum <> 'secildi'`.
  · **"Görüldü" SECILMIS teklifin uzerinde de duruyordu** ve secimi GERI
    DUSURUYORDU (istemci + **SUNUCU** kapisi — arayuz TEK BASINA yetmez).
  · **"revize edildi" HER TEKLIFTE ciziliyordu**: `guncellendi_at`
    `NOT NULL DEFAULT now()` ile eklendigi icin HER SATIRDA DOLU. Olcut artik
    **ZAMAN FARKI** (`created_at` istemciye eklendi).
  · **`PATCH /diyet/kayit` KALORI TAVANINI UYGULAMIYORDU** (POST'ta vardi) ->
    `SUM(kalori)::int` **integer out of range** -> `/diyet/ozet` KALICI 500
    ve "Diyetim" ozeti BIR DAHA ACILMAZ.
  · ⚠️ **GIZLILIK: `diyetErisim` CIFT YONLUYDU** — aktif bagi olan DANISAN,
    `?user_id=<diyetisyen>` ile **DIYETISYENIN KENDI kilo/olcum/ogun**
    verisini okuyabiliyordu (SAGLIK VERISI). Okuma **TEK YONLU** yapildi:
    diyetisyen danisani gorur, tersi GORMEZ. ⚠️ YAPMA: cift yone dondurme.
  · **BAG SONLANDIKTAN SONRA eski diyetisyen YAZMAYA devam edebiliyordu**
    (`yazan_id` tek basina yetiyordu). 045'in kendi sozu: *"gecmis korunur,
    ERISIM KORUNMAZ"*.
  · **`svc.detay()` PATLARSA KULLANICI TALEBI IKINCI KEZ OLUSTURUYORDU**
    (+ hedef isletmelere IKINCI fan-out). `detay` AYRI `try`a alindi.
  · Besin aramasinda **debounce YOKTU** (her tusta istek) + yanit yarisi.
  · **`_kesfiYukle`de BAYAT YANIT KAPISI YOKTU** (kardes `_yukle`de VARDI):
    hizli kategori degisiminde "Kuaför" secili gorunurken **Döner/Kebap**
    kartlari ciziliyordu.
  · **`_altSecili` sifirlamasi UC daldan yalniz BIRINDE vardi** -> "Tümü"ye
    basan kullanicida **GORUNMEZ bir suzgec** takili kaliyordu. Tek kapi:
    `_kategoriSec()`. ⚠️ YAPMA: `_kategori`ye o metodun DISINDA atama yapma.
  · Kesif istegi patlarsa ekranin tepesinde **350px BOS GRI KUTU** kaliyordu.
  · **Kart kapagi TAM DOSYA indirip 2048px decode ediyordu** (kullanicinin
    "bir tik kasiyor" sikayetinin kaynagi) -> genislik ACIKCA veriliyor.
  · `kYanBosluk` "TEK KAYNAK" serhi **AYNI DOSYADA IKI YERDE** ihlal edilmis.
  · 60x60 serit **92px SABITTI**; yazi olcegi **1.15**'te (ilk kademe) TASIYOR.
    Yukseklik artik `textScaler`dan turetiliyor.
  · 60x60 kartlar acik temada kontrast **~1.06** ile GORUNMEZDI (ustelik
    slider zemininden DAHA ACIK -> hiyerarsi TERS).
  · Filtre rozeti `_altSecili`yi saymiyordu · cip dokunma alani **36dp** idi
    (Material 48) · bos listede asagi-cek CALISMIYORDU · **`baslik` parametresi
    OLUYDU** (6 cagri yeri veri geciyor, ekran HIC okumuyordu).
- 🌱 **TURU 93b — TOHUMA KAPAK GORSELI** (`tools/kapak_uret.js`, bagimliliksiz
  PNG, salt `zlib`). Isletmelerin **YARISINA** verilir ki kullanici IKI DALI
  DA (kapakli/kapaksiz) ayni listede yan yana gorup tasarimi degerlendirsin.
  ⚠️ **AI ILE URETILMEDI**: (a) PARA harcar + gunluk kotayi yer, (b)
     `/ai/gorsel` `kind='image'` uretir ve `PATCH /users/me` kapak icin
     `kind='kapak'` sartini **403** ile DAYATIR.
  ⚠️ Uretilen gorsel bir FOTOGRAF DEGIL, desenli bir kapaktir — sahte yemek
     fotografi gosterilmiyor.
  ⚠️ EN IYI CABA (hata tohumu BOZMAZ): degeri aninda olculdu — ilk kosuda
     `require` unutulmustu, tohum bozulmadan devam etti ve eksik SATIRDAN
     gorundu.
- ⚠️⚠️ **TURU 93b — `tools/indir/r2put.js` ARTIK HTML YUKLEYEMEZ.**
  Kullanici **DORT TURDUR** "indir sitesinde saati goremiyorum" diyor ve
  sunucu tarafi HER SEFERINDE dogru cikiyor. Turu 85b'de OLCULEN kok neden
  BU DOSYANIN varsayilani (`application/octet-stream`) idi: `index.html` o
  baslikla yuklenince tarayici sayfayi **CIZMEZ, DOSYA OLARAK INDIRIR**.
  Duzeltme `r2yukle.js`e tasinmisti ama **bozuk varsayilan AYNI DIZINDE,
  BENZER ISIMLE kaldi** — yanlis araci secmek icin tek gereken iki isimden
  birini yazmak, hata da SESSIZ.
  FIX: `.html/.css/.js/.json/.txt/.xml/.svg` uzantisini ACIK tur olmadan
  yuklemeyi **REDDEDER** (cikis kodu 1) ve dogru araci gosterir.
  ⚠️ **SURUM RUTININDE `node tools/indir/r2yukle.js` KULLAN.**
- 📌 **MIGRATION NUMARALARI (guncel):** 045 = teklif (`ilan_basvurular.fiyat_kurus`
  + `guncellendi_at`) + diyet (`diyet_bag`, `diyet_kayit`). Sonraki **046**'dan.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.
  ⚠️ `beklemeyeAl`in `!bekletmeAcik` dali **CANLI** — silinirken KORUNMALI.

- **KALDIGIMIZ YER (11 Agu 23:08): TEST TURU 92 YAYINLANDI** — android
  **31530038962** + ios **31530042894** (**9558e76**), R2 apk=121745231
  (md5 d923054b) ipa=31586912 (md5 bd2318b2) index=9673 (md5 c5e0d025),
  purge OK, **CDN BIREBIR (ucu de)**, indir sayfasi 11 Agu 23:08 (saat 5
  yerde), debug imza YOK, iOS min 16.0, HARITA=true, **BACKEND DEPLOY** +
  health ok. ✅ **CANLIDA 341/341 UCTAN UCA** · **213 ROTA CAKISMASIZ** ·
  `flutter analyze` 0/0 · `flutter test` 6/6.
  🌱 DB TEMIZ + TOHUM (10/10 randevu + dugun talebi + 3 teklif + diyet).
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260811-2308
- **TURU 92 — KATEGORI EKRANI YENIDEN KURULDU** (kullanici emri).
  Ustte 350px slider (alta bakan radius, cok hafif gri, 3sn, BUTON YOK) ·
  AppBar YOK, geri (sol ust) + **harita (sag ust)** opak beyaz ikonlar ·
  arama · **60x60 alt kategori kartlari** · **Filtrele** + sik filtreler.
- ⚠️⚠️ **TURU 92 — ALT KATEGORI VE SLIDER METINLERI SUNUCUDAN**
  (`internal/isletme/altkategori.go`, 17 kategori + 11 slider seti).
  Kullanici: *"her kategori FARKLI"*. Istemciye sabit yazmak turu 77
  kuralinin ihlali olurdu: yeni bir alt kategori MAGAZA ONAYI gerektirir ve
  eski surumler listeyi EKSIK gosterirdi. Bir slayt cumlesi degistirmek
  artik DEPLOY yeter.
  ⚠️ **ALT KATEGORI = ARAMA KISAYOLU, AYRI SUTUN ACILMADI.**
     `isletmeler.alt_kategori` eklemek isletmelerin o alani DOLDURMASINI
     gerektirirdi; bugun hicbir kayitta dolu olmayan bir sutun kartlarin
     HEPSINI BOS SONUC dondururdu. ⚠️ YAPMA: bunun icin migration acma.
  ⚠️ TEK UC (`/isletme-kesif`) IKI VERI dondurur — ayri iki uc acilista
     IKI istek demekti (turu 91 performans dersi).
- ⚠️ **TURU 92 — IKINCI HARITA EKRANI YAZILMADI:** `YakinimdaEkrani`
  `kategori` parametresi aldi. O ekranda harita stili muhafizi, jest
  cakismasi cozumu (`EagerGestureRecognizer`), kamera takibi ve adresten
  pin cozumleme ZATEN var (turu 85-88); kopyasi drift ederdi.
- ⚠️ **TURU 92 — SLIDER TUZAKLARI:** `ClipRRect` ZORUNLU (yalniz
  `BoxDecoration` ile `PageView` kose disina TASAR) · nokta gostergesi
  `IgnorePointer` (kullanici "BUTON YOK" dedi) · TEK slaytta zamanlayici
  KURULMAZ · `dispose`ta zamanlayici ONCE iptal edilir (dispose edilmis
  `PageController`a `animateToPage` PATLAR) · `didUpdateWidget`te slayt
  sayisi degisirse zamanlayici YENIDEN kurulur.
- ⚠️ **TURU 92 — KATEGORI DEGISINCE `_altSecili` SIFIRLANIR:** "döner"
  secili kalip kategori "Kuaför"e gecerse sonuc DAIMA BOS olurdu ve
  secili kart artik cizilmedigi icin kullanici sebebini GOREMEZDI.
  ⚠️ `_kesfiYukle` DE cagrilir (alt kategoriler kategoriye ozel).
- 🛡️ **TURU 92 — UC MUHAFIZ, UCU DE BOZULARAK KANITLANDI**
  (`altkategori_test.go`): (a) her kategorinin alt kategorisi olmali
  (`kuafor` silindi -> KIRMIZI) · (b) `Ara` BOS OLAMAZ, bos arama metni
  karti TAMAMEN ETKISIZ yapar (bosaltildi -> KIRMIZI) · (c) slayt sayisi
  3-4 + metin uzunluk tavanlari (baslik 61 karaktere cikarildi -> KIRMIZI).
  Ayrica TERS YON: haritada var olmayan kategori girisi de yakalanir.

- **ONCEKI (11 Agu 19:06): TEST TURU 91 YAYINLANDI** — android
  **31509234749** + ios **31509238078** (**cee3038**), R2 apk=121728599
  (md5 4a2dff31) ipa=31584232 (md5 a56b7c2a) index=9771 (md5 4f63d676),
  purge OK, **CDN BIREBIR (ucu de)**, indir sayfasi 11 Agu 19:06 (saat 5
  yerde + canli saat), text/html + no-store + DYNAMIC, debug imza YOK,
  **iOS min 16.0**, HARITA=true dogrulandi, **IPA'da turu 91 kodu VAR**
  (dizeler UTF-16 arandi), **BACKEND DEPLOY** (migration 045 canlida;
  atilabilir kopyada 001->045 temiz = 53 tablo) + health ok.
  ✅ **CANLI SUNUCUDA 336/336 UCTAN UCA** · **211 ROTA CAKISMASIZ** ·
  `flutter analyze` **0 hata 0 uyari** · `flutter test` 6/6 · go build+vet temiz.
  🌱 **DB TEMIZ + TOHUM**: 10 isletme (10/10 randevu 201) · 2 kullanici ·
  2 ilan · 2 etkinlik · **dugun talebi + 3 teklif** · **diyet zinciri**.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260811-1906
- **TURU 91 — DORT IS:** dugun/hizmet **TEKLIF AKISI** (Armut deseni) ·
  **DIYET TAKIBI** · kategori **IZGARASI** · **PERFORMANS**.
- ⚠️⚠️ **TURU 91 — TEKLIF: YENI TABLO ACILMADI.** `ilan_basvurular` ZATEN
  "cok kisi -> tek ilan" istek/yanit iliskisi; teklif de "cok isletme ->
  tek talep". Yon BIREBIR AYNI. **YASAK TESTI (bu turda formullestirildi):**
  bir migration yasagi ancak **AYNI KAVRAM + AYNI GORUNURLUK + AYNI
  AKTORLER** ucu birden tutuyorsa baglayicidir. GIZLI KAZANC: turu 90'in
  bes ucu, yetki kapilari, `geri_cekildi` semantigi ve 1 saatlik bildirim
  bastirmasi DOKUNULMADAN miras alindi.
- ⚠️⚠️⚠️ **TURU 91 — TALEP HERKESE ACIKTIR** (migration 045 basinda yazili).
  Tercih degil, `ilanlar`in her yerine gomulu bir gercek (`media` ilan dali
  TEK KAPI olarak `durum <> 'kaldirildi'` + engel diyor).
  ⚠️ YAPMA: talep satirina isim/telefon/adres/"gizli butce" ekleme —
     eklenecekse `ilanlar` YANLIS EVDIR ve o dal MIRAS ALINAMAZ.
  ⚠️ Sihirbazin SON ADIMINDA kullaniciya bu ACIKCA soylenir.
- ⚠️⚠️ **TURU 91 — TALEP SIZINTI KAPISI (sevk engeli onlendi).** Talepler
  `ilanlar`da yasiyor; kapi olmasaydi "Sahibinden Ford Focus" ile "Düğün
  yapacağım" AYNI LISTEDE yan yana cikardi. `tur` BOSKEN
  `AND i.tur <> 'talep'`; `benim=1` MUAF.
- ⚠️⚠️ **TURU 91 — TEKLIF KAPILARI:** yalniz ISLETME (403 + ne yapmasi
  gerektigi) · FIYAT ZORUNLU (liste fiyata gore sirali) · **TAVAN 5,
  ADVISORY KILIT ICINDE** (`INSERT ... WHERE count < 5` READ COMMITTED'da
  escamanli iki istegi de gecirir — turu 79b'de AI kotasinda TAM BU yasandi)
  · 7 GUNLUK PENCERE **OKUMA VE YAZMA**da AYNI sabitten (`TalepPenceresi`;
  turu 80b'de `ileri_gun` iki tabanda olculunce arayuz "musait" gosterip
  POST 400 donmustu).
  ⚠️ SAHIPLIK KAPISI TALEP KAPILARININ **ONUNDE**: sonda kalsaydi kendi
     talebine teklif veren kisisel hesapli sahibi "işletme hesabına geç"
     mesaji alir ve GEREKSIZ bir hesap turu degisikligine yonlendirilirdi.
- ⚠️⚠️ **TURU 91 — `secildi` TEK ISLEMDE UC YAN ETKI:** kazanan isaretlenir ·
  digerleri `elendi` · talep `satildi`. Ayri isteklerde "kazanan var ama
  talep acik" gibi YARIM durumlar kalirdi ve secim GERI ALINAMAZ.
  ⚠️ Bildirim COMMIT'TEN SONRA (geri alinan islem icin "teklifin secildi"
     bildirimi gonderilmis olurdu). ⚠️ Elenenlere bildirim GONDERILMEZ.
  ⚠️ Is ilaninda yan etki UYGULANMAZ (birden fazla kisi ise alinabilir).
- ⚠️⚠️⚠️ **TURU 91 — DIYET: `diyet_bag` RIZA KAYDININ GEREKCESI HUKUKI.**
  Mevcut hicbir tablo "bu kisi benim SAGLIK VERIMI gorebilir" rizasini
  temsil etmiyor (`follows` tek yonlu sosyal · `randevular` tek seferlik ·
  `chats` mesajlasma). ⚠️ `baslatan_id` ZORUNLU: olmadan taraflardan biri
  KENDI istegini KENDISI onaylayabilirdi.
  ⚠️ **`diyetErisim()` TEK KAYNAK** ve FAIL-CLOSED. Yuklemi cagri yerlerine
     kopyalamak SAGLIK VERISI SIZINTISI demektir.
  ⚠️ `liste` YAZMA icin `diyetErisim` YETMEZ (o kapi CIFT YONLU) — ayri,
     tek yonlu yuklem yazildi.
  ⚠️ `ogun`/`olcum`da govdedeki `user_id` YOK SAYILIR: aksi halde biri
     baskasinin gunune 5000 kalori ekleyebilirdi.
  ⚠️ KISIYE OZEL diyet listesi `isletme_urunleri`ne YAZILAMAZ:
     `GET /users/{id}/urunler` HERKESE ACIK -> saglik verisi ANINDA sizar.
- ⚠️ **TURU 91 — `diyet_kayit.tarih` AYRI `DATE` SUTUNU**, `created_at`ten
  TURETILMEZ: (a) kullanici DUN yedigini BUGUN girebilmeli, (b) UTC/yerel
  farkiyla gece yarisindan sonraki ogun BIR ONCEKI gune yazilirdi.
- 📌 **TURU 91 — BESIN LISTESI GO'DA GOMULU** (~85 Turkce kalem), tabloda
  DEGIL: kucuk, sabit, KIMSEYE AIT OLMAYAN bir lookup (turu 77 kategori
  agaci gerekcesi). ⚠️ Turkce kucultme ELLE: `strings.ToLower` "İ"yi
  birlesik noktaya cevirir ve "İSPANAK" aramasi "ispanak"i BULAMAZDI.
- ⚠️ **TURU 91 — `/ai/kalori` `tur="kalori"`**, "gorsel" DEGIL (turu 79b
  sevk engelinin tekrarini onler). `grep 'h.kapi(w, r,'` ile TUM cagri
  yerleri TARANDI. Sonuc DOGRUDAN KAYDEDILMEZ, ONERI doner.
- 📌 **TURU 91 — KATEGORI IZGARASI (kullanici emri, DUZELTME).** Turu 90'da
  "5 tane alt alta" denmis, TEK SUTUN yapilmisti; turu 91'de netlesti:
  **SOLDAN SAGA akan, ASAGI ~5 satir, ESKI KARTLARIN KUCUGU**. 3 sutun,
  360dp'de hucre 102.7x125.2 · 414dp'de 120.7x147.2. "Yakınımda" USTTE
  AYRI + "KATEGORİLER" basligi KALDI. Yeni iki kart ILK IKI SIRADA.
- 🚀 **TURU 91 — PERFORMANS ("bir tik kasiyor"):**
  1. **`memCacheWidth`** — EN BUYUK KAZANC. Bayrak yokken 1600x1600 bir
     fotograf 120dp'lik hucre icin TAM COZUNURLUKTE cozuluyordu (~10 MB
     gecici RAM/kare). ⚠️ `devicePixelRatio` ile carpilir (yoksa BULANIK).
  2. **SEMAFOR (6) + ISTEK BIRLESTIRME** — soguk acilista ~60 ES ZAMANLI
     `/media/{id}/url` istegi havuzu doyuruyor ve ana isolate 60 JSON
     cozumuyle mesgul oluyordu. ⚠️ `finally` ZORUNLU (sayac dusmezse kuyruk
     KALICI kilitlenir); ⚠️ `whenComplete` ile kayit HEM basarida HEM hatada
     dusurulur (yoksa bir kez patlayan id SUREC BOYUNCA hatali Future'i
     paylasirdi).
  3. `shrinkWrap` KALDIRILDI · kartlar `RepaintBoundary` icinde.
- 🛡️ **TURU 91 — UC YENI MUHAFIZ, HEPSI BOZULARAK KANITLANDI:**
  · `ilan/sutun_test.go` `basvuru.go`ya genisletildi. ⚠️⚠️ MUHAFIZ ILK
    YAZIMDA **KENDISI YANLIS-YESILDI**: alan YALNIZ bir fonksiyonun yanit
    haritasindan silindiginde test GECIYORDU (arama DOSYA GENELINDEYDI ve
    kardes fonksiyondaki ayni anahtari buluyordu). FONKSIYON GOVDESINE
    cevrildi ve IKI YONDEN kanitlandi.
  · `ilan/talep_test.go`: her talep kategorisinin fan-out hedefi olmali +
    hedefler GECERLI isletme kategorisi olmali. Ikisi de bozularak
    kanitlandi. ⚠️ Ikinci kanit ILK DENEMEDE UYGULANMAMISTI (betik
    eslesmedi, test yesil kaldi) — betige "uygulanmadiysa PATLA" kapisi
    konup tekrarlandi (turu 89 CRLF dersi).
  · `sutunkontrol` paketi genisletildi (`YorumsuzGo` · `SelectSutunlari` ·
    `ScanSayilari`) — kopya ayristirici YAZILMADI.
- ⚠️⚠️ **TURU 91 — E2E'DE BIR KONTROL YALANCI-YESILDI.** AI kota kontrolu
  `/ai/kota` cagiriyordu ama **O UC YOK**; `undefined === undefined` ile
  geciyor ve HICBIR SEY OLCMUYORDU. Dogru uc `/ai/durum`; kontrol artik
  UC KOSUL birden bakiyor (metin 20->19, gorsel 10->10 DEGISMEDI).
- 📌 **MIGRATION NUMARALARI (guncel):** 045 = teklif (`ilan_basvurular.
  fiyat_kurus` + `guncellendi_at`) + diyet (`diyet_bag`, `diyet_kayit`).
  Sonraki **046**'dan.
- ⏳ **DURUST SINIRLAR (turu 91):** diyet listesi DUZ METIN (gun/ogun yapili
  editor yok) · olcum GRAFIGI yok (sayi listesi) · teklif pazarligi mevcut
  ilan sohbeti uzerinden (ayri teklif mesajlasmasi yok) · otel odalari HALA
  VITRIN · dugun talebi TEK kategoriye gider (coklu dal secimi yok).
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **ONCEKI (11 Agu 15:59): TEST TURU 90 + 90b YAYINLANDI** — android
  **31492792085** + ios **31492794766** (**bc4eace**), R2 apk=121332927
  (md5 707b0ef7) ipa=31518916 (md5 c6c8498b) index=9417 (md5 b6f2c96e),
  purge OK, **CDN BIREBIR (ucu de)**, indir sayfasi 11 Agu 15:59 (saat 5
  yerde + canli saat), `Content-Type: text/html` + `no-store` + DYNAMIC,
  debug imza YOK, **iOS min 16.0**, `--dart-define=HARITA=true` IKI build
  logunda da dogrulandi, **IKI ARTIFACT'TE DE turu 90b kodu var**
  (dizeler UTF-16 olarak arandi — bkz. asagidaki tuzak),
  **BACKEND DEPLOY** (bc4eace; migration 044 canlida) + health ok.
  ✅ **CANLI SUNUCUDA 301/301 UCTAN UCA** · `flutter analyze` **0 hata 0 uyari**
  · `go build`+`go vet` temiz · UTF-8 muhafizi temiz.
  🌱 **DB TEMIZLENDI + TOHUM ATILDI**: 10 isletme · 2 kullanici · 2 ilan
  (1 is ilani + basvuru) · 2 etkinlik · **10/10 isletmeden randevu 201**.
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260811-1559
  **KULLANICI TEST EDECEK.**
- **TURU 90:** is ilani + **basvuru** (herkes ilan verir, normal kullanici
  basvurur) · **tohum veri** (`tools/tohum.js`) · gonderide **konum** ·
  sag altta **olustur menusu** · global **odak birakma** (klavye kapanmasi) ·
  story editor cokmesi · menu duzeni (Yakinimda ayri + KATEGORILER).
- ⚠️⚠️⚠️ **TURU 90b — DENETIM: 6 MERCEK, 4 SEVK ENGELI + 15 BULGU.
  ILK BUILD (22d625d) ALINDI AMA YAYINLANMADI.** *"Build ALMAK yayinlamak
  DEGILDIR"* dersinin **ALTINCI** dogrulanmasi.
  · **BASVURU OZELLIGININ ISTEMCISI HIC YOKTU**: `grep -rn "basvur"
    mobile/lib/` = **SIFIR**. Sunucuda 5 uc + tablo + yetki kapilari +
    bildirim vardi, istemcide TEK SATIR YOKTU -> turun MANSET EMRI
    ("normal kullanicilar basvuru yapabilmeli") **%100 OLU DOGACAKTI**.
    UC BAGIMSIZ ajan ayni sonuca vardi. ⚠️ **DERS (DOKUZUNCU tekrar): bir
    uc/sutun/servis ekledigin AN onu KULLANAN yolu da yaz.**
  · **GERI CEKEN KULLANICI O ISE KALICI KILITLENIYORDU**: geri cekme satiri
    SILMEZ (`durum='geri_cekildi'`), yeniden basvuruda UNIQUE cakisir,
    `ON CONFLICT DO NOTHING` satira DOKUNMAZ, uc yine **200** doner.
    Kullanici "basvurum gitti" sanar, ilan sahibi onu HIC GORMEZ.
    KURTARMA YOLU YOKTU. FIX: kosullu `DO UPDATE ... WHERE
    durum='geri_cekildi'`. ⚠️ `WHERE` ZORUNLU — kosulsuz olsaydi sahibinin
    'olumsuz' verdigi basvuru her dokunusta 'bekliyor'a doner = SPAM KAPISI.
  · **`Create` KONUM DOGRULAMASI YAPMIYORDU**: kapi yalniz `Update`e
    konmustu, `Create` ise BIRINCIL yol. Yarim koordinat (`{"enlem":41.0}`)
    geciyordu ve istemci olcutu `enlem!=0||boylam!=0` oldugu icin gonderi
    "konumlu" sayilip cipe dokunanin haritasi **GINE KORFEZI'nde** aciliyordu.
    Turu 85c'nin *"ASIMETRININ KENDISI HATAYDI"* dersinin tekrari.
    ⚠️ INSERT'te `COALESCE($8, 0::double precision)` — ciplak `0` tamsayiya
       cozulup ondaligi KIRPARDI (40.8028 -> 40 = ~90 km).
  · **ANASAYFADA IKI FAB**: `AkisEkrani` KENDI Scaffold'unda ZATEN "+"
    tasiyor; turu 90 dis Scaffold'a ikincisini koydu. Ikisi de `endFloat` ve
    dipler AYNI cizgide -> PIKSEL PIKSEL ust uste; dokunusu DIS FAB aliyor,
    akisin kendi FAB'i **ULASILAMAZ** kaliyordu (turu 76b'de bilerek
    kapatilan hata geri gelmisti). ⚠️ YAPMA: `home_screen`e FAB ekleme.
  · **PAYLASILAN GONDERI AKISTA GORUNMUYORDU**: eski yol `nav.push<String>`
    sonucunu okuyup akisi tazeliyordu; menu DONEN ID'yi ATIYORDU. Ustteki
    sevk engeli eski yolu ulasilamaz kildigi icin bu KESIN yasanirdi.
    FIX: `olusturMenusuAc(context, sonrasinda:)`.
    ⚠️ Sheet'in KENDI future'i kullanilamaz (ekran sheet POP EDILDIKTEN
       SONRA push edilir, o an sheet context'i OLUDUR).
- ⚠️⚠️ **TURU 90b — ARAYUZ BULGULARI OLCULDU (font metrikleri fonttan
  okundu, `FontLoader` ile ampirik):**
  · **Olustur sheet'i 360x640'ta VARSAYILAN olcekte 44px TASIYORDU** ("Grup"
    maddesi kirpik). `isScrollControlled` yokken tavan `ekran*9/16`, ustune
    `showDragHandle` 48dp. ⚠️ **Test cihazi 414x896 oldugu icin ORADA
    GORUNMUYORDU — turu 70b dersinin birebir tekrari.**
  · **FAB SON GONDERININ "KAYDET" DUGMESINI KAPATIYORDU**: uzaklik 16.8dp,
    dokunma yaricapi 28dp -> kaydet FAB dairesinin TAM ICINDE. FIX: listeye
    `bottom: 80` dolgu. ⚠️ Son ogedeki `SizedBox`i buyutmek YETMEZ.
  · **KONUM CIPI ACIK TEMADA 2.27:1** (12px metin icin 4.5:1 gerekiyor;
    koyu temada 6.72:1 ile sorunsuzdu -> YALNIZ ACIK TEMA hatasi).
    FIX: `colorScheme.primary`.
  · `'Konum ✓'`: `✓` Lucide DEGIL · olcek 2.0'da **kirpilan ILK karakter
    "✓"** oluyordu (kullanici konumun ekli oldugunu ANLAYAMIYORDU) · olcut
    kaldirma daliyla UYUMSUZDU. FIX: durum IKONDAN + tek olcut `_konumVar`.
- 🧪 **TURU 90b — ODAK SARMALI AMPIRIK DOGRULANDI.** Denetim gercek
  `flutter test` sondalariyla KONTROL GRUBU kurdu: dugmeler · cift dokunus ·
  uzun basma · kaydirma · TextField **HICBIRI BOZULMUYOR** (arena uyeleri
  derinden koke eklenir, kok DAIMA SON uyedir, jest CALAMAZ).
  ⚠️ Bilinen sinir: yalniz-`onDoubleTap` alanlarda (akis medyasi/Reels) odak
     DUSMEZ — o ekranlarda metin girisi yok, pratik etkisi yok.
  ⚠️ `excludeFromSemantics: true` eklendi (olculdu: sarmal kok semantik
     dugume `tap` eylemi ekliyordu, TalkBack tum ekrani "etkinlestirilebilir"
     duyurabilirdi).
- 🛡️ **TURU 90b — YENI MUHAFIZ: `internal/isletme/modul_test.go`.**
  Her `Kategoriler` girisinin bir `moduller` karsiligi olmasini zorlar.
  ⚠️ **ILK KOSUDA IKI KATEGORI DAHA yakaladi** (`eglence`, `teknoloji`) —
     sorun turu 90'in getirdigi ikisinden ibaret DEGILDI.
  Ikinci test: `hizmet`/`oda` turu modul ALAN TANIMLAMAK ZORUNDA (istemci
  yalniz `modul.alanlar`i cizer; alansiz modulun verisi **OLU VERIDIR** —
  `diyetisyen`/`guzellik` tam bunu yasiyordu: "Ürün ekle" yaziyor,
  `sure_dakika` HIC cizilmiyor, duzenlemede tur 'hizmet'->'urun' donuyordu).
- ⚠️⚠️ **ARTIFACT ICINDE TURKCE DIZE ARAMA — UTF-16 (yeni tuzak).**
  Dart AOT anlik goruntusunde ASCII olmayan dizeler **UTF-16** saklanir
  (ASCII olanlar UTF-8/Latin-1). `grep -a "Başvuranlar"` **HER ZAMAN YOK
  DONER** ve build'in eski oldugu SANILIR. Dogrulama once "Yakınımda" gibi
  BILINEN bir dizeyle YAPILMALI: yontem yanlissa o da YOK doner.
  ⚠️ Kontrol: `buf.includes(Buffer.from(s,'utf16le'))`.
- 📌 **TURU 90 — SURUM RUTINI DEGISTI:** TRUNCATE'ten sonra
  **`node tools/tohum.js`** ZORUNLU (kullanici emri) ve cikan telefon/sifre
  tablosu KULLANICIYA VERILIR. Betik hicbir yerden otomatik cagrilmiyor;
  atlanirsa kullanici BOS uygulamaya girer.
  ⚠️ Betik 409'da login'e duserek IDEMPOTENT; randevu sonuclarini ASSERT
     eder (ilk yazimda kosulsuz "TOHUM TAMAM" diyordu).
- 📌 **MIGRATION NUMARALARI (guncel):** 044 = `posts` konum + `ilan_basvurular`.
  Sonraki **045**'ten.
- ⏳ **DURUST SINIRLAR:** otel odalari hala VITRIN (gece bazli fiyatlama yok;
  rezervasyon slot motorundan gecer, oda secimi YOK) · ilan detayindaki
  "Başvurun alındı" YALNIZ o oturumdaki dokunusu yansitir (sunucuda tekil
  basvuru durumu donduren uc yok; gercek durum "Başvurularım"da).
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **ONCEKI (11 Agu 13:37): TURU 89 YAYINLANDI** — android
  **31481923964** + ios **31481926355** (**70e255d**), R2 apk=121152035
  (md5 e0756fc3) ipa=31507031 (md5 7650529c) index=9327 (md5 495a60ca),
  purge OK, **CDN BIREBIR (ucu de)**, debug imza YOK, build logunda
  `--dart-define=HARITA=true` dogrulandi. **BACKEND DEPLOY** (70e255d;
  migration 001->043 atilabilir kopyada dogrulandi, canlida `tur` +
  `ozellikler` sutunlari mevcut) + health ok, DB TEMIZ.
  ✅ **CANLI SUNUCUDA 275/275 UCTAN UCA** · **197 ROTA CAKISMASIZ** ·
  `flutter analyze` **0 hata 0 uyari** · `flutter test` 6/6.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260811-1337
- ⚠️⚠️⚠️ **TURU 89 — HARITA MUHAFIZI **KORDU** (stil eklemeden ONCE onarildi).**
  Turu 86-88 regex'i `featureType` ile `visibility`nin **AYNI kume
  parantezinde** olmasini bekliyordu. Gercek Google JSON'unda `visibility`
  **DAIMA** `"stylers":[{...}]` icindedir; desendeki `[^{}]*` bir `{`
  gecemedigi icin muhafiz **HICBIR SEYI** eslestiriyordu — kodda DURAN kural
  bile. Test YESILDI ama **YANLIS SEBEPTEN**: turu 85'i onlemek icin yazilmis
  muhafiz turu 85'in TA KENDISINI yakalayamiyordu.
  FIX: stil artik **`jsonDecode`** ile YAPI OLARAK geziliyor.
  ✅ KANIT: Google'in **RESMI Silver** stili yapistirildi (icinde
     `labels.icon: off` var) -> test ANINDA KIRMIZI.
  ⚠️ **DERS: bir muhafizin YESIL olmasi, GERCEKTEN OLCTUGU anlamina GELMEZ.
     Yazdiktan sonra BOZ ve kirmiziya dustugunu GOR.**
  ⚠️ YAPMA: bu testi tekrar regex'e dondurme.
- 📌 **TURU 89 — HARITA RENGI (Ayarlar > Harita): `sistem`/`gri`/`gece`.**
  · **gri** = Google **Silver** TEMELLI ama `labels.icon: off` satiri
    **CIKARILMIS** (o satir turu 85 hatasinin ta kendisi).
  · **gece** = Google **Night** (hicbir `visibility` kurali icermez).
  · Her ikisine turu 88'in `poi.business` kurali TASINDI.
  Tercih diskte (tema deseninin IKIZI) + `haritaStiliProvider`.
  ⚠️ `style:` **CALISMA ANINDA** degisir (eklenti stili DIFF'leyip
     `didUpdateWidget -> _updateOptions` ile push eder; harita yeniden
     KURULMAZ, `key` degistirmek GEREKMEZ).
  ⚠️ YAPMA: `GoogleMapController.setMapStyle` kullanma — DEPRECATED.
- ⚠️⚠️ **TURU 89 — ISLETME MODULLERI (otel->Odalar, doktor->Hizmetler).**
  ⚠️ **AYRI TABLO ACILMADI** — UC ayri migration bunu ISIMLE yasakliyor
     (030:14, 038:15, 031:12). `ilanlar`in `tur` + `ozellikler JSONB` + GIN
     deseni kopyalandi; alan tanimlari **SUNUCUDAN** gelir
     (`GET /isletme-modulleri`) ve form ISTEMCIDE uretilir -> yeni alan
     eklemek **ISTEMCI GUNCELLEMESI GEREKTIRMEZ**.
  ⚠️ **GIZLI KAZANC:** tablo DEGISMEDIGI icin `media.erisebilir()` urun dali
     ve `ai_gorsel` referans sayimi DOKUNULMADAN kaldi. Yeni tablo acilsaydi
     bu iki nokta sessizce bozulur ve hata **YALNIZ IKINCI HESAPTA**
     gorunurdu (turu 75b/77/78/78b'de DORT kez sahaya cikan sinif).
  ⚠️ `Detay` yaniti `modul` doner (`randevu_turu` ile BIREBIR ayni desen:
     kategori -> davranis turetmesi SUNUCUDA).
  ⚠️ `tur`a CHECK YOK (036/037'de IKI KEZ sevk engeli uretmis tuzak);
     beyaz liste Go'da (`TurGecerli`).
- ⚠️⚠️⚠️ **TURU 89 — E2E GERCEK BIR HATA YAKALADI: BETIK "OK" DEDI AMA
  DEGISIKLIK UYGULANMAMISTI (CRLF).** `tur`/`ozellikler` kaydedilmiyordu.
  KOK NEDEN: bir onceki adimda `git checkout -- urun.go` calistirilmis ve git
  dosyayi **CRLF** ile geri yazmisti; betigimin `\n` iceren arama dizeleri
  ESLESMEDI ve INSERT, UPDATE ile IKI istek tipi **UYGULANMADI**. Derleme de
  gecti cunku **Go kullanilmayan FONKSIYON icin hata VERMEZ** (yardimcilar
  olu kalmisti).
  ⚠️ **DERS: Windows'ta betikle metin degistirirken SATIR SONLARINI VARSAYMA;
     `git checkout` sonrasi dosya CRLF olur. Kritik degisikligi `Edit` ile yap
     ve sonucu GREP'LE DOGRULA.**
  ⚠️ Bu sinifi `go build`+`go vet`+birim testler **GOREMEDI**; yalnizca
     **CANLI E2E** yakaladi.
- ⚠️⚠️ **TURU 89 — IZINLER ONBOARDINGE TASINDI, AYRI SAYFA KALDIRILDI.**
  Dort sayfa sirayla: mikrofon -> kamera -> bildirim -> tam ekran bildirim.
  ⚠️ **TAM EKRAN BILDIRIM EN SON**: sistem AYARLAR ekranini acar ve Activity
     duraklar; ortada olsaydi sonraki diyalog GOSTERILMEZDI (turu 56'da tam bu
     yuzden READ_PHONE_STATE 36 tur boyunca hic alinamadi).
  ⚠️⚠️ **SEVK ENGELI ONLENDI:** `main.dart` HER SOGUK ACILISTA, onboardingten
     BAGIMSIZ `CallKitService.izinleriIste()` cagiriyordu. Iki akis paralel
     kosunca Android ikinci istegi sessizce duserur -> READ_PHONE_STATE denied
     -> GSM gizlilik kapisi (turu 56/63) GERI GELIR.
     **`&& tercihler.onboardingGoruldu` kapisi ZORUNLU.**
  ⚠️⚠️ **KURTARMA YOLU (Ayarlar > IZINLER) ZORUNLU:** onboarding bayragi
     KALICI oldugu icin izinleri reddeden kullanicinin uygulamayi SILMEDEN
     donus yolu KALMAZDI. ⚠️ YAPMA: o girisi kaldirma.
  KALDIRILANLAR: `PermissionsScreen` kapisi + kayit akisinin 4. adimi
  (akis **4 -> 3 adim**).
- 📌 **TURU 89 — SADE KARSILAMA + GIRIS.** Onboardingden uc mor gradyanli ikon
  karti, `FontStyle.italic` (egim) ve mor vurgu KALDIRILDI; baslik TAMAMEN
  SIYAH, sol ustte (`mainAxisAlignment` da `center -> start` — iki eksen AYRI
  ayarlanir). Giris ekranindan 72px `messageCircle` ikonu ve "Gebzem" basligi
  kaldirildi; ekran kayit akisinin diline cevrildi.
  ⚠️ Ortak parcalar **KOPYALANMADI**: `auth_stil.dart` TEK KAYNAK.
- 🛡️ **TURU 89 — MUHAFIZ GENISLEMESI:** `internal/isletme/sutun_test.go` artik
  **URUN sorgusunu da** kapsiyor. ⚠️ Calistigi KANITLANDI: (a) SELECT'ten
  sutun cikarilinca *"SELECT 11 sutun donduruyor ama Scan 12 alan bekliyor"*,
  (b) `tur` yanit haritasindan cikarilinca *"YANIT HARITASINDA YOK"* — ikisi
  de KIRMIZI. **E2E 265 -> 276.**
- 📌 **MIGRATION NUMARALARI (guncel):** 043 = `isletme_urunleri.tur` +
  `ozellikler` JSONB + GIN. Sonraki **044**'ten.
- ⏳ **TURU 89 — KAPSAM DISI (durust not):** otel icin **gece bazli
  rezervasyon** YOK (`randevular` SLOT bazlidir; `slot_kapasite` "ayni anda
  kac randevu" demek, "kac oda bos" DEMEK DEGIL — tam cozum yeni bir
  tarih-araligi modeli ister ve cakisma mantigi advisory kilitli TEK deyim
  uzerine kurulu). Bu turda **oda modulu VITRIN**: tip/kapasite/fiyat/gorsel
  listelenir, iletisim mesajla. · **eczane nobetci** bilgisi YOK (sifir kod +
  resmi kaynak gerektirir) · `forgot_screen` yeni beyaz dile CEVRILMEDI
  (kullanici istemedi; "Şifremi unuttum" hala eski gorunumlu ekrani aciyor).

- **ONCEKI (11 Agu 09:05): TURU 87 YAYINLANDI** — android
  **31463073346** + ios **31463075086** (**f5781ca**), R2 apk=121151851
  (md5 8f390b14) ipa=31514590 (md5 6de8bda0) index=9456 (md5 286c3cc3),
  purge OK, **CDN BIREBIR (ucu de)**. Backend DEGISMEDI.
  ⚠️ **ADRES:** https://indir.gebzem.app/index.html?v=20260811-0905
- ⚠️⚠️⚠️ **TURU 87 — GERCEK GOOGLE HARITASI **HIC CIZILMIYORDU** (KOK NEDEN).**

      CI   : --dart-define=HARITA=1
      Dart : bool.fromEnvironment('HARITA')

  Dart sozlesmesi: deger **YALNIZCA** `"true"` ise true, `"false"` ise false,
  **BASKA HER SEYDE `defaultValue` (false)**. Yani `"1"` -> **FALSE**.
  `if (haritaAnahtariVar && ...)` kapisi **HIC ACILMADI**; uygulama gercek
  Google haritasini **HICBIR SURUMDE CIZMEDI**, hep elle boyanmis yer
  tutucuyu (`_SehirCizer`) gosterdi. Kullanici **UC KEZ** soyledi
  (*"bu nasil bir harita"* -> *"normal google haritasi degil ki bu"* ->
  *"yine sacma sapan bir harita, neden google haritasini kullanmiyorsun"*)
  ve **HER SEFERINDE HAKLIYDI**.
  ✅ **AMPIRIK KANIT:** `flutter test --dart-define=HARITA=1` -> `false`,
     `--dart-define=HARITA=true` -> `true`.
  **FIX (iki katmanli):** bayrak DIZEDEN turetiliyor (`true`|`1`|`yes`) +
  CI `HARITA=true` geciyor. Biri bozulursa oteki tutar.
  ⚠️ YAPMA: ciplak `bool.fromEnvironment('HARITA')`a donme.
- ⚠️⚠️⚠️ **TURU 87 — NEDEN 76 AJANLIK IKI DENETIM BUNU GOREMEDI (YONTEM DERSI).**
  Hepsi **kod<->kod** ve **kod<->serh** tutarliligina bakti. Bu hata **KOD ILE
  DERLEME YAPILANDIRMASI ARASINDA** duruyordu ve o siniri HICBIR mercek
  denetlemedi. Ustelik anahtarin APK manifestine ve iOS `Info.plist`ine
  enjekte edildigini dogrulamak **"harita calisiyor" KANITI SANILDI** — oysa
  **ENJEKSIYON ILE BAYRAK AYRI IKI SEYDIR**; biri dogruyken oteki sessizce
  yanlisti. Derleme temiz, uygulama saglam, hata **YALNIZCA EKRANDA**.
  ⚠️⚠️ **DERS: bir ozelligin CALISTIGININ TEK KANITI ONA BAKMAKTIR.** Yan
     kanitlar (anahtar enjekte oldu · paket kurulu · testler yesil · e2e
     264/264) ozelligin **GORUNDUGUNU** kanitlamaz.
- 🛡️ **TURU 87 — MUHAFIZ: DERLEME BAYRAGI <-> KOD** (`harita_stili_test.dart`).
  CI dosyalarindaki `--dart-define=HARITA` degerini **KODUN kabul kumesiyle**
  karsilastirir. ⚠️ Calistigi KANITLANDI: (a) CI'ya tanimsiz deger
  (`HARITA=on`), (b) bayragi HIC gecmemek, (c) koda ciplak
  `bool.fromEnvironment` — **UCU DE KIRMIZI**.
  ⚠️ **YENI BIR `--dart-define` EKLERKEN bu muhafiza da bir vaka ekle.**
- 📌 **TURU 87 — ADRESTEN PIN** (kullanici emri: *"isletmeler adreslerinde yer
  isaretlemesi gerekiyor"*). Turu 85'te isletmenin haritada gorunmesi icin
  sahibinin ya DUKKANINDA "Bulundugum konumu kullan"a basmasi ya da
  koordinati ELLE yazmasi gerekiyordu; ikisini de yapmayan isletme adresini
  yazmis olsa bile **HIC gorunmuyordu**. Artik konum BOSSA adres metninden
  otomatik cozumlenir (`geocoding`: Android `Geocoder`, iOS `CLGeocoder` —
  **API ANAHTARI GEREKTIRMEZ**). Yalniz konum YOKKEN calisir, GPS/elle
  girilene DOKUNMAZ; sonuc "Türkiye" ile sinirli (yanlis ulkeye pin,
  pinsizlikten KOTUDUR). Basarisizlik hata degil.
- ⚠️⚠️ **TURU 87 — ARA HATA: `geocoding` 3.0.0 ANDROID BUILD'INI PATLATTI.**
  `geocoding_android` 3.x **android-33**'e derlenmis; mevcut androidx
  bagimliliklarimiz daha yuksegini istedigi icin
  `:geocoding_android:checkReleaseAarMetadata` HATA VERDI. 5.1.0 `compileSdk 36`.
  ⚠️ **DERS: yeni bir Flutter paketi eklerken `flutter pub get` TEK BASINA
     YETMEZ** — paketin `android/build.gradle` `compileSdk` degerine BAK.
     `flutter analyze` bu sinifi **GORMEZ** (yalniz Dart'a bakar); hata
     GRADLE'da cikar ve YEREL Android SDK yoksa ancak CI'da gorunur.
  ⚠️ `geocoding` 5.x API **SINIF TABANLI**: ust duzey `locationFromAddress()`
     KALDIRILDI -> `Geocoding().locationFromAddress(...)`.

- **ONCEKI (11 Agu 08:26): TURU 86 YAYINLANDI** — android
  **31460848125** + ios **31460849840** (**5088dda**), R2 apk=120264179
  (md5 678c63d9) ipa=31373498 (md5 7ffeafd3) index=9456 (md5 473f2d7b),
  purge OK, **CDN BIREBIR (ucu de)**, debug imza YOK. Backend DEGISMEDI.
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260811-0826
- ⚠️⚠️⚠️ **TURU 86 — HARITA: "BU NASIL BIR HARITA?" (kullanici, SAHADA).**
  Kullanici: *"bu nasil bir harita? normal google haritasi degil ki bu"*.
  **HAKLIYDI.** Turu 85'te "uber tarzi grimsi beyaz" istegini stil JSON'una
  cevirirken haritanin **TANIMLAYICI HER UNSURUNU** kapatmisim:
  `poi: off` (hicbir mekan yok) · `road ... labels: off` (**SOKAK ADI YOK**) ·
  `labels.icon: off` · `transit: off` · `administrative geometry: off`.
  Geriye beyaz cizgili **GRI BIR KAGIT** kaliyordu; kullanici nerede oldugunu
  anlayamiyor, hicbir yeri taniyamiyordu.
  ⚠️ **"Grimsi beyaz" bir RENK TERCIHIYDI; haritayi OKUNAMAZ hale getirme
     yetkisi DEGILDI.**
  IKINCI KUSUR: harita **CANLI DEGILDI** — `scroll/zoom/rotate/tilt`
  jestlerinin HEPSI `false` idi (gerekce: *"liste icinde, dikey jesti alirsa
  sayfa kaydirilamaz"*). Kullanici haritaya dokunup suruyor ve **HICBIR SEY
  OLMUYORDU**; etiketlerin de kapali olmasiyla birlesince ortaya **"harita
  olmayan bir harita"** cikmisti.
  ✅ FIX: ozel stil **KALDIRILDI** (normal Google haritasi) · kaydirma +
  yakinlastirma **ACILDI**, liste catismasi **`EagerGestureRecognizer`** ile
  cozuldu (dokunus HARITADA baslarsa harita, KARTLARDA baslarsa liste alir) ·
  "konumuma don" dugmesi acildi (harita artik suruklendigi icin SART).
  ⚠️ YAPMA: `poi`/`road labels`/`transit` kapatan bir stil geri koyma. Renk
     tonu istenirse YALNIZCA `geometry` renkleri degistirilir, hicbir
     `visibility: off` eklenmez.
  ⚠️ YAPMA: jestleri tekrar `false` yapma; catismayi recognizer YERINE
     jestleri kapatarak "cozme".
- 🛡️ **TURU 86 — KALICI MUHAFIZ: `mobile/test/harita_stili_test.dart`**
  (projenin ILK Flutter testi). Bu hata **SESSIZDI**: `flutter analyze` temiz
  gecti, uygulama COKMEDI, harita "calisiyor" gorundu — yalnizca
  **KULLANILAMAZ** oldu. Bu sinifi ancak GOZLE bakan biri yakalayabilirdi;
  nitekim **KULLANICI SAHADA YAKALADI**. Muhafiz kaynagi DOSYADAN okur
  (kopya yok -> drift imkansiz) ve dogrular: (1) stilde hicbir
  `visibility: off` YOK, (2) scroll+zoom ACIK + `EagerGestureRecognizer` VAR.
  ⚠️ **Calistigi KANITLANDI**: eski bozuk stil **IKI AYRI YAZIM BICIMIYLE**
     (`'''` ham dize ve KACISLI duz dize) geri konup test KIRMIZIYA dusuruldu.
     Ilk desen yalniz ham dizeyi yakaliyordu; **kacisli bicim SESSIZCE
     GECIYORDU** -> desen ikisini de kapsayacak sekilde genisletildi.
  ⚠️ Test kendi serhini eslestirmesin diye kaynak once **YORUMLARDAN
     TEMIZLENIR** (turu 80b `sutun_test.go` + turu 83 `utf8_test.go` tuzagi).
  ⚠️ YAPMA: bu testi silme.
- ⚠️ **TURU 86 — DOGRULAMA SINIRI (durust not):** Dart AOT bu dizeleri duz
  metin olarak SAKLAMADIGI icin "eski stil artifact'ten cikti" dize aramasiyla
  KANITLANAMADI. Kanit zinciri: `libapp.so` MD5 degisti (37202a0f ->
  7a76d7b0) + build `5088dda`'dan alindi + o commit duzeltmeyi iceriyor +
  muhafiz testi o commit uzerinde YESIL.

- **ONCEKI (11 Agu 07:36): TURU 85c YAYINLANDI** — android
  **31458313670** + ios **31458315418** (**43a6038**), R2 apk=120264179
  (md5 8a91aad1) ipa=31373352 (md5 5f58fd78) index=9456 (md5 2a257758),
  purge OK, **CDN BIREBIR (ucu de)**, debug imza YOK, **iOS min 16.0** +
  `MapsApiKey` enjekte dogrulandi. Backend DEGISMEDI (df95e40 canli) +
  health ok. **264/264 uctan uca** yine gecti, `flutter analyze` 0/0.
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260811-0736
  **KULLANICI TEST EDECEK.**
  ⚠️ APK boyutu onceki build ile **BIREBIR AYNI** (120264179) ama MD5 FARKLI
     (0387a6d4 -> 8a91aad1). *"Boyut ayni = build eski"* DEME kurali dogrulandi.
- ⚠️⚠️ **TURU 85c — YAYINDAN SONRA SON DOGRULAMA (24 ajan, 18 iddia -> 11
  ONAY, 7 elendi).** E2E'nin GOREMEDIGI istemci yuzeyi (router · izinler ·
  tema · konum formu · harita) yeniden okundu. Sevk engeli YOK; hepsi
  duzeltilip **build YENIDEN ALINDI**. *"Build almak yayinlamak degildir"*
  dersinin **ALTINCI** dogrulanmasi.
- ⚠️⚠️⚠️ **TURU 85c (YUKSEK) — IKI IZIN ISTEGI CAKISIYORDU (turu 56'nin YENI
  KAPISI).** `FlutterCallkitIncoming.requestNotificationPermission` eklentide
  **BEKLEMEZ** (`requestPermissions(...)` sonrasi ARDISIK satirda
  `result.success(true)`). Yani `await` diyalog kapanmadan cozuluyor ve bir
  alttaki `Permission.phone.request()` **POST_NOTIFICATIONS diyalogu HALA
  EKRANDAYKEN** kosuyordu. Android ayni anda TEK izin kumesi kabul eder ve
  ikinci istegi **SENKRON BOS SONUCLA** dusurur -> `permission_handler`
  haritada PHONE anahtarini bulamaz -> **`denied`**.
  SONUC: kullanici **HICBIR DIYALOG GORMEDEN** READ_PHONE_STATE'i kaybeder ->
  `TelefonDurumu.izinVar()` false -> **GSM dinleyicisi SESSIZCE KAPALI** ->
  turu 56/63'te kapatilan **GIZLILIK ACIGI** (GSM gorusmesi surerken Gebzem
  mikrofonunun acik kalmasi) GERI GELIR.
  ⚠️ Carpisma **YALNIZ bildirim izni REDDEDILMISSE** olusur (eklenti
     `checkSelfPermission` GRANTED gorurse diyalog ACMAZ).
     **Turu 56 olcumunun `telefon=TRUE` cikmasinin sebebi TAM BUDUR** — test
     eden kisi bildirime IZIN VERMISTI, yani olcum hatayi GOREMEYECEK daldan
     gecmisti. ⚠️ **DERS: bir olcumun YESIL cikmasi, olculen hatanin TUM
     dallarda yok oldugu anlamina GELMEZ.**
  FIX: `CallKitService.izinleriIste({bildirimIste})` + toplu akistan `false`;
  ayrica eklenti cagrisindan ONCE `permission_handler` ile GERCEKTEN beklenir.
  ⚠️ Ayni tuzak `main.dart` acilis cagrisinda da vardi (taze kurulumda) ve
     kendi kendine duzelme yolu YOKTU.
  ⚠️ YAPMA: telefon iznini bildirim diyalogu ucustayken isteme.
- ⚠️⚠️ **TURU 85c (ORTA) — DORT BULGU:**
  · **Kayit adim 4'te `PopScope` YOKTU**: `_ustCubuk` serhi *"IZIN ADIMINDA
    GERI YOK"* diyordu ama govdede uygulanan TEK sey ARAYUZ OKUNUN
    CIZILMEMESIYDI. Donanim geri tusu route'u yine pop ediyor,
    `izinSorulduIsaretle()` HIC kosmuyor ve `HomeScreen` izin ekranini YENIDEN
    aciyordu -> 85b'de kapatilan "ayni ekran iki kez" hatasi BU YOLDAN geri
    geliyordu. Geri tusu artik "Şimdilik geç" ile AYNI yolu kosar.
  · **`PermissionsScreen._requestAll` try/catch'siz**: bu ekran `HomeScreen`in
    TAM SAYFA dali (ustunde Scaffold yok, geri tusu bir yere goturmez). Cagri
    FIRLARSA `_busy` true takili kalir ve **"Şimdilik geç" DE `_busy`ye
    bagliydi** -> kullanici uygulamaya **HIC GIREMEZDI**. Kacis yolu artik HER
    ZAMAN acik. ⚠️ Kardes cagiran ZATEN try/catch ile sariyordu —
    **ASIMETRININ KENDISI HATAYDI.**
  · **Elle koordinat "Uygula"siz SESSIZCE ATILIYORDU**: Flutter'da odak kaybi
    `onSubmitted` TETIKLEMEZ; metin alanlariyla ekran arasindaki TEK kopru
    dugmeydi. Artik `onChanged` ile tasinir.
  · **HARITA KAMERASI KONUMU HIC TAKIP ETMIYORDU**: `initialCameraPosition`
    YALNIZ ilk kurulumda uygulanir, `onMapCreated` verilmemisti ve
    `scrollGesturesEnabled: false` (liste icinde ZORUNLU) oldugu icin elle
    tasima yolu da YOKTU -> asagi-cek GPS'i tazelese bile **harita ILK KONUMA
    CIVILI** kaliyordu (kartlar yeni sehri, harita eski sehri gosterir ve
    kurtarma yolu YOK). FIX: `_HaritaAlani` **StatefulWidget** + controller +
    `didUpdateWidget`te `animateCamera`.
    ⚠️ YAPMA: `onMapCreated`i kaldirma; `initialCameraPosition` TEK BASINA
       YETERLI DEGILDIR.
- 📌 **TURU 85c (DUSUK):** adim 2'den geri donup ayni kodla "Doğrula"
  **deterministik 400** donerdi (`consumeOTP` kodu TUKETIR) ve `catch` dali
  elindeki GECERLI kayit jetonunu da atardi -> kisa devre · `izinSorulduIsaretle`
  artik `finally`de · konum alinamayan dalda liste bosaltilmiyordu (kardes dal
  duzeltilmisti) · her yenilemede kart listesi silinip spinner'a donuyordu
  (turu 83 sinifi) · `AnnotatedRegion` cikista geri alinmiyordu -> cozum ekrana
  KOPYALANMADI, uygulama geneli varsayilan `MaterialApp.builder`a kondu
  (yaprak annotation ezmeye DEVAM eder, cikista otomatik dogru degere doner).
- 🚫 **TURU 85c — ELENEN 7 IDDIA (bir daha arastirilmasin):** `fireImmediately`
  serh-govde celiskisi (yon TERS okunmus) · `permissions_asked` okuyucusu yok
  (bilincli) · pil isteginin ayar ekrani uzerinde acilmasi (sira 85c'de
  GELMEDI, oncesinde de ayniydi) · `izinBuOturumdaSoruldu` cikista
  sifirlanmiyor (etkisi yok) · `Isletme.fromJson`daki `?? 0` (nedensel olarak
  ETKISIZ) · `acildi` yer tutucu dalinda kullanilmiyor (serh BALONU kapsiyor) ·
  onboarding'de `AlwaysScrollableScrollPhysics` (onayli tasarim degismiyor).

- **ONCEKI (11 Agu 01:21): TEST TURU 84+85 YAYINLANDI** — android
  **31436812796** + ios **31436815156** (**df95e40**), R2 apk=120264179
  (md5 0387a6d4) ipa=31373753 (md5 df8222c7) index=9456 (md5 f6aceead),
  purge OK, **CDN BIREBIR (ucu de)**, indir sayfasi 11 Agu 01:21 (saat 5
  yerde + canli saat), debug imza YOK, **iOS min 16.0 dogrulandi**,
  IKI ARTIFACT'TE DE turu 85 kodu var, **BACKEND DEPLOY EDILDI** (df95e40;
  migration 001->042 atilabilir kopyada dogrulandi, canlida 51 tablo) +
  health ok, DB TEMIZ.
  ✅ **CANLI SUNUCUDA 264/264 UCTAN UCA GECTI** · **196 ROTA CAKISMASIZ** ·
  `flutter analyze` **0 hata 0 uyari**.
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260811-0121
  **KULLANICI TEST EDECEK.**
- **TURU 84+85:** onboarding (beyaz zemin, sola dayali) · **adimli kayit**
  (telefon -> OTP -> bilgiler -> izinler) · **Yakinimda** (ustte harita, altta
  mesafeye gore sirali kartlar) · **eczane + otel** kategorileri · Uber tarzi
  grimsi-beyaz harita (YEREL JSON stil) · isletmede **elle koordinat girisi**.
- ⚠️⚠️⚠️ **TURU 85b — DENETIM: 52 AJAN, 46 BULGU -> 42 ONAYLANDI, 10 SEVK
  ENGELI.** Onunun hepsi **DORT KOK NEDENE** iniyordu ve dordu de yeni kayit
  akisini **TAMAMEN OLU** birakiyordu:
  · **`verified` HIC YAZILMIYORDU** (`grep -c verified` = **0**): yeni akisla
    acilan HER hesap hayalet — `Login` 403, `Forgot`/`Reset` de `verified=true`
    istiyor. Kullanici kayit olup uygulamayi kapatiyor ve **BIR DAHA GIREMIYOR**;
    kurtarma yolu da YOK.
  · **ROUTER OTURUM DEGISIMINDE YENIDEN KURULUYORDU**: `routerProvider`
    govdesinde `ref.watch(authProvider)` vardi -> her giriste YEPYENI `GoRouter`
    -> `MaterialApp.router` yigini ATIP `initialLocation: '/'` ile tohumluyor.
    `redirect`e yazdigim `/register` ISTISNASI **HIC CALISMIYORDU** (onu tasiyan
    router copte). Yani **4. ADIM (IZINLER) HICBIR ZAMAN GORUNMUYORDU** — tam da
    o istisnanin engellemeye calistigi hata, BASKA bir katmandan.
    FIX: router BIR KEZ kurulur, oturum degisimi **`refreshListenable`** ile
    yalnizca `redirect`i yeniden kosturur.
    ⚠️ YAPMA: `routerProvider` govdesine tekrar `ref.watch(authProvider)` koyma.
  · **YANIT ANAHTARI DRIFT ETTI**: sunucu `{token, user:{id}}`, istemci
    `data['user_id'] as String` -> **TypeError**, jeton diske HIC yazilmiyor ve
    kayit **ASLA TAMAMLANMIYOR** (hesap sunucuda olusuyor, kullanici jenerik
    hata goruyor). Iki taraf da duzeltildi; istemci artik TOLERANSLI okur.
  · **ADIM 1'IN OLCUTU GIRISTEN FARKLIYDI** (`password_hash <> ''` vs
    `verified`): OTP adiminda vazgecen kullanici ne giris yapabiliyor ne
    YENIDEN KAYIT OLABILIYORDU (409) — hesabina **KALICI KILITLENIYORDU**.
  ⚠️ **DERS: yeni bir kimlik akisi yazarken MEVCUT akisin yazdigi TUM sutunlari
     ve olcutleri TEK TEK karsilastir; bir sutunu atlamak hesabi HAYALET yapar.**
- ⚠️⚠️ **TURU 85b — KABA KUTU BOYLAMDA `cos(enlem)` UYGULAMIYORDU.**
  `Yakinimda` yaricapi dereceye cevirirken **boylamda da 111.0**'a boluyordu.
  1 derece boylam enleme gore KISALIR (`111*cos`): Gebze'de (40.8°) ~**84 km**.
  Kutu `km/111` derece geniyor ama `km/84` lazim -> kutu **~%24 DAR** ve yaricap
  ICINDEKI isletmeler **SESSIZCE ELENIYORDU**.
  ⚠️ Serh **TAM TERSINI** iddia ediyordu (*"kutu gereginden GENIS olur, yalniz
     performans kaybi; Haversine son sozu soyler"*). O iddia GECERSIZ: Haversine
     yalniz KUTUDAN GECENLERE uygulaniyor; kutu elediyse sorgu HIC GORMEZ.
  FIX: `111.0 * greatest(cos(radians($2)), 0.01)` (kutupta sifira bolme kapisi).
  ✅ E2E'de AMPIRIK dogrulandi (8 km doguya isletme; duz bolenle KIRMIZI duser).
- ⚠️⚠️ **TURU 85b — `ON CONFLICT` DALINDA `EXCLUDED` **OLU KODDU** (80b tekrari).**
  `COALESCE(EXCLUDED.enlem, isletmeler.enlem)` yaziyordu ama `EXCLUDED.enlem`
  VALUES'taki `COALESCE($9, 0::double precision)` **SONUCUDUR** -> ASLA NULL
  OLAMAZ -> yedek HIC degerlendirilmez ve konum GONDERMEYEN her guncelleme
  (adres/telefon degistirmek = EN SIK islem) koordinati **0'A EZIYORDU**.
  Turu 78'de kapatilan hata FARKLI KAPIDAN geri gelmisti.
  FIX: UPDATE dalinda **HAM PARAMETRE** (`$9`/`$10`).
  ⚠️ **DERS (80b `randevu_ayar` ile birebir ayni): `ON CONFLICT` dalindaki
     `EXCLUDED.x`, VALUES'ta COALESCE'lanmis bir parametreyse "gonderilmedi"
     bilgisi ZATEN KAYBOLMUSTUR.**
- ⚠️⚠️ **TURU 85b — ISTEMCI DE AYNI KONUMU SILIYORDU (ikinci, BAGIMSIZ yol).**
  `isletme_duzenle` `_enlem/_boylam`i `double` tutup `i.enlem ?? 0` yaziyordu ->
  konumsuz her kayitta sunucuya **ACIKCA 0** = "SIFIRLA" emri gidiyordu.
  Kisisele donen isletmenin `isletmeler` satiri SILINMEZ (veri politikasi) ve
  koordinati orada durur; tekrar isletmeye gecerken `detay()` 404 doner, form
  bos acilir ve **ILK KAYDETMEDE ESKI KOORDINAT SILINIR**.
  FIX: alanlar `double?` — `null` = "dokunma", `0` = "sifirla".
  ⚠️ YAPMA: bu alanlari tekrar non-nullable yapma ya da `?? 0` ile doldurma.
- ⚠️⚠️ **TURU 85b — IZIN ISTEME IKI KOPYAYDI, MANSET OZELLIK KIRIKTI.**
  Kayit akisinin izin adimi izinleri KENDI govdesinde istiyordu:
  · `CallKitService.izinleriIste()` (Android 14+ **TAM EKRAN BILDIRIM** izni)
    cagrilmiyordu -> **telefon KILITLIYKEN gelen arama ekrani HIC ACILMIYORDU.**
  · Pil optimizasyonu muafiyeti istenmiyordu.
  · Kullanici reddederse/"Şimdilik geç" derse `HomeScreen` kendi kapisindan
    `PermissionsScreen`i aciyordu -> **AYNI IZIN EKRANI ARKA ARKAYA IKI KEZ.**
  FIX: **`izinleriTopluIste()` TEK KAYNAK** + oturum omurlu
  `izinBuOturumdaSoruldu` (kalici DEGIL — uygulama yeniden basladiginda kapi
  yine calisir). ⚠️ YAPMA: adimlari cagiran taraflara geri kopyalama.
- ⚠️ **TURU 85b — YENI BEYAZ EKRANLAR TEMADAN KOPMUSTU.** Zemin sabit beyaz
  yapilinca imlec, secim vurgusu, `TextField` etiketleri ve dolgulu dugme yazisi
  HALA KOYU TEMADAN geliyordu -> beyaz zeminde beyaz imlec, dugmede **~1.9:1**.
  Bes alani tek tek boyamak yerine iki ekran da **`lightTheme` ile SARILDI**
  (yarin eklenecek bilesen de dogru cizilsin) + `AnnotatedRegion` ile durum
  cubugu ikonlari koyu + onboarding KAYDIRILABILIR (yazi olcegi 1.5'te
  RenderFlex tasiyordu).
- ⚠️ **TURU 85b — KAYIT JETONU TEKRAR OYNATILINCA SIFRE EZILEBILIYORDU.**
  Jeton 15 dk yasiyor ve TEK KULLANIMLIK DEGIL. FIX: UPDATE dali
  `WHERE users.verified = false` ile korunur; **0 satir = "hesap ZATEN
  tamamlanmis" ve HATA DEGILDIR** -> yeniden deneme icin oturum verilir ama veri
  EZILMEZ. ⚠️ YAPMA: 0 satiri 500'e cevirme (flaky agda kayit hic bitmez).
- ⚠️⚠️⚠️ **INDIR SAYFASI — "SAATI GOREMIYORUM"UN **DORDUNCU** KOK NEDENI.**
  Sunucu tarafi YINE dogru cikti (`no-store` + `cf-cache-status: DYNAMIC` + saat
  5 yerde + canli saat). **GERCEK SEBEP: `Content-Type: application/octet-stream`.**
  `r2put.js`in varsayilani buydu; `index.html` o baslikla yuklenince tarayici
  sayfayi **CIZMEZ, DOSYAYI INDIRIR** — kullanici sayfayi HIC gormuyor,
  indirilenlere ya da onbellekteki ESKI kopyaya bakiyordu. Basliklar "dogru"
  cikiyordu cunku **YANLIS OLAN BASLIK BUYDU.**
  ✅ FIX: arac **REPOYA TASINDI** (`tools/indir/r2yukle.js`) ve Content-Type
  **UZANTIDAN TURETILIYOR**. Scratchpad kopyasi her oturum sifirdan yazildigi
  icin duzeltme KAYBOLUYORDU; artik kaybolamaz.
  ⚠️ **SURUM RUTININDE ARTIK `node tools/indir/r2yukle.js` KULLAN** (scratchpad
     `r2put.js` DEGIL).
  ⚠️ YAPMA: varsayilani tekrar octet-stream yapma; `.html`i elle tur gecmeye
     birakma (unutulur ve hata SESSIZDIR — yukleme "OK" der, sayfa yine acilmaz).
- 📊 **TURU 85b — E2E 248 -> 265.** Adimli kayit zinciri **HIC SINANMAMISTI** ve
  denetim orada DORT sevk engeli buldu. Muhafizlar: adim 1 hesap OLUSTURMAZ ·
  yanlis OTP redde · 72 bayt tavani **400 (500 DEGIL)** · yanit `user_id` ICERIR
  (istemci sozlesmesi) · `@` on eki kirpilir · **adimli kayitla acilan hesap
  GIRIS YAPABILIR** · jeton tekrar oynatilinca sifre EZILMEZ · NaN koordinat 400.
- 📌 **TURU 85b — DIGER:** sifre **72 bayt tavani** yoktu (bcrypt hata -> jenerik
  500; uzun sifre secen kayit OLAMIYORDU) · `@` on eki kirpilmiyordu · `NaN`
  koordinat dogrulamadan GECIYORDU (`ParseFloat("NaN")` hata DONDURMEZ ve NaN her
  karsilastirmadan gecer) -> 400 yerine SESSIZ BOS LISTE · `_yukle()` serhi
  "yeniden girme kapisi" diyordu, **govdede kapi YOKTU** (nesil kapisi eklendi) ·
  asagi-cek artik **GPS'i de tazeler** · **harita SALT DEKORATIFTI**
  (`Marker.onTap` verilmemis; balona basinca HICBIR SEY olmuyordu) · **elle
  koordinat girisi** serhte "BIRAKILDI" diyordu, govdede TEK ALAN BILE YOKTU
  (izin vermeyen isletme "Yakınımda"da HIC gorunemiyordu) · `vitrin` dikeyleri
  **UCUNCU KOPYAYDI** ve `eczane`/`otel` eklenmemisti -> artik
  `isletme.Kategoriler`den TURETILIYOR · menude "Yakınımda" serhi *"ILK SIRADA"*
  diyordu ama kart **4. siradaydi** (gercekten one alindi).
- 📌 **HARITA ANAHTARI — REPODA DEGIL, DERLEME ANINDA ENJEKTE EDILIYOR.**
  Android `manifestPlaceholders` (env), iOS PlistBuddy -> `Info.plist`
  **`MapsApiKey`** (AppDelegate ayni adi okur). GitHub secret + `.env.infra`
  (gitignore'lu). Artifact'lerde enjekte oldugu DOGRULANDI; izlenen HICBIR
  dosyada anahtar YOK. ⚠️ **REPO PUBLIC — anahtari koda/pubspec'e/Info.plist'e
  SABIT YAZMA.** ⚠️ `--dart-define=HARITA` yoksa `haritaAnahtariVar` false olur
  ve yer tutucu cizilir (anahtarsiz harita Android'de filigranli GRI kutu,
  iOS'ta BOS ekran olurdu).
- 📌 **MIGRATION NUMARALARI (guncel):** 042 = gonderi anketi (`polls.post_id`,
  `message_id`/`chat_id` NULL olabilir + XOR CHECK). Sonraki **043**'ten.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **KALDIGIMIZ YER (10 Agu 17:39): TEST TURU 83 YAYINLANDI** — android
  **31398063106** + ios **31398066317** (**9fdcea4**), R2 apk=120004914
  (md5 66d88a96) ipa=25801161 (md5 5939d789) index=9381 (md5 118b266a),
  purge OK, **CDN BIREBIR** (ucu de MD5 esit), indir sayfasi 10 Agu 17:39
  (saat 5 yerde + canli saat), debug imza YOK, **iOS min 16.0**, build
  **HEAD commit'inden**. **BACKEND DEPLOY (ae1de5d)** + migration 042 canlida
  (51 tablo) + health ok.
  ✅ **CANLIDA 219/219 UCTAN UCA** (208->219) · **192 ROTA CAKISMASIZ** ·
  `go build`+`go vet` temiz · `flutter analyze` **0 hata 0 uyari** ·
  **cift-UTF8 0 dosya**. DB TEMIZ.
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260810-1739
  ⚠️ Kullanici **onay beklemeden bitirilmesini** istedi (kural 0 bu tur ASKIDA).
- ⚠️⚠️⚠️ **TURU 83 — YENI KALICI MUHAFIZ: `internal/sutunkontrol/utf8_test.go`.**
  Git Bash `sed -i` / `perl -0pi` Windows'ta UTF-8'i **CIFT KODLUYOR**
  (`ç` = C3 A7 -> C3 83 C2 A7). Bu turda **IKI DOSYA** boyle bozuldu.
  ⚠️ **ETKI SESSIZ:** `go build` + `go vet` + `flutter analyze` UCU DE TEMIZ
     gecer, cunku bozulan **KOD DEGIL DIZE ICERIGI**; hata yalnizca
     KULLANICININ EKRANINDA gorunur. Yayinlansaydi TUM Turkce mesajlar
     okunamaz olurdu. Muhafiz **226 dosya** tariyor.
  ⚠️ **ARAC KURALI: Turkce/emoji iceren dosyada `sed -i`/`perl -pi` KULLANMA**
     — `Edit`/`Write` kullan. (CLAUDE.md'de PowerShell icin yazili olan ayni
     tuzak Git Bash araclarinda da var.)
  ⚠️ Muhafiz ILK YAZIMDA **KENDI SERHINDEKI ornegi** eslestirip yanlis alarm
     verdi (`isletme/sutun_test.go` tuzaginin birebir tekrari) — bozuk ornek
     artik HARFLE degil **BAYT** olarak yaziliyor.
  ⚠️ Onarim: dosyayi UTF-8 oku -> `Buffer.from(s,'latin1')` -> UTF-8 coz.
- ⚠️⚠️⚠️ **TURU 83 — GONDERIDE ANKET (migration 042).**
  · **KESIF KAZANCI: SES ICIN MIGRATION GEREKMEDI** — `media_assets.kind`
    CHECK'i **037'den beri `'audio'` kabul ediyor** ve `posts.media_ids` bir
    medya dizisi; eksik olan YALNIZCA kartin cizim daliydi.
  · Anket icin `polls` **SOHBETE CIVILIYDI** (`message_id`/`chat_id` NOT NULL).
    042 ikisini gevsetti, `post_id` ekledi, CHECK **"tam olarak BIR sahip"**
    zorluyor. ⚠️ Ikisi de NULL olan satir HICBIR yetki kontrolunden gecmezdi
    (sessiz gizlilik acigi).
  · **`polls` YENIDEN KULLANILDI, ikinci tablo ACILMADI**: oylama mantigi
    040'ta yazilip sinandi; ikinci kopya KACINILMAZ olarak drift eder (ALTI
    kez yasandi). Degisen TEK sey **YETKI KAPISI**.
  · **`chat.anketSahibi` TEK KAYNAK**: sohbette uyelik, gonderide GORUNURLUK.
    Dort uc (oy/kapat/getir/okuma) bunu cagirir.
  · ⚠️ **IMPORT DONGUSU YOK**: `chat` -> `social` importu yerine GERI CAGIRIM
    (`GonderiGorunur` / `AnketYazar` / `AnketOkuyucu`). Bag `main.go`da TEK
    YERDE kurulur. **NIL ISE FAIL-CLOSED** (403 / 500) — sessizce acik
    birakmak gizli hesap gonderisinin anketini herkese oylatirdi.
    ⚠️ YAPMA: `main.go`daki iki satiri silme; `nil` gecme.
  · Anket gonderiyle **AYNI ISLEMDE** yazilir (yarim kayit yok).
  · ⚠️⚠️ **`satirlariOku` IMZASI DEGISTI (ctx + userID)** — bilincli:
    anket ALTI sorgunun hepsinde cizilmeli ve cagri yerlerine tek tek eklemek
    "6'ya ekle, 7.'yi unut" hatasini acardi (turu 76'da Kaydedilenler'i
    BOMBOS birakan sinif). Imza degisikligi **DERLEYICIYI ZORLAYICI** kilar.
    ⚠️ YAPMA: anket eklemeyi cagri yerlerine tasima.
  · Anketler **TEK SORGUDA** okunur (N+1 yasak — turu 17 dersi).
- ⚠️⚠️ **TURU 83 — E2E GERCEK BIR HATA YAKALADI (mime).**
  `_SecilenMedya.mime` ses icin `audio/m4a` donduruyordu; sunucu beyaz listesi
  (`sniff.go`) **`audio/mp4`** bekliyor. Yani **gonderiye ses ekleme %100 OLU
  DOGACAKTI**. `go build` + `flutter analyze` IKISI DE TEMIZ geciyordu.
  ⚠️ Sohbetteki ses notu ZATEN `audio/mp4` gonderiyordu — iki yol artik ayni.
  ⚠️ YAPMA: `audio/m4a` ya da `audio/aac` yazma (ikincisi turu 74b'de beyaz
     listeden CIKARILDI).
- ⚠️⚠️⚠️ **TURU 83b — DENETIM: 39 BULGU -> 34 ONAY (44 ajan). IKI SEVK ENGELI:**
  · **"VIDEOLAR" SEKMESI KIRIK GORSEL CIZIP TUM mp4'U INDIRIYORDU**: izgara
    hucresi TUR KONTROLSUZ `MedyaGorsel(mediaIds.first)` cagiriyordu; thumb
    uretilmedigi icin (`kucukResim:` 17 `yukle()` cagrisinin HICBIRINDE
    gecmiyor) ham `url`e dusuluyor. Yeni "Videolar" sekmesi TANIMI GEREGI
    yalniz video listeledigi icin O SEKMEDEKI HER HUCRE bozuktu.
    FIX: **`KapakGorseli`** (tam bu is icin yazilmis TEK KAYNAK) — ILK
    FOTOGRAFI secer, yalniz-video gonderide INDIRME YAPMADAN yer tutucu cizer.
    ⚠️ Ayni kok KESFET izgarasinda da vardi; ikisi de baglandi.
    ⚠️ YAPMA: izgaraya `MedyaGorsel(... .first ...)` geri koyma.
  · **YUKLEME SIRASINDA TUM CIKIS YOLLARI KAPALIYDI**: geri dugmesi `null`,
    "İptal" `AbsorbPointer(absorbing: _yukleniyor)`in ICINDE (yani tam
    gorundugu anda dokunus ALMIYOR), `PopScope` kenar-cekmeyi bloke.
    100 MB video yuklenirken kullanici **KILITLI** kaliyordu.
    FIX: `maybePop()` + ilerleme blogu `AbsorbPointer` **DISINA**.
    ⚠️ YAPMA: `_yukleniyor ? null :` kapisini geri koyma; ilerleme blogunu
       `AbsorbPointer` icine tasima.
- ⚠️⚠️⚠️ **TURU 83b — MEDYA MODELI BES TUTARSIZLIK TASIYORDU, TEK SABITE
  INDIRILDI.** Onceki hal (`kKutuKisaltma` + `kKutuGenisletme` + `oran<1.0`):
  · %5 genislik HEM yan dolgudan HEM orandan aliniyordu (**CIFT SAYIM**),
  · carpan yukseklige degil KUTU ORANINA uygulandigi icin genislik tavana
    dayandiginda **HIC BAGLAMIYORDU** (kisalma %0-%21 dalgalaniyordu),
  · `oran < 1.0` kapisi **1.0'da SUREKSIZLIK**: kareye COK YAKIN dikey
    fotograf %24 kirpilirken TAM KARE hic kirpilmiyordu,
  · **GALERI yolu TAMAMEN MUAFTI** — ayni fotograf tek basina kirpilip
    kisaliyor, ikinci fotograf eklenince UZUYORDU,
  · yatay medya %20 kisalmak yerine **%3,3 UZUYORDU**.
  **YENI: `kutuOrani = max(medyaOrani, kEnDikKutu = 1.0)`** — kutu KAREDEN
  daha dikey olamaz. Tek/coklu, dikey/yatay AYRIMI YOK.
  Dogrulandi (3 cihaz x 6 oran): **her vakada kolonun %100'u** (BOSLUK YOK),
  yukseklik en fazla ekranin %45-54'u (onceden %54-60), **yatay/kare medya
  KIRPILMIYOR**, 4:5 -> 378x378 (onceki 366x457: genislik +%3,3, yukseklik
  -%17 — kullanicinin istedigi "+%5 genis / -%20 kisa"ya en yakin ve YANDA
  BOSLUK URETMEYEN nokta).
  ⚠️ Kirpilan medyanin KURTARMA YOLU: fotografa dokun · videoya UZUN BAS.
  ⚠️ GERI ALMA TEK SATIR: `kEnDikKutu = 0.0` -> hicbir sey kirpilmaz.
- ⚠️⚠️ **TURU 83b — DIGER ONAYLI BULGULAR:**
  · **iOS'ta UC NOKTA CEKERKEN HIC CIZILMIYORDU**: `BouncingScrollPhysics`in
    `applyBoundaryConditions`i **DAIMA 0.0 doner**, yani iOS'ta
    `OverscrollNotification` **HIC DOGMAZ**. Ozellik kullanicinin gordugu ilk
    platformda OLU dogacakti. FIX: `ScrollUpdate` + `extentBefore==0` +
    `dragDetails != null` dali. ⚠️ Uc sartin ucu de ZORUNLU.
  · **`depth != 0` SUZGECI YOKTU**: `RefreshIndicator`in kendi varsayilan
    suzgeci devre disiydi -> akistaki **YATAY GALERI SERIDI** uc noktayi
    tetikliyordu. ⚠️ YAPMA: bu kapiyi kaldirma.
  · **UC NOKTA EKRANDA ASILI KALIYORDU**: tek bayrak `Overscroll`da true,
    yalniz `onRefresh` `finally`sinde false oluyordu; kullanici cekip
    VAZGECERSE `onRefresh` HIC cagrilmaz. FIX: `_cekiliyor` (ScrollEnd ile
    kapanir) + `_yenileniyor` AYRI bayraklar.
  · **CIFT DOKUNUS KALBI ANIMASYONU OLU KODDU**: `AnimatedOpacity` `if`
    kapisinin icinde oldugu icin agaca ZATEN `opacity:1` ile giriyor, gecis
    yapacak onceki deger BULAMIYORDU. FIX: `TweenAnimationBuilder` + sayac
    anahtari (art arda dokunusta bastan oynasin).
  · Sayac tavani 40 -> **46dp**: turun kendi getirdigi "1,3 bin" bicimi
    (7 karakter ~46dp) 40dp tavani NORMAL olcekte bile kirpiyordu.
    ⚠️ 46'nin USTUNE CIKMA: 52'de worst-case 354dp olur ve 360dp telefonda TASAR.
  · Bildirimler/Kaydedilenler/Kanallar: bos-hata dallarindaki **5 ListView**e
    `AlwaysScrollableScrollPhysics` (ayni commit'te profil icin duzeltilen
    sinif UC kardes ekranda atlanmisti).
- ⚠️⚠️ **TURU 83 — PROFILDE "EKRAN BEYAZ PATLIYOR" (kullanici bildirimi).**
  `build()` icinde `if (_yukleniyor) return Scaffold(spinner);` satiri
  `Scaffold`+`AppBar`+`RefreshIndicator`+`ListView`in **USTUNDEYDI** ve
  `_yukleniyor` SADECE ilk yuklemede degil **HER YENILEMEDE** true oluyordu
  -> asagi-cek sayfanin TAMAMINI agactan siliyor, geriye AppBar'siz bos bir
  `Scaffold` kaliyordu. **Turu 81'in ACIK TEMASI** zemini `0xFFF2F2F5`
  yaptigi icin bu bosluk BEYAZ patliyor. (Koyu temada da vardi, "normal
  yukleme" gibi gorundugu icin fark edilmemisti.)
  ⚠️ **BES kullanici eyleminde** tetikleniyordu: asagi-cek · takip · engelle ·
     profil duzenlemeden donus · gizli hesap anahtari.
  FIX: tam sayfa bosaltma YALNIZ `_p == null` iken + AppBar korunur + yeniden
  girme kapisi + `AlwaysScrollableScrollPhysics`.
  ⚠️ Ayni sinif UC EKRANDA DAHA vardi (bildirimler/kaydedilenler/kanallar).
- 📌 **TURU 83 — LOGO HEADER'IN ORTASINDA.** Kullanicinin verdigi PNG
  1536x1024 YATAY ve ikonun etrafinda siyah parilti vardi; oldugu gibi 32dp
  kutuya konsaydi ikon ~19px kalip yanlarda siyah bant birakirdi. Kare ikon
  kirpilip 512x512 uretildi (`assets/icon/logo.png`).
  ⚠️ **LOGOYU DEGISTIRMEK ICIN YALNIZ O DOSYA degisir — KODA DOKUNMA.**
  ⚠️ `centerTitle: true` ACIKCA veriliyor (tema geneli `false`).
- 📌 **MIGRATION NUMARALARI (guncel):** 042 = gonderi anketi (`polls.post_id`,
  `message_id`/`chat_id` NULL olabilir). Sonraki **043**'ten.
- ⏳ **DURUST SINIRLAR (yapilmadi, sebebiyle):** gonderide **KONUM** yok —
  `posts`ta enlem/boylam sutunu yok; dugme var ama durust "yakinda" diyor
  (yarim baglamak yerine). Profil izgarasi ilk 30 gonderiyle sinirli
  (sayfalama yok) — "Henuz video yok" 30'dan sonrasi icin yaniltici olabilir.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **ONCEKI (10 Agu 15:03): TEST TURU 82 YAYINLANDI** — android
  **31385139757** + ios **31385142078** (**2235554**), R2 apk=118045737
  (md5 0ca789f7) ipa=24128899 (md5 b9b306e2) index=9443 (md5 be8a09e9),
  purge OK, **CDN BIREBIR** (ucu de MD5 esit), indir sayfasi 10 Agu 15:03
  (saat 5 yerde + canli saat), debug imza YOK, **iOS min 16.0** hem kaynakta
  hem IPA'da dogrulandi, build **HEAD commit'inden** (2235554) alindi.
  **BACKEND DEGISMEDI** (turu 82 salt Flutter) — `3efe91e` canli + health ok.
  ✅ **CANLI SUNUCUDA 208/208 UCTAN UCA GECTI** · **192 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata 0 uyari**.
  DB TEMIZ (0/0/0/0/0).
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260810-1503
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 82 — MEDYA OLCUSU (DORDUNCU SIKAYET): TURU 81'IN HATASI BULUNDU.**
  Kullanici: *"resimler genis, SOL SAG BIRSEYLER DOLUYOR; tek resim galeri
  seklini defalarca attim ama AYNI, degismemis"*.
  Turu 81'in MODELI DOGRUYDU (yukseklik -> genislik) ama **TAVAN DAVRANISI
  YANLISTI**: genislik kolona takildiginda **YUKSEKLIK SABIT KALIYORDU**, yani
  kutu orani medyanin oranindan SAPIYORDU:
      4:5 fotograf, tavan 270, kolon 366 -> genislik 216 (kolonun %59)
      kutu 216x270  ->  SAGINDA 150dp BOSLUK
  Ustelik tavan (%32) o kadar dusuktu ki HEMEN HER fotograf dar kaliyor,
  yani istenen "bazisi dar bazisi genis" etkisi DE OLUSMUYORDU.
      DOGRUSU:  w = min(kolon, tavan * enBoy)
                **h = w / enBoy**   <- bu satir turu 81'de YOKTU
  Kutu orani artik DAIMA medya oranina esit -> **kirpma YAPISAL OLARAK imkansiz**.
  ⚠️ **TAVAN EKRANDAN DEGIL KOLONDAN TURER**: ekran yuzdesine (%54) bagliyken
     kucuk telefonlarda 4:5 kolonun yalniz **%82**'sini dolduruyordu (bosluk geri
     geliyordu). Artik `min(kolon / 0.8, ekran * 0.60)` — birincisi "4:5 kolonu
     TAM DOLDURSUN", ikincisi kisa/yatay ekran emniyeti.
     Dogrulandi (6 cihaz x 5 oran): 4:5 her dikey cihazda kolonun **%91-100**'u,
     kutu orani HER vakada medya oranina esit, yukseklik hicbir yerde %60'i gecmiyor.
  ⚠️ **REDDEDILEN UC MODEL (bir daha onerilmesin):** genislik sabit + yukseklik
     tavani (turu 80: %41-51 KIRPMA) · yukseklik sabit + genislik tavani
     (turu 81: YANDA BOSLUK) · tek `enBoy` sabiti (etki OLUSMAZ).
- ⚠️⚠️⚠️ **TURU 82b — DENETIM: 21 BULGU -> 13 ONAY, 8 ELENDI. IKI GERCEK
  REGRESYONU KENDI KODUMDA BULDU:**
  · **GALERI COKUYORDU** (iki bagimsiz mercek buldu, iki hakem kendi
    matematigiyle dogruladi): `satirY = reduce(math.min)` yazmistim.
    `h_i = min(tavan, ogeTavani/oran_i)` ifadesi oran BUYUDUKCE KUCULUR, yani
    min **DAIMA EN GENIS OGEYE** aittir -> galeriye giren **TEK BIR YATAY
    FOTOGRAF BUTUN GALERIYI COKERTIYORDU**: `4:5+4:5+16:9` -> 4:5 ogeler
    285x357'den **128x160**'a (%35 olcek). Sikayet edilen tablo karma galeride
    GERI GELIYORDU, ustelik turu 81'e gore GERILEME.
    FIX: `galeriSatirYuksekligi()` — yukseklik **ICERIKTEN BAGIMSIZ**
    (`ogeTavani/0.8`). 4:5 ve daha dikey ogeler KIRPILMAZ; 4:5'ten genis oge
    kirpilir (sabit yukseklikli satirda 16:9 ile 9:16 ayni anda kirpilmadan
    DURAMAZ — yukseklikleri 3.2 kat ayrisir) ve tam ekranda tam haliyle acilir.
    ⚠️ YAPMA: yuksekligi tekrar ogelerden (min/max/ilk oge) turetme.
  · **GALERININ 2. VE SONRAKI OGELERI FIILEN OLUYDU**: `_sayfa` ham kaydirma
    ofsetini ogelerin baslangic toplamlariyla karsilastiriyordu; ogeler
    viewport'a SIGDIGI icin `maxScrollExtent` ilk ogenin YARISINA bile
    ULASMIYOR (16:9+9:16: maxScroll **128dp**, ilk yari **143dp**) ->
    `_sayfa` **0'DA TAKILI**. Sonuc: 2. medyanin oto-oynatma kapisi
    (`_sayfa==sira`) HIC acilmiyor, sayac "1/2"de donuyor, videoda tam ekran
    dugmesi gorunmuyordu. FIX: aktif oge **VIEWPORT MERKEZINDEN** bulunuyor.
    ⚠️ YAPMA: karsilastirmayi ham ofsete geri dondurme.
- ⚠️⚠️⚠️ **TURU 82b — AMPIRIK KANIT: `dispose()` ICINDEN EBEVEYN `setState`i
  SADECE HATA VERMEZ, `dispose()`UN GERI KALANINI IPTAL EDER.** Bir denetim
  ajani gercek bir `flutter test` yazip olctu:
      setState() ... called when widget tree was locked
      _ilerleme.dispose() calisti mi = false   <- AnimationController SIZAR
      super.dispose()     calisti mi = false
  Yani her hikaye kapanisinda hem kirmizi ekran hem KALICI SIZINTI olacakti.
  IKI KATMANLI SAVUNMA: (a) serit geri cagirimi artik `setState` CAGIRMAZ
  (yalniz modeli gunceller; cizimi `await Navigator.push` sonrasindaki mevcut
  `setState` yapar), (b) `_ilerleme.dispose()` geri cagirimdan **ONCE** kosar —
  biri (a)'yi ileride bozarsa bile controller serbest birakilir.
  ⚠️ **GENEL DERS: bir cocuk route'un `dispose()`inden EBEVEYNIN `setState`ini
     TETIKLEME.** Cocuk agactan sokulurken cerceve KILITLIDIR.
- ⚠️⚠️ **TURU 82 — STORY HALKASI: IZLEYICI LISTEYI SUNUCUDAN TAZE CEKIYOR.**
  Yani izleyicideki `Story` nesneleri seritteki modelden **AYRI NESNELERDIR**;
  `s.izledim = true` yazmak seridi ETKILEMEZ. Tek kopru `onIzlendi` idi ve
  YALNIZ `_sonraki()`nin "liste bitti" dalindan cagriliyordu -> geri tusu / X /
  asagi kaydirma ile cikista (vakalarin COGU) halka RENKLI kaliyordu.
  Artik `dispose()`ta `every(izledim)` ile uzlastiriliyor.
  ⚠️ Kosul `every` OLARAK KALIR (Instagram deseni): 3 hikayenin 1'ini izleyip
     cikanin halkasi RENKLI kalmalidir.
- ⚠️⚠️ **TURU 82 — "ESIT OLCU" ESIT GORUNUM DEMEK DEGIL (ikon optik boyu).**
  Kullanici: *"olculer aynidir ama goruntude biri kucuk biri buyuk"* — HAKLIYDI
  ve olcu de dogruydu. `size` ikonun **CIZILEN MUREKKEBINI** degil **SINIR
  KUTUSUNU** olcer; Lucide 24'luk izgarada `heart` govdeyi doldurur,
  `send`/`bookmark`/`chartNoAxesColumn` bosluk birakir. `_optikBoy` haritasiyla
  dengelendi, yerlesim kutusu **24x24 SABIT** (satir kaymaz).
  ⚠️ Bes ikonun codePoint'i FARKLI dogrulandi (`==` calisiyor, olu kod degil).
  ⚠️ YAPMA: hepsini tekrar tek sabite esitleme.
- ⚠️⚠️ **TURU 82b — YAZI OLCEGI TASMALARI OLCULDU VE YAPISAL OLARAK KAPATILDI:**
  · Etkilesim cubugu: normal 313dp / olcek 1.3 **335dp** (pay 1dp) / 1.5 TASMA.
    FIX: yatay dolgu 8->6 + sayaca **SERT 40dp tavan** + ellipsis. Yeni
    worst-case 318dp, en dar telefonda 18dp pay — **her olcekte** sabit.
    ⚠️ `Flexible` KULLANILMADI: bu Row `mainAxisSize.min` ve dis Row'un esnek
       OLMAYAN cocugu -> `Flexible` sinirsiz kisit alir, HICBIR SEY YAPMAZ.
  · Bolme yazilari 15->17px: olcek 2.0'da 379dp vs 344dp alan -> TASMA
    (15px'te 339 ile siginiyordu). FIX: yatay kaydirma sarmali.
    ⚠️ `Flexible`+ellipsis SECILMEDI: "Takip Ettiklerin" -> "Takip Ettik…"
       olurdu ve kullanicinin ACIKCA istedigi etiket okunamazdi.
  · Story seridi 106 -> 116 (olcek 1.3'te 108 gerekiyordu).
- 📌 **TURU 82 — `kMedyaDolgu` OLU SABITTI** (turu 81'de tanimlanmis, iki dal da
  `BoxFit.cover`i ELLE yaziyordu -> sabiti degistirmek HICBIR SEYI degistirmezdi).
  Tek kaynaga baglandi. **Bu sinifin dokuzuncu tekrari.**
- ⚠️⚠️ **INDIR SAYFASI — YENI KOK NEDEN (dorduncu tur).** Sunucu
  `Content-Type: application/octet-stream` gonderiyordu — `r2put.js`in
  VARSAYILANI ve tur argumani HIC gecilmemis. Tarayicilarin cogu icerigi
  koklayip yine cizer ama **agresif bir webview bunu INDIRME sayabilir**;
  kullanicinin uc turdur "sayfayi/saati goremiyorum" demesinin muhtemel payi.
  Artik `text/html; charset=utf-8` (APK de `vnd.android.package-archive`).
  ⚠️ YAPMA: `r2put.js`e tur argumani gecmeden HTML yukleme.
  ⚠️ Ciplak alan adi 302'si sorguyu HALA dusuruyor -> kullaniciya
     **`/index.html?v=<surum>`** verilir (turu 80b kurali DURUYOR).
- 📌 **MIGRATION NUMARALARI (guncel):** 041 = `posts.yayin_at`. Sonraki **042**'den.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **ONCEKI (10 Agu 07:40): TEST TURU 81 YAYINLANDI** — android
  **31355519304** + ios **31355521019** (**3efe91e**), R2 apk=118045737
  (md5 f0fadddb) ipa=24125685 (md5 ca885eb6) index=9344 (md5 c9bfdf58),
  purge OK, **CDN BIREBIR** (apk + ipa + index.html UCU DE MD5 esit),
  indir sayfasi 10 Agu 07:40 (saat 5 yerde + canli saat), debug imza YOK,
  **iOS min 16.0 dogrulandi**, IPA icinde turu 81 kodu var,
  **BACKEND DEPLOY EDILDI** (3efe91e; migration 039/040/041 canlida uygulandi
  = 51 tablo) + health ok, DB TEMIZ (0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 208/208 UCTAN UCA GECTI** · **192 ROTA CAKISMASIZ**.
  ⚠️ **KULLANICIYA VERILEN ADRES:**
  https://indir.gebzem.app/index.html?v=20260810-0740
  **KULLANICI TEST EDECEK.**
- **KALDIGIMIZ YER (10 Agu 04:30): TURU 81 KODU BITTI, BACKEND DEPLOY EDILDI**
  (**3efe91e**; migration 001->041 atilabilir kopyada dogrulandi, canlida
  uygulandi = 51 tablo) + health ok, DB TRUNCATE edildi.
  ✅ **CANLI SUNUCUDA 208/208 UCTAN UCA GECTI** · **192 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata 0 uyari**.
  Build tetiklendi: android **31355519304** · ios **31355521019**.
- **TURU 81 — YEDI OZELLIK** (kullanici istegi): medya olcusu (3. kez) · ses
  paylasma · konum · anket · ileri tarihli paylasim · IBAN/kisi/etkinlik ·
  acik-koyu tema + Ayarlar · 4 ekran onboarding · bolme secici (yazi).
- ⚠️⚠️⚠️ **TURU 81 — ONCE KESIF YAPILDI (9 alt sistem, KOD YAZMADAN).**
  Bu adim olmasaydi isin YARISI YENIDEN YAZILACAKTI, cunku cogunun altyapisi
  ZATEN VARDI ve yalnizca BAGLANMAMISTI:
  · **SES**: kayit + genlik + sunucu alanlari + oynatma balonu HEPSI calisiyor;
    eksik olan `onTap` ve `kayitSeridi()`nin CAGRILMAMASIYDI.
  · **KONUM**: `location` tipi DB CHECK'inde ve sunucu beyaz listesinde VARDI.
  · **KISI**: `contact` tipi CHECK'te VARDI, Go beyaz listesi REDDEDIYORDU.
  · **ANKET**: `docs/medya-arastirma/tasarim-anket.md` icinde **669 satirlik
    tam muhendislik tasarimi** duruyordu.
  ⚠️ **DERS: buyuk bir istek geldiginde ONCE "bunun ne kadari zaten var?"
     diye SOR.** Bu projede ozelliklerin buyuk kismi "yazilmis ama
     baglanmamis" durumda.
- ⚠️⚠️⚠️ **TURU 81 — MEDYA OLCUSU: MODEL TERSINE DONDU (kullanicinin UCUNCU
  sikayeti).** Kullanici: *"tek fotograflarda BAZILARI GENISLIK DAHA AZ
  BAZILARI BUYUK, bunun mantigi nedir, BIZIM DE BOYLE OLMASI GEREKIYOR"*.
      ESKI: genislik sabit -> yukseklik hesaplanir -> `cover` KIRPAR (%41-51)
      YENI: **yukseklik sabit -> genislik ORANDAN gelir -> KIRPMA YOK**
  ⚠️ ON KOSUL: `media_assets.width/height` 015'ten beri VARDI, presign ucu
     kabul ediyordu, `yukle()` parametreleri tasiyordu — ama **17 CAGRI
     YERININ HICBIRI DEGER GECMIYORDU**. Sutun bastan beri OLUYDU.
  ⚠️ Olcum **`yukle()` ICINDE** yapilir, CAGRI YERLERINDE DEGIL (17 yerden
     biri kesin unutulurdu). Gorselde `ui.ImageDescriptor.encoded` (yalniz
     BASLIK okunur; tam decode 1600x1600 icin ~10 MB gecici RAM demekti).
  ⚠️ `media_boyut` ("WxH") **`medyaTurleri` sabitine** eklendi — o sabiti YEDI
     sorgu da kullandigi icin "6'ya ekleyip 7.'yi atlama" hatasi YAPISAL
     OLARAK imkansiz.
  ⚠️ Coklu galeri **`PageView` -> `ScrollController` + `ListView`**: `PageView`
     TANIM GEREGI esit genislik ister. Turu 76b'nin yasagi `ListView`in
     KENDISINE degil **`PageScrollPhysics`e** aitti (sabit-viewport varsayimi).
     ⚠️ YAPMA: buraya `PageScrollPhysics`/`snap` ekleme.
- ⚠️⚠️ **TURU 81 — SES: OZELLIK VARDI, KESFEDILEMEZDI.** Mikrofonda YALNIZ
  `onLongPressStart/End` vardi (`onTap` YOK) ve `kayitSeridi()` REPODA
  HICBIR YERDEN CAGRILMIYORDU — serhi *"turu 74b'de duzeltildi"* dese de
  yalnizca `kayitAlani()` baglanmisti. Genlik 100ms'de bir okunuyordu ama
  YALNIZCA sunucuya gonderilmek uzere; kayit aninda HICBIR SEY cizilmiyordu.
  ⚠️ **DERS: "test edildi" yazan bir ozellik KESFEDILEBILIR mi diye ayrica sor.**
- ⚠️⚠️ **TURU 81 — ANKET: TASARIMIN KENDI TUZAGINA DUSMEDIK.** Tasarim
  `messages_type_check`i YENIDEN KURUYORDU; migration 039 (ayni tur) onu
  ZATEN kurmustu. Tasarimin yazdigi kume `document`, `contact`, `iban`,
  `etkinlik` tiplerini ICERMIYOR ve calissaydi **DORDUNU BIRDEN SESSIZCE
  DUSURURDU**. Migration 040 kisita HIC DOKUNMUYOR.
  ⚠️ 015'in "DOKUNMAYIN" serhinin korudugu sey tip kumesini DONDURMAK DEGIL,
     **BIRBIRINDEN HABERSIZ IKI YENIDEN KURULUM**dur.
- ⚠️⚠️ **TURU 81 — ZAMANLANMIS PAYLASIMDA SUPURGE YOK (tasarim kazanci).**
  Akis OKUMA ZAMANI calistigi icin (turu 75) `yayin_at <= now()` yuklemi
  yeterli. Bir sweeper'dan yalniz daha basit degil **DAHA GUVENLI**: sweeper
  calismazsa gonderi HIC yayinlanmaz ve kullanici sebebini bilemez.
  ⚠️ `created_at = yayin_at` YAZILIR: siralama ve imlec `created_at` uzerinden
     yuruyor; olusturma ani birakilsaydi yarina zamanlanan gonderi
     yayinlandiginda **DUNUN SIRASINDA** belirip GOMULURDU.
- 🛡️ **TURU 81 — YENI MUHAFIZ: `internal/social/yayin_test.go`.**
  Mevcut `sutun_test.go` YALNIZCA SELECT sutun listesini dogruluyor,
  **WHERE yuklemini DEGIL** — yani yuklem bir sorguda eksik kalirsa
  YAPISAL OLARAK yakalayamaz. Yeni muhafiz **ANINDA GERCEK BIR BOSLUK BULDU**
  (`erisebilirMi`: yayinlanmamis gonderi ETKILESIME ACIKTI).
  ⚠️ Calistigi, yuklem BIR SORGUDAN CIKARILIP test kirmiziya dusurulerek
     KANITLANDI. Denetim ayrica muhafizin **IKI YUZEYDE calismadigini** buldu
     (arama deseni `FROM posts p JOIN users` idi) -> `FROM posts p`ye
     genisletildi; 9 sorgu taraniyor, iki mesru istisna GEREKCESIYLE yazili.
- ⚠️⚠️⚠️ **TURU 81b — DENETIM: 31 AJAN, 25 BULGU -> 21 ONAYLANDI, 6 SEVK
  ENGELI. HEPSI DUZELTILDI.** En agirlari:
  · **ACIK TEMADA TUM SOHBET OKUNAMAZ**: balon renkleri SABIT KOYU, icindeki
    yazi TEMADAN (acik temada siyah) -> **1.23:1 kontrast** (olculdu). Turun
    getirdigi acik tema, uygulamanin EN COK KULLANILAN ekranini yok ediyordu.
    FIX: `ChatColors` `brightness`e baglandi.
    ⚠️ **DURUST SINIR: kod tabaninda ~500 sabit renk noktasi var**; tema
       iskeleti dogru olsa da o noktalar acik temada TEMANIN DISINDA kalir.
       Sohbet EN KRITIGIYDI ve kapatildi; digerleri kademeli cevrilmeli.
  · **BASILI TUT BOZULDU**: kayit baslayinca `build()` seride donuyor ->
    mikrofonun `GestureDetector`i AGACTAN SILINIYOR -> `onLongPressEnd` BIR
    DAHA CALISAMAZ -> parmagini kaldiran kullanicinin kaydi 10 dk tavana
    kadar TAKILI kaliyordu. Serhim *"WhatsApp deseni KORUNDU"* diyordu —
    **KORUNMAMISTI** (projenin en sik sinifi, kendi eklememde).
    ⚠️ Jest ONARILMADI **KALDIRILDI**: serit tasarimiyla YAPISAL OLARAK
       bagdasmiyor ve kullanici zaten "bir defa tiklama yeterli" dedi.
  · **CANLI DALGA HIC CIZILMIYORDU**: `shouldRepaint` AYNI liste nesnesinin
    uzunlugunu KENDISIYLE karsilastiriyordu -> her zaman `false`. Uzunluk
    artik KURULUM ANINDA yakalaniyor.
  · **`poll.vote`/`poll.closed` ISTEMCIDE DINLENMIYORDU** (sunucu uretiyor,
    tuketen yok) — biri oy verdiginde digerlerinin ekraninda HICBIR SEY
    degismiyordu.
  · **SOHBET LISTESI ONIZLEMESI HAM ICERIK BASIYORDU**: sunucudaki switch
    duzeltilmisti ama **ISTEMCININ KENDI KOPYASI** atlanmisti -> listede
    `TR33...|Ahmet` gorunurdu (**IBAN SIZINTISI**, ayrica PUSH'a da giderdi).
  · **ZAMANLANMIS GONDERI GECMISE YAYINLANIYORDU** (siralama `created_at`).
  · **WS DUZELTMEM `mine` ALANLARINI EZIYORDU**: yayin govdesi ORTAKTIR
    (sifir UUID), yani `mine` her secenekte false. Dogrudan atayinca BASKA
    BIRI oy verdiginde **KULLANICININ KENDI OYU EKRANDAN SILINIYORDU**.
    FIX: `yayinlaBirlestir()` — sayimlar yayindan, `benim` YERELDEN.
- ⚠️⚠️ **TURU 81 — KENDI BULDUKLARIM (denetim beklerken):**
  · **ANKET YAYINI HIC YAPILMIYORDU**: `anketOku(ctx, pollID, "")` — bos dize
    gecerli UUID DEGIL. **CANLI DB'DE DOGRULANDI:**
    `invalid input syntax for type uuid: ""`. `anketOku` hata doner,
    `anketYayinla` log basip cikar ve **WS yayini HIC yapilmaz.**
    FIX: sifir UUID (`00000000-...`).
  · **ONBOARDING HICBIR CIHAZDA ACILMAYACAKTI**: `_p?.getBool(k) ?? true`
    ifadesi "depo ACILAMADI" ile "anahtar HENUZ YAZILMADI" (= TEMIZ KURULUM)
    durumlarinin IKISINI DE `true`ya ceviriyordu. Dort ekran yazilmis olmasina
    ragmen kullanici onlari HIC GORMEYECEKTI.
- 📊 **TURU 81 — E2E 181 -> 208.** En degerli kontrol: **"GERCEK olcu
  ZINCIRDEN geciyor"** — ilk yazimda **KIRMIZI DUSTU** ve gercek bir bosluk
  gosterdi: e2e araci presign'da `width/height` GONDERMIYORDU, yani zincir
  (presign -> sutun -> gonderi sorgusu) HIC SINANMIYORDU. Cikti artik
  `["1080x1350","0x0"]`.
  ⚠️ E2E ayrica **KENDI DUZELTMEMIN YAN ETKISINI YAKALADI**:
     `created_at = yayin_at` degisikligi yazarin kendi zamanladigi gonderisini
     **GORUNURLUK yuklemine degil IMLECE** takiyordu (`now + 1 saat` tavani).
     Statik denetim GOREMEZDI.
- 📌 **MIGRATION NUMARALARI (guncel):** 039 = mesaj tipleri (`iban`,`etkinlik`)
  · 040 = anket (`polls`,`poll_options`,`poll_votes`) · 041 = `posts.yayin_at`.
  Sonraki **042**'den.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **KALDIGIMIZ YER (10 Agu 00:35): TEST TURU 80 YAYINLANDI** — android **31336651933**
  + ios **31336653481** (**edc0da8**), R2 apk=117730375 (md5 f97e5cb7) ipa=24040413
  (md5 63b38976) index=9624 (md5 50bc97cb), purge OK, **CDN BIREBIR** (apk + ipa +
  index.html UCU DE MD5 esit), indir sayfasi 10 Agu 00:35 (saat 5 yerde + canli saat),
  debug imza YOK, **iOS min 16.0 dogrulandi**, IPA icinde turu 80 kodu var
  ("Rezervasyon" gecti), **BACKEND DEPLOY EDILDI** (edc0da8; migration 001->038
  atilabilir kopya DB'de dogrulandi = 47 tablo; `medya: aktif (R2)` +
  `ai: aktif (metin gpt-4o-mini · gorsel gpt-image-1.5)`) + health ok, DB TEMIZ
  (0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 181/181 UCTAN UCA GECTI** · **188 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata**.
  ⚠️ **KULLANICIYA VERILEN ADRES:** https://indir.gebzem.app/index.html?v=20260810-0035
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 80b — IKI TUR DENETIM. IKINCI TUR **KENDI DUZELTMELERIMDE** 2 SEVK
  ENGELI DAHA BULDU (17/20 onaylandi, 3 elendi). "Build ALMAK yayinlamak DEGILDIR"
  dersinin BESINCI dogrulanmasi: UC build alindi, ilk IKISI YAYINLANMADI.**
- ⚠️⚠️⚠️ **(A) `KisiselYap` GECMIS RANDEVULARI DA IPTAL EDIYORDU (SEVK ENGELI).**
  Yuklemde `baslangic` KOSULU YOKTU, ama HEMEN USTUNDEKI KENDI SERHIM
  *"gecmis randevulara DOKUNULMAZ"* diyordu — projenin en sik tekrarlayan sinifi
  ("yorumun anlattigi kontrol GOVDEDE yok") ve bunu KENDI DUZELTMEMDE yaptim.
  `'onaylandi'` GELECEK demek DEGIL: `geldi`/`gelmedi` gecisleri OPSIYONEL ve o
  dugmeler turu 80b'ye kadar HIC YOKTU -> **GERCEKLESMIS TUM GECMIS RANDEVULAR
  hala 'onaylandi'**. Kisisele donen isletme aylar once tamamlanmis rezervasyonlari
  "isletme iptal etti"ye ceviriyor, musterilere o eski ziyaretler icin BILDIRIM
  yagdiriyordu. `Gecisler` tablosunda `iptal_isletme`den DONUS YOK -> **GERI
  ALINAMAZ KAYIT TAHRIFATI**. FIX: `AND baslangic > now()`.
- ⚠️⚠️⚠️ **(B) GECE YARISINI ASAN CALISMA SAATLERINDE HER SLOT 409 DONUYORDU
  (SEVK ENGELI).** `Slotlar(gun)` "22:00-02:00" mesaide gece yarisini ASAR ve
  ertesi takvim gunune tasan slotlari da uretir; yani 11 Agu 00:30 slotu **10 Agu'nun**
  calisma gunune aittir. Turu 80b'de ekledigim yazma-yolu dogrulamasi ise anin
  KENDI takvim gunune bakiyordu -> arayuzun GOSTERDIGI her gece slotu POST'ta 409.
  **Bar/restoran gibi gece calisan mekanlar randevu ALAMAZDI.**
  ⚠️ Bu, AYNI COMMIT'te `ileri_gun` icin duzelttigim *"okuma ve yazma FARKLI TABAN
  kullaniyor"* hatasinin TEKRARIYDI. FIX: `SlotVarMi()` tek kaynagi — anin kendi
  gunu VE bir onceki gun denenir.
  ✅ E2E'de AMPIRIK dogrulandi: saatler gecici gece vardiyasina cevrilip
  `GECE YARISI SONRASI slot POST ile KABUL EDILIYOR | HTTP 201 saat=00:15`.
- ⚠️⚠️ **(C) `randevu_iptal` CIFT YONLUDUR, istemci TEK YON varsayiyordu.**
  `IptalIsletme` -> alici MUSTERI · `Iptal` -> alici ISLETME. Ikisi de ayni tur
  adini gonderiyordu; istemci `randevu_iptal`i KOSULSUZ musteri listesine
  yonlendiriyordu -> musteri iptal edince ISLETME bildirime dokunup KENDI musteri
  listesine dusuyor, iptali gelen kutusunda GOREMIYORDU.
  FIX: `randevu_iptal_musteri` AYRI turu + istemcide `isletmeyeGiden` kumesi.
  ⚠️ YAPMA: ikisini tekrar tek tur adina indirgeme.
- 📌 **TURU 80b — DIGER (ikinci tur):** gun seridi sunucunun izin verdigi SON GUNU
  HIC gostermiyordu (`+1`) · `_yenile` catch dali bolme kimligini kontrol etmiyordu
  (bir bolmenin ag hatasi DIGER bolmenin dolu ekraninda hata cizdiriyordu) ·
  yukleme dali hikaye seridini ve **BOLME SECICISINI** cizmiyordu (Keşfet
  yuklenirken geri donme yolu KAYBOLUYORDU) · asagi-cek kurtarmasi tam gerektigi
  anda no-op oluyordu (`_elleYenile`: ucustaki istegi bekler) · tam ekran dugmesi
  SARKAN KOMSUDA da ciziliyordu ve dokunma alani **27dp** idi -> 44dp (turu 78b
  dersi; bu dugme KIRPILAN ICERIGIN TEK kurtarma yolu) · `AyarKaydet` okuma
  hatasini YUTUP uydurma varsayilanlari 200 ile donduruyordu · `AyarGetir`
  `AyarOkuSahip` kullaniyor (kapi RANDEVU ALMA yolundadir; salt-okumaya
  uygulanmasi ex-isletmenin gecmis kayitlarina giden TEK arayuz yolunu kapatiyordu).
- 🛡️ **TURU 80b — MUHAFIZLAR KANITLANDI:** `internal/isletme/sutun_test.go` artik
  SIRAYI da olcuyor (`il`<->`ilce` TAKAS EDILIP test KIRMIZIYA dusuruldu — ayni
  tipteki iki sutun yer degistirse Postgres HATA VERMEZ, degerler SESSIZCE takas
  olur) · `internal/randevu/sutun_test.go` (`oku()` IKI Scan dali) da
  `not_isletme` yanittan cikarilarak dogrulandi · **E2E 172 -> 181**.
- **KALDIGIMIZ YER (9 Agu 23:45): TURU 80 + 80b KODU BITTI, BACKEND DEPLOY EDILDI**
  (**001e2db**; migration 001->038 atilabilir kopya DB'de dogrulandi = 47 tablo;
  `medya: aktif (R2)` + `ai: aktif (metin gpt-4o-mini · gorsel gpt-image-1.5)`)
  + health ok, DB TRUNCATE edildi.
  ✅ **CANLI SUNUCUDA 178/178 UCTAN UCA GECTI** · **188 ROTA CAKISMASIZ** ·
  `go build`+`go vet`+`go test ./...` temiz · `flutter analyze` **0 hata**.
  Build tetiklendi: android **31334733441** · ios **31334734942**.
- ⚠️⚠️⚠️ **TURU 80b — DENETIM: 19/19 ONAYLANDI, 0 ELENDI (24 ajan, 5 mercek).**
  Dordu SEVK ENGELI; hepsi build ONCESI yakalandi.
- ⚠️⚠️⚠️ **(1) `randevu_ayar` UPSERT'te `COALESCE(EXCLUDED.x, mevcut)` OLU KODDU.**
  `EXCLUDED.acik` ZATEN `COALESCE($2,false)` sonucudur -> **ASLA NULL OLAMAZ** ->
  `randevu_ayar.acik` yedegi HIC degerlendirilmez. Istemci alanlari TEK TEK
  gonderdigi icin isletme "Randevu suresi"ni degistirince `acik` FALSE'a dusuyor,
  ayar bloku ekrandan kayboluyor: **ozellik ILK AYAR DOKUNUSUNDA KENDINI
  KAPATIYORDU** (turu 80'in manset ozelligi varsayilanlar disinda
  YAPILANDIRILAMAZDI). Gercek Postgres'te gecici tablo + ROLLBACK ile AMPIRIK
  kanitlandi. FIX: UPDATE dalinda EXCLUDED yerine **HAM PARAMETRE** (`$2..$6`);
  VALUES tarafindaki COALESCE'lar KALIR (INSERT'te NOT NULL sutunlar icin sart).
  ⚠️ **DERS: `ON CONFLICT` dalinda `EXCLUDED.x`, VALUES'ta COALESCE'lanmis bir
  parametreyse "gonderilmedi" bilgisi ZATEN KAYBOLMUSTUR.**
  ⚠️ **E2E NEDEN GOREMEDI: tum alanlari TEK cagrida gonderiyordu** -> hicbir
  parametre NULL olmuyor, COALESCE yedegi HIC sinanmiyordu. Artik KISMI govde
  gonderen kontrol var.
- ⚠️⚠️⚠️ **(2) `_yukleniyor` SIZINTISI — AKIS KALICI KILITLENIYORDU.**
  `if (!mounted || bolme != _bolme) return;` erken donusu `_yukleniyor = false`
  satirini ATLIYORDU. Bayrak **PAYLASILAN**: yukleme surerken bolme degistirilirse
  surec boyunca true kalir; `_yenile` ve `_dahaGetir`in ILK SATIRI her cagriyi
  reddeder -> asagi-cek CALISMAZ, sayfalama DURUR, paylasilan gonderi akista
  GORUNMEZ. `AkisEkrani` keepAlive oldugu icin **uygulama OLDURULMEDEN duzelmez**
  (turu 77b'de kapatilan hatanin AYNISI). Iki yerde birden duzeltildi.
  ⚠️ **DERS: bir bayragi await'ten once yazip erken donus ekliyorsan, o donusun
  bayragi TEMIZLEYIP temizlemedigini SOR.** Bayrak bolmeye ozgu DEGILSE, listeye
  yazmayi kapiyla koru ama BAYRAGI HER DURUMDA temizle.
- ⚠️⚠️ **(3) DORT RANDEVU BILDIRIM TURU ISTEMCIDE TANIMSIZDI** -> hepsi
  "bir işlem yaptı" genel metnine dusuyordu (**onay ile red AYIRT EDILEMIYORDU**)
  + her biri Sentry'ye alarm basiyordu. Turu 75b'deki `takip_onaylandi` hatasinin
  aynisi ve uyarisi HEMEN USTUNDE yaziliydi.
  ⚠️ **(4)** Randevu bildirimine dokunmak AKTORUN PROFILINE gidiyordu.
  ⚠️ YAPMA: sunucuya yeni bildirim turu eklerken `bildirimler_sayfasi.dart`
  switch'ini ve `_git()` yonlendirmesini atlama.
- ⚠️⚠️ **TURU 80b — `Olustur` TAKVIM KURALLARININ HICBIRINI DOGRULAMIYORDU.**
  Kapali gun · calisma saati · slot hizasi YALNIZ okuma yolunda (`Slotlar`)
  vardi; istemci takvimi HIC ACMADAN POST atarak **bayramda 03:17'ye** randevu
  yazdirabilirdi. **Arayuzun kurala uymasi, kuralin UYGULANDIGI anlamina GELMEZ.**
  ⚠️ FIX'te kural **IKINCI KEZ YAZILMADI**: uretecin KENDISI cagrilip istenen anin
  uretilen slotlar arasinda olup olmadigina bakiliyor (`Musait` BILEREK yok
  sayilir — kapasite karari advisory kilitli tek deyimde kalsin).
- ⚠️⚠️ **TURU 80b — `ileri_gun` IKI FARKLI TABANDA olculuyordu** (okuma GUN BASI,
  yazma AN) -> son gunun ogleden sonraki slotlari "musait" gorunup POST'ta **400**
  donuyordu. `IleriGunDisi()` TEK KAYNAGINA alindi (iki taraf da gun basi).
- ⚠️⚠️ **TURU 80b — `myProfileProvider` OTURUMA BAGLI DEGILDI.** `keepAlive`
  oldugu icin cikis sonrasi onbellek yasiyordu: baska hesapla girildiginde alt
  menude ve Profil sekmesinde **ONCEKI kullanicinin adi + avatari** ciziliyordu.
  Turu 80 profil ikonunu GERCEK RESME cevirdigi icin bedel gorunur oldu.
  FIX: govdenin ilk satirinda `ref.watch(authProvider)` (`myUserIdProvider` ile
  birebir ayni desen). ⚠️ YAPMA: `logout()` icine elle `invalidate` koyarak cozme
  — bir sonraki oturuma bagli saglayicida yine unutulur.
- ⚠️⚠️ **TURU 80b — E2E KALICI YALANCI-YESIL (yontem dersi).** Isletmenin calisma
  saatleri YALNIZ `gun: 1` (Pazartesi) tanimliydi; randevu blogu haftada TEK GUN
  calisiyordu. **172/172 gecmesinin sebebi, kosuldugu gunun (Pazar) yarininin
  PAZARTESI olmasiydi** — yesil, kodun dogrulugunu DEGIL **TAKVIMI** olcuyordu.
  ⚠️ **DERS: bir testin yesili, testin GERCEKTEN KOSTUGU anlamina gelmez.**
  Kosul-bagimli bloklarda (`if (musait) {...}`) sartın saglandigini de DOGRULA.
- ⚠️⚠️ **TURU 80b — OLU OZELLIKLER (bu sinifin YEDINCI tekrari):**
  · **KAPALI GUNLER**: `randevu_kapali` tablosu (038) + IKI uc + `Slotlar`daki dal
    + IKI servis metodu VARDI, **CAGIRAN EKRAN YOKTU** -> isletme bayramda randevu
    almayi DURDURAMIYORDU. `KapaliGunlerEkrani` eklendi.
  · **'geldi'/'gelmedi'**: gecis tablosunda tanimli, rozet 'geldi'yi YESIL
    ciziyordu — **YAZAN DUGME YOKTU**.
  · **`not_isletme`**: sutun + istek alani + SQL + yanit + Dart modeli vardi, ne
    YAZAN ne CIZEN yol vardi. Isletme artik red/iptal sebebi yaziyor (OPSIYONEL),
    musteri sebebi randevu satirinda goruyor.
    ⚠️ Ayrica **MUSTERI isletmenin ozel notuna yazabiliyordu** (`iptal` gecisini
    musteri yapiyor) — yetki `Gecisler` tablosuyla hizalandi.
  ⚠️ **DERS (yedinci kez): bir sutun/uc/servis ekledigin AN onu KULLANAN yolu da yaz.**
- 📌 **TURU 80b — MEDYA OLCULERI: DURUST NOT.** Yukseklik tavani DOGRU sonucu
  verdi (kutu her cihazda ekranin ~%32'si; Threads ~%28-31). AMA **`kMedyaEnBoy`
  BUGUN HICBIR CIHAZDA BAGLAYICI DEGIL** — `medyaYuksekligi` bir `math.min`dir ve
  tavan HER ZAMAN kazanir (sabitin baglayici olmasi icin oge genisliginin
  ~216dp ALTINA inmesi gerekir; en dar telefonda bile tek medya ~296dp).
  SONUC: kutu en-boyu ~1.06-1.65 ve `cover` ile **dikey fotograf %41-51, video
  %58-66 KIRPILIR.** Bu, *"cok uzun"* sikayetinin KACINILMAZ karsi tarafidir.
  ⚠️ **KIRPMANIN KURTARMA YOLU ZORUNLU**: fotografta VARDI (`TamEkranGorsel`),
  **VIDEODA HIC YOKTU** — yani videonun yalniz ORTA SERIDI gorulebiliyordu.
  `TamEkranVideo` eklendi; giris **NOKTASAL DUGME** (sol alt).
  ⚠️ YAPMA: videoya TAM ALANLI `GestureDetector` koyma — oynaticinin kendi tam
  ekran dinleyicisi jest arenasini kazanip dokunuslari YUTAR (turu 77b'de
  video hikayede ileri/geri dokunusu tam bu yuzden calismiyordu).
  ⚠️ YAPMA: `cover`i `contain`e cevirme (yatay kutuda dikey icerik kus kadar
  kalir + siyah bant).
- 🛡️ **TURU 80b — KALICI MUHAFIZLAR:**
  · **`internal/isletme/sutun_test.go`** (pakette HIC test yoktu): SELECT/Scan
    hizasi + **"Scan edilip yanit haritasina konmayan alan"** sinifi (turu 78'de
    kapak + onayli rozeti tam boyle kaybolmustu). ⚠️ Muhafizin calistigi,
    `randevu_acik` yanittan CIKARILIP test KIRMIZIYA dusurulerek **KANITLANDI**.
    ⚠️ Test ILK YAZIMDA kendi serhindeki "SELECT" kelimesini eslestirip YANLIS
    ALARM verdi -> ayristiriciya YORUM TEMIZLIGI eklendi. Kaynak okuyan her
    testte bu tuzagi hatirla.
  · **`rota_test.go`**: turu 80'in 13 ucu cozumleme vakalarina eklendi. En riskli
    ayrim `/isletme/...` (STATIK) vs `/isletmeler/{id}/...` (PARAMETRELI).
    **188 rota cakismasiz.**
  · **E2E 172 -> 178**: kapali gune dogrudan POST reddi · calisma saati disi reddi
    · slot hizasi disi reddi · **kismi ayar kaydinin diger ayarlari korudugu** ·
    kapali gun listeleme + geri alma.
- 📌 **TURU 80b — DIGER DUZELTMELER:**
  · Isletme kisisele donunce **bekleyen randevular YETIM kaliyordu** (musterinin
    listesinde gorunmeye devam ediyor; isletmenin iptal yolu TAMAMEN kapanmis —
    gelen kutusu 404). `KisiselYap` artik aktifleri `iptal_isletme` yapip
    musteriye BILDIRIYOR. **Satir SILINMEZ** (veri politikasi).
  · **`AyarOku`ya `hesap_turu='isletme'` kapisi**: hesap kisisellesince
    `isletmeler` satiri SILINMIYOR, kapi olmadigi icin randevu almaya DEVAM
    ediyordu. Kapi **TEK KAYNAGA** kondu (dort uc oradan gecer).
  · `_dahaVar` ve `_kesfet` **BOLME BASINA** tasindi (soguk baslangic seridi
    Keşfet'te de ciziliyordu; tukenmis sayfalama bolme degisiminde diriliyordu).
  · `_bolmeDegistir`in tetikledigi `_yenile()` **sessizce yutulabiliyordu**
    (`_yukleniyor` kapisi) ve TEKRAR DENEYEN yol yoktu -> **Keşfet KALICI BOS**.
    `_bolmeYukle()`: ucustaki istegin bitmesini bekler (10 x 150ms).
  · Yuklenmemis bolme artik SPINNER gosteriyor ("Henüz gönderi yok" YERINE).
  · Gonderi silme **HER IKI BOLMEDEN** (ayni gonderi iki listede de bulunabilir).
  · `IsletmeSeridi._yukle` **try/catch'siz** idi: tek ag kopmasi "Randevu al"
    dugmesini TAMAMEN dusuruyordu (tekrar deneme yolu yok). Tek tekrar eklendi.
  · `randevu_al` AppBar alt basligi **sabit 20px** idi; yazi olcegi 1.3'te tasip
    **RenderFlex seridi** cikariyordu -> olcege gore + ellipsis.
  · `u.username` COALESCE'siz taraniyordu (18 sorgunun tek istisnasi).
  · Bayat serhler: iki dosya *"flutter_localizations YOK"* diyordu, turu 80 onu
    **EKLEDI**; buna dayanan *"showDatePicker EKLEME"* hukmu GECERSIZDI.
    (Saat secici karari AYRI gerekceyle DURUYOR: serbest saat, calisma saatine
    uymayan secim demektir.)
- ⚠️⚠️⚠️ **INDIR SAYFASI — KOK NEDEN NIHAYET OLCULDU (kullanici UCUNCU KEZ
  "saati goremiyorum" dedi).** Sunucu tarafi YINE dogru cikti (`no-cache,
  no-store, must-revalidate` + `cf-cache-status: DYNAMIC` + saat 5 yerde + canli
  saat + turu 50 flexbox fix'i duruyor). **GERCEK SEBEP:**

      https://indir.gebzem.app/?v=123  --302-->  /index.html   <- SORGU DUSUYOR

  Yani **ciplak alan adina cache-busting parametresi eklemek ISE YARAMIYOR**;
  R2'nin 302'si sorgu dizesini KORUMUYOR. Ana ekrana eklenmis kisayoldan ya da
  agresif onbellekli bir webview'dan girildiginde tarayici `no-store` basligina
  **RAGMEN** eski kopyayi cizebiliyor.
  ✅ **COZUM: kullaniciya `/index.html?v=<surumEtiketi>` VERILECEK** — 302'ye HIC
  ugramaz ve her surumde FARKLI adres oldugu icin hicbir onbellek katmani
  eslestiremez. Uretici bu adresi kosu sonunda BASIYOR.
  ⚠️ **YAPMA: kullaniciya ciplak alan adini verme.**
  ⚠️ Icerik muhafizi turu 79'a SABITLENMISTI -> her turda BU SURUME sabitlenir
  (muhafiz calisti: turu 80 metnini yazinca eski kontrol PATLADI, sayfa
  uretilmedi).
- 📌 **MIGRATION NUMARALARI (guncel):** 038 = randevu (`randevu_ayar`,
  `randevu_kapali`, `randevular`). Sonraki **039**'dan.
- ⏳ **EN SONA BIRAKILAN (kullanici emri):** `active_call_controller.dart`
  ~500 satirlik olu bekletme/park zinciri temizligi.

- **TURU 79 — YAPAY ZEKA ILE GORSEL URETME (kod BITTI, backend DEPLOY d335af6).**
  Kullanici: *"yapay zeka ile görsel oluşturma nerede?"* -> *"tamamda olacak
  dedim ya"*. HAKLIYDI: anahtari verirken **"hepsi olsun"** demisti; turu 77/78'de
  yalniz METIN uclari baglanmisti. ✅ **CANLI DOGRULANDI** (uc kez: 21-28 sn,
  ~1,5 MB PNG, imzali adresten indi, kota dogru dustu) ve **GORSEL GOZLE
  KONTROL EDILDI**. ✅ **150/150 UCTAN UCA.**
- ⚠️⚠️⚠️ **TURU 79 — DIS SERVISIN MODEL ADINI VE PARAMETRELERINI VARSAYMA.**
  Iki varsayimim CANLI SUNUCUDA curudu:
  · `response_format: "b64_json"` -> **400 Unknown parameter** (images ucunda
    ARTIK YOK). Kaldirildi; artik `b64_json` VE `url` **IKI BICIM** de
    destekleniyor (URL gelirse sunucu INDIRIR) — API bir daha degisirse ozellik
    sessizce olmesin.
  · `dall-e-3` -> **"The model does not exist"**. `GET /v1/models` ile hesabin
    GERCEKTEN erisebildikleri listelendi -> **`gpt-image-1-mini`** (ailenin en
    ucuzu, urun fotografi icin yeterli).
  ⚠️ **YONTEM: once `/v1/models` ile listele, istegi `curl` ile SINA, SONRA kod yaz.**
- 📌 **TURU 79 — `media.Yukle` (SUNUCU TARAFI PUT) EKLENDI.** "Medya API'DEN
  GECMEZ" kuralinin **BILINCLI ISTISNASI**; kullanici dosyalari (100 MB video)
  HALA presigned PUT ile dogrudan R2'ye gidiyor. AI gorseli **ISTEMCIDE HIC
  YOKTUR** (OpenAI -> sunucu). Istemciye gonderip ondan yukletmek (a) baytlari
  IKI KEZ tasirdi, (b) istemcinin yuklemeyi ATLAYIP kendi baska bir gorselini
  "AI uretti" diye kaydetmesine izin verirdi. `Content-MD5` gonderilir (commit
  adimi YOK, butunluk BURADA kanitlanir).
  ⚠️ YAPMA: bu fonksiyonu kullanici yuklemelerine acma.
- 📌 **TURU 79 — `kind='image'` KULLANILDI, YENI TUR ACILMADI.** Yeni bir `kind`
  (a) `media_assets.kind` CHECK'ini genisletmeyi gerektirirdi (turu 78'de bu
  tuzaga IKI KEZ dusuldu), (b) `erisebilir()` icine YENI DAL gerektirirdi ve o
  dal unutuldugunda **yukleyenden baska HERKESE 403** donerdi (DORT kez sahaya
  cikti). Mevcut urun/ilan dallari zaten kapsiyor.
- ⚠️⚠️⚠️ **TURU 79b — `/ai/urun-metni` GORSEL KOTASINI YIYORDU (KENDI
  REGRESYONUM, SEVK ENGELI).** Turu 77'de `tur` YALNIZCA BIR ETIKETTI ve o uc
  "gorsel" yaziyordu — ZARARSIZDI. Turu 79'da `kapi()` icine
  `gorselMi := tur == "gorsel"` ekleyip etiketi **"pahali gorsel kotasi"**
  olcutune cevirdim ama CAGRI YERINI guncellemedim. Sonuc: "Yapay zekâ ile
  açıklama yaz" dugmesine her dokunus, turun MANSET OZELLIGINDEN bir hak
  yakiyordu; 10 aciklama yazdiran kisi HIC GORSEL URETMEDEN "gorsel hakkin
  doldu" goruyordu.
  FIX: `tur="urun-metni"` + olcut **TEK KAYNAGA** alindi (`gorselKotasiMi`).
  ⚠️ **DERS: bir kota/yetki olcutunu SERBEST METIN etiketine baglarken TUM
     cagri yerlerini TARA** (`grep 'h.kapi(w, r,'` dort satir donduruyor).
- ⚠️⚠️ **TURU 79b — ISTEMCI ZAMAN ASIMI SUNUCUNUN USTUNDE OLMALI (SEVK ENGELI).**
  Istemci 90 sn, sunucu gorsel uretimine 120 sn veriyordu: yavas uretim
  **GARANTILI KAYIP** — sunucu tamamlar, OpenAI FATURAYI KESER, gorsel R2'ye
  yazilir, kota 'tamam' kapanir, ama istemci `media_id`yi HIC ALMAZ; gorsel
  yetim kalir, kullanici jenerik hata gorup TEKRAR dener (ikinci hak da gider).
  FIX: istemci 150 sn. ⚠️ Sunucudaki `gorselZamanAsimi` degisirse BURASI DA.
- ⚠️⚠️ **TURU 79b — `durum='iptal'` YAZAN YOL YOKTU** ("sutun var, yazan yol
  yok" sinifinin **ALTINCI** tekrari). Sutun 036'da TAM BU IS ICIN eklenmis ve
  kota sayimi `durum <> 'iptal'` yuklemini ZATEN kullaniyordu. Icerik politikasi
  reddi **PARA HARCAMADIGI HALDE** gunluk hakki 24 saat yakiyordu.
  FIX: OpenAI'ya ULASIP reddettiyse `'iptal'`; zaman asimi/5xx -> `'hata'`
  (faturalanmis OLABILIR — turu 77b ilkesiyle ayni).
- ⚠️⚠️ **TURU 79b — KOTA REZERVASYONU ATOMIK DEGILDI.** `INSERT ... SELECT
  WHERE (count) < kota` READ COMMITTED'da escamanli iki istegi de gecirir; kota
  asilir ve GORSEL tarafinda bu **GERCEK PARA** demektir. FIX:
  `pg_advisory_xact_lock(hashtext(havuz+userID))` — islem bitince otomatik
  birakilir (kilit SIZMAZ). ⚠️ Anahtar HAVUZU da icerir: metin ve gorsel
  havuzlari birbirini gereksiz BEKLETMESIN. ⚠️ COMMIT sart (defer Rollback var).
- 📌 **TURU 79b — REDDEDILEN GORSEL: `DELETE /ai/gorsel/{id}`.** Onceden
  "Vazgec" denen gorsel R2'de kalip kullanicinin AYLIK DEPOLAMA kotasini KALICI
  yiyordu ve temizleyecek yol YOKTU. Silme kapilari: sahiplik + `kind='image'` +
  `status='aktif'` + **HICBIR YERE BAGLI OLMAMA** (urun/ilan/etkinlik/gonderi/
  kanal/avatar/kapak/grup/mesaj). ⚠️ **AI hakki IADE EDILMEZ** (uretim gercekten
  para harcadi); yalniz DEPOLAMA iade edilir — aksi halde "begenene kadar
  sinirsiz deneme" olurdu.
- ⚠️ **TURU 79b — `GorselAcik()` HICBIR SEY OLCMUYORDU** (deploy sonrasi kendi
  yakaladigim hata): `gorselKaydet != nil` kontrolu YAPISAL OLARAK her zaman
  true, cunku `mediaH.AIGorseliKaydet` bir **METOT DEGERIDIR**. R2 kapali bir
  kurulumda dugme cizilir, kullanici basinca hata alirdi.
  FIX: `medyaAcik func() bool` = `mediaH.Enabled`.
  ⚠️ **DERS: bir yetenegi "geri cagirim nil mi" ile yoklama — metot degeri ise
     HICBIR SEY OLCMEZ. Gercek durumu SORAN bir fonksiyon iste.**
- 📌 **TURU 79 — UCTAN UCA 148 -> 150; URETIM CAGRILMIYOR (bilincli).** Uretim
  her surumde kosulsaydi her e2e calistirmasi PARA harcar ve kullanicinin gunluk
  gorsel kotasindan duserdi. Onun yerine BAGLANTI ve KAPILAR ucretsiz yollardan
  dogrulaniyor + **`/ai/urun-metni` GORSEL kotasini YEMIYOR** (regresyon kaniti:
  metin 20->19, gorsel 10->10). Gercek uretim ELLE: `scratchpad/gorsel_test.js`.
- **ONCEKI (9 Agu 16:33): TEST TURU 78 YAYINLANDI** — android 31315541995 +
  ios 31315543585 (**7240bfb**), R2 apk=115648043 (md5 2911b24e) ipa=23723742
  (md5 99442aaf), purge OK, **CDN BIREBIR** (apk + ipa + index.html UCU DE MD5
  esit), indir sayfasi 16:33 (saat 5 yerde + **canli saat**), debug imza YOK,
  iOS min 16.0 dogrulandi, surum 1.0.127 build 127, **BACKEND DEPLOY EDILDI**
  (7240bfb; migration 032-037; `ai: aktif (gpt-4o-mini)` + `medya: aktif (R2)`)
  + health ok, DB temiz. ✅ **CANLI SUNUCUDA 144/144 UCTAN UCA GECTI.**
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 78b — ILK BUILD (79466d9) ALINDI AMA YAYINLANMADI.** Yayin oncesi
  adversaryal denetim (7 mercek + curutucu dogrulama, 35 ajan) **27 BULGU**
  buldu, **27'si de DOGRULANDI, 0 curutuldu**; hepsi duzeltilip build YENIDEN
  alindi. *"build ALMAK yayinlamak DEGILDIR"* dersinin **DORDUNCU** dogrulanmasi.
- ⚠️⚠️⚠️ **TURU 78b — `erisebilir()`DE GRUP SOHBETI AVATARI DALI YOKTU (SEVK
  ENGELI).** `chats.avatar_media_id` migration **024**'ten beri VAR ve grup
  olusturma ekrani onu DOLDURUYOR — ama dal HIC YAZILMAMISTI. Tum migration'lar
  tarandiginda **TEK KARSILIKSIZ MEDYA SUTUNU** buydu. Grubu KURAN fotografi
  gorur (kapi `sahip != userID` ile KISA DEVRE); gruptaki **DIGER HERKES**
  sohbet listesinde, baslikta ve grup bilgisinde KIRIK GORSEL gorurdu.
  Turu 75b (akis) · 77 (hikaye) · 78 (kapak) ile AYNI sinifin **DORDUNCU** tekrari.
  FIX: (i) dali, gorunurluk kurali **UYELIK** (kanal gibi "herkese acik" DEGIL).
  ⚠️ `medyayiKopar` referans sayimi da `users.kapak_media_id` ve
     `chats.avatar_media_id`i SAYMIYORDU -> paylasilan medya kopariliyordu.
  ⚠️ **YENI BIR MEDYA SUTUNU EKLERKEN UCUNU BIRLIKTE GUNCELLE:** `erisebilir()`
     dali · `medyayiKopar` sayimi · uctan uca kontrolu.
- ⚠️⚠️ **TURU 78b — VERI SILME: "AYNI KURALIN IKI KOPYASI DRIFT EDER" (iki yer).**
  · `isletme_duzenle`: turu 77b `_yuklemeHatasi` kapisini YALNIZ `catch` daline
    koymus, KARDES DAL (`id.isEmpty`) acik kalmisti. `/users/me` bir kez hata
    verirse `FutureProvider` hatayi KALICI onbellekler -> form BOS acilir,
    Kaydet ETKINDIR, kosulsuz `ON CONFLICT DO UPDATE` adres/il/ilce/web'i BOSA
    CEKER ve kategori 'yemek'e duser (**bir KUAFOR sessizce "Yemek" olur**).
  · `profil_duzenle`: profil yuklenemezse Kaydet `PATCH {name:''}` gonderip
    **GORUNEN ADI SILIYORDU**. FIX: `_dolduruldu` kapisi.
  ⚠️ Ikisinde de cozum `.future` ile BEKLEMEK + hata ekrani.
- ⚠️⚠️ **TURU 78b — AI MENUSU DORT AYRI YERDEN KIRIKTI:**
  · **"0 URUN EKLENDI"**: onizleme tip korumali (turu 77b), KAYDETME yolu ciplak
    `as num?` ile kalmisti ve `catch(_){}` yutuyordu. Model `"1250"` (METIN)
    dondurunce diyalog DOGRU gosteriyor, kaydetme HEPSINI atliyordu.
    FIX: `_kurusOku` **TEK KAYNAK**. ⚠️ YAPMA: iki yolda ayri ayristirma yazma.
  · **BEKLEME DIYALOGU KATALOG EKRANINI KAPATIYORDU**: `barrierDismissible:false`
    YALNIZ perdeyi engeller; **ANDROID GERI TUSU diyalogu YINE DE pop eder**,
    `diyalogAcik` yalanci kalir ve basari dalindaki kosulsuz `pop()` bir ustteki
    ekrani kapatirdi. FIX: `PopScope(canPop:false)` + `whenComplete` +
    `_BeklemeKapisi`. ⚠️ YAPMA: bayragi elle yonetmeye donme.
  · **ISTEMCI 20 sn'DE VAZGECIYORDU** (sunucu 60 sn'ye izin veriyor): kota
    rezervasyon yuzunden YANIYOR, sonuc URETILIYOR ama KAYBOLUYORDU.
    FIX: AI uclarina 90 sn. ⚠️ Sunucu tavani degisirse BURASI DA degismeli.
  · `aiDurumProvider` tek gecici ag hatasinda `acik:false`u SUREC OMRU BOYUNCA
    onbellekliyordu -> AI ozelligi uygulama yeniden baslatilana kadar KAYBOLUR,
    kurtarma yolu da YOKTU. FIX: hata onbelleklenmez (`invalidateSelf`).
- ⚠️⚠️⚠️ **TURU 78b — SESI ACILAN VIDEO DEFTERE GIRMIYORDU (SEVK ENGELI).**
  `_oynat()`in serhi *"ses acilinca `_sesiCevir` yeniden kaydolur"* diyordu ama
  **GOVDEDE O SATIR YOKTU** (CLAUDE.md turu 74 dersi). Galerilerdeki TUM videolar
  SESSIZ baslar; kullanici sesi acinca video SESLI calar ama `SesNotuKontrol`
  defterinde KAYITLI DEGILDIR -> **GELEN ARAMA O SESI SUSTURAMAZ.** Turu 78
  ilan + etkinlik galerileriyle bu yuzeyi IKIYE KATLADI.
  FIX: `_defteriGuncelle()` **TEK KAYNAK**, hem `_oynat` hem `_sesiCevir`ten.
- ⚠️⚠️ **TURU 78b — `ref.read` YUKLEME AWAIT'LERININ ALTINDAYDI** (ilan ·
  etkinlik · urun · iki AI yolu). Bu ekranlarda `PopScope` YOK; kullanici
  kaydetme surerken geri basarsa State DISPOSE olur, `ref.read` `StateError`
  firlatir, `catch` yutar: **medya R2'ye YUKLENIR ama POST HIC ATILMAZ.**
  Turu 77b'nin HIKAYE hatasinin birebir aynisi; duzeltmesi `story_seridi.dart:122`
  de duruyordu ve yeni ekranlar dersi TEKRARLADI.
  ⚠️ Servis yakalandigi icin is artik kullanici ekrandan ciksa bile TAMAMLANIR.
- ⚠️ **TURU 78b — DUZENLEME SERITLERI VIDEOYU KIRIK CIZIYORDU.** `_mevcutMedya`
  duz `List<String>`ti, `mediaKinds` ATILIYORDU -> video id'si `MedyaGorsel`e
  gidiyor ve kullanici **videosunu bozuk sanip SILEBILIYORDU**. FIX:
  `MedyaKucukResmi` + `_mevcutTurler` (ilan + etkinlik). ⚠️ IKI LISTE BIRLIKTE
  degisir (ekleme/silmede ikisine de dokun).
- ⚠️ **TURU 78b — GALERI VIDEOSU: rota kapisi YOKTU + `dongu` varsayilani TRUE**
  -> uste ekran acilinca ALTTA SONSUZ DONGUDE caliyordu. FIX: `_kapiyiYokla`
  icine `ModalRoute.isCurrent` kapisi (akistaki dort kapidan biri) + `dongu:false`.
  ⚠️ `MedyaSecici.videoSuresi` de `donanimSerbest` KAPISIZ oynatici kuruyordu —
  `mixWithOthers:true` **"oturumu ELE GECIRME"** demek, "HIC DOKUNMA" DEMEK DEGIL.
- ⚠️ **TURU 78b — ILAN DUZENLEMEDE TIPE OZEL METIN ALANLARI BOS ACILIYORDU.**
  `TextField`in `initialValue`u YOKTUR ve controller da verilmemisti: SECIM
  alanlari DOLU, Marka/Model/Yıl/Km/Metrekare BOS geliyordu (mansett ozellik
  yarim). FIX: `TextFormField` + `initialValue`. ⚠️ `ValueKey` ZATEN VAR ve
  ZORUNLU (`FormField.didUpdateWidget` `initialValue` degisimini YOK SAYAR —
  turu 77b hayalet-veri hatasi).
- 📌 **TURU 78b — DIGER KAPATILANLAR:** `VitrinSlider` `didUpdateWidget` yoktu
  (kategori degisince BAYAT kaliyor, slayta dokununca YANLIS kayda gidiyordu) ·
  "Satıcıya mesaj" cift dokunma korumasizdi · istemci `enlem/boylam`i HER
  ISTEKTE 0 gonderip sunucudaki `COALESCE` korumasini ATIL birakiyordu ·
  Reels sure uyarisi `inMinutes` TAM SAYI bolmesi yuzunden 90 sn icin
  "1 dakika" diyordu · medya kaldirma dugmesi 17x17 dp idi (Material 48/Apple 44)
  · `MedyaSecici.video` secici patlarsa SESSIZCE oluyordu · `bas_min`/`bas_maks`
  OLU YETENEKTI -> **"Bugün" / "Bu hafta sonu"** hizli kartlari eklendi.
- 📌 **TURU 78b — UCTAN UCA 140 -> 144 (GRUP AVATARI).** ⚠️ Son iki kontrol
  BIRLIKTE bir **KANIT**: B ile C arasindaki TEK fark sohbet UYELIGIDIR; B'nin
  200, C'nin **403** almasi erisimi verenin YALNIZCA yeni (i) dali oldugunu
  gosterir. Bu sinif **ancak IKI HESAPLA** yakalanir.
- 📌 **TURU 78b — INDIR SAYFASI ARACLARI REPOYA TASINDI: `tools/indir/`.**
  Kullanici IKI AYRI TURDA "saati goremiyorum" dedi; dosyalar scratchpad'de
  oldugu icin her oturum yeniden yaziliyor ve muhafizlar da yeniden kuruluyordu.
  Uretici; saat 5 yerden azsa · canli saat kaybolmussa · `?v=` yoksa · body'ye
  flex ortalama geri gelmisse · gorunen metinde emoji kalmissa **DERLEMEYI
  DURDURUR**. ⚠️ Yeni surumde `YENI_ICERIK` blogu ile onu dogrulayan
  `'turu NN icerigi yazilmadi'` satiri **BIRLIKTE** guncellenir.
- **ONCEKI (9 Agu 15:10):** TURU 78 KODU BITTI, BACKEND DEPLOY EDILDI
  (**fe104a8**; migration **032-037** uygulandi; `ai: aktif (model gpt-4o-mini)` +
  `medya: aktif (R2)`) + health ok, DB TRUNCATE edildi (7 tablo 0).
  ✅ **CANLI SUNUCUDA 140/140 UCTAN UCA KONTROL GECTI** (`node tools/uctan_uca.js`,
  IKI AYRI HESAPLA). **BUILD ALINMADI — KULLANICIYA SORULACAK (kural 0).**
- ⚠️⚠️⚠️ **TURU 78 — `Profile()` KAPAK/ONAYLI ALANLARINI YANIT HARITASINA KOYMUYORDU
  (SEVK ENGELI).** Sutunlar SELECT ediliyor, `rows.Scan(&u.KapakMediaID, &u.Onayli)`
  kosuyordu — ama yanit `map[string]any{...}` ELLE kuruluyor ve iki alan oraya
  YAZILMAMISTI. Derleyici goremez (Scan'in yan etkisi var, degisken "kullaniliyor").
  Sonuc: **kapak HICBIR PROFILDE gorunmez, onayli rozeti HIC cizilmezdi** —
  kullanicinin ACIKCA istedigi iki sey.
  **KALICI MUHAFIZ: `internal/users/profil_yanit_test.go`** — `Profile()`in `&u.Alan`
  taramalarini ayristirir, her birini `userResp` JSON etiketine cozer ve o etiketi
  yanit haritasinda ARAR. Muhafizin calistigi, duzeltme GERI ALINIP test KIRMIZIYA
  dusurulerek KANITLANDI.
  ⚠️ YAPMA: bu testi silme; `Profile()`e yeni sutun eklerken SELECT + Scan + yanit
  haritasi UCUNU BIRLIKTE guncelle. (`sutun_test.go` ailesinin kardesi.)
- ⚠️⚠️ **TURU 78 — CHECK CONSTRAINT TUZAGI IKI KEZ (SEVK ENGELI).**
  `media_assets.kind` `'kapak'` KABUL ETMIYORDU -> presign HER SEFERINDE 500 =
  kapak ozelligi **%100 OLU DOGARDI**. `ai_istekleri.durum` da `'iptal'` kabul
  etmiyordu. `go build` + `go vet` + `flutter analyze` UCU DE TEMIZ; hata YALNIZ
  gercek Postgres'te cikar. Migration **036** (durum) + **037** (kind).
  ⚠️ **DERS: yeni bir `kind`/`durum`/`tur` DEGERI eklerken once CHECK'i ac.**
- ⚠️⚠️ **TURU 78b — `PUT /users/me/isletme` HER SEFERINDE 500 (KENDI FAZ 0
  REGRESYONUM).** Koordinatlar ISARETCI yapildi ("gonderilmedi" != "0") ve UPDATE
  dali dogru kuruldu — **INSERT dali ATLANDI**. Istemci enlem/boylam HIC gondermedigi
  icin pgx `nil`i SQL NULL'a cevirdi, sutun NOT NULL: `SQLSTATE 23502`. Buna bagli
  **ALTI kontrol daha** coktu (isletme detayi, rehber, `hesap_turu`, urun ekleme,
  katalog, urun medyasi).
  ⚠️ CLAUDE.md'de defalarca yazili **"nil -> SQL NULL"** sinifini KENDI DUZELTMEMDE
  tekrarladim. Statik denetim GORMEDI; **UCTAN UCA TESTI YAKALADI** — surum
  rutinindeki "deploy sonrasi e2e" adimi bu yuzden ZORUNLU.
  FIX: INSERT'te `COALESCE($9,0)`; ON CONFLICT dalindaki COALESCE eski degeri KORUR.
- 📌 **TURU 78 — `etkinlik_kadro`DA MEDYA SUTUNU YOK (bilincli).** Sanatci fotografi
  `media_assets`e baglansaydi `erisebilir()` icine YENI BIR DAL gerekirdi; o dal
  unutuldugunda **yukleyenden baska HERKESE 403** donerdi (turu 75b + 77'de SAHAYA
  CIKTI). Kadro simdilik ad + rol. `user_id` **NULLABLE** — unluler kayitli degil.
  ⚠️ **KAYITLI kisinin adi SUNUCUDAN alinir**, istemcinin gonderdigi ad YOK SAYILIR
  (kimlik taklidi kapisi); e2e "SAHTE AD" gondererek dogruluyor.
- 📌 **TURU 78 — `reklamlar` TABLOSU ACILMADI (icerigini girecek YOL YOK).**
  Odeme yok · isletme hesabi sayisi SIFIR · **admin panelinden GORSEL YUKLENEMEZ**
  (admin uclari `?key=` ile JWT grubunun DISINDA, presign ICINDE -> onay kuyrugu
  yalnizca bir UUID LISTESI olurdu = KOR ONAY). Slider ORGANIK vitrinden beslenir
  (`/vitrin?dikey=`); odeme gelince tablo BU UCUN ARKASINA eklenir ve **istemci
  sozlesmesi DEGISMEZ**. ⚠️ Vitrin ilk **FOTOGRAFI** secer, ilk medyayi DEGIL
  (video olsaydi slider'da KIRIK GORSEL cizilirdi).
- 📌 **TURU 78 — `chats.ilan_id` (032) EKLENDI ama `type` HALA `'direct'`.**
  Kisisel sohbetin ilan sohbetine DUSMEMESI icin tum dogrudan-sohbet SQL'i TEK
  KAYNAGA alindi: **`internal/sohbet/direkt.go`** (`ilan_id IS NULL` yuklemi orada).
  ⚠️ YAPMA: yuklemi cagiran yerlere elle kopyalama (drift eder — turu 75b/H dersi).
  Kendi ilanina mesaj 400; ayni ilan icin ikinci cagri AYNI satiri doner.
- 📌 **TURU 78 — KALDIRMA NOBETCISI: BOS DIZE = SIL.** `null` "degistirme" demektir;
  ikisi ayrilmadan `kapak_media_id` / etkinlik `bitis` alani TEMIZLENEMEZ.
- ⚠️ **TURU 78 — UCTAN UCA 104 -> 140 KONTROL.** Turu 78'in sekiz fazi icin **36 yeni
  kontrol**; oncesinde bu fazlarin HICBIRI otomatik dogrulanmiyordu. En kritikleri:
  profil ucunun kapagi **yanit haritasinda** dondurmesi · `kind='kapak'` presign'in
  CHECK'ten gecmesi · kapagin **IKINCI HESAPTA** acilmasi · sadece `durum`
  degisiminin `duzenlendi_at` damgasini **DEGISTIRMEMESI** · kisisel sohbetin ilan
  sohbetine **DUSMEMESI** · kadroda **ad'in SUNUCUDAN** gelmesi.
- ⏳ **TURU 78 — DURUST SINIRLAR (yapilmadi, sebebiyle):** HARITA ve "yakinimda"
  YOK — `isletmeler.enlem/boylam` VAR ama **hicbir kayitta DOLU DEGIL** ve
  dolduracak arayuz yok; harita bos tuval olurdu. Once koordinat girisi lazim.
  Kartlar bugun calisan olcutlerle (onayli, yeni) besleniyor. **AI ile GORSEL
  URETME yok** — yalniz metin -> menu.
- 🔑 **BEKLEYEN:** kullanici OpenAI anahtarini sohbete yazdi ve "calistirdiginizda
  degistirecegim" dedi. Anahtar sunucuda CALISIYOR (canli test: metin -> 5,7 sn'de
  gecerli Turkce JSON menu, kota 20->19) -> **ARTIK DONDURULMELI.**
- 📌 **MIGRATION NUMARALARI (guncel):** 032 = `chats.ilan_id` · 033 = kapak + onayli ·
  034 = `ilanlar.duzenlendi_at` · 035 = `etkinlik_kadro` · 036 = `ai_istekleri.durum`
  CHECK · 037 = `media_assets.kind` CHECK. Sonraki **038**'den.
- **KALDIGIMIZ YER (9 Agu 06:40): TEST TURU 77 YAYINLANDI** — android 31292449948 +
  ios 31292451069 (fd5fbaa), R2 apk=115303523 (md5 685c27b1) ipa=23688271
  (md5 19616914), purge OK, **CDN BIREBIR** (apk + ipa + index.html MD5 esit),
  indir sayfasi 06:40 (saat **5 yerde + canli saat**), debug imza YOK,
  iOS min 16.0 dogrulandi, **BACKEND DEPLOY EDILDI** (fd5fbaa; migration
  **027-031** uygulandi, "medya: aktif (R2)", "ai: KAPALI" beklenen) + health ok,
  DB temiz (0/0/0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 105/105 UCTAN UCA KONTROL GECTI** (duzeltmelerden SONRA tekrar).
  ✅ **171 ROTA CAKISMASIZ** + turu 77 uclari dogru cozuluyor.
  **KULLANICI TEST EDECEK.**
- **ONCEKI ADIM:** TURU 77 — 6 YENI DIKEY + 77b DENETIMI.
  Kullanici emri (uyurken, ONAYSIZ ILERLEME ACIKCA ISTENDI): hikaye editoru ·
  isletme profilleri · etkinlikler · ilanlar (sahibinden) · hizmetler · isletme
  urunleri + AI. ⚠️ **CLAUDE.md kural 0 (build oncesi sor) BU TUR ICIN ASKIYA ALINDI**
  — kullanici *"durma sakin hepsini bitirene kadar"* dedi.
- ⚠️⚠️ **GO TESTLERI 3 TURDUR KOSTURULAMIYORDU — KOK NEDEN BULUNDU.**
  Windows Application Control, `go test`in VARSAYILAN gecici dizinde
  (`%LOCALAPPDATA%\Temp`) urettigi YENI ikilileri engelliyor; sunucuda da Go
  KURULU DEGIL (yalniz Docker derlemesi). Yani `internal/rota/rota_test.go`
  **HICBIR ORTAMDA** kosmamisti. COZUM: `GOTMPDIR="$(pwd)/.gotmp" go test ./...`
  (proje dizinindeki ikili engellenmiyor). `.gotmp/` gitignore'da.
  ⚠️ YAPMA: bir daha "test kosturulamiyor" diye gecme.
  SONUC: **171 rota cakismasiz** + turu 77'nin 33 yeni yolu dogru cozuluyor;
  `sutun_test.go` (7 sorgu SELECT-vs-Scan) da gecti.
- 📌 **MIGRATION NUMARALARI (guncel):** 027 = hikaye editoru (`stories.katmanlar`
  JSONB + `arka_plan` + `media_id` NULL olabilir), 028 = `users.hesap_turu` +
  `isletmeler`, 029 = `etkinlikler` + `etkinlik_katilim`, 030 = `ilanlar` +
  `ilan_favoriler`, 031 = `isletme_urunleri` + `ai_istekleri`. Sonraki **032**'den.
- ⚠️⚠️⚠️ **TURU 77 — AI KAPISI: `OPENAI_API_KEY` (R2 KALIBININ AYNISI).**
  Anahtar YOKSA `Acik()` false, uclar **503**, ve **istemci ozelligi HIC CIZMEZ**
  (`GET /ai/durum`). Acilista log: `ai: OPENAI_API_KEY yok — AI KAPALI`.
  ⚠️⚠️ **TURU 75'IN TEKRARI RISKI:** R2 anahtarlari sunucudaki `.env`e yazilmis
  ama `docker-compose.yml`in **`environment:` blogu** guncellenmemis ve medya
  SESSIZCE KAPALI kalmisti (/health "ok" donuyordu!). `OPENAI_API_KEY` compose'a
  ONCEDEN eklendi. ⚠️ YAPMA: yeni env'i yalniz `.env`e yazip birakma.
- ⚠️⚠️⚠️ **TURU 77b — SES SAHIPLIGI PING-PONG'U (SEVK ENGELIYDI, EN AGIR).**
  `SesNotuKontrol` **TEK SLOTLUDUR** (yeni sahip oncekini SUSTURUR) ama
  `MedyaVideo._oynat()` **SESSIZ** akis videolarinda bile KOSULSUZ kaydoluyordu.
  Akista bir video gorunurken Reels'e gecince Reels ~1sn oynayip DONUYOR
  (akistaki 1sn'lik `_kapiYoklama` sahipligi geri caliyor); ayni sekilde VIDEO
  HIKAYE ve **turu 74'te test edilip ONAYLANMIS SESLI MESAJ** susup basa donuyordu.
  Reels'te `kontrolGoster:false` oldugu icin kullanicinin duzeltme yolu da YOKTU.
  FIX: (a) deftere YALNIZ `_sesVerilebilir` ise girilir, (b) susturma SEBEBI
  ayrilir — `_aramaDurdurdu = !MedyaKapisi.donanimSerbest(ref)`.
  ⚠️ YAPMA: kosulsuz `kaydol`a donme; iki sebebi tek bayrakla temsil etme.
- ⚠️⚠️ **TURU 77b — AKIS VIDEOSU ARTIK DORT KAPILI.** `IndexedStack` secili
  OLMAYAN cocuklari da CANLI + LAYOUT EDILMIS tutar; sekme degisimi kaydirma
  uretmedigi icin gorunurluk gozcusu de yeniden olcmuyordu (ustelik Stack hepsini
  AYNI konuma koydugu icin gozcuyu duzeltmek TEK BASINA yetmezdi). Kapilar:
  `_gorunurOran>=0.6` · `_sayfa==sira` · **`aktifSekme==0`** ·
  **`ModalRoute.isCurrent`**. ⚠️ YAPMA: dortten birini kaldirma.
- ⚠️⚠️⚠️ **TURU 77b — HIKAYE CIZIM SOZLESMESI: TUVAL **SABIT 9:16**.**
  Onceki surumde hem editor hem izleyici katmanlari **EKRANIN TAMAMINA** gore
  konumluyordu. Ikisi ayni ekranda ayni sonucu verdigi icin **TEK CIHAZDA TEST
  EDILSE GORULMEZDI** — ama medya `contain` cizildigi icin fotografin kapladigi
  dikey oran EKRAN EN-BOYUNA gore degisiyor: ayni hikaye 390x844 ile 360x640
  arasinda fotografa gore **~%19 kayiyordu**; ucta yazi letterbox bandina dusuyordu.
  · `StoryTuvali` — medya DA katmanlar DA ayni 9:16 dikdortgene cizilir.
  · `storyKatmanGovdesi()` + `storyKatmanYerlestir()` **TEK KAYNAK** (eskiden
    editor kendi sarmalayicisini yazmisti: kutu acikken metin tavani 350 vs 338 ->
    editorde tek satira sigan cumle izleyicide IKI SATIRA sariyordu).
  · Editorun secim cercevesi **`foregroundDecoration`** — `border`/`padding`
    YERLESIMI DEGISTIRIR ve kaymayi geri getirir.
  · Konum `Align` DEGIL **`Positioned` + `FractionalTranslation(-0.5,-0.5)`**:
    `Align` cocugu `(alan-cocuk)*x`e koyar, metin sarip genisleyince hareket alani
    sifira gider ve **YATAY SURUKLEME SESSIZCE OLURDU**.
  ⚠️ YAPMA: tuvali `MediaQuery.size`a baglama; `Align`e donme; editorde ayri
    govde yazma.
- ⚠️⚠️ **TURU 77b — HIKAYE YUKLEMESI SESSIZCE IPTAL OLUYORDU** ("paylastim
  sandim, gitmemis" — dosyanin KENDI serhinin engellemeye calistigi senaryo).
  Serit bir `ListView` OGESI ve `AutomaticKeepAliveClientMixin` KULLANMIYORDU;
  akis ~356px kaydirilinca State dispose oluyor, `ref.read` `StateError` atiyor,
  `catch` + `if(!mounted) return` mesaji da yutuyordu. Medya R2'ye yukleniyor,
  `POST /stories` HIC ATILMIYOR, medya yetim kaliyordu.
  FIX: servisler TUM await'lerden ONCE yakalanir (turu 67 dersi) + KeepAlive +
  mesajlar `rootMessengerKey`ten. ⚠️ YAPMA: `ref.read`i await'lerin altina tasima.
- ⚠️⚠️⚠️ **TURU 77b — GIZLILIK: AI UCU MEDYA SAHIPLIK KAPISINI ATLIYORDU.**
  `media.ImzaliAdres(ctx, mediaID)` imzasi userID TASIMIYORDU, yani yapisal olarak
  sahiplik kontrolu YAPAMAZDI; govde yalniz `status`a bakiyordu. Ustundeki yorum
  *"cagiran yetkiyi kendisi dogrulamis olmali"* diyordu ama AI paketinde O
  DOGRULAMA YAZILMAMISTI. Elinde herhangi bir `media_id` olan biri
  `POST /ai/danisma` ile fotografin ICERIGINI okutabilirdi; AYNI id ile
  `GET /media/{id}/url` **403** donuyordu -> `erisebilir()`in TUM dallari (gizli
  hesap, engelleme, "herkesten silinmis" mesaj medyasi, 24 saati gecmis hikaye)
  tek seferde deliniyordu. Bu surumde INERT'ti (anahtar yok) ama anahtar eklendigi
  GUN aktif olacakti. FIX: `(ctx, mediaID, sahipID)` + `AND owner_id=$2` — yetki
  argumani artik TIP SISTEMINDE gorunuyor, vermeden DERLENMEZ.
  📌 CLAUDE.md turu 74 dersinin tekrari: **bir yorumun anlattigi kontrolun GOVDEDE
     gercekten olup olmadigini dogrula.**
- ⚠️⚠️ **TURU 77b — AI KOTASI FIILEN YOKTU.** `kapi()` `SELECT count(*)` okuyor,
  sayaci artiran `kaydet()` ise OpenAI cagrisi DONDUKTEN SONRA (60sn'ye kadar)
  kosuyordu; 100 escamanli istek 100'u de `count=0` gorup FATURALANIRDI.
  FIX: cagridan ONCE atomik rezervasyon
  (`INSERT ... SELECT ... WHERE (count) < kota RETURNING id`), sonuc `UPDATE`.
  Sayim `durum <> 'iptal'` (zaman asimina ugrayan istek de faturalanmis olabilir).
  ⚠️ YAPMA: sayimi `kaydet` icine geri koyma.
- ⚠️⚠️ **TURU 77b — VERI KAYBI: `isletme.detay()` HER hatayi yutup `null`
  donuyordu.** "Isletme degil (404)" ile "ag hatasi" ayirt edilemiyordu; ekran BOS
  aciliyor, kullanici tek alan doldurup kaydediyor ve sunucudaki `ON CONFLICT DO
  UPDATE` MEVCUT adres + telefon + 7 gunluk calisma saatlerini BOSA CEKIYORDU.
  FIX: 404'te `null`, digerlerinde FIRLAT; hata dalinda form CIZILMEZ + Kaydet YOK.
- 📌 **TURU 77b — DIGER KAPATILAN BULGULAR (hepsi "olu ozellik" ya da drift):**
  · Metin hikayesinde **zemin secici ULASILAMAZDI** (`_panel` otomatik 'yazi'ya
    geciyordu) — gradyan seridi HIC cizilmiyor, zemin 'mor'da kilitli kaliyordu.
  · `aci` (dondurme) modelde/JSON'da/sunucu kirpmasinda/cizimde VARDI ama ONA
    YAZAN SATIR YOKTU — iki parmak jesti eklendi.
  · Video hikayede oynaticinin tam ekran `GestureDetector`i jest arenasinda
    kazanip ILERI/GERI dokunusu YUTUYORDU -> `kontrolGoster:false`.
  · Ilan formunda **hayalet veri**: dinamik alanlar `key`siz oldugu icin tur
    degisince element yeniden kullaniliyor, `FormField.didUpdateWidget`
    `initialValue` degisimini YOK SAYIYOR -> "Metrekare" kutusunda "Ford"
    gorunuyor, `_ozellikler` bos, ilan EKSIK yayinlaniyordu.
    FIX: `ValueKey('$_tur:${a.anahtar}')`.
  · **`pickMultiImage(limit:1)` `ArgumentError` FIRLATIR** ("cannot be lower than
    2") ve UC ekranda `catch` yutuyordu: tavanin bir altinda "Fotoğraf ekle"
    SESSIZCE OLUYORDU. Ayrica `limit` platformlarca YOK SAYILABILIR -> 30
    secilirse 18 YETIM yukleme. FIX: `MedyaSecici.coklu()` + `take(kalan)`.
  · Ilan goruntulenme sayaci sahada HEP 0 (turu 76'nin gonderi hatasinin birebir
    tekrari) · "İlanlarım" HERKESIN ilanini aciyordu · urun "Tükendi" olu
    ozellikti (sunucu kabul ediyor, rozet ciziliyor, istemci HIC gondermiyordu).
  · Bos akista Android'de asagi-cek-yenile CALISMIYORDU
    (`AlwaysScrollableScrollPhysics` yok + IndexedStack canli tutuyor) — YENI
    kullanici uygulamayi oldurmeden akisini tazeleyemiyordu.
- ⚠️ **TURU 77b — ELENEN ALARM (kaynaktan curutuldu):** "urun medyasinda engelleme
  calismiyor; `blocks` kullanici id'siyle `p.isletme_id` karsilastiriliyor" iddiasi
  **YANLIS** — `isletme_urunleri.isletme_id UUID REFERENCES users(id)`, yani zaten
  kullanici id'si. ⚠️ Bunu bir daha "olasi risk" diye yazma.
- 📌 **TURU 77 — INDIR SAYFASI SAATI ALTI YERDE (kullanici ikinci kez "goremiyorum"
  dedi).** Sunucu tarafi DOGRUYDU: `no-cache, no-store, must-revalidate` +
  `cf-cache-status: DYNAMIC` + cubuk en ustte + turu 50'nin flexbox fix'i duruyor.
  Geriye kalan tek aciklama TARAYICI ONBELLEGI. Saat artik: `<title>` · mor serit ·
  **saniyesi AKAN CANLI SAAT** (sayfanin bayat olmadigini KANITLAR) · iki indirme
  dugmesinin ICI · dosya satiri. Uretici yer tutucu tabanli ve saat 5 yerden azsa
  **derlemeyi DURDURUR**. ⚠️ YAPMA: canli saati kaldirma; body'ye flex ortalama koyma.
- **ONCEKI (9 Agu 03:50):** TEST TURU 76b YAYINLANDI — android 31286588553 +
  ios 31286593307 (**751c5fc**), R2 apk=113053743 (md5 053f2e3e) ipa=23397403
  (md5 6079c71d), purge OK, **CDN birebir** (apk + ipa + index.html MD5 esit),
  indir sayfasi 03:50 (saat 3 yerde), debug imza YOK,
  **BACKEND DEPLOY EDILDI** (d0328a6; migration **026** uygulandi) + health ok,
  DB temiz (0/0/0/0/0).
  ✅ **CANLI SUNUCUDA 65/65 UCTAN UCA KONTROL GECTI** — `node tools/uctan_uca.js`.
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 76b — GALERI KAYDIRMASI YANLIS YASLANIYORDU (build ONCESI yakalandi).**
  Ilk surumde `ListView` + `PageScrollPhysics` kullanilmisti. O fizik sayfa
  genisligini **VIEWPORT'UN TAMAMI** sanar; ogeler ekranin %78'i oldugu icin
  yaslanma her ogede biraz daha kayar ve **ucuncu-dorduncu medyada tamamen bozulur**.
  FIX: `PageView.builder` + `viewportFraction: 0.78` + **`padEnds: false`**.
  ⚠️ `padEnds: false` ZORUNLU — varsayilan `true` sayfayi ORTALAR ve ILK medyanin
  SOLUNDA bosluk birakir; Threads/Instagram'da ilk medya SOLA DAYALIDIR.
  ⚠️ `PageController` **initState**te kurulur (build icinde kurulsaydi her cizimde
  yeni controller olusur ve kaydirma konumu SIFIRLANIRDI) ve dispose edilir.
  ⚠️ YAPMA: `ListView` + `PageScrollPhysics`e geri donme.
  📌 **SUREC:** ilk build (8a47ca3) **YAYINLANMADI**, bulgu sonrasi IPTAL edilip
  yeniden alindi — *"build ALMAK yayinlamak DEGILDIR"* (turu 59b dersi, ucuncu tekrar).
- ⚠️⚠️ **TURU 76b — "GRUP OLUSTURMA NEREDE?" IKI KOK NEDEN.**
  (1) Alt menude **IKI TANE "+"** vardi ve FARKLI IS YAPIYORLARDI: ust (AppBar)
  dogrudan kisi aramaya gidiyordu (grup secenegi YOK), alt (FAB) ise
  "Yeni sohbet | Yeni grup" sheet'i aciyordu. Ust dugme daha gorunurdu ->
  kullanici "grup yok" sonucuna vardi. **AppBar'daki "+" KALDIRILDI, TEK GIRIS FAB.**
  ⚠️ YAPMA: AppBar'a tekrar "+" ekleme; yeni eylem gerekirse `_yeniSecenek` sheet'ine koy.
  (2) Sunucudaki **UC grup-uye ucu ISTEMCIDEN HIC CAGRILMIYORDU**
  (`GET/POST/DELETE /chats/{id}/members`) -> grup KURULABILIYOR ama uyeleri
  GORULEMIYOR, uye EKLENEMIYOR/CIKARILAMIYORDU. Bu sinifin **BESINCI** tekrari.
  FIX: `chats/grup_bilgi.dart` + sohbet basligina dokunma ("Grup bilgisi icin dokun"
  alt yazisi + chevron). ⚠️ `ChatScreen.isGroup` ACIKCA tasinir (`chat.type=='group'`);
  `peerId==null` varsayimi YEDEK.
- ⚠️⚠️ **TURU 76b — AKISTA OTOMATIK VIDEO (`sosyal/gorunurluk.dart`, HARICI PAKET YOK).**
  Kullanici ekran goruntusu (Threads) gonderdi: galeri **YAN YANA KAYAR**, sonraki
  medya SAGDAN SARKAR (%78 genislik, yuvarlak kose, nokta gostergesi YOK).
  **IKI KAPI birden** saglanmadan video oynamaz: kart ekranda **>=%60 gorunur** VE
  galeride **ORTADAKI oge**. Aksi halde 20 kartin videosu ayni anda calar ->
  isinma + veri + iOS'ta proses-genelinde TEK ses oturumu yuzunden **ARAMA SAGIRLASIR**.
  ⚠️ **SESSIZ baslar** — tercih degil ZORUNLULUK (kaydirirken ses patlatmak
  AVAudioSession'i ele gecirip aramayi bozar). ⚠️ YAPMA: kapilardan birini kaldirma.
  ⚠️⚠️ **SEVK ENGELI (kod okunarak yakalandi):** kart EKRAN DISINDA kuruldugu icin
  `MedyaVideo` `_tembel` moda giriyor ve **oynatici HIC YARATILMIYOR**; gorunur
  olunca `didUpdateWidget` dogrudan `_oynat()` cagiriyordu, `_c` NULL oldugu icin
  **HICBIR SEY OLMUYORDU** = otomatik oynatma sahada HIC CALISMAZDI. FIX: tembel ise `_kur()`.
- 📌 **TURU 76b — ETKILESIM CUBUGU ESITLENDI (kullanici: "ikonlarin hepsi esit
  gorunmeli"):** begeni/yorum/paylas `TextButton.icon` (21px + degisken etiket),
  kaydet ciplak `IconButton` (24px) idi. Hepsi tek `_eylem` bileseni: **SABIT 22px**
  ikon + sabit dokunma alani. "Secili" hali artik BOYUT DEGISTIRMEZ (eskiden 21->23
  buyuyup satiri kaydiriyordu). **ISTATISTIK IKONU cubuga eklendi** — eskiden yalniz
  `•••` menusunun icindeydi, yani pratikte YOKTU (yalniz YAZARA gorunur).
- 📌 **TURU 76b — KANALDA VIDEO + ISTATISTIK.** Eski "kanalda video yok" siniri
  SUNUCU YASAGI DEGILDI: `channel_posts.media_ids` turu tasimiyordu. Gonderi
  tarafiyla AYNI `media_kinds` cozumu uygulandi. Yeni
  `GET /channel-posts/{id}/istatistik` (yalniz yazar + kanal sahibi, baskasina 404).
- ⚠️⚠️⚠️ **TURU 76b — HIKAYE (STORY): "24 SAAT" GORUNURLUKTUR, SILME DEGIL.**
  Alisilmis cozum `expires_at` + supurge ile SILMEK; **bu projede VERI SILINMEZ**
  (kullanici karari 8 Agu). Satirlar KALICI, kaybolma YALNIZCA sorgu suzgeciyle
  (`created_at > now() - interval '24 hours'`). Boylece ileride "hikaye arsivi"
  EK IS GEREKTIRMEZ. ⚠️ YAPMA: `stories`e `expires_at` ekleme; yas tabanli DELETE yazma.
  · migration **026** = `stories` + `story_views` (PK `(story_id,user_id)` -> ayni
    kisi tekrar izleyince YENI SATIR ACILMAZ).
  · 6 uc: `POST/GET /stories` · `GET /stories/{userId}` · `POST /stories/{id}/view`
    · `GET /stories/{id}/viewers` · `DELETE /stories/{id}`.
  · `GET /stories` **KULLANICI BASINA GRUPLU** doner — gruplamayi SUNUCU yapar;
    istemci de yapsaydi "hepsi izlendi" hesabi iki yerde yasar ve DRIFT ederdi.
  · Gizlilik gonderiyle AYNI (gizli hesabi yalniz onayli takipci gorur, engel IKI
    YONLU); izlenme sayisi YALNIZ SAHIBINE; kendi hikayeni izlemek SAYILMAZ.
  · Istemci: serit HER ZAMAN cizilir (hikaye yokken de) — "Hikâyen" halkasi
    ozelligin VARLIGINI ogrenmenin TEK yolu.
  · Video hikaye **SABIT 15 sn**: `MedyaVideo` sureyi disari VERMIYOR; oynaticiya
    gizli kanal acmak yerine durust sabit sure secildi (oynatici zaten kirilgan).
- 📌 **TURU 76b — ANASAYFA SOL UST HAMBURGER (`sosyal/hizmet_menusu.dart`).**
  Kullanici emri: **2 SATIR cizgi** (Lucide `menu` UC cizgidir -> ikon KULLANILMADI,
  cizgiler ELLE cizildi) · kartlar **Yemek/Restoran/Alisveris** · **IKON YOK**,
  yazi KARTIN ALTINDA. Bolumler urun olarak tanimli olmadigi icin durust "yakinda"
  bildirimi gosteriliyor. ⚠️ YAPMA: kartlarin icine ikon koyma; bos ekrana baglama.
- ⚠️ **TURU 76b — UCTAN UCA ARAC 65 KONTROL.** Story SQL'leri (`BOOL_AND` +
  `GROUP BY` + 24sa penceresi) ve kanal `media_kinds` GERCEK POSTGRES'TE ILK KEZ
  kosturuldu. ⚠️ **TEST SIRASI TUZAGI:** engelleme TAKIBI DE DUSURUR ve engel
  kaldirilinca takip GERI GELMEZ; hikaye seridi "takip ettiklerim" uzerinden
  calistigi icin takip geri kurulmadan serit HAKLI OLARAK bos doner.
- **ONCEKI (9 Agu 02:36):** TEST TURU 76 YAYINLANDI — android 31283866106 +
  ios 31283871070 (0eabe4a), R2 apk=112758779 (md5 85765bc9) ipa=23363163 (md5 8ce058e5),
  purge OK, **CDN birebir** (apk + ipa + index.html MD5 esit), indir sayfasi 02:36
  (saat 3 yerde gorunuyor), debug imza YOK, iOS deployment target 16.0 dogrulandi,
  **BACKEND DEPLOY EDILDI** (deb05b2; migration **024 + 025** uygulandi, "medya: aktif (R2)")
  + health ok, DB temiz (0/0/0/0).
  ✅ **CANLI SUNUCUDA 46/46 UCTAN UCA KONTROL GECTI** — `node tools/uctan_uca.js`.
  **KULLANICI TEST EDECEK.**
- 📌 **TURU 76 — UCTAN UCA ARAC GENISLETILDI (`tools/uctan_uca.js`, 46 kontrol).**
  EN KRITIK dogrulama: `media_kinds` alt sorgusu (`unnest ... WITH ORDINALITY` +
  `array_agg`) GERCEK POSTGRES'TE HIC KOSMAMISTI. Tip/sozdizim hatasi olsaydi
  **HER gonderi sorgusu 500 dondururdu** = akis + profil + kesfet + reels +
  kaydedilenler TAMAMEN olu. Statik denetim bunu YAKALAYAMAZ.
  ⚠️ Yeni bir SQL/uc eklerken bu araca da kontrol ekle; calistirdiktan sonra
  **DB'yi TRUNCATE et** (arac gercek hesap + gonderi + medya uretir).
  ⚠️ **DUZELTILEN ESKI VARSAYIM:** "engelden sonra akis TAMAMEN BOS" YANLIS —
  engelleme takibi de DUSURUYOR (turu 75 `Block` -> `takibiKaldir`, iki yonlu),
  kullanici SOGUK BASLANGIC dalina duser ve KESFET doner. Bos DB'de tesadufen 0
  cikiyordu. Dogru olcut: **engellenenin gonderisi YOK**.
- ⚠️⚠️ **TURU 76 — GORUNTULENME SAYACI ANA GIRIS YOLLARINDA HIC ARTMIYORDU**
  (ucuncu denetim bulgusu, build yeniden alindi). Sunucu sayaci YALNIZ
  `GET /posts/{id}` icinde artiriyor; detay ekrani hazir bir `Gonderi` NESNESIYLE
  acildiginda (profil izgarasi, kesfet izgarasi, kaydedilenler — GERCEK giris
  yollarinin COGU) o istek HIC ATILMIYORDU. Kullanicinin ozellikle istedigi
  istatistik pratikte HEP 0 kalirdi. FIX: nesneyle acilista SESSIZ tazeleme.
  ⚠️ `_g` NESNESI DEGISTIRILMEZ, ALANLARI guncellenir — model akis/izgara ile
  PAYLASILIYOR; yeni nesne atansaydi detayda yapilan begeni geri donuldugunde
  izgarada gorunmezdi.
- 📌 **SUREC (turu 59b dersinin tekrari):** ILK build (`deb05b2`) **YAYINLANMADI** —
  ucuncu bulgu build ALINDIKTAN sonra cikti, kod duzeltilip build YENIDEN alindi.
  *"build ALMAK yayinlamak DEGILDIR."*
- **ONCEKI (9 Agu):** TURU 76 — KOD BITTI, 8 FAZ + DENETIM TAMAM, BUILD ALINIYOR.
  Kullanicinin 10 maddelik eksik listesi (test sonrasi) TAMAMEN karsilandi:
  1 anlik mesaj/bildirim · 2 engelleme her yuzeyde · 3 profil fotograflari ·
  4 Instagram etkilesim + istatistik · 5 ALT MENUDE ARAMA (profil arama) ·
  6 grup olusturma · 7 sohbet filtre/arsiv/sil/kaydirma · 8 gonderi duzenleme ·
  9 karma medya galerisi (foto+video) · 10 video 100 MB.
- ⚠️⚠️⚠️ **TURU 76 — DENETIMDE YAKALANAN SEVK ENGELI (build ONCESI):**
  `media_kinds` + `duzenlendi_at` ALTI gonderi sorgusuna eklendi, **YEDINCISI**
  (`Kaydedilenler`, etkilesim.go) ATLANDI -> sorgu 16 sutun donuyor, `satirlariOku`
  18 bekliyordu -> `rows.Scan` hata -> `continue` -> **HER SATIR SESSIZCE ATLANIR**.
  Derleme hatasi YOK, log YOK, olcum YOK: "Kaydedilenler" sayfasi HERKESTE BOMBOS.
  **KALICI MUHAFIZ: `internal/social/sutun_test.go`** — kaynagi okuyup 7 sorgunun
  SELECT sirasini Scan sirasiyla karsilastirir, sorgu SAYISI dususe de uyarir.
  ⚠️ YAPMA: bu testi silme; yeni sutun eklerken sorgu + Scan + `beklenenSutunlar`
  UCUNU BIRLIKTE guncelle.
- ⚠️⚠️ **TURU 76 — SESSIZE ALMA PUSH'TA UYGULANMIYORDU (ikinci denetim bulgusu).**
  FAZ 6 `muted_until`i ekledi, liste ikonu da ciziliyordu; ama bildirim yolu
  `chatMemberIDs` sonucunu OLDUGU GIBI kullaniyordu -> sessize alinan sohbet
  TELEFONU CALDIRMAYA DEVAM EDIYORDU (ozellik "acik" gorunup FIILEN calismiyor —
  turu 74'un "yorumun anlattigi kontrol govdede var mi" dersinin tekrari).
  FIX: `sessizOlmayanlar()`. ⚠️ WS yayini (`To: members`) FILTRELENMEZ — sessize
  alma BILDIRIMI susturur, SOHBETI degil. ⚠️ Rozet sayaci da degismez (WhatsApp
  da sessiz sohbette sayaci gosterir). ⚠️ FAIL-OPEN bilincli.
- ⚠️⚠️ **TURU 76 — KARMA MEDYA GALERISININ KOK NEDENI YAPISALDI.**
  `posts.media_ids` yalnizca UUID diziisiydi; her medyanin FOTO mu VIDEO mu oldugu
  istemciye **HIC DONMUYORDU**. Kart, gonderi seviyesindeki `tur` bayragina bakip
  TUM medyayi ayni cizdigi icin "foto + video ayni gonderide" sunucu izin verse
  bile YANLIS CIZILIRDI. Yeni `media_kinds` dizisi `unnest(...) WITH ORDINALITY`
  ile **SIRA KORUYARAK** doner (`media_kinds[i]` <-> `media_ids[i]`).
  ⚠️ Duz JOIN kullanma — sira GARANTI OLMAZ. ⚠️ Silinmis medya icin `'yok'`
  (NULL DEGIL: `array_agg` NULL uretirse `[]string` taramasi PATLAR ve satir
  SESSIZCE atlanir = akis bosalir).
  ⚠️ **YENI `tur` DEGERI EKLENMEDI**: `tur='foto'` artik "GALERI (1-10 karma
  medya)" demek. `posts.tur` CHECK'ini DROP/ADD etmek 015'te yasanan migration
  tuzagini acar. `video`/`reels` TEK medya olarak KALIR (reels oynaticisi tek
  kaynak varsayiyor).
- ⚠️⚠️ **TURU 76 — REELS SEKMESI `IndexedStack`TE **KOSULLU** KURULUR (SES GUVENLIGI).**
  `IndexedStack` TUM cocuklari agacta CANLI tutar; reels sekmesinden cikinca video
  oynaticisi yasar ve **SES ARKA PLANDA CALMAYA DEVAM EDERDI**. iOS'ta ses oturumu
  PROSES GENELINDE TEK nesnedir (turu 64/65/73'te aramalar tam bu yuzden sagirlasti).
  `_index == _reels ? const ReelsSayfasi() : const SizedBox.shrink()`.
  ⚠️ YAPMA: kosulsuz `ReelsSayfasi()` yapma. ⚠️ Akis AppBar'indaki Reels dugmesi
  KALDIRILDI (ayni ekrana iki giris = push edilen kopya sekme degisince ustte kalir).
- 📌 **TURU 76 — ALT MENU YENIDEN KURULDU:** Anasayfa · Ara · Reels · Mesaj · Canli ·
  Profil. **"Ara" = PROFIL ARAMA** (kullanici: "aramadan kastim normal profil arama
  instagram gibi") — CAGRI GECMISI **SILINMEDI**, `Mesaj` sekmesinin segmentine
  tasindi; SESLI ODALAR da `Canli` segmentine. ⚠️ YAPMA: `CallsTab`/`RoomsTab`i
  kaldirma (`mesgulMu` muhafizlari `oda_`/`yayin_` onlara bagli).
  ⚠️ Akis/Ara/Reels sekmelerinde AppBar YOK -> o ekranlar KENDI `SafeArea`sini
  koymak ZORUNDA.
- 📌 **TURU 76 — AVATAR KOK COZUM: `GET /users/ozet?ids=a,b,c`.** Bir yuzey avatari
  ancak verisi `avatar_media_id` TASIYORSA cizebilir; arama katmani bunu tasimiyordu
  ve **TASIYAMAZDI** (gelen arama VoIP push/CallKit yolundan gelir, orada yalnizca
  kimlik vardir). "Her cagirana avatar alani ekle" o yolda YAPISAL OLARAK cozmez.
  · `POST /calls/{id}/answer` artik `peer_id` doner — gelen aramada TEK guvenilir
    kimlik kaynagi (WS olayi kaybolabilir, CallKit ek alanlari tutarsiz).
  · `IncomingCall.callerId`: sunucu `caller_id`yi ZATEN gonderiyordu, istemci OKUMUYORDU.
  · `medya/kullanici_ozeti.dart`: **40ms toplu istek penceresi** (N+1 YOK — turu 17
    dersi), negatif onbellek, ag hatasinda onbellege YAZMAZ, logout'ta temizlenir.
  ⚠️ `/users/{id}/profile` KULLANILMADI: gizlilik kapisi + takipci sayilari tasiyor;
  arama ekraninin avatari gizli hesapta kaybolamaz. ⚠️ `/users/ozet`te UUID BICIM
  SUZGECI ZORUNLU — tek bozuk deger `= ANY($2)` sorgusunun TAMAMINI 500 yapar.
- 📌 **MIGRATION NUMARALARI (guncel):** 024 = grup sohbet (`chats.avatar_media_id`,
  `chat_members.cleared_at`), 025 = `posts.duzenlendi_at`. Sonraki **026**'dan.
- **ONCEKI (8 Agu 22:40):** TEST TURU 75 YAYINLANDI — android 31274404137 +
  ios 31274409665 (1aa6274), R2 apk=112201055 (md5 024bc3af) ipa=23288435 (md5 f9cd1183),
  purge OK, **CDN birebir**, indir sayfasi 22:40, debug imza YOK, iOS min 16.0 dogrulandi,
  **BACKEND DEPLOY EDILDI** (turu 64 -> 75; migration 020/021/022/023) + health ok,
  DB temiz (0/0/0/0).
- ✅✅ **TEST SONUCU (8 Agu, kullanici): "hepsini test ettim, mukemmel calisiyor".**
  Tek seferde dogrulanan yigin — ucu de ILK KEZ sahada test edildi:
  · **turu 73** oda/yayin duraklatma (iOS dahil), SesSahipligi defteri, ses birimi merdiveni
  · **turu 74** medya (fotograf + sesli mesaj), engelleme, sikayet, mesaj silme
  · **turu 75** sosyal katman (akis/profil/takip/gonderi/begeni/yorum/kaydetme/reels/
    bildirimler) + kanal
  ⏳ **KULLANICI EKSIKLERI YAZACAK — BEKLENIYOR.**
- ⚠️⚠️⚠️ **TURU 75 YAYINDA YAKALANAN SEVK ENGELI: MEDYA SUNUCUDA KAPALIYDI.**
  Deploy sonrasi log: **"medya: R2_* env EKSIK — MEDYA KAPALI"**. /health "ok"
  donuyordu, API saglikli aciliyordu — hata SATIR ARASINDAYDI.
  **KOK NEDEN:** `backend/docker-compose.yml` **env_file: DEGIL** acik **environment:**
  eslemesi kullaniyor. Sunucudaki `.env` dosyasina R2 anahtarlarini eklemek
  **TEK BASINA YETMEDI**; degiskenlerin KABA gecmesi icin compose'da da eslenmesi
  gerekiyordu.
  **ETKISI:** yukleme, profil fotografi, gonderi/kanal gorselleri ve REELS tamamen olu
  olacakti (turu 74 medya + turu 75 sosyal katmanin GORSEL ayaginin hepsi).
  ⚠️ **YAPMA: yeni bir env degiskeni eklerken yalniz `.env`e yazip birakma; compose'daki
  `environment:` blogunu da guncelle (IKISI AYRI YERDIR).**
- ✅ **TURU 75 — UCTAN UCA CANLI DOGRULAMA: 27/27 GECTI** (scratchpad/uctan_uca.js).
  Gercek sunucuda, **IKI AYRI HESAPLA** (tek cihazda gorunmeyen hatalar icin SART):
  presign -> R2 PUT -> commit -> gonderi -> takip -> akis -> **B'nin A'nin gorselini
  imzali adresten BIREBIR indirmesi** -> begeni/yorum/kaydetme -> kaydedilenler ->
  **engelleme sonrasi profil gonderilerinin BOSALMASI** -> kanal ac/gonderi/abone/
  `sessiz` alani/kesfet filtresi -> reels -> bildirimler.
  ⚠️ Bu betik SURUM RUTININE EKLENDI: sosyal/medya degisen her turda kosulmali.
- 📌 **MIGRATION DOGRULAMA YONTEMI (yeni rutin adimi):** deploy ONCESI sunucuda
  ATILABILIR kopya DB (`CREATE DATABASE mig_dogrula`) acilip TUM migration'lar sirayla
  `psql -v ON_ERROR_STOP=1` ile uygulanir, sonra DROP edilir. Gercek veriye DOKUNULMAZ.
  Hatali bir migration API'yi ACILISTA oldurur; bu adim onu deploy'dan once yakalar.
  (Turu 75'te 9/9 temiz gecti.)
- **ONCEKI (8 Agu):** TURU 75 kodu — sosyal katman + kanal.
  Kullanici karari: **"testi en son yapacagiz, arastirma bittikten sonra hersyi bitir"**.
  Turu 73/74 HENUZ TEST EDILMEDI — hepsi TEK SEFERDE test edilecek.
  ⏳ **KULLANICIYA SORULACAK: build alalim mi?** (CLAUDE.md kural 0)
- ✅ **TURU 75 — SOSYAL KATMAN + KANAL TAMAMLANDI.**
  · migration **020** takip+sayaclar+gizli hesap+bildirimler · **021** gonderi/begeni/
    yorum/kaydetme · **022** kanal · **023** denetimde bulunan eksik indeksler
  · `internal/users/takip.go` · `internal/social/{handler,etkilesim}.go` ·
    `internal/kanal/handler.go` · 13 yeni Flutter ekrani (sosyal/ + kanal/)
  · Alt menu **6 sekme**: Akış · Sohbet · Arama · Oda · Canlı · Profil
    ⚠️ `_index` sabitleri ustune yazilmis kosullar var (0=akis -> ust AppBar GIZLENIR
    cunku akis kendi AppBar'ini cizer; 1=sohbet -> "yeni sohbet" + dugmesi).
    ⚠️ YAPMA: sirayi degistirme, 7. sekme ekleme (360dp'de etiketler sinirda).
  · Kanallar, Akis'in ustundeki **"Akış | Kanallar" segment secicisinde** (IndexedStack).
- ⚠️⚠️ **TURU 75 — FAN-OUT KARARI: OKUMA ZAMANI (akis VE kanal).**
  Yazma zamani fan-out'ta 10.000 takipcili biri gonderi atinca **10.000 satir yazilir**.
  cx33'te Postgres LiveKit ile **AYNI 4 vCPU'yu** paylasiyor — bu yazma firtinasi SFU'yu
  ac birakir (aramalar/yayinlar bozulur). Geri donulebilirlik de bu yonde: read-time ->
  hibrit KOLAY, tersi zor. ⚠️ YAPMA: olcum gormeden yazma zamanina gecme.
- ⚠️⚠️⚠️ **TURU 75 — KANAL `chats` HATTINI KULLANMIYOR (kod okunarak bulundu).**
  CLAUDE.md "tek chats tablosu, type: channel" diyor ve CHECK'i 'channel'i kabul ediyor.
  Ama `chat.SendMessage` her mesajda **UYE BASINA AYRI INSERT** yapiyor
  (`for _, uid := range members { INSERT INTO message_receipts ... }`) -> 10.000 aboneli
  kanalda TEK gonderi = **10.000 ayri sorgu**. `hub.Publish(To: members)` ve
  `push.NotifyUsers(members,...)` ayni diziyi tasiyor; `ListChats` okunmamisi
  `message_receipts` COUNT(*) ile buluyor. Ustelik kanalda **okundu bilgisi zaten
  istenmiyor** (WhatsApp kanallarinda tik yok) — o satirlarin urun karsiligi da YOK.
  COZUM: okunmamis = (kanal,kullanici) basina **TEK damga** (`son_okuma`).
  ⚠️ YAPMA: kanali `messages`/`message_receipts` hattina tasima.
  ⚠️ Kanal push'u **bilincli olarak YOK** (ilk surum): `NotifyUsers` tum aliciyi tek
  cagrida isliyor, FCM'in 500 hedef/istek siniri asilir. Parcali+kuyruklu gonderim AYRI IS.
- ⚠️⚠️⚠️ **TURU 75b DENETIMI — 5 SEVK ENGELI (38 bulgu, 18 onaylandi, 20 elendi):**
  **(1) AKISTAKI TUM GORSEL/VIDEO IZLEYICIYE 403 DONUYORDU.** `media.erisebilir()`
  yalniz iki dal taniyordu (mesaja bagli / avatar); `posts.media_ids` ve
  `channel_posts.media_ids` icin DAL YOKTU. Akis sadece id donduruyor, istemci her
  gorsel icin `GET /media/{id}/url` cagiriyor -> PAYLASANDAN BASKA HERKESE 403.
  ⚠️⚠️ **TEK CIHAZDA TEST EDILSE GORULMEZDI**: kapi `if sahip != userID && ...` —
  paylasan kendi gorselini kisa devreyle gorur; hata YALNIZ ikinci hesapta cikar.
  ⚠️ YAPMA: yeni dallari "herhangi bir gonderiye bagliysa serbest"e gevsetme (gizli
  hesap medyasi sizar + engelleme delinir).
  **(2) `/users/{id}/posts` ENGEL KONTROLUNU ATLIYORDU** — engellenen kisi profile girip
  her seyi okuyabiliyordu. Predikat DORT sorguya kopyalanmis, BESINCISINDE dusmustu
  (turu 72b/H "ayni kuralin iki kopyasi drift eder" dersinin tekrari).
  Artik `const engelYok` TEK KAYNAK. ⚠️ YAPMA: yuklemi sorgulara elle kopyalama.
  **(3) YUKLEME BITERKEN `Navigator.pop()` YANLIS ROUTE'U KAPATIYORDU** (acik onay
  diyalogu varsa) -> gonderi sunucuda OLUSUR ama ekran kalir, kullanici tekrar basar
  -> **CIFT GONDERI**. FIX: `ModalRoute.of` ile kendi route'unu ADRESLE + `popUntil`.
  **(4) VIDEO OYNATICI KURULUMU KAPISIZDI.** `video_player` iOS'ta `initialize()`
  sirasinda `setMixWithOthers(...)` gonderir; bu RTCAudioSession kilidinin **DISINDAN**
  AVAudioSession'i yeniden yapilandirir. ⚠️ **`mixWithOthers: true` "oturumu ele gecirme"
  demek, "oturuma HIC DOKUNMA" DEMEK DEGIL.** FIX: `_kur()` basinda
  `MedyaKapisi.donanimSerbest` kapisi. ⚠️ YAPMA: bu kapiyi kaldirma.
  **(5) KENDI PROFILIMDE "Takip et/Mesaj/Engelle/Şikayet"** cikiyordu (hicbir "bu benim"
  kapisi yoktu). FIX: `_benimMi` + "Profili düzenle/Kaydedilenler/**Gizli hesap**".
- ⚠️⚠️ **TURU 75b — OLU OZELLIKLER (ayni sinif ucuncu ve dorduncu kez):**
  · **Gizli hesap TAMAMEN ULASILAMAZDI**: `gizlilikAyarla()` yazilmis ama HIC
    cagrilmiyordu -> hicbiri gizli hesap olamiyor, dolayisiyla takip isteginin
    'bekliyor' dali + FollowApprove/Reject uclari + "Takip istekleri" ekrani + profil
    kilit dallari HEPSI olu kaliyordu.
  · **Kaydetme "KARA DELIK"ti**: `post_saves` yaziliyor, LISTELEYEN uc/ekran YOK.
    Yeni `GET /users/me/saved` + `kaydedilenler_sayfasi.dart`.
  · `posts.goruntulenme` OLU SUTUNDU (021'de var, yazan/okuyan yok) — baglandi.
  ⚠️ **DERS (dorduncu tekrar): bir sutun/servis/dugme ekledigin AN onu OKUYAN yolu da
  yaz. Onceki ornekler: `deleted_for_all`, `blocks`, foto gonderme, ses notu.**
- ⚠️⚠️ **TURU 75b — `nil` DILIM SQL NULL GONDERIR (SEVK ENGELIYDI).**
  `social.Create` icinde `req.MediaIDs = nil` yaziliyordu; `posts.media_ids` **NOT NULL**
  -> **HER YAZI GONDERISI 500 DONECEKTI.** FIX: `[]string{}`.
  ⚠️ YAPMA: `MediaIDs`i tekrar `nil`e set etme.
- ⚠️⚠️ **TURU 75b — KENDI ALARMIMI KENDIM CURUTTUM (yontem dersi).**
  Once "pgx `[]string`i `uuid[]`e kodlayamiyor, dolayisiyla TUM `= ANY($1)` cagrilari
  (push, engelleme, medya sahipligi) BOZUK" sonucuna vardim. **YANLISTI.** pgx v5.7.4
  `extended_query_builder.go:55-76` tercih edilen bicim hata verirse **DIGER bicimi
  dener** ve metin bicimi calisir. Kaynak okunarak curutuldu -> buyuk ve gereksiz bir
  refactor'dan donuldu.
  📌 **DERS: "kanit" diye sunulan bir olcumun HANGI KATMANI olctugune bak.**
  `Map.Encode`i dogrudan cagirmak, sorgu yolundaki geri donus mantigini ATLIYOR.
  ⚠️ YAPMA: `[]string` -> `[]pgtype.UUID` donusumu ekleme; OLCULDU, gerek YOK.
- ⚠️⚠️ **TURU 75 — YENI KALICI TESTLER (ikisi de canli DB GEREKTIRMEZ):**
  · `cmd/api/rota_test.go` — chi CAKISAN desenlerde **calisma aninda PANIK** atar ve
    `go build`/`go vet` bunu YAKALAMAZ. Desenleri `main.go` **KAYNAGINDAN** regex ile
    okur -> DRIFT YOK. **126 rota cakismasiz**; riskli STATIK-vs-PARAMETRE yollari
    (`/users/me/follow-requests` vs `/users/{id}/profile`, `/channels/kesfet` vs
    `/channels/{id}`) chi'nin GERI DONUS davranisiyla dogru cozuluyor — test kanitliyor.
    ⚠️ YAPMA: desenleri teste elle kopyalama.
  · `internal/social/tip_test.go` — `uuid[]` tarama (bozulsaydi `satirlariOku`daki
    `if rows.Scan(...) != nil { continue }` satirlari SESSIZCE atlar, akis BOMBOS
    donerdi) + `nil` vs bos dilim + `bigint -> int64`.
- ⚠️ **TURU 75 — GORUNTULENME YALNIZ REELS + GONDERI DETAYINDA ARTAR, AKISTA ARTMAZ.**
  Akista 20 kart TEK ISTEKTE gelir ama cogu HIC gorulmez; orada saymak sayiyi YALAN yapar.
  Kart uzerinde goruntulenme YALNIZ YAZARINA gorunur (Instagram deseni); reels'te herkese.
  ⚠️ YAPMA: sayimi `Akis` icine kopyalama.
- ⚠️ **DURUST SINIR — kanal gonderisinde VIDEO YOK (ilk surum):** `channel_posts.media_ids`
  medyanin TURUNU tasimiyor; istemci bir id'nin video mu foto mu oldugunu BILEMEZ ve
  video id'sini `MedyaGorsel`e verirse KIRIK GORSEL cizer. Once sunucu `media_kinds`
  dondurmeli. ⚠️ YAPMA: tur bilgisi olmadan medyayi video sanip oynatmaya calisma.
- ⚠️⚠️ **VERI POLITIKASI (kullanici karari 8 Agu): VERI SILINMEZ.** Hicbir semada yas
  tabanli silme YOK; depolama buyur, maliyet kabul edildi. Istisnalar yalnizca yasal
  zorunluluk: sahibi siler · hesap silinir (KVKK) · mahkeme/BTK karari · CSAM.
  ⚠️ YAPMA: herhangi bir tabloya `expires_at`/otomatik supurge ekleme.
- **KALDIGIMIZ YER (8 Agu):** TURU 74 — KOD YAZILIYOR, BUILD ALINMADI.
  Kullanici karari: **"testi en son yapacagiz, arastirma bittikten sonra hersyi bitir"** —
  yani medya + sosyal katman TAMAMLANIP TEK SEFERDE test edilecek. Turu 73 HENUZ TEST EDILMEDI.
  ⏳ Arka planda **sosyal katman arastirmasi** kosuyor (profil/takip/kanal/akis/gonderi/reels).
- ⚠️⚠️⚠️ **TURU 74 — BEKLEYEN OLCUMLER OKUNDU, UC ACIK SORU KAPANDI (Sentry, 14 gun):**
  **(1) TURU 68 KAPANDI — `supportsHolding: false` SAHADA DOGRULANDI.** `activeCalls()`
  yaniti: `maximumCallGroups: 2, maximumCallsPerCallGroup: 1, supportsHolding: false,
  supportsGrouping: false`. Deger CallKit'e ULASIYOR.
  🚫 **BEKLEYEN "maximumCallGroups 2 -> 1" KARARI ARTIK GEREKSIZ — KALICI IPTAL.**
  ⚠️ YAPMA: bir daha onerme. `maximumCallsPerCallGroup:1` ile birlikte toplam kapasite 1
  olur ve ikinci `reportNewIncomingCall` HATA donebilir -> telefon CALMAZ + iOS 13 kurali
  ihlali (turu 33/67 "arama karsilanmiyor" semptomu geri gelir).
  **(2) TURU 69 — IKI KAPATMA YOLU DA CALISIYOR:** `kaynak=eklenti` **25 olay**,
  `kaynak=native` **9 olay**. KRITIK ayrinti: `kaynak=native yasam=AppLifecycleState.paused`
  **8 kez** -> native kanca UYGULAMA ARKA PLANDAYKEN devreye giriyor, yani tam da kullanicinin
  sikayet ettigi senaryoyu yakaliyor. ⚠️ Kanca GEREKSIZ DEGIL, kaldirma.
  **(3) ⚠️ TURU 63 HIPOTEZI OLCUMLE CURUTULDU:** duzeltilmis metrikle
  `tamponMs=13 jitterMs=4.0 gizlenenOrnek=0 recvPaketSn=8`. **13 ms jitter tamponu YOK
  HUKMUNDEDIR** — bekletmeden cikista BIRIKMIS SES YOK.
  ⚠️ "Ses gecikmesi jitter tamponundan geliyor" aciklamasi **GECERSIZ**; bir daha bu
  hipotezle yola cikma. Gecikme yine bildirilirse BASKA yerde ara.
- ⚠️⚠️ **TURU 74 — OLCUM KUSURU (`holdDurumunuOlc`) DUZELTILDI:** iOS'ta
  `FlutterCallkitIncoming.activeCalls()` **Map DEGIL `CallKitParams` NESNESI** donduruyor;
  `c is Map` FALSE kalip `c.toString()` TUM NESNEYI (~900 karakter: id, isim, extra,
  bildirim ayarlari) mesaja basiyordu. Iki zarari: (a) aranan `hold=` degeri BASLIKTAN
  TASIP gorunmuyordu, (b) mesajda callId gectigi icin Sentry **her aramayi AYRI ISSUE**
  yapmis (tek olcum 6 kayda dagilmis). Artik tipten bagimsiz ALAN CIKARILIR; mesaj KISA
  ve SABIT -> tek issue'da gruplanir.
  ⚠️ YAPMA: `c.toString()`e geri donme; olcum mesajina callId koyma.
  ⚠️ **GENEL DERS: bir olcum eklerken DONEN TIPI DOGRULA.** Bu olcum 6 turdur
  yaziliyordu ve okunamaz oldugu icin sorunun cevabini 6 tur GECIKTIRDI.
- ⚠️⚠️⚠️ **TURU 74 — ENGELLEME SAHADA HIC CALISMIYORDU (kod okunarak tespit).**
  `blocks` tablosu **001_init.sql'den beri VAR** ama ONA YAZAN DA OKUYAN DA YOKTU.
  Ustelik `SendMessage` icinde `chatMemberIDs` cagrisinin ustundeki yorum yillardir
  **"uyelik + engel kontrolu"** diyordu — YANLIS; o fonksiyon yalnizca uyelige bakiyor.
  Yani engellemenin ne YOLU vardi ne de olsa UYGULANIRDI.
  ⚠️ **DERS: bir yorumun anlattigi kontrolun GOVDEDE gercekten olup olmadigini dogrula.**
  **EKLENENLER (turu 74):**
  · migration **014_reports.sql** — `reports` tablosu. `hedef_tur` SERBEST METIN (CHECK YOK):
    yeni icerik tipleri (medya/gonderi/reels/kanal) migration GEREKTIRMEZ.
    `UNIQUE(reporter_id,hedef_tur,hedef_id)` -> sikayet spam'i satir biriktirmez.
    ⚠️ YAPMA: `hedef_tur`a CHECK constraint koyma.
  · `internal/users/moderasyon.go` — POST/DELETE `/users/{id}/block` · GET `/users/me/blocks`
    · POST `/reports`. Hepsi IDEMPOTENT; hedef yoksa 404 (FK hatasi 500'e dusmesin).
  · `internal/chat.engelliMi()` **TEK KAYNAK** + `SendMessage`da uygulama.
    ⚠️ Kural **CIFT YONLU**: taraflardan HANGISI digerini engellediyse mesaj GITMEZ
    (tek yonlu olsaydi engelleyen taraf karsisindakini rahatsiz etmeye DEVAM edebilirdi).
    ⚠️ **FAIL-CLOSED**: engel sorgusu patlarsa mesaj GECMEZ.
    ⚠️ Hata metni **NOTR** ("bu kişiye mesaj gönderilemiyor") — "seni engelledi" demek
    engellemeyi IFSA eder (WhatsApp da gizler).
  · `DELETE /chats/{chatID}/messages/{msgID}` — herkesten silme. `deleted_for_all` sutunu
    001'den beri VARDI ve listeleme sorgulari onu OKUYORDU ama SILME UCU YOKTU (olu sutun).
    Yalniz GONDEREN siler; satir FIZIKSEL SILINMEZ (icerik bosaltilir) -> sira ve okundu
    bilgisi bozulmaz. WS `message.deleted` GONDERENE DE gider (ikinci cihaz).
    ⚠️ YAPMA: sure siniri koyma (icerik kaldirma yukumlulugu sureli olamaz).
    ⚠️ YAPMA: satiri fiziksel DELETE etme (`message_receipts` FK'si + sohbet sirasi bozulur).
  **NEDEN SIMDI:** App Store Review Guideline 1.2 (UGC) engelleme + sikayet + icerik
  kaldirmayi BIRLIKTE sart kosuyor; medya ve herkese acik gonderi gelmeden ONCE durmali.
- ⚠️ **TURU 74 — `media_url` ISTEMCI ALANI KALDIRILDI (guvenlik).** `sendMessageReq.MediaURL`
  istemciden SERBESTCE alinip DOGRULANMADAN `messages`a INSERT ediliyordu. Istemci bu alani
  HIC GONDERMIYOR (`chats_provider.dart:80` yalnizca `{'type','content'}`) — KULLANILMIYOR
  ama ACIK duruyordu. Herhangi biri `{"type":"image","media_url":"https://kotu/izleme.gif"}`
  gonderip alicinin IP'sini/saatini toplayabilir (IZLEME PIKSELI), sahte banner cizdirebilir
  (OLTALAMA), sunucu onizlemesi eklenirse SSRF acabilirdi. `models.dart:80` bu alani ZATEN
  okuyor -> gorsel cizimi eklendigi ANDA somurulebilir olacakti.
  ⚠️ YAPMA: alani geri ekleme. Medya gelince URL **SUNUCUDA turetilecek** (medya kaydinin
  id'sinden), istemci ASLA URL vermez.
- 📌 **MIGRATION NUMARALARI:** 014 = `reports` (turu 74). Medya migration'lari **015'ten**,
  sosyal katman **020'den** baslar (medya-plani.md "014'ten devam" diyordu — GUNCELLENDI).
- ⏳ **ERTELENDI (bilincli karar, turu 74):** ~500 satirlik olu bekletme/park zinciri
  (`ParkEdilenArama`/`parkEt`/`devamEt`/`beklemeyeAl` govdesi/`_iosSesOturumuGarantile`/
  `GebzemSesKurtar` + call_screen bekletme paneli) HALA DURUYOR.
  **GEREKCE:** `active_call_controller.dart` bu projenin en kirilgan dosyasi (3600+ satir,
  74 turluk birikim) ve turu 67'de bu silme denenirken dosya BOZULDU. Test EN SONDA tek
  seferde yapilacagi icin, oradan 500 satir silip ustune medya + sosyal katman koymak,
  arama bozulursa SEBEBI AYIRT EDILEMEZ hale getirir. **Buyuk testten SONRA kendi turunda.**
  ⚠️ `beklemeyeAl`in `!bekletmeAcik` dali **CANLI** (kacak CallKit hold olayinda aramayi
  BITIRIYOR) — silinirken o dal KORUNMALI.
- **ONCEKI (7 Agu 22:31):** TEST TURU 73 YAYINLANDI — android 31210896371 +
  ios 31210908402 (c5ccec7), R2 apk=108271245 (md5 07f4b9dc) ipa=22365997 (md5 43ccd140),
  purge OK, **CDN birebir**, indir sayfasi 22:31, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz (0/0/0/0). **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 73 — ODA/YAYIN DURAKLATMASI ARTIK iOS'TA DA ACIK (kullanici emri:
  "hepsine yapsana android ne alaka test edelim iste").**
  Turu 72'de yalniz Android acikti; gerekce turu 65'te OLCULEN `!pri` idi. Acmanin
  BEDELI IKI YAPISAL KAPIYLA odendi — ikisi de ZORUNLU, biri kaldirilirsa iOS BOZULUR:
  · **`SesSahipligi` DEFTERI** (`medya_beklet.dart`) — iOS'ta `isAudioEnabled` PROSES
    GENELINDE TEK bayraktir ve turu 73'e kadar arama ile oda/yayin AYNI ANDA hic
    yasamamisti. Iki yonlu yikim vardi: (a) ARAMA kapanisi (`_odaTemizle`) hala bagli
    odanin sesini OLDURUYORDU ("devam"da SESSIZLIK — turu 72'nin iOS'ta calismamasinin
    GERCEK sebebi; `!pri` TEK BASINA degil); (b) ODA/YAYIN kapanisi SUREN ARAMAYI
    sessize dusuruyordu. Artik her tuketici kaydolur (`arama_` / `oda_` / `yayin_b_` /
    `yayin_i_`) ve kapanirken BASKA TURDEN sahip varsa ses birimine DOKUNMAZ.
    ⚠️ Nesil jetonu (`_sesNesilSayaci`) yalniz ARAMA-ARAMA yarisini korur, oda/yayini GORMEZ.
  · **`iosSesBirimiAc` MERDIVENI** — "devam" ile arama kapanisi YARIS halinde; oturumu
    CallKit tutuyor olabilir. 5 basamak (0/200/600/1200/2000ms), olcut native
    `configOk && active`, tukenirse GERCEK Sentry olayi + kullaniciya durust mesaj.
    ⚠️ `required gecerli` canlilik kapisi ZORUNLU (bkz. turu 73b/1).
  · `mesgulMu` muafiyetindeki `Platform.isAndroid` KALDIRILDI -> iPhone'da odadayken/
    yayindayken arama artik GERCEKTEN kabul edilebiliyor (eskiden `answer()` null
    donuyor, CallKit kapaniyor, arayan "reddedildi" goruyordu).
  📌 **OLCUM — TEST SONRASI BAK:** `oda/yayin ses birimi ACILAMADI (oda|yayinci|
  izleyici): hata=..` cikarsa `!pri` iOS'ta HALA gecerli demektir; `N. denemede
  ACILDI` cikarsa merdiven kurtardi ve basamak sayisi ayarlanabilir.
- ⚠️⚠️ **TURU 73b — DENETIM 4 YUKSEK BULDU (ucu iOS ACILISININ YENI SINIF HATASI):**
  **(1) MERDIVENDE CANLILIK KAPISI YOKTU** — ~4sn await ediyor, hicbir basamakta
  `mounted`/`_ayrildi`/`_kapandi` kontrolu yoktu. Kullanici "devam"a basip odadan
  CIKARSA kapanis ses birimini kapatir, merdivenin sonraki basamagi GERI ACAR ->
  **AVAudioSession SAHIPSIZ ACIK** kalir (iPhone mikrofon gostergesi SONMEZ, sonraki
  aramanin kurulumuyla cekisir). ⚠️ YAPMA: `gecerli`yi opsiyonel yapma veya yalniz basa koyma.
  **(2) ODA/YAYIN `resumed` DALINDAKI `_sesiAc(true)` AKTIF ARAMAYI YIKIYORDU** —
  native `setAudioEnabled(true)` KOSULSUZ ZORLA TOGGLE yapar (yikip yeniden kurar).
  Turu 72'ye kadar zararsizdi cunku iOS'ta oda ile arama AYNI ANDA YASAYAMIYORDU.
  Gorusme surerken uygulamayi arka plana alip donmek (kilit ekrani/bildirim — arama
  sirasinda COK SIK) ARAMANIN ses birimini ~50-150ms sagirlastiriyor, hata da
  `catch (_)` ile yutuluyordu. FIX: uc ekranda da `if (!SesSahipligi.aramaCanli)`.
  ⚠️⚠️ **DERS: bir ozelligi YENI BIR PLATFORMA acarken, o platformda DAHA ONCE
  ULASILAMAYAN kod yollarinin artik ULASILABILIR oldugunu varsay ve HEPSINI yeniden
  degerlendir.** Buradaki uc bulgunun ortak koku tam olarak buydu.
  **(3) `geriAra()` DEFTERDE KALICI `arama_` SIZINTISI BIRAKIYORDU** — eski id'yi
  dusurebilecek tek yer `leave(eskiId)` ve o bir daha CAGRILAMAZ (`arama` artik yeni
  aramayi gosterir). "Geri ara"ya BIR KEZ basmak yeter: `aramaCanli` proses omru
  boyunca true takilir ve odadan/yayindan cikinca ses birimi BIR DAHA kapanmaz.
  **(4)** Ayni sizintinin ikinci yolu: bayat-`leave` kapisi (turu 69b'de sahada
  gerceklestigi KANITLI) `birak`i atliyordu -> kapinin USTUNE tasindi.
  ⚠️ YAPMA: `birak`i tekrar kapinin ALTINA tasima; `_odaTemizle` yalniz `oda_`/`yayin_`
  onekine baktigi icin erken birakma ZARARSIZ.
  **(5 ORTA) MERDIVEN `_micHedef` EZILME PENCERESINI ~100ms'DEN ~4sn'YE CIKARMISTI:**
  `_micOn` UI bayragi merdivenin ALTINDA yaziliyordu, yani 4sn boyunca BAYAT `false`.
  O pencerede gelen ikinci arama `_micHedef`i **false** yakalar ve arama bitince
  mikrofon BIR DAHA ACILMAZ. `live_broadcast_screen` bu deseni ZATEN dogru yapiyordu —
  **uc ekran arasindaki ASIMETRI hatanin kendisiydi.**
  **(6 ORTA)** Defter statikti, sifirlama yoktu + yayinci ile izleyici AYNI anahtari
  kullaniyordu (ust uste binmede biri digerinin kaydini siler) -> `SesSahipligi.sifirla()`
  (logout'ta cagrilir) + `yayin_b_` / `yayin_i_` ayrimi.
  **(8 DUSUK) KENDI TURU 72b UYARIM KAYNAKTAN CURUTULDU:** "`medyaBeklet` iOS'ta
  DOLAYLI olarak AVAudioSession'i yeniden yapilandirabilir" yolu YOK —
  `setMicrophoneEnabled(false)` -> `publication.mute(...)`; `onUnpublish` YALNIZ
  `unpublishTrack`/`removePublishedTrack` yolundan cagrilir (`_localTrackCount`
  DEGISMEZ); `RemoteTrackPublication.disable()` de `track.stop()` YAPMAZ
  (`_remoteTrackCount` DEGISMEZ). Yani `_onAudioTrackCountDidChange` HIC tetiklenmiyor.
  ⚠️ Bunu "olasi risk" diye geri yazma — kaynak okundu, tetiklenmiyor.
- **ONCEKI (7 Agu 16:35):** TEST TURU 70+71+72 YAYINLANDI — android 31182191326 +
  ios 31182204197 (7084341), R2 apk=108254865 (md5 024156c0) ipa=22361813 (md5 341a1981),
  purge OK, CDN birebir, indir sayfasi 16:35, backend DEGISMEDI + health ok, DB temiz.
- ⚠️⚠️⚠️ **TURU 72 — ODA/YAYIN DURAKLATMA (KULLANICI TASARIMI).**
  *"Oda kurdum konusuyorum, telefona cevap verdigimde odadaki mikrofonu kapat ve
  profilde pause isareti Bekliyor olsun; canli yayinda da mikrofonu kapat ve ekrani
  blurla; gorusme bitince 'Sohbete devam' / 'Canli yayina devam' olsun."*
  · Ortak primitif **`mobile/lib/features/calls/medya_beklet.dart`** — arama
    tarafindaki kanitli govde KOPYALANMADI, ORAYA CIKARILDI (tek kaynak).
  · **`disable()` kullanilir, `unsubscribe()` DEGIL** (abonelik korunur, donus ANINDA;
    unsubscribe ile yeniden pazarlik gerekir ve ses saniyelerce gec gelir).
  · **BAGLANTI ACIK KALIR:** sunucuda oda/yayin BITMEZ, nabiz SURER, izleyiciler DUSMEZ.
  · **DEVAM OTOMATIK DEGIL, DUGMEYLE** — telefon kapanir kapanmaz mikrofonun
    kendiliginden acilmasi gizlilik riski. ⚠️ YAPMA: otomatik devama cevirme.
  · Mesgulluk kapisi gevsetildi: odadayken/yayindayken telefon artik **CALAR**.
  ⚠️⚠️ **iOS'TA DURAKLATMA KAPALI (BILINCLI):** turu 65'te CallKit sonrasi ses birimini
    geri acma denememizin **`!pri` (InsufficientPriority)** ile REDDEDILDIGI OLCUMLE
    KANITLANDI. Acsaydik "odaya dondum ama ses yok" yasanirdi.
    ⚠️ YAPMA: olcum yesil donmeden iOS'u acma.
  ⚠️⚠️ **`medyaBeklet` `_sesiAc(false)` CAGIRAMAZ** — o native `gebzem/audio` uzerinden
    `RTCAudioSession.isAudioEnabled` yazar; PROSES GENELINDE TEK nesnedir ve AKTIF
    ARAMANIN sesini de OLDURUR. (iOS'ta livekit'in modul-global track sayaci uzerinden
    DOLAYLI dokunma yolu VAR — dosya serhinde yazili, iOS acilirsa ILK bakilacak yer.)
- ⚠️⚠️⚠️ **TURU 72b — BUILD ONCESI DENETIM 16 SEVK ENGELI BULDU (4 ajan). KALICI DERSLER:**
  **(A) GSM ARAMASI TETIGI HIC BAGLI DEGILDI** — tetikleyici yalniz `_aramaCtrl`
  (Gebzem aramasi) dinliyordu; `PipService.gsmAramada` bir ValueNotifier ve uc ekranda
  da `addListener` YOKTU. Yani ozelligin **MANSET SENARYOSU** ("telefona cevap
  verdigimde") calismiyordu, ustelik `odayaDevam`daki GSM kapisi **HIC GIRILEMEYEN**
  bir durum icin yazilmisti. ⚠️ YAPMA: iki dinleyiciden birini kaldirma.
  **(B) "DEVAM" DUGMESI AKTIF GEBZEM ARAMASINI SORMUYORDU** (yalniz GSM). Kullanici
  arama ekranini KUCULTUP (`call_screen._minimize` -> `Navigator.pop`) odaya/yayina
  donebiliyor; serit HER ZAMAN etkin oldugu icin basinca mikrofon + uzak sesler GERI
  ACILIYOR -> odadakiler/izleyiciler GORUSMEYI DUYUYOR (turu 56/63/71 aciginin aynisi).
  ⚠️ YAPMA: `arama != null` kapisini kaldirma.
  **(C) DURAKLATMA KATMANI STACK'IN ORTASINDAYDI** — Stack SON cocugu EN USTE cizer ve
  hit-test'i TERS sirada yapar. Ust bar (**MIKROFON DUGMESI**) ve alt serit ("Canliya
  katil") hem BLUR'LANMIYOR hem TIKLANABILIYORDU; basan kullanici yayini GERI ACIYOR,
  ekran "Bekliyor" demeye DEVAM ediyordu (`_duraklatildi` true kaldigi icin tetikleyici
  de KENDINI ONARMIYOR). ⚠️ Katman **EN SONDA** + `GestureDetector(HitTestBehavior.opaque)`.
  ⚠️ YAPMA: `IgnorePointer` kullanma (dokunus alttakilere GECER); katmani ortaya tasima.
  **(D) BAGLANIRKEN DURAKLATMA KILITLENIP NO-OP KALIYORDU** — `_room` connect'ten ONCE
  atanir ama livekit `localParticipant`i ancak `RoomConnectedEvent` ile yaratir.
  O pencerede `medyaBeklet` TAMAMEN no-op, `_duraklatildi = true` ise KILITLENIYOR;
  ardindan connect `setMicrophoneEnabled(true)` cagiriyordu. Sonuc KALICI: ekran
  "Bekliyor", oda SENI DUYUYOR. FIX: connect'te `&& !_duraklatildi` + connect sonunda
  `if (_duraklatildi) await medyaBeklet(room, true);`.
  ⚠️ **GENEL DERS: bir bayragi await'ten ONCE yazip is'i await'ten SONRA yapan her
  yerde, o penceredeki BASKA yazicilari da say.** (turu 68'in "kuyruga sararken hangi
  alanlar ne zaman okunuyor" dersinin kardesi.)
  **(E) `_konukOl()` / ROL TERFISI / HOST SUSTURMASI / `restartTrack()` KAPISIZDI** —
  dordu de duraklatmada medyayi YAYINA sokuyor ya da tercihi bozuyordu. Ozellikle
  livekit `restartTrack()` **`muted` bayragina HIC BAKMAZ**: stop -> createStream
  (KAMERAYI FIZIKSEL ACAR) -> replaceTrack -> start.
  ⚠️ YAPMA: `_videoSagligiKur` timer'indan `_duraklatildi` kapisini cikarma.
  **(F) ARKA PLAN KAMERA DEFTERI UZLASTIRILMIYORDU** — telefon CALARKEN uygulama
  >=900ms arka planda kalirsa oto-mute `_kameraAcik=false` yazar; duraklatma onu
  KULLANICI TERCIHI sanip `_kamHedef=false` yakaliyordu -> "devam" sonrasi kamera
  **BIR DAHA ACILMIYORDU** (yayincida kamera ac/kapa dugmesi YOK = kurtarma yolu yok).
  FIX: `yayiniDuraklat` basinda `_pipKameraGecikme?.cancel()` + `_kameraOtoKapandi`
  uzlastirmasi. ⚠️ **DERS: ayni alanin IKI SAHIBI varsa yeni sahip, eskisinin
  defterini OKUMADAN tercih yakalayamaz.**
  **(G) MESGULLUK MUAFIYETI FAIL-OPEN'DI:** `live_start_screen`in muhafizi
  **`yayin-onizleme`** ve iki kapi da `startsWith('yayin')` kullaniyordu ->
  DURAKLATILAMAYAN, ustelik FIZIKSEL KAMERAYI TUTAN o ekran muafiyete giriyordu
  (arama kabul edilince IKI capture oturumu cakisir).
  ⚠️ **MUAFIYET ONEKI ALT CIZGILI OLMAK ZORUNDA** (`oda_` / `yayin_`) + `every`
  (FAIL-CLOSED). ⚠️ YAPMA: `startsWith('yayin')`e genisletme. ⚠️ YENI duraklatilabilir
  ekran eklersen muhafiz onekini `oda_`/`yayin_` yap; duraklatilamayanlara BASKA onek ver.
  **(H) AYNI KURALIN IKI KOPYASI DRIFT ETMISTI:** `_onEvent` `every`, `mesgulMu` `any`
  kullaniyordu -> kumede bayat bir arama id'si varken **ON PLANDA telefon CALMIYOR ama
  ayni arama KILIT EKRANINDAN (CallKit -> answer -> mesgulMu) KABUL EDILIYORDU.**
  Karar `mesgulMu`ya DEVREDILDI. ⚠️ YAPMA: bu kurali tekrar `_onEvent`e kopyalama.
  **(I) BAYAT MUHAFIZ SELF-HEAL'I ULASILAMAZDI:** eski kodda `if (gercekArama ||
  odaVeyaYayin) return true;` satirinin ALTINDAYDI; kumede bir `oda_` kaydi varsa bayat
  arama id'sine HIC ULASILMIYOR ve muhafiz **KALICI** asili kaliyordu. Artik gercek
  arama yoksa arama id'li her kayit tanim geregi bayattir ve temizlenir.
- ⚠️⚠️ **TURU 70b — "%20 UZAT" ARITMETIGI YANLIS UYGULANMISTI (kullaniciya gorunen).**
  PiP kose kutusu **%20 degil %42** uzamisti. Sebep: sayilar ARAMA EKRANI kutusundan
  kopyalandi ama **IKI YUZEYIN TABANI FARKLIYDI** — arama ekrani 140x200 (en-boy
  **1.4286**), PiP kutusu 0.34W / 6:5 (en-boy **1.2**). 5:6 pencerede karsi tarafin
  videosunun ~yarisini yiyordu.
  **DOGRUSU — HER YUZEY KENDI TABANINDAN:**
  · PiP kutusu: `0.3740` genislik / `1.3091` en-boy  (= 0.34*1.10 ve (0.34*1.2*1.20)/0.3740)
    -> `mini_izgara.dart` **VE** `AppDelegate.swift yerelAyarla` BIREBIR AYNI.
  · Arama ekrani self-view: `_selfOran = 0.3720` / `_selfEnBoy = 1.5584` (140*1.10=154,
    200*1.20=240) — AYRI YUZEY, esitleme.
  ⚠️ **DERS: "ucu birden ayni sayi olmali" kurali burada HIC GECERLI DEGILDI; kural
  VARSAYILARAK kopyalandi. Bir sabiti baska yuzeye tasirken once TABANLAR AYNI MI diye sor.**
  ⚠️ `tavan` `0.55*H` — 5:6 pencerede kh=0.4896W, tavan=0.66W (pay %26). YAPMA: 0.405'e dondurme.
- ⚠️⚠️ **TURU 70b — KONUM PUANDA, BOYUT ORANLI.** Self-view'in KONUM ofsetleri de orana
  cevrilmisti (0.15625 / 0.14509, 414x896'dan). Ama **KACINILACAK OGELER SABIT PUANDA
  CAPALI**: ust bilgi blogu `Positioned(top: 48)`, alt kontroller `bottom: 48`.
  375x667'de (SE) kutu **BASLIK + UYARI SERIDININ USTUNE BINIYOR**, alt sinirda
  kontrollere 140 yerine 104pt kaliyordu. **TEST CIHAZI 414x896 OLDUGU ICIN REGRESYON
  ORADA GORUNMEZDI.** ⚠️ YAPMA: bu ofsetleri tekrar orana cevirme.
- ⚠️ **TURU 70 — PiP'TEN BUYUTURKEN SIYAH KAPAK:** `restoreUserInterfaceForPictureInPictureStop`
  -> `kapakGoster()` **FLUTTER KOK VIEW'INA** (`flutterKok`, weak) siyah katman koyar;
  Dart ilk kareyi cizince (`iosPipGeriYukleniyor` -> post-frame -> `iosGeriYuklemeTamam`)
  kalkar, 700ms emniyet timer'i var.
  ⚠️ **YAPMA: kapagi `callVC?.view.window`a koyma** (AVKit'in PiP penceresidir, non-nil
  oldugu icin keyWindow yedegi HIC kosmaz ve kapak HICBIR ISE YARAMAZ — ilk denemede oldu).
  ⚠️ Route gecisinde siyah **PUSH'ta opak, POP'ta ALFA ANIMASYONLU** (turu 59'un
  "POP yonunu opaklastirma" kurali). YAPMA: pop'u opak yapma.
- ⚠️⚠️ **TURU 71/72b — `gsmDinle` SAHIPLIK SAYACI (`_gsmSahipleri`).** Arama + oda +
  yayin AYNI native gozcuyu paylasir; **SON sahip** birakmadan dinleyici kapanmaz.
  ⚠️ Sahip adlari **ORNEGE BAGLI** olmali (`oda_<id>` / `yayin_<id>`) — sabit ad
  kullanirsan ayni isimli iki ekran bir an ust uste yasadiginda (Flutter'da yeni
  route'un `initState`i eskinin `dispose`indan ONCE kosar) gozcu ERKEN kapanir ve
  gizlilik kapilari SESSIZCE oler.
  ⚠️ `gsmAramada.value = false` temizligi **`try`IN USTUNDE** — icindeyken
  `invokeMethod` firlatirsa bayrak SUREC BOYUNCA true takili kalir ve dort ekran
  mikrofonu bir daha ACMAZ, hicbir olcum dusmeden.
- **ONCEKI (5 Agu 18:06):** TEST TURU 69 YAYINLANDI — android 31017049686 +
  ios 31017055749 (522f908), R2 apk=108238365 (md5 da3eb963) ipa=22353814 (md5 b2a11ea7),
  purge OK, **CDN birebir**, indir sayfasi 18:06, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 69 — "GSM'DE BITIR DEDIM, KARSI TARAF KAPANDI AMA BENDE EKRAN ARKADA
  DURUYOR; GSM'i kapatinca ekran ANLIK gorunup gidiyor."**
  **YAPILAN:** `AppDelegate.onEnd` ve `onDecline` artik `GebzemGsmGozcu
  .callkitBittiBildir(call.data.uuid)` ile MEVCUT `gebzem/pip` kanalindan Dart'a
  `callkitBitti` gonderiyor; `PipService.callkitBittiCb` -> controller kimlik kapisiyla
  dogrulayip TEK KAPIDAN `leave(notifyServer: true)` cagiriyor.
  ⚠️ `notifyServer: TRUE` BILEREK — `/end` genelde zaten gitmis olur ama iki yol da
  kacirirsa arama sunucuda 'active' ASILI kalir; `/end` IDEMPOTENT (turu 59).
  ⚠️ YAPMA: `action.fulfill()`i geciktirme; `onEnd` icinde agir is yapma.
  ⚠️ `call.data.uuid` DOGRU alan (plugin `Data.init(id:)` -> `self.uuid = id`).
  🔴 **KOK NEDEN HALA KANITLANMADI (durustluk):** ilk aciklamam ("olay arka plan
  isolate'ine dusuyor") **iOS ICIN YANLISTI** — bkz. asagidaki teshis duzeltmesi.
  Bu kanca semptomu KESIN kapatir ama NEDEN gec kapandigini olcum gosterecek.
- ⚠️⚠️ **TESHIS DUZELTMESI — `onBackgroundMessage` YALNIZ ANDROID'DE VAR.**
  `FlutterCallkitIncoming.onBackgroundMessage` eklentinin iOS tarafinda UYGULANMAMIS;
  `MissingPluginException` firlatiyor ve `catch (_)` YUTUYOR -> **`_callkitArkaPlan`
  iPHONE'DA HIC CALISMIYOR.** Eski yorum ("iOS DAHIL ... iOS reddi de arka plandan
  sunucuya ulasabilir") YANLISTI. Kayit artik `if (Platform.isAndroid)` kapisinda.
  ⚠️ YAPMA: Android'de kaldirma (terminated Android'de CallKit reddi/bitisi YALNIZ
  bu yoldan sunucuya ulasir). ⚠️ Bunu bir daha "iOS'ta da calisiyor" diye varsayma.
- ⚠️⚠️ **TURU 69b — DENETIM KENDI KANCAMDA 2 SEVK ENGELI BULDU:**
  **(E1) KENDI `bitir()` CAGRIMIZ KANCAYI TETIKLIYORDU:** `CallKitService.bitir()` ->
  `endCall` -> plugin `CXEndCallAction` -> `AppDelegate.onEnd` -> callback -> `leave()`.
  Yani `_cevapsizGoster`/`geriAra` yollarinda **"Cevap yok — Geri Ara" ekrani ~50-150ms
  sonra KENDILIGINDEN kapaniyor**, kullanici "Geri ara"ya BASAMIYORDU.
  ⚠️⚠️ **`_bizBitirdik` BU IS ICIN KULLANILAMAZ:** (a) yalniz Dart olay yolunu korur,
  (b) okurken TUKETIR (`remove`), (c) plugin Dart olayini native `onEnd`TEN ONCE
  gonderir -> kume native kanca gelmeden BOSALMIS olur.
  FIX: AYRI + ZAMAN PENCERELI defter `_programatikBitirilen` (10sn) + `bizMiBitirdik()`;
  callback'in **ILK** kapisi bu, ayrica `_cevapsiz` kapisi.
  ⚠️ YAPMA: iki defteri birlestirme; okurken silme; kapiyi kimlik kapilarinin altina koyma.
  **(E2) BAYAT `leave` YENI ARAMAYI OLDURUYORDU (eski gizli hata, kanca gorunur yapti):**
  `leave()` icinde SENKRON olan tek sey `_ayrildi = true`; asil yikim
  `await CallSounds.durdur(...).timeout(250ms)` SONRASI. O pencerede "Bitir ve Kabul"
  ikinci aramayi baslatirsa (`main.dart`teki `await ctrlOn.leave()` `_ayrildi` yuzunden
  ANINDA doner) asili eski `leave` YENI aramanin aboneliklerini oldurur, ekranini pop
  eder, ESKI id ile `ekranKapandi` cagirdigi icin mesgul muhafizini ASILI birakir.
  FIX: await'ten hemen sonra **`if (arama?.callId != id) return;`** (tek satir).
  ⚠️ YAPMA: bu kapiyi kaldirma; `_kapatOdayiKuyrugaKoy()`u await'in ALTINA tasima.
- 📌 **TURU 69 OLCUMU — TEST SONRASI BAK:** iki kapatma yolu damgalandi:
  `callkit bitir: kaynak=native yasam=..` ve `callkit bitir: kaynak=eklenti`.
  Ikisinin ZAMAN FARKI, ekranin neden gec kapandigini KESIN gosterecek
  (native once gelirse kanca kurtardi; eklenti hic gelmiyorsa asil delik orada).
- **ONCEKI (5 Agu 00:59):** TEST TURU 68 YAYINLANDI — android 30953817519 +
  ios 30953819602 (e8215da), R2 apk=108238369 (md5 0925d92d) ipa=22353332 (md5 06475a23),
  purge OK, **CDN birebir**, indir sayfasi 00:59, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 68 — "ARKADA ACIK KALIYOR"UN IKI SEBEBI DE TURU 67'DE BENIM EKLEDIGIM
  KODDU.** Kanit: sunucu TEMIZ (son 12 arama satirinin hepsi ended/missed/rejected,
  asili `active` YOK) -> acik kalan sey CIHAZDA.
  **(1) KILIT SIRASI TERSINE DONMUS (ASIL SEBEP):** turu 67'de kapanis animasyonu icin
  `CallRoomLock.calistir(_odaTemizle)` cagrisini `Future.delayed(260ms)` closure'inin
  **ICINE** koymustum. O kilit GLOBAL ve SERIDIR; TEK varolus sebebi *"yeni oda
  BAGLANMADAN once eskisinin kapanisi TAMAMEN bitmis olsun"*. Kuyruga **GIRIS** gecikince
  sira TERSINE donebiliyor: "Bitir ve kabul et"te `leave -> /end -> /answer -> yeni
  _odayaBaglan` tipik **120-200ms**; 260ms'in ALTINA dusunce YENI baglanti kilidi ONCE
  aliyor ve **ESKI ODA LiveKit'e BAGLI + MIKROFONU YAYINDA** kaliyordu.
  ("bazen" = wifi HIZLI -> olur; hucresel YAVAS -> olmaz.)
  **FIX:** kuyruga GIRIS senkron (`leave` govdesinde), **260ms BEKLEME closure'in ICINDE**.
  Animasyon fix'i AYNEN korunur.
  ⚠️ **YAPMA: `CallRoomLock.calistir`i BIR GECIKMENIN ARKASINA koyma** — kuyruga giris
  ANI sirayi belirler, closure'in ICI degil. ⚠️ YAPMA: 260ms'i tamamen kaldirma.
  **(2) `_onizlemeBirak` NO-OP OLMUS (kamera arkada ACIK = iPhone'da YESIL NOKTA):**
  turu 67'de govdeyi `_kameraKuyruguna` ile sarmistim. Ama `baslat()` icinde
  `unawaited(_onizlemeBirak()); _onizlemeTrack = null;` ARASINDA **await YOK** (turu 32'nin
  "once SAL sonra sifirla" deseni). Kuyruk mikrotask sonrasi kostugunda `_onizlemeTrack`
  ARTIK NULL okunuyor, metot `if (t == null) return;` ile cikiyor -> `t.stop()`/`t.dispose()`
  **HIC CAGRILMIYOR** -> yayinlanmamis track + NATIVE capture oturumu ACIK kaliyor,
  sonraki aramada kamera MESGUL.
  **FIX:** track VE `_onizlemeYayinda` **kuyruga GIRMEDEN SENKRON** yakalanir.
  ⚠️ **DERS: bir govdeyi kuyruga/gecikmeye sararken, o govdenin okudugu ALANLAR cagri
  aninda mi yoksa calisma aninda mi gecerli — MUTLAKA sor.** Ayni hatanin iki turemesi
  (kilit girisi + alan okuma) ayni turda olustu.
  **(3) EK EMNIYET:** `_odaTemizle` icinde `disconnect()` ONCESI `setMicrophoneEnabled(false)`
  (300ms timeout) — `disconnect().timeout(1200ms)` ALTTAKI ISI IPTAL ETMEZ (turu 50).
  ⚠️ YAPMA: buraya `setCameraEnabled(false)` ekleme (paylasilan `videoCapturer` + gelen
  arama kamera DEVRI -> yeni aramanin videosu olur).
- ⚠️⚠️ **TURU 68 — "TUT VE KABUL ET"IN KAYNAGI: `setCallConnected`.**
  Bizim kodda UC yerde `supportsHolding: false` DOGRUYDU; deger CallKit'e ULASMIYORDU.
  `CallKitService.baglandi()` (`setCallConnected`) TURU 56'DA **TAM DA BEKLETMEYI ACMAK
  ICIN** eklenmisti ("iOS bagli olmayan aramayi HOLD EDILEBILIR saymaz"). Bekletme turu
  66'da kapatilinca satir GERIDE KALDI. Ustelik plugin `setCallConnected`e yalniz
  `{'id':...}` gonderiyor; harita **"ios" alani ICERMEDIGI** icin plugin `data`yi
  **VARSAYILANLARLA** yeniden kuruyor -> `supportsHolding = true`. Yani yazdigimiz `false`
  TAM BURADA EZILIYORDU. **FIX:** `if (bekletmeAcik && b.outgoing)`.
  ⚠️ YAPMA: `gidenArama` CallKit kaydini kaldirma (ikinci arama arayuzu + turu 57
  `gidenler` kapisi ona bagli).
  **IKINCI SIZINTI:** AppDelegate **IPTAL dali** `Data(...)` uretip `supportsHolding`
  YAZMIYORDU -> plugin varsayilani TRUE (`Call.swift:194`). FIX: `false` + `supportsGrouping=false`.
  ⚠️ **PLUGIN VARSAYILANI TRUE — yeni bir `Data(...)` uretilen HER yerde ACIKCA yaz.**
- ✅ **TURU 68 OLCUMU:** `CallKitService.holdDurumunuOlc()` — `activeCalls()` yanitindaki
  `supportsHolding`/`maximumCallGroups` Sentry'e yazilir (arama basina TEK).
  **TEST SONRASI BAK:** `callkit aktif arama (giden|gelen): adet=.. hold=.. grup=..`
  -> `hold=false` cikarsa deger CallKit'e ULASMIS demektir.
  ⚠️ **ERTELENDI (SON CARE, once olcume bak):** `maximumCallGroups 2 -> 1`.
  `maximumCallsPerCallGroup:1` ile birlikte toplam kapasite 1 olur ve ikinci
  `reportNewIncomingCall` **HATA donebilir** -> telefon CALMAZ + iOS 13 kurali ihlali
  (turu 33/67 "arama karsilanmiyor" semptomu geri gelir). OLCMEDEN UYGULAMA.
- ✅ **TURU 67 FIX'I TUTTU (kanit):** `Bad state: Cannot use "ref" after the widget was
  disposed.` hatasi Sentry'den **TAMAMEN KAYBOLDU** — "bitir sonrasi aramayi HIC
  karsilamama" kok nedeni cozuldu.
- **ONCEKI (4 Agu 23:55):** TEST TURU 67 YAYINLANDI — android 30949200253 +
  ios 30949203156 (e24e7d1), R2 apk=108238369 (md5 1cdad676) ipa=22352640 (md5 da21c05c),
  purge OK, **CDN birebir**, indir sayfasi 23:55, debug imza YOK, **backend DEGISMEDI**
  (19d0a96) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 67 — "BITIR DEDIKTEN SONRA GELEN ARAMAYI BAZEN KARSILAMIYOR" KOK NEDENI**
  (Sentry kaniti: `Bad state: Cannot use "ref" after the widget was disposed.`):
  ZINCIR: "Bitir ve kabul et" -> `leave()` -> `_svc.end()` -> `call_provider` `state=null`
  -> gelen-arama katmanini cizen kosul FALSE -> **WIDGET DISPOSE** -> hemen ardindan
  `_accept()` icindeki `ref.read(...)` PATLAR. O cagri **try blogunun DISINDA** oldugu icin
  **`answer` REST'i HIC GITMEZ**. "Bazen" = dispose ile `_accept` arasindaki YARIS.
  **FIX:** `_notifier` + `_ctrl` `initState`te BIR KEZ yakalanir (tum `ref.read`lar cevrildi).
  ⚠️ YAPMA: bu alanlari tekrar gec `ref.read`e cevirme; provider'lari `autoDispose` yapma;
  `call_provider`daki `state = null` yan etkisini kosullu yapma (turu 27-31 regresyonu).
  **IKINCI KAPI:** 3sn'lik durum yoklamasi `s != 'ringing'` gorunce ekrani kapatiyordu —
  kabul akisinda arama ZATEN 'active' oluyor. FIX: `if (_busy) return;` + answer basarili
  olunca yoklama IPTAL. **UCUNCU KAPI:** `catch` KOSULSUZ `end()` cagiriyordu -> `answer`
  OK'ten SONRAKI bir hata YENI KABUL EDILEN aramayi olduruyordu. FIX: `_cevaplandi` bayragi.
- ⚠️⚠️ **TURU 67 — "DONMA"NIN KOK NEDENI: KAPANIS ANIMASYONU BOS EKRANDA OYNUYORDU.**
  `_kapatOdayiKuyrugaKoy` `_room = null`i SENKRON yapiyordu; `notifyListeners()` cok sonra.
  220ms'lik solmanin ILK KARESINDE `c.room` null -> `_remoteVideo`/`_localVideo` null ->
  renderer'lar agactan SILINIYOR -> canli goruntu ANINDA kayboluyordu.
  **FIX:** mandal + timer iptalleri + yakalama SENKRON kalir; yalniz alan null'lama ve oda
  temizligi **260ms GECIKIR**. ⚠️ `identical(_room, room)` kapilari ZORUNLU (seri aramada
  YENI aramanin Room'unu null'lamasin — turu 54/59 sinifi). ⚠️ YAPMA: gecikmeyi
  `call_screen` dispose/pop tarafina tasima ("leave TEK KAPI" hukmu).
  **IKINCI SEBEP:** `await CallSounds.durdur(...)` ZAMAN ASIMSIZDI (`Vibration.cancel` +
  `player.stop`); takilirsa `arama=null` + `notifyListeners()` HIC calismaz, ekran son
  karede ASILI kalir -> 250ms timeout. ⚠️ YAPMA: `unawaited`a cevirme (yeni aramanin
  zilini keser — nesil jetonu).
- ⚠️⚠️ **TURU 67 — "GORUNTU GEC GIDIYOR": KAMERA TEARDOWN YARISI.** `_onizlemeAc()` hicbir
  kilit arkasinda DEGILDI; onceki aramanin `leave()` yolundaki `_onizlemeBirak()`
  (unawaited) HALA kosarken yeni onizleme kamerayi aciyordu. iOS'ta flutter_webrtc
  **TEK PAYLASILAN `videoCapturer`** tutar (turu 50 kok nedeni) -> iki capture birbirinin
  oturumunu CALAR. **FIX:** `_kameraKuyruguna` — acma/birakma TEK SLOTLUK zincire dizildi.
  ⚠️ YAPMA: bunu `CallRoomLock` ile yapma (GLOBAL kilit; `_onizlemeAc` icinde izin
  DIYALOGU var -> oda/yayin girisi kilitlenir). ⚠️ YAPMA: zinciri `await` edip `baslat()`i
  bloklama. `_onizlemeBirak` hatasi artik arama basina TEK Sentry olcumu.
- ⚠️⚠️ **OLCUM TUZAGI — `izin:NNNN` IZIN SURESI DEGILDIR (kendi teshisimi curuttum).**
  `_kurulumSaat` YALNIZ `baslat()`ta kuruluyor; GIDEN aramada `_connect()` ancak
  `call.answered` gelince kosar -> `izin` degeri **ZIL SURESINI de icerir**. Sahada
  gorulen `izin:3992` "izin 4 saniye surdu" ANLAMINA GELMEZ.
  ⚠️ YAPMA: `_kurulumSaat`i `_connect()` icinde yeniden baslatma (zil suresi bilgisi
  kaybolur, eski turlarla kiyas biter). Ayrim icin `giden` alani eklendi.
- ✅ **TURU 67 — BEKLETMENIN GORUNEN TUM KALINTILARI SILINDI:** main.dart `_heldSub`
  (WS `call.held` ALMA — karsi taraf ESKI surumdeyse turuncu serit YAPISIYORDU) ·
  controller `peer_held` uzlastirmasi · bant bekletme metinleri + "Devam et" dugmesi +
  park seridi + `_bandanDevamEt` + `_gsmUyarisiGoster`.
  ⚠️ `_holdSub` KALDI — kendi cihazimizdaki KACAK CallKit hold olayina karsi tek emniyet
  (artik aramayi BITIRIYOR). ⚠️ Backend `held_by`/`peer_held` + migration 013'e DOKUNULMADI
  (additive, turu 61).
- ⏳ **TURU 67 — YAPILMADI (durust not):** `call_screen.dart` bekletme paneli/rozeti ve
  controller'daki ~500 satirlik olu park zinciri (`ParkEdilenArama`/`parkEt`/`devamEt`/
  `beklemeyeAl`/`_medyaBeklet`/`_iosSesOturumuGarantile`/`GebzemSesKurtar`) HALA DURUYOR.
  Hepsi `bekletmeAcik=false` arkasinda **ULASILAMAZ** = kullaniciya GORUNMEZ.
  Toplu silme denendi, satir sinirlari yanlis hesaplandi, dosya bozuldu, `git checkout`
  ile geri alindi. ⚠️ **DERS: coklu-blok silmeyi script'le yapma — Edit ile TEK TEK ve
  her adimda `flutter analyze`.** Ayri turda yapilacak.
- **ONCEKI (4 Agu 22:48):** TEST TURU 66 YAYINLANDI — android 30943942830 +
  ios 30943945392 (c8a6c9d), R2 apk=**108238477** (md5 579cd292, KUCULDU = bekletme
  arayuzu gitti) ipa=22349753 (md5 49cd6b0e), purge OK, **CDN birebir**, indir sayfasi
  22:48, debug imza YOK, **backend DEGISMEDI** (19d0a96) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️⚠️ **TURU 66 — ARAMA BEKLETME KALDIRILDI (KULLANICI EMRI 4 Agu).**
  Kullanici: *"beklemeyi yapmayalim, arama geldiginde KABUL ET ve BITIR olsun."*
  **GEREKCE (uc turluk OLCULMUS kanit):** bekletmeden CIKIS iOS'ta BIZIM
  KONTROLUMUZDE DEGIL — turu 65 kaniti: CallKit unhold ediyor ama `didActivate`i HIC
  cagirmiyor; bizim aktive denememiz `!pri` (InsufficientPriority) ile REDDEDILIYOR.
  **TEK BAYRAK: `ActiveCallController.bekletmeAcik = false`** (kod SILINMEDI —
  CLAUDE.md "bayrakla kapat" kurali). Geri istenirse: bayrak + `supportsHolding`
  (Dart gelen+giden) + Swift `data.supportsHolding` UCU BIRLIKTE true.
  · CallKit `supportsHolding=false` + `maximumCallsPerCallGroup=1` -> iOS "Beklet ve
    Kabul" YERINE **"Bitir ve Kabul"** cizer (Gebzem VE hucresel aramalar icin).
  · GSM olayi -> `leave(notifyServer:true)`; `parkEt`/`beklemeyeAl` son savunma kapilari.
  ✅ **VoIP PUSH RISKI ELENDI (denetim, plugin kaynagi okundu):**
    `maximumCallsPerCallGroup=1` `reportNewIncomingCall`i ETKILEMEZ — plugin 3.1.3
    `Call.swift:191-194` VoIP push yolunda ZATEN 1 kullaniyordu; Dart'i 2->1 cekmek
    push yolunu DEGISTIRMEDI, HIZALADI. `supportsHolding` yalnizca CXCallUpdate susu.
    ⚠️ Bunu bir daha arastirma.
- ⚠️⚠️ **TURU 66b — DENETIM 3 SEVK ENGELI BULDU (biri HER aramayi olduruyordu):**
  · **EN AGIR:** `_connect` sonundaki SEVIYE kontrolu (turu 56 emniyet agi)
    `beklemeyeAl(id,true)` cagiriyordu; bekletme kapaliyken bu `leave()` demek ->
    **hucresel gorusme SURERKEN kurulan HER Gebzem aramasi KENDINI OLDURUYORDU**
    (yaris DEGIL, deterministik: `gsmDinle` oda baglantisindan once kosuyor).
    Ustelik OLEN, kullanicinin YENI KABUL ETTIGI aramaydi — emrin TERSI.
    FIX: `if (bekletmeAcik && PipService.gsmAramada.value && !beklemede)`.
    ⚠️ YAPMA: `bekletmeAcik` sartini kaldirma.
  · **YESIL "Beklet ve kabul et" DUGMESI EKRANDA KALMISTI** (yalniz govde
    degistirilmisti) -> basan kullanici "bekletiyorum" sanarken gorusme BITIYORDU.
    Bu Android'in BIRINCIL ikinci-arama arayuzu. FIX: dugme `bekletmeAcik` ile sarildi
    + "Önceki arama sonlandırıldı" bildirimi (rootMessengerKey — widget Navigator DISINDA).
    ⚠️ **DERS: bir ozelligi bayrakla kapatirken GOVDEYI degistirmek YETMEZ — o ozelligi
    CAGIRAN ARAYUZ de gizlenmeli, yoksa dugme SESSIZCE BASKA IS YAPAR.**
  · **CEVAPLANMAMIS GIDEN HUCRESEL CAGRI ARAMAYI OLDURUYORDU:** iOS kapisi
    `!c.isOutgoing && !c.hasConnected` idi (turu 64'te GERI DONULEBILIR bir eylem icin
    yazilmisti; artik geri donusu YOK). FIX iOS: `if !c.hasConnected { continue }`.
    FIX Android (native "baglandi" sinyali YOK): Dart'ta **2sn TEYIT** — kimlik SENKRON
    yakalanir, 2sn sonra hucresel HALA suruyorsa ve AYNI arama devam ediyorsa bitirilir.
    ⚠️ YAPMA: bu teyidi kaldirma; `isOutgoing` dalini geri ekleme.
- ⚠️⚠️ **YANILTICI SERH DUZELTILDI (gelecek denetimler icin):** "bekletme yokken turu 56
  GSM gizlilik acigi YAPISAL OLARAK IMKANSIZ" iddiasi **YALNIZ 1:1 ARAMA** icin dogru.
  `gsmDinle` YALNIZ arama akisinda (`_connect`) aciliyor; `features/rooms` ve
  `features/live` altinda `gsmAramada` **HIC OKUNMUYOR** ve `room_screen` `resumed`da
  mikrofonu KOSULSUZ geri aciyor. Bu acik turu 66'nin getirdigi DEGIL (turu 56'dan beri
  var). ⏳ **AYRI IS: oda/yayin icin GSM kapisi.**
- 📌 **ODA/YAYIN SIRASINDA GELEN ARAMA — MEVCUT DAVRANIS (koddan dogrulandi, kullanici sordu):**
  · Android + uygulama ON PLANDA: `call_provider.dart:173` `aramadaMi` true (`oda_`/`yayin`
    muhafizi) -> overlay HIC acilmaz, telefon CALMAZ.
  · iOS her zaman + Android arka plan: VoIP/FCM push gelir, CallKit **CALAR** (iOS 13
    kurali geregi raporlamak ZORUNLU; `callkit_service.goster`da mesguliyet kapisi YOK).
  · KABUL EDILIRSE: `mesgulMu(haric:)` `oda_`/`yayin` kaydini gorur -> `answer()` **null**
    -> `main.dart` `baskaIsleMesgul` -> `CallKitService.bitir` + `end` -> CallKit ekrani
    kapanir, **arayan "reddedildi" gorur**, oda/yayin sesi BOZULMAZ.
  · Turu 66 bu akisin HICBIRINI degistirmedi (oda/yayinin CallKit kaydi yok).
  ⏳ **ONERI (kullaniciya sunuldu, KARAR BEKLIYOR):** mikrofonu KAPALI olanda telefon
    CALSIN (oda dinleyicisi + yayin izleyicisi), konusmaci uyariyla, YAYINCI'da CALMASIN.
- **ONCEKI (4 Agu 21:51):** TEST TURU 65 YAYINLANDI — android 30939684916 +
  ios 30939688331 (7109a2c), R2 apk=108254861 (md5 **d7b16b8c**) ipa=22361701
  (md5 e266567b), purge OK, **CDN'den indirilen apk+ipa yerelle MD5 BIREBIR**,
  indir sayfasi saati 21:51, debug imza YOK, **BACKEND DEGISMEDI** (19d0a96'da kaldi)
  + health ok, DB temiz (0/0/0/0). **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 65 — "!pri" KANITI: ASIL KOK NEDEN ARTIK OLCULDU (tahmin DEGIL).**
  Turu 64'te ekledigim olcum sahada su olayi yazdi (4 Agu 18:02, arama d31f6fc5):
  `ses oturumu ACILAMADI (unhold): configOk=false hata=NSOSStatusErrorDomain#561017449`
  **561017449 = 0x21707269 = "!pri" = AVAudioSessionErrorCodeInsufficientPriority.**
  iOS diyor ki: *"ses oturumunu SEN aktive edemezsin, oncelik sende degil."*
  ⚠️⚠️ **BU BIR ZAMANLAMA SORUNU DEGIL, YETKI SORUNU** — tekrar denemek TEK BASINA
  COZMEZ. (Turu 64'un 3 basamakli merdiveni bu yuzden yetmedi.)
  **PLUGIN KAYNAGI OKUNDU** (flutter_callkit_incoming 3.1.3):
  · `provider(_:didActivate:)` (satir 775-779) AppDelegate'e **KOSULSUZ** iletiyor
    -> `aktif=false` olmasi "iletilmedi" degil, **"CallKit didActivate'i HIC CAGIRMADI"**.
  · `CXSetHeldCallAction` (719-732) ses oturumuna **DOKUNMUYOR**, yalnizca sahte bir
    "interruption ended" bildirimi atiyor.
  **YANI: hucresel arama bitince CallKit aramayi unhold ediyor ama SESI GERI VERMIYOR.**
  **FIX (kademeli):** (1) merdiven 3 -> 6 basamak (~11sn), (2) tukenirse SON CARE
  `GebzemSesKurtar`: `CXCallController` ile arama BEKLET + 400ms + DEVAM -> aktivasyonu
  Apple'in izin verdigi TEK sahip (CXProvider) yapar, `didActivate` zinciri BASTAN calisir.
  ⚠️ `CXCallController` STATIK olmali (asenkron istek boyunca yasamali).
  ⚠️ Iki istek arasi gecikme SART (CallKit birlestirip NO-OP yapabilir).
  ⚠️ YAPMA: kurtarmayi merdivenden ONCE calistirma; arama basina 1'den fazla denetme.
- ✅ **TURU 65 — "SES AVIZEDEN GELIYOR" (kullanici):** sunucu logunda SESLI aramada
  `rota=Speaker`. KOK: bekletmeden sonra iOS rotayi KENDI seciyor; Android'de
  `_androidSesTazele` geri uyguluyordu ama o metot **iOS'ta ERKEN DONER** — iOS'ta
  rotayi geri uygulayan **HICBIR SEY YOKTU** (bayrak/donanim celiskisi: hoparlor
  dugmesi "kapali" gorunurken donanim ACIK). FIX: `_sesYolunuGeriUygula()`
  (mic -> hoparlor sirasi). ⚠️ **SAGLIKLI DALDA DA CAGRILIR** — bekletmelerin COGU
  ilk denemede acilan daldan gecer; orada ciplak `return` vardi ve fix HIC devreye
  girmiyordu (denetimde yakalandi).
- ⚠️⚠️ **TURU 65b — DENETIM TURUN ASIL FIX'INI OLU KOD OLARAK YAKALADI (6 sevk engeli).**
  🔴 **KANAL UYUSMAZLIGI:** native `case "callkitSesKurtar"` **`gebzem/pip`** handler'ina
  yazilmisti, Dart ise `_audioCh` (**`gebzem/audio`**) uzerinden cagiriyordu ->
  `MissingPluginException` -> `catch (_)` yutuyor -> **kurtarma blogu HIC calismiyordu.**
  FIX: `PipService.callkitSesKurtar()` (mevcut `gsmDinle`/`gebzemAramaKaydet` deseni).
  ⚠️ **DERS: yeni bir native `case` eklerken HANGI KANALA yazdigini Dart cagirisiyla
  KARSILASTIR** — iki kanal var (`gebzem/audio` ve `gebzem/pip`) ve uyusmazlik
  derleme zamani YAKALANMAZ (`invokeMethod` string'i kontrol edilmez).
  · **KOR PENCERE:** bastirma penceresi cagridan ONCE ve KOSULSUZ aciliyordu; cagri
    her zaman basarisiz oldugu icin HER aramada 4sn kor pencere olusacakti.
    FIX: pencere yalniz istek BASARILI ise acilir, `finally` ile kapanir, callId'ye bagli.
  · **PARK SIRASI:** bastirma kapisi park dalinin USTUNDEYDI -> park edilmis aramaya
    gelen "devam" olayini yutup parki SONSUZA KADAR sikistirabilirdi (turu 54).
    FIX: park dali EN USTE.
  · **PARK KAPISI YOK:** `parkEt()` `arama`yi temizlemez/`beklemede` yazmaz, yalniz
    `_room`u null'lar -> kurtarma kapilari park edilmis aramada da GECIYORDU.
    FIX: `if (parkEdilen != null || _room == null) return;`.
  · **OLCUM YANLIS POZITIF:** kurtarma sonucu `getAudioState` ile olculuyordu ama o uc
    `configOk` DONDURMUYOR; merdivenin olcutu `active && configOk`. FIX: ayni yoldan
    (`_sesiAc`) yeniden olculur. (turu 60/61 olcum korlugu dersi)
- ⚠️ **TAMPON OLCUMU OLCEK HATASI:** `jitterBufferDelay` ORNEK-AGIRLIKLI; dogru bolen
  ornek SAYISI. livekit 2.5 `jitterBufferEmittedCount` acmadigi icin `sure x 48000`
  ile TAHMIN ediliyor (sahadaki `tamponMs=5510400` bu yuzdendi). ⚠️ Deger TAHMINI.
- **ONCEKI (4 Agu 20:30):** TEST TURU 64 YAYINLANDI — android 30933267247 +
  ios 30933270300 (19d0a96), R2 apk=108254861 (md5 **22aac748**) ipa=22358493
  (md5 fd7c8d44), purge OK, **CDN'den indirilen APK yerelle MD5 BIREBIR**, indir sayfasi
  saati 20:30, **BACKEND DEPLOY EDILDI** (19d0a96 + health ok + yeni `held_by` SQL'i
  canli DB'de EXPLAIN ile dogrulandi), DB temiz (0/0/0/0), debug imza YOK,
  iOS deployment target 16.0 korunuyor. **KULLANICI TEST EDECEK.**
  ⚠️ **APK BOYUTU TURU 63 ILE BIREBIR AYNI CIKTI (108254861) ama MD5 FARKLI**
  (63: `2b466ce4` -> 64: `22aac748`). "Boyut ayni = build eski" DEME kurali yine dogrulandi.
  ⚠️ IPA BUYUDU (22349602 -> 22358493) = yeni Swift (`GebzemGsmGozcu`) DERLENDI kaniti.
- ⚠️⚠️ **TURU 64 — "GSM SONRASI SES GITMIYOR" KOK NEDENI OLCUMLE KANITLANDI.**
  Kullanici (3 Agu gecesi) uc sikayet bildirdi; 25 ajanlik kok-neden + 23 ajanlik
  adversaryal denetim kosuldu. **Sunucu logu + Sentry, arama `be27eed9`:**
  · 21:11:24 iOS bekletti -> `POST /hold` 200, Android `call.held on=true` ALDI ✓
  · 21:11:37 unhold -> 200, Android `on=false` ALDI ✓
  · 21:11:38+ iOS: **`iOS[acik=true aktif=FALSE]`** · `recv delta=100` (INIS SAGLAM)
    · `sent sdelta=0` `mikE=0.0` -> **MIK-OLU-SENT0**. Sunucu `KURTARMA=sent0` denedi, olmadi.
  **Yani sinyal/sunucu/LiveKit CALISTI; bozulan tek sey iOS YEREL SES GIRISI.**
  **KOK-A:** bekletmede CallKit `didDeactivate` ile oturumu kapatir; unhold'da simetrik
  `didActivate` **GELMEYEBILIR** — `flutter_callkit_incoming`in `CXSetHeldCallAction`
  isleyicisi ses oturumuna DOKUNMAZ, yalnizca SAHTE bir "interruption ended" atar
  (plugin 3.1.3, `SwiftFlutterCallkitIncomingPlugin.swift:719-731`). Geriye kalan TEK
  aktivasyon denemesi bizim `_sesiAc(true)`imizdi ve GSM hatti kaynagi BIRAKMADAN
  kostugu icin patliyordu. `AppDelegate.swift` `setConfiguration(active:true)` hatasi
  **YALNIZ NSLog'a** yaziliyor, `result(nil)` ile Dart'a **KOSULSUZ BASARI** donuyordu.
  ⚠️ **AYNI YARISIN ANDROID KANITI:** `ses tazelendi: oncekiMod=2` (= MODE_IN_CALL) —
  biz tazelerken telefon HALA hatti tutuyordu.
  **FIX:** native artik `{configOk,hata,enabled,active}` DONDURUR; yeni
  `_iosSesOturumuGarantile` 200/600/1200ms artan araliklarla TEKRAR dener, basarinca
  mikrofonu YENIDEN uygular, olmazsa **arama basina TEK** Sentry GERCEK olayi yazar.
  ⚠️ YAPMA: hatayi tekrar yutma; `result`u `nil`e dondurme; FAZ-7'nin "zorla toggle"ini
  kaldirma (ilk arama sessizligi geri gelir); `_sesiAc`i ISTISNA FIRLATIR yapma
  (`_connect` await ediyor, catch `_svc.end` ile SAGLIKLI aramayi oldurur).
- ⚠️⚠️ **TURU 64 — iOS'TA HUCRESEL ARAMA KORLUGU (kullanici: "iPhone'da bekletme
  gorunmedi, Android'de devam et/iptal yoktu").** `gsmAramada` bayragini yazan TEK
  kaynak Android `TelefonDurumu.kt` idi; `gsmDinle` iOS'ta **kosulsuz false** donuyordu.
  CallKit yalniz **GELEN** hucresel aramada bizimkini bekletir — kullanici **KENDISI
  arama YAPINCA** hicbir olay gelmez. Turu 63'un "Devam et" GSM kapisi iPhone'da
  **OLU KODDU**. **FIX:** `GebzemGsmGozcu` (CXCallObserver, AppDelegate.swift dosya
  kapsaminda — ⚠️ pbxproj'a AYRI dosya EKLENMEDI, BOM tuzagi).
  ⚠️⚠️ **FILTRE HAYATI ONEM TASIR:** kendi CallKit aramalarimiz da bu listede gorunur;
  filtresiz birakilirsa uygulama KENDI aramasini beklemeye alir.
  · Defter `bizimAramalar`; `gsmDinle(true, callId:)` gozcu BASLAMADAN ONCE doldurur.
  · ⚠️⚠️ **iOS'TA GELEN ARAMA DART'TAN KAYDEDILEMEZ** — `CallKitService.goster`
    iOS'ta CAGRILMAZ (`call_provider.dart` IKI yerde `if (Platform.isIOS) return;`);
    gelen arama VoIP push ile **native `pushRegistry` icinde** olusur. Bu yuzden
    `aramaEkle` HER IKI `showCallkitIncoming` cagrisinin **ONUNE** konur.
    ⚠️ YAPMA: bu satirlari closure'in ICINE veya cagrinin ALTINA tasima (CXCall SENKRON olusur).
  · ⚠️ **RINGING KURALI (turu 62'nin iOS karsiligi):** `if !c.isOutgoing &&
    !c.hasConnected { continue }` — yalniz BAGLANMIS ya da GIDEN arama bekletme baslatir.
    GIZLILIK KORUNUR: suren GSM zaten `hasConnected`, ikinci cagri calarken de sayilir.
  · ⚠️ **SILME ASLA YENI YABANCI URETMEZ:** `aramaSil` icinde `degerlendir()` YOK
    (`CallKitService.bitir` silmeyi `endCall`in ONUNDE, `parkiDusur` ise AKTIF ARAMA
    SURERKEN yapiyor). Defter temizligi `callObserver`daki `hasEnded` dalinda.
  · ⚠️ Gozcu kanali **WEAK OLAMAZ** (GebzemPip ile ayni tuzak).
  · Dart'ta IKINCI suzgec: `PipService.gsmYabanciId` == kendi callId ise olay YOK SAYILIR.
    ⚠️ NOT: bu suzgec "ikinci GEBZEM aramasi" vakasini YAKALAMAZ — onu native defter kapatir.
- ⚠️⚠️ **TURU 64 GIZLILIK (turu 56/63 acigina UC YENI KAPI — denetimde yakalandi):**
  (a) `_iosSesOturumuGarantile`: kapilar `_sesiAc` await'inin ONUNDEYDI, mikrofon acilisi
  ARKASINDA -> await sirasinda GSM baslarsa mikrofon acilir ve `beklemeyeAl`
  `beklemede==aktif` kapisinda erken donecegi icin **bir daha KAPANMAZ**. Kapilar await
  SONRASI tekrar okunur, hedef DURUMDAN turetilir.
  (b) `devamEt`: `_medyaBeklet(..., false)` mikrofonu KOSULSUZ aciyordu, GSM kontrolu
  metodun SONUNDAYDI; arada `setSpeakerOn` + `_androidSesTazele` (native stop/start +
  120ms) var -> **yuzlerce ms canli sizinti**. Karar (`gsmVar`) artik MEDYADAN ONCE.
  ⚠️ YAPMA: oraya `return` koyma (turu 54 park sikismasi) — karar DEGERE donusur.
  (c) Park seridi (turuncu) `devamEt()`i **GSM KAPISIZ** cagiriyordu. Uc "devam" yolu
  (call_screen · yesil bant · park seridi) artik AYNI `_gsmUyarisiGoster()` kapisindan gecer.
  ⚠️ YAPMA: yeni bir "devam" yolu eklerken bu kapiyi unutma.
- ✅ **TURU 64 DIGER:** `devamEt` unhold sinyali medyanin ONUNE (kardes `beklemeyeAl`
  turu 60'ta duzeltilmisti, bu ATLANMISTI) + await'ler arasi kimlik kapisi ·
  `hold()` **per-callId son-karar kapisi** (3 kor tekrar hold/unhold yarisi uretiyordu) ·
  backend `held_by` artik `AND (held_by IS NULL OR held_by=$2)` ·
  `_birimYenidenKur` basina `if (_ayrildi || beklemede) return;` (GSM'de mikrofon aciyordu) ·
  **`devamEt`e `_statsBaslat()` GERI KONDU** — `parkEt` timer'i iptal ediyor, geri kuran
  YOKTU: park/devam sonrasi ses olcumu VE olu-mik OTO KURTARMASI arama boyunca OLUYDU.
  ⚠️ ERTELENDI: migration 014 + `hold_seq` (tek turda sema+deploy riski, kazanc orantisiz).
- ⚠️⚠️ **TELEMETRI DUZELTMESI — TURU 63'UN "JITTER HIPOTEZI CURUDU" HUKMU GECERSIZ.**
  `tamponDeltaMs` ham `jitterBufferDelay` farkiydi; `totalSamplesDuration`a BOLUNMEDIGI
  icin **ms DEGILDI** (ayrica `jitter` bambaska bir metriktir). Negatif degerlerin
  (`-199939200`, `gizlenenOrnek=-2128`) sebebi: olcum tabanlari arama basinda
  SIFIRLANMIYORDU. `recvDelta` de gecen sureye bolunmuyordu (arka planda Timer BOGULUR).
  FIX: `tamponMs = delta(jitterBufferDelay)/delta(totalSamplesDuration)*1000`, bolen<=0 ise
  olcum GONDERILMEZ; `recvPaketSn` gercek tik suresiyle; tabanlar `baslat()`ta sifirlanir.
  ⚠️ Ses gecikmesi konusu KAPALI DEGIL — dogru metrikle tekrar bakilacak.
- 📌 **SUREC DERSI (turu 59b'nin TEKRARI — bu adimi ASLA atlama):** kod yazilip
  `go build`+`flutter analyze` gectikten SONRA kosulan adversaryal denetim, kendi
  turu 64 kodumda **YUKSEK bir regresyon** (E1) buldu. Build ALINMADAN yakalandi.
- 📌 **TEKRARLAYAN DESEN (turu 50·56·60·63·64 — CLAUDE.md'ye kalici not):** bu hatalarin
  ORTAK koku karmasiklik degil, **YUTULAN HATA + BREADCRUMB-ONLY LOG**. Yeni bir hata
  yolu yazarken sor: "bu patlarsa TELEMETRIDE gorur muyum?" Cevap hayirsa once olcumu koy.
- 📌 **IKINCI DESEN:** bir yol icin yazilmis primitif BASKA yola baglanirsa dogrulugu
  ORADA TEKRAR sorgula (FAZ-7'nin arama-BASLANGICI ses fixi, turu 56'da bekletme yoluna
  baglaninca YIKICI oldu).
- **ONCEKI (3 Agu 02:05):** TEST TURU 63 YAYINLANDI — android 30771106968 +
  ios 30771107969 (5187fc8), R2 apk=108254861 (md5 2b466ce4) ipa=22349602 (md5 d322b588),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 02:05,
  **BACKEND DEPLOY EDILDI** (5187fc8) + health ok + canli dogrulama
  (`{"error":"telefon veya şifre hatalı"}` — Turkce duzeltmeler SUNUCUDA), DB temiz.
  **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 63 — "DEVAM ET" GSM KAPISI (YENI GIZLILIK ACIGI KAPATILDI):**
  Kullanici sordu: "devam et dedigimde GSM aramasini kapatmasi gerekmiyor mu?"
  **CEVAP: KAPATAMAYIZ** — Android ucuncu parti uygulamanin hucresel aramayi
  sonlandirmasina IZIN VERMEZ (`TelephonyManager.endCall()` API 29'da KALDIRILDI;
  `MODIFY_PHONE_STATE` sistem izni). iOS'ta da imkansiz. ⚠️ Bunu bir daha arastirma.
  **ASIL BULGU (kullanicinin sorusu sayesinde):** GSM gorusmesi SURERKEN "Devam et"e
  basilinca Gebzem mikrofonu geri aciliyordu -> **KARSI TARAF GSM KONUSMASINI
  DUYABILIYORDU.** Ustelik bir daha otomatik bekletilmiyordu: `gsmAramada` bir
  ValueNotifier ve yalniz DEGISIMDE tetiklenir; GSM zaten "suruyor" durumunda oldugu
  icin yeni olay gelmez ve mikrofon GSM BOYUNCA ACIK kalirdi. Turu 56 aciginin BASKA kapisi.
  **FIX (kullanici karari — zorlama YOK):** kisa profesyonel aciklama gosterilir,
  bekletme SURER: "Telefon görüşmeniz sürüyor. Önce onu sonlandırın; Gebzem araması
  kaldığı yerden devam edecek." GSM bitince ZATEN kendiliginden devam eder.
  ⚠️ YAPMA: bu kapiyi kaldirma; GSM surerken elle devam ettirmeye izin verme.
- ✅ **TURU 63 — TURKCE KARAKTER SUPURGESI: 204 DUZELTME** (13 ajan tarama+denetim).
  Dagilim: backend 132 · auth 42 · calls 19 · chats/rooms 9 · core 2.
  Ornek: Caliyor->Çalıyor · Mesgul->Meşgul · Sifre->Şifre · Giris Yap->Giriş Yap ·
  "gecersiz istek"->"geçersiz istek" (sunucu hatalari SnackBar'da GORUNUYOR).
  ⚠️ **UYGULAMA GUVENLIGI (bir daha ayni yontemi kullan):** once KURU CALISMA ile her
  `eski` metnin dosyada BIREBIR var oldugu dogrulandi (204/204, 0 kayip); uygulayici
  ayrica YENI metinde Turkce karakter YOKSA degisikligi ATLAR.
  ⚠️ DOKUNULMAYANLAR: yorumlar (bilerek ASCII — CLAUDE.md regex/encoding tuzagi) ·
  protokol dizeleri (`call:ended:audio`, `oda_`, `yayin`) · JSON alan adlari ·
  MethodChannel adlari · Sentry/log mesajlari (gelistirici icin).
- ✅ **TURU 63 — SOHBETTEKI ARAMA BALONU (kullanici ekran goruntusu: Messenger):**
  yuvarlak ikon + baslik + saat, ALTINDA tam genislikte **"Geri ara"** dugmesi.
  Cevapsizda daire KIRMIZI dolu, baslik "Cevapsız sesli/görüntülü arama".
  "Geri ara" -> alttan "Sesli ara / Görüntülü ara" paneli.
- ⏳ **SES GECIKMESI — OLCUME BAGLANDI (kullanici: "gecikme NORMALDE OLMUYOR, biri GSM
  aradiktan SONRA devam ettikten sonra oluyor"):** bu tarif jitter tamponu hipoteziyle
  BIREBIR uyusuyor (kesintide paketler birikir, devam edince birikmis ses calinir).
  Bekletmeden CIKISTAN 5sn sonra TEK SEFER Sentry olcumu:
  `devam sonrasi ses: jitterMs=.. tamponDeltaMs=.. gizlenenOrnek=.. recvDelta=..`
  **TEST SONRASI BAK** — degere gore hedefli duzeltme yapilacak.
  ⚠️ YAPMA: bu olcumu her istatistik tikinda gondermeye cevirme (Sentry gurultusu).
- **ONCEKI (3 Agu 01:18):** TEST TURU 62 YAYINLANDI — android 30769340134 +
  ios 30769341238 (05ec544), R2 apk=108254861 (md5 d29009c4) ipa=22344495 (md5 f240450f),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 01:18,
  **backend DEGISMEDI** (8276219'da kaldi) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 62 — UC SORUN + TUM ARAYUZ IKONLARI 2B'YE CEVRILDI**
  **(A) GSM ZIL ≠ KABUL (kok neden):** `TelefonDurumu.bildir()` karari
  `durum != CALL_STATE_IDLE` ile uretiyordu; sabitler IDLE=0/RINGING=1/OFFHOOK=2 —
  telefon SADECE CALARKEN de bekletme basliyordu. Kullanici reddederse/kacirirsa
  Gebzem bos yere kesilip geri aciliyordu.
  **YENI TABLO:** `OFFHOOK -> BEKLET` · `IDLE -> DEVAM` · `RINGING -> KARAR DEGISMEZ (latch)`.
  ⚠️⚠️ **RINGING NEDEN `false` DEGIL:** Android `CALL_STATE_RINGING`i "zaten aktif
  gorusme varken IKINCI cagri geldi" (GSM cagri bekletme) durumunda DA uretir. `false`
  yazsaydik SUREN GSM gorusmesinin ORTASINDA mikrofonu geri acardik ve karsi taraf GSM
  konusmasini DUYARDI — turu 56 GIZLILIK aciginin aynisi.
  ⚠️ `dur()` icinde `sonBildirilen` DE sifirlanir (ZORUNLU — nesne aramalar arasi yasiyor;
  yoksa GSM SURERKEN yeni arama baslayinca OFFHOOK olayi YUTULUR, mikrofon ACIK kalir).
  ⚠️ YAPMA: RINGING dalini `false` yapma; `sonBildirilen` sifirlamasini kaldirma.
  **(B) UYARI SERIDI SURENIN ALTINA ALINDI** (kullanici emri: "pil seviyen dusuk —
  bu butonlar zamanin altina olmali").
  ⚠️⚠️ `Flexible` sarmali KALDIRILDI — ZORUNLU: turu 60'ta bu Padding bir ROW cocuguyken
  `Flexible` DOGRUYDU; COLUMN cocugu olunca DIKEY eksende esner ve Column'un yuksekligi
  SINIRSIZ oldugu icin RenderFlex ASSERTION ile PATLAR (kirmizi ekran).
  ⚠️ YAPMA: buraya Flexible/Expanded koyma.
  **(C) "BEKLETMEDEN SONRA SES ARKADAN GELIYOR" (kok neden):** Android'de ses MODU
  (MODE_IN_COMMUNICATION), AUDIO FOCUS ve cihaz secimi YALNIZCA flutter_webrtc'nin
  `AudioSwitch.activate()` gecisinde uygulanir; o gecis `AudioSwitchManager.start()`in
  `if (!isActive)` kilidiyle korunur ve `isActive` ARAMA BOYUNCA true takilidir. GSM
  bitince Android modu MODE_NORMAL'a dondurur + cihaz secimini temizler -> ses kulaklik
  yerine HOPARLORDEN calar. Geri alan HICBIR SEY yoktu.
  **FIX:** native `sesOturumunuTazele` -> `AudioSwitchManager.stop()` + `start()`.
  ⚠️⚠️ **`stop(); start()` ARKA ARKAYA CAGRILIRSA CALISMAZ** (kaynak okunarak bulundu):
  ikisi de `handler.removeCallbacksAndMessages(null)` yapar, yani `start()` `stop()`un
  kuyruga koydugu `deactivate` isini SILER; `isActive` true kalir ve `activate()`
  `if (!isActive)` kapisinda NO-OP olur. `start()` BIR SONRAKI dongu turunda
  (postDelayed 120ms) cagriliyor. ⚠️ YAPMA: bu gecikmeyi kaldirma.
  ⚠️ YAPMA: `am.mode`u KENDIMIZ yazma (Activity'nin AudioManager'i AYRI istemcidir;
  birakan kod olmadigi icin MODE_IN_COMMUNICATION SIZAR).
  ⚠️ Dart'tan `setAndroidAudioConfiguration` YETMEZ — kaynak okundu: `setAudioMode`
  yalniz DEGERI saklar, uygulamayi `activate()` yapar.
  **(C-2)** `_androidSesTazele` AYNI degeri yaziyordu -> alt katman fark-kontrolunde
  ERKEN DONUP NO-OP kaliyordu. Artik once TERS deger, sonra dogrusu. ⚠️ AMA KULAKLIK
  KAPISI VAR: `setSpeakerOn(true)` BT/kablolu kulakligi YOK SAYIP hoparloru secer;
  kulaklikta ara deger olarak hoparlor secmek SCO'yu koparir + ses patlatir.
  ⚠️ YAPMA: kulaklik kapisini kaldirma; toggle'i kosulsuz yapma.
  **(C-3)** `devamEt()` `_speakerOn`i geri yuklemiyordu -> park edilmis SESLI arama,
  uzerine gelen GORUNTULU arama bitince HOPARLORDEN aciliyordu. `ParkEdilenArama
  .speakerOn` eklendi; bayrak await'lerden ONCE senkron, ROTA `_medyaBeklet` sonrasi +
  `_sesiAc(true)` ONCESI (CLAUDE.md iOS ses sirasi hukmu).
  **OLCUM:** `ses tazelendi: oncekiMod=N ...` GERCEK Sentry olayi. `oncekiMod=0`
  (NORMAL) -> teshis DOGRU; `=3` (IN_COMMUNICATION) -> mod bozulmuyor, baska yerde ara.
- ✅ **TURU 62 — ARAYUZDE EMOJI KALMADI (kullanici emri: "hicbir 3B ikon istemiyorum").**
  Emoji sistem emoji fontuyla (Apple Color Emoji / Noto Color Emoji) PARLAK ve 3B cizilir
  — 3B gorunumun kaynagi buydu. 35 arayuz noktasi Lucide (2B cizgi) ikona cevrildi:
  bekletme rozeti · sohbet listesi onizlemeleri (ayri `_previewIkon()`) · silinen mesaj ·
  canli yayin izleyici/jeton sayaclari · kesfet listesi · oda basliklari · host taci ·
  kalp animasyonu · kalan 3 Material ikon da Lucide'a.
  ⚠️ YAPMA: arayuze emoji geri koyma (metin ICINE de). Yeni ikon gerekirse Lucide.
  ⏳ **HEDIYE SIMGELERI BILINCLI BIRAKILDI:** sunucudan geliyor (`v['emoji']`), 30
  hediyelik katalog backend'de emoji olarak tanimli. Cevirmek ARAYUZ degil URUN
  degisikligi (katalog + backend + animasyonlar). **KULLANICI KARARI BEKLENIYOR.**
- **ONCEKI (3 Agu 00:07):** TEST TURU 61 YAYINLANDI — android 30766687222 +
  ios 30766688233 (8276219), R2 apk=108254021 (md5 1e589c3e) ipa=22344434 (md5 776ce510),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 00:07,
  **BACKEND DEPLOY EDILDI** (8276219; migration 013 uygulandi, `calls.held_by` sutunu
  canli DB'de DOGRULANDI) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 61 — KAYBOLAN `call.held` OLAYI SENTRY ILE KANITLANDI (tahmin DEGIL).**
  Turu 60'ta ekledigim olcum kok nedeni KANITA cevirdi. Kullanici testi (Android GSM
  bekletme, karsi taraf iPhone) — Sentry olaylari:
  · `20:48:04  gsm olayi: gsm=true  beklemede=false platform=android`  <- Android BEKLETTI
  · `20:48:32  gsm olayi: gsm=false beklemede=true  platform=android`  <- 28sn sonra kaldirdi
  · `20:48:35  call.held alindi: on=false eslesti=true ekran=true`     <- iPhone SADECE bunu aldi
  **`call.held alindi: on=true` olayi HIC YOK.** Android gonderdi, sunucu 200 dondu, ama
  iPhone o 28 saniye boyunca HICBIR SEY ALMADI. Ustelik `ekran=true` — arama ekrani ACIKTI.
  **KOK NEDEN:** `call.held` KAYBOLABILIR bir olaydi (ne kuyruk, ne tekrar, ne sunucu
  durumu). Istemci HER arka plana geciste WS'i kapatir (`bg` cercevesi; kilit ekraninda
  arama caldirmak icin ZORUNLU — turu 33) ve iPhone 47 dakikada 27 kez kopup baglaniyor.
  Olay o bosluga denk gelirse BIR DAHA ogrenilemiyordu.
  ⚠️ Turu 60 denetiminde ajanlar bunu **DUSUK** derecelendirmisti; SAHA VERISI ASIL SEBEP
  oldugunu gosterdi. **DERS:** "nadir gorunuyor" != "onemsiz"; olcum koyup BAKMAK sart.
  **FIX (durum sunucuda, istemci KENDINI ONARIR):**
  · migration **013**: `calls.held_by UUID` (en son beklemeye alan; cikinca NULL).
  · `Hold` handler: on=true -> `held_by=$user`; on=false -> yalniz KENDI kaydini siler
    (`AND held_by=$user`) ki karsi tarafin bekletmesi silinmesin.
  · `Status` ucu additive **`peer_held`** doner. ⚠️ `elapsed_ms` semantigine DOKUNULMADI.
  · Istemci `_durumKontrol` (ZATEN var olan **3sn'lik** yoklama) `peer_held` ile uzlastirir
    -> yeni trafik YOK, yeni uc YOK, yeni bagimlilik YOK.
  · WS olayi HIZLI YOL olarak KALIR (aninda tepki); yoklama EMNIYET AGI.
  ⚠️ YAPMA: `Hold`daki UPDATE'i kaldirip yalniz WS'e donme; `peer_held` uzlastirmasini
  istemciden cikarma; `held_by`yi grup aramasi acilirsa tek-kisi varsayimiyla kullanma.
- **ONCEKI (2 Agu 20:52):** TEST TURU 60 YAYINLANDI — android 30759365570 +
  ios 30759366701 (1159115), R2 apk=108254021 (md5 6562395b) ipa=22344917 (md5 6aa52c46),
  purge OK, CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 20:52,
  **backend DEGISMEDI** (db7e8a8'de kaldi) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 60 — "ANDROID GSM BEKLETMESI KARSI TARAFA GITMIYOR": ROZET CIZILIYORDU
  AMA EKRANDAN TASIP KIRPILIYORDU** (15 ajanlik kok-neden arastirmasi).
  🔴 **ILK HIPOTEZIM CURUTULDU:** "Android hold gondermiyor" YANLISTI. Mikrofon-enerjisi
  korelasyonuyla KANITLANDI: hold POST'uyla ES ZAMANLI olarak Android cihazin mikrofon
  enerjisi 0.0'a dusuyor, hold-off'ta geri geliyor; ayni anda iOS tarafi konusuyor.
  19 hold'un 6'si ANDROID, 6'si iOS, 7'si park (cagri bekletme) yolundan.
  **Android GSM zinciri CALISIYOR — sorun GONDERMEDE degil GORUNMEDE idi.**
  **KOK NEDEN:** bekletme rozeti DIKEY yigin icin yazilmisti (`top: 6` payi ele veriyor)
  ama bir `Row`un cocuguydu. Row'un hicbir cocugu `Flexible` degil -> RenderFlex hepsini
  SINIRSIZ genislikle olcer, Row ise `Positioned(left:0,right:0)` ile EKRAN GENISLIGINE
  tutturuludur. Karsi taraf GSM'i kabul edince uygulamasi arka plana gecer -> `karsiKalite`
  duser -> `uyariMetni` ("X baglantisi zayif") DOLAR (o kapi `!c.beklemede`ye bagli, yani
  KARSI tarafta ACIKTIR) -> sure + uyari + rozet ~490px, ekran 360-414px -> rozet sagdan
  TASAR ve ust `Stack` (varsayilan `Clip.hardEdge`) KIRPAR.
  **Rozet CIZILIR ama EKRANDA GORUNMEZ.**
  **FIXLER:** (1) rozet Row'dan CIKARILDI -> ust Column'un dogrudan cocugu; tam genislikte,
  14px kalin, ortali turuncu serit. ⚠️ YAPMA: rozeti tekrar o Row'un icine koyma.
  (2) bekletme aktifken uyari seridi BASTIRILDI (`!c.karsiBeklemede` eklendi) — hem
  yaniltici (sebep ag degil, bekletme) hem tasmaya katki.
  (3) uyari seridi `Flexible` ile sarildi: icindeki `Flexible` OLU KODDU (dis Row'un flex
  OLMAYAN cocugu -> sinirsiz kisit -> ellipsis HIC calismiyordu; turu 23'un "uzun uyari
  metni tasiyor" duzeltmesi fiilen TUTMAMIS). ⚠️ YAPMA: bu Flexible'i kaldirma.
  (4) `_svc.hold` MEDYANIN ONUNE alindi — eskiden UC await ve IKI kimlik kapisinin
  ARKASINDAYDI; unhold yolunda bir kapi tetiklenirse karsi taraf SONSUZA KADAR
  "beklemede" kaliyordu (temizleyecek baska yol YOK). ⚠️ YAPMA: await'lerin altina tasima.
  (5) `hold()` REST: hata TAMAMEN yutuluyordu (`catch (_) {}`) + TEK deneme -> 3 deneme
  (artan aralik) + basarisizsa Sentry olcumu. ⚠️ YAPMA: sessiz yutmaya donme.
  (6) bekletme bilgisi KUCULTULMUS aramada da gorunuyor (yesil bant). Rozet yalniz
  CallScreen agacindaydi; GSM konusurken Gebzem arka planda oldugu icin kullanicinin
  BAKTIGI yerde hicbir gosterge YOKTU.
  (7) **IKI OLCUM KORLUGU KAPATILDI:** GSM olayi ve `call.held` alimi artik GERCEK Sentry
  olayi. Ikisi de `_sesLog` = yalniz BREADCRUMB idi; breadcrumb ancak baska bir olayla
  yuklenir, bu yuzden 4 turdur telemetriyle KANITLAYAMIYORDUK (turu 50 ile ayni tuzak).
  ⚠️ YAPMA: bunlari tekrar breadcrumb'a cevirme.
  🚫 **AJANLARIN ELEDIGI COZUMLER — TEKRAR ONERME:**
  · hold icin PUSH YEDEGI -> iOS'ta VoIP push = HAYALET GELEN ARAMA ekrani (CLAUDE.md
    "reportNewIncomingCall KOSULSUZ" kurali).
  · `calls` tablosuna `held_by` sutunu -> GRUP icin YANLIS model (ayni anda birden fazla
    kisi beklemede olabilir) + handler'in acik tasarim kararini tersine cevirir.
  · wakelock / ekrani-acik-tut -> projede YAKINLIK SENSORU YOK; sesli aramada yanak
    dokunuslari dugmelere basar + pil akar (WhatsApp TAM TERSINI yapar: ekrani karartir).
  · WS'i arama boyunca acik tutmak -> turu 33: yari-acik soket yuzunden push atilmiyor,
    telefon CALMIYOR.
- **ONCEKI (2 Agu 19:05):** TEST TURU 58+59 YAYINLANDI — android 30755334616 +
  ios 30755335791 (db7e8a8), R2 apk=108254021 (md5 7d33c2d6) ipa=22342407, purge OK,
  CDN'den indirilen APK yerelle MD5 BIREBIR, indir sayfasi saati 19:05 gorunuyor,
  **BACKEND DEPLOY EDILDI** (db7e8a8, health ok, yeni SQL canli DB'de test edildi),
  DB temiz (0/0/0/0). **KULLANICI TEST EDECEK.**
  ⚠️ APK boyutu bir onceki (yayinlanmayan) build ile BIREBIR AYNI cikti — MD5 farkli.
  "Boyut ayni = build eski" DEME kurali yine dogrulandi.
- ⚠️⚠️ **TURU 59b — BUILD ALINDIKTAN SONRA, YAYINDAN ONCE 19 AJANLIK ADVERSARYAL
  DOGRULAMA KOSULDU ("bu fixler YANLIS, kanitla") ve KENDI TURU 59 FIX'IMDE YUKSEK
  REGRESYON BULDU. Ilk build YAYINLANMADI, kod duzeltilip YENIDEN build alindi.**
  · **(1)(2) YUKSEK — IKI BAGIMSIZ AJAN AYNI HATAYI BULDU:** `nav.pop()` EN USTTEKI
    route'u kapatir, "beni" DEGIL. Turu 59'un (5) numarali fix'i bayat ekrani pop
    akisina DUSURDUGU icin, ustunde duran YENI aramanin **CANLI ekranini OLDURUYORDU**
    (bayat yasar, canli olur — sorunu TERSINE cevirmisti).
    **FIX:** arama hala yasiyorsa `ModalRoute.of(context)` + `removeRoute` ile YALNIZ
    KENDI route'umuz kaldirilir (animasyonsuz); ustteki ekrana DOKUNULMAZ.
    ⚠️ YAPMA: buraya kosulsuz `nav.pop()` geri koyma.
    **DERS:** "kendi ekranimi kapat" niyetiyle `Navigator.pop()` yazmak, ekran YIGINDA
    en ustte DEGILSE baskasini kapatir. Route'u ADRESLE.
  · **(8) ORTA — "siyahi `barrierColor` sagliyor" PREMISIM YANLISMIS:** Flutter'da
    `barrierColor` SABIT DEGIL, route animasyonuyla saydamdan renge gider
    (`AnimatedModalBarrier`). Container'i kaldirinca gecisin ortasinda arama ekrani
    YARI SAYDAM oluyor, ALTTAKI SAYFA ICINDEN gorunuyordu.
    **FIX:** siyah zemin `ColoredBox` olarak FADE'IN ICINE alindi.
    ⚠️ YAPMA: `ColoredBox`u kaldirip yalniz `barrierColor`a guvenme.
  · **(3) ORTA — KIMLIK TAKLIDI ACIGI (beklenmedik bulgu):** backend `SendMessage`
    mesaj TIPINI HIC dogrulamiyordu; DB CHECK 'system'e izin verdigi icin HERHANGI
    BIR KULLANICI `{"type":"system","content":"Gebzem Destek: hesabiniz askiya
    alindi..."}` gonderip karsi tarafta **gonderen adi/avatari/tiki OLMAYAN**, sunucu
    uretimi gibi gorunen satir cizdirebiliyordu.
    **FIX:** TIP BEYAZ LISTESI (text/image/video/audio/location). 'system' YALNIZ
    sunucunun kendi yazdigi arama kayitlari icin (calls paketi dogrudan INSERT eder).
    ⚠️ YAPMA: beyaz listeye 'system' ekleme. Ayrica iki istemci cagirani da ham
    icerik yerine notr "Sistem mesajı" basiyor.
  · **(4) DUSUK:** `End()` mutex UPDATE'i istek-omurlu `r.Context()` kullaniyordu —
    istemci tam o anda kapanirsa Postgres COMMIT etse bile pgx iptal hatasi doner,
    handler 500 yazip cikar, balon HIC yazilmaz (webhook da satiri 'ended' buldugu
    icin telafi edemez). Artik ayri, 5sn zaman asimli context.
    ⚠️ YAPMA: burayi `r.Context()`e dondurme.
  · **(5) DUSUK:** sohbet listesi onizlemesi ARAYANA da "Cevapsız" diyordu. Sunucu
    listede gondereni DONDURMUYORDU -> `last_sender_id` eklendi (SELECT + Scan sirasi
    birebir dogrulandi, canli DB'de test edildi); `onizleme({benimMi})` yon biliyorsa
    ayirir, BILMIYORSA yon iddiasinda BULUNMAZ.
  · **(7) DUSUK:** `devamEt()` ekrani UC await SONRASI aciyordu; o pencerede
    `minimized` zaten false yazildigi icin yesil bant da cizilmiyordu -> arama
    yasarken NE EKRAN NE BANT. Ekran artik await'lerden ONCE aciliyor.
    ⚠️ YAPMA: `ekraniAc()`i tekrar await'lerin altina tasima.
  · ✅ **"oda-yayin-dokunulmamis-mi" boyutu 0 BULGU** — sesli oda ve canli yayin
    akislari turu 58/59'dan ETKILENMIYOR (kullanici emri dogrulandi).
  **SUREC DERSI:** build ALMAK yayinlamak DEGILDIR. Artifact hazirken kosulan
  adversaryal dogrulama, sahaya cikacak YUKSEK bir regresyonu yakaladi. Bu adimi
  atlama.
- ⚠️⚠️ **TURU 59 — TURU 58'DE EKLEDIGIM OZELLIK OLU DOGMUSTU (build oncesi denetim):**
  "Cevaplanan arama" sohbet balonu kaydi YALNIZ `End()` handler'ina konmustu. Kullanici
  kapatinca istemci AYNI ANDA hem odadan cikar hem `/end` atar; LiveKit webhook'u
  **localhost'tan ms'ler icinde** gelir, istemcinin REST'i mobil agdan. Yani
  `UPDATE ... WHERE status IN ('ringing','active')` yarisini **neredeyse HER ZAMAN
  webhook kazanir** ve `/end` bir ustteki `RowsAffected()==0` kapisinda sessizce doner
  -> balon SAHADA HIC YAZILMAZDI.
  **FIX:** ortak `bitenAramayiSohbeteYaz()`; yarisi KAZANAN **her iki yoldan** cagriliyor.
  ⚠️ YAPMA: cagriyi `RowsAffected>0` kapisinin DISINA tasima (CIFT BALON); cop
  toplayicilara (sweep 2sa / olu-arama 90sn / `oluAramaTemizle`) ekleme (orada
  `ended_at` gercek kapanistan cok sonra -> SISMIS sure gosterir).
  **GENEL DERS:** "iki yazicidan biri kazanir" mimarisinde yeni yan etkiyi TEK yaziciya
  koymak = o yan etkinin hic calismamasi.
- **TURU 59 DIGER FIXLER:** (1) sohbet listesinde HAM `call:ended:audio:75` ->
  yeni `chats/arama_kaydi.dart` ayristirmanin TEK kaynagi (balon + onizleme).
  (2) `call:ended:*` artik `read_at=now()` ile OKUNMUS dogar (rozet gurultusu bitti);
  `call:missed:*` rozet URETMEYE DEVAM eder. (3) **BAYAT EKRAN CANLI EKRANI EZIYORDU**
  (dispose pop kararindan ~400ms sonra calisir; arada yeni arama devralirsa yesil bant
  canli ekranin ustune biner, banta dokunmak IKINCI push yapar) -> `ekranSahibi`
  NESNE KIMLIGI jetonu; ⚠️ callId karsilastirmasi YETMEZ (`geriAra()` callId'yi degistirir).
  (4) 240ms dirilme dali bayat ekrani pop etmiyordu -> ayni track'e iki renderer.
  (5) ELLE minimize'da yesil bant 1sn'ye kadar cizilmiyordu (`notifyListeners` `if`
  icindeydi, `minimized` zaten true) -> disari alindi. (6) GECIS: siyah katman
  `FadeTransition`in DISINDAYDI -> pop yonunde 160ms duz siyah + sert kesme + arama
  boyunca 2 fazla opak katman; Container kaldirildi (siyahi `barrierColor` veriyor),
  `CurvedAnimation` -> `CurveTween` (her karede kurulup dispose edilmiyordu).
  (7) Android `PipService.pipModu` PAYLASILAN bayragi hicbir yerde oz-iyilestirilmiyordu
  -> kacan bir `pipDegisti(false)` sonraki YAYIN ekranini kalici "PiP sade gorunumu"nde
  birakabilirdi; `resumed` dalinda temizleniyor.
  ⚠️ YAPMA: (3)(4) jeton kapilarini kaldirma; (5) notify'i geri `if` icine alma;
  (6) siyah Container'i geri koyma.
- **KALDIGIMIZ YER (2 Agu 16:58):** TEST TURU 57 YAYINLANDI — android 30750686204 +
  ios 30750682791 (33089f9), R2 apk=105211469 ipa=19313086, purge OK, CDN birebir,
  backend degismedi + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ⚠️⚠️ **TURU 57 — "GSM SONRASI DEVAM ETMIYOR" + "ARAMA BULUNAMADI" TEK KOK NEDEN**
  (turu 55 REGRESYONU, sunucu loguyla KANITLI):
  Sunucuda `POST /calls/{id}/answer` **6 kez 404**; hepsi ARAYANIN cihazindan ve aramanin
  ZATEN cevaplanmasindan SANIYELER SONRA (19be2fd1: cevap 13:29:34, 404 **13:29:38**).
  **MEKANIZMA:** turu 55'te giden aramayi da CallKit'e kaydettik (`gidenArama`). Amac
  dogruydu (iOS "Beklet ve Kabul"u ancak CallKit'te AKTIF arama varsa cizer) ama yan
  etkisi: ARAYAN tarafta da CallKit araması olusuyor ve CallKit **"kabul" olayi** uretince
  `main._callKitKabul` **KENDI GIDEN ARAMAMIZI** cevaplamaya calisiyordu -> sunucu 404
  (`WHERE id=$1 AND callee_id=$2` — arayan callee DEGIL).
  **ZINCIRLEME (iki semptom TEK kaynak):** 404 -> `main.dart` catch -> `CallKitService
  .bitir(callId)` -> **CallKit kaydimiz YOK EDILIYOR** -> iOS ses oturumunu birakip GERI
  VERMIYOR -> GSM sonrasi Gebzem **SESSIZ**; ayni catch SnackBar ile **"arama bulunamadi"**
  gosteriyor.
  **FIX:** `CallKitService.gidenler` kumesi — kendi baslattigimiz aramalarin **kabul
  olaylari YOK SAYILIR** (o olay yalniz GERCEKTEN GELEN aramalar icin anlamlidir).
  `gidenArama()` doldurur; `bitir()` ve `davetSifirla()` bosaltir.
  ⚠️ YAPMA: bu kapiyi kaldirma; `gidenler`i `gidenArama` disinda doldurma.
  ⚠️ **DERS:** CallKit'e giden arama kaydetmek, GELEN arama icin yazilmis TUM olay
  yollarini (kabul/red/timeout) arayan tarafta da tetikler — her birini ayrica ele al.
- ✅ **TURU 56 TESTI SONUCU (kanit):** cokme YOK · **`callkit izin durumu ... telefon=TRUE`**
  (36 turdur alinamayan Android GSM izni ARTIK ALINIYOR — izin sirasi fix'i TUTTU) ·
  17 aramada tek tarafli video YOK · 3 oda + 3 yayin sorunsuz · `bayat mesgul muhafizi` /
  `kamera acilamadi` / `video yayin yok` / `arama tipi CELISKI` HICBIRI CIKMADI ·
  PiP `oturum=true yerel3=90 cagri=2 iptal=0 msMax=0`.
- **ONCEKI (2 Agu 15:50):** TEST TURU 56 YAYINLANDI — android 30748279270 +
  ios 30748275465 (91f2b00), R2 apk=105211469 (KUCULDU) ipa=19312972, purge OK, CDN birebir,
  **BACKEND DEPLOY** (`grupAramaAcik=false` dogrulandi) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ✅ **URUN KAPSAMI (kullanici karari 2 Agu): 1:1 SESLI + 1:1 GORUNTULU + SESLI ODA +
  CANLI YAYIN. GRUP ARAMASI YOK.**
  · Istemci: `calls_tab` grup FAB'i ve `call_screen` "Kisi ekle" iki kapisi KALDIRILDI.
  · Backend: **`grupAramaAcik = false`** — `Start` (grup dali) ve `Add` KOSULSUZ reddeder.
  ⚠️ **DENETIM DERSI:** yalniz `maxGrupKatilimci`yi 2'ye indirmek YETMIYORDU — tek kisilik
  grupta `2 > 2` FALSE olup 2 kisilik grup ACILIYORDU. Bayrak SART.
  ⚠️ `return` sonrasi OLU KOD BIRAKMA (turu 48: "gozcu ULASILAMAZ KODDU") — bayrakla kapat.
  ⚠️ **GRUP KODU SILINMEDI** (37 dal 1:1 yollarina orulmus). `mini_izgara.dart` DURUYOR —
  oda/yayin kullaniyor. ⚠️ YAPMA: silmeye calisma.
- ✅ **GSM BEKLET — IKI KOK NEDEN (36 turdur sessizce bozuktu):**
  (1) **iOS HARF UYUSMAZLIGI:** CallKit hold olayi `action.callUUID.uuidString` ile gelir
  ve Foundation bunu **BUYUK HARF** dondurur; callId'lerimiz Postgres `gen_random_uuid()`
  = **kucuk harf**. Tam esitlik ESLESMIYOR -> `beklemeyeAl` SESSIZCE return ediyordu
  (medya durmuyor, sunucuya hold gitmiyor). Kabul/Reddet/Bitir ETKILENMIYOR — yalniz
  **hold ve mute** olaylari uuidString kullanir. FIX: `CallKitService._asilId` cevrimi +
  `beklemeyeAl`da harf-duyarsiz karsilastirma (ikinci katman).
  (2) **ANDROID IZNI HIC VERILMIYORDU:** `Permission.phone.request()`,
  `requestFullIntentPermission()`ten SONRA cagriliyordu; o cagri SISTEM AYARLAR ekranini
  acar, Activity duraklayinca izin diyalogu GOSTERILMEZ, Future ASILI KALIR.
  FIX: telefon izni ONCE, ayar ekranina sicrama EN SON. + sonuc okunuyor (Sentry olcumu).
  ⚠️ YAPMA: bu iki blogun sirasini degistirme; `gsmDinle` sonucunu `unawaited` ile atma.
- ⚠️ **GIZLILIK:** GSM gorusmesi surerken Gebzem'e gecince `resumed` dali MIKROFONU geri
  aciyordu -> **karsi taraf GSM konusmasini duyuyordu.** `resumed` sartina `&& !beklemede`
  + `_kesintidenTopla` basina savunma kapisi. ⚠️ YAPMA: bu kapilari kaldirma.
- ⚠️ **TURU 55/56 KENDI REGRESYONLARIM (build oncesi denetimde yakalandi):**
  · `beklemeyeAl`: uc await'ten sonra `arama!` -> NULL-CHECK PATLAMASI + `beklemede` TAKILI
    kalmasi. Kimlik await'lerden ONCE yakalanir + her await sonrasi kimlik kapisi.
  · `!beklemede` kapisi `resumed`daki `_kameraOtoAc()`i de blokluyordu -> GSM sonrasi
    GORUNTULU aramada kamera BIR DAHA ACILMIYORDU. unhold dalina `_kameraOtoAc()` eklendi.
  · `gidenArama` (turu 55) **HAYALET CALLKIT ARAMASI** birakiyordu: `_cevapsizGoster` ve
    `geriAra` yollarinda `CallKitService.bitir` CAGRILMIYORDU.
  · Giden arama CallKit'te "araniyor" kaliyordu; iOS bagli olmayan aramayi HOLD EDILEBILIR
    saymaz -> `CallKitService.baglandi()` (`setCallConnected`) eklendi (YALNIZ giden).
  ⚠️ YAPMA: bu dort duzeltmeyi geri alma.
- ✅ **MESGULLUK KONTROLU TEK KAYNAK:** `CallService.mesgulMu({haric, etiket})` —
  start/answer/oda/yayin AYNI yolu kullanir. Bayat kayit bulursa temizler + Sentry olcumu;
  GERCEK arama veya `oda_`/`yayin` kaydi varsa ENGELLER.
  ⚠️ YAPMA: bu mantigi cagiran yerlere kopyalama (drift eder — `rooms_tab`/`live_tab` ham
  `aramadaMi`ye bakiyordu ve self-heal'den yararlanmiyordu).
- ✅ **ANDROID SES TAZELEME:** `_sesiAc` Android'de kosulsuz erken donuyordu; GSM sonrasi
  ses SAGIR kalabiliyordu. `_androidSesTazele()` eklendi — YALNIZ kurtarma yollarindan
  (`beklemeyeAl(false)`, `devamEt`) cagrilir. ⚠️ YAPMA: `_connect` akisina sokma.
- **ONCEKI (1 Agu 19:23):** TEST TURU 54 YAYINLANDI — android 30707620654 +
  ios 30707617339 (384920c), R2 apk=105227853 ipa=19322064, purge OK, CDN birebir,
  backend 384920c'ye senkron + health ok, DB temiz. **KULLANICI TEST EDECEK.**
- ✅ **TURU 54 — TEKRAR DAVET TAKILMASININ ASIL KOKU (sunucu kaniti):** grup aramasi
  `7bc32718`e **4 x `/add` (hepsi 200), 0 x `/answer`** — davet ulasiyor, telefon caliyor,
  KABUL SUNUCUYA HIC VARMIYOR. Arama-id bazli **UC KUME** surec omru boyunca HIC
  temizlenmiyordu: `_cevaplanan` (ikinci kabul REST'e GITMEDEN null doner — ASIL KOK),
  `_bitenler`, `CallKitService.islenenler` (Android'de gelen-arama katmani bir daha acilmaz).
  FIX: `CallService.davetSifirla(id)` — `aramaBitti()`, `grupDavetiGoster()`, `leave()`ten.
  ⚠️ YAPMA: kapilarin KENDISINI kaldirma (ayni ZIL episodunda cift kabul korumasi);
  `davetSifirla`yi arama SURERKEN cagirma.
- ✅ **GRUP ARAMASINA DONUS (`devamEt`)**: WS aboneliklerini GERI KURMUYORDU (ikinci
  aramanin `baslat()`i `_iptalAbonelikler()` ile oldurmustu) -> devam edilen arama sunucuda
  'ended' olsa bile istemcide SONSUZA KADAR acik kaliyor, mesgul muhafizi dusmuyor,
  kullanici bir daha arama YAPAMIYOR/ALAMIYOR. Abonelikler `_aboneliklerKur(id)` ile TEK
  yere alindi (`baslat()` + `devamEt()`); `devamEt()` ayrica `_aktifPollBaslat()` +
  `_pilTakibiBaslat()` cagiriyor. ⚠️ YAPMA: `_aboneliklerKur`u yalniz `baslat()`a baglama.
- ✅ **PARK SURESI**: parkta gecen sure KAYBOLUYORDU. `ParkEdilenArama.parkSayaci`
  (MONOTONIK Stopwatch) + `_sureBaz = p.gecen + p.parkSayaci.elapsed`.
  ⚠️ YAPMA: DateTime/sunucu saati karsilastirmasiyla hesaplama (CLAUDE.md sure hukmu).
- ⚠️ **TURU 53 DARALTMASI:** `_iosPipBasarisiz` kapisi `inactive`i de kapsiyordu ama
  **EKRAN KILIDI de `inactive`ten GECER** -> durust mute atlanip karsi taraf DONMUS KARE
  goruyordu ("kamera duraklatildi kaldirmissin"). Kapi yalniz `resumed`e daraltildi.
  Kendi iptalimizi ayirt etme isi NATIVE `iptalIstendi` kapisinda (kesin bilgi).
  ⚠️ YAPMA: buraya `inactive`i geri ekleme; native kapiyi kaldirma.
- ⚠️ **"BEKLET/DURDUR KALDIRMISSIN" — KALDIRILMADI, HIC VAR OLMADI.**
  `git log -S "Beklet" -- call_screen.dart` BOS doner. "Arama beklemede" paneli yalnizca
  (a) CallKit hold, (b) Android GSM aramasi, (c) ikinci gelen arama ile ACILIR; elle
  basilacak dugme YOK. Kullanicinin gordugu sesli/goruntulu farki `_gizliEfektif`ten:
  GORUNTULUDE ekrana dokununca alt kontrol cubugu GIZLENIYOR ve geri gelmiyor.
- **HENUZ YAPILMADI (kok neden bulundu, kullanici karari bekliyor):**
  (1) **Goruntuluede "Beklet ve Kabul" gelmiyor** — ANA KOK: GIDEN aramalar CallKit'e HIC
  bildirilmiyor (`FlutterCallkitIncoming.startCall` kod tabaninda YOK); iOS o ekrani ancak
  CallKit'te aktif arama varsa cizer. Fark sesli/goruntulu DEGIL, **ARAYAN/ARANAN** farki.
  (2) **Gecis animasyonu** — minimize/restore Navigator PUSH/POP; ekran her buyutmede
  SIFIRDAN kuruluyor, `VideoTrackRenderer` dispose oluyor.
- **ONCEKI (31 Tem 23:30):** TEST TURU 53 YAYINLANDI — android 30662374718 +
  ios 30662368371 (53512fc), R2 apk=105227853 ipa=19165051, purge OK, CDN birebir,
  **BACKEND DEPLOY EDILDI** (53512fc, `maxGrupKatilimci=4` sunucuda dogrulandi) + health ok,
  DB temiz. **KULLANICI TEST EDECEK.**
- ✅ **TURU 53 — "APP SWITCHER'DA KAMERA KAPANIYOR"UN KOK NEDENI: BIZ (16 ajanlik denetim)**
  **iOS KURALI (Apple):** kamera YALNIZ uygulama GERCEKTEN `.background`a gecerse kesilir
  ("Camera usage is prohibited while in the background"); tek istisna PiP'in AKTIF olmasi.
  **App switcher / Kontrol Merkezi uygulamayi YALNIZ `.inactive` yapar** (Flutter belgesi)
  ve iOS orada kamerayi HIC KESMEZ. **WhatsApp'in yaptigi sey: HICBIR SEY YAPMAMAK.**
  **BIZIM ZINCIR:** `inactive`te PiP baslat -> donuste `resumed` dalinda KOSULSUZ
  `iosPipDurdur()` ile PiP'i BIZ iptal et -> yarida kesilen acilis AVKit'in
  `failedToStartPictureInPicture`ini atesler -> 800ms teyit blogu yalnizca
  `isPictureInPictureActive`e bakar (biz kapattik, false) -> `iosPipBasarisiz` Dart'a iner
  -> uygulama ON PLANDA, AKTIF, ekran acikken `setCameraEnabled(false)`. Ustelik geri acma
  `resumed` KENARINA bagli oldugu icin kamera BIR DAHA ACILMIYORDU.
  **FIX:** (a) native `failedToStart` 800ms blogunun basina `if self.iptalIstendi { return }`
  (turu 49'un "800ms'i kaldirma" kuralini IHLAL ETMEZ; "`.background` kapisi" kurali
  `baslat()` icindir, BURASI DEGIL), (b) Dart `_iosPipBasarisiz` on-plan kapisi.
  **ILKE: kamerayi yalnizca iOS'un KENDI kesinti olayi veya GERCEK arka plan gecisi kapatir.**
  ⚠️ YAPMA: bu iki kapiyi kaldirma.
- ✅ **`_kameraOtoAc` (seviye-tetiklemeli geri acma):** bekleyen `_kesintiMuteGecikme`yi
  IPTAL EDER + `resumed` dalindan VE `_iosKameraKesinti(false)`tan cagrilir (o dal eskiden
  bos `return` = OLU KOD idi). ⚠️ YAPMA: icine `_iosArkaPlanKamera = true` yazma
  ("yalan bayrak" regresyonu, turu 32-33).
- ✅ **AKTIF KONUSAN TAKIBI KAPATILDI** (kullanici: "bu tur ozellikleri kapa"):
  `miniKatilimcilar` ve `_uzakVideoTrackId` icindeki `activeSpeakers` bloklari SILINDI ->
  sira SABIT (katilma sirasi). Tam ekrandaki yesil "konusuyor" cercevesi KORUNDU.
  ⚠️ YAPMA: bu iki yere tekrar `activeSpeakers` siralamasi koyma.
- ✅ **DONUSTE "CIZME":** renderer anahtarlari TRACK KIMLIGINE bagliydi; on plana donuste
  `setCameraEnabled(true)` -> livekit `restartTrack()` -> YENI `mediaStreamTrack` ->
  anahtar degisiyor -> renderer YIKILIP yeniden kuruluyordu. Artik ROL bazli
  (`vid-yerel`/`vid-uzak`) ve grup tile'i `tile-${p.identity}`.
  ⚠️ YAPMA: anahtarlara tekrar track kimligi (id/sid) koyma.
- ✅ **IZGARA SIYAHLIKLARI:** Flutter `bosluk` 2.0 -> 0 · iOS native `yigin.spacing` ve
  `satir.spacing` 1 -> 0 · `callVC.view.backgroundColor` lacivere sabitlendi (bosluklardan
  ATANMAMIS SIYAH zemin gorunuyordu) · grup izgarasi padding `(8,108,8,132)` -> **zero** +
  tile boslugu 6 -> 0. ⚠️ Grup kapasitesi 4'un UZERINE cikarilirsa padding'i GERI GETIR
  (5-6 kisilik SESLI grupta alt satirin adi kontrollerin altinda kaybolur).
- ✅ **PiP ORANI:** ⚠️ `preferredContentSize` **MUTLAK BOYUT DEGIL** — iOS yalniz ORANI
  kullanir; Android'de de `setAspectRatio` disinda boyut API'si YOK. Bu yuzden "%10 buyut"
  = ORTAK VE DAHA GENIS ORAN: iOS 0.563 / Android 3:4 -> **ikisi de 5:6 (0.833)**.
  ⚠️ YAPMA: orani calisma aninda degistirme; iki platformu farkli oranda birakma.
- ✅ **GORUNTULU ARAMA "SESLI" BASLIYORDU (aranan tarafta):** `_camOn=false` olunca kamera
  blogu KOMPLE atlanir ve turu 50'nin `_videoYayinDogrula`si DA O BLOGUN ICINDE oldugu icin
  hicbir iz kalmiyordu (DB `type=video`, LiveKit'te yalniz audio, Sentry bombos).
  `_camOn` CallKit yukundeki bayraktan geliyordu. FIX: `answer()` yanitindaki `type`
  (backend handler.go ZATEN donduruyor) **OTORITER**; CallKit yuku YEDEK. Ayrica
  `arama.video==true && camOn==false` ise artik Sentry'e olay dusuyor (korluk kapandi).
  ⚠️ YAPMA: arama tipini tekrar yalniz `c['video']`ya baglama.
- ✅ **"CIKIP HEMEN TEKRAR ARAYAMIYORUM":** sunucu TEMIZDI (asili arama 0, 409 yok).
  Engel istemcideki `ekrandakiAramalar` mesgul muhafizi — 5 ekrandan giriliyor, 9 yerden
  birakiliyor; biri kacinca id asili kalip `start()` kosulsuz hata firlatiyordu.
  Artik GERCEKLIGE soruluyor: gercek aktif arama VEYA `oda_`/`yayin` muhafizi varsa engelle,
  yoksa BAYAT kabul edip temizle + Sentry olcumu.
  ⚠️ YAPMA: bu kapiyi kosulsuz temizlemeye cevirme (ses cakismasi korumasi orada).
- **ONCEKI (31 Tem 02:05):** TEST TURU 52 YAYINLANDI — android 30588794092 +
  ios 30588788364 (33fc2d9), R2 apk=105227853 ipa=19317028 (+169KB = native izgara),
  purge OK, CDN birebir, backend degismedi (678f5fc) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ✅ **TURU 52 — KUCUK PENCERE IZGARASI (24 ajanlik denetim):**
  Native `ekKaynaklarAyarla` + Flutter `miniIzgara` AYNI merdiven: 1 tam · 2 UST/ALT ·
  3-8 iki sutunlu satirlar (son satirda tek kalirsa tam genislik). Kose kutusu (ben)
  yalniz 1-2 uzak kutu varken cizilir.
  ⚠️ **ONCEKI ISRARIM YANLISTI:** "iOS sistem PiP'inde izgara yapilamaz, orayi iOS ciziyor"
  DEMISTIM — YANLIS. `AVPictureInPictureVideoCallViewController` BIZIM VC'miz, icine ne
  koyacagimiza BIZ karar veriyoruz (AppDelegate.swift:583). Izgara orada da calisir.
  **DENETIM KENDI YENI KODUMDA 5 HATA BULDU** (hepsi duzeltildi): (1) sira duyarli
  karsilastirma + `activeSpeakers` sirasi -> biri konusunca izgara komple yikiliyordu;
  (2) PiP yeniden kurulunca `_iosPipEkIdler` sifirlanmiyordu -> izgara bir daha
  cizilmiyordu; (3) gozcu ek kutulari izlemiyordu -> donmus kare deligi geri acilmisti;
  (4) izgarada kose kutusu bir katilimciyi kapatiyordu; (5) 8 renderer = kare basina
  CVPixelBufferCreate + ornek-basina kuyruk -> **HAVUZ + TEK paylasilan kuyruk**.
  ⚠️ YAPMA: karsilastirmayi sira duyarli yapma; ek listeyi `activeSpeakers` ile siralama;
  `_iosPipEkIdler` sifirlamalarini kaldirma; gozcuden ek kutulari cikarma; izgarada kose
  kutusunu geri acma; havuzu/tek kuyrugu kaldirma.
- ✅ **"KAMERA DURAKLATILDI" TEK GORUNUM:** ayni durum 3 farkli bicimde ciziliyordu
  (uygulama ici blur+yazi · iOS PiP MOR DAIRE+yazi · Android PiP mor daire+HARF, yazi YOK).
  Hepsi TEK dile indi: koyu zemin + siyah seffaf hap + beyaz yazi. `_bantIlkVideo` mute
  track'i ELIYORDU (kutu mor daireye dusuyordu) -> yeni `_miniVideo` + `MiniKatilimci.beklemede`.
  ⚠️ YAPMA: mor daireyi geri koyma; native tarafa `UIVisualEffectView` (blur) ekleme
  (katman flush edildigi icin bulaniklastirilacak goruntu YOK, ustelik riskli).
- ✅ **KOSE KUTUSU:** cerceve KALDIRILDI · yaricap iOS 5 / Flutter 7 -> **ikisi de 14**
  (buyuk ekranla ayni) · yukseklik **%10 kisaldi** (4:3 -> 6:5; Flutter tavani 0.45 -> 0.405)
  · genislik %34 ve kenar boslugu 5 DEGISMEDI -> iOS/Android BIREBIR ayni.
- ⚠️ **"cagri=10" YORUMUM YANLISTI (duzeltme):** `baslatCagri` YALNIZ didStart'in BASARILI
  dalinda sifirlaniyordu; iptal/failedToStart olan acilislar sayaci artirip HIC
  sifirlamiyordu -> deger tek bir alta almayi degil BIRIKMIS gecisleri sayiyordu.
  "10 kez ust uste istendi" TESHISI GECERSIZ. Artik `iptalCagri` ayri sayilir (`iptal=N`)
  ve ikisi de `durdur()`ta (= on plana donus) sifirlanir.
  ⚠️ YAPMA: sayaclari yalniz basarili dalda sifirlamaya donme.
- **ONCEKI (31 Tem 00:06):** TEST TURU 51 YAYINLANDI — android 30581163737 +
  ios 30581157141 (f7f5040), R2 apk=105227857 (MD5 degisti) ipa=19148243 (BUYUDU = Swift
  derlendi), purge OK, CDN birebir, **backend DEGISMEDI** (678f5fc) + health ok, DB temiz.
  **KULLANICI TEST EDECEK.**
- ✅ **TURU 51 — PiP BOLUNME DENETIMININ 6 DUZELTMESI (28 ajanlik denetim sonucu):**
  (1) **ALTA ALMA COKMESI COZULDU** (EXC_BAD_ACCESS, Sentry 29 Tem, son iz
  `app.lifecycle:background`): kare teslimi WebRTC thread'inde kosarken ANA thread
  `track.remove(renderer)` + nil yapip nesneyi serbest birakiyordu. FIX: `PipRenderer`a
  NSLock + `aktif` bayragi + **MEZARLIK** (sokulen renderer 2sn canli tutulur).
  (2) `toplamKare`/`sayac` kilide alindi (iki thread'den kilitsizdi).
  (3) `gozcuDur()` artik `durdur()` ve `didStopPictureInPicture` icinde de cagriliyor
  (gozcu KAPANMIS pencere icin sink ameliyati tetikliyordu).
  (4) **KOSE KUTUSU KOR TRACK SECIMI BITTI**: yalniz `.live && isEnabled`; birden fazla
  aday varsa TAHMIN YOK (`belirsiz`); olu track `track-olu`. (NSMutableDictionary anahtar
  sirasi deterministik DEGIL — "ilkini al" yanlis kamerayi da seciyordu.)
  (5) **KIMLIK DEGISIMINDE PENCERE KAPANMASI**: once SICAK GECIS denenir, yalniz
  basarisizsa `iosPipKur` (o native `birak()` -> `stopPictureInPicture` yapar).
  (6) **"IKI KUTUDA DA BENI GOSTERIYOR"**: kose kutusu YALNIZ `_iosPipKurulanId == uzakId`
  iken cizilir (eskiden yalniz `uzakId != null` bakiyordu).
  (7) **SESLI->GORUNTULU ARAMADA PENCERE KAYBI**: `pipModunda` iken `iosPipBirak`
  CAGRILMAZ (arka planda kamera kesilince `uygun` dusup pencereyi kapatiyordu).
  (8) Kose kutusu hatasi Sentry'e ARAMA BASINA 1 kez (eskiden saniyede bir -> 195 kayit).
  ⚠️ YAPMA: mezarligi/kilidi kaldirma; `gozcuDur()` cagrilarini geri alma; kose kutusunda
  canlilik kontrolunu kaldirma veya coklu adayda tahmin yurutme; kimlik degisiminde sicak
  gecis denemesini atlama; kose kutusu sartini yalniz `uzakId != null`a indirgeme;
  `pipModunda` birakma kapisini kaldirma.
- **KAMERA "DURAKLATILDI" NEDIR (kullanici sorusu 30 Tem):** referans **iOS**, WhatsApp
  degil. iOS uygulama gorunmuyorken kameraya izin VERMEZ — capture session
  `videoDeviceNotAvailableInBackground` (sebep=1) ile kesilir. Bu bir GUVENLIK/GIZLILIK
  kurali; WhatsApp da ayni seyi yasar, sadece durustce "video duraklatildi" yazar.
  Tek istisna: iOS 16+ PiP AKTIFKEN kamera yasayabilir (turu 43-49'un konusu).
- **ONCEKI (30 Tem 21:39):** TEST TURU 50 YAYINLANDI — android 30570448293 +
  ios 30570457011 (678f5fc), R2 apk=105227857 ipa=19146222 index=6945, purge OK, CDN birebir,
  backend deploy (678f5fc) + health ok, DB temiz. **KULLANICI TEST EDECEK.**
  ⚠️ **APK BOYUTU YANILTIR:** turu 44-50 boyunca apk hep 105227857 cikiyor ama ICERIK farkli
  (eski ETag `31161020…` / yeni MD5 `5d1381a2…`). "Boyut ayni = build eski" DEME, MD5 karsilastir.
- **INDIR SAYFASI — "SAATI GOREMIYORUM" KOK NEDENI:** saat sayfada VARDI ama ERISILEMIYORDU.
  `body { display:flex; align-items:center }` + karttan uzun icerik = **ust tasma kaydirilamaz**
  (klasik flexbox tuzagi) -> mor saat cubugu telefonda kirpiliyordu. FIX: body'den flex ortalama
  KALDIRILDI, saat cubugu **kartin DISINA, sayfanin en ustune** tasindi. Uretici:
  `scratchpad/indir_uret.js` (saat UTC+3, surum etiketi APK linkine `?v=`).
  ⚠️ YAPMA: body'ye tekrar `display:flex; align-items:center` koyma.
- **TURU 50 OLCUMLERI (Sentry, gebzem-mobile — test sonrasi BAK):**
  `kamera acilamadi: …` (kamera yolu hala patliyor) · `video yayin yok — kamera tekrar
  deneniyor` (emniyet agi kurtardi) · `video tekrar denemesi BASARISIZ: …` (kurtarma da
  tutmadi). Hicbiri cikmazsa kok cozum TUTTU.
- ✅ **BIREBIR VIDEO DUSMESI — KOK NEDEN KANITLI COZULDU (sunucu logu, tahmin degil):**
  LiveKit 96 saatlik log oda-oda sayildi: **64 aramanin 9'unda tek tarafli video (%14)**;
  patlayan taraf **9/9 iOS, 0 Android**, **8/9 iPhone11,6 (XS Max)**, **7/9 ARANAN**.
  Ag 6 hucresel/2 wifi -> **internet hizi veya sarj DEGIL, KOD.**
  KOK: `_odayaBaglan`da `await _onizlemeIsi?.timeout(700ms)` — **`Future.timeout` alttaki
  isi IPTAL ETMEZ**. Sure asilinca yedek yol `setCameraEnabled(true)` IKINCI kamerayi acar;
  `createCameraTrack` hala calisiyordur ve iOS'ta flutter_webrtc **TEK paylasilan
  `videoCapturer`** tuttugu icin iki capture oturumu birbirini oldurur -> video track odaya
  HIC ulasmaz. ARANAN'da onizleme ancak answer REST'inden SONRA basladigi icin pencere yok
  denecek kadar az; ARAYAN'da erken basladigi icin neredeyse hic patlamaz.
  **NEDEN 20+ TUR GORUNMEDI:** hata `_sesLog` ile yutuluyordu, `_sesLog` Sentry'e yalniz
  **BREADCRUMB** yazar (breadcrumb ancak baska bir olay/crash olursa yuklenir).
  Bagimsiz teyit: Sentry `ios pip alt gorunum sonuc=track-yok` **195 kayit**.
  FIX: `_onizlemeIptal` (gec biten onizleme ATILIR) · pencere 700ms -> **2500ms** · kamera
  hatasi artik `Sentry.captureMessage` (gorunur olcum) · **`_videoYayinDogrula`**: baglantidan
  1.5sn sonra video track yoksa TEK SEFER tekrar dener (yapisal emniyet).
  ⚠️ YAPMA: `_onizlemeIptal`i kaldirma; beklemeyi 700ms'e dusurme veya suresiz yapma;
  `_videoYayinDogrula`yi kaldirma/dongu yapma; kamera hatasini tekrar yalniz breadcrumb'a yazma.
- **SINIRLAR (kullanici karari 30 Tem — koda islendi):**
  · Grup aramasi (sesli VE goruntulu): **4 kisi** (arayan dahil) — 31 Tem'de 8'den
    INDIRILDI (kullanici: "aciklari ve buglari minimumda tutmak istiyorum").
    GEREKCE (olculere dayali): SFU iletimi N*(N-1) — 4 kisi 12 akis, 8 kisi 56 akis
    (4.7 kati) ve tum trafik TURN relay'den geciyor; istemci N-1 video COZER, VP8
    iPhone'da yazilimla cozuluyor (XS Max'te 7 cozme + simulcast = isinma/pil);
    kucuk pencerede 8 kutu ~74x64pt + 8 yazilim i420 donusumu.
    **DORT YER AYNI SAYI OLMALI:** backend `maxGrupKatilimci` · `toggleCam` kapisi ·
    `_ekUzakVideoTrackIdleri` (`>= 3`) · `kMiniEnFazlaKutu`.
    ⚠️ YAPMA: bu dordunu farkli birakma; PiP tavanini backend kapasitesinden buyuk yapma.
  · Sohbet odasi: **konusmaci 20** (odayi kuran dahil) + **dinleyici SINIRSIZ**
    (`internal/rooms/handler.go` `maxKonusmaci=20`, `maxDinleyici=0`, `odaKapasitesi=0`;
    kapasite kontrolleri `maxDinleyici > 0` sartli). ⚠️ Sartsiz geri koyma.
  · Canli yayin: **yayinci + 3 konuk = 4** + **izleyici SINIRSIZ** (zaten boyleydi;
    `STREAM_MAX_GUESTS=3`, `STREAM_MAX_VIEWERS=0`).
- **GRUP IZGARASI ALT TASMASI:** satir yukseklikleri `box.maxHeight`e TAM oturuyordu;
  ondalik yuvarlama alt kenarda sari-siyah "RenderFlex overflowed" seridi cizdiriyordu
  (kullanici: "toplu goruntuluda altta patliyor"). Yarim piksel pay + `math.max(1.0, ...)`.
- **SUNUCU SAGLIKLI:** %79-82 bosta CPU, wa=0, LiveKit hatasiz. ⚠️ `top -bn1`in ILK
  iterasyonu YANILTICI (surec omru ortalamasi verir) — CPU'yu vmstat/2. ornekle olc.
- **KALDIGIMIZ YER (28 Tem 01:06):** TEST TURU 49 YAYINLANDI — android 30308483234 +
  ios 30308485130 (a2ead0e), R2 apk=105227857 ipa=19145592 (buyudu), purge OK, CDN birebir,
  backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 49:** OLCUM `kesinti ... pip=FALSE` + olcum satiri YOK -> turu 48te ekledigim
  `applicationState == .background` kapisi TEK BASLATMA denemesini de yutmus (Dart tetigi
  method channel ile ASENKRON iniyor). Kapi KALDIRILDI; `SceneDelegate.sceneWillResignActive`
  kancasi GERI ama **DispatchQueue.main.async** ile (turu 43 SENKRONDU -> kamera yasadi ama
  alta alma takildi; turu 46 kanca yoktu -> takilma gecti ama kamera oldu). failedToStart
  artik 800ms teyit gecikmesiyle bildiriliyor.
  ⚠️ YAPMA: `.background` kapisini geri koyma; kancayi senkron yapma veya kaldirma;
  failedToStart gecikmesini kaldirma.
- **KALDIGIMIZ YER (28 Tem 00:32):** TEST TURU 48 YAYINLANDI — android 30306342017 +
  ios 30306343945 (91a9661), R2 apk=105227857 ipa=19145142 (buyudu = yeni native kod),
  purge OK, CDN birebir, backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 48 — "kose kutusu (kendi goruntum) donuyor" KOK SEBEP:**
  (1) **GOZCU ULASILAMAZ KODDU** (gorunen sebep): `gozcuBaslat()` once BUYUK kutuya bakip
  `if n != sonGorulenKare { ...; RETURN }` yapiyordu; KOSE kutusu kontrolu O RETURN'UN
  ALTINDAYDI. Karsi tarafin videosu aktigi surece (kullanicinin tam durumu, `arka=89`)
  kose kutusunun donmasi HIC fark edilmiyordu. FIX: kose kontrolu EN BASA, iki kutu bagimsiz.
  (2) **YANLIS BAYRAK** (20 turdur): `isMultitaskingCameraAccessEnabled` yalnizca sebep 4
  (`...WithMultipleForegroundApps`) kesintisini engelliyor; bizimki `sebep=1`
  (`videoDeviceNotAvailableInBackground`). Uc olcumde de `coklu=true` — bayrak degisken
  DEGIL. Arka planda kamerayi ayakta tutan tek sey PiP'in AKTIF olmasi.
  (3) Turu 47 GERI ALINDI (`arka=0` regresyonu): `cokluGorevKameraAc()` tekrar SALT OKUMA.
  (4) Arka planda `startRunning()` kurtarmasi SILINDI (Apple: arka planda kamera YASAK;
  yapisal olarak imkansiz — `kurtarma=null`).
  (5) `yereliBosalt()` / `iosPipKareBosalt(yalnizYerel:true)` — eskiden kendi kamera
  kapaninca KARSI TARAFIN kutusuna da "duraklatildi" basiyordu.
  (6) PiP baslatma 1200ms TEKRAR PENCERESI + native `applicationState == .background` kapisi.
  (7) Olcum: `yerelOn/yerel1/yerel3`, `arka1/arka3`, `durum`, `pipAktif`.
  ⚠️ YAPMA: kose gozcusunu tekrar buyuk kutunun dalinin altina tasima; capture session'i
  disaridan yeniden yapilandirma (45: takilma / 47: medya durur); arka planda `startRunning()`
  kurtarmasi ekleme; `.background` kapisini kaldirma.
- **KALDIGIMIZ YER (27 Tem 23:10):** TEST TURU 47 YAYINLANDI — android 30300476213 +
  ios 30300478407 (e160976), R2 apk=105227857 ipa=19144584, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 47 — "kose kutusu (kendi goruntum) yine donuyor":**
  OLCUM: turu 44 (tazeleme VAR) `oturum=true` · turu 46 (tazeleme YOK)
  `oturum=false cagri=1 msMax=0`. Yani turu 46'nin TAKILMA duzeltmesi tuttu ama AYNI turda
  (45) kaldirdigim **kamera-izni tazelemesi YUK TASIYORMUS** — kaldirinca kamera arka planda
  yine oluyor. Kesinti kaydi: `sinif=AVCaptureMultiCamSession` (webrtc-sdk PAYLASILAN statik
  multicam oturumu — bayrak orada sarkabiliyor; Apple'in "baslatmadan once yaz" kurali
  GEREKLI ama TEK BASINA YETMIYOR) ve `kurtarma=null` (kosulda `!calisiyor` vardi ama kesinti
  aninda `isRunning` HALA true).
  **FIX:** tazeleme GERI GELDI ama yazma **ARKA PLAN KUYRUGUNDA** (turu 45'teki takilmanin
  sebebi yazmanin kendisi degil, ANA IS PARCACIGINDA yapilmasiydi) · Dart `inactive` dalindaki
  tazeleme cagrisi geri geldi · kurtarma kesintiden **400ms sonra** kontrol edip deniyor.
  ⚠️ YAPMA: tazelemeyi ana is parcacigina tasima (takilma doner) veya kaldirma (kamera oluyor);
  `!calisiyor` sartini kesinti anina geri koyma.
- **KALDIGIMIZ YER (27 Tem 21:54):** TEST TURU 46 YAYINLANDI — android 30294743012 +
  ios 30294745045 (e07c24d), R2 apk=105227857 ipa=19144256, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK (alta alma akici mi).
- **TEST TURU 46 — "ALTA ALIRKEN ZORLANIYORUM, EKRAN KAYIYOR AMA INMIYOR":**
  Tek bir home hareketinde `startPictureInPicture()` **5 KAYNAKTAN** cagriliyordu:
  (1) SceneDelegate `sceneWillResignActive` (turu 43) — SENKRON, UIKit gecis callout'unun
  ICINDE ve parmak HENUZ EKRANDAYKEN (home hareketi INTERAKTIFTIR), (2) Dart `inactive`,
  (3) Dart `hidden` (Flutter iOS'ta SENTEZLER), (4) Dart `paused`, (5) iOS auto-enter.
  Tek koruma `isPictureInPictureActive` ACILIS ANIMASYONU boyunca FALSE doner — hicbirini
  durdurmuyordu. Hareket IPTAL edilirse `.active`e donulur -> didStart kapisi
  `stopPictureInPicture()` cagirir -> ac-kapa savasi.
  **FIX:** SceneDelegate kancasi KALDIRILDI · NATIVE tek-istek kapisi (`baslatIstendi` +
  1.5sn emniyet timer'i, tum delegate dallarinda sifirlanir; `isPictureInPicturePossible`
  false iken bayrak SET EDILMEZ) · DART yalniz `inactive` + YON KONTROLU (`_sonYasamDurumu`,
  yalniz `resumed`dan geliyorsak) · OLCUM `cagri`/`msMax` Sentry'e.
  ⚠️ YAPMA: `paused`/`hidden` dallarini geri ekleme; yon kontrolunu kaldirma; SceneDelegate'e
  tekrar senkron `startPictureInPicture` koyma; tek-istek bayragini `possible==false` iken
  set etme (pencere HIC acilmaz — turu 20 regresyonu).
- **KALDIGIMIZ YER (27 Tem 20:45):** TEST TURU 45 YAYINLANDI — android 30289622533 +
  ios 30289624993 (5c07af0), R2 apk=105227857 ipa=19143856, purge OK, CDN birebir, IPA icinde
  MinimumOSVersion=16.0, backend degismedi + health ok, DB temiz.
  **ARAMA/PiP FAZI TAMAMLANDI** (kullanici onayi: "on numara").
- **TEST TURU 45:** "alta alirken zorlaniyorum, ekrani zorla ciziyor gibi" —
  KOK: turu 31'de `didChangeAppLifecycleState` `inactive` dalina konan
  `iosArkaPlanKamerayiTazele()`, CALISAN `AVCaptureSession` uzerinde
  `beginConfiguration`/`commitConfiguration` yapiyordu: AGIR is + TAM GECIS ANI + ana is
  parcacigi. Kaldirildi; `cokluGorevKameraAc()` SALT OKUMA yapildi.
  ⚠️ YAPMA: gecis aninda (inactive/paused) capture session yeniden yapilandirma; bu metoda
  tekrar begin/commitConfiguration koyma. (Bayragi turu 37 swizzle'i zaten DOGRU anda yaziyor.)
- **SIRADAKI IS:** teshis/olcum kodlarinin temizligi -> **MEDYA MESAJLASMA (foto/video/sesli
  mesaj)** -> kalici grup sohbeti -> profil -> yayin oncesi temizlik (admin "Ses Teshis"
  sekmesi, BTK yer saglayici bildirimi).
- **KALDIGIMIZ YER (27 Tem 20:12):** TEST TURU 44 YAYINLANDI — android 30287113321 +
  ios 30287115762 (26c8854), R2 apk=105227857 ipa=19143659, purge OK, CDN birebir, IPA icinde
  MinimumOSVersion=16.0 dogrulandi, backend degismedi + health ok, DB temiz.
- ✅ **iOS ARKA PLAN KAMERASI KANITLI COZULDU (20+ turluk sorun):**
  Sentry: ONCE `oturum=false` + `kamera kesinti sebep=1` -> SONRA `oturum=TRUE`, kesinti
  kaydi YOK. Kullanici: "alta indirdigimde donma vs olmadi." KOK COZUM =
  `IPHONEOS_DEPLOYMENT_TARGET` 15.0 -> **16.0**.
  ⚠️ **BIR DAHA YANILMA:** `isMultitaskingCameraAccessSupported=true` olcumu BIZI 20 TUR
  YANILTTI — o AYRI kapidir ("iOS 18 SDK'ya link + UIBackgroundModes'ta voip" ile true doner).
  PiP'te kamera KULLANMA izni **deployment target**'a bakar (Apple: "Apps that have a
  deployment target earlier than iOS 16 require the multitasking-camera-access entitlement").
  ⚠️ Deployment target'i 16'nin ALTINA dusurme — arka plan kamerasi ANINDA bozulur.
- **TEST TURU 44 FIX:** "iki kutuda da beni gosteriyor" — PiP, karsi tarafin videosu HENUZ
  abone olunmadan kurulabiliyor; `aday` YEREL'e dusuyor ve turu 36 kimlik-calkanti korumasi
  onu KILITLIYORDU. Uzak video gelince pencereyi KAPATMADAN sicak gecis
  (`PipService.iosPipKaynak` -> native `kaynakDegistir`; yalniz sink tasir).
  ⚠️ YAPMA: bu gecisi `iosPipKur` ile yapma (pencere kapanir — turu 24/26 dersi).
- **SIRADAKI (kullaniciya sunuldu):** teshis/olcum kodlarinin temizligi ->
  **MEDYA MESAJLASMA (foto/video/sesli mesaj)** -> kalici grup sohbeti -> profil ->
  yayin oncesi temizlik (admin "Ses Teshis" sekmesi, BTK yer saglayici bildirimi).
- **KALDIGIMIZ YER (27 Tem 19:47):** TEST TURU 43 YAYINLANDI — android 30285412862 +
  ios 30285415219 (0a14f97), R2 apk=105227857 ipa=19142958, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. **IPA icinde MinimumOSVersion=16.0 DOGRULANDI.**
  KULLANICI TEST EDECEK — kok neden HIPOTEZ, cihazda kanitlanmadi.
- **TEST TURU 43 — iOS ARKA PLAN KAMERASININ ASIL KAPISI (Apple dokumani):**
  *"In iOS 16 and later, you can use the camera in Picture in Picture mode by enabling a
  capture session's isMultitaskingCameraAccessEnabled property. **Apps that have a deployment
  target earlier than iOS 16 require the com.apple.developer.avfoundation.multitasking-
  camera-access entitlement to use the camera in PiP mode.**"
  BIZIM `IPHONEOS_DEPLOYMENT_TARGET` **15.0** IDI -> kapi kapaliydi. Artik **16.0**.
  ⚠️ `isMultitaskingCameraAccessSupported=true` olcumu BIZI YANILTTI: o AYRI bir kapidir
  ("iOS 18 SDK'ya link + UIBackgroundModes'ta voip" ile true doner). PiP'te kamera KULLANMA
  izni DEPLOYMENT TARGET'a bakar. Ayrica Apple `enabled` icin yalniz
  `videoDeviceNotAvailableWithMultipleForegroundApps` kesintisini bastirmayi taahhut eder —
  bizim aldigimiz sebep=1 (InBackground) o degildi. Olcum tutarliydi, YORUM yanlisti.
  ⚠️ **ENTITLEMENT EKLEME**: profilde olmayan entitlement imzayi patlatir, ad-hoc IPA hic
  uretilmez (jitsi-meet #12839 ayni hatayi yasamis). Ancak Apple'a basvurup profil
  yenilendikten sonra eklenebilir.
  ⚠️ **UYGULAMA SCENE TABANLI**: Apple "If you're using scenes, UIKit will not call this
  method" — AppDelegate'e yazilacak yasam dongusu kancalari OLU KODDUR. Dogru yer
  `SceneDelegate.swift` (pbxproj'da KAYITLI, yeni dosya ekleme YOK). PiP artik oradan,
  arka plana gecmeden ONCE baslatiliyor.
  ⚠️ Kesintide kamerayi ANINDA mute etme: Apple "If you don't explicitly call stopRunning(),
  your startRunning() request is preserved" — native 1 kez `startRunning()` deniyor, Dart
  durust mute'u 1.5sn erteliyor; kurtarma tutarsa mute ATLANIR.
- **ETKI:** iOS 15'te kalmis cihazlar (iPhone 6s/7/SE1) artik uygulamayi KURAMAZ.
- **KALDIGIMIZ YER (27 Tem 18:38):** TEST TURU 41-42 YAYINLANDI — android 30279978077 +
  ios 30279981045 (6fef48a), R2 apk=105227857 ipa=19142325, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 41-42:**
  (1) **UYGULAMA-ICI YUZEN PENCERE KALDIRILDI** (kullanici: "gereksiz"). Yerine SESLI
  aramadaki ince serit (dokun -> aramaya don). `_yuzenVideo` kodu SILINMEDI — geri istenirse
  `active_call_banner.build()` icinde tek satir yeter.
  (2) **KOSE KUTUSU (WhatsApp gorunumu):** karsi taraf tam pencere + BEN sag-altta %34
  genislikte 4:3 kucuk kutu. iOS'ta native `yerelAyarla` artik UIStackView'a degil
  `callVC.view` uzerine KOSE KISITLARIYLA ekliyor; Android PiP icerigi icin
  `miniIzgara(..., ustUste: true)`.
  (3) **KOSE KUTUSUNA AYRI KARE GOZCUSU:** iOS arka planda kamerayi DURDURUR (olcum kaniti
  asagida) -> kutu 1.5sn kare gormezse DONMUS KARE yerine "Sen" yazisina duser. Kutu HEP
  durur, icerigi DURUSTTUR; Android'de kamera yasadigi icin kutu CANLI olur.
  ⚠️ YAPMA: kose kutusunu gozcusuz birakma (donmus kare geri gelir); yuzen pencereyi
  serit koymadan tamamen kaldirma (goruntulu aramada geri donus yolu kalmaz).
- **OLCUM KANITI (turu 40, Sentry — bir daha tartisma):**
  `ios pip olcum on=177 arka=75 kaynak=uzak oturum=false coklu=true` + `kamera kesinti sebep=1`
  (= videoDeviceNotAvailableInBackground). Yani coklu-gorev kamera izni DOGRU veriliyor ama
  **iPhone arka planda kamerayi yine de kapatiyor**; pencere saglikli (arka planda 3sn'de 75
  kare — karsi tarafin videosu agdan geldigi icin akiyor).
  SONUC: iPhone'da arka planda KENDI CANLI goruntun kucuk pencerede GOSTERILEMEZ (Apple).
  Uygulama-ici ve Android'de gosterilir.
- **SIRADAKI ONERI (kullaniciya sunuldu, karar bekliyor):** teshis kodlarinin temizligi ->
  **MEDYA MESAJLASMA (foto/video/sesli mesaj)** -> kalici grup sohbeti -> profil ->
  yayin oncesi temizlik (admin "Ses Teshis" sekmesi, BTK yer saglayici bildirimi).
- **KALDIGIMIZ YER (27 Tem 00:42):** TEST TURU 40 YAYINLANDI — android 30221177316 +
  ios 30221178264 (adfb558), R2 apk=105227857 ipa=19152061, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 40 — "ONCEDEN CALISIYORDU" SORUSUNUN CEVABI (git kaniti):**
  Kucuk pencerede KENDI kamerayi gosterme (`yerelId ?? uzakId`) YALNIZ 0bb2660 (turu 36) ile
  girdi; oncesi `uzakId ?? yerelId` (KARSI TARAF) idi ve CALISIYORDU. "Donuyor" sikayetleri
  turu 36'dan SONRA basladi. GERI ALINDI.
  **FIZIK:** iPhone uygulama arka plana gecince KENDI kamerayi DURDURUR; karsi tarafin
  videosu AGDAN geldigi icin AKMAYA DEVAM EDER. Kucuk pencereye kendi kamerani koymak =
  arka planda gosterilecek goruntu olmamasi = son karede donma.
  **KULLANICI GOZLEMI (teshisi kesinlestirdi):** "uygulama ICINDE kucultunce ust/alt bolme
  cok iyi calisiyor, uygulamadan CIKINCA gidiyor; Android'de ikisi de calisiyor."
   · uygulama ici pencere = BIZIM Flutter widget'imiz, uygulama ON PLANDA -> kamera yasiyor
   · iOS arka plan = SISTEM PiP'i (native), uygulama ARKA PLANDA -> kamera duruyor
   · Android PiP = uygulamanin KENDISI kucuk pencerede ("gorunur") -> kamera yasiyor
  ⚠️ YAPMA: kucuk pencere kaynagini tekrar YEREL yapma (kullanici istese bile once bu fizik
  anlatilmali); "sadece bizim goruntu" gibi belirsiz istegi UYARMADAN uygulama.
  **ACIK OLCUM:** Sentry "ios pip olcum on=.. arka=.. oturum=.. coklu=.." — `oturum=true`
  cikarsa arka planda kamera YASIYOR demektir ve kucuk pencereye WhatsApp gibi UFAK kendi
  goruntusu EKLENEBILIR; `false` ise Apple/cihaz kisitidir, kullaniciya kesin soylenecek.
- **KALDIGIMIZ YER (27 Tem 00:11):** TEST TURU 39 YAYINLANDI — android 30220063911 +
  ios 30220064859 (84066ac), R2 apk=105227857 ipa=19151962, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
  ⚠️ Kullanici "iki sorun var" demisti, ikincisini henuz tarif etmedi — SORULACAK.
- **TEST TURU 39 — DONMUS KARE ARTIK YAPISAL OLARAK IMKANSIZ:**
  KANIT: Sentry "ios pip 3sn kare=0" (yerel kaynak) + "kesinti kaydi YOK". Ama "kesinti yok"
  KAMERA CALISIYOR demek DEGIL (Apple yalniz `videoDeviceNotAvailableWithMultipleForeground
  Apps`i bastirir). Ayrica turu 32'de kullanici "karsinin goruntusu VAR, benimki YOK" demisti
  -> UZAK sink'e kare akiyor, YEREL sink'e akmiyor.
  (1) **KARE GOZCUSU** (native `gozcuBaslat`): 500ms tik, 3 tik (~1.5sn) yeni kare yoksa
  katman BOSALTILIR ("Kamera duraklatildi") + Dart'a `iosPipKareDurdu`.
  (2) **SICAK KAYNAK DEGISIMI** (`kaynakDegistir` / `PipService.iosPipKaynak`): YALNIZ sink
  tasinir; `pipController`/`callVC`/`videoView` DOKUNULMAZ -> `stopPictureInPicture`
  CAGRILMAZ -> PENCERE KAPANMAZ. Yerel kare durunca karsi tarafin videosuna gecilir; kamera
  DURUSTCE kapatilir (TAHMIN degil OLCUM).
  (3) **IKI TARAFLI OLCUM**: on/arka kare + `captureSession.isRunning` + `isMultitasking
  CameraAccessEnabled`; ON PLANA DONUNCE Sentry'e yazilir (arka planda teslim garantisiz).
  (4) **`_iosPipGuncelle` YENIDEN-GIRME KILIDI** (`_iosPipMesgul`): metot her notifyListeners
  ve saniyelik sayacla cagriliyor, `_iosPipKurulanId` await'ten SONRA yaziliyordu -> iki es
  zamanli akis `iosPipKur` cagirip native `birak()` ile PENCEREYI KAPATIYORDU (turu 24-29
  "pencere gidiyor" sikayetlerinin yapisal koku).
  ⚠️ YAPMA: gozcu esigini 1 tike dusurme; kaynak degisimini `kur()`/`birak()` ile yapma
  (pencere kapanir); yeniden-girme kilidini kaldirma; olcumu arka planda Sentry'e yollamaya
  calisma (teslim garantisiz — on planda gonder).
- **KALDIGIMIZ YER (26 Tem 22:22):** TEST TURU 38 YAYINLANDI — android 30216228929 +
  ios 30216229892 (6605a16), R2 apk=105227857 ipa=19148842, purge OK, CDN birebir, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
  ⚠️ Kullanici "iki sorun var" dedi, YALNIZ BIRINI (donma) tarif etti — ikincisi SORULACAK.
- **TEST TURU 38 — "ALTA ALINCA DONUYOR"UN GERCEK SEBEBI (Sentry kaniti):**
  · "ios coklu-gorev kamera destek=true" -> 70 kayit VAR · "ios kamera kesinti" -> HIC YOK.
  Yani **iOS kamerayi KESMIYOR**; kamerayi durduran BIZIM 900ms'lik arka plan kamera-mute
  yolumuzdu. livekit `stopCameraCaptureOnMute=true` oldugundan mute CAPTURE'I DURDURUR ve bu
  "nazik" durdurma `AVCaptureSessionWasInterrupted` URETMEZ -> ne haberimiz oluyor ne de
  "Kamera duraklatildi" etiketi cikiyor -> kucuk pencere SON KAREDE DONUYOR. Turu 36'dan beri
  pencere KENDI kamerami gosterdigi icin bu MANTIKSAL CELISKIYDI.
  **FIX:** iOS'ta PiP kuruluysa (`_iosPipKurulanId` dolu) kamera artik KENDILIGINDEN
  KAPATILMAZ. Yedek kaybolmadi — kamera gercekten durdurulursa OS soyler (turu 37 kesinti
  dinleyicisi) ve orada DURUSTCE mute edilir. Ayrica kamera her kapatildiginda
  `iosPipKareBosalt()` ile katman bosaltilir (donmus kare yerine etiket).
  **OLCUM:** PiP basladiktan 3sn sonraki kare sayisi Sentry'e yazilir ("ios pip 3sn kare=N").
  ⚠️ YAPMA: iOS'ta zamanlayiciyla kamera-mute'a geri donme (donma geri gelir); kamera
  kapatirken `iosPipKareBosalt` cagrisini atlama.
- **KALDIGIMIZ YER (26 Tem 21:55):** TEST TURU 37 YAYINLANDI — android 30215341399 +
  ios 30215342412 (26a2cf3), R2 apk=105227857 ipa=19148233 (BUYUDU=swizzle derlendi), purge OK,
  CDN birebir, backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
  ⚠️ Kullanici "iki sorun var" dedi, YALNIZ BIRINI tarif etti (donma) — ikincisi SORULACAK.
- **TEST TURU 37 — iOS ARKA PLAN KAMERA KOK NEDENI (Apple dokumaniyla kanitli):**
  Apple: *"you can enable multitasking camera access by setting this value to true **PRIOR TO
  STARTING THE CAPTURE SESSION**"*. Biz `isMultitaskingCameraAccessEnabled` bayragini ZATEN
  CALISAN session'a yaziyorduk (Dart tetikleyicilerin HEPSI startRunning SONRASI). iOS yazmayi
  KABUL ediyor, geri okuma `true` donuyor, ama **FIILEN ETKISIZ** -> arka planda capture durur,
  PiP SON KAREDE DONAR ve bayrak "true" gorundugu icin DURUST MUTE yedegi de calismaz (karsi
  taraf donmus kare gorur). flutter_webrtc bunu upstream'de HIC set etmiyor (1.4.0/1.5.2).
  **COZUM:** `GebzemKameraKanca` — `RTCCameraVideoCapturer.startCapture(with:format:fps:
  completionHandler:)` SWIZZLE edilir, ORIJINAL cagrilmadan HEMEN ONCE bayrak yazilir
  (uygulama acilisinda kurulur). Bu, "her mute/unmute YENI capture session yaratir, bayrak
  sifirlanir" sorununu da kokten kapatir. `cokluGorevKameraAc()` artik YALNIZ dogrulama.
  Ayrica `kesintileriDinle()` (AVCaptureSessionWasInterrupted) -> Dart `_iosKameraKesinti`:
  OS gercekten kestiyse kamerayi DURUSTCE mute et + PiP'te "Kamera duraklatildi" + sebep Sentry'e.
  ⚠️ YAPMA: kancayi kaldirip bayragi yalniz calisan session'a yazmaya donme; capture session'i
  stopRunning/startRunning ile "bounce" etme (WebRTC capturer disaridan durdurulmayi beklemez);
  pbxproj'a AYRI Swift dosyasi ekleme (BOM tuzagi — kod AppDelegate.swift icinde);
  coklu-gorev kamerasi icin ENTITLEMENT ekleme (imza patlar);
  deployment target'i 15->16 yapma (Apple'in "supported" kosulu OR'lu, cihazda zaten TRUE).
- **KALDIGIMIZ YER (26 Tem 20:23):** TEST TURU 34-36 YAYINLANDI — android 30212040142 +
  ios 30212041360 (0bb2660), R2 apk=105227857 ipa=19143161, purge OK, CDN birebir, sayfadaki
  saat GERCEK yukleme saati, backend DEGISMEDI (865c5f0) + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 34-36 (16 ajanlik denetim sonucu):**
  (1) **GRUP "KATIL" EKRANI**: ekran hic silinmemisti; yalniz "Android + uygulama ON PLANDA +
  WS call.incoming" yolunda cizilebiliyordu. iOS'ta WS call.incoming KOSULSUZ atlanir
  (cift-UI tuzagi — GEVSETME), Android kilitli/arka planda FCM->CallKit gelir. **`is_group`
  bayragi CallKit yukunde UC yerde dusuruluyordu**: `AppDelegate.swift` data.extra,
  `CallKitService.goster` extra, `_ayikla`. Artik ucdan uca tasinir; `main._callKitKabul`
  GRUP dalinda arama HENUZ cevaplanmaz -> `callServiceProvider.grupDavetiGoster` ile davet
  ekrani acilir; "Katil" normal `_accept` akisini calistirir. `_reject` artik
  `CallKitService.bitir` + onizleme kapatma da yapar (hayalet CallKit aramasi kalmasin).
  ⚠️ YAPMA: bu dali 1:1'e acma (CallKit'te zaten kabul edildi, ikinci onay yanlis);
  `hazirlaVeAc` hizli-acilisini 1:1'de bozma.
  (2) **ILK KAYITTA PATLAMA/IZIN GELMEMESI**: VoIP token OTURUMSUZ POST -> 401 -> `api.dart`
  interceptor TUM OTURUMU siler + `authProvider` invalidate -> GoRouter sifirdan kurulur ->
  kullanici KAYIT ekranindan LOGIN'e firlar, acik izin diyaloglari duser. Turu 33'te 5
  denemeyle 5 KAT siklasti. FIX: token POST'u oturum varsa yapilir; `/users/me/voip-token`
  ve `/users/me/fcm-token` 401'i oturumu SILMEZ. ⚠️ YAPMA: bu muafiyetleri kaldirma.
  (3) **iPHONE KUCUK PENCERE = SADECE KENDI KAMERAM** (kullanici karari): kaynak sirasi
  yerel -> uzak; ust/alt bolunme o TURDA `pipBolunme=false` ile kapatildi;
  `preferredContentSize` 120x213 (120x400 asiri uzundu, geri alindi).
  ⚠️ **BU MADDE ESKIDI (30 Tem denetimi):** `pipBolunme` turu 41-42'den beri **TRUE (ACIK)** —
  bolunme artik KOSE KUTUSU olarak ciziliyor. false yaparsan kose kutusu TAMAMEN kaybolur. **KIMLIK CALKANTISI KORUMASI**: kurulmus `_iosPipKurulanId` hala gecerli bir
  track'e isaret ediyorsa DEGISTIRILMEZ — aksi halde kaynak degisince `kur()`->`birak()`->
  stopPictureInPicture PENCEREYI KAPATIYOR (turu 24 dersi). `_yerelVideoTrackId` MUTE track
  de dondurur (arka planda oto-mute'ta id sabit kalsin diye KASITLI).
  (4) `iosKameraCanli` artik `!_iosCokluGorevDeniyor` sartini da tasir (bayrak tazeleme
  ucarken bayat deger okunup durust kamera-mute atlaniyordu -> karsi tarafta donmus kare).
- **DURUST SINIR:** iPhone'da CALARKEN kendi kamerani goremezsin (gelen arama ekranini Apple/
  CallKit cizer). Grup aramasinda kabul sonrasi "Katil" ekraninda gorunur; 1:1'de kabul eder
  etmez. Uygulama OLDURULURSE arama devam ettirilemez (OS kurali).
- **KALDIGIMIZ YER (26 Tem 18:44):** TEST TURU 32-33 YAYINLANDI — android 30208385166 +
  ios 30208386190 (7aca13b), R2 apk=105227857 ipa=19139678, purge OK, CDN birebir, sayfadaki
  saat GERCEK yukleme saati, **BACKEND DEPLOY EDILDI** (health ok), DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 32-33 (arka plan + kilit ekrani — 19 ajanlik arastirma sonucu):**
  (1) **ANDROID ONDEPLAN SERVISI** `AramaServisi.kt` + manifest `<service
  foregroundServiceType="microphone|camera">` + kanal `aramaServisiBasla/Dur` +
  `PipService.aramaServisi`. KOK: Android 14+ arka plana gecen sureci **10sn sonra DONDURUR**
  (cached apps freezer) -> WebRTC durur -> arama biter (kullanici: "5-10sn sonra bitiyor").
  Android 11+ arka plan mikrofonu icin `microphone` tipi ZORUNLU. Izinler alinmisti ama
  HICBIR servis yoktu. Baslat: `_connect` icinde `aktifKonusmaBasladi` ile ayni yer (izin
  KESIN + ekran GORUNUR). Durdur: `leave` icindeki `parkEdilen == null` kapisi + `parkiDusur`.
  (2) **KILITLI iPHONE CALMIYORDU**: VoIP token TEK denemede gonderiliyordu; PushKit kaydi
  ASENKRON oldugu icin giris aninda `getDevicePushTokenVoIP()` BOS donuyor ve BIR DAHA
  denenmiyordu -> `voip_tokens` satiri HIC olusmuyor. Her surumde DB TRUNCATE edildigi icin
  surekli tekrarliyordu. Artik istemcide 5 deneme (token alma + POST) ve sunucuda
  `voip push: VOIP TOKEN YOK` / `gonderildi` / `gonderim HATASI` loglari.
  (3) **ARANANDA KAMERA ACILMIYOR**: `_onizlemeAc()` unawaited + `_odayaBaglan` SENKRON
  okuma = iki kamera track'i (iOS'ta flutter_webrtc TEK `videoCapturer` uzerine yazar ->
  coklu-gorev bayragi YANLIS oturuma gider). Artik `_onizlemeIsi` en fazla **700ms** beklenir.
  `setCameraEnabled` try'siz idi -> istisna `_connect` catch'ine dusup `_svc.end` ile aramayi
  OLDURUYORDU; artik try/catch + "Kamera acilamadi". Zombi onizleme track'i `baslat`ta salinir.
  Gelen arama ekrani onizlemesi artik izin ISTIYOR (parite).
  (4) **iOS PiP ALT KUTU**: `preferredContentSize` 120x200 -> **120x400** (iki kutu 6:5 iken
  9:16 kaynak kirpiliyordu); `yerelAyarla` SONUC METNI dondurur (eklendi/track-yok/...),
  Dart Sentry'e yazar + bayragi sifirlayip TEKRAR dener; `localTracks` defterinden yedek
  cozumleme; `PipVideoView` bos siyah yerine "Kamera duraklatildi" etiketi (kare gelince gizlenir).
  (5) `cokluGorevKameraAc` artik sonucu GERI OKUR (kosulsuz true = yalan bayrak, durust mute
  yolunu kapatiyordu). `RoomDisconnectedEvent.reason` Sentry'e yazilir (olcum).
  ⚠️ YAPMA: ondeplan servisini izin alinmadan/arka plandayken baslatma; `_onizlemeIsi`
  await'ini kaldirma; VoIP token gonderimini tek denemeye dondurme; `yerelAyarla`yi tekrar
  sessiz-basarisiz yapma; Objective-C `NSMutableDictionary` icin Swift'te `.keys` kullanma
  (`allKeys` + String cast — iOS build bu yuzden patladi).
- **DURUST SINIR (kullaniciya soylendi):** iOS/Android'de kullanici uygulamayi OLDURURSE
  (app switcher'dan yukari atma) arama devam ETTIRILEMEZ — OS kurali, WhatsApp da yapamaz.
  Kilit ekrani ise devam EDER.
- **KALDIGIMIZ YER (26 Tem 16:40):** TEST TURU 27-31 YAYINLANDI — android 30204095501 +
  ios 30204096587 (eb29925), R2 apk=105227813 ipa=19138192, purge OK, CDN birebir, sayfadaki
  saat GERCEK yukleme saati, backend degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 27-31 (31 AJANLIK DENETIMLE BULUNAN KOKLER):**
  (1) **SIYAH PATLAMA KOKU**: video renderer'i if/else dallarinda YER DEGISTIRIYORDU (tam ekran
  dali -> kucuk pencere dali) -> element yeniden kurulur -> texture sifirdan. Artik iki video da
  anahtarli `AnimatedPositioned` icinde, YALNIZ dikdortgen animasyonla degisir (`_videoKutu`,
  260ms easeOutCubic). GRUPTA ayni kok: tile anahtari `video.sid` idi — sid YAYINLANANA KADAR
  NULL -> `mediaStreamTrack.id`.
  (2) **KARSI TARAF MUTE OLUNCA KUTU SILINIYORDU** (`_remoteVideo` muted'da null donuyordu) ->
  buyuk goruntu BANA zipliyor + donuste patlama. Artik mute track de doner, kutu KALIR, ustune
  `BeklemedeOrtusu` biner ("Kamera duraklatıldı" — WhatsApp yazisi; hold ise "Beklemede").
  (3) **HIZ**: 1:1'de `adaptiveStream`/`dynacast` KAPALI (grupta acik); gelen-arama onizleme
  kamerasi kapatilmadan controller'a DEVREDILIR (`baslat(hazirKamera:)`).
  (4) **CALLKIT KABULUNDE EKRAN ANINDA**: `hazirlaVeAc()` — answer REST'i beklemeden "Baglaniliyor"
  ekrani acilir (eskiden once sohbet listesi gorunuyordu). Navigator bekleme adimi 100ms -> 16ms.
  (5) **iOS PiP**: `uygun` sartindan `ekranGorunur` KALKTI (kucultulmus aramada PiP hic acilmiyordu);
  resumed'da `iosPipDurdur` KOSULSUZ; native `durdur()` kosulsuz + `iptalIstendi`; `didStart`
  uygulama ON PLANDAYSA pencereyi aninda kapatir; UIStackView ile ust/alt bolunme (`yerelAyarla`,
  kimlik SADECE uzak track); uzak video yoksa KENDI kameram ana kutu.
  (6) **iOS ARKA PLAN KAMERA BAYRAGI**: `isMultitaskingCameraAccessEnabled` capture SESSION'a
  yazilir; livekit `stopCameraCaptureOnMute=true` her kamera ac/kapa YENI session yaratip bayragi
  sifirliyordu -> `iosArkaPlanKamerayiTazele()` baglantida + kamera her acildiginda + arka plana
  GECMEDEN ONCE ('inactive') yeniden uygular.
  (7) **••• MENUSU ACIKKEN EKRAN KILITLENMESI**: `_sheetAcik` isaretlenmiyordu -> yanlis pop,
  kullanici bos ekranda kaliyor + SONRAKI arama ekrani hic acilmiyordu.
  (8) **YUZEN PENCERE SURUKLEME**: delta BUILD'deki bayat `pos`a ekleniyordu -> parmagin gerisinde
  kaliyordu. Artik guncel `_pos` + kenara 180ms yapisma.
  (9) Canli yayin ekranlarinda `pipModu` sade gorunumu YALNIZ Android (bayat bayrak iOS'ta
  kontrolsuz/cikissiz ekran = "ekran gidiyor").
  (10) Sohbette "Aramaya don" HEADER -> MESAJ BALONU (`_AktifAramaBalonu`).
  ⚠️ YAPMA: video renderer'i kosullu dallarda farkli konumlarda cizme; tile anahtarina sid koyma;
  `_remoteVideo`/`_katilimciVideosu`a `!muted` sarti geri koyma; `_iosPipGuncelle` `uygun` sartina
  `ekranGorunur` koyma; resumed'daki `iosPipDurdur`a `pipModunda` sarti koyma; arka plan kamera
  bayragini tek seferlik yapma; grupta adaptiveStream/dynacast kapatma; yeni sheet/dialog eklerken
  `_sheetAcik` + `whenComplete` unutma.
- **KALDIGIMIZ YER (26 Tem 13:13):** TEST TURU 24 YAYINLANDI — android 30197469551 +
  ios 30197470722 (3c52912), R2 apk=105211301 (SHA 716d9c6d) ipa=19134680, purge OK, backend
  degismedi + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 23-24 (arama deneyimi):** (1) YUZEN PENCERE yalniz `minimized && !ekranGorunur`
  iken cizilir (arama ekraniyla UST USTE binme hatasi). (2) CALARKEN kendi kameram TAM EKRAN
  (`kendimBuyuk`), karsi taraf acinca buyuk ONA gecer. (3) **iOS ARKA PLAN KAMERA**: kamera-mute
  900ms ERTELENIR; PiP basladi + `_iosArkaPlanKamera` (isMultitaskingCameraAccessEnabled)
  varsa HIC mute edilmez -> karsi taraf gormeye devam eder; destek yoksa mute (bulanik
  "Beklemede"). (4) **KUCUK PENCERE 2 KISI UST/ALT** (miniIzgara) + iOS native PiP'te IKI video
  (`GebzemPip.kur(trackId:, yerelTrackId:)`, `pipAddStacked`, kurulanId = "uzak|yerel").
  (5) **PiP'ten DONUS HIZI**: CallScreen PiP dalinda bos Scaffold YERINE `Offstage` — renderer'lar
  canli kalir (eskiden agac sifirdan kuruluyordu = yavas cizim). (6) Grup tile'lari 180ms hafif
  belirme. (7) **BILDIRIM SERIDI** `controller.bildirim` (5sn, yenisi eskisinin yerine):
  "X sessize alındı/sesini açtı/kamerasını kapattı-açtı", grupta "X katıldı/ayrıldı".
  (8) Kucuk ekranlarda border/golge KALDIRILDI.
  ⚠️ YAPMA: PiP dalinda tekrar bos Scaffold dondurme (yavas cizim geri gelir); iOS'ta kamerayi
  PiP baslamadan mute etme (karsi taraf goruntuyu kaybeder); miniIzgara'da 2 kisiyi tekrar
  yan yana yapma; yuzen pencereyi `ekranGorunur` kontrolsuz cizme.
- **KALDIGIMIZ YER (26 Tem 12:03):** TEST TURU 22 YAYINLANDI — android 30195338773 +
  ios 30195339779 (4f04497), R2 apk=105211301 ipa=19131169, purge OK, backend deploy + health ok,
  DB temiz. KULLANICI TEST EDECEK. **KALAN IS:** sohbetteki "aramaya don" kaydi HEADER yerine
  MESAJ BALONU olarak istendi (su an ust serit).
- **TEST TURU 22 (kok fixler):** (1) **"KULLANICI ZATEN ARAMADA" KOK COZUM** —
  `internal/calls/mesgul.go` `gercektenMesgul()`: DB 'active'/'joined' dese bile LiveKit'e
  `ListParticipantIdentities` ile SORULUR; kisi odada degilse satir OLU sayilir
  (`oluAramaTemizle`: katilimci 'left', oda bossa arama 'ended' + call.ended) ve kisi MUSAIT
  kabul edilir. `Add` (hem "zaten aramada" hem "baska gorusmede") ve `Start` (1:1 'active')
  yollarinda. LiveKit'e ULASILAMAZSA mesgul kabul (canli gorusme bolunmesin).
  (2) **ANINDA KAMERA**: giden goruntulu aramada kamera odaya BAGLANMADAN acilir
  (`_onizlemeAc` -> `kendiGoruntum`), baglantida AYNI track `publishVideoTrack` ile yayinlanir
  (canli yayin P1 deseni); yayinlanmadan biterse `_onizlemeBirak` kapatir.
  (3) **GRUP IZGARA**: sesli grup da ayni izgarayi kullanir (eski Wrap SILINDI — "hepsi
  gorunmuyor"); kamerasiz katilimci ORTADA daire avatar + ALTINDA renkli ad.
  ⚠️ YAPMA: mesgulluk kararini tekrar SADECE DB'ye baglama; LiveKit hatasinda kisiyi musait
  sayma; onizleme track'ini publish edildikten sonra stop etme (yayin kesilir).
- **KALDIGIMIZ YER (26 Tem 11:17):** TEST TURU 21 YAYINLANDI — android 30193969124 +
  ios 30193969987 (e101c8f), R2 apk=105211305 ipa=19129943, purge OK, backend deploy + health ok,
  DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 21 (WhatsApp grup-arama deneyimi + uyarilar):**
  (1) **BULANIK "Beklemede"** (`beklemede_katmani.dart`): uzak katilimcinin video track'i MUTED
  ise SON KARE blur + "Beklemede" (1:1 tam ekran + grup tile). `_beklemedekiVideo(p)` = subscribed
  && muted && track!=null.
  (2) **GRUP DAVET EKRANI**: gelen arama katmani `isGroup` ise WhatsApp duzeni — kendi kamera
  ONIZLEMESI (LocalVideoTrack, izin varsa) + kamera/mik ON-AYAR dugmeleri + "Yok say / Katil".
  Secim aramaya tasinir: `baslat(b, micAcik:, kameraAcik:)`. 1:1 ekrani AYNEN korundu.
  (3) **SOHBET KAYITLARI** (`internal/calls/grup_sohbet.go`): `call:group:invite:<id>` /
  `call:group:end:<id>` sistem mesajlari — kalici grupta grup sohbetine, ANLIK grupta arayanla
  olan DIREKT sohbete (grup sohbeti UI'si yok). Flutter `_CallLogChip` bunlari cizer.
  (4) **SOHBET UST SERIDI**: arama kucultulmusken "Aramada · Geri dönmek için dokun".
  (5) **PIL/BAGLANTI UYARILARI**: `battery_plus` + LiveKit veri kanali (`{"t":"batt","v":n}`,
  1 dk'da bir) -> `karsiPil`; `ParticipantConnectionQualityUpdated` yerel+UZAK -> `karsiKalite`;
  RoomReconnecting/Reconnected. Tek satir `uyariMetni` (oncelik: yeniden baglanma > baglanti > pil).
  ⚠️ YAPMA: `_beklemedekiVideo`u muted olmayan track'e acma (canli video bulaniklasir);
  grup davet onizlemesini kabul sonrasi kapatmayi unutma (kamera cakismasi);
  `call:group:*` sistem mesajlarini 1:1 arama kaydi (`call:missed:*`) ile karistirma.
- **KALDIGIMIZ YER (26 Tem 10:46):** TEST TURU 20 YAYINLANDI — android 30193050269 +
  ios 30193051177 (86e6717), R2 apk=105112813 ipa=19114885, purge OK, CDN birebir, backend
  deploy + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 20:** (1) **GSM ARAMA BEKLETME (Android)**: `READ_PHONE_STATE` izni +
  `TelefonDurumu.kt` (API31+ TelephonyCallback.CallStateListener / altinda PhoneStateListener)
  -> kanal olayi `gsmDurum` -> `PipService.gsmAramada` -> controller `beklemeyeAl` (medya durur,
  arama SUNUCUDA OLMEZ; telefon bitince kaldigi yerden devam). Izin verilmezse ozellik SESSIZCE
  kapali. iOS'ta ayni isi CallKit yapar (turu 18). Arama basinda `gsmDinle(true)`, bitince false.
  (2) **"Arama beklemede" paneli** (WhatsApp duzeni): beklemedeyken alt kontroller yerine
  "Aramayi bitir" / "Devam et".
  (3) **iOS KUCUK PENCERE AYARDAN BAGIMSIZ**: otomatik PiP telefon Ayari + Dusuk Guc Modu'na
  bagliydi; artik uygulama arka plana GECERKEN (inactive/paused) `GebzemPip.baslat()` ->
  `startPictureInPicture()` ELLE cagriliyor (arama + yayinci + izleyici ekranlari).
  (4) **OLU KATILIMCI**: webhook `participant_left` ANINDA islenir — 1:1 arama BITER, grupta
  katilimci 'left' + `call.participant.left`; kimse kalmadiysa arama biter; `participant_joined`
  -> 'joined' geri (reconnect). Boylece "iPhone kapatilinca karsida ekran donuyor / sonra
  'zaten aramada'" sorunu biter.
  ⚠️ YAPMA: GSM dinleyicisini izin olmadan zorlama (crash/ANR riski, sessiz kalsin);
  `iosPipBaslat`i on plandayken (resumed) cagirma (Apple reddeder); webhook'ta 1:1 icin
  `participant_left`i yok sayma (donma geri gelir).
- **SORU-CEVAP (kullaniciya):** bekletme MALIYETI ~sifir — beklemedeki arama SFU'da medya
  TASIMAZ (disable), yalniz sinyal baglantisi durur. Binlerce bekleyen arama sunucuyu zorlamaz;
  yuk KONUSAN aramalardadir.
- **KALDIGIMIZ YER (26 Tem 09:30):** TEST TURU 19 YAYINLANDI — android 30190799515 +
  ios 30190800266 (e2198ef), R2 apk=105112781 ipa=19111472, purge OK, CDN birebir, backend +
  LiveKit deploy, health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 19 (ANLIK KAPANIS):** (1) **LIVEKIT WEBHOOK** (yeni): `livekit.yaml` ->
  `webhook: api_key: <LIVEKIT_KEYS adi>, urls: [http://127.0.0.1:8080/livekit/webhook]`
  (LiveKit HOST aginda, api 8080'i host'a aciyor). Backend: `internal/livekit/webhook.go`
  (HS256 JWT dogrulama + govde SHA-256 ozeti; harici bagimlilik YOK) + `internal/calls/webhook.go`
  (`POST /livekit/webhook`, auth middleware DISINDA). KURAL: oda GERCEKTEN bosalinca
  (`participant_left` + numParticipants==0 VEYA `room_finished`) `calls` ('active') ve `streams`
  satirlari ANINDA 'ended'. 'ringing' fazina DOKUNULMAZ (gecmis "Cevapsiz" semantigi).
  DOGRULANDI: gecerli imza 200 / sahte 401 + LiveKit logu "sent webhook room_finished 1.7ms".
  (2) Sohbet basligindaki "Sesli aramada" YAZISI kaldirildi; arama ikonlari KILITLENMEZ (yalniz
  renk ipucu) + arama bitince durum ANINDA tazelenir (kullanici "kapattim hemen arayamiyorum").
  (3) YUMUSAK KAPANIS: arama/yayin ekranlari 220ms solma + %94 kuculme ile kapanir (_kapanisSarmal).
  (4) Oda kapatma zaman asimlari 3sn -> 1.2sn (yeni arama kilit sirasinda beklemesin).
  ⚠️ YAPMA: webhook'ta 'ringing' aramalari kapatma (cevapsiz gecmisi bozulur); tek katilimci
  ayrilinca (numParticipants>0) arama kapatma (mobil ag kopmasi aramayi oldurur); webhook ucunu
  auth middleware'e sokma (LiveKit Bearer token gondermez, kendi JWT'siyle gelir);
  livekit.yaml'daki webhook.api_key'i LIVEKIT_KEYS'teki ANAHTAR ADINDAN farkli yazma.
- **KALDIGIMIZ YER (26 Tem 08:51):** TEST TURU 18 YAYINLANDI — android 30189717769 +
  ios 30189718708 (508208a), debug imza YOK, R2 apk=105096401 ipa=19108493 index=6437, purge OK,
  CDN birebir, backend deploy + health ok, DB temiz. KULLANICI TEST EDECEK (ozellikle ARAMA
  BEKLETME + iOS CallKit hold).
- **TEST TURU 18:** (1) **KONUK SINIRI 4** (yayinci dahil): `STREAM_MAX_GUESTS` varsayilan **3**
  konuk; 0 = sinirsiz. IZLEYICI sinirsiz KALDI (STREAM_MAX_VIEWERS=0).
  (2) **ARAMA BEKLETME (call waiting + hold):**
  · BACKEND: mesgul kullaniciya ikinci arama ARTIK ILETILIR — `Start` 'active' ise
    `waiting:true` ile WS/push gonderir (yalniz callee'nin telefonu ZATEN CALIYORSA eski 409).
    Yeni uc `POST /calls/{id}/hold {on}` -> karsi tarafa WS `call.held`.
  · CONTROLLER: `ParkEdilenArama` (oda+listener+sure+mic/cam) · `parkEt()` (medya durur, ODA
    ACIK kalir: LiveKit `RemoteTrackPublication.disable()` + yerel mic/kam kapali) · `devamEt()`
    (sure KALDIGI YERDEN `_sureBaz`, ses birimi `_sesiAc(true)` ile tazelenir) · `parkiDusur()`
    · `beklemeyeAl(callId,on)` (CallKit/GSM hold, id-farkindalikli) · aktif arama bitince
    beklemedekine 500ms sonra OTOMATIK donus.
  · UI: gelen arama katmani `waiting` ise UC dugme; uygulama genelinde turuncu
    "Beklemede: X — dokun ve gec" seridi (✕ bitirir); arama ekraninda "⏸ Beklemede" rozeti.
  · iOS: `IOSParams.supportsHolding=true` + `maximumCallsPerCallGroup=2` + AppDelegate VoIP
    yolunda `data.supportsHolding = true` -> "Beklet ve Kabul / Bitir ve Kabul / Reddet"
    ekranini SISTEM cizer; `CallEventActionCallToggleHold` artik ISLENIYOR.
  ⚠️ **GERI ALMA (iOS beklet sorun cikarirsa):** callkit_service.dart `IOSParams.supportsHolding`
  + AppDelegate.swift `data.supportsHolding` -> **false**. (Eskiden false idi cunku hold olayi
  ISLENMIYORDU; artik medya durdurma + ses birimi tazeleme var.)
  ⚠️ YAPMA: `answer(zorla:)` kapisini gelisiguzel acma (yalniz beklet/bitir-kabul yolunda);
  `parkEt` sonrasi eski odayi `leave` ile kapatma (park BITMEZ, sunucuda 'active' kalir);
  `baslat()`te `parkEdilen`i sifirlama (beklemedeki arama kaybolur); oda/canli yayin
  ekranlarinda ikinci aramayi gosterme (ses cakismasi — `aktifAramaVar` kapisi).
- **KALDIGIMIZ YER (26 Tem 08:15):** TEST TURU 17 YAYINLANDI — android 30188758448 +
  ios 30188759300 (9c00366), debug imza YOK, R2 apk=105014357 ipa=19103992 index=6442, purge OK,
  CDN birebir, backend deploy + health ok (yeni uc /users/{id}/presence canli), DB temiz.
- **TEST TURU 17 FIXLERI:** (1) **IZLEYICI SINIRI KALDIRILDI**: STREAM_MAX_VIEWERS varsayilani
  300 -> **0 (SINIRSIZ)**; watch/heartbeat/invite kapasite kontrolleri `maxIzleyici > 0` sartli;
  LiveKit odasi max_participants=0. (Konuk siniri turu 16'da kalkmisti.) (2) **KUCUK PENCERE
  IZGARASI** `mobile/lib/features/calls/mini_izgara.dart`: 1 tam · 2 SOL/SAG · 3 ustte 2 + ALTTA 1
  TAM GENISLIK · 4 CEYREK (2x2); en fazla 4 kutu (+N rozeti); kutular alani DOLDURUR (bosluk yok),
  video yoksa harf avatari. Kullanan: arama sistem PiP + uygulama-ici yuzen pencere
  (`ActiveCallController.miniKatilimcilar` — uzaklar/grupta aktif konusan once, BEN en sonda),
  canli yayin yayinci PiP'i (yayinci+konuklar) ve izleyici PiP'i (yayinci+konuklar, kimlik kapisi
  korunur). (3) **KISI ARAMA DURUMU**: yeni uc `GET /users/{id}/presence` ->
  {in_call, call_type, in_stream} (1:1 + grup 'joined' + yayincilik). Sohbet basliginda
  "🎙 Sesli aramada / 🎥 Goruntulu aramada / 🔴 Canli yayinda"; ilgili ikon YESIL-AKTIF digeri
  PASIF; mesgulken dokunus arama BASLATMAZ, durumu soyler; 15sn'de tazelenir.
  ⚠️ YAPMA: miniIzgara'ya en-boy koruma ekleme (kucuk pencerede bosluk kotu duruyor); PiP
  izgarasinda 4'ten fazla kutu cizme (okunmuyor); presence ucunu liste ekranlarinda (sohbet
  listesi/arama sonuclari) kisi basina cagirma (N+1 sorgu) — tekil sohbet ekraninda kalsin;
  maxIzleyici kontrollerini `> 0` sartsiz geri koyma (sinir geri gelir).
- **KALDIGIMIZ YER (26 Tem 07:46):** TEST TURU 16 YAYINLANDI — android 30187982072 +
  ios 30187982757 (c2c7b3b), debug imza YOK, R2 apk=104997973 (SHA effad2c9) ipa=19099167
  index=6444, purge OK, CDN birebir, backend deploy + health ok, DB temiz. KULLANICI TEST EDECEK.
- **TEST TURU 16 FIXLERI:** (1) **KONUK SINIRI KALDIRILDI** (kullanici karari): maxKonuk sabiti (4)
  -> `var maxKonuk = konukSinirOku()` env `STREAM_MAX_GUESTS` (0/tanimsiz = SINIRSIZ); Lua
  `max <= 0` ise kapasite kontrolu ATLANIR. Pratik tavan cx33'te ~5-8 video yayinci (kod
  engellemez). (2) **IZGARA SON SATIR TAM GENISLIK:** son satirda TEK kisi kalirsa yarim
  genislikte solda durmaz, TAM GENISLIK (yatik) olur — `yayinIzgara` (canli yayin) ve
  `_grupVideoIzgara` (grup aramasi; GridView.count -> elle satir/sutun, 4 satir ustu kaydirma
  KORUNDU). 3 kisi: ustte 2 + altta 1 genis (WhatsApp duzeni). (3) **GERI SAYIM SADE:** karartma
  katmani + mor golge + pop animasyonu KALDIRILDI; sayarken TUM arayuz gizli (yalniz kamera +
  ortada beyaz rakam). ⚠️ YAPMA: geri sayima golge/karartma/animasyon geri koyma; izgarada son
  satir tek kisiyi tekrar yarim genislige dusurme; maxKonuk'u tekrar SABIT yapma (env kalsin).
- **KALDIGIMIZ YER (26 Tem 07:11):** TEST TURU 15 YAYINLANDI (yayin arka plan/PiP + yayin sonrasi
  ARAMA DUSMESI kritik fix), KULLANICI TEST EDECEK. android 30187028051 + ios 30187028788 (d468ef8),
  debug imza YOK, R2 apk=104997973 (SHA farkli!) ipa=19101212 index=6540, purge OK, CDN birebir,
  backend degismedi + health ok, DB temiz.
- **TEST TURU 15 FIXLERI:** (1) **KRITIK — yayin sonrasi arama duser:** izleyici ekraninda yayin
  bitince MODAL DIALOG aciliyor, `_cik()` ancak "Tamam"da calisiyordu -> `yayin_<id>` MESGUL
  MUHAFIZI askida kaliyor -> gelen arama `answer()` null -> CallKit bitir + end -> ARAYANIN HATTI
  ANINDA DUSUYORDU. Artik yayin bitince muhafiz+oda+ekran ANINDA birakilir, bilgi kok SnackBar.
  (2) **Yayinda arka plan/PiP:** yayin ekranlarinda PiP davranisi HIC YOKTU -> yayinci alta alinca
  kamera capture durur, IZLEYENLER DONMUS KARE gorurdu. PipService yeniden yapilandirildi (kanal
  handler TEK yerde; `pipModu` ValueNotifier; `pipIzinli(sahip:)` sahiplik korumasi; dugmeleriGoster),
  MainActivity `setPipDugmeler` (yayin PiP'inde arama dugmeleri gizli, BOS liste acikca set edilir),
  AppDelegate GebzemPip.kur uzak track yoksa YEREL track'e duser (iOS yayincisi kendi kamerasi),
  yayinci+izleyici ekranlarina PiP izni + PiP'te SADE gorunum, PiP YOKSA arka planda kamera
  DURUSTCE mute (donmus kare yerine avatar) + donuste geri ac.
  ⚠️ YAPMA: yayin bitisini tekrar MODAL DIALOG'a baglama (mesgul muhafizi askida kalir, aramalar
  duser); PipService kanal handler'ini tekrar tek sahibe (controller) verme (yayin ekrani dinleyemez);
  `pipIzinli`yi sahipsiz cagirma (yayin PiP'ini arama controller'i kapatir); yayinci arka plan
  kamera-mute'unu kaldirma (izleyicide DONMUS kare geri gelir).
- **BILINEN DAVRANIS:** yayin/oda ekrani ACIKKEN gelen arama "mesgul" sayilir (ses cakismasi
  karari) — telefon CALMAZ. Istenirse ayri faz: "yayin izlerken arama calsin, kabulde yayindan cik".
- **TEST TURU 14 SURUMU YAYINLANDI (26 Tem 06:11) — KULLANICI TEST EDECEK:** android 30185398548 +
  ios 30185399247 (ae26a76), debug imza YOK, R2 apk=104997973 ipa=19096351 index=6570, purge OK,
  CDN birebir, backend deploy + health ok, DB temiz. ARAMA KUCUK EKRAN (PiP) + HAT DUSME:
  (1) **1:1'de PiP gelmiyordu** — `_pipIstenir` kapisi `(_camOn || _uzakVideoVar())` idi; arka plana
  inince kamera OTO-MUTE oluyor (_camOn=false) ve karsi taraf da alta alininca uzak video mute ->
  izin kapaniyordu (grupta 3+ kisiden biri hep acik oldugu icin sorun gorunmuyordu). Artik
  `goruntuluMu` (arama tipi video VEYA biri kamera acmis). (2) **PiP'te buton yoktu** — MainActivity
  RemoteAction (mikrofon ac/kapa + kapat) -> broadcast -> 'pipEylem' -> toggleMic/leave; ikon durumla
  guncellenir (setMicDurum); kendi vektor ikonlarimiz res/drawable/pip_*.xml. (3) **Pencere kucuktu**
  — PiP orani 9:16 -> 3:4; uygulama-ici yuzen pencere 116x168 -> 152x232 (mic+HOPARLOR+kapat 36px).
  (4) **PiP'te kendi kameram kapaniyordu** — lifecycle 'paused' pipDegisti'dan once gelebiliyor;
  kamera-mute 900ms ERTELENIR, PiP baslarsa hic yapilmaz. (5) **PiP icerigi UYGULAMA KATMANINDA**
  (AktifAramaBanner/MaterialApp.builder, tam ekran) -> arama kucultulup baska sayfadayken de PiP'te
  karsi taraf gorunur; CallScreen PiP dalinda renderer YOK. Arama bitince PiP kapanir (moveTaskToBack).
  (6) **HAT DUSME (backend)** — uygulama zorla kapatilinca End gelmiyor, satir 2 SAAT 'active'
  kaliyordu; grup satirini pairwise temizlik (is_group=false) hic kapatmiyordu -> grup baslatan
  2 saat "baska gorusmede". Sweeper artik LiveKit'e soruyor (ListRoomNames + ListParticipants):
  odasi YOK/BOS olan >=90sn 'active' aramalar kapatilir + call.ended. (7) Goruntulu aramada
  HOPARLOR varsayilan ACIK. ⚠️ YAPMA: `_pipIstenir`e tekrar `_camOn/_uzakVideoVar` sarti koyma
  (1:1 PiP olur); PiP icerigini CallScreen'e geri tasima (kucultulmus aramada PiP bozulur);
  kamera-mute gecikmesini kaldirma (PiP'te karsi taraf seni goremez); olu-arama sweeper'inda
  LiveKit hatasinda arama KAPATMA (yanlis pozitif); 90sn yas sinirini dusurme.
- **KALDIGIMIZ YER (26 Tem 06:11):** TEST TURU 14 YAYINLANDI (arama PiP/yuzen pencere + hat dusme,
  7 fix), KULLANICI TEST EDECEK. Onceki turda test turu 13 (canli yayin 6 fix) yayinlandi — o turun
  geri bildirimi de bekleniyor. Her sey commit+push, backend deploy + health ok, DB temiz.
  BEKLEYEN/ACIK: (1) kullanici test turu 13 + 14 geri bildirimi. (2) CANLI YAYIN MINIMIZE = AYRI FAZ
  (arama minimize/PiP test turu 14'te tamamlandi; YAYIN icin ayni desen uygulanabilir).
  (3) iOS GERCEK arka plan sistem PiP telefon Ayari + Dusuk Guc Modu'na bagli (bizim kod disi).
  Rutin: yeni surumde build->R2->purge->boyut dogrula->DB TRUNCATE->health. gh token .env.infra
  GITHUB_TOKEN, CF zone a8af9ee51c2c3ed70cc30d705038abfd, r2put.js scratchpad'de (her oturumda
  yeniden yaz — ⚠️ .env.infra'da satir-sonu YORUMLARI var, deger okurken `\s+#.*` KES).
- **TEST TURU 13 SURUMU YAYINLANDI (26 Tem 05:25) — KULLANICI TEST EDECEK:** android 30184022784 +
  ios 30184023533 (83ddcb4), debug imza YOK, R2 apk=104979437 ipa=19095161 index=6354, purge OK,
  CDN birebir, backend deploy + health ok, DB temiz. CANLI YAYIN 6 FIX:
  (1) **BAYAT NABIZ** (kok): nabiz UCARKEN konuk durumu degisirse donen yanit kosulsuz uygulaniyordu ->
  izleyiciyi konukluktan DUSURUYOR (hayalet slot), yayincida yeni konugun tile'i 15sn kayboluyordu.
  `_konukEpok` nesli (istek oncesi yakala, yerel degisiklikte artir, nesil degistiyse UYGULAMA).
  (2) **HAYALET KONUK SLOTU:** app-kill sonrasi geri donen konuk sunucuda `:guests` uyesi kalir,
  nabiz attigi icin sweeper ASLA dusurmez -> 4 slottan biri yayin boyu kilitli. Ekran acilisindaki
  guest_ids'te kendi id'im varsa (>=2. nabiz) slot BIRAKILIR. (3) **KACAN guest.accepted onarimi**
  (elle ✕ Ayril sonrasi geri sokmaz — `_elleAyrildim`). (4) **SESLI konuk kamera acamiyordu**
  (pill izin istemiyordu). (5) **KONUK ADLARI** izleyicide "Konuk" yerine gercek ad (guest.joined +
  backend watch `guest_list`). (6) **app-kill sonrasi eski yayin ~2 dk yeni yayini engelliyordu**
  (409'da stream_id doner -> "Kapat ve baslat" onayi). ⚠️ YAPMA: nabiz mutabakatini epok kapisi
  OLMADAN uygulama; hayalet-slot temizligini ilk nabizda yapma (gercek kabul yarisir); auto-promote'u
  `_elleAyrildim` guard'siz birakma; guest_list'i heartbeat'e tasima (300 izleyici x 15sn DB yuku).
- **TEST TURU 12 SURUMU YAYINLANDI (23 Tem 21:19) — KULLANICI TEST EDECEK:** android 30032129115 +
  ios 30032132733 (71a0e36), debug imza YOK, R2 apk=104979441 ipa=19092619, purge OK, CDN birebir,
  DB temiz, health ok. FIX: yayinIzgara TAM-BOY (Expanded-doldur, yarim-genislik x tam-yukseklik ~1:4.3)
  KOTU gorunuyordu (9:16 goruntu `cover` ile korkunc kirpiliyordu) -> **LayoutBuilder ile tile'lar
  DOGAL 9:16 PORTRE en-boy korur + ORTALANIR + yukseklige sigmazsa KUCULUR**. 2 kisi -> yarim-genislik
  x 9:16, ekran ortasinda (UZAMAZ). Seamless 2px koyu bosluk. ⚠️ YAPMA: yayinIzgara'yi tekrar Expanded-
  doldur (tam-boy) yapma; en-boyu bozma (kirpma artar); border/ClipRRect ekleme.
- Onceki: **TEST TURU 11 SURUMU YAYINLANDI (23 Tem 02:17):** android 29965135036 +
  ios 29965136743 (dc70108), debug imza YOK, R2 apk=104979437 ipa=19093092, purge OK, CDN birebir,
  backend deploy + health ok, DB temiz. **CANLI YAYIN COKLU-KONUK:** tek-konuk (Redis STRING/SETNX/
  cadScript) -> COKLU (`stream:{id}:guests` SET, **maxKonuk=4**); guestAddScript atomik kapasite Lua
  SADD; konukDusur SREM (uye-bazli); GuestRefresh SISMEMBER; is_guest=guestSet[id]; Watch/Heartbeat
  **guest_ids DIZI** (guest_id DEGIL); sweeper SMEMBERS dongusu; endStream `:guests`. FRONTEND:
  yayinSplitAlani(ust/alt) SILINDI -> **yayinIzgara(tiles)** (2 kisi YAN YANA/sol-sag, 3-4 grid,
  SEAMLESS border/ClipRRect YOK); SplitVideoPaneli avatarHarf (SESLI konuk avatar tile); broadcast
  `_konuklar` Map + _konukTile(id,ad) + _konukVideoBul; viewer `_aktifKonuklar` Set + ilkKonukIds +
  _konukOl KAMERA OPSIYONEL (mik zorunlu, kamerasiz SESLI katil, _kameramAcik) + pill kamera ac/kapa;
  live_start_screen geri sayim daire KALDIRILDI -> tam ortada 140px rakam (border yok).
  ⚠️ YAPMA: guests SET'i STRING yapma; yayinIzgara'ya border/ClipRRect ekleme; _konukOl kamerayi
  ZORUNLU yapma (sesli konuk bozulur); guest_ids'i guest_id'e dondurme; maxKonuk'u cx33'te cok buyutme
  (yayinci+4 konuk video publish = SFU yuku). kimlik-kapisi (bayat kendi id tile uretmez) KORUNSUN.
- Onceki: **TEST TURU 10 SURUMU YAYINLANDI (22 Tem 20:16):** android 29939980308 +
  ios 29939982616 (a710627), debug imza YOK, R2 apk=104963053 ipa=19087218, purge OK, CDN birebir,
  DB temiz, health ok. ASIL FIX: **UYGULAMA-ICI SURUKLENEBILIR YUZEN VIDEO** (active_call_banner.dart
  ConsumerStatefulWidget) — goruntulu aramada arama ekranindan cikip gezinince karsi tarafin canli
  videosunu gosteren mini pencere (116x168, dokun->don, mic toggle + kapat butonu, grupta aktif
  konusan, avatar yedegi). controller.bantVideo getter (uzak !muted / activeSpeakers). %100 Flutter
  kontrolu -> iOS Dusuk Guc Modu/ayar BAGIMSIZ, crash yok (arama==null->render durur). SESLI arama
  eski yesil bant. iOS PiP REGRESYON FIX: _iosPipGuncelle cokluGorevKamera artik iosPipKur SONRASI +
  bloklamayan (fire-and-forget, _iosCokluGorevDeniyor guard) — agir capture-reconfig PiP kurulumunu
  geciktirip auto-enter'i kaciriyordu.
  ⚠️ KRITIK OGRENME: iOS SISTEM PiP GUVENILIR YAPILAMAZ (arastirma kaniti) — auto-PiP telefon
  Ayari "PiP'i Otomatik Baslat" + Dusuk Guc Modu KAPALI sartina bagli (kullanici "sarj azken gelmedi"
  = Dusuk Guc Modu). ASIL COZUM uygulama-ici yuzen video (kontrolumuzde). YAPMA: bantVideo'yu yerel
  kameraya cevirme (karsiyi gormek istiyor); yuzen video renderer'ini track guard'siz cizme (crash);
  cokluGorevKamera'yi tekrar iosPipKur ONUNE await koyma (regresyon). Canli yayin minimize AYRI faz.
- Onceki: **TEST TURU 9 SURUMU YAYINLANDI (22 Tem 01:13):**
  android 29871829312 + ios 29871831125 (headSha 3dcdf3b), iOS Swift DERLEME GECTI (IPA
  19082928->19085286 buyudu=yeni native kaniti), debug imza YOK, R2 apk=104946669 ipa=19085286,
  purge OK, CDN boyut birebir, index saati BELIRGIN, health ok, DB temiz. FIXLER:
  (1) iOS PiP'te KENDI KAMERA CANLI: AppDelegate.cokluGorevKameraAc ->
  FlutterWebRTCPlugin.sharedSingleton.videoCapturer.captureSession.isMultitaskingCameraAccessEnabled
  (iOS16+ property, ENTITLEMENT YOK -> imza riski YOK; iOS16-17 destek cihaza bagli, desteksizse
  false->avatar yedegi). PiP delegate didStart/Stop/failed -> pipCh.invokeMethod -> pip_service.iosDinle
  -> controller pipModunda/_iosPipBasarisiz. Arka planda _iosArkaPlanKamera acikken kamera MUTE
  EDILMEZ (capture surer, karsi taraf gorur); PiP basarisizsa avatar yedegi. (2) GRUP iOS PiP:
  `!_isGroup` kapisi KALDIRILDI; _uzakVideoTrackId grupta room.activeSpeakers'tan baskin uzak
  konusanin videosunu secer (ActiveSpeakersChangedEvent zaten notifyListeners->_iosPipGuncelle).
  (3) CANLI YAYIN 3-2-1 GERI SAYIM: live_start_screen _basla REST ONCESI (hayalet live yok).
  ⚠️ YAPMA: cokluGorevKamera icin entitlement ekleme (imza patlar; iOS16+ property yeter);
  GebzemPip.kanal weak yapma (dealloc->geri bildirim gitmez); grup PiP'te yerel kamerayi PiP'e
  sokma (yalniz uzak konusan); geri sayimi REST SONRASINA koyma (hayalet live); _uzakVideoTrackId'e
  muted serti koyma (PiP kaybolur). iOS PiP GERCEK cihazda test edilir (simulatorde CALISMAZ).
- Onceki: **TEST TURU 8 FIX SURUMU YAYINLANDI (21 Tem 23:45) — KULLANICI KURUP TEST EDECEK:**
  android 29866251897 + ios 29866254208 (headSha 25419ff), debug imza YOK, R2 apk=104946669
  ipa=19082928, purge OK, CDN boyut birebir, index saati BELIRGIN, backend deploy + health ok,
  DB temiz. FIXLER: (1) iOS PiP donma (PipRenderer host-clock PTS + DisplayImmediately +
  isReadyForMoreMediaData — frame.timeStampNs RTP saati donduruyordu; referans videosdk/rn-webrtc)
  + PiP muted'ta sokulmez (_uzakVideoTrackId muted DAHIL — gecici kamera-kapamada pencere kaybolmasin).
  (2) Konuk-split OWN-DEVICE (3. nuks kok neden): atilan konugun KENDI ekraninda _aktifKonuk
  (kendi id'si) hic temizlenmiyordu -> "Görüntü bekleniyor" sonsuz. Fix: guest.left ben-dali +
  _konuktanCik + build KIMLIK KAPISI (_aktifKonuk != benim -> split cizilmez, takilma yapisal
  imkansiz) + 15sn NABIZ MUTABAKATI (heartbeat guest_id doner, kacan guest.* kendini onarir).
  (3) Watch guest_id -> gec katilan izleyici split gorur. (4) Cikis REST unawaited (olu agda
  10-20sn donma). (5) _konukOl re-entrancy + konukAyril catchError + mic mounted guard.
  ⚠️ PiP GERCEK iPhone'da test edilir (simulatorde CALISMAZ). YAPMA: _uzakVideoTrackId'e muted
  serti geri koyma (PiP kaybolur); split'e track-OR koyma (siyah bug diriltir); _cik'e REST await
  geri koyma (donma). Nabiz artik Future<String> (guest_id) doner — void'e cevirme.
- Onceki: **iOS PiP + KONUK-PANEL + YENI MENU SURUMU YAYINLANDI (20 Tem 22:50):** iPhone goruntulu aramada arka plana alininca UZAK video sistem PiP penceresinde (native GebzemPip AppDelegate.swift icinde; flutter_webrtc sharedSingleton+remoteTrackForId->RTCVideoRenderer->AVSampleBufferDisplayLayer->AVPictureInPictureController auto-enter; SES BIRIMINE DOKUNULMADI; kurulamazsa kamera-mute avatar yedegi); konuk SERT-KAPATINCA panel kalkar (ParticipantDisconnected); yeni menu (tap dairesi yok, radius, sik gorusulenler). **Kullanici GERCEK iPhone test edecek (PiP simulatorde test EDILEMEZ).** ⚠️ iOS PiP: pbxproj'a AYRI dosya EKLEME (BOM tuzagi) — kod AppDelegate.swift icinde; flutter_webrtc header <flutter_webrtc/FlutterWebRTCPlugin.h> public; V1 yalniz 1:1 goruntulu UZAK video (kendi kamera bg'de OS durur); ses sirasina DOKUNMA.
- Bu oturumda ayrıca YAYINLANDI (19 Tem 20:20 sürümü): Faz-A/B/C (minimize+yeşil bant,
  mesaj ikonu, kişi ekleme, davet, konuk+listeler, 30 hediye, 10k jeton) + 16 tarama fix'i.
  Mimari: aktif arama ActiveCallController'da (tuzaklar bölümüne bakın).
- Spaces özet: /rooms uçları (11), rol=DB, dinleyici publish yok, el kaldırma REST, sweep
  (LiveKit ListRooms kontrolü dahil), LiveKit pin v1.13.3, internal/livekit ortak twirp paketi.
- Grup görüntülü fazı 18 Tem akşam YAYINLANDI (oturum.md "Oturum 16": adımlar, test rehberi,
  bilinen sınırlar). Sonraki adaylar: test bulguları → geç-katılma/kişi-ekleme → kalıcı grup
  sohbeti → Spaces (yol haritası).
- Kritik bağlam: backend startGroup videoyu zaten destekliyordu; eklenenler = kapasite sınırı
  (video≤8/sesli≤32), grup düşük video profili (540p), grid video tile, başlatma ekranı seçimi,
  grup kamera butonu, overlay metni. 1:1 ve SESLİ grup davranışı DEĞİŞMEDİ (isGroup dalları +
  "video track yoksa eski avatar ızgara birebir").

## TELEMETRİ & İZLEME (12 Tem 2026 — hepsi canlı)
- **Sentry:** https://gebzem.sentry.io — gebzem-mobile + gebzem-backend projeleri; hatalar dosya+satır ile otomatik düşer. OTURUM BAŞINDA KONTROL ET. sentry_flutter ^9.6 (8.x KULLANMA — Kotlin/Swift derleme hatası)
- **Paneller (Caddy basic auth: gebzem/cKIZMzFJCyNERn):** nabiz.gebzem.app (Netdata), log.gebzem.app (Dozzle) · bekci.gebzem.app (Uptime Kuma: gebzem/Gebzem2026!, 4 monitor)
- **Admin panel:** https://api.gebzem.app/admin/izle (giriş: **admin / Gebzem2026!** — env ADMIN_USER/ADMIN_PASS override; login gövdesi `{"user","pass"}` alanları!). **ADMIN_KEY artık güçlü** (19 Tem, sunucu .env + .env.infra'da; eski `gbz-izle-2026` GEÇERSİZ) — kullanıcılar, aramalar + **canlı Ses Teşhis sekmesi** (audio-stat renk kodlu, 2sn yenilenir: 🟢SES-VAR 🔴iOS-CIKIS-YOK 🟠SES-GELMIYOR 🟣TRACK-YOK 🟡SES-DUSUK). Veri: bellek ring buffer (son 120) + docker log. GEÇİCİ teşhis — üretim öncesi kaldır.
- **Nöbetçi:** sunucuda dakikalık cron (backend/watchdog.sh) — API 2 kez sağlıksızsa otomatik restart, disk ≥%90 docker prune. Log: /var/log/gebzem-watchdog.log
- **API HTTPS:** https://api.gebzem.app (Cloudflare flexible SSL → Caddy:80 → api:8080). Caddyfile değişince `docker compose -f monitoring-compose.yml restart caddy` ŞART
- **Cloudflare Global API Key** .env.infra'da (CF_GLOBAL_KEY; legacy header: X-Auth-Email + X-Auth-Key — Bearer ÇALIŞMAZ). DNS tam kontrolde
- **ufw:** sadece 22/80/8080 açık
- **KURAL: Codemagic build tetikledikten sonra ANLIK izle** (arka plan poll scripti), patlarsa subactions[].logUrl'den logu çek, düzelt
- Kullanıcı anahtarları sohbete YAZMAZ → gbz-a3/token.txt'ye koyar, oradan oku (güvenlik filtresi tetiklenmesin)

## DAĞITIM KONTROL LİSTESİ (her yeni sürümde ZORUNLU — kullanıcı boşuna eski sürüm kurdu)
1. Build bitti mi + artifact var mı (status=finished ve .apk/.ipa mevcut)
2. APK debug imzayla mı derlendi? (logda "Signing with debug keys" OLMAMALI — SMS/Firebase çalışmaz)
3. R2'ye yükle (scratchpad/r2put.js — Cache-Control: no-cache gönderiyor)
4. **Cloudflare zone purge ŞART** (Global API Key ile) — yoksa CDN eski dosyayı servis eder
5. **Yayın sonrası doğrula:** sunucudaki Content-Length == yerel dosya boyutu; /health = ok
6. Ancak bundan sonra kullanıcıya "hazır" de

## CI/CD: GITHUB ACTIONS (Codemagic ücretsiz dakikaları bitti — 12 Tem 2026)
- Workflow'lar: `.github/workflows/android.yml`, `ios.yml` (workflow_dispatch ile tetiklenir)
- Tetikle: `gh workflow run android.yml --repo gbz-app/gebzem` · Takip: `gh run list/view --log-failed`
- Artifact indir: `gh run download <id> --repo gbz-app/gebzem --dir <klasor>`
- ⚠️⚠️ **SECRET KURALI:** `gh secret set NAME --body "deger"` KULLAN. **PowerShell borusu (`$x | gh secret set`) secret'ları BOZUYOR** (base64 invalid / keystore tampered / Apple 401). Çok satırlı anahtarlar (p8, pem) → **base64'le, workflow'da çöz**
- Kota: özel repoda 2000 dk/ay, **iOS 10x sayılır** (~12 iOS build/ay). Repo public yapılırsa sınırsız bedava

## RUTİN: HER YENİ SÜRÜMDE
1. Build (GitHub Actions) → artifact indir → içerik doğrula
2. **`node tools/uctan_uca.js`** canlı sunucuda (301 kontrol) — deploy SONRASI ZORUNLU
3. R2'ye yükle (**`node tools/indir/r2yukle.js`**) → **Cloudflare purge** → CDN MD5 = yerel MD5
4. **Veritabanını temizle:** `TRUNCATE users CASCADE; TRUNCATE otp_codes;`
5. ⚠️⚠️ **`node tools/tohum.js`** — TRUNCATE'ten HEMEN SONRA (turu 90 kullanıcı emri:
   *"her build'de hesaplar temiz olacak YENİDEN KURULACAK"*). 10 işletme + 2 kullanıcı
   + 2 ilan (1 iş ilanı + başvuru) + 2 etkinlik kurar, 10/10 işletmeden randevu alır
   ve **hesap tablosunu basar**. Betik idempotent (409'da login'e düşer).
   ⚠️ **Bu adım atlanırsa kullanıcı BOŞ bir uygulamaya girer** — test edecek hiçbir
   işletme/randevu/ilan olmaz. Betik hiçbir yerden otomatik çağrılmıyor.
6. **Çıktıdaki telefon/şifre tablosunu KULLANICIYA VER** (kullanıcı emri: *"her seferinde
   telefon ve şifrelerini TABLO ŞEKLİNDE verirsin"*).
7. Ancak sonra "hazır" de

## ARAMA SİSTEMİ (LiveKit — kendi sunucumuzda)
- LiveKit v1.13.3: `backend/livekit-compose.yml` + `livekit.yaml` (host network, TURN açık)
- Adresler: **wss://rtcd.gebzem.app:7443** (sinyal DOĞRUDAN, CF'siz — hız için 20 Tem; gri DNS + Caddy LE cert; istemcide `rtc.gebzem.app` fallback'i var. GERİ ALMA: docker-compose.yml LIVEKIT_URL=wss://rtc.gebzem.app + api restart, ANINDA). Eski **wss://rtc.gebzem.app** (CF proxied) hâlâ çalışır/fallback · **turn.gebzem.app: TLS 443 + UDP 3478** (DNS proxy KAPALI olmalı!)
- **use_ice_lite: true** (livekit.yaml, 20 Tem hız) — connectTime 2.6s→~0.55s. Geri alma: satırı sil + livekit force-recreate.
- ⚠️ **TURN TLS ŞART** (mobil operatör NAT'ı): Let's Encrypt sertifikası /opt/gebzem/letsencrypt (certbot+dns-cloudflare, Global Key ile). `external_tls: false` + cert_file/key_file. TLS'siz TURN = `dtls timeout`, ses gitmez!
- Sertifika yenileme (90 günde bir): `docker run --rm -v /opt/gebzem/letsencrypt:/etc/letsencrypt -v /opt/gebzem/cf:/cf certbot/dns-cloudflare renew` + livekit restart
- Portlar (ufw): 7880, 7881, 443, 3478/udp, 50000-50200/udp, 30000-40000/udp
- Teşhis: `node scratchpad/stuntest.js` (UDP/TCP erişim testi) · LiveKit logunda `dtls timeout` = medya geçmiyor, `"network":"cellular"` = operatör NAT'ı
- Backend: `internal/calls` — /calls (başlat), /calls/{id}/answer, /calls/{id}/end, GET /calls (geçmiş); WS: call.incoming/answered/ended
- Env: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET (sunucu .env'inde)
- Flutter: livekit_client + permission_handler; adaptiveStream/dynacast/simulcast açık (zayıf bağlantı + otomatik yeniden bağlanma)

## KRİTİK TUZAKLAR (tekrar yaşamayalım)
- **CallKit/VoIP push (iOS):** FCM VoIP push GÖNDEREMEZ → Go'dan doğrudan APNs (`app.gebzem.voip`).
  VoIP push gelince CallKit'e KOŞULSUZ `reportNewIncomingCall` (iOS 13+ kuralı: bildirmezsen Apple
  uygulamayı öldürür + VoIP push'ları keser). Android: `notification` DEĞİL **data-only** push +
  `@pragma('vm:entry-point')` (yoksa release'de tree-shake). Test: simülatörde CallKit ÇALIŞMAZ, gerçek cihaz şart.
- **1080p video:** H264 KULLANMA (SDK level 3.1 = 720p tavanı). VP8 + simulcast + `degradationPreference: balanced`
  (varsayılan `maintainResolution` → ağ kötüleşince fps çakılır). `restartTrack()` sender encoding'i
  yeniden HESAPLAMAZ → arama ortasında çözünürlük yükseltme temiz çalışmaz, BWE'ye bırak.
- **ARAMA HATASI ARARKEN ÖNCE ODA LOGUNU OKU** (12 Tem'de 3 saat kaybettim):
  `docker logs livekit | grep call_<id>` → `participant active` + `mediaTrack published`
  varsa **WebRTC/TURN ÇALIŞIYOR**, hatayı istemci mantığında ara.
  `dtls timeout` uyarılarının çoğu **kendi test scriptlerimin** odalarından gelir
  (`medyatest`, `icecheck`, `turntest`) — sinyale bağlanıp WebRTC yapmayan istemciler
  bunu üretir. **Oda/katılımcı adını filtrelemeden log okuma.**
- **iOS SES BİRİMİ (19 Tem, grup-host sessiz-mic dersi):** iOS'ta CallKit'siz bağlanan HER yol
  (grup hostu, giden arama) için ses birimi start'ı ÖNCESİ oturum aktivasyonu ŞART —
  AppDelegate setAudioEnabled(true) artık `setConfiguration(webRTC(), active:true)` yapıyor
  (CallKit'li yolda no-op). Bu satırı SİLME. Grup hostu ringback ÇALMAZ (kabulEdilenler
  kısayolu `|| widget.isGroup`) — geri getirme. Yeni CallKit'siz ses yolu eklerken (oda/yayın
  deseni) aynı sıra: bağlan → mic → hoparlör → setAudioEnabled EN SON.
- **ARAMA SÜRE SENKRONU (18 Tem, 3. kez elden geçti — REGRESYON YAPMA):** İki cihaz sayacı
  **monotonik `Stopwatch`** ile sayar (`_sureBaz + _sureSayaci.elapsed`), ASLA `DateTime.now()` ile
  sunucu zamanı karşılaştırmasıyla değil (saat kayması = yanlış başlangıç). Backend `answer()`/WS
  `call.answered` → `elapsed_ms` (~0); Status → `answered_at NULL iken -1` (**created_at'e DÜŞÜRME**
  → arayan zil fazında sahte referans kilitler, sayaç şişer!). İstemci referansı **yalnız `s=='active'`
  iken** alır. Push süre TAŞIMAZ (zamanlama güvenilmez). Grup HARİÇ (`!widget.isGroup`) → yerel sayaç.
- **AKTİF ARAMA = ActiveCallController (GLOBAL, Faz-C):** Room+timer+süre+ses birimi+muhafızlar
  `active_call_controller.dart`'ta; CallScreen SAF GÖRÜNÜM. **Ekran dispose'u aramayı BİTİRMEZ**
  (minimize sayılır — `ekranBeklenmedikKapandi`). Aramayı yalnız `leave` TEK KAPISI bitirir;
  yeni ekran-kapatan kod da leave'i kullanmalı. Teardown "ENQUEUE ANINDA YAKALA": kuyruğa koyarken
  room/listener/nesil senkron yakalanır (tek controller'da alanlar yeni aramada resetlenir —
  bekleyen eski teardown yeni Room'u öldürmesin). Minimize bitiş DEĞİL: muhafızlar dolu, timer'lar
  akar, CallKit aktif. Bant `AktifAramaBanner` (builder içinde — Navigator.of YASAK, root key'ler).
- **STALE-ASYNC DESENLERİ (19 Tem taraması — 16 bulgunun ortak kökleri, TEKRAR ETME):**
  (1) Uygulama-boyu controller/serviste HER async akış + event listener kendi kimliğini
  yakalar (`final id = b.callId;` → `if (arama?.callId != id) return;`) — "null mu" kontrolü
  YETMEZ, yeni arama devralmış olabilir. (2) Stale akış paylaşılan bayrak/timer/alanlara
  DOKUNMAZ — yalnız kendi yakaladığı nesneleri temizler (`_staleTemizle`). (3) Singleton
  provider'ı (wsProvider) INVALIDATE ETME — constructor'da abone olan singleton'lar (CallService,
  DavetServisi) ölü stream'de kalır; close()+connect() aynı instance'ı canlandırır.
  (4) Kullanıcı-tetiklemeli async akışa re-entrancy kilidi (çift dokunuş = çift REST/ekran).
  (5) Redis'te sahiplikli anahtar silme = compare-and-delete Lua (koşulsuz DEL yarışta yanlış
  sahibi siler). (6) Yetki/anahtar fallback'i YASAK — env boşsa fail-closed (repo PUBLIC!).
  (7) "Üyelik tazeleme" uçları (heartbeat) ilk-katılım kurallarını (blok/kapasite) atlamamalı.
- **Riverpod + overlay:** Bir widget'ı gösteren state'i, o widget'ın `async` işleminin
  ORTASINDA sıfırlama → widget dispose olur, sonraki `if (!mounted) return;` sessizce
  devreye girer ve **sonraki satır (Navigator.push) hiç çalışmaz**. Önce ekranı aç, sonra state'i temizle.
- **`MaterialApp.builder` içindeki widget Navigator'ın DIŞINDADIR** → `Navigator.of(context)`
  çalışmaz. `rootNavigatorKey` (GoRouter navigatorKey) + `scaffoldMessengerKey` kullan.
- **Firebase SMS bölge politikası:** yeni projelerde `smsRegionConfig = allowlistOnly{}` (BOŞ = tüm ülkeler engelli!) → `{"allowlistOnly":{"allowedRegions":["TR"]}}` PATCH et
- Firebase Flutter paketleri: **core ≥4, auth ≥6, messaging ≥16** (eski sürümler iOS'ta EXC_BREAKPOINT ile çöküyor); iOS deployment target ≥ **15.0**
- **PowerShell ile Dart/emoji içeren dosyalarda toplu regex replace YAPMA** — `Get-Content -Raw` UTF-8'i bozar, Türkçe karakterler/emoji mahvolur. Edit tool kullan.
- pbxproj'a yazarken `[System.IO.File]::WriteAllText` (BOM'suz) — `Set-Content -Encoding utf8` BOM ekler, Xcode imzalama patlar
- AGP 9 Kotlin DSL: `java.util.Properties()` inline ÇALIŞMAZ → dosya başına `import java.util.Properties`
- sentry_flutter 8.x → Android Kotlin + iOS Swift derleme hatası; **9.x kullan**
- Codemagic: private repo klonu **SSH deploy key** ile (token'lı HTTPS URL kabul edilmiyor); çok satırlı secure var'larda `\r` temizle
- Firebase APNs anahtarı yükleme ve bazı Console işlemleri API'de YOK → kullanıcıya adım adım tarif et
- Cloudflare Global API Key: `X-Auth-Email` + `X-Auth-Key` başlıkları (Bearer değil)

## PROJE DURUMU (son güncelleme: 12 Temmuz 2026)
- ✅ **Faz 1 CANLIDA:** kayıt/OTP(kendi 6 hane)/giriş/şifre yenileme + 1:1 mesajlaşma (tikler, yazıyor, okunmamış)
- ✅ Kullanıcı arama (@kullanıcıadı / isim) — rehber yerine gerçek profiller
- ✅ Backend + LiveKit + Caddy + Postgres + Redis sunucuda Docker'da; https://api.gebzem.app, wss://rtc.gebzem.app
- ✅ Push: FCM v1 (Android ✓, iOS APNs anahtarı yüklü); Sentry (mobil + backend) açık
- ✅ **CI/CD: GitHub Actions** (Codemagic'in bedava dakikaları bitti) → APK + ad hoc IPA → **https://indir.gebzem.app**
- ✅ **ARAMA (1:1 sesli/görüntülü):** CANLI, kullanıcı testlerinden geçti (süre senkron, CallKit, ses teşhis dahil)
- ✅ **GRUP ARAMASI (sesli + görüntülü, 18 Tem):** sesli ≤32, görüntülü ≤8 kişi; video ızgara + mid-call kamera; anlık grup (member_ids) — kalıcı grup sohbeti UI'si sonraki faz
- ⏳ Sonraki: geç-katılma/kişi-ekleme → Faz 2 (gruplar, story, profil, medya) → odalar+yayın (Spaces) → admin
- ✅ Uygulama ikonu: kullanıcı tasarımı (mor/kıvrımlı logo) koda işlendi 18 Tem — kaynak
  mobile/assets/icon/kaynak.jpg; güncelleme: `dart run tool/ikon_uret.dart` + `dart run
  flutter_launcher_icons` (⚠️ sonrasında pbxproj'daki GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS
  bozulmasını git checkout ile geri al — araç bug'ı, APPICON_NAME zaten şablonda var)
- Test kullanıcıları: her sürümde DB temizleniyor (aşağıdaki rutin) → kullanıcı sıfırdan kayıt olur

## REPO YAPISI (monorepo: github.com/gbz-app/gebzem — **PUBLIC** 15 Tem 2026: Actions kotası doldu → sınırsız bedava için public yapıldı; secrets Actions'ta gizli, kodda/geçmişte hassas dosya YOK)
- `backend/` — Go API (chi + pgx + go-redis + gorilla/websocket)
- `mobile/` — Flutter (org: app.gebzem). lib/: core/ (api, ws, storage, theme), features/ (auth, chats, home), router.dart
- `admin/` — yer tutucu (Faz 5: Next.js)
- Kök: CLAUDE.md, oturum.md, arastirma-raporu.md, ozellik-listesi.md, .env.infra (gitignore'lu)

## API UÇLARI (backend)
Açık: POST /auth/register, /auth/verify (test OTP), **/auth/verify-firebase (GERÇEK SMS)**, /auth/login, /auth/forgot, /auth/reset · GET /health
Korumalı (Bearer): GET/PATCH /users/me · POST /users/me/username · POST /users/me/fcm-token · **GET /users/search?q=** (isim/@username; telefon dönmez) · GET /users/by-phone · GET /chats · POST /chats/direct · GET+POST /chats/{id}/messages · POST /chats/{id}/read · GET /ws (WebSocket; ?token= de kabul eder)
WS olayları: message.new, receipt.read, typing
**Kimlik doğrulama:** GERÇEK SMS aktif (Firebase Phone Auth → Google imzalı ID token → backend doğrular). Test moduna dönmek için Flutter: `--dart-define=REAL_SMS=false` (o zaman /auth/register+verify akışı, dev_otp yanıtta döner).
**Kullanıcı adı:** kayıtta zorunlu (@handle, 3-20 karakter a-z0-9_). Arama isim veya @username ile.

## KOMUTLAR
- **Backend yerel derleme:** `cd backend && go build ./...`
- **Flutter analiz:** `cd mobile && flutter analyze`
- **Mobil çalıştırma (emülatör, yerel backend):** `cd mobile && flutter run` (API varsayılanı 10.0.2.2:8080)
- **Mobil canlı sunucuya karşı:** `flutter run --dart-define=API_URL=http://167.233.229.88:8080`
- **DEPLOY (sunucuda güncelleme):** `ssh -i ~/.ssh/gebzem_ed25519 root@167.233.229.88 "cd /opt/gebzem/repo && git pull && cd backend && docker compose up -d --build"`
- Sunucuda log: `docker compose logs -f api` (dizin: /opt/gebzem/repo/backend)
- **YENİ SÜRÜM DAĞITIMI:** Codemagic API ile derleme tetikle (appId 6a52c71564181d764c0d9c88, workflow `android-build` / `ios-adhoc`) → artifact indir → R2 `gebzem-dist` bucket'a yükle (scratchpad/r2put.js, SigV4) → indir.gebzem.app'te güncellenir

## SUNUCU (Hetzner gebzem-1)
- IP: 167.233.229.88 · Ubuntu 24.04 · cx33 (4 vCPU/8GB) · Falkenstein · €8,99/ay
- SSH: `ssh -i ~/.ssh/gebzem_ed25519 root@167.233.229.88`
- Docker compose stack: /opt/gebzem/repo/backend → api (8080 dışa açık) + postgres:17 + redis:7 (ikisi sadece 127.0.0.1)
- `backend/.env` sunucuda JWT_SECRET içerir (git dışı). Repo klonu token'lı HTTPS remote
- ⚠️ Güvenlik duvarı henüz YOK (prototip); API şimdilik HTTP — yayın öncesi: firewall + HTTPS (api.gebzem.app + Caddy)

## MİMARİ KARARLAR (arastirma-raporu.md'ye dayalı)
- Kanal/grup: Telegram modeli (tek chats tablosu, type: direct/group/channel)
- Mesaj akışı: PostgreSQL'e yaz → Redis pub/sub "events" → hub → WebSocket; çevrimdışı = REST gecmisi (inbox deseni) + ileride FCM push
- Hediye: animasyon LiveKit data API; bakiye/işlem coin_ledger tablosunda (kayıt bonusu 100 jeton kodda çalışıyor)
- Prototipte ödeme YOK (bedava jeton); IAP V2 (%15 tier kaydı unutulmasın); payout ileride banka/İyzico (6493 — asla kendi bünyede değil)
- Harita: google_maps_flutter, cloudMapId KULLANMA (bedava kalması için); OSMF bedava tile YASAK
- Yayın öncesi yasal: BTK yer sağlayıcı bildirimi + 4 saat içerik kaldırma + trafik logu 1-2 yıl + hukukçu teyidi (sosyal ağ eşiği)
- LiveKit: sesli odalar cx33'te OK; video yayında benchmark'ın %50'si varsay + büyümede dedicated makine

## CI/CD + DAĞITIM (Codemagic)
- App: `6a52c71564181d764c0d9c88` (SSH deploy key ile bağlı — token'lı HTTPS klon ÇALIŞMIYOR!)
- Workflow'lar (codemagic.yaml): `android-build` (APK), `ios-adhoc` (IPA — keychain initialize + fetch-signing-files --create + add-certificates ŞART)
- Apple: bundle `app.gebzem`, ASC API anahtarı BYRG6K58NK (.p8 kökte, gitignore'lu), Issuer dd626245-204e-4b73-a98a-3fa9241b4a47; iPhone XS Max cihaz kayıtlı (ad hoc'a otomatik dahil)
- Codemagic'te güvenli değişken grubu: `appstore_credentials` (ISSUER_ID, KEY_IDENTIFIER, PRIVATE_KEY=p8, CERTIFICATE_PRIVATE_KEY=cert_key.pem)
- ⚠️ Codemagic API çok satırlı değerlerde CR kabul etmez → `-replace "\`r",""` şart
- ⚠️ Codemagic build logu: `GET /builds/{id}` → buildActions[].subactions[].logUrl (üst seviyede logUrl BOŞ gelir)

## HESAPLAR & ARAÇLAR
- GitHub: gbz-app · Cloudflare: Gebzemapp@outlook.com (zone gebzem.app; R2: gebzem-media + gebzem-dist→indir.gebzem.app) · Google: gebzemapp@gmail.com (gcloud girişli; API çağrılarında `x-goog-user-project` başlığı şart) · Codemagic + Apple: yukarıda
- Anahtarlar: `.env.infra` · gh CLI: `C:\Users\gebze\tools\gh\bin\gh.exe` (PATH'te yok) · gcloud: `C:\Users\gebze\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd` · Firebase CLI (npm), Node 24, git 2.54, Flutter 3.44, Go 1.26
- PowerShell tuzakları: git/gcloud çıktısı stderr'e gider (`2>&1` NativeCommandError yanıltır — kullanma); Dart 3.12'de `(_, __)` yerine `(_, _)`
