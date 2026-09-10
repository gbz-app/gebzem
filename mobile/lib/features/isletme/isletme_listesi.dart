import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/konum_servisi.dart';
import '../../core/theme.dart';
import '../../core/api.dart';
import "../../core/yenile.dart";

import '../home/home_screen.dart' show myProfileProvider;
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_basligi.dart' show kOnayliRengi;
import '../sosyal/profil_sayfasi.dart';
import 'favorilerim_ekrani.dart';
import 'isletme_filtre.dart';
import 'isletme_kart.dart';
import '../home/alt_menu.dart';
import '../home/home_screen.dart' show aktifSekme;
import 'isletme_servisi.dart';
import 'konum_secici.dart';
import 'kategori_slider.dart';
import 'yakinimda_ekrani.dart';

/// ⚠️⚠️ TURU 77 — ISLETME REHBERI.
///
/// ⚠️⚠️ BU EKRAN, HAMBURGER MENUDEKI KARTLARIN GITTIGI YERDIR.
///    Turu 76b'de Yemek / Restoran / Alisveris kartlari HICBIR YERE gitmiyordu
///    ("yakında" diyordu) — bu projede tekrar eden "olu dogmus ozellik"
///    sinifiydi. Artik gercek bir listeye baglaniyor.
///
// ⚠️ `kYanBosluk` `isletme_kart.dart`a TASINDI: slider da ayni sabiti
//    kullanmak ZORUNDA (peek orani ondan turuyor) ve bu dosyayi import
//    etmesi dongu olurdu.

/// ⚠️⚠️⚠️ TURU 95 — **DIKEY RITIM: TEK KAYNAK.**
///
///	Kullanici: *"slider inputa yapismis; bu bosluklari yukari, sol, sag
///	guzel bir mimari yap, olculeri duzgun yap"*. HAKLIYDI ve sebebi
///	yapisaldi: dikey bosluklar BES AYRI YERDE, birbirinden habersiz
///	sayilarla yaziliydi —
///	  slider  : hic ust dolgu yok
///	  60x60   : icinde `fromLTRB(.., 12, ..)`
///	  arama   : icinde `fromLTRB(.., 4, ..)`
///	  filtre  : icinde `fromLTRB(.., 10, ..)`
///	  liste   : `fromLTRB(.., 6, ..)`
///	Yani iki oge arasindaki mesafe, o iki ogeden BIRININ ic dolgusuydu;
///	sirayi degistirince (input yukari/asagi) bosluk da rastgele degisiyor
///	ve "yapismis" gorunuyordu.
///
///	YENI KURAL: bolumlerin IC DIKEY DOLGUSU YOKTUR. Aralarindaki mesafe
///	YALNIZCA asagidaki sabitle, sliver sirasinda verilir.
/// ⚠️ YAPMA: bu ekrandaki bir bolume tekrar ust/alt dolgu yazma; mesafeyi
///    sliver arasina koy.
///
/// ⚠️⚠️⚠️ TURU 96 — **UC SABIT TEKE INDI** (kullanici emri: *"slider
///	altindaki kategori arasindaki boslugu 2px arttir ve BUTUN SATIRLAR
///	AYNI BOSLUK olsun; yani slider, altindaki kartlar, onlarin altindaki
///	input arasindaki bosluk HEPSI ESIT olmali"*).
///
///	Turu 95'te ritim uc kademeye (10/14/18) ayrilmisti; niyet "gorsel
///	agirlikli bloktan sonra daha genis nefes" idi. Ekranda sonuc AYRI
///	gorunuyordu: bes bolum arasinda UC FARKLI mesafe olunca goz duzenli
///	bir izgara DEGIL, rastgele araliklar goruyordu.
///	Artik **TEK deger: 16** (14 + kullanicinin istedigi 2).
/// ⚠️ YAPMA: buraya ikinci bir bosluk sabiti ekleme; bir bolum icin
///    "biraz daha genis olsun" diye ozel sayi yazma.
const double kBosluk = 16;

/// ⚠️⚠️⚠️ TURU 96 — ARAMA SATIRININ **TEK YUKSEKLIGI** (kullanici emri:
///	*"input ve sagdaki daireler AYNI YUKSEKLIKTE olacak"*).
///
///	Eskiden input yuksekligi DOLAYLIYDI: `contentPadding` 14+14 ustune
///	temanin yazi yuksekligi (M3 `bodyLarge` = 16px x 1.5 = 24) binince
///	**~52px** cikiyordu; yanindaki daireler ise elle 48 yazilmisti. Yani
///	iki komsu oge, birbirinden habersiz iki AYRI yoldan olculuyordu ve
///	kullanicinin gordugu 4px'lik kayma bundan geliyordu.
///
///	Artik ikisi de bu sabitten besleniyor ve input yuksekligi ACIKCA
///	dayatiliyor (`SizedBox`) — yani yazi tipi/tema degisse bile kayamaz.
/// ⚠️ Yaricap buradan TUREMEZ: ekrandaki her oge `kYaricap` kullanir.
/// ⚠️ YAPMA: daire ya da input yuksekligini elle yazma.
const double kInputBoy = 48;

/// ⚠️⚠️⚠️ TURU 96 — ALT KATEGORI KARTININ IKI OLCUSU **ACIKCA** (kullanici
///	emri: *"kartlar vb. bunlar ayni hizada degil; slider vs. HEPSI ayni
///	hizada olmali"*).
///
///	SORUNUN KOKU: gorsel kutu 60, hucre 78 ve kutu hucrenin ORTASINDA.
///	Serit `kYanBosluk`(16) dolguyla cizilince ILK KUTUNUN sol kenari
///	16 + (78-60)/2 = **25**'te basliyordu; slider, arama kutusu ve liste
///	ise 16'da. Yani kod "ayni yan bosluk" veriyordu ama EKRANDA 9px kayma
///	vardi — kullanicinin gordugu tam buydu.
///
///	FIX: seridin dolgusu `kYanBosluk - kAltIcBosluk` olur; boylece ILK
///	KUTUNUN sol kenari tam 16, SON KUTUNUN sag kenari tam `genislik-16`.
/// ⚠️ Serit YATAY KAYDIGI icin bu kucultulmus dolgu gorunmez (kaydirma
///    payidir, gorsel hiza degil).
/// ⚠️ YAPMA: bu ikisinden birini degistirip otekini birakma; hiza
///    `kAltIcBosluk` uzerinden TURETILIYOR.
/// Kesif kartlari (4 x 2) — bkz. `_kesifIzgarasi`.
/// ⚠️ TURU 96c — 60 -> **78** (kullanici emri: *"kartin yuksekligini
///    arttir"*). Kutu ICI BOS oldugu icin (ikonlar kaldirildi) alcak bir
///    kutu "yer tutucu" gibi duruyordu.
/// ⚠️ Kutu yuksekligi SABIT, genislik EKRANDAN turer: dorduncu kart dar
///    telefonda tasmasin.
const double kKesifKutu = 78;
/// ⚠️⚠️⚠️ TURU 96k — **BOSLUK OLCEGI: 8 · 12 · 16.**
///
///	Kullanici sordu: *"hepsinin arasindaki esitlik ayni olmali mi?"*
///	CEVAP HAYIR — hepsi esit olsaydi bir BASLIK, kendi kartlarina tam da
///	ustundeki bolume oldugu kadar uzak dururdu ve goz neyin neye ait
///	oldugunu ayirt edemezdi (yakinlik ilkesi). Dogru olan TEK SAYI degil,
///	UC KADEMELI bir olcektir:
///
///	  `kBaslikBosluk` **8**  — baslik ↔ KENDI kartlari (en sıkı bag)
///	  `kIzgaraAralik` **12** — ayni izgaranin kartlari arasi
///	  `kBosluk`       **16** — BOLUMLER arasi (sayfa ritmi)
///
/// ⚠️ Bu uc sayi disinda bu ekrana elle bir dikey bosluk YAZMA; biri
///    guncellenip otekiler unutuldugunda ritim SESSIZCE bozulur.
const double kBaslikBosluk = 8;

/// ⚠️ IZGARA ARALIGI **HER IKI EKSENDE** (turu 96k). Onceden yatay aralik
///    "hucreyi 10 daralt" emrinden TURUYOR (13.3) ve dikey aralik ayrica 12
///    yaziliyordu — ayni izgarada iki farkli sayi. Artik aralik SECILIR,
///    hucre genisligi ondan turetilir.
/// ⚠️ YAPMA: yatay ve dikey icin ayri sabit acma.
const double kIzgaraAralik = 12;

// ⚠️⚠️ TURU 96e — kullanici emri: kutu **+10px** (60 -> 70), kutular arasi
//    bosluk **+2px** (10 -> 12). Aralik hucre ile kutu farkindan turer:
//    hucre 82 - kutu 70 = 12.
const double kAltKutu = 70; // gorsel kutu (kare)
const double kAltHucre = 82; // kutu + altindaki yazi alani
const double kAltIcBosluk = (kAltHucre - kAltKutu) / 2; // = 6

/// ⚠️⚠️⚠️ TURU 180ae — **MUTFAK CIPLERI: FILTRE CIPININ %15 BUYUGU**
///	(kullanici emri: *"filtredeki gibi buton yap, %15 kadar daha buyuk
///	olsun"*).
///
/// Olculer `_hizliCip`ten TURETILIR — elle "yaklasik" sayi YAZILMAZ:
///	  boy   32 x 1.15 x 1.10 = 40.5 -> **41**
///	  yazi  13 x 1.15 x 1.10 = 16.4 -> **16**
///	  dolgu 11 x 1.15 x 1.10 = 13.9 -> **14**
/// ⚠️ IKINCI carpan (1.10) turu 180af kullanici emri: *"bu doner kebap
///	butonlarini %10 daha buyut"*. Carpan ZINCIRI korunur ki bir sonraki
///	istekte "neyin uzerine ne kadar" sorusu cevapsiz kalmasin.
/// ⚠️ `kAltKutu`/`kAltHucre` **DOKUNULMADI**: onlari ilan ve talep ekranlari
///	da okuyor; kullanici yalnizca YEMEK ekranini degistirmek istedi.
/// ⚠️ `kAltCipBoy` bir TABANDIR (alt sinir), sabit yukseklik DEGIL: gercek
///	boy yazi olceginden turetilir (bkz. `_altKategoriSeridi`).
const double kAltCipBoy = 41;
const double kAltCipYazi = 16;
const double kAltCipDolgu = 14;

/// ⚠️⚠️⚠️ TURU 96 — **BOLUMLERIN IC PAYI ARALIKTAN DUSULUR.**
///
/// Iki bolum DOKUNMA ALANI icin kendi icinde bos pay tasiyor:
///	· header  : dokunma 44, gorsel daire 34 -> altta **5** bos
///	· cip serit: serit 40, cip 32          -> altta/ustte **4** bos
/// Bu paylar KALDIRILAMAZ (Material 48 / Apple 44 kurali), ama sliver
/// araligina `kBosluk` yazilirsa EKRANDA gorunen mesafe 21 ve 20 olur —
/// yani kod "hepsi 16" derken goz "hepsi farkli" gorur. Kullanicinin
/// *"butun satirlar ayni bosluk"* emrinin karsiligi: aralik = `kBosluk`
/// EKSI o bolumun ic payi.
/// ⚠️ YAPMA: bir bolumun dokunma alanini kucultup "duzelttim" deme; payi
///    ARALIKTAN dus.
/// ⚠️ TURU 96b — daire kaldirilip ikon 24'e cikinca **5 -> 10** oldu.
///    Pay, dokunma alani ile GORSEL oge arasindaki farkin yarisidir.
const double kHeaderPay = (44 - 24) / 2; // = 10
const double kCipPay = (40 - 32) / 2; // = 4

/// ⚠️⚠️ TURU 136 — FILTRE USTUNDEKI YATAY ISLETME SERIDI (bkz. `_isletmeSeridi`).
///
/// ⚠️ **TAVAN ZORUNLU:** serit LISTENIN AYNISINI tasir; sinir olmasaydi 60
///    kart yan yana kurulur ve her biri bir kapak gorseli COZERDI (turu 91
///    performans dersi: `memCacheWidth`siz bir kapak ~10 MB gecici RAM).
/// ⚠️ Tamami zaten seridin ALTINDAKI listede — serit bir VITRIN, arsiv degil.
const int kSeritTavan = 10;

/// ⚠️ Kart eni; gercek deger ekranin %62'siyle SINIRLANIR (dar telefonda
///    "yandaki kart" ipucu kaybolmasin).
const double kSeritKartEn = 200;

/// ⚠️ Header ikonlarinin GLIF ICI boslugu — ekrandan OLCULDU (bkz. header
///    dolgusu serhi). Ikon degisirse yeniden olc.
const double kNavOptik = 1.6; // navigation (konum dugmesi, olculdu)
const double kKalpOptik = 0.8; // heart

/// ⚠️ Bolum basliklarinin ("Mutfaklar", "İşletmeler (N)") GLIF ICI boslugu.
///    Ikisi de ekrandan 17.1 dp olculdu; kutular 16.0. Metin sabit oldugu
///    icin (bas harfleri degismez) telafi guvenli.
/// ⚠️ Baslik metni degisirse yeniden olc.
const double kBaslikOptik = 1.1;

/// ⚠️⚠️⚠️ TURU 96j — GORUNUM SECICI (liste · kart · harita).
///
///	Kullanici once *"ikonlari minimalist yapar misin, bir tik ustunde de
///	olsun"* dedi; dis kutu kaldirildi ve bu REDDEDILDI:
///	*"ikonlarin ARKASINDA BORDER YOK; hepsi BIR SEYIN ICINDE border olacak,
///	aktif ikon ARKA RENGI olacakti"*.
///	Yani **KUTU KALIR**; sadelestirme ikonun KENDISINDE yapilir.
///
/// ⚠️⚠️⚠️ **KUTU, FILTRE BUTONUYLA AYNI YUKSEKLIKTE** (kullanici emri:
///	*"filtre butonu genislik yuksekliginde olsun, gorunum alani cok
///	buyuk"*).
///
///	Onceki olcu 44x40'lik hucrelerdi ve kutu toplam **48 dp** oluyordu;
///	yanindaki `Filtre` cipi ise **40 dp**. Ayni satirda iki cerceve vardi ve
///	biri otekinden 8 dp daha yuksekti — goz bunu "gorunum alani cok buyuk"
///	diye okuyor.
///
/// ⚠️⚠️⚠️ **OLCUT: CIPIN *GORUNEN* YUKSEKLIGI (32), DOKUNMA ALANI (40)
///	DEGIL.** Bu ayrim ekrandan OLCULEREK bulundu:
///	  Filtre cipi — dugum kutusu **40** dp, GORUNEN murekkep **31.6** dp
///	  (aradaki 8 dp `kCipPay`, yani goze GORUNMEYEN dokunma payi)
///	Ilk denemede kutu 40'a esitlendi ve kullanici HAKLI olarak "hala buyuk"
///	dedi: goz murekkebi kiyasliyor, dokunma alanini DEGIL.
///
/// ⚠️ **HESAP TERSTEN KURULUR** (gorunen yukseklik SABIT hedeftir):
///	  kutu = hucre + kSegDolgu*2 + kenarlik*2
///	  32   = 26    + 2*2         + 1*2          ✔ cipin murekkebiyle BIREBIR
///	`kSegHucreBoy` degistirilirse `kSegDolgu` da yeniden hesaplanmali;
///	ikisi bagimsiz sayilar DEGILDIR (muhafiz bunu zorluyor).
/// ⚠️ HUCRE **KARE** (26x26): kullanici *"genislik yuksekliginde olsun"*
///	dedi. Kutu 140 -> **84 dp**; yanindaki cip 88.8 dp, yani satirdaki iki
///	oge artik ayni agirlikta.
/// ⚠️⚠️ DOKUNMA ALANI 26x26 = Material 48 kuralinin ALTINDA. **BILINCLI
///	TAVIZ**: kullanici alanin kucultulmesini IKI KEZ acikca istedi ve kutu
///	ancak hucre kadar kucultulebiliyor. Zararini sinirlayan sey, uc hedefin
///	YAN YANA ve hepsinin `HitTestBehavior.opaque` olmasi: iska giden dokunus
///	komsu GORUNUME duser (tek dokunusla geri alinir), oluye gitmez.
/// ⚠️ YAPMA: hucreyi daha da kucultme (ikon 16 ve 26'lik hucrede zaten 5 dp
///    pay kaliyor).
/// ⚠️ Aktif gri zemin hucrenin TAMAMINI doldurur: kutu dolgusu (`kSegDolgu`)
///    zaten bosluk veriyor, ikinci bir ic bosluk zemini "yuzen" gosterirdi.
/// ⚠️ Dis kutunun GORUNEN sag kenari `kYanBosluk`ta durur; kutu bir CIZGI
///    oldugu icin glif telafisi (turu 96b `kNavOptik` deseni) GEREKMEZ —
///    kenarlik zaten murekkebin ta kendisidir.
const double kSegHucre = 26; // dokunma alani (genislik) — KARE
const double kSegHucreBoy = 26; // dokunma alani (yukseklik)
const double kSegBoy = 26; // aktif zemin hucreyi doldurur
const double kSegIkon = 16; // GORUNEN ikon (26'lik hucrede optik denge)
const double kSegDolgu = 2; // kutu ile segmentler arasi

/// ⚠️ "Bir tik ustte" — kullanicinin istedigi kaydirma. `Transform` ile
///    uygulanir (yerlesimi DEGISTIRMEZ, bkz. `_listeBasligi`).
const double kSegYukari = 2;

// ⚠️ `kYuzeyGri` `isletme_kart.dart`a TASINDI (tek kaynak): kart ve bu
//    ekran ayni griyi kullanmak ZORUNDA.

/// [kategori] bos ise TUM isletmeler; doluysa o kategori.
/// TURU 174 — **ALT MENU BAYRAGI** (kullanici emri: *"alt menuyu
/// kaldir"*).
///
/// ⚠️ Turu 96l'de kullanici TAM TERSINI istemisti (*"alt menuyu getir,
///	gorunmesi gerekiyor"*). Govde silinmedi, bayrakla kapatildi:
///	karar degisirse tek satir.
const bool kAltMenuAcik = false;

/// Kategori ekraninin zemini — **SABIT SIYAH** (kullanici emri).
///
/// ⚠️⚠️ Renk TEMADAN GELMIYOR ve bu BILINCLI: ekran artik acik/koyu
///	temadan BAGIMSIZ olarak siyah. Ayni ilke menude de var
///	(`kAiZemin`). ⚠️ Bu yuzden ekranin ICINDEKI metinler de
///	temaya birakilamaz — govde zorla KOYU temaya alindi
///	(turu 135c/138/140: yalniz zemini siyah yapmak, uzerine
///	koyu yazi cizip ekrani OKUNMAZ birakir).
// ⚠️ TURU 178 — deger `core/theme.dart`taki `kAiZemin` ile BIREBIR
//    aynidir ve artik ORADAN gelir; iki kopya kacinilmaz olarak
//    ayrisirdi.
const Color kKategoriZemin = kAiZemin;

class IsletmeListesiEkrani extends ConsumerStatefulWidget {
  const IsletmeListesiEkrani({
    super.key,
    this.kategori = '',
    this.baslik = '',
    this.ara = '',
  });

  final String kategori;
  final String baslik;

