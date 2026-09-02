/// ⚠️⚠️⚠️ TURU 151 — **ROTA TAKIBI** (kullanici sorusu: *"telefonla
/// yurudugumde ARKAMDAN SHAPE GIDECEK MI?"* — cevap EVET, burasi onun
/// matematigi).
///
/// Kullanicinin tarifi (turu 150'de, birebir): *"basla dediginde otobus ve
/// varis HAFIF SONECEK, ilk duraga goturcez, sonra otobus, sonra durak;
/// gittikce ARKADAKI SHAPE SILINECEK. Navigasyon olmayacak, sadece KUS
/// BAKISI."*
///
/// ⚠️ **BU DOSYA SAF DART**: Flutter'a, haritaya, konum eklentisine BAGLI
///	DEGIL. Sebep: mantik ancak boyle BIRIM TESTIYLE kanitlanabilir
///	(`test/rota_takip_test.dart`). Bu projede "olculmeden dogru sayilan
///	formul" defalarca sahaya cikti.
library;

import 'dart:math' as math;

/// Bir noktanin polyline uzerindeki izdusumu.
class Izdusum {
  const Izdusum({
    required this.segment,
    required this.t,
    required this.enlem,
    required this.boylam,
    required this.uzaklikM,
  });

  /// Izdusumun dustugu segmentin BASLANGIC indeksi (`noktalar[segment]` ->
  /// `noktalar[segment + 1]`).
  final int segment;

  /// Segment icindeki oran (0 = bas, 1 = son).
  final double t;

  final double enlem;
  final double boylam;

  /// Noktanin cizgiye METRE cinsinden uzakligi.
  final double uzaklikM;
}

/// Bir noktayi cok segmentli bir polyline'a **yapistirir** (snap).
///
/// ⚠️⚠️ **METRIK DUZLEME GECILIR.** Ham derece ile calisilsaydi Gebze
///	enleminde (40,8°) boylam ekseni **%24 yanlis** olceklenir ve izdusum
///	YANLIS segmente kayardi. (Ayni hata sunucu tarafinda turu 85b'de
///	SAHAYA CIKTI: kaba kutu boylamda `cos(enlem)` uygulamiyordu.)
///
/// ⚠️⚠️ **ARAMA PENCERESI ZORUNLU** ([basSegment], [pencere]).
///	⚠️ Bu pencere ile `ilerlet` icindeki `math.max(basSeg, ...)`
///	   **BIRBIRININ YEDEGI**: ikisinden biri kaldirilinca
///	   monotonluk yine korunuyor (bozarak olculdu). Ikisi de
///	   KALIR - biri gelecekte degisirse oteki tutar.
///	Kucuk bir sehirde hatlar kendi uzerine doner; GLOBAL "en yakin
///	segment" araması, ayni caddeden ikinci kez gecen bir rotada
///	kullaniciyi **ILERIYE SICRATIR** ya da geri atar. Arama yalnizca
///	`[basSegment, basSegment + pencere)` araliginda yapilir — yani
///	ilerleme **MONOTON** olur.
///	⚠️ YAPMA: pencereyi kaldirip tum cizgiyi taramaya donme.
///
/// ⚠️⚠️ **SIFIRA BOLME KAPISI - DURUST NOT (OLCULDU):** GTFS
///	sekillerinde ARDISIK TEKRARLI nokta gercekten var (ayni
///	koordinat iki kez) ve orada `l2 = 0` olur.
///
///	Ilk yazimda buraya *"kapi olmasaydi t = NaN olur ve NaN her
///	karsilastirmadan sessizce duserdi"* yazmistim. **BOZARAK
///	DENEDIM: kapiyi kaldirinca test YESIL KALDI.** Sebebi
///	olculdu: `num.clamp` `<` degil **`compareTo`** kullanir ve
///	`double.compareTo`da NaN EN BUYUK sayilir, yani
///	`NaN.clamp(0.0, 1.0)` **1.0** doner (dart ile dogrulandi).
///	Yani NaN'i zaten `clamp` etkisizlestiriyor.
///
///	Kapi YINE DE DURUYOR: (a) niyeti belgeliyor, (b) `clamp`
///	bir gun kaldirilirsa `d = NaN` olur ve **o zaman** gercekten
///	`NaN < enAz` daima false oldugu icin segment HIC secilmez.
///	⚠️ Bunu "test ediliyor" diye YAZMA - edilmiyor, cunku
///	   `clamp` onu gormeden yutuyor.
Izdusum? yapistir(
  List<({double enlem, double boylam})> yol,
  double enlem,
  double boylam, {
  int basSegment = 0,
  int pencere = 40,
}) {
  if (yol.length < 2) return null;
  final son = math.min(yol.length - 1, basSegment + pencere);
  if (basSegment >= son) return null;

  final kx = 111320.0 * math.cos(yol.first.enlem * math.pi / 180);
  const ky = 111320.0;
  final px = boylam * kx;
  final py = enlem * ky;

  var enIyiSeg = basSegment;
  var enIyiT = 0.0;
  var enAz = double.infinity;

  for (var i = basSegment; i < son; i++) {
    final ax = yol[i].boylam * kx;
    final ay = yol[i].enlem * ky;
    final bx = yol[i + 1].boylam * kx;
    final by = yol[i + 1].enlem * ky;
    final abx = bx - ax;
    final aby = by - ay;
    final l2 = abx * abx + aby * aby;
    var t = 0.0;
    if (l2 > 0) {
      t = (((px - ax) * abx) + ((py - ay) * aby)) / l2;
      t = t.clamp(0.0, 1.0);
    }
    final qx = ax + t * abx;
    final qy = ay + t * aby;
    final dx = px - qx;
    final dy = py - qy;
    final d = dx * dx + dy * dy;
    if (d < enAz) {
      enAz = d;
      enIyiSeg = i;
      enIyiT = t;
    }
  }

  final a = yol[enIyiSeg];
  final b = yol[enIyiSeg + 1];
  return Izdusum(
    segment: enIyiSeg,
    t: enIyiT,
    enlem: a.enlem + (b.enlem - a.enlem) * enIyiT,
    boylam: a.boylam + (b.boylam - a.boylam) * enIyiT,
    uzaklikM: math.sqrt(enAz),
  );
}

