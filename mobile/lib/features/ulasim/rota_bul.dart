/// ⚠️⚠️⚠️ TURU 150 — **A -> B ROTA ARAMA (aktarmasiz).**
///
/// Kullanicinin emri: *"nereden / nereye secilsin, rotayi cizsin: durak
/// yolu ve varisa IKI RENK — durak guzergahi ve yurume mesafesi, altta da
/// step adimlar"*.
///
/// ⚠️⚠️ **GOOGLE'A ISTEK ATILMIYOR.** Hangi otobuse binilecegi, nerede
///	inilecegi ve kac dakika surdugu **kullanicinin verdigi GTFS
///	akisindan** hesaplaniyor. Fatura YOK, cevrimdisi calisir.
///
/// ⚠️⚠️ **TURU 152 — YURUME BACAKLARI ARTIK SOKAKTAN GIDIYOR.**
///	Turu 150/151'de kus ucusu duz cizgiydi ve kullanici hakli olarak
///	*"bizim yurume EVLERIN UZERINDEN gidiyor"* dedi. Artik sunucudaki
///	Routes vekilinden (`/yolbul/yaya`) gercek yol agi cizgisi aliniyor.
///	⚠️ Rota alinamazsa (ag yok / anahtar yok / cok uzak) **DUZ CIZGIYE
///	   DUSULUR** — ozellik COKMEZ, yalnizca kabalasir.
///	⚠️ DURUST SINIR: Gebze'de OSM yaya verisi fiilen yok (canli
///	   olculdu: 9.647 yolda 99 kaldirim, 40 isaretli gecit). Rota
///	   SOKAK AGINDAN gider; yaya gecidi garanti EDILMEZ. Google da
///	   WALK modunu BETA ilan edip bu uyariyi gostermeyi ZORUNLU
///	   tutuyor — metin sunucudan geliyor.
///
/// ⚠️⚠️ **AKTARMA YOK (V1).** Olculdu: 800 m yurume yaricapiyla rastgele
///	200 durak ciftinin **%41'i** aktarmasiz cozuluyor, %59'u tek aktarma
///	istiyor. Bacak modeli LISTE oldugu icin aktarma V2'de veri modeli
///	degismeden eklenebilir. Aday yoksa ekran DURUSTCE soyler, sahte rota
///	uretmez.
library;

import 'dart:math' as math;

import 'adres_servisi.dart';
import 'ulasim_veri.dart';

/// Bir rota bacaginin turu.
enum BacakTuru { yuru, bekle, otobus }

/// Rotanin tek bir bacagi.
class RotaBacagi {
  const RotaBacagi({
    required this.tur,
    required this.noktalar,
    required this.dakika,
    required this.baslik,
    required this.altBaslik,
    this.hat,
    this.metre = 0,
    this.eylem = '',
    this.yer = '',
    this.aktarmaYurumesi = false,
    this.kalkisDakika,
  });

  /// ⚠️⚠️⚠️ TURU 157 - **KOTA KAPISI.**
  ///
  ///	Aktarma yurumesi artik IKI GERCEK NOKTA tasiyor (haritada
  ///	cizilebilsin ve takipte atlanmasin diye). Ama
  ///	`_yurumeleriZenginlestir` tam da "iki noktali yurume bacagi"
  ///	olcutunu kullaniyor - yani bu bacak da Google Routes'a
  ///	gonderilirdi ve kazanan 3 aday x 3 yurume = **9 cagri**
  ///	olurdu (bugun 6). Aylik 10.000 ucretsiz kota ~1.660
  ///	aramadan ~1.100'e duserdi (turu 152 maliyet dersi).
  /// ⚠️⚠️ Aktarma yurumesi medyan **1 dk**, en fazla **2 dk** ve
  ///	aktarmalarin %36'sinda HIC YOK - duz cizgi yeterince dogru.
  /// ⚠️ Varsayilan `false`: mevcut 20+ cagri yeri DOKUNULMADAN derlenir.
  final bool aktarmaYurumesi;

  /// ⚠️⚠️⚠️ TURU 158b - **BEKLEME BACAGININ KALKIS DAKIKASI (MUTLAK).**
  ///
  ///	YAYIN ONCESI DENETIM (YUKSEK): imlec bu degeri `varisDakika`dan
  ///	SONRAKI bacaklarin sureleri cikarilarak TURETIYORDU. Aktarmali
  ///	rotada `kAktarmaTampon` (2 dk) HICBIR bacaga yazilmadigi icin
  ///	turetilen deger **DAIMA tam 2 dakika GEC** cikiyordu:
  ///	cebirsel olarak `varis - sonra = binis + tampon`.
  ///	Sonuc: otobus KALKMISKEN imlec bekleme diliminde park ediyor,
  ///	ve bekleme 2 dakikadan kisaysa oran DAIMA <= 0 -> imlec
  ///	**HIC KIPIRDAMIYOR**. Yani turu 158'in kapatmak icin acildigi
  ///	"beklemede imlec donuyor" sikayeti AKTARMALI rotalarda geri
  ///	donmustu (son olcumde 59 ciftin 46'sinda aktarma oneriliyor).
  ///
  /// ⚠️⚠️ **TURETME YOK, TASINIYOR**: bacagin `baslik`/`eylem` metinleri
  ///	ZATEN bu degerden uretiliyor, yani TEK KAYNAK olur ve drift
  ///	yapisal olarak imkansizdir.
  /// ⚠️⚠️ Deger **MUTLAK ve 1440'i ASABILIR** (GTFS 24:xx+ gece seferi);
  ///	okuyan taraf "simdi"yi AYNI tabana normallestirmek ZORUNDADIR.
  final int? kalkisDakika;

  /// ⚠️⚠️ TURU 156 — **EYLEM ve YER AYRI** (kullanici emri: adim karti
  ///	Yandex duzenine gecti; orada ust satir KUCUK eylem
  ///	("Durağa kadar yürüyün"), alt satir BUYUK yer adi
  ///	("Güzeller Osb Giriş 2")).
  ///
  /// ⚠️⚠️ `baslik`/`altBaslik` **DOKUNULMADI**: iki tuketicileri daha
  ///	var (rota ozet karti ve rota detay sheet'i). Yeni ALAN eklemek
  ///	onlari BOZMAZ; `baslik`i parcalamak bozardi.
  /// ⚠️ `baslik`i METINDEN AYIRMAK (orn. " durağına yürü" ekini kesmek)
  ///    REDDEDILDI: 4. bacagin basligi "Varışa yürü" — icinde yer adi YOK,
  ///    ve durak adlarinda da o ek gecebilir.
  final String eylem;
  final String yer;

  final BacakTuru tur;

  /// Haritada cizilecek nokta dizisi (bekleme bacaginda BOS).
  final List<({double enlem, double boylam})> noktalar;

  final int dakika;
  final String baslik;
  final String altBaslik;

  /// Otobus bacaginda hattin kendisi (rozet ve renk icin).
  final Hat? hat;

  final double metre;
}

/// Bir rota adayi (yuru -> bekle -> otobus -> yuru).
/// ⚠️⚠️⚠️ TURU 158 - **SEFERI YENIDEN SECEBILMEK ICIN HAM VERI.**
///
///	Sefer secimi KUS UCUSU yurume tahminiyle yapiliyor
///	(`enErken = suAn + oDk`). Yurume bacagi GERCEK yol agiyla
///	zenginlestirildikten sonra sure buyuyebilir (olculdu: ~1,74x)
///	ve kullanici o otobusu **KACIRIR**. Ekran "9 dk yuru" deyip
///	15:16 kalkisini onerirse plan ACIKCA imkansizdir.
///
/// ⚠️⚠️ Kalkis listeleri ZATEN bellekte; yeniden secim TAMAMEN
///	YERELDIR ve **EK AG ISTEGI URETMEZ** (turu 152 kota dersi:
///	zenginlestirme aday dongusune tasinirsa tek arama 90+ istek).
/// ⚠️ Aktarmali adayda ZINCIRLEME var: 1. bacagin binisi ilerleyince
///    inis de ilerler ve 2. sefer gecersiz kalabilir - o zaman aday DUSER.
class SeferKaydi {
  const SeferKaydi({
    required this.b1,
    required this.i1,
    this.yurDk,
    this.b2,
    this.i2,
  });

  /// 1. hattin BINIS ve INIS duraklarindaki kalkis sutunlari.
  final List<int> b1;
  final List<int> i1;

  /// Aktarma yurumesi (dk) ve 2. hattin sutunlari — aktarmasizda null.
  final int? yurDk;
  final List<int>? b2;
  final List<int>? i2;
}

class RotaAdayi {
  const RotaAdayi({
    required this.bacaklar,
    required this.varisDakika,
    required this.toplamDakika,
    required this.yurumeDakika,
    required this.hat,
    this.aktarma = 0,
    this.sefer,
  });

  /// ⚠️ GORUNMEYEN ic veri (bkz. `SeferKaydi`). Arayuz OKUMAZ.
  final SeferKaydi? sefer;

  /// ⚠️⚠️ TURU 157 - kac AKTARMA var (0 = aktarmasiz).
  ///	Siralama cezasi ve arayuzdeki "1 aktarma" etiketi bunu okur.
  /// ⚠️ `hat` alani ILK otobus hattidir; aktarmali rotada IKINCI hat
  ///    bacaklardan (`RotaBacagi.hat`) okunur.
  final int aktarma;

  /// ⚠️ Liste DEGISTIRILEBILIR: yurume bacaklari sonuc uretildikten SONRA
  ///    gercek yol agi cizgisiyle degistiriliyor
  ///    (bkz. `_yurumeleriZenginlestir`). `const` bir listeyle
  ///    kurulmadigi icin guvenli.
  final List<RotaBacagi> bacaklar;

  /// Gece yarisindan itibaren dakika (24'u asabilir).
  final int varisDakika;
  final int toplamDakika;
  final int yurumeDakika;
  final Hat hat;
}


/// ⚠️⚠️⚠️ TURU 157 - **AKTARMALI ROTA** (kullanici emri: *"cok uzakta bir
///	yeri isaretledigimde AKTARMA YOLLARINI gostermiyor, onu da yap"*).
///
/// ⚠️⚠️ **KULLANICI HAKLIYDI VE SAYISALLASTIRILDI.** 200 rastgele durak
///	cifti, hafta ici 12:00, 800 m yurume yaricapi:
///	  aktarmasiz motor toplam **%39,5** cozuyor
///	    0-3 km  %61  ·  6-10 km %27  ·  10-15 km %24
///	    **15 km ustu YALNIZCA %8**  <- sikayetin tam karsiligi
///	  TEK aktarma eklenince: **%98,5** (+%59).
///
/// ⚠️⚠️ **ALGORITMA OLCULEREK SECILDI** (uc secenek karsilastirildi):
///	  (a) kaba kuvvet: sorgu basina ~687.000 ic-dongu islemi -> 200 ms
///	      butcesine SIGMAZ.
///	  (b) hat-cifti kesisim tablosu: **HICBIR SEYI ELEMIYOR** - 200x200
///	      hat ciftinin %72,4'unde zaten ortak bir aktarma noktasi var,
///	      ustelik kurulumu 72 ms. (Bu secenegi bir daha arastirma.)
///	  (c) **IKI TURLU (RAPTOR benzeri)**: Dart'ta olculdu, ort **2,39 ms**
///	      / p95 5,74 / maks 9,48 ms. SECILEN BU.
///	⚠️ Olcum MASAUSTU + JIT ile yapildi; gercek cihazda AOT ile
///	   TEKRAR OLCULMELI. Sayiya degil BUYUKLUK MERTEBESINE guven.
///
/// ⚠️⚠️ **AKTARMA YARICAPI 150 m** (olculdu): 250 m ve 400 m kapsamaya
///	**HICBIR SEY EKLEMIYOR** ama komsu durak cifti sayisini 3.880'den
///	22.657'ye cikariyor. Aktarmalarin **%36'si AYNI DURAKTA**;
///	yuruyerek aktarmada sure medyan 1 dk, en fazla 2 dk.
///
/// ⚠️⚠️⚠️ **IKI AKTARMA YAPILMADI**: kazanc en fazla ~%1, maliyet katlaniyor.
/// ⚠️⚠️ Kalan ~%1,5 cozulmez; ayrica ciftlerin ~%5,5'inde 800 m icinde
///	HIC DURAK yok. O vakalarda bugunku durust *"rota bulunamadi"*
///	metni KALIR - sahte rota URETILMEZ.
/// ⚠️⚠️ TURU 158 - zorlanan inis izdusumu bu mesafeden UZAKSA sonuc
///	duragi TEMSIL ETMIYOR demektir; global aramaya bakilir.
/// ⚠️ 300 m: saglikli durak-sekil izdusumu medyan **8 m**; 300 m
///    esigi yalnizca GERCEKTEN bozuk vakalari yakalar (olculdu: %1,05).
const double kDilimIzdusumTavani = 300;