  /// ⚠️⚠️ TURU 96t — EKRAN ACILIRKEN KUTUYA YAZILACAK ARAMA.
  ///
  ///	Menudeki "Taksi · Akaryakıt · Durak" gibi kartlar bir KATEGORI
  ///	DEGIL bir ARAMA KISAYOLUDUR (turu 92'nin alt-kategori kartlariyla
  ///	ayni desen). Bu alan olmadan o kartlar ya olu olurdu ya da her biri
  ///	icin AYRI EKRAN yazmak gerekirdi.
  /// ⚠️ Kutuya GORUNUR sekilde yazilir: kullanici neyin suzuldugunu gorur
  ///    ve X ile temizleyip tum kategoriye donebilir.
  final String ara;

  @override
  ConsumerState<IsletmeListesiEkrani> createState() =>
      _IsletmeListesiEkraniState();
}

class _IsletmeListesiEkraniState extends ConsumerState<IsletmeListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;

  /// Bayat yanit kapisi — yanitlar SIRASIZ donebilir (kesfet ekraniyla ayni desen).
  int _istekNo = 0;

  /// ⚠️⚠️⚠️ **SLIDER HIC CIZILMIYORDU — AYRI SAYAC ZORUNLU.**
  ///
  ///	`_kesfiYukle` ile `_yukle` AYNI `_istekNo` sayacini paylasiyordu ve
  ///	ikisi de `initState`te ARDISIK cagriliyor:
  ///	   `_kesfiYukle()` -> jeton 1 · `_yukle()` -> jeton 2
  ///	Kesif yaniti donunce `1 != 2` cikip **SESSIZCE ATILIYORDU**. Yani
  ///	slider ve 60x60 serit **HICBIR ZAMAN** cizilmiyordu.
  /// ⚠️ YAPMA: bu iki sayaci tekrar birlestirme. Farkli iki istegin bayatlik
  ///    kapisi AYRI olmak ZORUNDA.
  int _kesifNo = 0;

  List<IsletmeOzet>? _liste;
  String? _hata;
  // ⚠️ TURU 96d — **FINAL**: ekran ici kategori degistirme kaldirildi
  //    (bkz. `_kategoriSec` serhi). Degisken kalsaydi analiz uyarisi
  //    verirdi ve "burasi degisebilir" yanilgisi surerdi.
  late final String _kategori = widget.kategori;

  /// ⚠️⚠️ TURU 121d — **ALT KATEGORI SERIDININ BASLIGI KATEGORIYE GORE.**
  ///
  ///	Baslik SABIT `"Mutfaklar"` yaziliydi. Kullanici emri gercekten
  ///	*"sol uste MUTFAKLAR yazsin"* idi ama o emir **YEMEK** ekrani icin
  ///	verilmisti; bu ekran **17 KATEGORIYE** hizmet ediyor. Sonuc:
  ///	Egitim`de "Dershane · Kurs · Dil" seridinin ustunde de
  ///	**"Mutfaklar"** yaziyordu (emulatorde goruldu).
  /// ⚠️ Sunucu bu basligi DONDURMUYOR (`/isletme-kesif` yalniz alt kategori
  ///	listesi verir) ve bu tur arayuz turu oldugu icin uca dokunulmadi.
  ///	Baslik istemcide turetiliyor — turu 77 kurali BURADA GECERLI DEGIL:
  ///	bu yalniz bir GORUNEN ETIKET, hicbir sorguyu/yetkiyi beslemiyor.
  /// ⚠️ Haritada OLMAYAN kategori notr **"Türler"**e duser: uydurma bir
  ///	baslik yazmaktansa notr olani dogrudur.
  String get _altBaslik => switch (_kategori) {
        'yemek' || 'kafe' => 'Mutfaklar',
        'saglik' || 'guzellik' || 'diyetisyen' => 'Bölümler',
        'egitim' => 'Alanlar',
        'kuafor' || 'oto' || 'hizmet' => 'Hizmetler',
        'market' || 'giyim' || 'teknoloji' || 'eczane' => 'Reyonlar',
        _ => 'Türler',
      };

  /// ⚠️⚠️ TURU 78 — HIZLI KARTLAR ("Şehrimde" / "Onaylı").
  ///
  /// Kullanici emri: "altta kucuk kartlar mesela yemekte yakinimda favoriler
  /// vs diye kartlar olsun".
  ///
  /// ⚠️⚠️ "YAKINIMDA" YERINE "ŞEHRİMDE" — bu bilincli ve DURUST bir karar:
  ///    GPS icin `AndroidManifest.xml`de `ACCESS_*_LOCATION`, `Info.plist`te
  ///    `NSLocation*` anahtarlari YOK. Podfile olmadigi icin
  ///    `permission_handler`in TUM izin isleyicileri derleniyor ve anahtar
  ///    eksikken konum istenirse **iOS uygulamayi ANINDA SONLANDIRIR**.
  ///    Ayrica sistemde tek bir gercek koordinat da yok (bkz. FAZ 0 koordinat
  ///    ezme duzeltmesi). Il/ilce ile ayni isi BUGUN goruyoruz; GPS ayri tur.
  ///    ⚠️ YAPMA: izin anahtarlarini eklemeden konum paketi cagirma.
  String _hizli = '';

  /// Kullanicinin kendi ilcesi — "Şehrimde" kartinin kaynagi.
  /// ⚠️ Bos ise kart CIZILMEZ (olu kart birakmiyoruz).
  String _benimIlce = '';

  /// ⚠️⚠️ TURU 92 — KESIF VERISI **SUNUCUDAN** (alt kategoriler + slaytlar).
  ///    Istemciye sabit yazmak turu 77'nin "Dart'a kategori sabiti YAZMA"
  ///    kuralinin ihlali olurdu ve yeni bir alt kategori eklemek MAGAZA
  ///    ONAYI gerektirirdi.
  /// ⚠️ TEK ISTEK: alt kategoriler ve slayt metinleri AYNI uctan gelir —
  ///    ekran acilisinda iki istek atmak turu 91'de olculen "acilistaki
  ///    es zamanli istek" maliyetini artirirdi.
  List<({String ad, String ara})> _altKategoriler = const [];
  List<({String baslik, String alt})> _slaytlar = const [];

  /// Secili alt kategori (arama metni). Bos = hicbiri.
  String _altSecili = '';

  /// ⚠️⚠️ TURU 96 — FILTRE EKRANININ SECIMLERI (kullanici emri).
  ///    Nesne SABIT kalir, icerigi sheet uzerinde degisir; `_gosterilen`
  ///    her cizimde bunu ham listeye UYGULAR.
  final _filtre = IsletmeFiltre();

  /// ⚠️⚠️ EKRANDA CIZILEN LISTE = ham liste + filtre.
  ///
  ///	Suzulmus liste AYRI BIR ALANDA TUTULMAZ: tutulsaydi filtre degisince
  ///	onu tazelemeyi unutmak "filtreyi degistirdim, liste ayni kaldi"
  ///	hatasini uretirdi (bu projede "iki kopya drift eder" sinifi).
  /// ⚠️ Ham liste (`_liste`) DEGISMEZ: "Önerilen"e donuldugunde sunucunun
  ///    dondurdugu sira geri gelmeli.
  List<IsletmeOzet>? get _gosterilen {
    final l = _liste;
    return l == null ? null : _filtre.uygula(l);
  }


  /// ⚠️ TURU 94 — GORUNUM: false = liste (tek sutun), true = kart (iki sutun).
  ///    Varsayilan LISTE: genis kapak + tum bilgiler sigar. Izgara,
  ///    "cok isletme var, hizlica tara" durumu icin ikincil bir gorunum.
  bool _izgara = false;

  /// ⚠️⚠️ TURU 96 — KART MESAFESI ICIN KONUM (kullanici emri).
  ///    `null` = konum bilinmiyor -> kartlarda mesafe CIZILMEZ.
  (double, double)? _konumum;

  /// Header'da yazan konum adi. Bos = kayitli konum yok ("Konum seç").
  String _konumAdi = '';

  /// ⚠️⚠️⚠️ TURU 96f — **KAYITLI KONUM, GPS'TEN ONCELIKLI.**
  ///
  ///	Kullanici bir konum sectiyse (Ev/İş) mesafe ONA gore hesaplanir;
  ///	kayitli konum yoksa cihazin GPS'ine dusulur. Tersi olsaydi kullanici
  ///	"Ev"i secer ama kartlar hala bulundugu yerden uzakligi gosterirdi —
  ///	secim GORUNURDE calisir, FIILEN hicbir sey yapmazdi.
  /// ⚠️ Sunucunun doldurdugu `km` (Yakınımda ucu) YINE de kazanir; bu
  ///    fonksiyon yalnizca `_konumum`u belirler.
  Future<void> _kayitliKonumuOku() async {
    final k = await KonumDeposu.secili(ref.read(apiProvider));
    if (!mounted || k == null) return;
    setState(() => _konumAdi = k.ad);
    _konumuUygula(k.enlem, k.boylam);
  }

  /// Konum panelini acar; secim degistiyse mesafeleri yeniden hesaplar.
  Future<void> _konumSec() async {
    await konumSeciciAc(context);
    if (!mounted) return;
    final k = await KonumDeposu.secili(ref.read(apiProvider));
    if (!mounted) return;
    setState(() => _konumAdi = k?.ad ?? '');
    if (k != null) {
      _konumuUygula(k.enlem, k.boylam);
    }
  }

  @override
  void initState() {
    super.initState();
    // ⚠️ Arama metni ILK ISTEKTEN ONCE konur: `_yukle()` kutuyu okuyor.
    if (widget.ara.isNotEmpty) {
      _arama.text = widget.ara;
      _aramaDolu = true;
    }
    _ilceyiOgren();
    _kesfiYukle();
    _yukle();
    // ⚠️ ONCE kayitli konum (varsa mesafe ANINDA cizilir), SONRA GPS.
    _kayitliKonumuOku();
    _konumuAl();
  }

  /// ⚠️⚠️⚠️ TURU 96 — KART MESAFESI ICIN KONUM.
  ///
  /// ⚠️⚠️ **IZIN BURADA ISTENIR** (ilk yazimda ISTENMIYORDU ve bu bir
  ///	HATAYDI): kullanici *"isletme kartlarinda 1 km / 300 m gibi mesafeler
  ///	gorunsun"* dedi. Ilk surumde izin YALNIZ "Yakınımda" cipine
  ///	dokunulunca isteniyordu; yani TEMIZ KURULUMDA hicbir kartta mesafe
  ///	GORUNMUYORDU ve kullanici bunu ozelligin yapilmadigi sanabilirdi.
  ///	Mesafe bu ekranin ANA vaadi — Getir/Yemeksepeti de tam bu noktada
  ///	izin ister.
  /// ⚠️ **BLOKLAMAZ**: izin reddedilirse liste normal calisir, yalnizca
  ///    mesafe cizilmez. Hicbir yerde hata gosterilmez.
  /// ⚠️ `deniedForever` ise TEKRAR SORULMAZ (sistem zaten gostermez);
  ///    ayarlara yonlendiren bir diyalog da acilmaz — kullanici bir kez
  ///    "bir daha sorma" dediyse ona uyulur.
  ///
  /// ⚠️⚠️ **ONCE `getLastKnownPosition`**: cihazda genelde saniyeler oncesine
  ///	ait bir konum ZATEN vardir; onu okumak ANINDA doner ve GPS'i hic
  ///	uyandirmaz. `getCurrentPosition` kapali alanda 8 saniyeye kadar
  ///	bekleyebilir ve o sure boyunca kartlarda mesafe GORUNMEZDI.
  ///	Taze olcum yine de arkadan alinir ve degeri gunceller.
  Future<void> _konumuAl() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin != LocationPermission.always &&
          izin != LocationPermission.whileInUse) {
        return;
      }
      // ⚠️⚠️ KAYITLI KONUM VARSA GPS **EZMEZ**: kullanici "Ev"i sectiyse
      //    mesafe ona gore kalmali (bkz.  serhi).
      if (_konumAdi.isNotEmpty) return;
      // 1) Hizli yol — varsa aninda ciz.
      final son = await Geolocator.getLastKnownPosition();
      if (son != null) _konumuUygula(son.latitude, son.longitude);
      // 2) Taze olcum — gelince degeri tazeler.
      // ⚠️⚠️ TURU 158b - **TEK-UCUS KAPISINDAN** (bkz. `KonumServisi.fix`).
      //	Dogrudan `getCurrentPosition` cagirmak, Yakinimda ekrani ayni
      //	anda fix isterse iOSta iki istegi carpistiriyordu.
      final f = await KonumServisi.fix();
      if (f.konum != null) _konumuUygula(f.konum!.enlem, f.konum!.boylam);
    } catch (_) {
      // ⚠️ SESSIZ: konum alinamazsa yalnizca mesafe cizilmez.
    }
  }

  /// Konumu kaydeder ve ELDEKI listeye uygular.
  ///
  /// ⚠️ Liste konumdan ONCE gelmis olabilir; bu yuzden mevcut kayitlara da
  ///    uygulanir. Yalniz `_konumum`u yazmak yetmezdi (bir sonraki `_yukle`ye
  ///    kadar mesafe gorunmezdi).
  void _konumuUygula(double enlem, double boylam) {
    if (!mounted) return;
    _konumum = (enlem, boylam);
    final l = _liste;
    if (l != null) mesafeleriDoldur(l, enlem, boylam);
    setState(() {});
  }

  /// Kullanicinin ilcesini KENDI isletme kaydindan ogrenir.
  ///
  /// ⚠️ Bu YALNIZ isletme hesaplarinda dolu olur. Kisisel hesapta ilce bilgisi
  ///    HICBIR YERDE tutulmuyor — o yuzden "Şehrimde" karti onlarda CIZILMEZ.
  ///    Sahte bir varsayilan ("Gebze") koymak YANLIS olurdu: kullanici baska
  ///    ilcedeyse liste yanlis gelir ve sebebini anlamaz.
  Future<void> _ilceyiOgren() async {
    // ⚠️⚠️ TURU 78b — SAGLAYICI HENUZ COZULMEMISSE **BEKLENIR** (denetim).
    //    `myProfileProvider` bir `FutureProvider`dir; `initState`ten cagrilan
    //    bu metot `valueOrNull`u okuyup null bulunca SESSIZCE cikiyordu ve
    //    TEKRAR DENEYEN HICBIR SEY YOKTU -> ekran soguk acildiginda "Şehrimde"
    //    karti KALICI OLARAK cizilmiyordu (ozellik rastgele "yok" gorunuyordu).
    var id = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '').toString();
    if (id.isEmpty) {
      try {
        final p = await ref.read(myProfileProvider.future);
        id = (p['id'] ?? '').toString();
      } catch (_) {
        return; // profil alinamadi: kart cizilmez (durust davranis)
      }
    }
    if (!mounted || id.isEmpty) return;
    try {
      final i = await ref.read(isletmeServisiProvider).detay(id);
      if (mounted && i != null && i.ilce.isNotEmpty) {
        setState(() => _benimIlce = i.ilce);
      }
    } catch (_) {
      // ⚠️ SESSIZ: ilce ogrenilemezse yalnizca "Şehrimde" karti cizilmez.
    }
  }

  /// Alt kategorileri ve slayt metinlerini sunucudan alir.
  ///
  /// ⚠️ HATA SESSIZ: kesif verisi gelmezse slider VARSAYILAN metinlerle
  ///    (sunucu zaten oyle donuyor) ve alt kategori seridi CIZILMEDEN
  ///    calisir. Ekranin ASIL isi (isletme listesi) bundan BAGIMSIZ.
  Future<void> _kesfiYukle() async {
    // ⚠️⚠️ TURU 93b — BAYAT YANIT KAPISI (denetim: kardes metotta VARDI,
    //	BURADA YOKTU).
    //
    //	Kullanici filtre sheet'inde ChoiceChip'ler yan yana oldugu icin
    //	hizlica "Yemek" -> "Kuaför" secebiliyor. Iki `kesif` istegi PARALEL
    //	ucar; Yemek'in yaniti GEC gelirse Kuaför'un uzerine YAZAR. Ekranda
    //	"Kuaför" cipi SECILI gorunur ama alt kategori kartlari
    //	**Döner/Kebap/Pide** olur. Kullanici "Döner"e basar ->
    //	`kategori=kuafor` + `q=döner` -> **KALICI BOS LISTE**, sebebi
    //	ekranda hicbir yerde yazmaz.
    // ⚠️⚠️ **AYRI SAYAC** (`_kesifNo`): `_yukle` ile paylasilirsa ikisi de
    //    `initState`te ardisik cagrildigi icin kesif yaniti DAIMA bayat
    //    sayilir ve slider HIC CIZILMEZ (bkz. `_kesifNo` serhi).
    final jeton = ++_kesifNo;
    try {
      final d = await ref.read(isletmeServisiProvider).kesif(_kategori);
      if (!mounted || jeton != _kesifNo) return;
      setState(() {
        _altKategoriler = d.altKategoriler;
        _slaytlar = d.slaytlar;
      });
    } catch (_) {
      // ⚠️ SESSIZ: slider ve serit cizilmez, ekranin ASIL isi (liste)
      //    bundan bagimsiz calisir. Kurtarma yolu asagi-cek (`_tazele`).
    }
  }

  /// ⚠️⚠️ TURU 93b — KATEGORI DEGISTIRMENIN **TEK KAPISI** (denetim).
  ///
  /// Onceden kategori UC ayri yerde yaziliyordu ve `_altSecili` sifirlamasi
  /// YALNIZ BIRINDE vardi:
  ///   · kategori cipi secimi          -> `_altSecili = ''`  ✓
  ///   · "Tümü" cipi                   -> **YOK**
  ///   · `InputChip.onDeleted` (✕)     -> **YOK**
  ///
  /// Sonuc: "Yemek → Döner" seciliyken "Tümü"ye basan kullanicida
  /// `_altSecili='döner'` KALIYORDU. Yeni kategoride o kart LISTEDE
  /// OLMADIGI icin secili gorunmuyor bile — yani **GORUNMEZ bir suzgec**
  /// takili kaliyor ve kullanici neden az sonuc gordugunu EKRANDA HICBIR
  /// YERDE goremiyordu.
  ///
  /// ⚠️ Duzeltmenin dogru yeri "ucuncu dala da o satiri ekle" DEGIL, tek
  ///    kapiya indirmektir: dordunc bir dal eklendiginde ayni hata
  ///    tekrarlanmasin.
  ///
  /// ⚠️⚠️⚠️ TURU 96d — METOT **SILINDI**, cunku EKRAN ICINDE KATEGORI
  ///	DEGISTIREN YOL KALMADI:
  ///	  · secili kategori cipi ("Yemek ✕") kullanici emriyle KALDIRILDI
  ///	    (ona basmak TUM kategorileri getiriyordu — doktor, otel...),
  ///	  · filtre paneline kategori bolumu HIC konmadi (gerekce
  ///	    `_filtreSheet` serhinde).
  ///	`_kategori` artik ekran omru boyunca SABIT: hangi kategoriyle
  ///	acildiysa o. Kategori degisimi hamburger menusunden YENI EKRAN acar.
  ///
  /// ⚠️ YAPMA: `_kategori`ye elle atama yapan bir yol ekleme. Ekran ici
  ///    kategori degistirme geri gelirse bu metodu AYNEN geri getir —
  ///    `_altSecili` sifirlamasi ve `_kesfiYukle` cagrisi ONUN icindeydi.

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final jeton = ++_istekNo;
    try {
      final svc = ref.read(isletmeServisiProvider);

      // ⚠️⚠️ "YAKINIMDA" **AYRI UC** kullanir (`/isletmeler/yakinimda`):
      //	mesafeye gore siralama sunucuda, kaba kutu + Haversine ile
      //	yapiliyor. Istemcide siralamak YANLIS olurdu — sunucu `LIMIT`
      //	donduruyor ve istemci elindeki 60 kaydi siralasa "en yakin"
      //	garantisi OLMAZDI.
      // ⚠️ Konum alinamazsa (izin yok / GPS kapali) cip SESSIZCE
      //    DUSURULMEZ: kullaniciya sebep soylenir ve normal liste gosterilir.
      //    Sessizce normal listeye donmek, "yakinimda calismiyor" hissi
      //    verir ve kullanici sebebini goremezdi.
      if (_hizli == 'yakinimda') {
        final k = await _konumAl();
        if (!mounted || jeton != _istekNo) return;
        if (k != null) {
          // ⚠️ Kullanici burada izni ACIKCA verdi; kartlarda mesafe artik
          //    normal listede de cizilebilir.
          _konumum = k;
          final yl = await svc.yakinimda(
            enlem: k.$1,
            boylam: k.$2,
            kategori: _kategori,
          );
          if (!mounted || jeton != _istekNo) return;
          setState(() {
            _liste = yl;
            _hata = null;
          });
          return;
        }
        // Konum yok: cipi birak, normal listeye dus.
        setState(() => _hizli = '');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Konum alınamadı. Ayarlardan konum iznini açabilirsin.'),
        ));
      }

      final l = await svc
          .liste(
            kategori: _kategori,
            // ⚠️ ALT KATEGORI **ARAMA METNINE** cevrilir (ayri sutun YOK —
            //    gerekce sunucudaki `altkategori.go` serhinde). Kullanici
            //    hem kart secip hem yazi yazabilir; ikisi BIRLESTIRILIR.
            q: [_altSecili, _arama.text.trim()]
                .where((x) => x.isNotEmpty)
                .join(' '),
            // ⚠️ Hizli kart suzgecleri SUNUCUYA gider. Istemcide suzmek YANLIS
            //    olurdu: sunucu `LIMIT 60` donuyor, istemci 3'e dusurseydi
            //    kullanici "sadece 3 isletme var" sanirdi.
            ilce: _hizli == 'sehrimde' ? _benimIlce : '',
            yalnizOnayli: _hizli == 'onayli',
            // ⚠️⚠️ TURU 96h — SUZGECLER **SUNUCUYA** gonderilir (LIMIT 60
            //    sorunu icin; gerekce `isletme_filtre.dart` `uygula`da).
            //    "Gece Kuşu" ve "Şu an açık" ISTEMCIDE kalir (saat dilimi).
            minTutarKurus: _filtre.minTutarTavanKurus ?? 0,
            puanTaban: _filtre.puanTaban ?? 0,
            teslimatTavanDk: _filtre.teslimatTavanDk ?? 0,
            kampanyali: _filtre.kampanyali,
            puansiz: _filtre.puansiz,
          );
      if (!mounted || jeton != _istekNo) return;
      // ⚠️ MESAFE: sunucu bu ucta hesaplamiyor (siralama mesafeye gore DEGIL),
      //    o yuzden istemcide doldurulur. Konum yoksa hicbir sey yazilmaz.
      final k = _konumum;
      if (k != null) mesafeleriDoldur(l, k.$1, k.$2);
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'İşletmeler alınamadı');
    }
  }

  /// Konumu alir; izin yoksa ister. Basarisizsa `null`.
  ///
  /// ⚠️ `geolocator` ZATEN projede (Yakinimda ekrani kullaniyor) — yeni
  ///    paket eklenmedi.
  /// ⚠️ Hata YUTULUR ama `null` doner: cagiran taraf kullaniciya SEBEP
  ///    gosterir. Sessizce normal listeye dusmek "calismiyor" hissi verirdi.
  Future<(double, double)?> _konumAl() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        return null;
      }
      // ⚠️⚠️ TURU 158b — **TEK-UCUS KAPISINDAN** (bkz. `KonumServisi.fix`).
      //	Zaman asimi da orada; kapali alanda GPS sonsuza kadar
      //	bekleyemez.
      final f = await KonumServisi.fix();
      if (f.konum == null) return null;
      return (f.konum!.enlem, f.konum!.boylam);
    } catch (_) {
      return null;
    }
  }

  void _aramaDegisti(String metin) {
    _gecikme?.cancel();
    // ⚠️⚠️ TURU 96o — TEMIZLE (X) DUGMESI **BOS/DOLU GECISINDE** cizilir;
    //	o yuzden burada `setState` gerekir. AMA her tusta setState etmek
    //	tum listeyi yeniden cizerdi: yalniz **gecis anlarinda** cagrilir.
    final dolu = metin.isNotEmpty;
    if (dolu != _aramaDolu) setState(() => _aramaDolu = dolu);
    // ⚠️ 320ms gecikme — her tusa basista istek atmak sunucuyu bosuna yorar.
    _gecikme = Timer(const Duration(milliseconds: 320), _yukle);
  }

  /// Arama kutusunda metin var mi (X dugmesinin gorunurlugu).
  bool _aramaDolu = false;

  /// ⚠️ Temizleme TEK KAPIDAN: metni sil, X'i gizle, listeyi HEMEN tazele
  ///    (gecikmeyi bekletmek "sildim ama sonuclar duruyor" hissi verirdi).
  void _aramaTemizle() {
    _gecikme?.cancel();
    _arama.clear();
    setState(() => _aramaDolu = false);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ HAM liste degil **SUZULMUS** liste cizilir (bkz. `_gosterilen`).
    final l = _gosterilen;
    // ⚠️⚠️ TURU 135 — kart **BIR KEZ** kurulur: hem cizilecek mi karari hem
    //	ustundeki boslugun buyuklugu ona bagli (bkz. `_isletmeSeridi`).
    //	Iki ayri yerde ayri ayri hesaplansaydi biri degisince oteki geride
    //	kalir ve bosluk 4 px kayardi.
    // TURU 174 - serit ARTIK CIZILMIYOR (kullanici emri); degisken
    //	yalnizca ALTTAKI bosluk hesaplarinin okunur kalmasi icin
    //	`null` sabitlendi. `_isletmeSeridi` govdesi SILINMEDI.
    // ⚠️ Bosluk formulleri `isletmeSeridi != null` soruyor; degisken
    //	kaldirilsaydi iki ayri yerde elle `false` yazmak gerekirdi
    //	ve biri unutulunca bosluk 4 px kayardi (turu 96k dersi).
    const Widget? isletmeSeridi = null;
    // TURU 174 - **ZORLA KOYU TEMA** (kullanici emri: *"arka plan siyah
    //	olacak"*).
    // ⚠️⚠️ Yalniz `backgroundColor` vermek YETMEZ: bu ekranda kartlar,
    //	cipler ve liste basligi renklerini TEMADAN aliyor ve acik
    //	temada siyah zemine SIYAH yazi cizilirdi (turu 135c'de
    //	olculen 1,056:1 kontrastin ayni sinifi).
    // ⚠️ `splashFactory`/`splashColor`/`highlightColor` ACIKCA geri
    //	konur: `ThemeData.dark()` uygulamanin "dokunma dairesi
    //	YOK" kararini (turu 7 kullanici emri) SIFIRLIYOR.
    // ⚠️⚠️ TURU 174 — **DURUM CUBUGU IKONLARI ACIK** (emulatorde goruldu:
    //	acik temada saat/wifi/pil KOYU cizilir ve siyah zeminde
    //	OKUNMAZ olur).
    // ⚠️ `AnnotatedRegion` ekran agacindan CIKINCA kendiliginden geri
    //	aliniyor; elle sifirlamaya gerek YOK (turu 155 dersi).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kKategoriZemin,
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: Scaffold(
      backgroundColor: kKategoriZemin,
      // ⚠️⚠️⚠️ TURU 96l — **ALT MENU BU EKRANDA DA CIZILIR** (kullanici emri:
      //	*"alt menuyu getir, alt menu gorunmesi gerekiyor"*).
      //
      //	Bu ekran `home_screen` uzerine PUSH edilmis bir route oldugu icin
      //	ev sahibinin `bottomNavigationBar`i gorunmuyordu; kullanici
      //	kategoriye girince uygulamanin geri kalanina ulasamiyordu.
      // ⚠️ GOVDE KOPYALANMADI: `AltMenu` tek kaynak (`home/alt_menu.dart`).
      // ⚠️ `secili: null` — kategori ekrani bir SEKME DEGIL. "Anasayfa"yi
      //    secili gostermek kullaniciya yalan soylerdi.
      // ⚠️ Sekmeye dokunulunca ONCE hedef sekme yazilir, SONRA bu route
      //    kapatilir: ters sirada `home` eski sekmesiyle bir kare cizer ve
      //    goz "yanlis sekmeye dondu" diye okur.
      // TURU 174 - **ALT MENU KALDIRILDI** (kullanici emri).
      // ⚠️⚠️ Govde SILINMEDI, `kAltMenuAcik` bayragiyla kapatildi:
      //	turu 96l'de kullanici TAM TERSINI istemisti (*"alt menuyu
      //	getir"*). Geri istenirse tek satir.
      // ⚠️⚠️ CIKIS YOLU: alt menu gidince bu ekrandan cikmanin tek yolu
      //	header'daki **GERI OKU** kaldi (konum secicinin yerine
      //	kondu). Ikisi birden kaldirilirsa kullanici ekranda
      //	KILITLENIR.
      bottomNavigationBar: !kAltMenuAcik
          ? null
          : AltMenu(
        secili: null,
        // ⚠️ IKINCI BIR NOTIFIER ACILMADI: `aktifSekme` ZATEN sekme durumunu
        //    tasiyor (akis videolarinin ses kapisi ona bakiyor) ve
        //    `HomeScreen` artik onu DINLIYOR. Ayri bir kanal acilsaydi iki
        //    kaynak birbirinden ayrisirdi.
        onSec: (sira) {
          aktifSekme.value = sira;
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      // ⚠️⚠️⚠️ TURU 92 — **APPBAR KALDIRILDI** (kullanici emri: *"'Yemek'
      //    yazisi gerek yok, sadece GERI IKONU"*). Baslik slider'in
      //    kendisinde degil, HIC YOK; geri ve harita ikonlari slider'in
      //    USTUNDE yuzuyor.
      // ⚠️ `extendBodyBehindAppBar` GEREKMEZ cunku AppBar YOK; slider
      //    dogrudan ekranin tepesinden baslar ve durum cubugunun altina
      //    girer — ikonlar `MediaQuery.paddingOf(context).top` ile
      //    guvenli alana konumlanir.
      // ⚠️⚠️ TURU 93 — HER SEY **TEK YATAY DOLGUDA** (kullanici emri:
      //    *"hepsi bir container icinde sol sag bosluk icinde"*).
      //    `kYanBosluk` TEK KAYNAK: header, slider, arama, kartlar ve
      //    filtreler AYNI hizada durur. Ayri ayri sayilar yazilsaydi biri
      //    guncellenip otekiler unutulurdu.
      // ⚠️⚠️⚠️ TURU 93b — GOVDE **KAYDIRILABILIR** OLDU (denetimde yakalanan
      //    IKINCI SEVK ENGELI).
      //
      //	Onceki hal bir `Column` + `Expanded(liste)` idi. `Expanded`in
      //	USTUNDEKI SABIT bloklar olculdu:
      //
      //	   header 48 + bosluk 10 + slider 350 + arama ~58
      //	   + 60x60 serit 92 + filtre satiri 56  =  **614 px**
      //
      //	· 360x800 (en yaygin modern Android, kullanilabilir ~776):
      //	  listeye **162px** kaliyor. Bir kart ~250px (16:9 kapak + ad +
      //	  meta) -> kapagin bir kismi gorunuyor, **AD VE META HIC
      //	  GORUNMUYOR**.
      //	· 360x640 + 3 tus navigasyon (~568): `Expanded` NEGATIF alan alir
      //	  -> **RenderFlex overflowed** sari-siyah serit.
      //	· 414x896 (test cihazi): 238px — yine tek kart bile tam sigmiyor.
      //
      //	Yani "kategori ekrani bastan tasarlandi" denen ekranda kullanici
      //	KAYDIRMADAN TEK BIR ISLETME ADI GOREMIYORDU.
      //
      // ⚠️ FIX: slider + arama + 60x60 serit + filtre satiri artik LISTENIN
      //    KENDISININ parcasi (`CustomScrollView` slaytlari). Yemeksepeti/
      //    Getir de boyle yapar: ust blok yukari kayip gider, liste ekranin
      //    TAMAMINI kullanir.
      // ⚠️ Slider yuksekligi (350) **DEGISTIRILMEDI** — kullanicinin verdigi
      //    olcu. Sorun yuksekligin kendisi degil, SABIT bir dikey butceyi
      //    listeden CALMASIYDI.
      // ⚠️ `AlwaysScrollableScrollPhysics` ZORUNLU: icerik ekrandan kisa
      //    oldugunda (bos liste / hata) asagi-cek-yenile CALISMAZ (turu 83b
      //    dersi — dort kardes ekranda ayni sinif duzeltilmisti).
      // ⚠️ YAPMA: bunu tekrar `Column` + `Expanded`e cevirme.
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ⚠️ Header SABIT kalir: geri dugmesi HER ZAMAN erisilebilir
            //    olmali (kaydirinca kaybolan bir geri tusu tuzaktir).
            _header(),
            Expanded(
              child: YenileSarmali(
                // ⚠️ TURU 93b — YENILEME **IKISINI DE** tazeler. Eskiden
                //    yalniz `_yukle` cagriliyordu; kesif istegi hata verirse
                //    350px BOS GRI KUTU kaliyor ve kullanicinin onu
                //    duzeltecek HICBIR yolu olmuyordu.
                onRefresh: _tazele,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── HEADER -> ARAMA ──
                    // ⚠️ Header'in ALTINDA kendi payi var (bkz. `kHeaderPay`):
                    //    ekranda gorunen bosluk yine 16.
                    const SliverToBoxAdapter(
                        child: SizedBox(height: kBosluk - kHeaderPay)),

                    // ── ARAMA ──
                    // ⚠️⚠️ TURU 96f — ARAMA **HEADER ALTINA, SLIDER USTUNE**
                    //	tasindi (kullanici emri). Onceden kesif kartlarinin
                    //	ALTINDAYDI; artik ekrana girer girmez gorunuyor.
                    // ⚠️ Gorunum ve harita dugmeleri BURADA DEGIL, liste
                    //    basliginda (turu 96c) — input satirin TAMAMI.
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: kYanBosluk),
                        child: _aramaKutusu(),
                      ),
                    ),
                    // ⚠️ TURU 175 — slider YOKSA bir sonraki oge "Mutfaklar"
                    //    ya da cip seridi olur; kural slider'inkiyle AYNI.
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: (_slaytlar.isNotEmpty ||
                                    _altKategoriler.isNotEmpty)
                                ? kBosluk
                                : kBosluk - kCipPay)),

                    // ⚠️⚠️ SLAYT YOKSA SLIDER HIC CIZILMEZ: istek patlarsa
                    //    `_slaytlar` bos kalir ve `PageView` 0 ogeyle
                    //    cizilir -> ekranin tepesinde ICI BOS gri dikdortgen.
                    if (_slaytlar.isNotEmpty) ...[
                      // ⚠️⚠️ **DOLGU YOK — SLIDER TAM GENISLIK** (turu 96b).
                      //    Yandaki slaytlarin sarkmasi icin viewport ekranin
                      //    TAMAMI olmali; yan bosluk slider'in KENDI
                      //    `viewportFraction` hesabindan geliyor ve aktif
                      //    kartin sol kenari yine tam `kYanBosluk`ta duruyor.
                      // ⚠️ YAPMA: burayi tekrar `Padding` ile sarma — kart
                      //    16 yerine ~35 dp'ye kayar (olculdu).
                      SliverToBoxAdapter(
                        // ⚠️⚠️⚠️ TURU 180ae — **SLIDERDEKI GORSEL KALDIRILDI**
                        //	(kullanici emri: *"yemekteki sliderdeki resmi
                        //	kaldir"*). `ilkGorsel:` parametresi ARTIK
                        //	GECILMIYOR; ilk slayt da otekiler gibi metin
                        //	slaydi olarak cizilir.
                        // ⚠️ `kSliderIlkGorsel` sabiti ve
                        //	`assets/slider/slider1.jpg` **SILINMEDI**:
                        //	varligi pubspec'ten cikarmak bu ekrani degil,
                        //	onu HALA kullanabilecek yollari kirik gorsele
                        //	dusururdu (turu 180q dersi). Geri almak TEK
                        //	SATIR: `ilkGorsel: kSliderIlkGorsel`.
                        child: KategoriSlider(slaytlar: _slaytlar),
                      ),
                      // ⚠️ TURU 96 — bu bosluk artik OTEKILERLE BIREBIR AYNI
                      //    (kullanici emri); slider'a ozel genis nefes YOK.
                      // ⚠️⚠️ TURU 175 — cip payi ARTIK BURADA dusulur: kesif
                      //	izgarasi kalkinca slider'in bir SONRAKI ogesi
                      //	ya "Mutfaklar" basligi (pay YOK) ya da
                      //	dogrudan filtre cipleri (kendi 4 px ic payi
                      //	VAR) oluyor. Pay dusulmezse cipli dalda
                      //	gorunen bosluk 16 degil 20 dp olurdu.
                      SliverToBoxAdapter(
                          child: SizedBox(
                              height: _altKategoriler.isNotEmpty
                                  ? kBosluk
                                  : kBosluk - kCipPay)),
                    ],

                    // ── KESIF KARTLARI (4 x 2) — **KALDIRILDI (turu 174)** ──
                    // Kullanici emri: *"altindaki NE YESEM diye buyuk
                    // kartlari kaldir"*. Izgaranin ilk karti "Ne Yesem?"
                    // idi; kullanicinin tarif ettigi blok BUYDU.
                    // ⚠️⚠️ `_kesifIzgarasi` GOVDESI SILINMEDI
                    //	(`ignore: unused_element`): bu dosyada uye
                    //	silmek BES kez komsu uyeyi de goturdu
                    //	(turu 127/138/140/141/143).
                    // ⚠️ Suzgecler OLU KALMADI: 'İndirimli' · '4+' ·
                    //	'Şimşek' · 'Yakınımda' · 'Gece Kuşu' ·
                    //	'Yeni Restoran' · 'Favori' hepsi ALTTAKI
                    //	filtre seridinden ve filtre panelinden
                    //	ulasilabilir durumda.
                    // ⏳ DURUST SINIR: **"Ne Yesem?"** (rastgele isletme)
                    //	artik HICBIR yerden cagrilmiyor - o tek
                    //	ozellik ulasilamaz oldu. Istenirse filtre
                    //	seridine bir cip olarak geri konabilir.

                    // ⚠️⚠️⚠️ TURU 175 — **BU BOSLUK KALDIRILDI** (kullanici:
                    //	*"mutfaklar slider yukarida fazla bosluk olmus,
                    //	hepsinin arasindaki bosluk ESIT olmali"*).
                    //
                    //	Turu 174'te kesif izgarasi kaldirildi ama onun
                    //	**ALTINDAKI bosluk BIRAKILDI**; slider'in kendi
                    //	`kBosluk`u ile ust uste gelip slider ↔ "Mutfaklar"
                    //	arasini **32 dp** yapiyordu. Sayfanin geri kalani
                    //	16 ile yuruyor.
                    //
                    // ⚠️⚠️ **TURU 96k'NIN BIREBIR TEKRARI**: o turda da tam
                    //	bu iki bosluk ust uste gelmisti ve serhi HEMEN
                    //	BURADA yaziliydi. Bir blogu kaldirirken **onun
                    //	bosluklarini da kaldir** — yoksa hata gozle
                    //	"burasi biraz genis" diye gecilir.
                    //
                    // ⚠️ Cip payi (`kCipPay`) ARTIK BURADA DUSULMEZ: bir
                    //    sonraki oge alt kategori seridi YOKSA filtre cipleri
                    //    gelir ve o payi **slider'in kendi boslugu** dusuyor
                    //    (bkz. asagidaki `_slaytlar` blogu).

                    // ── "MUTFAKLAR" + ALT KATEGORI SERIDI (60x60) ──
                    // ⚠️ Kullanici emri: *"döner kebap vs. bunlari isletme ara
                    //    ALTINA al, sol uste MUTFAKLAR yazsin"*.
                    // ⚠️ Baslik YALNIZ serit varken cizilir: bos bir "Mutfaklar"
                    //    basligi, altinda hicbir sey yokken tuhaf durur
                    //    (her kategoride alt kategori tanimli degil).
                    if (_altKategoriler.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          // ⚠️ Baslik metninin GLIF ICI boslugu telafi edilir
                          //    (bkz. `kBaslikOptik`): kutular 16'da hizaliyken
                          //    yazi 17.1'de basliyordu.
                          padding: const EdgeInsets.only(
                              left: kYanBosluk - kBaslikOptik),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _altBaslik,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      // ⚠️ Baslik ↔ KENDI kartlari: `kBaslikBosluk` (8).
                      //    Bolum araligindan (16) KUCUK olmasi ZORUNLU —
                      //    yoksa "Mutfaklar" altindaki seride degil,
                      //    ustundeki bolume ait gibi gorunur.
                      const SliverToBoxAdapter(
                          child: SizedBox(height: kBaslikBosluk)),
                      SliverToBoxAdapter(child: _altKategoriSeridi()),
                      // ⚠️ Cip seridinin USTUNDE 4px kendi payi var
                      //    (bkz. `kCipPay`): gorunen bosluk yine 16.
                      // ⚠️ Araya isletme karti girdiyse pay DUSULMEZ (bkz.
                      //    yukaridaki ayni gerekce).
                      SliverToBoxAdapter(
                          child: SizedBox(
                              height: isletmeSeridi != null
                                  ? kBosluk
                                  : kBosluk - kCipPay)),
                    ],

                    // ── ISLETME SERIDI — **KALDIRILDI (turu 174)** ──
                    // Kullanici emri: *"mutfagin altinda isletme kartlari
                    // var onlari kaldir; FILTRELEME ALTINDAKI isletmeden
                    // bahsetmiyorum"*.
                    // ⚠️⚠️ Kaldirilan YALNIZ 'Mutfaklar' seridinin hemen
                    //	altindaki YATAY serit. Filtre satirinin
                    //	ALTINDAKI **asil isletme listesi**
                    //	('Restoranlar (N)') AYNEN DURUYOR - ekranin
                    //	varlik sebebi odur.

                    // ── HIZLI SUZGEC SERIDI — **KALDIRILDI (turu 180af)** ──
                    // Kullanici emri: *"filtrelemede sagdaki hizli
                    // filtrelemeleri kaldir, filtreleme gorunumun hemen
                    // solunda olsun"*.
                    //
                    // ⚠️⚠️ Serit ekranin ustunde TAM BIR SATIR (40 dp + 16 dp
                    //	bosluk) yer kapliyordu ve tasidigi alti cipin BESI
                    //	(Siralama · Min. tutar · Puan · Teslimat · Onayli)
                    //	yalnizca AYNI paneli aciyordu — filtre cipinin
                    //	kopyasiydilar. Tek gercek kapi (`_filtreCipi`) artik
                    //	liste basliginda, gorunum seciciyle YAN YANA.
                    // ⚠️ HICBIR SUZGEC ULASILAMAZ KALMADI: hepsi ayni
                    //	panelin bolumleri (`isletmeFiltreAc`) ve "Onaylı"
                    //	da o panelde duruyor.
                    // ⚠️ `_filtreSatiri`/`_bolumCipi`/`_hizliCip` govdeleri
                    //	`ignore: unused_element` ile DURUYOR — bu dosyada uye
                    //	silmek BES kez komsu uyeyi de goturdu.

                    // ── "2 Restoran" + FILTRE + GORUNUM ──
                    if (l != null && l.isNotEmpty) ...[
                      SliverToBoxAdapter(child: _listeBasligi(l.length)),
                      // ⚠️⚠️ TURU 96k — 16 -> **`kBaslikBosluk` (8)**.
                      //	Olculdugunde YAKINLIK TERSTI: "Restoranlar" ustundeki
                      //	suzgec seridine 16, KENDI listesine 19.8 dp uzaktaydi.
                      //	Yani baslik, ait oldugu listeye degil bir onceki
                      //	bolume yapisik duruyordu. Artik "Mutfaklar" ile ayni
                      //	kurala tabi.
                      const SliverToBoxAdapter(
                          child: SizedBox(height: kBaslikBosluk)),
                    ],

                    if (_hata != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Text(_hata!,
                                  style: const TextStyle(color: Colors.grey)),
                              TextButton(
                                // ⚠️ IKISI BIRDEN: kesif verisi de bu
                                //    hatadan etkilenmis olabilir.
                                onPressed: _tazele,
                                child: const Text('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (l == null)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    // ⚠️⚠️ TURU 96 — BOS MESAJI **SEBEBE GORE** degisir.
                    //	Filtre listeyi bosalttiginda "bu kategoride henuz
                    //	isletme yok, ilk isletme sen ol" demek YANLIS BILGI
                    //	olurdu: isletme VAR, suzgecten gecmedi. Kullanici
                    //	sebebini goremez ve kurtarma yolunu (filtreyi
                    //	temizle) bulamazdi.
                    else if (l.isEmpty && _filtre.aktifSayi > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            children: [
                              const Text(
                                'Seçtiğin filtrelere uyan işletme bulunamadı.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _suzgecDegistir(_filtre.temizle),
                                child: const Text('Filtreleri temizle'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (l.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                            'Bu kategoride henüz işletme yok.\n'
                            'İlk işletme sen ol: Profil → İşletme hesabı.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      // ⚠️ TURU 93 — AYIRICI CIZGI KALDIRILDI: kartlar artik
                      //    kendi golgeleriyle ayriliyor (Yemeksepeti/Getir
                      //    deseni). Cizgi + kart ARADA cift ayirici olurdu.
                      SliverPadding(
                        // ⚠️ TURU 96e — yatay dolgu `kYanBosluk`a GERI
                        //    DONDU (kartlar daralmisti). Kartlar arasi dikey
                        //    bosluk kartin KENDI alt marjindan geliyor.
                        padding: const EdgeInsets.fromLTRB(
                            kYanBosluk, 0, kYanBosluk, 24),
                        // ⚠️ IKI GORUNUM (kullanici emri: "kart gorunumu").
                        //    Izgarada IKI SUTUN; ucuncusu 360dp'de kapagi
                        //    ~104px'e dusurup okunamaz yapardi.
                        sliver: _izgara
                            ? SliverGrid(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 20,
                                  // ⚠️ Kapak 16:9 + ad + iki bilgi satiri.
                                  //    Dusuk oran metni kirpar, yuksek oran
                                  //    kartlar arasinda bosluk birakir.
                                  childAspectRatio: 0.86,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _izgaraKarti(l[i]),
                                  childCount: l.length,
                                ),
                              )
                            : SliverList.builder(
                                itemCount: l.length,
                                itemBuilder: (_, i) => IsletmeKarti(o: l[i]),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  /// Kesif verisi + liste birlikte tazelenir.
  ///
  /// ⚠️ Asagi-cek YALNIZ `_yukle` cagirsaydi, kesif istegi patlamis bir
  ///    ekranda slider ve 60x60 serit KALICI olarak bos kalirdi ve
  ///    kullanicinin ekrani kapatmaktan baska yolu olmazdi.
  Future<void> _tazele() async {
    // ⚠️⚠️ TURU 135 (denetim) — **PROFIL DE TAZELENIR.**
    //
    //	`myProfileProvider` `keepAlive` ve govdesinde `invalidateSelf` YOK:
    //	`/users/me` BIR KEZ patlarsa (mobil ag, sunucu restarti, soguk
    //	acilis) hata SUREC OMRU BOYUNCA onbellekte kalir ve `valueOrNull`
    //	bir daha DOLMAZ. Bu ekran profili "Şehrimde" suzgecinde ve kendi
    //	isletmesini ayirt etmekte kullaniyor; asagi-cek o hatadan da
    //	donebilmeli.
    //	⚠️ Turu 136 notu: bu kapi turu 135'te FILTRE USTUNDEKI KART icin
    //	   eklenmisti; o kart yerini isletme SERIDINE birakti ve serit
    //	   profile bakmiyor. Kapi yine de KALIR — sebebi degisti, gecerliligi
    //	   degil (ayni sinif turu 78b `aiDurumProvider` ve turu 113 Ayarlar >
    //	   Gizlilik ile IKI KEZ sahaya cikti).
    // ⚠️ Saglayicinin KENDISI degistirilmedi: 15+ tuketicisi var ve hata
    //    dalinin semantigini degistirmek bu arayuz turunun kapsami disi.
    ref.invalidate(myProfileProvider);
    await Future.wait([_kesfiYukle(), _yukle()]);
  }

  /// ⚠️⚠️ TURU 93 — HEADER: geri (arrow-left) + harita, DAIRE YOK.
  ///
  /// Kullanici emri: *"header'da geri ikonu ARROW-LEFT olsun, sagdaki harita
  /// kalsin, bunlarin ARKASINDAKI DAIRE KALDIR; bunlar bir HEADER olacak"*.
  ///
  /// ⚠️ Daire (opak beyaz zemin) kalkinca ikonlar SAYFA ZEMINI uzerinde
  ///    duruyor — renk TEMADAN alinir; sabit siyah yazilsaydi koyu temada
  ///    GORUNMEZ olurdu.
  /// ⚠️ `IconButton` 48dp dokunma alanini KORUR (gorsel olarak yalniz ikon
  ///    gorunse de); ciplak `Icon` + `GestureDetector` hedefi 24dp'ye
  ///    dusururdu (Material 48 / Apple 44 kurali).
  /// ⚠️⚠️ HEADER — geri · baslik · favoriler · profil.
  ///
  /// Kullanici emri: *"header'daki ikonlar profil dairesi boyutunda olsun,
  /// o dairenin icinde harf yazmasin, rengi slider renginde olsun"*.
  ///
  /// ⚠️ UC OGE DE **AYNI 34dp DAIRE** ve **AYNI GRI** (`kYuzeyGri`): farkli
  ///    boyut/zemin, ayni satirdaki ogeleri "baska bilesenler" gibi
  ///    gosteriyordu.
  /// ⚠️ Profil dairesinde **HARF YOK**: avatar yoksa duz gri daire cizilir.
  ///    Harf, yanindaki iki ikonla ayni dili konusmuyordu.
  /// ⚠️ Dokunma alani daireden BUYUK (44dp): 34dp gorsel, Material'in 48 /
  ///    Apple'in 44 kuralinin altinda kalirdi.
  Widget _header() => Padding(
        // ⚠️⚠️⚠️ TURU 96 — **GORSEL HIZA** (kullanici emri: *"geri ikonu saga
        //	yatmis, o da alttakilerle ayni hizada olsun"*). HAKLIYDI ve
        //	sebebi olculebilir:
        //
        //	Dokunma alani 44, GORSEL daire 34 ve daire kutunun ORTASINDA
        //	-> daire, kutunun sol kenarindan **5px** iceride basliyor. Dolgu
        //	`kYanBosluk` (16) olsaydi dairenin sol kenari **21px**'te olur,
        //	altindaki slider/kart/input ise 16px'te baslardi: header 5px
        //	SAGA KAYMIS gorunurdu.
        //
        //	FIX: dolgudan o ic pay DUSULUR. Boylece SOLDA ikonun sol kenari
        //	tam 16, SAGDA da (pay simetrik oldugu icin) sag kenari tam
        //	`genislik - 16`.
        // ⚠️⚠️ TURU 96b — DAIRE KALKTI, IKON 24 OLDU -> pay `(44-34)/2 = 5`
        //    DEGIL artik **`(44-24)/2 = 10`**. Eski 5 birakilsaydi ikonlar
        //    5px ICERIDE kalir ve hiza YENIDEN bozulurdu.
        // ⚠️ YAPMA: burayi sabit bir sayiya donme; ikon ya da dokunma olcusu
        //    degisirse `kHeaderPay` uzerinden yeniden turer.
        // ⚠️⚠️⚠️ TURU 96e — **OPTIK TELAFI** (kullanici: *"sol sag container
        //	icinde olanlar ayni hizada degil"* — HAKLIYDI, ekrandan olculdu).
        //
        //	Ikonun YERLESIM kutusu tam 16 dp'de basliyor ama CIZILEN glif
        //	kutunun icinde bosluk (side bearing) tasiyor: olcum
        //	  · arrow-left : 19.8 dp'de basliyor -> **3.8 dp** ic bosluk
        //	  · heart      : sagdan 16.8 dp -> **0.8 dp** ic bosluk
        //	Sonuc: slider, input ve kartlar 16'da hizaliyken header 4 dp
        //	SAGA kayik gorunuyordu. Daire varken sorun yoktu (dairenin
        //	KENDISI 16'da basliyordu); daireler kalkinca glif ortaya cikti.
        //
        // ⚠️ Telafi IKI YAN ICIN AYRI: bearing degerleri ikona OZEL.
        // ⚠️ Ikonlar degisirse bu iki sayi YENIDEN OLCULMELI (ekrandan;
        //    tahmin etme). Olcum araci: scratchpad/hiza.js
        padding: const EdgeInsets.only(
          // ⚠️⚠️ TURU 96f — SOL TARAF YENIDEN OLCULDU. Geri tusu (44dp kutuda
          //	ortali ikon) yerine artik konum dugmesi var ve o bir `Row`:
          //	dolgunun BASINDAN basliyor, yani `kHeaderPay` SOLDA GECERSIZ.
          //	Eski telafi birakilinca ikon **3.8 dp**ye kaydi (olculdu).
          // ⚠️ SAG hala `_headerDaire` -> orada ikisi de gecerli.
          left: kYanBosluk - kNavOptik,
          right: kYanBosluk - kHeaderPay - kKalpOptik,
        ),
        // ⚠️⚠️⚠️ TURU 96g — BASLIK **GERCEK MERKEZDE** (kullanici emri:
        //	*"Yemek yazisi ortada olacak"*).
        //
        //	ONCEKI HAL `Row` + `Expanded` idi: soldaki konum dugmesi ile
        //	sagdaki kalp ESIT GENISLIKTE OLMADIGI icin "orta" kayiyordu.
        //	`Stack` + `Center` yapisal cozum: baslik yanindakilerden
        //	BAGIMSIZ, header'in gercek ortasinda durur.
        // ⚠️ Ayni hata filtre panelinde de vardi ve kullanici orada da fark
        //    etti — cozum ayni.
        child: SizedBox(
          height: 44,
          child: Stack(
            children: [
              if (widget.baslik.isNotEmpty)
                Center(
                  child: Text(
                    widget.baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // ⚠️ DIKEY DENGE: yazi tipinin ascent'i descent'ten
                    //    buyuk oldugu icin varsayilan satir kutusunda glif
                    //    YUKARI kayik oturur (kullanici: *"alt kismi kisa
                    //    kaliyor"*). `height: 1.0` + `even` esit dagitir.
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                ),
              // ⚠️⚠️ GERI TUSU YERINE **KONUM SECICI** (turu 96f).
              //	Geri dugmesi yok; Android'de donanim/jest geri, iOS'ta
              //	kenardan cekme CALISMAYA DEVAM EDER.
              // ⚠️ YAPMA: bu satiri "sadelestirme" adina kaldirma — ekranda
              //    baska cikis yolu yok.
              // TURU 174 - **KONUM SECICI KALDIRILDI, YERINE GERI OKU**
              //	(kullanici emri: *"solda konum sec var onu
              //	kaldir"*).
              // ⚠️⚠️ Yerine GERI OKU kondu, bosluk BIRAKILMADI: ayni
              //	turda alt menu de kaldirildi ve ikisi birden
              //	gidince ekranda **HICBIR cikis yolu kalmiyordu**
              //	(donanim geri disinda). `KategoriKabugu` da
              //	sol kose bosken geri oku cizer — ayni dil.
              Align(
                alignment: Alignment.centerLeft,
                child: _headerDaire(
                  LucideIcons.arrowLeft,
                  'Geri',
                  () => Navigator.of(context).maybePop(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                // ⚠️⚠️ TURU 175 — **KALP CIZGISI 1 TIK INCE** (kullanici:
                //	*"kalp beyaz border 1 tik incelt"*).
                //	Lucide bir **FONT**tur; `strokeWidth` YOKTUR
                //	(turu 93/141'de kaynaktan dogrulandi) ve
                //	kalinlik ancak GLIFIN KENDISIYLE degisir.
                //	Material'in `favorite_border` glifi ayni 24 dp
                //	izgarada daha INCE cizilir - istenen "1 tik"
                //	tam bu.
                // ⚠️ Boyut DEGISMEDI (24): `size`i kucultmek cizgiyi
                //    inceltir ama ikonu da kucultur; kullanici boyut
                //    degil KALINLIK istedi.
                // ⚠️ Ayni istisna projede daha once de var (turu 98:
                //    dolu kalp icin Material `Icons.favorite`).
                child: _headerDaire(
                  Icons.favorite_border,
                  'Favorilerim',
                  () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FavorilerimEkrani()),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// ⚠️⚠️ TURU 96f — KONUM DUGMESI: navigator ikonu + secili konumun ADI.
  ///
  /// ⚠️ Kayitli konum YOKSA **"Konum seç"** yazar. "Ev" yazmak SAHTE olurdu:
  ///    kullanicinin kayitli bir evi yok ve dokununca bos liste gorurdu.
  ///    Ilk konum eklenirken ad alani ZATEN "Ev" ile dolu geliyor.
  /// ⚠️ Ad UZUNSA kirpilir (`Flexible` + ellipsis): "Babaannemin Evi" gibi
  ///    bir ad header'i tasirdi.
  /// ⚠️ Dokunma alani ikon + yazinin TAMAMI (`opaque`): yalniz ikon
  ///    dokunulabilir olsaydi kullanici yaziya basip "calismiyor" derdi.
  // TURU 174 - cagri yerinden CIKARILDI (kullanici emri: *"solda konum
  //	sec var onu kaldir"*), yerine geri oku kondu. Govde
  //	SILINMEDI: bu dosyada uye silmek BES kez komsu uyeyi de
  //	goturdu (turu 127/138/140/141/143).
  // ignore: unused_element
  Widget _konumDugmesi() => Semantics(
        button: true,
        label: 'Konum: ${_konumAdi.isEmpty ? "seçilmedi" : _konumAdi}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _konumSec,
          // ⚠️⚠️ TURU 96g — **GENISLIK TAVANI** (kullanici emri: *"belirli
          //	bir yazidan sonra ... olmasi gerekiyor, ortadaki Yemek
          //	yazisina cok yaklasmasin"*).
          //
          //	Baslik artik `Stack` icinde ORTALI, yani konum dugmesi
          //	buyudukce onu ITMEZ — UZERINE BINER. Tavan olmadan "Babaannemin
          //	Evi" gibi bir ad basligin altina girerdi.
          // ⚠️ Oran ekrandan turer (%32): sabit dp dar telefonda cok yer
          //    kaplar, genis telefonda gereksiz erken kirpardi.
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.32),
            child: SizedBox(
            height: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ⚠️ Ikonun sol GLIF boslugu header dolgusunda telafi ediliyor
                //    (bkz. `kNavOptik`) — deger `navigation` icin olculdu.
                Icon(LucideIcons.navigation, size: 22, color: _notrYazi),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    _konumAdi.isEmpty ? 'Konum seç' : _konumAdi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _notrYazi,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(LucideIcons.chevronDown, size: 15, color: _notrYazi),
              ],
            ),
          ),
          ),
        ),
      );

  /// Header'daki gri daire — ikonlu.
  Widget _headerDaire(IconData ikon, String ipucu, VoidCallback onTap) =>
      Semantics(
        button: true,
        label: ipucu,
        child: GestureDetector(
          // ⚠️ **DALGA YOK**: kullanici "tikladiginda titreme olmasin" dedi.
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            // ⚠️ Dokunma alani 44 KALIR (Material 48 / Apple 44 kurali):
            //    daire kalksa da dokunulabilir alan KUCULMEZ.
            width: 44,
            height: 44,
            child: Center(
              // ⚠️⚠️ TURU 96b — **DAIRE KALDIRILDI** (kullanici emri: *"geri
              //	ve kalp arkasindaki daireleri kaldir, o ikonlari 4px daha
              //	buyut"*). Ikon artik sayfa zemini uzerinde ciplak duruyor.
              // ⚠️ 20 -> **24**: daire kalkinca ikon kucuk kaliyordu; 4px
              //    buyume o boslugu dolduruyor.
              child: Icon(ikon, size: 24, color: _notrYazi),
            ),
          ),
        ),
      );

  /// ⚠️⚠️ TURU 93 — ARAMA KUTUSU (kullanici emri).
  ///
  /// · Odaklaninca kenarlik **TAM SIYAHIN BIR TIK ACIGI** (`0xFF1A1A1A`).
  ///   Varsayilan Material odak rengi TEMA VURGUSU idi; kullanici notr
  ///   istedi.
  /// · Arama ikonu **BIR TIK KALIN**: `size` 19 -> 21 **+ golge hilesi**.
  ///   ⚠️⚠️ `strokeWidth` YOKTUR: `lucide_icons_flutter` ikonlari bir FONT
  ///      olarak sunar (glif), SVG olarak degil — cizgi kalinligi
  ///      ayarlanamaz. Yalniz `size` buyutmek ikonu BUYUTUR ama oransal
  ///      olarak AYNI incelikte birakir.
  ///   ⚠️ Cozum: ayni renkte, ±0.4px kaydirilmis DORT golge. Glif kendi
  ///      uzerine hafifce yayilir ve cizgi KALINLASIR. Bu, font tabanli
  ///      ikonlarda kalinlik simule etmenin standart yolu.
  ///   ⚠️ YAPMA: `Icon`a `strokeWidth` eklemeye calisma — DERLENMEZ.
  /// · Ikon ile yazi arasi **BIR TIK AZ**: `prefixIconConstraints` ile kutu
  ///   daraltilir. Varsayilan `prefixIcon` 48dp'lik bir kutuya oturur ve
  ///   metin ondan SONRA baslar.
  /// ⚠️ Koyu temada siyah kenarlik GORUNMEZ olurdu — tema parlakligina gore
  ///    secilir.
  Widget _aramaKutusu() {
    // ⚠️ TURU 174 — ekran her zaman siyah; tema SORULMAZ (bkz. `_notrYazi`).
    const ikonRenk = Colors.white70;
    // ⚠️⚠️⚠️ TURU 96 — YUKSEKLIK **EN UZUN COCUKTAN** gelir (emulatorde
    //	olculdu: 33 dp cikiyordu, yanindaki daireler 48'di).
    //
    //	ILK DENEME `SizedBox(height: 48)` ILE SARMAKTI — **CALISMADI** ve
    //	sebebi ogreticidir: `SizedBox` widget'in KAPLADIGI ALANI 48 yapar,
    //	ama `InputDecorator` KENARLIGI `size`a gore degil kendi hesapladigi
    //	`containerHeight`e gore cizer. Yani kutu 48 yer kapliyor, cerceve
    //	33 cizilmeye devam ediyordu: ekranda hem input kisa gorunuyor hem
    //	de altinda 15 dp GORUNMEZ bosluk kaliyordu (o bosluk da alttaki
    //	cip seridiyle arasindaki mesafeyi 30 dp gosteriyordu).
    //
    //	DOGRU YOL: `containerHeight` = en uzun cocugun boyu. Suffix ikonu
    //	`kInputBoy` yuksekliginde bir kutuya alinir, gri daire onun ICINDE
    //	ortalanir -> cerceve GERCEKTEN 48 olur.
    // ⚠️ YAPMA: burayi tekrar `SizedBox`la sarip cozdum sanma; olcup dogrula.
    // ⚠️⚠️ TURU 96c — YAZI **1px KUCUK, BIR TIK KALIN** (kullanici emri:
    //	*"isletme ara yazisini 1px ufalt ve 1 tik kalinlastir"*).
    //	Varsayilan `bodyLarge` 16/w400 idi -> **15/w500**.
    // ⚠️ Ipucu ve GERCEK METIN **AYNI** stili kullanir: farkli olsalardi
    //    kullanici yazmaya basladigi an yazi boyu ZIPLARDI.
    const yaziStili = TextStyle(fontSize: 15, fontWeight: FontWeight.w500);
    return TextField(
      controller: _arama,
      onChanged: _aramaDegisti,
      style: yaziStili,
      decoration: InputDecoration(
        hintText: 'Ne Aramıştın?',
        hintStyle: yaziStili.copyWith(
            color: Colors.white.withValues(alpha: 0.45)),
        // ⚠️⚠️ MESAFELER **ACIKCA** VERILIR (kullanici emri: *"arama ikonu
        //	input soluna dayanmis, bu mesafeleri lutfen mimarisini iyi
        //	ayarla"*).
        //
        //	ONCEKI HAL BIR HACKTI: `prefixIconConstraints` ile 38x38'lik bir
        //	kutu zorlaniyor, ikon O KUTUNUN ORTASINA dusuyordu. Kutunun sol
        //	kenari inputun sol kenariyla CAKISTIGI icin ikon kenara YAPISIK
        //	gorunuyordu ve aradaki bosluk DOLAYLI (kutu genisligi eksi ikon
        //	genisliginin yarisi) belirleniyordu — yani sayilar ekranda ne
        //	oldugunu ANLATMIYORDU.
        //
        //	YENI: kisit SIFIRLANIR, bosluklar ikonun KENDI `Padding`inde
        //	yazilir. Artik sayilar birebir ekranda gordugun mesafedir:
        //	  · sol kenar -> ikon      : **16**
        //	  · ikon -> "İşletme ara"  : **10**
        //	  · dikey (yukseklik ~48)  : **14**
        // ⚠️ `contentPadding` yatayda **0**: yatay bosluklarin TEK sahibi
        //    ustteki `Padding` olsun; iki yerden beslenirse toplam mesafe
        //    "neden 24 cikti" sorusuna donusur.
        // ⚠️⚠️⚠️ TURU 96d — YUKSEKLIGI ARTIK **BU KUTU** BELIRLIYOR.
        //	Filtre ikonu (suffix) cip seridine tasindi; o kutu inputun
        //	yuksekligini tasiyordu (bkz. ustteki serh). Bu \n        //	olmadan cerceve 48 -> **33 dp**ye duser ve input yanindaki
        //	olculerle yeniden AYRISIRDI.
        // ⚠️ YAPMA: bu i kaldirma.
        prefixIcon: SizedBox(
          height: kInputBoy,
          child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(
            LucideIcons.search,
            size: 21,
            color: ikonRenk,
            shadows: [
              for (final d in const [
                Offset(0.4, 0),
                Offset(-0.4, 0),
                Offset(0, 0.4),
                Offset(0, -0.4),
              ])
                Shadow(color: ikonRenk, offset: d),
            ],
          ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        // ⚠️⚠️⚠️ TURU 96o — **TEMIZLE (X)** (kullanici emri: *"inputta bir sey
        //	yazdiginda inputun saginda x isareti olsun, arkasinda hafif gri
        //	daire olacak, x isareti ikonu bir tik kalin olsun"*).
        //
        // ⚠️ YALNIZ METIN VARKEN cizilir: bos kutuda X gostermek "neyi
        //    temizleyecegim" sorusu dogurur ve dokunma alanini bosa harcar.
        // ⚠️ Kalinlik `strokeWidth` ILE VERILEMEZ — `lucide_icons_flutter`
        //    ikonlari bir FONT olarak sunar (glif), SVG degil. Kalinlik ayni
        //    renkte ±0.4 px kaydirilmis DORT GOLGE ile simule edilir
        //    (turu 93'te olculen tek yol).
        // ⚠️ Dokunma alani 32x32 daireden BUYUK tutulur (`padding`), yoksa
        //    parmak ucu kaciriyor.
        suffixIcon: !_aramaDolu
            ? null
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _aramaTemizle,
                // ⚠️⚠️⚠️ GENISLIK **ACIKCA** VERILIR (44). Ilk yazimda yalniz
                //	`height` verilmisti ve `suffixIconConstraints`in
                //	`minWidth: 0`i yaniltici cikti: `InputDecorator` suffix'e
                //	KALAN GENISLIGIN TAMAMINI veriyor, icteki `Center` de
                //	daireyi o genis kutunun ORTASINA koyuyordu.
                //	SONUC (emulatorde olculdu): X **inputun tam ortasinda**
                //	duruyor ve **yaziya hic yer kalmadigi icin metin
                //	GORUNMUYORDU**.
                // ⚠️ YAPMA: bu genisligi kaldirip `Center`a guvenme.
                child: SizedBox(
                  height: kInputBoy,
                  width: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 12),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // "hafif gri daire"
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          LucideIcons.x,
                          size: 15,
                          color: ikonRenk,
                          shadows: [
                            for (final d in const [
                              Offset(0.4, 0),
                              Offset(-0.4, 0),
                              Offset(0, 0.4),
                              Offset(0, -0.4),
                            ])
                              Shadow(color: ikonRenk, offset: d),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        isDense: true,
        // ⚠️ DIKEY DOLGU **0**: yukseklik suffix kutusundan geliyor (bkz.
        //    `kInputBoy`). Burada da deger yazilsaydi ikisi TOPLANIR ve
        //    input dairelerden UZUN olurdu.
        contentPadding: const EdgeInsets.only(right: 8),
        // ⚠️⚠️⚠️ TURU 174 — **KENARLIK KALDIRILDI** (kullanici emri:
        //	*"aramayi bordersiz yap"*).
        //
        // ⚠️⚠️ Kenarligi kaldirmak TEK BASINA YETMEZ: siyah zeminde
        //	cercevesiz ve dolgusuz bir `TextField` **GORUNMEZ**
        //	olur — kullanici oraya dokunulabilecegini anlayamaz.
        //	Yerine hafif bir DOLGU kondu; kutu duruyor, cizgi yok.
        // ⚠️ `InputBorder.none` UC HALDE DE verilir (enabled/focused/
        //	border): yalniz birini bosaltmak odaga girince cizginin
        //	geri gelmesine yol acar.
        filled: true,
        fillColor: kInputZemin,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap(kInputBoy)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap(kInputBoy)),
          borderSide: BorderSide.none,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kYaricap(kInputBoy)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96b — **KESIF KARTLARI: 4 x 2 = 8** (kullanici emri:
  ///	*"döner kebap kartlari yerine 4 tane soldan saga dogru, ama daha
  ///	buyuk kart seklinde 'Ne Yesem?', 'İndirimli Restoranlar' gibi; 4
  ///	altina 4, 8 tane kart olacak, isimlerini sen bul"*).
  ///
  /// ⚠️⚠️ **SEKIZININ DE ARKASINDA GERCEK BIR DAVRANIS VAR.** Bu projede
  ///	"arayuz var, veri yok" en pahali hata sinifi (filtre panelinde
  ///	"Ödeme Yöntemleri"ni tam bu yuzden cizmedik). Her kart, ZATEN
  ///	calisan bir suzgece/siralamaya/ekrana baglandi:
  ///	  Ne Yesem?     -> listeden RASTGELE bir isletme acar
  ///	  İndirimli     -> `kampanyali` suzgeci
  ///	  Yüksek Puanlı -> `puan >= 4,5`
  ///	  En Hızlı      -> teslimat suresine gore siralama
  ///	  Yakınımda     -> mesafeye gore siralama
  ///	  Şu An Açık    -> calisma saatine gore suzgec
  ///	  Uygun Fiyatlı -> `min. tutar <= 150 TL`
  ///	  Favorilerim   -> favoriler ekrani
  /// ⚠️ YAPMA: buraya davranisi olmayan "guzel duran" bir kart ekleme.
  ///
  /// ⚠️⚠️ ETIKETLER ISTEMCIDE (alt kategorilerin AKSINE) ve bu BILINCLI:
  ///	alt kategoriler VERIDIR (her kategoride baska mutfaklar var, sunucu
  ///	doldurur — turu 92 kurali). Bunlar ise DAVRANIS: her biri istemcideki
  ///	bir suzgec alanina baglaniyor, sunucudan gelen bir metin o alani
  ///	YARATAMAZ. Suzgecler sunucuya tasindiginda bu liste de oraya taşınır.
  /// ⚠️ "Ne Yesem?" YALNIZ yemek kategorisinde; digerlerinde "Sürpriz"
  ///    (kuaförde "Ne Yesem?" yazmak sacma olurdu).
  // TURU 174 - cagri yerinden CIKARILDI (kullanici emri: *"NE YESEM diye
  //	buyuk kartlari kaldir"*). Govde SILINMEDI.
  // ignore: unused_element
  Widget _kesifIzgarasi() {
    final f = _filtre;
    final kartlar = <({String ad, bool secili, VoidCallback ac})>[
      (
        ad: _kategori == 'yemek' ? 'Ne Yesem?' : 'Sürpriz',
        secili: false,
        ac: _rastgeleAc,
      ),
      (
        ad: 'İndirimli',
        secili: f.kampanyali,
        ac: () => _suzgecDegistir(() => f.kampanyali = !f.kampanyali),
      ),
      // ⚠️ ETIKET **4+** oldugu icin esik de 4.5 -> **4.0**: kart "4+" deyip
      //    4.5 suzseydi etiket YALAN SOYLERDI.
      (
        ad: '4+',
        secili: f.puanTaban == 4.0,
        ac: () => _suzgecDegistir(() => f.puanTaban = f.puanTaban == 4.0 ? null : 4.0),
      ),
      (
        ad: 'Şimşek',
        secili: f.siralama == Siralama.teslimat,
        ac: () => _suzgecDegistir(() => f.siralama = f.siralama == Siralama.teslimat
            ? Siralama.onerilen
            : Siralama.teslimat),
      ),
      (
        ad: 'Yakınımda',
        secili: f.siralama == Siralama.mesafe,
        ac: () => _suzgecDegistir(() => f.siralama = f.siralama == Siralama.mesafe
            ? Siralama.onerilen
            : Siralama.mesafe),
      ),
      // ⚠️⚠️ "Gece Kuşu" = **GEC SAATE KADAR ACIK**, "su an acik" DEGIL.
      //	Etiket degisince YUKLEM DE degisti: bir kart "Gece Kuşu" deyip
      //	ogle vakti acik olan her yeri gostersendi ad YALAN olurdu.
      //	Olcut `calisma`dan turuyor (kapanis >= 23:00 ya da gece yarisini
      //	asan mesai) — yeni veri GEREKMEDI.
      (
        ad: 'Gece Kuşu',
        secili: f.geceAcik,
        ac: () => _suzgecDegistir(() => f.geceAcik = !f.geceAcik),
      ),
      // ⚠️⚠️⚠️ "Yeni Restourant" — **DURUST SINIR**. Sunucu liste sorgusu
      //	`ORDER BY u.onayli DESC, u.name ASC` ile siraliyor ve yanitta
      //	KAYIT TARIHI YOK; yani "en yeni" gercekten hesaplanamiyor.
      //	Elde kalan tek durust gosterge: **puani henuz olmayan** isletme
      //	(yeni acilan yerin degerlendirmesi olmaz).
      // ⚠️ Kart bos donebilir ve bu BOZUKLUK DEGIL: tohum verisindeki tum
      //    isletmelere puan yazili. Gercek yeni kayitta gorunur.
      // ⚠️ TAM COZUM: liste yanitina `created_at` eklemek (tek sutun,
      //    `enlem`/`boylam` ile ayni desen) — backend turuna birakildi.
      // ⚠️ YAPMA: bu karti "min. tutar <= 150"e baglayip "Yeni" demek —
      //    etiketle yuklem AYRISIR ve kullanici yanlis bilgi alir.
      (
        // ⚠️ TURU 135 — YAZIM DUZELTMESI: "Restourant" -> **"Restoran"**
        //    (turu 121d denetiminden beri bekleyen listede duruyordu).
        //    Etiket YALNIZ ekranda gorunur; suzgec anahtari `f.puansiz`
        //    oldugu icin sunucu sozlesmesine DOKUNMAZ.
        // ⚠️ Kartin YEMEGE OZEL olmasi ayri bir konu ve HALA BEKLIYOR
        //    (Egitim/Otel/Saglik ekranlarinda anlamsiz duruyor) — o karar
        //    kullanicinin.
        ad: 'Yeni Restoran',
        secili: f.puansiz,
        ac: () => _suzgecDegistir(() => f.puansiz = !f.puansiz),
      ),
      (
        ad: 'Favori',
        secili: false,
        ac: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FavorilerimEkrani()),
        ),
      ),
    ];
    // ⚠️ Hucre genisligi EKRANDAN turetilir: sabit yazilsaydi 360dp'lik
    //    telefonda dorduncu kart TASARDI.
    // ⚠️⚠️⚠️ TURU 96e — KUTU 10px DAR **AMA HIZA BOZULMADAN**.
    //
    //	ILK DENEME kutuya `margin: horizontal 5` vermekti ve HIZAYI BOZDU:
    //	kutunun sol kenari 16 yerine **21 dp**ye kayiyordu — kullanici
    //	fark etti (*"sol sag container icinde olanlar ayni hizada degil"*).
    //
    //	DOGRUSU: hucreyi daralt, ARTAN YERI ARALIGA VER. Boylece ilk
    //	kutunun sol kenari tam `kYanBosluk`, sonuncununki tam `W-kYanBosluk`
    //	kalir ve kutular gercekten 10px darallir.
    // ⚠️ Aralik SABIT DEGIL, TURETILIR: dar ekranda da dort kutu tam otursun.
    // ⚠️⚠️⚠️ TURU 96k — **ARALIK SECILIR, HUCRE TURETILIR** (onceden tersiydi).
    //
    //	Eski hesap: `en = alan/4 - 10` · `aralik = (alan - en*4)/3`
    //	Yani aralik, "hucreyi 10 daralt" emrinin bir YAN URUNUYDU ve
    //	**13.3 dp** cikiyordu; ayni izgaranin SATIR araligi ise
    //	`kKesifSatirAralik = 12` idi. Ayni izgarada yatay 13.7 / dikey 12.2
    //	olcen kullanici hakli olarak "bosluklar esit degil" dedi.
    // ⚠️ Artik IKI EKSEN DE `kIzgaraAralik`: once aralik konur, kalan yer
    //    dorde bolunur. Hucre ~1 dp genisler (84.9 -> 85.9) — kullanicinin
    //    "10px daralt" istegi pratikte korunur, ama izgara KARE bir ritme
    //    oturur.
    final alan = MediaQuery.sizeOf(context).width - kYanBosluk * 2;
    const aralik = kIzgaraAralik;
    final en = (alan - aralik * 3) / 4;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
      child: Column(
        children: [
          for (var satir = 0; satir < 2; satir++) ...[
            // ⚠️ Satir araligi = sutun araligi (turu 96k): izgara icindeki
            //    ritim TEK sayidir.
            if (satir > 0) const SizedBox(height: kIzgaraAralik),
            Row(
              // ⚠️⚠️⚠️ TURU 96g — **`start` ZORUNLU** (kullanici: *"Yeni
              //	Restourant karti yukari kalmis, onu duzelt"*).
              //
              //	`Row`un varsayilani `center`: hucreler FARKLI YUKSEKLIKTE
              //	oldugunda (etiket bir satir mi iki satir mi) dikeyde
              //	ORTALANIR. "Yeni Restourant" iki satira sardigi icin o
              //	hucre daha uzun, ORTALANINCA da GRI KUTUSU yukari kaydi.
              //	`start` ile tum kutular AYNI ust hizada; farkli olan
              //	yalnizca etiketin alt tarafi.
              // ⚠️ YAPMA: bunu kaldirma; iki satirlik bir etiket eklendigi
              //    an ayni kayma geri gelir.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var s = 0; s < 4; s++) ...[
                  if (s > 0) SizedBox(width: aralik),
                  SizedBox(
                    width: en,
                    child: _kesifKarti(kartlar[satir * 4 + s]),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Tek kesif karti — gri kutu + ikon, ALTINDA ad.
  ///
  /// ⚠️ Ad kutunun ICINE yazilmaz: "Yüksek Puanlı" ~89dp'lik bir kutuya tek
  ///    satirda SIGMAZ; disarida iki satira sarabilir (60x60 kartlarla ayni
  ///    desen).
  /// ⚠️ Secili hal **KENARLIK** (yesil dolgu DEGIL — bkz. `kVurgu`), ve
  ///    kutuyu BUYUTMEZ.
  Widget _kesifKarti(
      ({String ad, bool secili, VoidCallback ac}) k) {
    final vurgu = kVurgu(context);
    return Semantics(
      button: true,
      selected: k.secili,
      label: k.ad,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: k.ac,
        child: Column(
          children: [
            Container(
              height: kKesifKutu,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _yuzey,
                borderRadius: BorderRadius.circular(kYaricap(kKesifKutu)),
                border:
                    k.secili ? Border.all(color: vurgu, width: 1.6) : null,
              ),
              // ⚠️⚠️ TURU 96c — **IKON KALDIRILDI** (kullanici emri: *"ne
              //	yesem vb. kartlardaki ikonlari kaldir"*). Kutu artik salt
              //	bir yuzey; ad ALTINDA yaziyor — 60x60 mutfak kartlariyla
              //	BIREBIR ayni dil.
              // ⚠️ YAPMA: buraya ikon ya da harf geri koyma (kullanici bu
              //    ekranda kutu icine kondan HER SEYI uc kez kaldirtti).
            ),
            const SizedBox(height: 5),
            // ⚠️⚠️⚠️ ETIKET ALANI **SABIT IKI SATIR** (turu 96k).
            //
            //	Onceden yukseklik ICERIGE gore degisiyordu: "Yeni Restourant"
            //	iki satira sardigi icin o hucre **115**, digerleri **99** dp
            //	oluyordu. `Row` yuksekligini EN UZUN hucre belirledigi icin
            //	izgaranin altindaki bosluk sutundan sutuna **32 ile 48 dp**
            //	arasinda degisiyor, goz bunu "boslukar esit degil" diye
            //	okuyordu (kullanici olculeri sorunca ortaya cikti).
            // ⚠️ Iki satirlik yer HER hucrede AYRILIR ve tek satirlik
            //    etiketler bu alanda DIKEYDE ORTALANIR; boylece tum hucreler
            //    ayni yukseklikte olur ve izgaranin alt sinirî DUZ olur.
            // ⚠️ Yukseklik ELLE YAZILMAZ, yazi olceginden TURETILIR: kullanici
            //    yazi boyutunu buyutunce alan da buyumeli (turu 90b'de sabit
            //    92px'lik bir serit yazi olcegi 1.15'te tasmisti).
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(14) * 1.15 * 2,
              child: Center(
                child: Text(
              k.ad,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // ⚠️ TURU 96g — 12 -> **14** (kullanici emri: *"slider
                //    altindaki kartlardaki yazilari 2px buyut"*).
                fontSize: 14,
                height: 1.15,
                // ⚠️ KALINLIK SABIT: degisseydi metin genisleyip satiri
                //    kaydirirdi (ciplerde yasanan hata).
                fontWeight: FontWeight.w600,
                color: k.secili ? vurgu : null,
              ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 96h — SUZGEC DEGISTIRMENIN **TEK KAPISI**.
  ///
  ///	Suzgecler artik SUNUCUDA uygulaniyor (LIMIT 60 sorunu). Kesif
  ///	kartlari eskiden yalniz setState cagiriyordu; sunucuya tasindiktan
  ///	sonra bu, kartin GORUNURDE secilip listenin DEGISMEMESI demek
  ///	olurdu — yani "kart calismiyor".
  /// ⚠️ Istek YALNIZ sunucu imzasi degistiyse atilir: siralama ve saat
  ///    suzgecleri istemcide uygulaniyor, bosuna ag trafigi olurdu.
  /// ⚠️ YAPMA: kart/cip icinde dogrudan setState ile filtre alani yazma;
  ///    bu kapidan gec.
  void _suzgecDegistir(void Function() degistir) {
    final onceki = _filtre.sunucuImzasi;
    setState(degistir);
    if (_filtre.sunucuImzasi != onceki) _yukle();
  }

  /// "Ne Yesem?" — elindeki listeden RASTGELE bir isletme acar.
  ///
  /// ⚠️ Liste BOSSA hicbir sey yapmaz ama kullaniciya SEBEP soylenir:
  ///    sessizce hicbir sey olmamasi "dugme bozuk" hissi verirdi.
  /// ⚠️ **SUZULMUS** listeden secer (`_gosterilen`): kullanici bir filtre
  ///    acmissa "rastgele" onun disina cikmamali.
  void _rastgeleAc() {
    final l = _gosterilen ?? const <IsletmeOzet>[];
    if (l.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Önce listede işletme olmalı.'),
      ));
      return;
    }
    final o = l[DateTime.now().microsecondsSinceEpoch % l.length];
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
    );
  }

  /// ⚠️⚠️ TURU 92 — ALT KATEGORI KARTLARI (kullanici emri: *"aramanin
  ///    altinda soyle kartlar olacak, UFAK kartlar 60x60 RADIUSLU, iste
  ///    doner kebap gibi"*).
  ///
  /// ⚠️⚠️ **BU SERH TURU 180ae'DE GECERSIZ KALDI** (asagidaki blok gecerli):
  ///	*"Kart 60x60 KARE + altinda ad"* artik DOGRU DEGIL — kartlar CIPE
  ///	cevrildi ve ad KUTUNUN ICINDE yaziliyor. Yanlis yonlendirmesin diye
  ///	silinmeyip isaretlendi (bu projenin en sik hata sinifi: *serhin
  ///	anlattigi sey GOVDEDE YOK*).
  /// ⚠️ Liste BOSSA serit HIC CIZILMEZ — her kategoride alt kategori yok
  ///    (bos yatay bosluk birakmiyoruz).
  /// ⚠️ Secili kart TEK: ikinci karta basmak oncekini kapatir. Coklu secim
  ///    "döner kebap" gibi ikisini birden iceren bir arama uretir ve
  ///    neredeyse DAIMA BOS sonuc doner.
  /// ⚠️⚠️⚠️ TURU 180ae — **MUTFAK KARTLARI ARTIK BUTON (CIP)** (kullanici
  ///	emri: *"mutfağın altındaki kartları filtredeki gibi buton yap, onları
  ///	%15 kadar daha büyük olsun"*).
  ///
  /// ═══════════ NE DEGISTI ═══════════
  ///
  /// Onceki hal: 70x70 gri KUTU + altinda IKI SATIRA sarabilen ad. Bu yuzden
  /// serit yuksekligi `TextPainter` ile OLCULUYORDU (iki satira saran bir ad
  /// seridi tasirmasin diye — turu 93b/96/135'te uc kez sahaya cikti).
  ///
  /// Yeni hal: filtre cipleriyle (`_hizliCip`) **AYNI DIL** — kenarlikli hap,
  /// TEK SATIR yazi, zemin dolgusu YOK, secili halde kenarlik `_notrYazi`.
  ///
  /// ⚠️⚠️ **`TextPainter` OLCUMU ARTIK GEREKMIYOR** ve bu bir sadelestirme
  ///	DEGIL, YAPISAL bir kazanc: yazi tek satir oldugu icin yukseklik
  ///	YALNIZCA yazi olceginden turer. (Eski olcum, olcum stili yazi tipini
  ///	tasimadigi icin turu 135'te TAM BIR SATIR sasirmisti.)
  /// ⚠️ Yine de yukseklik SABIT DEGIL: `textScaler`dan turetilir — sabit 37
  ///	yazilsaydi ilk yazi olcegi kademesinde bile metin dikeyde kirpilirdi.
  /// ⚠️ `kAltKutu`/`kAltHucre`/`kAltIcBosluk` sabitleri SILINMEDI: ilan ve
  ///	talep ekranlari onlari HALA kullaniyor (kullanici yalniz YEMEK
  ///	ekranini degistirmek istedi).
  Widget _altKategoriSeridi() {
    if (_altKategoriler.isEmpty) return const SizedBox.shrink();
    final olcek = MediaQuery.textScalerOf(context);
    // ⚠️ 1.252 = Google Sans Flex satir kutusu carpani (turu 180i'de TTF
    //    metriklerinden OLCULDU); +16 dikey dolgu payi.
    // ⚠️ `dart:math` BILEREK import EDILMEDI (bu dosyada baska kullanimi yok):
    //    alt sinir ucluyle uygulanir.
    final ham = olcek.scale(kAltCipYazi) * 1.252 + 16;
    final boy = (ham < kAltCipBoy ? kAltCipBoy : ham).ceilToDouble();
    return SizedBox(
      height: boy,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // ⚠️ Yatay dolgu artik TAM `kYanBosluk`: eski kod `- kAltIcBosluk`
        //    dusuyordu cunku kutu, hucrenin ORTASINDA duruyordu. Cipte boyle
        //    bir ic bosluk YOK — dusulseydi serit slider/arama kutusundan
        //    6 dp SOLDA baslardi.
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        itemCount: _altKategoriler.length,
        itemBuilder: (_, i) {
          final a = _altKategoriler[i];
          final secili = _altSecili == a.ara;
          return Padding(
            // ⚠️ Cipler arasi aralik `_hizliCip` ile BIREBIR ayni (8).
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              button: true,
              selected: secili,
              label: a.ad,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _altSecili = secili ? '' : a.ara);
                  // ⚠️ TURU 93b — BEKLEYEN ARAMA ZAMANLAYICISI IPTAL EDILIR:
                  //    kullanici yazip hemen cipe basarsa 320ms'lik timer
                  //    ikinci bir istek daha atardi.
                  _gecikme?.cancel();
                  _yukle();
                },
                child: Container(
                  height: boy,
                  padding:
                      const EdgeInsets.symmetric(horizontal: kAltCipDolgu),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(kYaricap(boy)),
                    // ⚠️⚠️ SECILI HAL **YALNIZ KENARLIK RENGI** (filtre
                    //	cipleriyle ayni karar): zemin dolgusu ya da degisken
                    //	`fontWeight`/`width` yerlesimi degistirir ve serit
                    //	her dokunusta YANA KAYARDI (turu 96'da olculdu).
                    // ⚠️ YAPMA: buraya `color:` (zemin) geri koyma.
                    border:
                        Border.all(color: secili ? _notrYazi : _notrKenar),
                  ),
                  // ⚠️⚠️ `Row(mainAxisSize.min)` ZORUNLU — `alignment:` DEGIL.
                  //	`Container`a `alignment` verilince cocugu bir `Align`e
                  //	sarar ve `Align` GEVSEK kisitta EN BUYUK BOYUTU ALIR;
                  //	yatay `ListView`de genislik kisiti SINIRSIZ oldugu icin
                  //	bu SONSUZ GENISLIK demektir (turu 138/180t tuzagi).
                  //	`Row` hem genisligi icerikten alir hem cocugu dikeyde
                  //	ORTALAR.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.ad,
                        // ⚠️ TEK SATIR: cip dili iki satir tasimaz; asiri
                        //    uzun bir ad KIRPILIR, serit BUYUMEZ.
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: kAltCipYazi,
                          color: _notrYazi,
                          // ⚠️ KALINLIK SABIT (bkz. yukaridaki serh).
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ⚠️⚠️ TURU 92 — FILTRE SATIRI (kullanici emri: *"altinda FILTRELEME
  ///    BUTONU, saginda da genel olarak kullanilan filtrelemeler"*).
  ///
  /// SOLDA sabit "Filtrele" dugmesi (tum secenekleri alttan sheet'te acar),
  /// SAGINDA yatay kayan SIK KULLANILANLAR.
  /// ⚠️ Solraki dugme KAYMAZ (`Row` + `Expanded`): kullanici filtreyi
  ///    ararken seridi kaydirmak zorunda kalmamali.
  /// ⚠️⚠️⚠️ TURU 136 — **FILTRE SERIDININ USTUNDE YATAY ISLETME SERIDI**
  ///	(kullanici emri, DUZELTME: *"yemege tikladigimda mesela ISLETMELER
  ///	kart seklinde filtrenin uzerinde cikmasi gerekiyordu, sol sag
  ///	scroll"*).
  ///
  /// ⚠️⚠️ **TURU 135'TE YANLIS ANLASILDI:** buraya "İşletmen mi var?" diye
  ///	bir ISLETME HESABI kisayolu konmustu. Kullanici isletme HESABINI
  ///	degil **ISLETMELERIN KENDISINI** kart olarak istiyormus. O kart
  ///	KALDIRILDI; hesap girisi zaten Ayarlar > Isletme hesabi ve profil
  ///	sayfasinda DURUYOR (ulasilamaz kalmadi).
  ///
  /// ⚠️ VERI UYDURULMAZ: serit, listenin beslendigi AYNI kumeden
  ///    (`_gosterilen`) beslenir — suzgecler seride de uygular ve kullanici
  ///    seritte gordugu yeri listede de bulur. Ayri bir istek ATILMAZ.
  /// ⚠️ Liste BOSSA serit HIC cizilmez (bos gri bir serit "yukleniyor" gibi
  ///    okunurdu).
  ///
  /// ⚠️⚠️ **YUKSEKLIK TASMAYA KAPALI:** kapak `Expanded` icinde, metinler
  ///	SABIT. Yazi olcegi 1.3/2.0'da metin buyur, KAPAK KUCULUR ve toplam
  ///	boy DEGISMEZ — `Column` hicbir olcekte tasamaz. (Sabit kapak +
  ///	esnek metin yazilsaydi 2.0'da sari-siyah serit cikardi; bu ekranda
  ///	ayni sinif turu 121/123/135b'de UC KEZ olculdu.)
  /// ⚠️ Boy yine de yazi olceginden TURETILIR ki olcek 1.0'da kapak 16:9 kalsin.
  // TURU 174 - cagri yerinden CIKARILDI (kullanici emri: *"mutfagin
  //	altinda isletme kartlari var onlari kaldir"*). Govde
  //	SILINMEDI.
  // ignore: unused_element
  Widget? _isletmeSeridi() {
    final l = _gosterilen;
    if (l == null || l.isEmpty) return null;
    // ⚠️ Serit bir VITRIN: ilk N kayit. Tamami zaten ALTTAKI listede.
    //    Sinir olmasaydi 60 kart yan yana decode edilirdi (turu 91 dersi).
    final ogeler = l.take(kSeritTavan).toList();
    final olcek = MediaQuery.textScalerOf(context);
    // ad (14 x 1.2) + 2 + vitrin satiri (12 x 1.2) + 7 (kapak-ad araligi)
    final yaziBoy = olcek.scale(14) * 1.2 + 2 + olcek.scale(12) * 1.2 + 7;
    // ⚠️ Kart eni EKRANDAN SINIRLANIR: 320 dp'lik bir telefonda sabit 200 dp
    //    ekranin %63'unu yer ve "yandaki kart" ipucu kaybolurdu. `dart:math`
    //    import edilmedi — tek karsilastirma icin gereksiz bagimlilik.
    final tavan = MediaQuery.sizeOf(context).width * 0.62;
    final en = kSeritKartEn < tavan ? kSeritKartEn : tavan;
    return SizedBox(
      height: en * 9 / 16 + yaziBoy,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // ⚠️ Yan dolgu ekranin geri kalaniyla AYNI (`kYanBosluk`): serit
        //    kaydirilmadan once ilk kart arama kutusuyla HIZALI durur.
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        physics: const BouncingScrollPhysics(),
        itemCount: ogeler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _seritKarti(ogeler[i], en),
      ),
    );
  }

  /// Seritteki tek kart — izgara kartinin DAR surumu.
  ///
  /// ⚠️ Parcalar KOPYALANMADI, ORTAK: kapak yer tutucusu, kampanya rozetleri
  ///    ve `vitrinSatiri` izgara kartiyla AYNI fonksiyonlardan gelir.
  /// ⚠️ `width:` `MedyaGorsel`e ACIKCA verilir: yoksa 200 dp'lik bir kutu
  ///    icin tam cozunurlukte decode edilir (turu 91 performans dersi).
  Widget _seritKarti(IsletmeOzet o, double en) {
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    return SizedBox(
      width: en,
      child: InkWell(
        borderRadius: BorderRadius.circular(kYaricapBuyuk),
        // ⚠️ Hedef izgara/liste kartiyla AYNI: kullanici ayni yere iki
        //    farkli yoldan girip farkli ekran gormemeli.
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ⚠️ `Expanded`: yazi olcegi buyudukce KAPAK kuculur, kart
            //    yuksekligi sabit kalir (bkz. `_isletmeSeridi` serhi).
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(kYaricapBuyuk),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    gorselID.isEmpty
                        ? _kapakYerTutucu(o)
                        : MedyaGorsel(
                            mediaId: gorselID,
                            fit: BoxFit.cover,
                            width: en,
                          ),
                    kampanyaRozetleri(o),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Flexible(
                  child: Text(
                    o.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (o.dogrulandi)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(LucideIcons.badgeCheck,
                        size: 13, color: kOnayliRengi),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            vitrinSatiri(context, o, kompakt: true),
          ],
        ),
      ),
    );
  }


  /// ⚠️ TURU 180af — CAGRI YERI KAPATILDI (hizli suzgec seridi kalkti).
  ///	Govde DURUYOR: geri istenirse tek satirla sliver'a eklenir ve
  ///	`_bolumCipi`/`_hizliCip` da onunla birlikte canlanir.
  // ignore: unused_element
  Widget _filtreSatiri() {
    return Padding(
      // ⚠️ TURU 93b — `12` idi -> `kYanBosluk` (dosya basindaki "elle yatay
      //    dolgu YAZMA" serhinin ikinci ihlali; "Filtrele" dugmesi arama
      //    kutusundan 4px solda duruyordu).
      // ⚠️ Sag 0 KALIR: sagdaki serit YATAY KAYIYOR, sag dolgu son cipi
      //    kirpiyormus gibi gosterirdi.
      // ⚠️ IC DIKEY DOLGU YOK; sag 0 KALIR (serit yatay kayiyor, sag dolgu
      //    son cipi kirpiyormus gibi gosterirdi).
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, 0, 0),
      child: Row(
        children: [
          // ⚠️ TURU 94 — "Filtrele" DUGMESI **KALDIRILDI** (kullanici emri).
          //    Kategori secimi artik hamburger menusunden ve secili kategori
          //    cipinden yonetiliyor; ekranda IKI AYRI kategori kapisi vardi.
          // ⚠️ YAPMA: bu satira yeni bir "Filtrele" dugmesi geri koyma.
          Expanded(
            child: SizedBox(
              // ⚠️ TURU 93b — 36 -> 48 (denetim). `FilterChip` varsayilan
              //    `materialTapTargetSize: padded` ile **48dp**lik dokunma
              //    alani ister; ebeveyn 36'ya kesince hedef Material 48 /
              //    Apple 44 kuralinin ALTINA dusuyordu.
              // ⚠️ Eklenen 12px artik bir sorun degil: govde turu 93b'de
              //    KAYDIRILABILIR oldu, yani sabit dikey butce yok.
              // ⚠️ Cipler 32'ye indi; serit de 48 -> 40.
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // ⚠️⚠️ "YAKINIMDA" (kullanici emri: *"orada yakinimdaki vb
                  //	seyler olsun"*).
                  //
                  //	Bu cip HARITAYA GITMEZ; listeyi KONUMA GORE siralar
                  //	(`/isletmeler` yerine `/yakinimda` ucu). Ayri bir
                  //	ekran acsaydi "suzgec" degil "gezinme" olurdu ve
                  //	yanindaki ciplerle ayni dili konusmazdi.
                  // ⚠️ Konum izni YOKSA cip yine cizilir; dokununca izin
                  //    istenir ve reddedilirse durust bir mesaj gosterilir.
                  //    Cizmemek, ozelligin VARLIGINI gizlerdi.
                  // ⚠️⚠️⚠️ TURU 96d — FILTRE **BURAYA TASINDI** (kullanici
                  //	emri: *"inputtaki filtreyi Yakinimda vb. soluna ekle,
                  //	ikonun yanina Filtre yaz"*). Arama kutusunun icindeki
                  //	ikon KALDIRILDI.
                  // ⚠️ Kardes ciplerle AYNI bilesen (`_hizliCip` degil ama
                  //    ayni olcu/yaricap): serit tek bir dil konusmali.
                  // ⚠️ Aktif suzgec varsa **NOKTA** cizilir — kullanici
                  //    listenin neden kisaldigini gorebilmeli.
                  _filtreCipi(),
                  // ⚠️⚠️⚠️ TURU 96g — CIPLER ARTIK **FILTRE PANELININ BOLUM
                  //	BASLIKLARI** (kullanici emri: *"filtreler sagindaki
                  //	butonlara filtrelerdeki basliklar olsun, ekstra olarak
                  //	Onayli butonu olsun"*).
                  //
                  //	Her cip bir BOLUMU temsil eder; o bolumde secim varsa
                  //	**DEGERI YAZAR** ("Puan" -> "4,0+") ve kenarligi siyah
                  //	olur. Dokununca filtre panelini acar.
                  // ⚠️ Cip KENDI BASINA SUZMEZ: tek dokunusla "Puan"in hangi
                  //    esik olacagi (4+ mi 3+ mi) secilemez. Paneli acmak TEK
                  //    durust davranis; aksi halde cip bir degeri kendiliginden
                  //    secer ve kullanici sebebini bilemezdi.
                  // ⚠️ "Yakınımda" cipi KALDIRILDI: ayni is hem kesif kartinda
                  //    hem "Sıralama > Mesafe"de var; ucuncu kapi gereksizdi.
                  _bolumCipi(
                    'Sıralama',
                    LucideIcons.arrowUpDown,
                    _filtre.siralama == Siralama.onerilen
                        ? ''
                        : siralamaAdi(_filtre.siralama),
                  ),
                  _bolumCipi(
                    'Min. tutar',
                    LucideIcons.wallet,
                    _filtre.minTutarTavanKurus == null
                        ? ''
                        : '${_filtre.minTutarTavanKurus! ~/ 100} TL',
                  ),
                  _bolumCipi(
                    'Puan',
                    LucideIcons.star,
                    _filtre.puanTaban == null
                        ? ''
                        : '${_puanYaz(_filtre.puanTaban!)}+',
                  ),
                  _bolumCipi(
                    'Teslimat',
                    LucideIcons.clock,
                    _filtre.teslimatTavanDk == null
                        ? ''
                        : '${_filtre.teslimatTavanDk} dk',
                  ),
                  // ⚠️ "Onaylı" KENDI BASINA SUZER: tek degerli (acik/kapali),
                  //    panele gerek yok. Kullanici acikca istedi.
                  _hizliCip('onayli', 'Onaylı', LucideIcons.badgeCheck),
                  if (_benimIlce.isNotEmpty)
                    _hizliCip('sehrimde', _benimIlce, LucideIcons.mapPin),
                  // ⚠️ Kategori CIPLERI buraya TASINDI: eskiden ayri bir
                  //    44px'lik serit vardi ve ekranin ustunde ARKA ARKAYA
                  //    UC yatay serit (hizli kartlar + arama + kategoriler)
                  //    olusuyordu. Tek satirda birlesince liste 80px daha
                  //    erken basliyor.
                  // ⚠️⚠️ TURU 96d — SECILI KATEGORI CIPI ("Yemek x")
                  //	**KALDIRILDI** (kullanici emri: *"oradaki Yemek x
                  //	kaldir; tikladigimda doktor vb. geliyor, bunu
                  //	duzelt"*).
                  //
                  //	HAKLIYDI ve sebep yapisaldi: cipin isi kategoriyi
                  //	KALDIRMAKTI (`_kategoriSec('')`), yani "Yemek"
                  //	ekranindayken ona basmak TUM KATEGORILERI getiriyordu
                  //	— doktor, otel, kuafor hepsi. Kullanici bir SUZGEC
                  //	cipine bastigini sanip ekranin KIMLIGINI kaybediyordu.
                  // ⚠️ Kategori zaten header basliginda yazili ve hamburger
                  //    menusunden degistiriliyor; ucuncu bir kapiya gerek yok.
                  // ⚠️ YAPMA: bu cipi geri koyma.
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Notr renkler — arama kutusuyla AYNI dil (kullanici emri: yesil YOK).
  ///
  /// ⚠️ TEK KAYNAK: filtre dugmesi, hizli cipler ve secili kategori cipi
  ///    ayni iki degeri kullanir. Elle yazilsaydi biri guncellenip otekiler
  ///    unutulur ve ekranda IKI FARKLI vurgu rengi olusurdu.
  /// ⚠️⚠️ KENARLIK **ARAMA KUTUSUYLA BIREBIR AYNI** (kullanici emri:
  ///	*"border input gibi olacak"*).
  ///
  ///	Onceden cipler 0.16, arama kutusu 0.14 alfa kullaniyordu. Yan yana
  ///	duran iki eleman icin bu fark GORUNUR: cipler bir tik daha koyu
  ///	cizilip "baska bir bilesen" gibi duruyordu.
  /// ⚠️ Deger **TEK YERDE**: arama kutusu da bunu kullanir. Iki ayri sayi
  ///    yazilsaydi biri guncellenip oteki geride kalirdi — bu ekranda gri
  ///    tonda ZATEN yasandi.
  // ⚠️⚠️⚠️ TURU 174 — RENKLER **KOYUYA SABITLENDI**, temadan OKUNMUYOR.
  //
  //	Ekran artik `kKategoriZemin` (sabit siyah) uzerinde ve govde
  //	`Theme(ThemeData.dark())` ile sarildi. AMA bu getter'lar bir
  //	`State` uyesi ve `context` **State'in context'idir** — yani
  //	o `Theme`in **USTUNDE** kalir ve `Theme.of` UYGULAMANIN
  //	temasini cozer (turu 135c/138'de olculen tuzagin ta kendisi:
  //	*"bir alt agaci Theme ile sarmak YETMEZ — o agaci CIZEN
  //	metotlar da Theme'in ALTINDAKI context'i almali"*).
  //	Sonuc acik temada: siyah zemine **siyah yazi**.
  //
  // ⚠️ Metotlara `BuildContext c` eklemek yerine sabitlendi: bu ekran
  //	ARTIK HER ZAMAN siyah, yani temaya sorulacak bir sey KALMADI.
  // ⚠️ YAPMA: bunlari tekrar `Theme.of(context)`e baglama.
  Color get _notrKenar => Colors.white.withValues(alpha: 0.14);

  Color get _notrYazi => Colors.white;

  /// Ekranin kendi yuzey grisi — `kYuzeyGri`nin KOYU dali.
  ///
  /// ⚠️ Paylasilan yardimci da ayni tuzaga dusuyordu (State context'i);
  ///	burada tek kaynaga alindi. Deger `isletme_kart.dart`taki
  ///	koyu dalla BIREBIR ayni.
  Color get _yuzey => const Color(0xFF2A2A2E);

  /// Filtre cipi — serit BASINDA, panel acar.
  ///
  /// ⚠️ Kardes ciplerle **AYNI OLCU** (32 boy, `kYaricap(32)`, ayni dolgu):
  ///    serit tek bir dil konusmali. `_hizliCip` KULLANILAMAZ cunku bu cip
  ///    bir SUZGEC DEGIL, bir EKRAN acar — secili durumu yoktur.
  /// ⚠️ Aktif suzgec varsa **NOKTA**: kullanici listenin neden kisaldigini
  ///    gorebilmeli (eski input-ici ikonun rozeti buraya tasindi).
  Widget _filtreCipi() {
    final aktif = _filtre.aktifSayi > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        label: 'Filtre',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _filtreSheet,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kYaricap(32)),
                border: Border.all(color: aktif ? _notrYazi : _notrKenar),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cipIkon(LucideIcons.slidersHorizontal),
                  const SizedBox(width: 5),
                  Text(
                    'Filtre',
                    style: TextStyle(
                      fontSize: 13,
                      color: _notrYazi,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (aktif) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration:
                          BoxDecoration(color: _notrYazi, shape: BoxShape.circle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filtre panelinin bir BOLUMUNU temsil eden cip.
  ///
  /// [deger] bos ise yalniz baslik yazar (notr kenarlik); doluysa
  /// "Baslik · deger" yazar ve kenarlik SIYAH olur.
  /// ⚠️ Dokununca filtre panelini acar — cip kendi basina suzmez (gerekce
  ///    cagri yerindeki serhte).
  /// ⚠️ Kardes ciplerle AYNI olcu (32 boy, `kYaricap(32)`, ayni dolgu).
  Widget _bolumCipi(String baslik, IconData ikon, String deger) {
    final aktif = deger.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: aktif,
        label: aktif ? '$baslik: $deger' : baslik,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _filtreSheet,
          child: Center(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kYaricap(32)),
                border: Border.all(color: aktif ? _notrYazi : _notrKenar),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _cipIkon(ikon),
                  const SizedBox(width: 5),
                  Text(
                    aktif ? '$baslik · $deger' : baslik,
                    style: TextStyle(
                      fontSize: 13,
                      color: _notrYazi,
                      // ⚠️ KALINLIK SABIT: degisseydi metin genisler ve serit
                      //    yana KAYARDI (ciplerde yasanan hata).
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 96g — CIP IKONLARI **BIR TIK KALIN** (kullanici emri:
  ///	*"ikonlar 1px kalinlastirirsin"*).
  ///
  ///	`lucide_icons_flutter` ikonlari bir **FONT** olarak sunar (glif),
  ///	SVG degil — `strokeWidth` YOKTUR ve yazilsa DERLENMEZ. Kalinlik ayni
  ///	renkte ±0.4px kaydirilmis DORT golgeyle simule edilir; glif kendi
  ///	uzerine hafifce yayilir ve cizgi kalinlasir.
  /// ⚠️ TEK KAYNAK: serit uzerindeki HER cip bunu kullanir. Ayri ayri
  ///    yazilsaydi biri guncellenip otekiler ince kalirdi.
  /// ⚠️ TURU 96j — GOVDE `isletme_kart.dart`taki **`kalinIkon`**a tasindi
  ///    (TEK KAYNAK). Kullanici kart meta ikonlarinin da "filtre gibi"
  ///    olmasini isteyince ayni teknik iki dosyada birden gerekti; kopya
  ///    birakilsaydi biri guncellenip oteki ince kalirdi.
  /// ⚠️ YAPMA: buraya golge listesini geri kopyalama.
  Widget _cipIkon(IconData ikon) =>
      kalinIkon(ikon, olcu: 13, renk: _notrYazi);

  /// "4.0" -> "4,0" (Turkce ondalik ayraci).
  String _puanYaz(double p) => p.toStringAsFixed(1).replaceAll('.', ',');

  /// Hizli suzgec cipi.
  ///
  /// ⚠️⚠️ `FilterChip` YERINE ELDE CIZILDI (kullanici emri: *"alttaki
  ///	butonlar TAM RADIUS olsun, tikladiginda TITREME vs olmasin"*).
  ///
  ///	Material'in `FilterChip`i iki sorun uretiyordu:
  ///	  · `StadiumBorder` verilse bile ic dolgusu ve `labelPadding`i
  ///	    yuzunden kose yaricapi tam yuvarlak gorunmuyordu;
  ///	  · dokununca **dalga (ripple) + hafif olcek animasyonu** oynuyor,
  ///	    kullanicinin "titreme" dedigi his tam buydu.
  ///	Elde cizilen bir `Container` + `GestureDetector` ikisini de kokten
  ///	kaldirir ve yaricap ACIKCA yuksekligin yarisidir (= tam radius).
  ///
  /// ⚠️ `Semantics(button: true)` ZORUNLU: `FilterChip` bunu kendisi
  ///    veriyordu; ciplak `Container` ekran okuyucuda "dugme" olarak
  ///    duyurulmazdi.
  /// ⚠️ Dokunma alani 40dp — Material 48'in altinda ama serit yataydir ve
  ///    ciplerin arasi 8dp bosluktur; 48 yapmak serit yuksekligini
  ///    gereksiz buyutuyordu.
  Widget _hizliCip(String anahtar, String ad, IconData ikon) {
    final secili = _hizli == anahtar;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: secili,
        label: ad,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // ⚠️ TEK SECIM: ikinci cipe basmak oncekini KAPATIR. Coklu secim
            //    bos sonuclar uretip kullaniciyi "hic isletme yok" sanisina
            //    dusururdu.
            setState(() => _hizli = secili ? '' : anahtar);
            _yukle();
          },
          // ⚠️ DAHA MINIMAL (kullanici emri): 40 -> **32** yukseklik,
          //    yatay dolgu 14 -> 11, ikon 15 -> 13, yazi 14 -> 13.
          //    Yaricap yine yuksekligin yarisi (= tam radius).
          // ⚠️⚠️⚠️ TURU 96 — `Center` **ZORUNLU** (emulatorde olculdu).
          //	YATAY bir `ListView` cocuklarina DIKEYDE **TIGHT** kisit verir
          //	(= seridin yuksekligi, 40). Yani `Container(height: 32)`
          //	SESSIZCE 40'a GERILIYORDU: yaricap 16 kaliyor ama kutu 40
          //	oldugu icin kose "tam hap" DEGIL, kirpik gorunuyordu —
          //	kullanicinin *"radius mantigi ayni olmali"* dedigi sey buydu.
          //	`Center` kisiti GEVSETIR: kutu gercekten 32 olur ve dikeyde
          //	ortalanir; dokunma alani `GestureDetector` `Center`i sardigi
          //	icin 40 KALIR (erisilebilirlik kaybi YOK).
          // ⚠️ YAPMA: bu `Center`i kaldirma; serit yuksekligini cip
          //    yuksekligiyle esitleyerek "cozme" (dokunma alani duser).
          child: Center(
            child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              // ⚠️ Kart/kapak/input ile AYNI hafif yaricap (bkz. `kYaricap`).
              borderRadius: BorderRadius.circular(kYaricap(32)),
              // ⚠️⚠️⚠️ TURU 96 — SECILI HAL **YALNIZ SIYAH KENARLIK**
              //	(kullanici emri: *"yakinimda vb. bunlara tikladiginda
              //	border SIYAH olacak, tikladiginda patlama vb. oynama
              //	olmasin"*).
              //
              //	⚠️ ONCEKI HAL GERCEKTEN "OYNUYORDU": secilince yazi
              //	   `w500 -> w700`a cikiyordu ve **kalin yazi DAHA GENIS**
              //	   oldugu icin cipin genisligi degisiyor, yanindaki tum
              //	   cipler YANA KAYIYORDU. Ustelik zemin de doluyordu.
              //	   Kullanicinin "patlama" dedigi sey bu kaymaydi.
              //	⚠️ Yazi kalinligi artik SABIT (`w600`), zemin dolgusu YOK:
              //	   degisen TEK sey kenarlik rengi -> yerlesim BIREBIR ayni
              //	   kalir.
              // ⚠️ Kenarlik KALINLIGI da sabit (1): `Border.all` kalinligi
              //    kutu genisligine eklenir; 1 -> 1.5 yapmak yine kaydirirdi.
              // ⚠️ YAPMA: buraya `color:` (zemin) ya da degisken
              //    `fontWeight`/`width` geri koyma.
              border: Border.all(color: secili ? _notrYazi : _notrKenar),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _cipIkon(ikon),
                const SizedBox(width: 5),
                Text(
                  ad,
                  style: TextStyle(
                    fontSize: 13,
                    color: _notrYazi,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ FILTRE EKRANI — girisi ARAMA KUTUSUNUN ICINDEKI ikon.
  ///
  /// Kullanici once alttaki "Filtrele" dugmesini kaldirtti, sonra ayni islevi
  /// **input icinde** istedi; turu 96'da da tam sayfa bir panele cevirdi
  /// (%100 genislik, %95 yukseklik). Yani ozellik degil, GIRIS NOKTASI ve
  /// BICIM degisti.
  /// ⚠️ EKRANDA TEK FILTRE KAPISI VAR: burasi (turu 90b `OlusturFab` dersi:
  ///    ayni ise iki giris koymak, birinin ULASILAMAZ kalmasiyla bitiyor).
  /// ⚠️⚠️ KATEGORI SECIMI BU PANELE **KONMADI**: kategori zaten (a) ekranin
  ///    basligi, (b) hamburger menusu ve (c) cip seridindeki "Yemek ×" ile
  ///    yonetiliyor. Panele DORDUNCU bir kapi eklemek, kategori degisiminin
  ///    tetikledigi `_kategoriSec` -> `_kesfiYukle` zincirini (alt
  ///    kategoriler + slaytlar KATEGORIYE OZEL) bir yerden atlamak demekti.
  /// ⚠️ Suzgecler ISTEMCIDE uygulaniyor (gecici) — gerekce ve durust sinir
  ///    `isletme_filtre.dart` dosyasinin basinda YAZILI.
  Future<void> _filtreSheet() async {
    final onceki = _filtre.sunucuImzasi;
    await isletmeFiltreAc(context, _filtre);
    // ⚠️ Sunucuya YENI ISTEK ATILMAZ: suzgecler istemcide uygulaniyor ve ham
    //    liste degismiyor; yalnizca yeniden cizilir (nokta + liste guncel
    //    kalsin). Suzgecler sunucuya tasindiginda BURAYA `_yukle()` gelecek.
    if (!mounted) return;
    // ⚠️⚠️ TURU 96h — SUNUCU SUZGECI DEGISTIYSE **YENIDEN SORULUR**.
    //    Suzme artik sunucuda; yalniz yeniden cizmek eski listeyi
    //    gosterirdi ve kullanici "filtre calismiyor" derdi.
    // ⚠️ Yalniz SIRALAMA/saat suzgeci degistiyse istek ATILMAZ: onlar
    //    istemcide uygulaniyor ve bosuna ag trafigi olurdu.
    if (_filtre.sunucuImzasi != onceki) {
      _yukle();
    } else {
      setState(() {});
    }
  }

  /// Kapak da avatar da yoksa: kategori renginde gradyan + isletme adinin
  /// bas harfi.
  ///
  /// ⚠️ Renk ADDAN turetilir (kategoriden DEGIL): ayni kategorideki tum
  ///    kartlar ayni renk olsaydi liste tekduze bir blok gibi gorunurdu.
  /// Izgara gorunumundeki kompakt kart (iki sutun).
  ///
  /// ⚠️ Liste kartinin KOPYASI DEGIL: dar sutunda "Açık · 20:00'a kadar ·
  ///    En uygun 80 ₺ · Gebze" satiri UC SATIRA sarardi. Burada yalnizca
  ///    **puan · sure · min tutar** cizilir; gerisi karta dokununca acilan
  ///    profilde zaten var.
  /// ⚠️ Kapak genisligi: (ekran - 2*yan bosluk - sutun araligi) / 2.
  ///    Verilmezse gorsel iki katindan fazla cozunurlukte decode edilir
  ///    (turu 91 performans dersi).
  Widget _izgaraKarti(IsletmeOzet o) {
    final gorselID = (o.kapakMediaId != null && o.kapakMediaId!.isNotEmpty)
        ? o.kapakMediaId!
        : (o.avatarMediaId ?? '');
    final hucre = (MediaQuery.sizeOf(context).width - kYanBosluk * 2 - 12) / 2;
    return InkWell(
      borderRadius: BorderRadius.circular(kYaricapBuyuk),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: o.id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(kYaricapBuyuk),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: gorselID.isEmpty
                      ? _kapakYerTutucu(o)
                      : MedyaGorsel(
                          mediaId: gorselID,
                          fit: BoxFit.cover,
                          width: hucre,
                        ),
                ),
                // ⚠️⚠️ TURU 175 — **IZGARADA KAMPANYA ROZETI CIZILMEZ**
                //	(kullanici: *"sol sag ortadaki gorunumu
                //	sectigimde isletme kartinin uzerindeki 300 TL
                //	indirim vs GORUNMEYECEK"*).
                //
                // ⚠️ Rozet TEK SATIRLI LISTE gorunumunde DURUYOR: orada
                //    kapak ekranin tamamina yakin genislikte ve rozet
                //    okunabiliyor. Izgarada hucre ~yari genislikte,
                //    'İlk sipariş 100 TL indirim' zaten kirpiliyordu.
                // ⚠️ `kampanyaRozetleri` SILINMEDI - liste gorunumu ve
                //    diger ekranlar onu kullanmaya devam ediyor.
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Flexible(
                child: Text(
                  o.ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (o.dogrulandi)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(LucideIcons.badgeCheck,
                      size: 13, color: kOnayliRengi),
                ),
            ],
          ),
          const SizedBox(height: 2),
          vitrinSatiri(context, o, kompakt: true),
        ],
      ),
    );
  }

  // ⚠️ TURU 96d — `_gorunumAnahtari` ve `_daireDugme` SILINDI: gorunum
  //    artik `_gorunumSecici` segment kutusunda, harita da onun ucuncu
  //    segmenti. Iki gri daire kalmadi.

  /// ⚠️⚠️⚠️ TURU 96c — LISTE BASLIGI (kullanici emri: *"arama inputun
  ///	sagindaki gorunumleri isletme kartinin SOL USTUNDE 'İşletmeler (2)',
  ///	EN SAGDA gorunum ikonlari olsun"*).
  ///
  /// ⚠️ SAYI **SUZULMUS** listeden gelir: kullanici bir filtre acinca kacini
  ///    gordugunu ANINDA bilmeli. Ham listeden verilseydi "İşletmeler (14)"
  ///    yazip altta 2 kart cizerdi.
  Widget _listeBasligi(int adet) => Padding(
        // ⚠️ Solda baslik metni (glif telafili), sagda segment KUTUSU.
        // ⚠️ Kutunun kenarligi murekkeptir: sag dolgu dogrudan `kYanBosluk`,
        //    boylece cerceve alttaki kartlarin kenariyla AYNI hizada durur.
        //    (Kutu kaldirilmis surumde `kSegYan + kSegOptik` telafisi
        //    gerekiyordu; kutu geri gelince o telafi GECERSIZ.)
        padding: const EdgeInsets.only(
            left: kYanBosluk - kBaslikOptik, right: kYanBosluk),
        child: Row(
          children: [
            // ⚠️⚠️ TURU 180af — **"2 Restoran"** (kullanici emri:
            //	*"restoranların 2 Restoran olarak olsun"*).
            //	Onceki hal "Restoranlar (2)" idi; sayi ARTIK ONDE ve ad
            //	TEKIL — parantez kalktigi icin baslik da kisaldi.
            Text(
              '$adet ${_listeAdiTekil()}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            // ⚠️⚠️ FILTRE **GORUNUM SECICININ HEMEN SOLUNDA** (kullanici
            //	emri). Ustteki hizli suzgec seridi kalkinca ekranda tek
            //	kapi kaldi ve o da listenin BASLIGINDA — yani suzgecin
            //	etkiledigi seyin tam ustunde.
            // ⚠️ Ayni `Transform` ile kaydirilir: iki eleman AYNI optik
            //	hatta durmali (biri kayip oteki durursa satir egri gorunur).
            // ⚠️ Araya `SizedBox` KONMAZ: `_filtreCipi` kendi sag payini
            //	(8) TASIYOR — ikisi birden 16 dp yapar ve cerceveler
            //	kopuk gorunurdu.
            Transform.translate(
              offset: const Offset(0, -kSegYukari),
              child: _filtreCipi(),
            ),
            // ⚠️⚠️ TURU 96j — "BIR TIK USTTE" (kullanici emri). `Transform`
            //	KULLANILDI, dolgu DEGIL: dolgu satirin yuksekligini degistirir
            //	ve altindaki kart listesi asagi kayardi. `Transform.translate`
            //	YALNIZ cizimi tasir, yerlesim BIREBIR ayni kalir.
            // ⚠️ Dokunma alani da birlikte tasinir (`Transform` hit-test'i
            //    donusturur) — ikon nerede gorunuyorsa orada basiliyor.
            Transform.translate(
              offset: const Offset(0, -kSegYukari),
              child: _gorunumSecici(),
            ),
          ],
        ),
      );

  /// ⚠️⚠️ TURU 96g — LISTE BASLIGI **KATEGORIYE OZEL** (kullanici emri:
  ///	*"İşletmeler (2) yerine Restoranlar olarak yazabilirsin"*).
  ///
  /// ⚠️ Cogul adlar ISTEMCIDE ve bu bilincli bir GECICI: sunucudaki
  ///    `Kategoriler` haritasi TEKIL ad tutuyor ("Yemek"), cogulunu
  ///    ("Restoranlar") tutmuyor. Sunucuya eklemek bir alan + deploy
  ///    demekti; bu tur SALT ARAYUZ turu.
  /// ⚠️ **BACKEND TURUNDA** bu harita `altkategori.go`ya tasinmali —
  ///    yeni bir kategori eklendiginde istemci guncellemesi gerekmesin
  ///    (turu 77 kurali).
  /// ⚠️ Bilinmeyen kategori "İşletmeler"e duser: eksik bir anahtar yuzunden
  ///    baslik BOS kalmaz.
  /// ⚠️ TURU 180af — baslik artik "2 Restoran" (tekil) yaziyor; bu COGUL
  ///	harita hicbir yerden cagrilmiyor ama SILINMEDI: bu dosyada uye
  ///	silmek BES kez komsu uyeyi de goturdu (turu 127/138/140/141/143).
  // ignore: unused_element
  String _listeAdi() {
    const adlar = {
      'yemek': 'Restoranlar',
      'kafe': 'Kafeler',
      'doktor': 'Doktorlar',
      'diyetisyen': 'Diyetisyenler',
      'kuafor': 'Kuaförler',
      'guzellik': 'Güzellik Merkezleri',
      'otel': 'Oteller',
      'eczane': 'Eczaneler',
      'emlak': 'Emlak Ofisleri',
      'giyim': 'Mağazalar',
      'teknoloji': 'Teknoloji Mağazaları',
      'eglence': 'Eğlence Mekânları',
      'hizmet': 'Hizmetler',
    };
    return adlar[_kategori] ?? 'İşletmeler';
  }

  /// TEKIL kategori adi — baslik "**2 Restoran**" bicimindedir.
  ///
  /// ⚠️ Sayi ONDE oldugu icin ad TEKIL olmak ZORUNDA: "2 Restoranlar"
  ///	Turkce'de yanlistir (sayidan sonra cogul eki KULLANILMAZ).
  /// ⚠️ Cogul harita (`_listeAdi`) SILINMEDI — geri donus tek satir.
  /// ⚠️ Bilinmeyen kategori "İşletme"ye duser; baslik BOS kalmaz.
  /// ⏳ **BACKEND TURU**: bu harita `altkategori.go`ya tasinmali (turu 77
  ///	kurali) — yeni kategori istemci guncellemesi gerektirmesin.
  String _listeAdiTekil() {
    const adlar = {
      'yemek': 'Restoran',
      'kafe': 'Kafe',
      'doktor': 'Doktor',
      'diyetisyen': 'Diyetisyen',
      'kuafor': 'Kuaför',
      'guzellik': 'Güzellik Merkezi',
      'otel': 'Otel',
      'eczane': 'Eczane',
      'emlak': 'Emlak Ofisi',
      'giyim': 'Mağaza',
      'teknoloji': 'Teknoloji Mağazası',
      'eglence': 'Eğlence Mekânı',
      'hizmet': 'Hizmet',
    };
    return adlar[_kategori] ?? 'İşletme';
  }

  /// ⚠️⚠️⚠️ TURU 96d — GORUNUM SECICI **TEK KUTU** (kullanici emri:
  ///	*"isletmelerin sagindaki ikonlari TEK BIR DIVIN ICINE al, tikladiginda
  ///	gecis yapsin, divin icinde AKTIF olunca arka plan hafif gri olacak"*).
  ///
  /// ⚠️ Onceki hal IKI AYRI gri daireydi ve gorunum anahtari **HEDEFI**
  ///    cizyordu (izgaradayken "liste" ikonu): kullanici hangi gorunumde
  ///    oldugunu ikondan ANLAYAMIYORDU. Segment kutusunda IKISI DE gorunur,
  ///    aktif olan gri zeminle isaretlenir — durum artik OKUNABILIR.
  ///
  /// ⚠️⚠️ HARITA SEGMENTININ **AKTIF HALI YOKTUR** ve bu bilincli: liste ile
  ///	kart bir GORUNUM DURUMU, harita ise AYRI BIR EKRAN. Ona gri zemin
  ///	verilseydi "haritadayim" der ama ekran zaten degismis olurdu.
  /// ⚠️ Kutu `kYuzeyGri`nin BIR TIK ACIGI ile cerceveleniyor; aktif segment
  ///    tam `kYuzeyGri`. Ikisi ayni ton olsaydi aktiflik GORUNMEZDI.
  /// ⚠️ **DALGA YOK**: `GestureDetector` (kullanici "titreme olmasin" dedi).
  Widget _gorunumSecici() {
    // ⚠️⚠️ TURU 96g — KUTU ZEMINI **BEYAZ + KENARLIK** (kullanici emri:
    //	*"sagdaki ikonlari arkasi beyaz, filtre butonu gibi; neye tikladiysam
    //	arkasi gri olacak"*).
    //
    //	Onceki hal kutuyu hafif GRI boyuyordu; aktif segment de gri olunca
    //	ikisi birbirine cok yakin kaliyor ve hangisinin secili oldugu zor
    //	anlasiliyordu. Artik kutu ZEMINLE AYNI (seffaf) + cip kenarligi,
    //	aktif segment ise dolu gri -> kontrast net.
    // ⚠️ Kenarlik cipler ile AYNI kaynaktan (`_notrKenar`).
    // ⚠️⚠️⚠️ TURU 96j — **KUTU GERI GELDI** (kullanici DUZELTMESI).
    //
    //	Once *"ikonlari minimalist yapar misin"* dendi ve dis kutu (kenarlik +
    //	dolgu) KALDIRILDI. Kullanici bunu REDDETTI:
    //	  *"Restoranlar sagdaki ikonlarin ARKASINDA BORDER YOK; hepsi BIR
    //	   SEYIN ICINDE border olacak, ikonlari icinde, AKTIF ikon ARKA
    //	   RENGI olacakti"*
    //	Yani "minimalist" istegi KUTUYU DEGIL, ikonlarin kendisini
    //	sadelestirmeyi kastediyordu. Segment kutusu bu ekranin TASARIM
    //	DILIDIR: uc gorunum TEK bir cerceve icinde yasar, aktif olan gri
    //	zeminle isaretlenir (turu 96d'de "hangi gorunumdeyim anlayamiyorum"
    //	sikayetinin cozumu buydu).
    // ⚠️ YAPMA: kutuyu bir daha kaldirma. Sadelestirme gerekiyorsa ikon
    //    OLCUSU/kalinligi ile oyna, CERCEVEYI silme.
    // ⚠️ Kenarlik cipler ile AYNI kaynaktan (`_notrKenar`) — satirdaki iki
    //    cerceve (Filtre cipi ve bu kutu) ayni tonda olmak ZORUNDA.
    Widget segment(IconData ikon, String ipucu, bool aktif, VoidCallback ac) =>
        Semantics(
          button: true,
          selected: aktif,
          label: ipucu,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: ac,
            child: SizedBox(
              width: kSegHucre,
              height: kSegHucreBoy,
              child: Center(
                child: Container(
                  width: kSegHucre,
                  height: kSegBoy,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: aktif ? _yuzey : Colors.transparent,
                    borderRadius: BorderRadius.circular(kYaricap(kSegBoy)),
                  ),
                  child: Icon(ikon, size: kSegIkon, color: _notrYazi),
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(kSegDolgu),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            kYaricap(kSegHucreBoy + kSegDolgu * 2)),
        border: Border.all(color: _notrKenar),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ⚠️ TURU 96j — ILK IKON **`listFilter`** (kullanici SECTI:
          //	*"list-filter dostum ilk ikonu boyle yap"*).
          //	Once `list`ti, `layoutList` denendi; kullanici son olarak
          //	`listFilter`i istedi.
          // ⚠️ YAPMA: "liste ikonu daha dogru olur" diye geri degistirme —
          //    bu bir KULLANICI SECIMI, cikarim degil.
          segment(LucideIcons.listFilter, 'Liste görünümü', !_izgara,
              () => setState(() => _izgara = false)),
          // ⚠️⚠️⚠️ TURU 180ag — **ORTADAKI SEGMENT (`layoutGrid` / kart
          //	gorunumu) KALDIRILDI** (kullanici emri: *"gorunumde ortadaki
          //	2. gorunumu kaldir"*).
          //
          // ⚠️ `_izgara` ARTIK DAIMA `false`: diske yazilmiyordu, tek
          //	yazicisi bu segmentti. Yani izgara dali (`_izgaraKarti` +
          //	`SliverGrid`) ULASILAMAZ kod oldu — govdeler SILINMEDI, karar
          //	tek satirla geri alinabilsin diye duruyor.
          // ⚠️ **CERCEVE (kenarlik + dolgu) DURUYOR**: kullanici onu bir kez
          //	ACIKCA reddetti (*"hepsi BIR SEYIN ICINDE border olacak"*) —
          //	tek segment kalsa bile kutu kaldirilmaz (turu 96j).
          // ⚠️ YAPMA: `kSeg*` sabitlerine dokunma; kutu genisligi segment
          //	SAYISINDAN turemiyor ve muhafiz testi o sabitleri kilitliyor.
          segment(
            LucideIcons.map,
            'Haritada gör',
            false,
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => YakinimdaEkrani(kategori: _kategori),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️⚠️ KAPAK YOKSA **HAFIF GRI** (kullanici emri: *"kapaklardaki renkli
  ///    desenleri kaldir, onun yerine hafif gri slider gibi yap"*).
  ///
  ///	Onceden ADDAN turetilen RENKLI bir gradyan ciziliyordu. Listede alt
  ///	alta duran kirmizi/mor/yesil bloklar dikkati icerikten CALIYOR ve
  ///	referans ekrandaki sakin gorunumden UZAKLASTIRIYORDU.
  /// ⚠️ Ton **slider ile AYNI** (`0xFFE7E7EA` / koyu `0xFF2A2A2E`): ekranda
  ///    iki farkli gri olmasin.
  /// ⚠️ Bas harf KALDI ama artik SOLUK: kartin bos degil "gorseli yok"
  ///    oldugunu gosterir; tamamen bos bir kutu "yukleniyor" gibi durur.
  /// Kapak yoksa: **DUZ HAFIF GRI**, icinde hicbir sey yok.
  ///
  /// ⚠️ Kullanici emri: *"kartlarin neden icine harf koyuyorsun, kaldir"*.
  ///    Onceden ortada bas harf ciziliyordu; kullanici bunu IKI KEZ
  ///    kaldirtti (once 60x60 kartlardan, sonra buradan).
  /// ⚠️ Ton `kYuzeyGri` — slider ve 60x60 kartlarla AYNI.
  Widget _kapakYerTutucu(IsletmeOzet o) => ColoredBox(color: _yuzey);


}