/// Iki nokta arasi kaba mesafe (metre) — **`cos(enlem)` duzeltmeli**.
double metre(double aEn, double aBoy, double bEn, double bBoy) {
  final kx = 111320.0 * math.cos(aEn * math.pi / 180);
  final dx = (bBoy - aBoy) * kx;
  final dy = (bEn - aEn) * 111320.0;
  return math.sqrt(dx * dx + dy * dy);
}

/// Bir polyline'in [iz] noktasindan SONRAKI parcasi — yani **KALAN yol**.
///
/// ⚠️ Ilk oge izdusumun KENDISI: cizgi kullanicinin BULUNDUGU yerden
///    baslasin, bir onceki koseden degil. Aksi halde cizgi kullanicinin
///    ARKASINDA kalan kisa bir kuyruk birakirdi.
List<({double enlem, double boylam})> kalanYol(
  List<({double enlem, double boylam})> yol,
  Izdusum iz,
) =>
    kalanYolNoktadan(yol, iz.segment, iz.enlem, iz.boylam);

/// ⚠️⚠️⚠️ TURU 157 - **KOPMANIN KOKU BURADAYDI.**
///
///	Kullanici: *"bazen boyle KOPMALAR yasanabiliyor, bu normal mi?"*
///	Cevap: **HAYIR.**
///
/// ⚠️⚠️ **KOK NEDEN: CIZIM ILE TAKIP AYNI SORUYU FARKLI SORUYORDU.**
///	Haritayi cizen kod (`_cizgiler`) her karede `yapistir`i
///	**ADSIZ** cagiriyordu, yani `basSegment: 0, pencere: 40`:
///	"yolun BASINDAN itibaren 40 segment tara".
///	Takip motoru (`ilerlet`) ise `basSegment: onceki.segment`
///	geciyor: "EN SON BULUNDUGUN yerden itibaren tara".
///
///	**OLCULDU:** 202 GTFS guzergah seklinin nokta sayisi
///	min 74 / medyan 314 / maks 924 — yani **HEPSI 40i ASIYOR**.
///	40. segment gecilir gecilmez cizim kodu dogru segmenti
///	ARAMA PENCERESINDE BULAMIYOR ve yanlis yere kilitleniyor.
///	Gercek sekil 414301 (hat 430) uzerinde sapma:
///	  segment  45 ->   877 m
///	  segment 150 -> 3.145 m
///	  segment 250 -> 4.581 m
///	Ekranda **cizginin basi yanlis yerden basliyor** = KOPMA.
///
/// ⚠️⚠️ **FIX: IKINCI ARAMA YAPILMIYOR.** `TakipDurumu` ZATEN
///	`segment` + `izEnlem` + `izBoylam` tasiyor - yani cizim icin
///	gereken UC alanin ucu de ELDE. Cizim artik HESAPLAMIYOR,
///	takip durumundan OKUYOR.
/// ⚠️⚠️ YAPMA: cizim tarafina `pencere: yol.length` gibi bir kol
///	koyup "coz". O pencere GPS **MONOTONLUGU** icin var;
///	acilirsa ilmekli hatlarda cizgi GERIYE SICRAR (`yapistir`
///	serhi bunu yaziyor).
/// ⚠️⚠️ YAPMA: yeniden hesaplamayi birakip `takipSegment`i de
///	gecirme - IKI dogruluk kaynagi kalirsa yine AYRISIRLAR.
List<({double enlem, double boylam})> kalanYolNoktadan(
  List<({double enlem, double boylam})> yol,
  int segment,
  double enlem,
  double boylam,
) {
  if (yol.length < 2) return yol;
  return [
    (enlem: enlem, boylam: boylam),
    ...yol.sublist(math.min(segment + 1, yol.length)),
  ];
}