/// ⚠️⚠️⚠️ TURU 158b - **TERS DILIM ICIN ARAMA PENCERESI ASGARISI.**
///
///	YAYIN ONCESI DENETIM (kendi turu 158 kodumda YUKSEK regresyon):
///	`_enYakinIz` icindeki `basSegment.clamp(0, yol.length - 2)`,
///	`a` sekilin SON segmentine dustugunde pencereyi **TEK SEGMENTE**
///	indiriyor. O durumda donen `bIz.uz` bir BILGI degil, dejenere
///	pencerenin ARTIGIDIR (ornek: 1592 m). Kapi aciliyor, `bG.seg <= a`
///	zaten HER ZAMAN dogru oldugu icin TERS dal calisiyor ve
///	**TUM GUZERGAH GERI CIZILIYOR**.
/// ⚠️⚠️ OLCULDU (varlik verisi, 360.384 gecerli cift): `a == yol.length-2`
///	olan **591** ciftin **591**'i de turu 157'de KISA duz cizgiydi;
///	turu 158 onlari medyan **18.951 m** (maks **32.134 m**) ters
///	cizgiye cevirmisti — 1 dakikalik bir bacakta **681 km/h**.
///	Yani kullanicinin sikayet ettigi duz cizginin yerine DAHA BUYUK
///	bir gorsel bozukluk geciyordu.
/// ⚠️ 5 segment: dejenere (1-2 segmentlik) pencereleri eler, gercek
///    "durak sekilde yok" vakalarini ETKILEMEZ.
const int kDilimPencereAsgari = 5;

/// ⚠️⚠️⚠️ TURU 158b - **TERS DILIM MAKULLUK TAVANI (kus ucusunun kati).**
///
///	Ikinci koruma: pencere yeterince genis olsa bile ters cevrilen
///	dilim iki durak arasi kus ucusundan bu kattan UZUNSA, o dilim bir
///	guzergah degil bir ARTIKTIR ve ATILIR (duz-cizgi emniyet agina
///	dusulur).
/// ⚠️⚠️ 5 kat OLCULEREK secildi: gercek geri-inis vakalarini (en kotusu
///	oran **2,69**) KORUR, dejenere vakalarin TAMAMINI eler.
/// ⚠️ Bu UCUNCU korumadir; `basSegment` ve izdusum kapisi KALDIRILMAZ.
const double kDilimTersTavani = 5.0;

const double kAktarmaYaricapM = 150;

/// ⚠️⚠️ Aktarma icin en az bekleme tamponu (dk). Otobus 1 dk gec kalirsa
///	kullanici aktarmayi kacirmasin diye ikinci hat bu kadar SONRA
///	kalkmali.
const int kAktarmaTampon = 2;

/// ⚠️⚠️ Kapidan kapiya toplam sure tavani (dk).
///	Bugunku tek kapi BACAK BASINA 180 dk; aktarmada iki otobus bacagi
///	birden ona yaklasabilir (olculen en kotu: **234 dk**). Boyle bir
///	rota gosterilmemeli.
const int kToplamSureTavani = 150;

/// ⚠️⚠️ Siralamada aktarmaya eklenen CEZA (dk).
///	Aktarma yalnizca sureye bakilarak siralansaydi, 3 dakika daha
///	erken varan aktarmali bir rota aktarmasizin ONUNE gecerdi -
///	oysa aktarma gercek bir zahmet ve KACIRMA RISKI tasir.
///	Olculdu: 8 dk ceza ile aktarmali rota aramalarin **%37**'sinde
///	yine birinci kaliyor ve kazandiginda kazanc **medyan 53 dakika**.
const int kAktarmaCezasi = 8;

/// Sefer sutunundan bir bacak icin binis/inis dakikasi bulur.
///
/// ⚠️⚠️⚠️ **BU KAPI TAM KORUMA SAGLAMAZ — DURUST OLCUM.**
///
///	Kod `kalkislar[j]`nin iki durakta da AYNI SEFERI gosterdigini
///	VARSAYIYOR. Kapi yalniz uzunluklar farkliysa cifti atar.
///
/// ⚠️⚠️ **KOK NEDEN VARLIK URETICISINDE** (`tools/ulasim_uret.js`):
///	kalkis listeleri durak basina AYRI siralaniyor ve **sefer
///	kimligi ATILIYOR**. Yani veri, "bu kalkis hangi sefere ait"
///	bilgisini TASIMIYOR; indeks eslesmesi ancak iki duragi AYNI
///	sefer kumesi geciyorsa dogru olur.
///
/// ⚠️⚠️ **DENETIMDE OLCULEN GERCEK** (eski serhteki %0,12 YANILTICIYDI —
///	o, kapinin YAKALADIGI orandir, KACIRDIGI degil):
///	  · kapi cift havuzunun **%0,12**'sini eliyor
///	  · kapidan GECENLERIN **%2,6**'sini hicbir gercek sefer saglamiyor
///	  · secilen bacaklarin **%4,4**'unde varis saati UYDURMA
///	  · hatalarin **TAMAMI** varisi **ERKEN** gosteriyor -> o rota
///	    siralamada HAKSIZ YERE ONE gecer
///	  · bacaklar COGRAFI olarak GERCEK (durak sirasi dogru); yanlis
///	    olan yalnizca SAAT.
///
/// ⚠️⚠️ **KALICI COZUM AYRI TUR**: uretici `kalkislar`i
///	`[dakika, seferIndeksi]` olarak tasimali; o zaman `kalkislar[j]`
///	iki durakta da AYNI seferi gosterir ve bu kapi GEREKSIZLESIR.
///	Varlik yeniden uretimi + yeni surum gerektirir.
/// ⚠️⚠️ YAPMA: buraya "binis ve inis ayni seferden mi" kontrolu
///	eklemeye calisma - **mevcut varlik o bilgiyi TASIMIYOR.**
/// ⚠️ Ayni varsayim `_aktarmaliAra` icinde IKI KEZ daha kullaniliyor
///    (tur 1 ve tur 2 sutun kapilari) - orasi da bu serhe baglidir.
/// ⚠️ 180 dk tavani: ayni hattin gunun BASKA seferlerinin yanlis
///    eslesmesini eler (mevcut kuraldan devir).
({int binis, int inis, int sutun})? _seferBul(
  List<int> binisSaatleri,
  List<int> inisSaatleri,
  int enErken,
) {
  if (binisSaatleri.length != inisSaatleri.length) return null;
  // ⚠️⚠️⚠️ TURU 159 - **GECE HATLARI GORUNMUYORDU** (denetim; YUKSEK).
  //
  //	GTFS gece yarisini asan seferi **24:xx+** olarak saklar. Bu
  //	varlikta servis 1de **5.889 kalkis >= 1440**; 01:00-02:30 arasi
  //	**3.177 gercek kalkis** var (G1/G2/G3/N4 gece hatlari dahil,
  //	29 hat). `enErken` ise duvar saatinden turedigi icin 0..1439.
  //	Eski govde ham `b < enErken` karsilastiriyordu: saat 01:00de
  //	(`enErken` ~60) 24:30 kalkisi (1470) "1410 dakika sonra"
  //	sayiliyor, sonra `varis - suAn > kToplamSureTavani` (150)
  //	kapisinda ELENIYORDU -> **00:00-04:00 arasi TEK ADAY BILE yok.**
  //
  // ⚠️⚠️ **COZUM: "SIMDIDEN KAC DAKIKA SONRA" TABANI** (`sonrakiler`
  //	ile AYNI desen, turu 158b). Her sutunun beklemesi
  //	`((b - enErken) mod 1440)` ile bulunur, **EN KISA BEKLEYEN** secilir.
  // ⚠️⚠️⚠️ **ILK ESLESME ARTIK YETMEZ**: kalkis listesi MUTLAK dakikaya
  //	gore sirali, BEKLEMEYE gore DEGIL. "Ilk `b >= enErken`" almak,
  //	gece yarisindan sonra listenin BASINDAKI SABAH kalkisini secer
  //	ve gece otobusu HIC gorulmez. Bu yuzden TUM sutunlar taranir.
  // ⚠️⚠️ Donen `binis`/`inis` **MUTLAK ve 1440i ASABILIR**; cagiran
  //	tarafin aritmetigi (`varis - suAn`) ayni tabanda kalsin diye
  //	bekleme `enErken`e EKLENEREK dondurulur.
  // ⚠️ YAPMA: her `b`yi kosulsuz mod 1440 yapma — o zaman GECMIS bir
  //    sefer "yarin" sayilip en yakin gibi secilir ve normal saatlerde
  //    aday sayisi coker.
  var enIyi = -1;
  var enAzBek = 1 << 30;
  var eB = 0;
  var eI = 0;
  for (var j = 0; j < binisSaatleri.length; j++) {
    final b = binisSaatleri[j];
    final i = inisSaatleri[j];
    if (i <= b) continue;
    if (i - b > 180) continue;
    final bek = ((b - enErken) % 1440 + 1440) % 1440;
    if (bek >= enAzBek) continue;
    enAzBek = bek;
    enIyi = j;
    eB = enErken + bek;
    eI = eB + (i - b);
  }
  if (enIyi < 0) return null;
  return (binis: eB, inis: eI, sutun: enIyi);
}
/// Yaya hizi (m/sn). ⚠️ TEK KAYNAK: hem sure hem "kac dakika yurudum"
/// hesabi bunu okur. 1,3 m/sn ~ 4,7 km/sa — yetiskin ortalamasi.
const double kYayaHizi = 1.3;

int _yurumeDakikasi(double metre) => (metre / kYayaHizi / 60).ceil();

/// Bir polyline uzunlugu (metre) - sunucu `mesafe_m` vermezse yedek.
double _yolUzunlugu(List<({double enlem, double boylam})> yol) {
  var t = 0.0;
  for (var i = 0; i < yol.length - 1; i++) {
    t += UlasimVeri.kabaMetre(
        yol[i].enlem, yol[i].boylam, yol[i + 1].enlem, yol[i + 1].boylam);
  }
  return t;
}

/// ⚠️ Bir noktanin polyline uzerindeki EN YAKIN segment indeksi.
///
/// ⚠️⚠️ **METRIK DUZLEME GECILIR**: ham derece ile Gebze enleminde (40,8°)
///	boylam ekseni %24 yanlis olceklenir ve izdusum YANLIS segmente kayar
///	(turu 85b'de sunucu tarafinda birebir bu yasandi).
/// ⚠️ Sifira bolme kapisi ZORUNLU: GTFS sekillerinde ardisik TEKRARLI
///    nokta gercekten var; kapi olmazsa `t = NaN` olur ve **NaN her
///    karsilastirmadan sessizce duser** (turu 85b NaN dersi).
/// ⚠️⚠️⚠️ TURU 155 — **[basSegment]: ARAMAYI BURADAN BASLAT.**
///
///	Kullanici: *"bizimki DIREK USTUNDE"* (otobus cizgisi binalarin
///	uzerinden duz gidiyor).
///
/// ⚠️⚠️ **KOK NEDEN — ILMEKLI HATLAR.** Kucuk bir sehirde hatlar kendi
///	uzerine doner ve GLOBAL "en yakin segment" aramasi inis duragini
///	aynı caddenin **IKINCI GECISINE** kilitleyebilir. O zaman inis
///	indeksi binis indeksinden KUCUK cikar (`b <= a`), `_guzergahDilimi`
///	diimi uretemez ve iki durak arasi **DUZ CIZGI** dondurur.
///
///	GERCEK VERIDE OLCULDU (hafta ici, sefer-sutunu gecerlilik testiyle):
///	**361.110 gecerli durak ciftinin 14.799'u (%4,10)** bu dala
///	dusuyordu. En kotuleri: 300/yon1 **%41,2** · 480/yon0 %35,1 ·
///	440/yon1 %32,5 · 315/yon1 %30,3.
///
/// ⚠️⚠️ Kardes dosya `rota_takip.dart` bu tuzagi ZATEN kapatmis
///	(`basSegment` + arama penceresi) ve serhinde aynen soyle diyor:
///	*"Kucuk bir sehirde hatlar kendi uzerine doner; GLOBAL en yakin
///	segment aramasi kullaniciyi ILERIYE SICRATIR ya da geri atar."*
///	Ayni ders buraya UYGULANMAMISTI.
///
/// ⚠️ Burada PENCERE YOK (tum kalan cizgi taranir): `rota_takip`teki
///    40 segmentlik pencere GPS monotonlugu icindir; burada inis duragi
///    uzun bir hatta pencerenin DISINDA kalir ve sonuc DAHA KOTU olurdu.
/// ⚠️⚠️ TURU 158 - **IZDUSUM MESAFESI DE DONER.**
///	Segment indeksi tek basina "durak bu sekilde var mi" sorusunu
///	cevaplamiyordu; `_guzergahDilimi` artik uzakligi OLCUYOR.
/// ⚠️⚠️ **KOSE MESAFESI DEGIL IZDUSUM**: GTFS sekillerinde 400 m'yi
///	asan segmentler var; segmentin BASLANGIC KOSESINE olan mesafe
///	durak yolun tam ustunde olsa bile buyuk cikar. Bu tuzaga
///	ilk olcumde DUSULDU: kose ile "kotu vaka" %4,09 gorunurken
///	izdusumle **%1,05** cikti.
({int seg, double uz, double t}) _enYakinIz(
  List<({double enlem, double boylam})> yol,
  double enlem,
  double boylam, {
  int basSegment = 0,
}) {
  if (yol.length < 2) return (seg: 0, uz: double.infinity, t: 0);
  // ⚠️ Taban cizginin DISINA tasarsa arama yapilacak segment KALMAZ;
    // cagiran (`_guzergahDilimi`) bunu duz-cizgi dali ile karsilar.
  final bas = basSegment.clamp(0, yol.length - 2);
  final kx = 111320.0 * math.cos(yol.first.enlem * math.pi / 180);
  final px = boylam * kx;
  final py = enlem * 111320.0;
  var enIyi = bas;
  var enAz = double.infinity;
  // ⚠️⚠️⚠️ TURU 161 - **`t` ARTIK SAKLANIYOR** (dik baglayici icin).
  //
  //	Izdusum noktasi bu fonksiyonda ZATEN hesaplaniyordu (`qx`/`qy`)
  //	ama disari CIKMIYORDU; `_guzergahDilimi` elinde yalniz segment
  //	indeksi kaldigi icin duragi bir SONRAKI KOSEYE baglamak zorunda
  //	kaliyordu. Kullanici bunu gordu: *"otobus duraklari icerden
  //	90 derece dik cikip devam etmiyor"*.
  // ⚠️⚠️ **OLCULDU (11.437 hat-yon x durak cifti):** baglayicinin yola
  //	gore acisi ham GTFSte medyan **6,7 derece**; turu 160 sonrasi
  //	medyan **46,5** ama dik gorunen (>=70) hala yalnizca **%20,3**.
  //	Sebep geometrik: izdusum mesafesi medyan 5,7 m, koseye ileri
  //	ofset medyan 5,6 m -> atan(5,7/5,6) = 45,5 derece.
  //	Izdusum eklendiginde aci vakalarin **%98,2**sinde 90 olur.
  var enT = 0.0;
  for (var i = bas; i < yol.length - 1; i++) {
    final ax = yol[i].boylam * kx;
    final ay = yol[i].enlem * 111320.0;
    final bx = yol[i + 1].boylam * kx;
    final by = yol[i + 1].enlem * 111320.0;
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
      enIyi = i;
      enT = t;
    }
  }
  return (seg: enIyi, uz: math.sqrt(enAz), t: enT);
}

/// Uc noktalarinin tekillestirme esigi (metre).
///
/// ⚠️ TEK KAYNAK: hem `_uclariBagla` hem `_dilimKur` bunu okur. Ayri
///    sabit yazilirsa ikisi zamanla ayrisir (bu projenin ikinci en sik
///    hata sinifi).
const double kUcEsikM = 0.5;

/// [seg] segmenti uzerinde [t] parametresindeki nokta.
///
/// ⚠️⚠️ Hesap **DERECE UZAYINDA** yapilir, metrik uzayda DEGIL.
///
///	`t` afin bir parametre oldugu icin iki uzayda AYNIDIR; metrik
///	uzayda kurup `kx` ile geri cevirmek yalnizca yuvarlama kaymasi
///	uretir.
({double enlem, double boylam})? _izdusumNoktasi(
  List<({double enlem, double boylam})> yol,
  int seg,
  double t,
) {
  if (seg < 0 || seg + 1 >= yol.length) return null;
  final a = yol[seg];
  final b = yol[seg + 1];
  return (
    enlem: a.enlem + t * (b.enlem - a.enlem),
    boylam: a.boylam + t * (b.boylam - a.boylam),
  );
}

/// Otobus bacagi dilimini kurar: `[binis, q_a, ...koseler, q_b, inis]`.
///
/// ⚠️⚠️⚠️ TURU 161 - **DIK BAGLAYICI TEK KAYNAK.**
///
///	Kullanici (Yandex referansiyla): *"otobus duraklari icerden
///	90 derece dik cikip devam etmiyor"*. Eskiden dilim duragi bir
///	SONRAKI KOSEYE (`yol[a+1]`) bagliyordu; cizgi duraktan cikip
///	yola EGIK giriyor ve kayarak karisiyordu. Artik once duragin
///	yola DIK AYAGI (`q_a`) konur.
///
/// ⚠️⚠️ **MUKERRER NOKTA KAPISI ZORUNLU**: `_enYakinIz` icinde `t`
///
///	`clamp(0,1)` ile kirpiliyor; vakalarin **%1,8**inde q tam bir
///	KOSENIN uzerine duser ve ayni nokta iki kez girer (ya da dilim
///	bir adim geri gider). Bu yuzden komsusuna `kUcEsikM`den yakin
///	her nokta ATILIR. Turu 155in `_uclariBagla` esigiyle AYNI sinif.
///
/// ⚠️⚠️ **TERS DILIMDE UCLAR TAKASLANMAZ**: ters cevrilen yalniz KOSE
///
///	SIRASIDIR; izdusumler kendi duraklarina bagli kalir. Yani her iki
///	dalda da **q_a BASTA, q_b SONDA**. Yardimciya "uclari takasla"
///	parametresi KOYMA.
///
/// ⏳ **DURUST SINIR:** dik cikisin boyu = izdusum mesafesi, medyan
///
///	**5,7 m**. Gebze enleminde z18de ~12,6 dp; cizgi genisligi
///	`kOtobusEn` 6 + kilif 2 = 8 dp. Yani z18de SINIRDA, **z19da
///	net**. p25 = 3,3 m olan ciftlerde z18de fiilen gorunmez.
List<({double enlem, double boylam})> _dilimKur({
  required List<({double enlem, double boylam})> yol,
  required Durak binis,
  required Durak inis,
  required int aSeg,
  required double aT,
  required int bSeg,
  required double bT,
  required double aUz,
  required double bUz,
  required Iterable<({double enlem, double boylam})> koseler,
}) {
  // ⚠️⚠️⚠️ TURU 161 - **SEKIL DURAGI KAPSAMIYORSA O UC CIZILMEZ.**
  //
  //	Turu 161 koy duraklarini varliga eklerken bir delik acti:
  //	**423 hattinin GTFS sekli Ovacik Koyune HIC ULASMIYOR**
  //	(durak seklin en kuzey noktasindan **6.989 m** uzakta) ama
  //	`stop_times` 74 trip ile oraya gittigini soyluyor. Yani SEFER
  //	GERCEK, bozuk olan yalniz SEKIL.
  //	Eskiden dilimin sonuna **7.001 m uzunlugunda uydurma bir
  //	baglayici** ekleniyordu -> haritada tam da kullanicinin
  //	sikayet ettigi *"alakasiz, fazladan dev diagonal cizgi"*.
  //
  // ⚠️⚠️ **TURU 158 MUHAFIZI BUNU YAPISAL OLARAK YAKALAYAMAZ**:
  //	kurtarma sarti `bG.uz * 3 < bIz.uz`; burada global izdusum de
  //	ayni degeri veriyor (`6989*3 < 6989` FALSE) -> kurtarma dalina
  //	HIC girilmiyor.
  //
  // ⚠️ **SEFER SILINMEZ, YALNIZ CIZGI KESILIR.** Cift elenirse Gebze
  //    merkez -> Ovacik icin dogrudan rota KALMIYOR (KM58 165 dk ile
  //    150 dk tavanina takiliyor) ve turu 161de kullanicinin ACIKCA
  //    istedigi sey geri kaybedilirdi.
  //
  // 📊 OLCULDU: 11.440 (durak,hat,yon) uclusunun **8i** bu sinifta
  //    (%0,07). En kotusu Ovacik degil: SEKER SOKAK 2 / hat 504 yon0
  //    = **7.200 m**. Bu sinif turu 160ta da vardi.
  final basVar = aUz <= kDilimIzdusumTavani;
  final sonVar = bUz <= kDilimIzdusumTavani;
  final ham = <({double enlem, double boylam})>[
    if (basVar) (enlem: binis.enlem, boylam: binis.boylam),
    ?_izdusumNoktasi(yol, aSeg, aT),
    ...koseler,
    ?_izdusumNoktasi(yol, bSeg, bT),
    if (sonVar) (enlem: inis.enlem, boylam: inis.boylam),
  ];
  final cikti = <({double enlem, double boylam})>[];
  for (final n in ham) {
    if (cikti.isNotEmpty) {
      final o = cikti.last;
      if (UlasimVeri.kabaMetre(o.enlem, o.boylam, n.enlem, n.boylam) <=
          kUcEsikM) {
        continue;
      }
    }
    cikti.add(n);
  }
  return cikti;
}