/// Bir polyline'in toplam uzunlugu (metre).
double yolUzunlugu(List<({double enlem, double boylam})> yol) {
  var t = 0.0;
  for (var i = 0; i < yol.length - 1; i++) {
    t += metre(yol[i].enlem, yol[i].boylam, yol[i + 1].enlem, yol[i + 1].boylam);
  }
  return t;
}

/// [iz] noktasindan yolun SONUNA kalan mesafe (metre).
double kalanMetre(
  List<({double enlem, double boylam})> yol,
  Izdusum iz,
) =>
    yolUzunlugu(kalanYol(yol, iz));

/// Kullanicinin rotadan "ciktigi" sayilacagi uzaklik.
///
/// ⚠️ 60 m: sehir ici GPS dogrulugu iyi kosulda ~5-10 m, bina aralarinda
///	20-40 m'ye cikiyor. Esik daha DAR olsaydi normal GPS gurultusunde
///	kullaniciya surekli "rotadan ciktin" denirdi.
/// ⚠️ Esik ASILDIGINDA ilerleme DURDURULUR ama rota SILINMEZ: kullanici
///	geri dondugunde kaldigi yerden devam etmeli.
const double kRotaDisiM = 60;

/// ⚠️⚠️⚠️ TURU 158b - **GERCEK GERI YURUME ESIGI (metre).**
///
///	Monoton `t` mandali GPS gurultusunu yutmali ama kullanicinin
///	GERCEKTEN geri donmesini yutmamalidir. Ham izdusum monoton
///	noktanin bu kadar ARKASINDA ve UST USTE IKI olcumde boyle
///	kalirsa mandal BIRAKILIR.
/// ⚠️ 20 m: tipik sehir ici GPS gurultusu tavani. Daha kucuk deger
///    tek bir sicramada mandali birakir (kalan mesafe geri buyur);
///    daha buyuk deger gercek geri donusu gec fark eder.
const double kGeriEsikM = 20;