/// Bir polyline'in iki durak arasindaki dilimi.
///
/// ⚠️⚠️ TURU 155 — **INIS DURAGI BINISTEN SONRA ARANIR** (`basSegment`).
///	Onceden ikisi de GLOBAL araniyordu ve ilmekli hatlarda inis,
///	aynı caddenin ikinci gecisine kilitlenip `b <= a` uretiyordu;
///	o durumda cizgi iki durak arasi DUZ bir hat oluyor, yani
///	kullanicinin gordugu **"binalarin uzerinden gecen"** cizgi.
///	Olculdu: %4,10 -> yapisal olarak ~0.
///
/// ⚠️⚠️⚠️ TURU 158 — **BU SAYI YANILTICIYDI: `b <= a` SAYACINI olcuyor,
///	CIZGININ DOGRULUGUNU degil.** `basSegment` `b > a`yi yapisal
///	kildigi icin sayac dustu ama hata KUYRUGA TASINDI: zorlanan `b`
///	alakasiz bir segmente kilitlenince dilimin SONUNA kilometrelerce
///	uydurma duz cizgi ekleniyordu. Asagidaki izdusum kapisi (turu 158)
///	tam bunu kapatir. Olculdu: inis izdusumu >300 m olan cift orani
///	**%0,99 -> %0,06**, izdusum p99 **289 m -> 41 m**.
///
/// ⚠️ Sira TERS gelirse (sekil ters yonde cizilmis) dilim BOS DONMEZ,
///    duraklar arasi duz cizgi dondurulur — ekranda "hicbir sey yok"
///    gorunmesindense kaba ama DOGRU bir cizgi daha iyidir.
/// ⚠️ **Bu duz-cizgi dali SILINMEZ**: `basSegment` ile bile
///    `yol.length < 2` ya da binis son segmentte olma hali kalir.
///    Artik ULASILMASI ZOR bir emniyet agidir.
List<({double enlem, double boylam})> _guzergahDilimi(
  List<({double enlem, double boylam})> yol,
  Durak binis,
  Durak inis,
) {
  if (yol.length < 2) {
    return [
      (enlem: binis.enlem, boylam: binis.boylam),
      (enlem: inis.enlem, boylam: inis.boylam),
    ];
  }
  final aIz = _enYakinIz(yol, binis.enlem, binis.boylam);
  final a = aIz.seg;
  // ⚠️⚠️ Inis BINISTEN SONRA aranir — bkz. `_enYakinSegment` serhi.
  // ⚠️⚠️⚠️ TURU 161 - **KAPSAM SORUSU GLOBALDIR, PENCERELI DEGIL.**
  //
  //	"Sekil bu duragi kapsiyor mu?" sorusunun cevabi PENCERELI
  //	aramadan OKUNAMAZ: ilmekli hatlarda (seklilerin **%17,3**u
  //	ilmekli - turu 155 olcumu) durak sekil UZERINDE olsa bile
  //	binisin ILERISINDE olmadigi icin pencereli mesafe buyuk cikar.
  //	O deger kapsam kapisina baglansaydi SIRADAN ilmekli hatlarda
  //	tetiklenir ve cizgi yanlis yerde kesilirdi.
  // ⚠️ Ek maliyet YOK sayilir: `_guzergahDilimi` yalniz KAZANAN
  //    adaylar icin cagriliyor (pahali insa turu 157de ic donguden
  //    CIKARILDI).
  final bIzG = _enYakinIz(yol, inis.enlem, inis.boylam);
  var bIz = _enYakinIz(yol, inis.enlem, inis.boylam, basSegment: a + 1);
  // ⚠️⚠️⚠️ TURU 158 - **ZORLANAN `b` GERCEKTEN DURAGIN YANINDA MI?**
  //
  //	Kullanici: *"aktarmali otobuste DIREK CIZGI var yesilde"*.
  //
  // ⚠️⚠️ **KOK NEDEN — VE TURU 155 BUNU AZALTMADI, TASIDI.**
  //	`basSegment: a + 1` ile `b > a` **YAPISAL OLARAK** garanti
  //	oldugu icin asagidaki `b <= a` duz-cizgi dali artik
  //	neredeyse hic tetiklenmiyor (**%0,17**). Ama inis duragi
  //	sekil boyunca GERCEKTEN binisten once geliyorsa, zorlanan
  //	`b` ileride ALAKASIZ bir segmente kilitleniyor ve dilimin
  //	SONUNA **kilometrelerce uydurma DUZ CIZGI** ekleniyor.
  //	OLCULDU: gecerli ciftlerin **%6,13**'unde son baglayici
  //	>300 m (turu 155 oncesi %4,03 -> sonrasi %6,13, yani
  //	TOPLAM ARTTI); aktarmali rotada iki otobus bacagi oldugu
  //	icin maruziyet **%11,88**.
  //	Kullanicinin ekran goruntusu BIT BIT yeniden uretildi:
  //	510B|yon0, GUZELLER OSB -> 2477. SOKAK 1, a=441, zorlanan
  //	b=448, **son baglayici 1224 m**; global b=344 ile ~5 m.
  //
  // ⚠️⚠️ **IKI KORUMA BIRLIKTE GEREKIR**: `basSegment` KALDIRILMAZ
  //	(kaldirilirsa turu 155'in kapattigi %4,03 geri gelir),
  //	ustune baglayici UZUNLUGU olculur.
  // ⚠️ `dG * 3 < dIleri`: global aday BELIRGIN bicimde daha iyi
  //    olmali. Ilmekli hatlarda global indeks yanlis gecisi secebilir,
  //    bu yuzden kapi MUHAFAZAKAR.
  // ⚠️ Bu duzeltme SALT GEOMETRIKTIR: otobus bacaginin `dakika`si
  //    GTFS sefer sutunundan gelir, otobuse yetisme hesabi ETKILENMEZ.
  // ⚠️⚠️⚠️ TURU 158b - **DEJENERE PENCEREDE `bIz.uz` KANIT DEGILDIR.**
  //	Aranan segment sayisi `kDilimPencereAsgari`nin altindaysa donen
  //	uzaklik pencerenin artigidir; kapi ACILMAZ ve akis asagidaki
  //	duz-cizgi emniyet agina duser (turu 157 davranisi).
  final pencereGenis =
      (yol.length - 2) - (a + 1) + 1 >= kDilimPencereAsgari;
  if (pencereGenis && bIz.uz > kDilimIzdusumTavani) {
    final bG = bIzG;
    // ⚠️⚠️ **`bG.seg > a` KOSULU YOKTUR — OLCULDU, BOS CIKIYOR.**
    //	Arastirma o kosulu onerdi; simule edildi ve **0 cift**
    //	duzeldi: `bG.seg > a` ise `bG` zaten pencerenin ICINDE
    //	ve pencereli arama onu ZATEN buluyor, yani kosul
    //	yapisal olarak ETKISIZ. Asil vakalarda `bG.seg < a`dir.
    if (bG.uz * 3 < bIz.uz) {
      if (bG.seg > a) {
        bIz = bG;
      } else {
        // ⚠️⚠️⚠️ **SEKIL TERS YONDE CIZILMIS**: inis duragi sekil
        //	boyunca binisten ONCE geliyor ama izdusumu duraga
        //	COK yakin. Dilim [bG..a] alinip TERS CEVRILIR;
        //	boylece cizgi binisten inise dogru akar.
        // ⚠️ OLCULDU: kotu vakalarin **%86,5**'i tam budur
        //    (global izdusum medyan **8 m**).
        final alt = bG.seg + 1;
        final ust = math.min(a + 1, yol.length);
        if (alt < ust) {
          final ters = _dilimKur(
            yol: yol,
            binis: binis,
            inis: inis,
            aSeg: a,
            aT: aIz.t,
            bSeg: bG.seg,
            bT: bG.t,
            aUz: aIz.uz,
            bUz: bG.uz,
            koseler: yol.sublist(alt, ust).reversed,
          );
          // ⚠️⚠️⚠️ TURU 158b - **SONUC MAKUL MU?**
          //	Ters dilim iki durak arasi kus ucusunun
          //	`kDilimTersTavani` katindan uzunsa bu bir guzergah
          //	DEGIL, artiktir (olculdu: 31 km'lik cizgiler).
          //	Atilir ve duz-cizgi emniyet agina dusulur.
          // ⚠️⚠️ Denetim dersi: turun KENDI olcumu yalniz IZDUSUM
          //	MESAFESINI olcuyordu ve kapi acildiginda o deger
          //	TANIM GEREGI iyilesiyor (1592 m -> 2 m); 31 km'lik
          //	ters cizgi o metrikte "basari" gorunuyordu.
          //	**Bir duzeltmeyi, duzeltmenin KENDI hedef metrigiyle
          //	olcme — SONUCU olc.**
          final kus = UlasimVeri.kabaMetre(
              binis.enlem, binis.boylam, inis.enlem, inis.boylam);
          if (kus <= 0 || _yolUzunlugu(ters) <= kus * kDilimTersTavani) {
            return ters;
          }
        }
      }
    }
  }
  final b = bIz.seg;
  if (b <= a) {
    // ⚠️⚠️⚠️ TURU 161 - **KAPSAM DISI UCTA DUZ CIZGI CIZME.**
    //
    //	Bu emniyet agi normalde ILMEKLI hatlar icindir ve iki durak
    //	da sekil UZERINDE oldugu icin cizdigi duz cizgi KISADIR.
    //	Ama sekil duragi hic kapsamiyorsa (423/Ovacik) ayni dal
    //	hariteyi capraz kesen **19.264 m** uzunlugunda bir cizgi
    //	uretiyordu. O vakada seklin KENDI kuyrugu cizilir: cizgi
    //	gercek guzergahi izler ve seklin bittigi yerde DURUR.
    if (bIzG.uz > kDilimIzdusumTavani && a + 1 < yol.length) {
      return _dilimKur(
        yol: yol,
        binis: binis,
        inis: inis,
        aSeg: a,
        aT: aIz.t,
        bSeg: yol.length - 2,
        bT: 1,
        aUz: aIz.uz,
        bUz: bIzG.uz,
        koseler: yol.sublist(a + 1, yol.length),
      );
    }
    if (aIz.uz > kDilimIzdusumTavani && bIzG.seg > 0) {
      return _dilimKur(
        yol: yol,
        binis: binis,
        inis: inis,
        aSeg: 0,
        aT: 0,
        bSeg: bIzG.seg,
        bT: bIzG.t,
        aUz: aIz.uz,
        bUz: bIzG.uz,
        koseler: yol.sublist(0, math.min(bIzG.seg + 1, yol.length)),
      );
    }
    return [
      (enlem: binis.enlem, boylam: binis.boylam),
      (enlem: inis.enlem, boylam: inis.boylam),
    ];
  }
  return _dilimKur(
    yol: yol,
    binis: binis,
    inis: inis,
    aSeg: a,
    aT: aIz.t,
    bSeg: b,
    bT: bIz.t,
    aUz: aIz.uz,
    // ⚠️⚠️ Kapsam kapisi burada **PENCERELI** olcuyu okur, global degil.
    //
    //	`bIz` binisin ILERISINDEN aranir; bu dalda buyuk cikmasi
    //	"seklin ILERI kismi bu duragi icermiyor" demektir ve o zaman
    //	cizilecek baglayici UYDURMADIR. Global olcuyle yumusatmak
    //	(min) olculdu: 2 km+ uydurma baglayici %0,73te KALIYORDU.
    // ⚠️ Ters cevirme dali AYRI: orada bilerek `bG.uz` gecilir.
    bUz: bIz.uz,
    koseler: yol.sublist(a + 1, math.min(b + 1, yol.length)),
  );
}

/// Aktarmasiz rota adaylari (en erken varis ONCE, en fazla [adet]).
///
/// ⚠️ Yaricap 800 m: olculdu, 500 m'de kapsama %28, 800 m'de %41.
///    Daha genis yaricap yurume suresini kabul edilemez yapiyor.
Future<List<RotaAdayi>> rotaAra({
  required double baslangicEnlem,
  required double baslangicBoylam,
  required double varisEnlem,
  required double varisBoylam,
  int adet = 3,
  double yaricapM = 800,
  DateTime? an,
  String varisAd = '',
}) async {
  final servis = UlasimVeri.bugunServis(an);
  final suAn = UlasimVeri.suAnDakika(an);

  final basDuraklar = await UlasimVeri.i.yakinDuraklar(
    baslangicEnlem,
    baslangicBoylam,
    adet: 12,
    yaricapM: yaricapM,
  );
  final varDuraklar = await UlasimVeri.i.yakinDuraklar(
    varisEnlem,
    varisBoylam,
    adet: 12,
    yaricapM: yaricapM,
  );
  if (basDuraklar.isEmpty || varDuraklar.isEmpty) return const [];

  // Duraklarin hat tablolarini BIR KEZ coz (ic ice dongude tekrar cozmek
  // 144 kez ayni isi yapardi).
  final basHat = <String, List<DurakHatti>>{};
  for (final d in basDuraklar) {
    basHat[d.id] = await UlasimVeri.i.duraginHatlari(d.id, servis);
  }
  final varHat = <String, List<DurakHatti>>{};
  for (final d in varDuraklar) {
    varHat[d.id] = await UlasimVeri.i.duraginHatlari(d.id, servis);
  }

  final adaylar = <RotaAdayi>[];
  for (final o in basDuraklar) {
    final oM = UlasimVeri.kabaMetre(
        baslangicEnlem, baslangicBoylam, o.enlem, o.boylam);
    final oDk = _yurumeDakikasi(oM);
    for (final d in varDuraklar) {
      if (d.id == o.id) continue;
      final dM =
          UlasimVeri.kabaMetre(varisEnlem, varisBoylam, d.enlem, d.boylam);
      final dDk = _yurumeDakikasi(dM);

      for (final oh in basHat[o.id] ?? const <DurakHatti>[]) {
        for (final dh in varHat[d.id] ?? const <DurakHatti>[]) {
          if (oh.hat.id != dh.hat.id || oh.yon != dh.yon) continue;

          // ⚠️⚠️ **GECERLILIK SIRADAN DEGIL SEFER SUTUNUNDAN.**
          //	Durak sirasi (stop_sequence) veride YOK ve zaman siralamasi
          //	dongusel hatlarda yaniltiyor (olculdu: en kotu grupta %65,8
          //	ters cift). Dogru olcut: AYNI SEFERDE binis saati inis
          //	saatinden ONCE mi?
          // ⚠️⚠️⚠️ TURU 157 - **`math.min(...)` GIZLI BIR VARSAYIMDI.**
          //	Iki duragin kalkis listelerinin INDEKS INDEKS AYNI
          //	SEFERI gosterdigini varsayiyordu. **OLCULDU: 200
          //	hat-yonun 8'i bunu SAGLAMIYOR** ve fark TAM 2 KAT -
          //	ilmekli hatta ayni durak ayni seferde IKI KEZ
          //	geciliyor. `min` ile kisa listeye hizalanmak, uzun
          //	listedeki duragin **YANLIS seferini** okumak demekti.
          //	Bugun durak ciftlerinin %0,12'si etkileniyordu;
          //	aktarmada IKI otobus bacagi oldugu icin maruziyet
          //	IKIYE KATLANIRDI.
          // ⚠️⚠️ Kapi TEK KAYNAKTAN (`_seferBul`): uzunluklar ESIT
          //	DEGILSE cift ATLANIR. Yanlis sonuc uretmektense
          //	sonuc URETMEMEK dogrudur.
          final enErken = suAn + oDk;
          final sf = _seferBul(oh.kalkislar, dh.kalkislar, enErken);
          if (sf == null) continue;
          final binis = sf.binis;
          final inis = sf.inis;

          final varis = inis + dDk;
          // ⚠️⚠️⚠️ TURU 157 - **TAVAN ARTIK AKTARMASIZ DALA DA UYGULANIR.**
          //	Onceden `kToplamSureTavani` YALNIZ `_aktarmaliAra`da
          //	vardi ve asimetri kullaniciya GORUNURDU: 151 dakikalik
          //	aktarmali rota SESSIZCE atilirken **984 dakikalik
          //	(16 saat)** aktarmasiz bir rota *"en iyi secenek"* diye
          //	BIRINCI sirada gosteriliyordu.
          // ⚠️⚠️ Yan etki ISTENEN: tavan yuzunden tekil hat sayisi duser,
          //	dolayisiyla aktarma aramasi DAHA SIK kosar.
          if (varis - suAn > kToplamSureTavani) continue;
          final yol = await UlasimVeri.i.guzergah(oh.hat.id, oh.yon);
          final dilim = _guzergahDilimi(yol, o, d);


          adaylar.add(RotaAdayi(
            sefer: SeferKaydi(b1: oh.kalkislar, i1: dh.kalkislar),
            hat: oh.hat,
            varisDakika: varis,
            toplamDakika: varis - suAn,
            yurumeDakika: oDk + dDk,
            bacaklar: [
              RotaBacagi(
                tur: BacakTuru.yuru,
                noktalar: [
                  (enlem: baslangicEnlem, boylam: baslangicBoylam),
                  (enlem: o.enlem, boylam: o.boylam),
                ],
                dakika: oDk,
                metre: oM,
                baslik: '${o.ad} durağına yürü',
                altBaslik: '${oM.round()} m · yaklaşık',
                eylem: 'Durağa kadar yürüyün',
                yer: o.ad,
              ),
              RotaBacagi(
                tur: BacakTuru.bekle,
                noktalar: const [],
                dakika: math.max(0, binis - (suAn + oDk)),
                // ⚠️ TURU 158b - imlec bunu TURETMEZ, OKUR.
                kalkisDakika: binis,
                baslik: '${UlasimVeri.saatMetni(binis)} kalkış',
                altBaslik: o.ad,
                hat: oh.hat,
                eylem: '${UlasimVeri.saatMetni(binis)} kalkışını bekleyin',
                yer: o.ad,
              ),
              RotaBacagi(
                tur: BacakTuru.otobus,
                noktalar: dilim,
                dakika: inis - binis,
                baslik: '${d.ad} durağında in',
                altBaslik: oh.hat.yonBaslik[oh.yon] ?? oh.hat.uzunAd,
                hat: oh.hat,
                eylem: '${oh.hat.kisaAd} ile gidin, inin:',
                yer: d.ad,
              ),
              RotaBacagi(
                tur: BacakTuru.yuru,
                noktalar: [
                  (enlem: d.enlem, boylam: d.boylam),
                  (enlem: varisEnlem, boylam: varisBoylam),
                ],
                dakika: dDk,
                metre: dM,
                baslik: 'Varışa yürü',
                altBaslik: '${dM.round()} m · yaklaşık',
                eylem: 'Varışa kadar yürüyün',
                // ⚠️ Varis adi CAGIRANDAN gelir (`rotaAra(varisAd:)`);
                //    `rotaAra` yalniz KOORDINAT aliyordu, ad ekranda vardi
                //    ama fonksiyona GECMIYORDU. Bos ise 'Varış' yazilir.
                yer: varisAd.isEmpty ? 'Varış' : varisAd,
              ),
            ],
          ));
        }
      }
    }
  }

  // ⚠️⚠️⚠️ TURU 157 - **AKTARMALI ADAYLAR AYNI LISTEYE KATILIR.**
  //
  //	AYRI BIR BOLUM YAPILMADI (olculdu): durak ciftlerinin **%61'inde
  //	aktarmasiz cozum HIC YOK**, yani "Aktarmasız" basligi cogu
  //	aramada BOMBOS kalirdi.
  // ⚠️⚠️ **ARAMA HER ZAMAN KOSULMAZ**: aktarmasiz sonuc `adet` kadar
  //	doluysa ikinci tur ATLANIR - kisa mesafelerde (0-3 km, %61
  //	basari) gereksiz is yapilmaz.
  //
  // ⚠️⚠️⚠️ **OLCUT HAM LISTE DEGIL, TEKIL HAT SAYISI.**
  //	Ilk yazimda kapi `adaylar.length < adet` idi ve `adaylar`
  //	TEKILLESTIRILMEMIS ham listedir: 12 binis x 12 inis duragi
  //	taranidigi icin **TEK BIR HAT** bile onlarca kayit uretir.
  //	Yani ekranda YALNIZ BIR rota gorunecek olsa bile
  //	`adaylar.length` 3'u rahatca astigi icin aktarma aramasi
  //	**HIC KOSMUYORDU** - kullanici tek secenekle kalirken
  //	aktarmayla cok daha hizli bir yol VARDI ve gosterilmiyordu.
  // ⚠️⚠️ Tekilleme olcutu asagidaki `zincir` ile AYNI olmak zorunda;
  //	ayrisirsa kapi yine yanlis sayar.
  final tekilHat = <String>{};
  for (final a in adaylar) {
    tekilHat.add([
      for (final b in a.bacaklar)
        if (b.tur == BacakTuru.otobus && b.hat != null) b.hat!.id,
    ].join('>'));
  }
  if (tekilHat.length < adet) {
    adaylar.addAll(await _aktarmaliAra(
      basDuraklar: basDuraklar,
      varDuraklar: varDuraklar,
      basHat: basHat,
      baslangicEnlem: baslangicEnlem,
      baslangicBoylam: baslangicBoylam,
      varisEnlem: varisEnlem,
      varisBoylam: varisBoylam,
      servis: servis,
      suAn: suAn,
      varisAd: varisAd,
    ));
  }

  // ⚠️⚠️⚠️ **SIRALAMA: VARIS + AKTARMA CEZASI.**
  //	Ciplak varis saatiyle siralansaydi, 3 dakika daha erken varan
  //	aktarmali bir rota aktarmasizin ONUNE gecerdi - oysa aktarma
  //	gercek bir zahmet ve KACIRMA RISKI tasir.
  //	Olculdu: 8 dk ceza ile aktarmali rota aramalarin %37'sinde
  //	yine birinci kaliyor ve kazandiginda kazanc medyan 53 dakika.
  int puan(RotaAdayi a) => a.varisDakika + a.aktarma * kAktarmaCezasi;
  adaylar.sort((a, b) => puan(a).compareTo(puan(b)));
  // ⚠️⚠️ **TEKILLEME ANAHTARI HAT ZINCIRI**, tek basina `hat.id` DEGIL
  //	(olculdu: tekil hat cifti medyan 26, maks 509). Tek anahtarla
  //	ilk hattin BUTUN aktarmalari SESSIZCE elenirdi.
  final gorulen = <String>{};
  final sonuc = <RotaAdayi>[];
  for (final a in adaylar) {
    final zincir = [
      for (final b in a.bacaklar)
        if (b.tur == BacakTuru.otobus && b.hat != null) b.hat!.id,
    ].join('>');
    if (!gorulen.add(zincir)) continue;
    sonuc.add(a);
    if (sonuc.length >= adet) break;
  }

  // ⚠️⚠️⚠️ **YURUME ROTALARI EN SONDA, YALNIZ KAZANAN ADAYLAR ICIN.**
  //	Ilk yazimda cagri ic ice dongunun ICINDEYDI ve SUNUCU
  //	LOGUNDA OLCULDU: **tek arama 90+ istek** uretiyordu. Her
  //	istek Google Routes'ta FATURALANABILIR bir cagri; aylik
  //	10.000 ucretsiz kota ~110 aramada biterdi.
  //	Simdi yalniz DONULECEK adaylar zenginlestiriliyor:
  //	en fazla `adet x 2` = **6 cagri**.
  // ⚠️ Tumu PARALEL: ard arda beklenseydi sonuc ekrani 6 tur gecikirdi.
  await _yurumeleriZenginlestir(sonuc);
  // ⚠️⚠️⚠️ TURU 158 - yurume sureleri GERCEKLESTI; sefer secimi ESKI
  //	tahmine dayaniyordu ve artik yetisilemeyecek bir kalkis
  //	onerebilir. Yeniden secim TAMAMEN YEREL (bkz. serh).
  _seferleriYenidenSec(sonuc, suAn);
  return sonuc;
}