/// Bir bacagin "tamamlandi" sayilacagi kalan mesafe.
///
/// ⚠️ 25 m: GPS dogrulugundan BUYUK olmak zorunda, yoksa kullanici duraga
///	varmis olsa bile adim ILERLEMEZ. Daha genis olsaydi (ornegin 60 m)
///	kisa bir yurume bacagi HIC baslamadan biterdi.
const double kBacakBittiM = 25;

/// Rotanin bir anlik takip DURUMU.
///
/// ⚠️ Bu sinif **DEGISMEZ (immutable)**: her konum guncellemesinde YENISI
///    uretilir. Yerinde degistirilseydi arayuz "deger degismedi" sanip
///    yeniden cizmezdi (bu ekranda `_odak`/`_zoom` ile ayni ders).
class TakipDurumu {
  const TakipDurumu({
    required this.bacak,
    required this.segment,
    required this.kalanM,
    required this.rotaDisi,
    required this.bitti,
    this.izEnlem,
    this.izBoylam,
    this.t = 0,
    this.geriSayac = 0,
  });

  /// Su an hangi bacaktayiz (aday.bacaklar indeksi).
  final int bacak;

  /// O bacagin polyline'inda kacinci segmentteyiz (arama penceresi tabani).
  final int segment;

  /// Bu bacagin sonuna kalan mesafe (metre).
  final double kalanM;

  /// Kullanici cizgiden [kRotaDisiM]'den uzak mi?
  final bool rotaDisi;

  /// Tum rota tamamlandi mi?
  final bool bitti;

  final double? izEnlem;
  final double? izBoylam;

  /// ⚠️⚠️⚠️ TURU 158 - **SEGMENT ICI ORAN (0..1), MONOTON.**
  ///
  ///	`segment` zaten monotondu ama `kalanM` HAM izdusumden
  ///	geliyordu: segment ICINDE `t` geri gidince kalan mesafe
  ///	**BUYUYOR**. Olculdu: GPS duzeltmelerinin **%19-39**'unda
  ///	artis, otobus bacaginda **maks +57 m**.
  ///	Yani ekranin EN BUYUK sayisi ("677 m kaldı") yururken
  ///	BUYUYOR ve ilerleme imleci GERI kayiyordu - kullanicinin
  ///	*"hareket ederken hareket etmiyor gibi"* tarifinin bir parcasi.
  ///	Dosyanin KENDI serhi *"cizilen kalan yol geri UZAMAZ"* diyordu;
  ///	govdede o koruma YOKTU.
  /// ⚠️⚠️ Yalniz `kalanM`i kirpmak YETMEZ: `izEnlem/izBoylam` HAM
  ///	kalirsa cizginin BASI geri oynamaya devam eder ve "sayi sabit,
  ///	cizgi geri gidiyor" seklinde YENI bir tutarsizlik dogardi.
  ///	Bu yuzden izdusum noktasi da MONOTON `t`den kurulur.
  final double t;

  /// ⚠️⚠️ TURU 158b - ust uste kac olcumdur ham izdusum monoton
  ///	noktanin `kGeriEsikM`den GERISINDE. 2'ye ulasinca mandal
  ///	birakilir (bkz. `ilerlet` icindeki serh).
  final int geriSayac;

  static const TakipDurumu basla = TakipDurumu(
    bacak: 0,
    segment: 0,
    kalanM: double.infinity,
    rotaDisi: false,
    bitti: false,
  );
}