/// ⚠️⚠️⚠️ TURU 157 - **AKTARMALI ADAYLARI URETIR (IKI TUR).**
///
///	TUR 1: baslangica yakin duraklardan kalkan her hat-yon icin
///	       SECILEN SEFER SUTUNU boyunca **hattin tum duraklarina**
///	       varis saatleri okunur (ters indeks sayesinde O(1)).
///	TUR 2: her varis noktasindan (kendisi + 150 m icindeki komsulari)
///	       kalkan hatlar taranir; ikinci sefer sutunu
///	       `inis1 + tampon + aktarma yurumesi` sonrasi olmali.
///
/// ⚠️⚠️ **AYNI HATTA AKTARMA ELENIR**: ayni hat-yonda inip tekrar binmek
///	bir aktarma DEGILDIR, tek bacaktir; tur 1 zaten o dilimi buluyor.
/// ⚠️⚠️ **TEKILLEME ANAHTARI `hat1|hat2`**, tek basina `hat.id` DEGIL
///	(olculdu: tekil hat cifti sayisi medyan 26, maks 509 - tek
///	anahtarla ilk hattin butun aktarmalari SESSIZCE elenirdi).
/// ⚠️⚠️ **AKTARMA YURUMESI ICIN GOOGLE ROUTES CAGRILMAZ**: sure medyan
///	1 dk / maks 2 dk, duz cizgi yeterince dogru. Cagrilsaydi bacak
///	sayisi 2'den 3'e cikacagi icin aylik 10.000 ucretsiz kota
///	~1.660 aramadan ~1.100'e duserdi (turu 152 maliyet dersi).
///	Bu yuzden aktarma yurumesi `noktalar: const []` ile kurulur -
///	`_yurumeleriZenginlestir` yalniz 2 noktali bacaklari isliyor,
///	yani bu bacak ONA HIC UGRAMAZ ve kota **6'da KALIR**.
///	⚠️⚠️ Ayni durakta aktarmada (vakalarin %36'si) zaten yurume YOK.
Future<List<RotaAdayi>> _aktarmaliAra({
  required List<Durak> basDuraklar,
  required List<Durak> varDuraklar,
  required Map<String, List<DurakHatti>> basHat,
  required double baslangicEnlem,
  required double baslangicBoylam,
  required double varisEnlem,
  required double varisBoylam,
  required int servis,
  required int suAn,
  required String varisAd,
}) async {
  final indeks = await UlasimVeri.i.hatDuraklari(servis);
  final durakM = await UlasimVeri.i.durakHaritasi();
  final durakHat = await UlasimVeri.i.durakHatIndeksi(servis);
  final komsu = await UlasimVeri.i.komsuDuraklar(kAktarmaYaricapM);
  // ⚠️⚠️ Guzergah cizgileri DONGUNUN ICINDE cozulmez: `guzergah()`
  //	polyline coz uyor ve ic ice donguden cagrilsaydi ayni sekil
  //	yuzlerce kez yeniden cozulurdu. Yerel onbellek.
  final yolOnbellek = <String, List<({double enlem, double boylam})>>{};
  // ⚠️ hat|yon -> o hattin VARIS ADAYI duraklari (bkz. kesit serhi).
  final kesit = <String, List<({String durakId, List<int> kalkislar})>>{};
  Future<List<({double enlem, double boylam})>> yolAl(
      String hatId, int yon) async {
    final k = '$hatId|$yon';
    return yolOnbellek[k] ??= await UlasimVeri.i.guzergah(hatId, yon);
  }
  // ⚠️⚠️⚠️ TURU 157 - **VARIS TARAFINDA TAVAN YOK** (denetimde olculdu).
  //
  //	Ilk yazimda burada da `.take(7)` vardi ve GEREKCESI KENDI
  //	ICINDE CURUKTU: serh *"`hedef` bir Set-benzeri arama tablosu
  //	oldugu icin kucultmek dogrudan ic dongu maliyetini DUSURMEZ"*
  //	diyordu - yani tavanin performans kazanci OLMADIGINI kendisi
  //	yaziyordu; geriye yalnizca ZARARI kaliyordu.
  //
  //	**OLCULDU (tavan kaldirilinca):**
  //	  birinci sira kotulesmesi  %22,8 -> **%4,0**  (5,7 kat)
  //	  bos sonuc ekrani              9 -> **1**
  //	  maliyet p99               203 ms -> **192 ms**
  //	Yani kaldirmak DAHA IYI SONUC ve DAHA UCUZ.
  // ⚠️ KALKIS tarafindaki tavan (`kAktarmaDurakTavani`) KALIR:
  //    asil maliyet orada ve orasi gercekten dogrusal DEGIL.
  final hedef = {for (final d in varDuraklar) d.id: d};
  final sonuc = <RotaAdayi>[];
  // ⚠️ Hat cifti -> O CIFTIN EN ERKEN VARAN kombinasyonu (hafif kayit).
  final enIyi = <String,
      ({
    Durak o,
    DurakHatti oh,
    int binis,
    int oDk,
    double oM,
    int enErken,
    Durak aktD,
    int inis1,
    Durak y,
    double yurM,
    int yurDk,
    int hazir,
    DurakHatti dh,
    int binis2,
    Durak d,
    int inis2,
    double dM,
    int dDk,
    int varis,
    List<int> i1Kalkis,
    List<int> i2Kalkis,
  })>{};

  // ⚠️⚠️⚠️ **AKTARMA TURUNDE DURAK SAYISI SINIRLI** (olculdu).
  //
  //	Aktarmasiz arama 12 binis x 12 inis duragi tariyor; aktarmada
  //	her binis duragi ayrica **hattin TUM duraklarina** ve onlarin
  //	komsularina aciliyor, yani maliyet dogrusal DEGIL.
  //	OLCULDU: 12 durakla en kotu arama **171 ms** (masaustu, JIT) -
  //	200 ms butcesinin sinirinda. Yavas bir telefonda ASILIRDI.
  //
  // ⚠️⚠️ EN YAKIN duraklar zaten EN IYI adaylar: `yakinDuraklar`
  //	listeyi mesafeye gore SIRALI donduruyor ve 7. duraga kadar
  //	inince yurume suresi cogu vakada rotayi ZATEN eliyor.
  // ⚠️ Aktarmasiz arama 12 durakla KALIR - orada maliyet dusuk ve
  //    kapsama daha degerli.
  const kAktarmaDurakTavani = 7;
  final basAktarma = basDuraklar.take(kAktarmaDurakTavani).toList();

  for (final o in basAktarma) {
    final oM = UlasimVeri.kabaMetre(
        baslangicEnlem, baslangicBoylam, o.enlem, o.boylam);
    final oDk = _yurumeDakikasi(oM);
    for (final oh in basHat[o.id] ?? const <DurakHatti>[]) {
      final anahtar1 = '${oh.hat.id}|${oh.yon}';
      final hat1Duraklar = indeks[anahtar1];
      if (hat1Duraklar == null) continue;
      // binis duraginin bu hattaki sutunu
      final binisSat = oh.kalkislar;
      var sutun1 = -1;
      final enErken = suAn + oDk;
      // ⚠️⚠️ TURU 159 - gece sarmasi (bkz. `_seferBul` serhi). Aktarmali
      //	dal da AYNI tabani kullanmali; yoksa gece yarisindan sonra
      //	aktarmali rota hic uretilmez (aktarmasiz duzelirken bu dal
      //	geride kalirdi - "ayni kuralin iki kopyasi drift eder").
      var bek1 = 1 << 30;
      for (var j = 0; j < binisSat.length; j++) {
        final b = ((binisSat[j] - enErken) % 1440 + 1440) % 1440;
        if (b < bek1) {
          bek1 = b;
          sutun1 = j;
        }
      }
      if (sutun1 < 0) continue;
      // ⚠️ MUTLAK degere cevrilir; `inis1` ayni sutundan okundugu icin
      //    aralarindaki fark (yolculuk suresi) DEGISMEZ.
      final binis = enErken + bek1;
      final kaydir = binis - binisSat[sutun1];

      // ── TUR 1: hattin tum duraklarina varis ──
      for (final x in hat1Duraklar) {
        if (x.durakId == o.id) continue;
        // ⚠️⚠️ SUTUN UZUNLUGU KAPISI (bkz. `_seferBul` serhi).
        if (x.kalkislar.length != binisSat.length) continue;
        // ⚠️ TURU 159 - ayni gun kaymasi (bkz. `kaydir`).
        final inis1 = x.kalkislar[sutun1] + kaydir;
        if (inis1 <= binis || inis1 - binis > 180) continue;
        final aktD = durakM[x.durakId];
        if (aktD == null) continue;

        // ── AKTARMA NOKTALARI: DURAGIN KENDISI + 150 m komsulari ──
        // ⚠️⚠️ Komsular IZGARADAN gelir. Duz tarama olsaydi her x icin
        //	2032 durak olculur, tek aramada MILYONLARCA mesafe hesabi
        //	cikar ve 200 ms butcesi KATLANARAK asilirdi.
        // ⚠️ Duragin KENDISI bastadir (aktarmalarin %36'si ayni durakta).
        final aktarmaNoktalari = <({Durak d, double m})>[
          (d: aktD, m: 0.0),
          ...?komsu[aktD.id],
        ];
        for (final k in aktarmaNoktalari) {
          final y = k.d;
          final yurM = k.m;
          final yurDk = yurM == 0 ? 0 : _yurumeDakikasi(yurM);
          final hazir = inis1 + kAktarmaTampon + yurDk;

          // ── TUR 2 ──
          for (final dh in durakHat[y.id] ?? const <DurakHatti>[]) {
            if (dh.hat.id == oh.hat.id) continue; // ayni hat aktarma DEGIL
            final anahtar2 = '${dh.hat.id}|${dh.yon}';
            final hat2Duraklar = indeks[anahtar2];
            if (hat2Duraklar == null) continue;
            // ⚠️⚠️⚠️ TURU 157 - **HEDEF KESITI ONBELLEKLI.**
            //	Ic dongu hattin TUM duraklarini tariyor ama yalnizca
            //	`hedef` tablosunda olanlar ise yariyor. Kesit hat|yon
            //	basina BIR KEZ hesaplanir.
            // ⚠️⚠️ **OLCULDU (Dart AOT, gercek GTFS):** ic dongu
            //	9.804.508 -> **69.114** islem, arama 234,5 -> **42,4 ms**;
            //	uretilen aday sayisi UC senaryoda da **BIREBIR AYNI**
            //	(310/626/106). Yani bu bir HIZLANDIRMA, davranis
            //	degisikligi DEGIL.
            final hedefliDuraklar = kesit[anahtar2] ??= [
              for (final q in hat2Duraklar)
                if (hedef.containsKey(q.durakId)) q,
            ];
            if (hedefliDuraklar.isEmpty) continue;
            // ⚠️⚠️ TURU 159 - gece sarmasi (bkz. `_seferBul` serhi).
            //	IKINCI otobus bacagi da AYNI tabani kullanmali.
            var sutun2 = -1;
            var bek2 = 1 << 30;
            for (var j = 0; j < dh.kalkislar.length; j++) {
              final b = ((dh.kalkislar[j] - hazir) % 1440 + 1440) % 1440;
              if (b < bek2) {
                bek2 = b;
                sutun2 = j;
              }
            }
            if (sutun2 < 0) continue;
            final binis2 = hazir + bek2;
            final kaydir2 = binis2 - dh.kalkislar[sutun2];

            for (final z in hedefliDuraklar) {
              final d = hedef[z.durakId];
              if (d == null || d.id == y.id) continue;
              if (z.kalkislar.length != dh.kalkislar.length) continue;
              // ⚠️ TURU 159 - ayni gun kaymasi (bkz. `kaydir2`).
              final inis2 = z.kalkislar[sutun2] + kaydir2;
              if (inis2 <= binis2 || inis2 - binis2 > 180) continue;

              final dM = UlasimVeri.kabaMetre(
                  varisEnlem, varisBoylam, d.enlem, d.boylam);
              final dDk = _yurumeDakikasi(dM);
              final varis = inis2 + dDk;
              if (varis - suAn > kToplamSureTavani) continue;

              // ⚠️⚠️⚠️ TURU 157 - **HAT CIFTI BASINA EN ERKEN VARAN.**
              //
              //	Ilk yazimda `if (!gorulen.add(ck)) continue;` vardi:
              //	bir hat cifti icin **ILK RASTLANAN** kombinasyon
              //	kilitleniyor, digerleri HIC uretilmiyordu. Duraklar
              //	mesafeye gore siralandigi icin ilk bulunan EN YAKIN
              //	duraktir, **EN ERKEN VARAN degil**.
              //
              // ⚠️⚠️ **OLCULDU:** aktarma sonuclarinin **%38-43**'unde en
              //	ustteki rota, TAM AYNI iki hatti kullanan daha erken
              //	varan bir yolculuktan **6-123 dakika** daha gec
              //	variyordu. Rota GECERLIYDI, sadece gereksiz yere kotu:
              //	kullanici 8 dakikalik aktarma cezasini BOSUNA odemis
              //	oluyordu. Aktarmasiz cozumun olmadigi %61'lik dilimde
              //	bu dogrudan kullanicinin gordugu ILK sonuctur.
              // ⚠️⚠️ Anahtara **YON de girer**: ayni hattin iki yonu farkli
              //	yolculuklardir.
              // ⚠️ Pahali insa (`yolAl` + `_guzergahDilimi`) donguden CIKTI;
              //    yalniz KAZANANLAR icin bir kez kosar, yani maliyet DUSER.
              final ck =
                  '${oh.hat.id}|${oh.yon}|${dh.hat.id}|${dh.yon}';
              final mevcut = enIyi[ck];
              if (mevcut != null && mevcut.varis <= varis) continue;
              enIyi[ck] = (
                o: o,
                oh: oh,
                binis: binis,
                oDk: oDk,
                oM: oM,
                enErken: enErken,
                aktD: aktD,
                inis1: inis1,
                y: y,
                yurM: yurM,
                yurDk: yurDk,
                hazir: hazir,
                dh: dh,
                binis2: binis2,
                d: d,
                inis2: inis2,
                dM: dM,
                dDk: dDk,
                varis: varis,
                i1Kalkis: x.kalkislar,
                i2Kalkis: z.kalkislar,
              );
            }
          }
        }
      }
    }
  }
  // ⚠️⚠️ **KAZANANLARI SIMDI INSA ET.** `yolAl` hat|yon basina
  //	onbellekli oldugu icin bu dongu polyline'lari YENIDEN cozmez.
  for (final k in enIyi.values) {
    final yol1 = await yolAl(k.oh.hat.id, k.oh.yon);
    final yol2 = await yolAl(k.dh.hat.id, k.dh.yon);
    sonuc.add(RotaAdayi(
      sefer: SeferKaydi(
        b1: k.oh.kalkislar,
        i1: k.i1Kalkis,
        yurDk: k.yurDk,
        b2: k.dh.kalkislar,
        i2: k.i2Kalkis,
      ),
      hat: k.oh.hat,
      varisDakika: k.varis,
      toplamDakika: k.varis - suAn,
      yurumeDakika: k.oDk + k.yurDk + k.dDk,
      aktarma: 1,
      bacaklar: [
        RotaBacagi(
          tur: BacakTuru.yuru,
          noktalar: [
            (enlem: baslangicEnlem, boylam: baslangicBoylam),
            (enlem: k.o.enlem, boylam: k.o.boylam),
          ],
          dakika: k.oDk,
          metre: k.oM,
          baslik: '${k.o.ad} durağına yürü',
          altBaslik: '${k.oM.round()} m · yaklaşık',
          eylem: 'Durağa kadar yürüyün',
          yer: k.o.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.bekle,
          noktalar: const [],
          dakika: math.max(0, k.binis - k.enErken),
          // ⚠️ TURU 158b - imlec bunu TURETMEZ, OKUR.
          kalkisDakika: k.binis,
          baslik: '${UlasimVeri.saatMetni(k.binis)} kalkış',
          altBaslik: k.o.ad,
          hat: k.oh.hat,
          eylem: '${UlasimVeri.saatMetni(k.binis)} kalkışını bekleyin',
          yer: k.o.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.otobus,
          noktalar: _guzergahDilimi(yol1, k.o, k.aktD),
          dakika: k.inis1 - k.binis,
          baslik: '${k.aktD.ad} durağında in',
          altBaslik: k.oh.hat.yonBaslik[k.oh.yon] ?? k.oh.hat.uzunAd,
          hat: k.oh.hat,
          eylem: '${k.oh.hat.kisaAd} ile gidin, inin:',
          yer: k.aktD.ad,
        ),
        // ⚠️⚠️⚠️ TURU 157 - **IKI GERCEK NOKTA** (denetim bulgusu).
        //	Ilk yazimda `noktalar: const []` idi ve UC ZARARI vardi:
        //	  · `_cizgiler` `length < 2` bacaklari ATLADIGI icin 1.
        //	    otobusun bittigi yer ile 2. otobusun basladigi yer
        //	    arasinda **0-150 m CIZGISIZ BOSLUK** kaliyordu - yani
        //	    turu 157'yi baslatan *"bazen boyle KOPMALAR
        //	    yasanabiliyor"* sikayetinin YENI BIR ORNEGI. Ikinci
        //	    otobusun TURKUAZ olmasi boslugu daha da gorunur yapardi.
        //	  · `ilerlet` bos bacaklari ATLADIGI icin "Aktarma icin
        //	    yuruyun" adimi takipte HIC AKTIF OLMUYOR; kullanici
        //	    inince kart aninda ikinci otobusu gosteriyordu.
        //	  · `_adimaGit` kamerayi o adima TASIYAMIYORDU.
        // ⚠️⚠️ Kota `aktarmaYurumesi` bayragiyla korunur (o serhe bak):
        //	gercek noktalar Google Routes cagrisi URETMEZ.
        if (k.y.id != k.aktD.id)
          RotaBacagi(
            tur: BacakTuru.yuru,
            noktalar: [
              (enlem: k.aktD.enlem, boylam: k.aktD.boylam),
              (enlem: k.y.enlem, boylam: k.y.boylam),
            ],
            dakika: k.yurDk,
            metre: k.yurM,
            baslik: '${k.y.ad} durağına yürü',
            altBaslik: '${k.yurM.round()} m · aktarma',
            eylem: 'Aktarma için yürüyün',
            yer: k.y.ad,
            aktarmaYurumesi: true,
          ),
        RotaBacagi(
          tur: BacakTuru.bekle,
          // ⚠️⚠️⚠️ TURU 158b - **TAMPON BEKLEMEYE EMANET** (denetim).
          //
          //	`kAktarmaTampon` (2 dk) hicbir bacaga yazilmiyordu:
          //	bacaklarin toplami `toplamDakika`dan **2 dk EKSIK**
          //	kaliyor ve ozet karti ile adim listesi birbirini
          //	yalanliyordu. Tampon fiziksel olarak BEKLEMEDE gecen
          //	suredir; oraya yazilmasi en dogru yer.
          // ⚠️ Kalkis ve varis saatleri DEGISMEZ — tampon yalnizca
          //    gorunen bekleme suresine dahil olur.
          dakika: math.max(0, k.binis2 - (k.hazir - kAktarmaTampon)),
          noktalar: const [],
          // ⚠️ TURU 158b - imlec bunu TURETMEZ, OKUR.
          kalkisDakika: k.binis2,
          baslik: '${UlasimVeri.saatMetni(k.binis2)} kalkış',
          altBaslik: k.y.ad,
          hat: k.dh.hat,
          eylem: '${UlasimVeri.saatMetni(k.binis2)} kalkışını bekleyin',
          yer: k.y.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.otobus,
          noktalar: _guzergahDilimi(yol2, k.y, k.d),
          dakika: k.inis2 - k.binis2,
          baslik: '${k.d.ad} durağında in',
          altBaslik: k.dh.hat.yonBaslik[k.dh.yon] ?? k.dh.hat.uzunAd,
          hat: k.dh.hat,
          eylem: '${k.dh.hat.kisaAd} ile gidin, inin:',
          yer: k.d.ad,
        ),
        RotaBacagi(
          tur: BacakTuru.yuru,
          noktalar: [
            (enlem: k.d.enlem, boylam: k.d.boylam),
            (enlem: varisEnlem, boylam: varisBoylam),
          ],
          dakika: k.dDk,
          metre: k.dM,
          baslik: 'Varışa yürü',
          altBaslik: '${k.dM.round()} m · yaklaşık',
          eylem: 'Varışa kadar yürüyün',
          yer: varisAd.isEmpty ? 'Varış' : varisAd,
        ),
      ],
    ));
  }
  return sonuc;
}