/// Yeni bir konum geldiginde takip durumunu ILERLETIR.
///
/// [bacakYollari] her bacagin polyline'i (bekleme bacaginda BOS liste).
///
/// ⚠️⚠️ **MONOTONLUK**: `segment` ASLA geri gitmez. GPS gurultusu
///	kullaniciyi bir kare geri atsa bile cizilen "kalan yol" geri
///	UZAMAZ — ekranda cizginin ileri geri oynamasi, kullanicinin
///	guvenini tumden bitirir.
///
/// ⚠️⚠️ **BOS (bekleme) BACAKLARI ATLANIR**: `BacakTuru.bekle` bacaginin
///	polyline'i YOK. Atlanmasaydi takip orada KILITLENIRDI (yapistirma
///	hep null doner, ilerleme hic olmaz).
///
/// ⚠️ Rota disindayken (`rotaDisi`) **ilerleme yazilmaz** ama durum yine
///    dondurulur: arayuz kullaniciya "rotaya don" diyebilsin.
TakipDurumu ilerlet(
  TakipDurumu onceki,
  List<List<({double enlem, double boylam})>> bacakYollari,
  double enlem,
  double boylam,
) {
  if (onceki.bitti || bacakYollari.isEmpty) return onceki;

  var bacak = onceki.bacak;
  // Bos bacaklari (bekleme) ATLA.
  while (bacak < bacakYollari.length && bacakYollari[bacak].length < 2) {
    bacak++;
  }
  if (bacak >= bacakYollari.length) {
    return const TakipDurumu(
      bacak: 0,
      segment: 0,
      kalanM: 0,
      rotaDisi: false,
      bitti: true,
    );
  }

  final yol = bacakYollari[bacak];
  var basSeg = bacak == onceki.bacak ? onceki.segment : 0;
  var iz = yapistir(yol, enlem, boylam, basSegment: basSeg);
  if (iz == null) return onceki;

  // ⚠️⚠️⚠️ TURU 158b - **ROTA DISI KALICI KILITLENIYORDU** (yayin oncesi
  //	denetim; YUKSEK).
  //
  //	`yapistir` yalniz [basSeg, basSeg + 40) araligini tarar. Kullanici
  //	iki GPS olayi arasinda 40 sekil noktasindan fazla ilerlerse
  //	(telefon cepte, ekran kapaliyken Android akisi KISILIR - bu
  //	`konum_servisi.dart` serhinde ZATEN yazili) izdusum o pencerenin
  //	SONUNA yapisir, uzaklik `kRotaDisiM`yi asar ve `rotaDisi` dali
  //	`segment: basSeg` dondurur. **BIR SONRAKI cagride taban AYNIDIR**
  //	-> ayni pencere -> ayni uzak izdusum -> SONSUZA KADAR rotaDisi.
  //	Kullanici cizginin TAM USTUNDE yurumeye devam etse, hatta yolun
  //	SONUNA varsa bile durum degismez: `kalanM` donar, bacak HIC
  //	tamamlanmaz, `bitti` HIC tetiklenmez ("Vardin." mesaji gelmez).
  //	"Bitir" + "Basla" da ayni pencereye doner - KURTARMA YOLU YOKTU.
  //
  // ⚠️⚠️ **YALNIZ ILERI**: global yeniden yakalama sonucu ancak
  //	`basSeg`ten SONRAYSA kabul edilir. Boylece monotonluk korunur ve
  //	`yapistir` serhindeki *"pencereyi kaldirma"* yasagi IHLAL EDILMEZ
  //	(o yasak ilmekli hatlarda cizginin GERI sicramasina karsidir).
  // ⚠️ Kapi YALNIZ izdusum pencerenin SON segmentine yapismisken
  //    calisir: normal rotaDisi (kullanici gercekten sapmis) vakasinda
  //    pahali global arama YAPILMAZ.
  if (iz.uzaklikM > kRotaDisiM && iz.segment >= basSeg + 40 - 1) {
    final global = yapistir(yol, enlem, boylam,
        basSegment: 0, pencere: yol.length);
    if (global != null &&
        global.uzaklikM <= kRotaDisiM &&
        global.segment > basSeg) {
      basSeg = global.segment;
      iz = global;
    }
  }

  if (iz.uzaklikM > kRotaDisiM) {
    return TakipDurumu(
      bacak: bacak,
      segment: basSeg,
      kalanM: onceki.kalanM,
      rotaDisi: true,
      bitti: false,
      // ⚠️⚠️ TURU 157 - **GUNCEL izdusum yazilir, BAYAT olan degil.**
      //	Onceden `onceki.izEnlem/izBoylam` tasiniyordu ve bayat
      //	bir nokta durumlar boyunca YAYILABILIYORDU. Cizim artik
      //	bu alanlari okudugu icin bayatlik dogrudan EKRANA
      //	yansirdi.
      // ⚠️ PUCK ETKILENMEZ: yapistirma `rotaDisi` kapisinin
      //    ARKASINDA, yani rotadan cikmis kullanici HAM GPS'te kalir.
      izEnlem: iz.enlem,
      izBoylam: iz.boylam,
      // ⚠️ Rota disinda ilerleme YAZILMAZ; oran ONCEKI degerde kalir.
      t: onceki.t,
      // ⚠️ Sayac da TASINIR: rota disinda geri-yurume karari verilemez.
      geriSayac: onceki.geriSayac,
    );
  }

  final kalan = kalanMetre(yol, iz);

  // ── BACAK BITTI MI? ──
  if (kalan <= kBacakBittiM) {
    var sonraki = bacak + 1;
    while (sonraki < bacakYollari.length &&
        bacakYollari[sonraki].length < 2) {
      sonraki++;
    }
    if (sonraki >= bacakYollari.length) {
      return TakipDurumu(
        bacak: bacak,
        segment: iz.segment,
        kalanM: 0,
        rotaDisi: false,
        bitti: true,
        izEnlem: iz.enlem,
        izBoylam: iz.boylam,
        t: iz.t,
      );
    }
    // ⚠️⚠️⚠️ TURU 157 - **IZDUSUM DE YENI BACAGA TASINIR.**
    //
    //	Onceden `bacak` ve `segment` YENI bacaga gecerken
    //	`izEnlem/izBoylam` ESKI bacagin izdusumu olarak
    //	kaliyordu. Turu 157 cizimi ve puck'i bu UC alana
    //	bagladigi icin sonuc GORUNUR oldu:
    //	  · `kalanYolNoktadan` yeni bacagin ILK noktalarini
    //	    siliyor ve cizgiyi ESKI noktadan basliyormus gibi
    //	    cizyordu -> aktarmadan hemen sonra 2. otobus
    //	    hattinin basi **0-175 m** kayiyor ve arasi DUZ bir
    //	    dogruyla (binalarin ustunden) gecilmis gorunuyordu -
    //	    turu 155'te *"BIZIMKI DIREK USTUNDE"* diye
    //	    duzeltilen gorunumun AYNISI.
    //	  · Puck da o eski noktaya yapistigi icin kullanici
    //	    kendini ~100 m GERIDE goruyordu.
    // ⚠️⚠️ Dosyanin KENDI kurali: `bacak`, `segment` ve `iz` UCU DE
    //	AYNI bacaga ait olmali; iki dogruluk kaynagi kalirsa
    //	AYRISIRLAR.
    // ⚠️ `?? yeniYol.first` yapisal emniyet: `yapistir` null donse
    //    bile cizgi HICBIR durumda kopmaz.
    final yeniYol = bacakYollari[sonraki];
    final iz2 = yapistir(yeniYol, enlem, boylam);
    return TakipDurumu(
      bacak: sonraki,
      segment: iz2?.segment ?? 0,
      kalanM: yolUzunlugu(yeniYol),
      rotaDisi: false,
      bitti: false,
      izEnlem: iz2?.enlem ?? yeniYol.first.enlem,
      izBoylam: iz2?.boylam ?? yeniYol.first.boylam,
      // ⚠️ YENI bacak: oran sifirdan baslar (bkz. `t` serhi).
      t: iz2?.t ?? 0,
    );
  }

  // ⚠️⚠️⚠️ TURU 158 - **SEGMENT ICI ORAN DA MONOTON** (bkz. `t` serhi).
  //	Ayni segmentte kalindiysa `t` geri GITMEZ; izdusum noktasi
  //	ve kalan mesafe O NOKTADAN yeniden kurulur.
  // ⚠️ Bacak ya da segment DEGISTIYSE `t` ham degerden baslar.
  final ayniSeg = bacak == onceki.bacak && iz.segment == onceki.segment;
  // ⚠️⚠️⚠️ TURU 158b - **MANDAL GPS GURULTUSUYLE SINIRLI** (denetim; ORTA).
  //
  //	Kosulsuz `math.max` kullanicinin GERCEKTEN geri yurumesini de
  //	yutuyordu: duragi 30-40 m gecip donen kisi cizginin USTUNDE
  //	oldugu icin `rotaDisi` TETIKLENMEZ, ama `t`, `kalanM` ve (turu
  //	157'den beri cizgiye yapistirilan) PUCK **DONAR**. Kamera ham
  //	GPS'i izledigi icin harita kayar, puck yerinde kalir: kullanici
  //	yururken kendini hareketsiz gorur. Yani turu 157'de "geri
  //	gidiyordu ama HAREKET EDIYORDU", turu 158 onu "HIC hareket
  //	etmiyor"a cevirmisti - sikayetin ta kendisi.
  // ⚠️ Tek gurultulu fix hala YUTULUR: birakma icin UST USTE IKI olcum
  //    ve esigin asilmasi gerekir.
  // ⚠️⚠️ **OLCUT SEGMENT ICI ORAN DEGIL, GPS ILE IZDUSUM ARASI MESAFEDIR.**
  //	Ilk yazimda `(onceki.t - iz.t) * segmentUzunlugu` kullanildi ve
  //	MUHAFIZ TESTI KIRMIZI DUSTU: kullanici bir segmentten FAZLA geri
  //	giderse `yapistir` penceresi geriye BAKMADIGI icin izdusum
  //	segmentin BASINA (t = 0) yapisir ve fark en fazla BIR SEGMENT
  //	uzunlugu (~11 m) cikar - esige HIC ULASMAZ. Yani olcut, olcmesi
  //	gereken seyi yapisal olarak olcemiyordu.
  //	Dogru sinyal: kullanici cizginin USTUNDE (rotaDisi degil) ama
  //	bizim ONCEKI izdusum noktamizdan UZAKTA.
  final ileri = !ayniSeg || iz.t > onceki.t;
  final geriM = (ileri || onceki.izEnlem == null || onceki.izBoylam == null)
      ? 0.0
      : metre(enlem, boylam, onceki.izEnlem!, onceki.izBoylam!);
  final geriSayac = geriM > kGeriEsikM ? onceki.geriSayac + 1 : 0;
  final birak = geriSayac >= 2;
  // ⚠️⚠️ Mandal birakilinca **PENCERE DE GERI ACILIR**: aksi halde `t`
  //	serbest kalir ama izdusum yine segment basinda kilitli kalirdi.
  //	Global arama YALNIZ burada ve YALNIZ kullanici cizgiye YAKINSA
  //	yapilir (ilmekli hatta yanlis gecise atlamasin diye `kRotaDisiM`).
  if (birak) {
    final geriIz = yapistir(yol, enlem, boylam,
        basSegment: 0, pencere: yol.length);
    if (geriIz != null &&
        geriIz.uzaklikM <= kRotaDisiM &&
        geriIz.segment < basSeg) {
      basSeg = geriIz.segment;
      iz = geriIz;
    }
  }
  final tMono = (ayniSeg && !birak) ? math.max(onceki.t, iz.t) : iz.t;
  final p0 = yol[iz.segment];
  final p1 = yol[iz.segment + 1];
  final monoIz = Izdusum(
    segment: iz.segment,
    t: tMono,
    enlem: p0.enlem + (p1.enlem - p0.enlem) * tMono,
    boylam: p0.boylam + (p1.boylam - p0.boylam) * tMono,
    uzaklikM: iz.uzaklikM,
  );
  return TakipDurumu(
    bacak: bacak,
    // ⚠️ MONOTON: segment geri GITMEZ.
    segment: math.max(basSeg, iz.segment),
    // ⚠️⚠️ Kalan mesafe MONOTON noktadan olculur; ham `kalan`
    //	yalnizca yukaridaki BACAK BITTI kapisinda kullanilir
    //	(monoton degere baglanirsa bitis erken tetiklenebilir).
    kalanM: kalanMetre(yol, monoIz),
    rotaDisi: false,
    bitti: false,
    izEnlem: monoIz.enlem,
    izBoylam: monoIz.boylam,
    t: tMono,
    geriSayac: geriSayac,
  );
}