/// ⚠️⚠️⚠️ TURU 158 - **ZENGINLESTIRMEDEN SONRA SEFERI YENIDEN SEC.**
///
///	Sefer secimi KUS UCUSU yurume tahminiyle yapiliyor; gercek yol
///	agiyla yurume **~1,74 kat** uzayabiliyor (ekrandan olculdu).
///	Turu 158 yurume sayilarini gercege cevirdi, ama sefer secimi
///	ESKI tahminde kaldigi icin ekran **"9 dk yuru" deyip fiziksel
///	olarak yetisilemeyecek bir kalkis** onerebiliyordu: sessizce
///	iyimser bir plan, ACIKCA imkansiz bir plana donusuyordu.
///
/// ⚠️⚠️ **TAMAMEN YEREL**: kalkis sutunlari zaten bellekte, EK AG ISTEGI
///	YOK (turu 152 kota dersi).
/// ⚠️⚠️ Aktarmalida ZINCIRLEME var: 1. bacagin binisi ilerleyince inis
///	de ilerler ve 2. sefer gecersiz kalabilir -> aday DUSER.
/// ⚠️⚠️ `kToplamSureTavani` YENIDEN uygulanir; yoksa varis kaymasiyla
///	saatlerce suren bir rota birinci sirada kalabilir (turu 157).
/// ⚠️ `RotaAdayi` alanlari `final`: yerinde guncellenemez, YENI nesne
///    kurulup listeye yazilir. `bacaklar` listesi mutable oldugu icin
///    bacaklar yerinde degistirilebilir.
void _seferleriYenidenSec(List<RotaAdayi> sonuc, int suAn) {
  final kalanlar = <RotaAdayi>[];
  for (final a in sonuc) {
    final s = a.sefer;
    if (s == null) {
      kalanlar.add(a);
      continue;
    }
    final bacaklar = a.bacaklar;
    // Bacak duzeni: [yuru, bekle, otobus, (yuru), (bekle), (otobus), yuru]
    final ilkYuru = bacaklar.first;
    final sonYuru = bacaklar.last;
    if (ilkYuru.tur != BacakTuru.yuru || sonYuru.tur != BacakTuru.yuru) {
      kalanlar.add(a);
      continue;
    }
    final oDk = ilkYuru.dakika;
    final dDk = sonYuru.dakika;
    final enErken = suAn + oDk;
    final sf1 = _seferBul(s.b1, s.i1, enErken);
    // ⚠️⚠️ Yetisilemiyorsa aday DUSER: yanlis bir plani ekranda
    //	birakmaktansa gostermemek dogrudur.
    if (sf1 == null) continue;

    int varis;
    int? binis2;
    int? inis2;
    if (s.b2 != null && s.i2 != null) {
      final hazir = sf1.inis + kAktarmaTampon + (s.yurDk ?? 0);
      final sf2 = _seferBul(s.b2!, s.i2!, hazir);
      if (sf2 == null) continue;
      binis2 = sf2.binis;
      inis2 = sf2.inis;
      varis = sf2.inis + dDk;
    } else {
      varis = sf1.inis + dDk;
    }
    if (varis - suAn > kToplamSureTavani) continue;

    // ── BACAKLARI YENI SAATLERLE GUNCELLE ──
    var otobusSay = 0;
    var bekleSay = 0;
    for (var i = 0; i < bacaklar.length; i++) {
      final b = bacaklar[i];
      if (b.tur == BacakTuru.bekle) {
        final ilk = bekleSay++ == 0;
        final kalkis = ilk ? sf1.binis : (binis2 ?? sf1.binis);
        // ⚠️ TURU 158b - tampon BEKLEMEYE dahil (bkz. `_aktarmaliAra`
        //    icindeki ayni serh); iki kopya DRIFT ETMESIN diye ayni formul.
        final oncesi = ilk ? enErken : sf1.inis + (s.yurDk ?? 0);
        bacaklar[i] = RotaBacagi(
          tur: BacakTuru.bekle,
          noktalar: const [],
          dakika: math.max(0, kalkis - oncesi),
          // ⚠️ TURU 158b - imlec bunu TURETMEZ, OKUR (yeniden secimde de).
          kalkisDakika: kalkis,
          baslik: '${UlasimVeri.saatMetni(kalkis)} kalkış',
          altBaslik: b.altBaslik,
          hat: b.hat,
          eylem: '${UlasimVeri.saatMetni(kalkis)} kalkışını bekleyin',
          yer: b.yer,
        );
      } else if (b.tur == BacakTuru.otobus) {
        final ilk = otobusSay++ == 0;
        final dk = ilk
            ? sf1.inis - sf1.binis
            : (inis2 ?? sf1.inis) - (binis2 ?? sf1.binis);
        bacaklar[i] = RotaBacagi(
          tur: BacakTuru.otobus,
          noktalar: b.noktalar,
          dakika: math.max(1, dk),
          baslik: b.baslik,
          altBaslik: b.altBaslik,
          hat: b.hat,
          eylem: b.eylem,
          yer: b.yer,
        );
      }
    }

    var yurume = 0;
    for (final b in bacaklar) {
      if (b.tur == BacakTuru.yuru) yurume += b.dakika;
    }
    kalanlar.add(RotaAdayi(
      sefer: s,
      hat: a.hat,
      bacaklar: bacaklar,
      varisDakika: varis,
      toplamDakika: varis - suAn,
      yurumeDakika: yurume,
      aktarma: a.aktarma,
    ));
  }
  // ⚠️ Varis saatleri degistigi icin siralama YENIDEN yapilir
  //    (ayni ceza kurali).
  kalanlar.sort((x, y) => (x.varisDakika + x.aktarma * kAktarmaCezasi)
      .compareTo(y.varisDakika + y.aktarma * kAktarmaCezasi));
  sonuc
    ..clear()
    ..addAll(kalanlar);
}
/// Kazanan adaylarin YURUME bacaklarini gercek yol agi cizgisiyle degistirir.
///
/// ⚠️ Rota alinamazsa bacak **DOKUNULMADAN** kalir (kus ucusu duz cizgi):
///    ag yoksa ya da `GOOGLE_SERVIS_KEY` tanimli degilse ozellik COKMEZ,
///    yalnizca kabalasir.
/// ⚠️ `RotaBacagi` DEGISMEZ (immutable) oldugu icin bacak YERINDE
///    degistirilemez; yeni bacak kurulup listeye YAZILIR.
// ⚠️ TURU 158 — ucler ARTIK PARAMETREDEN GELMIYOR: govde onlari
//    `b.noktalar.first/.last`ten okuyor ve dort parametre SIFIR kez
//    kullaniliyordu (olu parametre).
Future<void> _yurumeleriZenginlestir(List<RotaAdayi> adaylar) async {
  final isler = <Future<void>>[];
  for (final a in adaylar) {
    for (var i = 0; i < a.bacaklar.length; i++) {
      final b = a.bacaklar[i];
      // ⚠️⚠️ TURU 157 - aktarma yurumesi ZENGINLESTIRILMEZ (kota).
      //	Bkz. `RotaBacagi.aktarmaYurumesi` serhi.
      if (b.tur != BacakTuru.yuru ||
          b.noktalar.length != 2 ||
          b.aktarmaYurumesi) {
        continue;
      }
      final bas = b.noktalar.first;
      final var_ = b.noktalar.last;
      final sira = i;
      isler.add(() async {
        // ⚠️⚠️⚠️ TURU 157 - **KORUMA SERHTE VARDI, GOVDEDE YOKTU.**
        //
        //	Fonksiyonun serhi *"Rota alinamazsa bacak DOKUNULMADAN
        //	kalir ... ozellik COKMEZ, yalnizca kabalasir"* diyordu
        //	ama govdede **hicbir `try` yoktu**: `AdresServisi.i` ya da
        //	`yayaRotasi` firlatirsa hata `Future.wait`e, oradan
        //	`rotaAra`ya cikiyor ve **TUM ROTA ARAMASI COKUYORDU** -
        //	kullanici yalniz kabalasmis degil, HIC sonuc gormuyordu.
        //
        // ⚠️⚠️ **OLCUMDE YAKALANDI**: turu 157 aktarma olcum testinde
        //	`AdresServisi.i` -> `Geocoding()` eklenti kanali olmadigi
        //	icin *"Null check operator used on a null value"* firlatti
        //	ve `rotaAra` komple dustu. Sahada ayni sey eklenti
        //	baslatilamadiginda ya da beklenmedik bir yanit bicimide olur.
        // ⚠️ Bu projenin en sik hata sinifi: serhin anlattigi kontrolun
        //    govdede GERCEKTEN olup olmadigini dogrula.
        ({
          List<({double enlem, double boylam})> noktalar,
          int? mesafeM,
          int? sureSn,
        })? yanit;
        try {
          yanit = await AdresServisi.i.yayaRotasi(
              bas.enlem, bas.boylam, var_.enlem, var_.boylam);
        } catch (_) {
          return; // bacak DOKUNULMADAN kalir: kus ucusu duz cizgi
        }
        if (yanit == null || yanit.noktalar.length < 2) return;
        final yol = yanit.noktalar;
        // ⚠️⚠️⚠️ TURU 158 - **MESAFE VE SURE DE GUNCELLENIR.**
        //	Onceden yalniz `noktalar` degistiriliyor, `metre`/`dakika`
        //	ise `b.metre`/`b.dakika` ile KUS UCUSU degerinden
        //	kopyalaniyordu. Sonuc: ozet "5 dk" derken adim ekrani
        //	"9 dk · 677 m" diyordu (ekrandan olculen oran ~1,74).
        // ⚠️ Sunucu vermezse polyline uzunlugundan hesaplanir - yine
        //    de KUS UCUSUNDAN dogru.
        // ⚠️⚠️⚠️ TURU 158b - **OLCU, CIZILEN VE TAKIP EDILEN YOLUN
        //	KENDISINDEN ALINIR** (yayin oncesi denetim; YUKSEK).
        //
        //	Onceki hal sunucunun `mesafe_m` degerini kullaniyordu; o deger
        //	YALNIZ YOLA SNAP EDILMIS polyline'i olcer. Takip ekranindaki
        //	her sayi (`d.kalanM`, `_bacakDakika`, `_bacakOrani`) ise
        //	`_uclariBagla` ile GERCEK baslangic/varis noktalari EKLENMIS
        //	polyline'i olcer. Sonuc: ozet "5 dk · 390 m" derken kullanici
        //	TEK ADIM ATMADAN adim kartinda "6 dk · 445 m kaldi" goruyordu —
        //	turun MANSET sikayetinin (ozet 5 / adim 9) kucultulmus hali.
        // ⚠️ `mesafe_m` artik YEDEK bile degil: bagli yolun uzunlugu her
        //    zaman hesaplanabilir ve TEK KAYNAK olmasi sarttir.
        final bagli = _uclariBagla(yol, bas, var_);
        final gercekM = _yolUzunlugu(bagli);
        // ⚠️⚠️⚠️ TURU 158 - **SURE `sure_sn`DEN DEGIL, `kYayaHizi`DEN.**
        //	Sunucu `sure_sn` donduruyor ve tipte KALIYOR (ileride
        //	gerekebilir) ama BURADA KULLANILMIYOR.
        // ⚠️⚠️ **SEBEP: `_bacakDakika` (adim karti) sureyi HER ZAMAN
        //	`d.kalanM / kYayaHizi` ile YENIDEN hesapliyor.** `sure_sn`
        //	kullanilsaydi ozet Google'in hiz modelinden 8 dk, adim
        //	karti bizim modelimizden 9 dk der ve kullanicinin
        //	sikayet ettigi CELISKI KAPANMAZ, yalnizca kucululurdu.
        // ⚠️ `kYayaHizi` serhi zaten "TEK KAYNAK" diyor; iki hiz
        //    modelini ayni ekranda kullanmak onu ihlal ederdi.
        final gercekDk = _yurumeDakikasi(gercekM);
        a.bacaklar[sira] = RotaBacagi(
          tur: b.tur,
          // ⚠️ TURU 158b - olcu ile cizgi AYNI liste (tek kaynak).
          noktalar: bagli,
          dakika: gercekDk,
          baslik: b.baslik,
          // ⚠️⚠️ TURU 158 - alt satir da GERCEK olcumden.
          //	Onceden `b.altBaslik` ("390 m · yaklaşık") kopyalaniyordu
          //	ve ayni satirda "9 dk" ile yan yana duruyordu —
          //	ceil(390/1,3/60) = 5, yani sayilar birbirini YALANLIYORDU.
          // ⚠️ "· yaklaşık" ibaresi BURADAN kalkti (artik TAHMIN degil
          //    OLCUM). Zenginlestirilemeyen dalda bacak DOKUNULMADAN kalir
          //    ve orada ibare KALIR — iki dal AYRIDIR.
          // ⚠️⚠️ TURU 158b - **HAM METRE DEGIL** (denetim): turu 155
          //	"15240 m kaldı" hatasini duzeltmisti, turu 158 bu dalda
          //	onu geri getirmisti. Bicim TEK KAYNAKTAN.
          altBaslik: UlasimVeri.mesafeMetni(gercekM),
          hat: b.hat,
          metre: gercekM,
          // ⚠️⚠️ TURU 156 — YENI ALANLAR DA KOPYALANMALI. Unutulsaydi
          //	yaya rotasi ZENGINLESTIRILEN bacaklarda (yani tam da
          //	kullanicinin gordugu yurume adimlarinda) eylem/yer BOS
          //	kalir ve adim karti SESSIZCE bosalirdi.
          eylem: b.eylem,
          yer: b.yer,
          aktarmaYurumesi: b.aktarmaYurumesi,
        );
      }());
    }
  }
  await Future.wait(isler);
}

/// ⚠️⚠️⚠️ TURU 155 — **GERCEK UCLARI CIZGIYE GERI EKLER.**
///
///	Kullanici sahada gordu: *"rota cizdiginde mesela EVDEN DISARIYA
///	shape cizmiyor"* + *"Yandex'te kesikler TAM YOLUN ICINDE, yurume
///	biterken otobus duraginda bitiyor; BIZIMKI DIREK USTUNDE"*.
///
/// ⚠️⚠️ **KOK NEDEN: Google Routes uclari YOLA SNAP EDER.** Donen
///	polyline kullanicinin GERCEK koordinatindan degil, ona en yakin
///	YOL noktasindan baslar; duragin da tam ustunde bitmez. Aradaki
///	boslukta HICBIR SEY cizilmedigi icin cizgi "evden cikmiyor" ve
///	duraga "degmiyor" gorunuyordu.
///
///	Yandex ve Google Maps de ayni seyi yapar: gercek konumdan yola
///	KISA BIR BAGLAYICI cizerler. Burada da uclar cizginin basina/
///	sonuna geri konuyor.
///
/// ⚠️⚠️⚠️ TURU 157 - **ESIK 5 m -> 0,5 m** (kullanici sahada gordu:
///	*"bazen boyle KOPMALAR yasanabiliyor, bu normal mi?"*).
///
///	**OLCULDU (kullanicinin ekran goruntusunden):** yurume bacagi
///	"43 m" kalmisti ve ekranda ~913 px yer kapliyordu, yani
///	**~21 piksel/metre**. Yurume cizgisinin ucu ile durak pini
///	arasindaki bosluk ~83 px = **~4 metre**.
///
/// ⚠️⚠️ **KOK NEDEN: esigin KENDISI.** Google Routes ucu yola SNAP
///	eder; durak yolun kenarindaysa snap mesafesi 5 m'nin ALTINDA
///	kalir, kosul saglanmaz ve gercek uc EKLENMEZ. Cizgi duraga
///	4 metre uzakta biter. Sehir olceginde (z13-15) bu 1-2 piksel
///	olur ve GORUNMEZ; **navigasyon zoomunda (z19-20) 80+ piksel
///	olur ve APACIK bir kopma gibi durur**.
/// ⚠️⚠️ Yani esik SABIT METRE, gorulen bosluk ise ZOOM'A BAGLI —
///	ikisi ayni birimde olmadigi icin 5 m "kucuk" sanilmisti.
///
/// ⚠️ 0,5 m: tek amaci AYNI noktayi iki kez eklememek. Ayni koordinat
///    iki kez girse bile zarari YOK (`yapistir` sifir uzunluklu segmenti
///    `l2 > 0` kapisiyla atliyor) - yani esik guvenli tarafta KUCUK olmali.
/// ⚠️⚠️ YAPMA: esigi tekrar buyutme. "Gereksiz dugum" korkusu olculdu:
///	en fazla IKI fazladan nokta, cizim maliyeti SIFIRA yakin.
/// ⚠️ Otobus bacaginda bu GEREKMEZ: `_guzergahDilimi` binis ve inis
///    duraklarini ZATEN basa/sona koyuyor (bkz. o fonksiyon).
List<({double enlem, double boylam})> _uclariBagla(
  List<({double enlem, double boylam})> yol,
  ({double enlem, double boylam}) bas,
  ({double enlem, double boylam}) varis,
) {
  const esik = kUcEsikM;
  final ilk = yol.first;
  final son = yol.last;
  return [
    if (UlasimVeri.kabaMetre(bas.enlem, bas.boylam, ilk.enlem, ilk.boylam) >
        esik)
      bas,
    ...yol,
    if (UlasimVeri.kabaMetre(
            varis.enlem, varis.boylam, son.enlem, son.boylam) >
        esik)
      varis,
  ];
}
