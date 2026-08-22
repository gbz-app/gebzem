/// ⚠️⚠️⚠️ TURU 89 — KIMLIK EKRANLARININ **TEK GORSEL KAYNAGI**.
///
/// Kullanici emri: *"kayit ekranindaki tarzin aynisi giriste de olsun"* ve
/// (turu 120) *"ayni mantigi kayit ekraninda da yap, HER MANTIK"*.
///
/// Bu dosya olmadan iki yol vardi:
///   (a) `login_screen`e ayni renkleri/bicimleri ELLE kopyalamak — bu projede
///       **"ayni kuralin iki kopyasi DRIFT EDER"** hatasi ALTI kez yasandi;
///       biri degistiginde oteki geride kalir ve iki ekran birbirinden
///       gorsel olarak ayrilirdi. (Turu 119'da tam bu oldu: giris alt-cizgili
///       yeni bicime gecti, kayit ESKI cerceveli halinde kaldi.)
///   (b) `kayit_akisi.dart`in ozel yardimcilarini disari acmak — o dosya
///       adimli akisa OZEL durum tutuyor (`_adim`, `_mesgul`), disaridan
///       kullanilamaz.
/// Bu yuzden ORTAK parcalar buraya cikarildi ve HER IKI ekran da BURADAN
/// beslenir.
///
/// ⚠️ ZEMIN SABIT BEYAZ oldugu icin renkler **TEMADAN ALINMAZ**. Koyu temada
///    tema renkleri beyaz zemine beyaz yazi cizerdi — turu 81b'de sohbet
///    balonlarinda yasanan **1.23:1 kontrast** hatasinin birebir aynisi.
/// ⚠️ Ekranlar ayrica `Theme(data: lightTheme)` ile sarilir (turu 85b): imlec,
///    secim vurgusu ve `TextField` etiketleri de koyu temadan gelmesin.
/// ⚠️ YAPMA: bu sabitleri/yardimcilari cagiran ekranlara geri kopyalama.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';

/// Baslik ve govde yazisi (beyaz zeminde okunur koyu ton).
const Color authYazi = Color(0xFF14141A);

/// Ikincil yazi: aciklama, etiket, ipucu.
const Color authAltYazi = Color(0xFF6B6B76);

/// ⚠️ TURU 119 — HATA RENGI (kullanici emri: *"sifre hatali olunca input
///    KIRMIZI olsun"*). Beyaz zeminde 4,5:1 uzeri okunur bir kirmizi.
const Color authHata = Color(0xFFD92D20);

/// Alan cercevesi (odaklanmamis hal).
const Color authCizgi = Color(0xFFE3E3EA);

/// ⚠️⚠️ TURU 120 — YAZI OLCULERI **TEK SABITTEN** (kullanici emri:
///	*"telefon numarasi ve sifre yazisini 2px, ALTINDAKILERI 4px daha
///	buyuk yap"*).
///
/// ⚠️ Ikisi de sabit olarak DURUR ve `authAlan` / `authDegerStili` disinda
///    HICBIR YERDE elle yazilmaz: turu 119'da alanlarin bicimi iki dosyada
///    ayri ayri yaziliyordu ve biri guncellenince oteki geride kaldi.
const double authEtiketBoy = 15.5; // 13.5 + 2
const double authDegerBoy = 20.0; //  16   + 4

/// Ekrani beyaz zemin + acik tema + koyu durum cubugu ikonlariyla sarar.
///
/// ⚠️ `AnnotatedRegion` ZORUNLU: zemin sabit beyaz yapilinca durum cubugu
///    ikonlari TEMADAN geliyordu ve koyu temada BEYAZ kaliyordu — beyaz
///    zeminde saat/pil/sinyal GORUNMUYORDU (turu 85b bulgusu).
/// ⚠️ Cikista eski stile donus `main.dart`taki uygulama geneli varsayilan
///    `AnnotatedRegion` sayesinde OTOMATIKTIR (turu 85c) — burada geri alma
///    kodu YAZMA, iki kopya drift eder.
/// ⚠️⚠️⚠️ TURU 126 — [klavyeyeGoreKuculme] (kullanici emri: *"inputa
///	tikladigimda animasyonlu kalip inmesin, takiliyor donma yapiyor;
///	seri, tatli, hafif olsun"*).
///
/// `Scaffold`un varsayilan `resizeToAvoidBottomInset: true` davranisi,
/// klavye acilirken GOVDENIN TAMAMINI kisaltir: `Expanded` daralir, icerik
/// yukari kayar, alttaki dugme yukari firlar. Kucuk ekranda bu, her odak
/// dokunusunda TUM SAYFANIN oynamasi demek — kullanicinin "kalip iniyor,
/// takiliyor" dedigi sey budur.
///
/// `false` verildiginde ust icerik **HIC OYNAMAZ**; klavyenin ustunde
/// durmasi gereken tek oge (ana dugme) kendi dolgusunu `viewInsets`ten
/// alir ve Flutter o degeri klavye animasyonuyla KADEMELI gunceller —
/// yani hareket serttten yumusaga doner.
/// ⚠️ YAPMA: `false` verilen bir ekranda alt dugmeye `viewInsets` dolgusu
///    koymayi unutma; yoksa dugme klavyenin ALTINDA kalir ve ULASILAMAZ olur.
class AuthSayfa extends StatelessWidget {
  const AuthSayfa({
    super.key,
    required this.child,
    this.klavyeyeGoreKuculme = true,
  });

  final Widget child;
  final bool klavyeyeGoreKuculme;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Theme(
        data: lightTheme,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: klavyeyeGoreKuculme,
          body: child,
        ),
      ),
    );
  }
}

/// Sola dayali baslik + altinda aciklama (kayit akisinin dili).
///
/// ⚠️ TURU 120 — kullanici emri: *"Tekrar hos geldin altindaki aciklamayi daha
///    profesyonel yap, IKISINI DE 2px daha buyuk yap"* -> 26 -> **28**,
///    14.5 -> **16.5**.
/// ⚠️ TURU 126 — [aciklama] ARTIK OPSIYONEL. Referans tasarimda basligin
///    altinda aciklama YOK; baslik ile giris alani DOGRUDAN komsu
///    (kullanici: *"buyuk yazinin altina telefon olacak"*). Verilmezse
///    aciklama satiri VE onun altindaki 9 dp bosluk CIZILMEZ — bos bir
///    `Text('')` birakmak, gorunmez ama yer kaplayan bir satir olurdu.
/// ⚠️ Parametre POZISYONEL-OPSIYONEL: mevcut dort cagri yeri
///    (kayit akisi · sifre unuttum · OTP · kayit) DEGISMEDEN calisir.
Widget authBaslik(String baslik, [String? aciklama, double altBosluk = 28]) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: authYazi,
          ),
        ),
        if (aciklama != null) ...[
          const SizedBox(height: 9),
          Text(
            aciklama,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 16.5,
              height: 1.45,
              color: authAltYazi,
            ),
          ),
        ],
        SizedBox(height: altBosluk),
      ],
    );

/// Alan icindeki DEGERIN stili (etiketin altindaki asil yazi).
///
/// ⚠️ TURU 120 — hatada YAZI DA kirmizi olur (kullanici emri: *"5 ile
///    baslamazsa kirmizi olsun HEM YAZI HEM CIZGI"*). Turu 119'da yalnizca
///    cizgi ve etiket kirmiziya donuyordu; kullanicinin yazdigi rakamlar
///    siyah kaliyordu ve hatanin NEREDE oldugu belirsizdi.
TextStyle authDegerStili({
  bool hatali = false,
  double? boy,
  bool sade = false,
}) => TextStyle(
  color: hatali ? authHata : (sade ? authSadeDeger : authYazi),
  fontSize: boy ?? authDegerBoy,
  fontWeight: FontWeight.w500,
);

/// ⚠️⚠️ TURU 126 — SADE MODDAKI DEGER BOYU (kullanici referansi).
///
/// Referans tasarimda giris metni sayfadaki EN BUYUK ikinci ogedir (baslik
/// 28, deger 24); alt cizgi ve etiket olmadigi icin BOYUT tek hiyerarsi
/// isaretidir. `authDegerBoy` (20) sade modda kucuk kaliyordu.
const double authSadeDegerBoy = 30.0;

/// Sade moddaki IPUCU ve `+90` on eki — hafif gri.
const Color authSadeSoluk = Color(0xFFB6B6BF);

/// Sade moddaki DEGER — ipucundan **bir tik koyu**, ama siyah DEGIL.
///
/// ⚠️ Kullanici emri: *"hepsi hafif gri olsun, mevcut telefon girisi bir tik
///    ustunde renk olsun"*. Deger `authYazi` (neredeyse siyah) kalsaydi
///    ipucuyla arasindaki fark SERT olurdu; bu ton ikisini ayni aileye
///    baglar ve okunurlugu korur (beyaz zeminde ~7:1).
const Color authSadeDeger = Color(0xFF5A5A66);

/// ⚠️⚠️⚠️ TURU 119 — METIN ALANI **YALNIZ ALT CIZGI** (kullanici emri:
///	*"input ALT CIZGI olsun, sol sag ust cizgi DEGIL; alt cizgi de 2px
///	olsun; TELEFON NUMARASI yazisi USTTE, altta telefon numarasi
///	yazilsin, aynisi sifrede; sifre hatali olunca input KIRMIZI olsun"*).
///
/// ⚠️⚠️ **`UnderlineInputBorder` + `alwaysUse` ETIKETI TEK BASINA YETMEZ.**
///	Material'in varsayilan davranisi: etiket alan BOSKEN icerideki
///	yer tutucunun yerinde durur, YAZILINCA yukari kucuIur. Kullanici
///	etiketin **DAIMA USTTE** durmasini istedi (yazi girilmemis olsa bile),
///	bu yuzden `floatingLabelBehavior: always`.
///	⚠️ Bu ayni zamanda ipucu (`hintText`) ile etiketin UST USTE
///	   binmesini de onler — `always` olmadan ikisi ayni yerde cizilir.
///	⚠️⚠️ TURU 120 — `always` AYRICA **`prefixText`IN GORUNMESINI SAGLAR**
///	   (SDK kaynagindan dogrulandi, `input_decorator.dart`):
///	     `labelShouldWithdraw = _labelShouldWithdraw || behavior == always`
///	   ve `_AffixText` opakligi `labelIsFloating ? 1.0 : 0.0`.
///	   Yani `always` OLMASAYDI **`+90` on eki alan bos ve odaksizken
///	   GORUNMEZDI** ve kullanici numarayi bastan yazmaya calisirdi.
///	   ⚠️ YAPMA: `floatingLabelBehavior`i degistirme.
///
/// ⚠️ Alt cizgi **2 px** (kullanici olcusu). Odakta MARKA MORU, hatada
///    KIRMIZI; kalinlik UC HALDE DE 2 px kalir — degisseydi alanin ic
///    yuksekligi oynar ve yazi 1 px ZIPLARDI.
/// ⚠️ [hataliMi] bir `errorText` DEGIL: `errorText` alanin yuksekligini
///    degistirir ve form ZIPLARDI. Aciklama satiri AYRI bir bilesenle
///    (`authNot`) alanin ALTINA konur.
/// ⚠️ YAPMA: `OutlineInputBorder`a geri donme.
/// ⚠️⚠️⚠️ TURU 126 — **[sade] MODU** (kullanici referansi: buyuk baslik,
///	altinda CIZGISIZ ve ORTALANMIS giris, altta hap dugme).
///
/// Sade modda: hicbir kenarlik YOK · etiket YOK · ipucu ve deger ORTALI ·
/// deger 24 px. Alan bir "kutu" degil, sayfanin govde METNI gibi durur.
///
/// ⚠️⚠️ **ETIKET SADE MODDA CIZILMEZ ama BILGI KAYBOLMAZ**: `labelText`
///	kaldirilinca alanin ne istedigini soyleyen tek sey IPUCU kalir, bu
///	yuzden cagiran taraf sade modda ipucunu ZORUNLU verir
///	("5xx xxx xx xx" / "Şifren"). Ipucusuz sade alan, kullanicinin BOS
///	bir satira bakip ne yazacagini bilememesi demektir.
/// ⚠️⚠️ **`floatingLabelBehavior: always` SADE MODDA DA KALIR.** Etiket yok
///	ama `prefixText` (`+90`) VAR ve SDK kaynagi (`input_decorator.dart`)
///	`_AffixText` opakligini `labelIsFloating ? 1.0 : 0.0` ile hesaplar:
///	bayrak dusurulseydi alan bos ve odaksizken **`+90` GORUNMEZDI**
///	(turu 120'de olculen hata). ⚠️ YAPMA: sade dalda bu bayragi kaldirma.
/// ⚠️ Hata sade modda RENKLE anlatilir (deger + on ek kirmizi olur) —
///    cizgi olmadigi icin baska tasiyici yok; aciklama satiri `authNot`
///    zaten alanin ALTINDA duruyor.
InputDecoration authAlan(
  String etiket, {
  String? ipucu,
  Widget? sonek,
  bool hataliMi = false,
  bool sade = false,
  bool sadeKoyuCizgi = false,
}) {
  UnderlineInputBorder cizgi(Color renk) =>
      UnderlineInputBorder(borderSide: BorderSide(color: renk, width: 2));
  UnderlineInputBorder sadeCizgi(Color renk) =>
      UnderlineInputBorder(borderSide: BorderSide(color: renk, width: 1));
  // ⚠️ Alan DOLUYKEN cizgi koyulasir; bos ve hatasizken acik gri kalir.
  final sadeNormal = hataliMi
      ? authHata
      : (sadeKoyuCizgi ? authYazi : authCizgi);
  final normal = hataliMi ? authHata : authCizgi;
  final odak = hataliMi ? authHata : morLogo;
  final etiketStili = TextStyle(
    color: hataliMi ? authHata : authAltYazi,
    fontSize: authEtiketBoy,
    fontWeight: FontWeight.w600,
  );
  if (sade) {
    return InputDecoration(
      hintText: ipucu,
      suffixIcon: sonek,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      // ⚠️⚠️ TURU 126 — SADE MODDA **HER SEY GRI TONUNDA** (kullanici emri:
      //	*"hepsi hafif gri olsun, mevcut telefon girisi bir tik ustunde
      //	renk olsun"*). Ipucu ve `+90` ACIK gri; kullanicinin YAZDIGI
      //	deger bir tik KOYU (bkz. `authSadeDeger`) — yani hiyerarsi
      //	KOYULUKLA kurulur, siyah/gri karsitligiyla degil.
      hintStyle: TextStyle(
        color: authSadeSoluk,
        fontSize: authSadeDegerBoy,
        fontWeight: FontWeight.w400,
        // ⚠️ TURU 120 dersi: `hintStyle` taban stili MERGE eder; sifre alani
        //    gizliyken `letterSpacing: 5` kullaniyor ve ipucuna SIZIYORDU.
        letterSpacing: 0,
      ),
      // ⚠️⚠️⚠️ TURU 126b — **DIKEY DOLGU ACIKCA VERILIR (denetim bulgusu).**
      //	Ilk yazimda `contentPadding: zero` + `isDense: true` vardi ve
      //	IKI SORUN birden uretiyordu:
      //	  (a) telefon alaninin dokunma yuksekligi **36 dp** kaliyordu —
      //	      Material tavani 48; alt cizgi olmadigi icin kullanicinin
      //	      nereye dokunacagini soyleyen GORSEL bir sinir da yok,
      //	  (b) sifre alani `suffixIcon` (goz) yuzunden **48 dp** cikiyordu:
      //	      ust uste duran iki alan FARKLI YUKSEKLIKTEYDI ve aradaki
      //	      bosluk esit gorunmuyordu.
      // ⚠️ 12 dp: 24 px'lik deger satiriyla birlikte ~48 dp verir, yani
      //    sonekli sifre alaniyla AYNI. Degistirirsen IKISINI birlikte olc.
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      // ⚠️⚠️ TURU 126 — SADE ALANDA **1 PX ALT CIZGI** (kullanici emri).
      //	Kalinlik UC HALDE DE 1 px: degisseydi alanin ic yuksekligi oynar
      //	ve yazi 1 px ZIPLARDI (turu 119 sinifi). Renk hatada KIRMIZI.
      border: sadeCizgi(sadeNormal),
      enabledBorder: sadeCizgi(sadeNormal),
      focusedBorder: sadeCizgi(sadeNormal),
      errorBorder: sadeCizgi(authHata),
      focusedErrorBorder: sadeCizgi(authHata),
      disabledBorder: sadeCizgi(authCizgi),
    );
  }
  return InputDecoration(
    labelText: etiket,
    hintText: ipucu,
    suffixIcon: sonek,
    // ⚠️ Etiket DAIMA USTTE (bkz. serh) — ayrica `prefixText`i gorunur kilar.
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: etiketStili,
    floatingLabelStyle: etiketStili,
    hintStyle: TextStyle(
      color: authAltYazi.withValues(alpha: 0.45),
      // ⚠️ Ipucu DEGERLE AYNI BOYDA: kucuk kalsaydi kullanici yazmaya
      //    basladiginda yazi tipi "buyuyor" gibi gorunurdu.
      fontSize: authDegerBoy,
      fontWeight: FontWeight.w400,
      // ⚠️⚠️ TURU 120 — `letterSpacing: 0` ZORUNLU (EMULATORDE GORULDU).
      //	Flutter `hintStyle`i **`TextField.style` UZERINE MERGE EDER**;
      //	verilmeyen alanlar TABANDAN gelir. Sifre alani gizliyken
      //	`letterSpacing: 5` kullaniyor (daireler ayri okunsun diye) ve o
      //	deger IPUCUNA DA siziyordu: ekranda **"E n  a z  6  k a r a k t e r"**
      //	yaziyordu.
      // ⚠️ YAPMA: bu satiri kaldirma; aralik kullanan her alanda ipucu bozulur.
      letterSpacing: 0,
    ),
    // ⚠️ Yan dolgu SIFIR: alt cizgili alanda ic dolgu, yaziyi cizginin
    //    baslangicindan iceri kaydirir ve hizalama bozulur.
    contentPadding: const EdgeInsets.only(top: 12, bottom: 10),
    enabledBorder: cizgi(normal),
    focusedBorder: cizgi(odak),
    errorBorder: cizgi(authHata),
    focusedErrorBorder: cizgi(authHata),
    disabledBorder: cizgi(authCizgi),
    border: cizgi(normal),
  );
}

/// Alanin ALTINA konan kisa aciklama/hata satiri.
///
/// ⚠️⚠️ TURU 120 — kullanici emri: *"5 ile baslamasi gerektigini KISA
///	PROFESYONEL aciklama yazsin ... telefon numarasi bulunamazsa yine
///	basit bir aciklama yazsin, sifrede aynisi"*.
///
/// ⚠️ `errorText` YERINE AYRI BILESEN: `errorText` `InputDecoration`in ic
///    yuksekligini degistirir; alt cizgi ve etiket ZIPLARDI. Ayri satir
///    alanin DISINDA durur, cizgiye dokunmaz.
/// ⚠️ Ikon + metin AYNI renkte: renk korlugunde tek basina renk hicbir sey
///    anlatmaz (turu 98b dersi), ikon anlamı TASIR.
Widget authNot(String mesaj, {bool hata = true}) {
  final renk = hata ? authHata : authAltYazi;
  return Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          hata ? LucideIcons.circleAlert : LucideIcons.info,
          size: 16,
          color: renk,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            mesaj,
            style: TextStyle(fontSize: 14.5, height: 1.35, color: renk),
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════ TELEFON ALANI ═══════════════════════

/// Ulke kodu — **DENETLEYICIDE TUTULMAZ**, on ek olarak cizilir.
const String authUlkeKodu = '+90';

/// Turkiye cep numarasi: `5` ile baslar ve 10 hanedir.
const int authTelefonHane = 10;

/// Denetleyicideki HANELERDEN sunucuya gidecek tam numarayi uretir.
///
/// ⚠️ TEK KAYNAK: giris, kayit ve kod dogrulama AYNI numarayi uretmek
///    ZORUNDA. Uc yerde `'+90' + text` yazilsaydi biri `trim()` unuturdu.
/// ⚠️⚠️⚠️ TURU 126 — **DENETLEYICI ARTIK BOSLUKLU METIN TUTUYOR**
///	(`512 345 67 89`, kullanici emri). Numarayi okuyan HER yardimci
///	once HANELERI SUZER; sunucuya bosluklu numara giderse `users.phone`
///	ile eslesmez ve giris SESSIZCE basarisiz olur.
/// ⚠️ YAPMA: cagiran taraflarda `controller.text`i dogrudan sunucuya verme.
String authHaneler(String metin) => metin.replaceAll(RegExp(r'\D'), '');

/// Denetleyicideki HANELERDEN sunucuya gidecek tam numarayi uretir.
///
/// ⚠️ TEK KAYNAK: giris, kayit ve kod dogrulama AYNI numarayi uretmek
///    ZORUNDA.
String authTamNumara(String haneler) => '$authUlkeKodu${authHaneler(haneler)}';

/// Numarayi EKRANDA gostermek icin bicimlendirir: `+90 532 123 45 67`.
///
/// ⚠️⚠️ **`authTamNumara` ILE KARISTIRMA.** Bu yalniz GORUNUM icindir;
///	sunucuya BOSLUKLU numara gonderilirse dogrulama basarisiz olur.
///	Sunucuya giden TEK yol `authTamNumara`dir.
/// ⚠️ 10 hane degilse OLDUGU GIBI dondurulur: yarim yazilmis bir numarayi
///    zorla gruplamak ("+90 55 " gibi) kullaniciya bozuk gorunurdu.
String authNumaraGoster(String haneler) {
  final h = authHaneler(haneler);
  if (h.length != authTelefonHane) return authTamNumara(h);
  return '$authUlkeKodu ${h.substring(0, 3)} ${h.substring(3, 6)} '
      '${h.substring(6, 8)} ${h.substring(8)}';
}

/// Yazarken gosterilecek hata — yoksa `null`.
///
/// ⚠️ Kullanici HENUZ YAZMAYA BASLAMADIYSA (bos) hata GOSTERILMEZ: bos bir
///    formu kirmiziya boyamak "bir sey yanlis yaptim" hissi verir.
/// ⚠️ Eksik hane de hata SAYILMAZ (yaziyor olabilir); yalniz **ilk hane**
///    yanlissa aninda uyarilir, cunku o hatanin duzelmesi mumkun degildir:
///    `0` ile baslayan numara ne kadar yazilirsa yazilsin gecerli olmaz.
String? authTelefonHatasi(String haneler) {
  final h = authHaneler(haneler);
  if (h.isEmpty) return null;
  if (!h.startsWith('5')) {
    return 'Numara 5 ile başlamalı — alan kodu olmadan yaz (örnek: 532 123 45 67).';
  }
  return null;
}

/// Gonderilebilir mi (10 hane ve 5 ile basliyor).
bool authTelefonTam(String haneler) {
  final h = authHaneler(haneler);
  return h.length == authTelefonHane && h.startsWith('5');
}

/// ⚠️⚠️⚠️ TURU 126 — **NUMARAYI YAZARKEN GRUPLAR**: `512 345 67 89`.
///
/// ⚠️⚠️ **IMLEC KONUMU -1 GELEBILIR** (secim bildirilmemis). Onu
///	`clamp(0, ...)` ile 0 saymak imleci metnin BASINA tasir ve bir
///	SONRAKI tus BASA eklenir — haneler birbirinin ustune biner.
///	-1 ya da sonda ise imlec metnin SONUNA konur: telefon alaninda
///	yazim daima sondan ilerler, en guvenli varsayilan budur.
/// ⚠️ Tavan BURADA uygulanir (10 hane);
///    `LengthLimitingTextInputFormatter` KULLANILAMAZ — o KARAKTER sayar
///    ve bosluklarla 13'e cikan metni erken keserdi.
class AuthTelefonBicimlendirici extends TextInputFormatter {
  const AuthTelefonBicimlendirici();

  static String grupla(String h) {
    final p = <String>[];
    if (h.isNotEmpty) p.add(h.substring(0, h.length < 3 ? h.length : 3));
    if (h.length > 3) p.add(h.substring(3, h.length < 6 ? h.length : 6));
    if (h.length > 6) p.add(h.substring(6, h.length < 8 ? h.length : 8));
    if (h.length > 8) p.add(h.substring(8));
    return p.join(' ');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue eski,
    TextEditingValue yeni,
  ) {
    final h = authHaneler(yeni.text);
    final kirpik = h.length > authTelefonHane
        ? h.substring(0, authTelefonHane)
        : h;
    final metin = grupla(kirpik);
    final off = yeni.selection.baseOffset;
    if (off < 0 || off >= yeni.text.length) {
      return TextEditingValue(
        text: metin,
        selection: TextSelection.collapsed(offset: metin.length),
      );
    }
    // Imlecten ONCEKI hane sayisi -> yeni metinde ayni hane sayisina
    // denk gelen konum.
    final oncekiHane = authHaneler(yeni.text.substring(0, off)).length;
    var konum = metin.length;
    var sayac = 0;
    for (var i = 0; i < metin.length; i++) {
      if (sayac >= oncekiHane) {
        konum = i;
        break;
      }
      if (metin[i] != ' ') sayac++;
    }
    return TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: konum),
    );
  }
}

/// ⚠️⚠️⚠️ TURU 120 — TELEFON ALANI (kullanici emri: *"+90 SILINMESIN;
///	oraya tikladiginda ARASINDA BIRAZ BOSLUKLA aynı font size ile telefon
///	numarasi yazsin; 5 ile baslamazsa KIRMIZI olsun hem yazi hem cizgi"*).
///
/// ⚠️⚠️ **DENETLEYICI YALNIZ HANELERI TUTAR** (`5321234567`), `+90` DEGIL.
///	Onceden metin `+90` ile baslatiliyordu ve kullanici onu SILEBILIYOR,
///	basina tekrar yazabiliyor, imleci arasina koyabiliyordu; sunucuya
///	`+9` ya da `+905321234567890` gidebiliyordu. On ek artik METNIN
///	PARCASI DEGIL, `prefixText` ile CIZILEN bir sus — silinmesi
///	YAPISAL OLARAK imkansiz.
///	⚠️ Bedeli: cagiran taraf sunucuya giderken `authTamNumara()`
///	   kullanmak ZORUNDA. Uc cagri yeri de o yardimciyi kullanir.
///
/// ⚠️ `digitsOnly` + 10 hane siniri: yapistirilan `+90 532 ...` metninden
///    bosluk/artı otomatik dusurulur.
///    ⚠️ **BILINEN SINIR:** kullanici basina `90` da yapistirirsa
///       (`905321234567`) ilk 10 hane alinir -> `9053212345`. Bu durumda ilk
///       hane `9` oldugu icin alan ANINDA kirmiziya doner ve aciklama cikar,
///       yani hata SESSIZ DEGIL. Akilli on-ek soyma yazilmadi: `5` ile
///       baslayan gecerli bir numarayi da bozma riski var.
class AuthTelefonAlani extends StatefulWidget {
  const AuthTelefonAlani({
    super.key,
    required this.controller,
    this.hataliMi = false,
    this.etiket = 'Telefon numarası',
    this.not,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.sade = false,
  });

  final TextEditingController controller;

  /// Disaridan gelen hata (or. giris reddedildi) — bicim hatasiyla BIRLESIR.
  final bool hataliMi;
  final String etiket;

  /// Disaridan gelen aciklama (or. *"numarani eksiksiz gir"*).
  ///
  /// ⚠️ BICIM HATASI ONCELIKLIDIR: ikisi ayni anda gorunmez. Alt alta iki
  ///    kirmizi satir, kullanicinin IKI AYRI sorun oldugunu sanmasina yol
  ///    acardi — oysa "5 ile baslamiyor" zaten "gecersiz numara" demektir.
  final String? not;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Cizgisiz + ortali + 24 px gorunum (bkz. `authAlan` sade serhi).
  final bool sade;

  @override
  State<AuthTelefonAlani> createState() => _AuthTelefonAlaniState();
}

/// ⚠️⚠️⚠️ TURU 120 — ALAN **KENDI DENETLEYICISINI DINLER** (`StatelessWidget`
///	DEGIL).
///
/// ═══════════ ILK YAZIMDAKI HATA ═══════════
/// Bicim hatasi (`5 ile baslamali`) `build` icinde `controller.text`ten
/// hesaplaniyordu ama widget DURUMSUZDU: satirin yeniden cizilmesi
/// **EBEVEYNIN `setState` CAGIRMASINA** bagliydi.
///   · Kayit ekrani her tusta kosulsuz `setState` cagirdigi icin ORADA
///     calisiyordu (emulatorde goruldu),
///   · giris ekraninda `_temizle()` **yalnizca temizlenecek bir sey varsa**
///     `setState` cagiriyor -> temiz bir formda ILK tusta hicbir sey
///     yeniden cizilmiyor ve **hata SATIRI HIC GORUNMUYORDU**.
///
/// ⚠️ Yani ozellik, cagiranin dogru `onChanged` yazmasina bagliydi — bu
///    projede DOKUZ kez sahaya cikan "olu ozellik" sinifinin ta kendisi.
///    Artik alan KENDI durumundan sorumlu; cagiranin hicbir sey yapmasi
///    gerekmiyor.
/// ⚠️ `didUpdateWidget` ZORUNLU: cagiran denetleyiciyi degistirirse
///    dinleyici ESKI nesnede kalir ve alan bir daha guncellenmezdi.
class _AuthTelefonAlaniState extends State<AuthTelefonAlani> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_degisti);
  }

  @override
  void didUpdateWidget(AuthTelefonAlani eski) {
    super.didUpdateWidget(eski);
    if (!identical(eski.controller, widget.controller)) {
      eski.controller.removeListener(_degisti);
      widget.controller.addListener(_degisti);
    }
  }

  @override
  void dispose() {
    // ⚠️ Denetleyici CAGIRANA ait — yalniz dinleyici kaldirilir, `dispose`
    //    EDILMEZ (eden taraf onu hala kullaniyor olabilir).
    widget.controller.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bicimHatasi = authTelefonHatasi(widget.controller.text);
    final kirmizi = widget.hataliMi || bicimHatasi != null;
    // ⚠️⚠️ TURU 126 — **DOLUYKEN TAM SIYAH** (kullanici emri: *"numara
    //	yazdigimizda numara tam siyah olmali"*). Bos alanda ipucuyla ayni
    //	soluklukta durur; ilk hane girilir girilmez deger `authYazi`ye
    //	gecer ve `+90` da onunla birlikte koyulasir — numara TEK BUTUN.
    final dolu = widget.controller.text.isNotEmpty;
    final stil = authDegerStili(
      hatali: kirmizi,
      boy: widget.sade ? authSadeDegerBoy : null,
      sade: widget.sade && !dolu,
    );
    // ⚠️ TURU 126 — sade modda `+90` **IPUCUYLA AYNI SOLUKLUKTA**: yazilan
    //    haneler bir tik koyu kalir, on ek geride durur (kullanici emri:
    //    *"hepsi hafif gri, mevcut telefon girisi bir tik ustunde renk"*).
    // ⚠️ Hatada IKISI DE kirmizi olur — numara tek butun okunmali.
    // ⚠️⚠️ TURU 126 — **ON EK, DEGER GIRILINCE KOYULASIR** (kullanici emri:
    //	*"telefon yazdigimda +90 da siyahlassin"*). Alan BOSKEN `+90`
    //	ipucuyla ayni soluklukta durur (ikisi birlikte tek bir "yer tutucu"
    //	gibi okunur); kullanici yazmaya baslayinca numara TEK BUTUN olur ve
    //	on ek de degerin rengine gecer.
    // ⚠️ Hatada zaten IKISI DE kirmizi.
    final onEkStili = widget.sade && !kirmizi && !dolu
        ? stil.copyWith(color: authSadeSoluk)
        : stil;
    // ⚠️⚠️ TURU 126b — **SADE MODDA ERISILEBILIRLIK ADI ACIKCA VERILIR**
    //	(denetim bulgusu). Sade dalda `labelText` CIZILMIYOR; alanin adini
    //	tasiyan tek sey `hintText` ve o da **alan dolunca kayboluyor** —
    //	TalkBack numarayi duzeltmek isteyen kullaniciya alani ISIMSIZ okurdu.
    // ⚠️ Cizgili dalda GEREKSIZ: `labelText` zaten hem cizilir hem okunur.
    final alan = Semantics(
      label: widget.sade ? widget.etiket : null,
      textField: true,
      child: TextField(
        controller: widget.controller,
        keyboardType: TextInputType.phone,
        textInputAction: widget.textInputAction,
        style: stil,
        // ⚠️⚠️⚠️ TURU 126 — **TELEFON SADE MODDA DA SOLA DAYALI. OLCULDU.**
        //	Ilk yazimda `textAlign: center` denendi ve EMULATORDE BOZUK
        //	CIKTI: `+90` SOL UCTA kaldi, haneler ORTADA — numara ikiye
        //	bolunmus gorunuyordu.
        //	KOK NEDEN: `InputDecorator` on eki ve girisi bir satirda YAN
        //	YANA dizer; giris kalan alani `Expanded` gibi alir ve
        //	`textAlign` YALNIZ O ALANIN icinde hizalar. Yani on ek
        //	ORTALAMAYA KATILMAZ — hicbir `textAlign` degeri `+90` ile
        //	haneleri tek blok yapamaz.
        // ⚠️ Sola dayali olmasi ayrica DAHA TUTARLI: baslik da sol dayali,
        //    alan onun tam altinda ve ayni x'ten basliyor.
        // ⚠️ YAPMA: burada `textAlign.center` deneme; ortalamak isteniyorsa
        //    `prefixText` BIRAKILIP kendi `Row`u kurmak gerekir ve o zaman
        //    bos alanda genislik cokup ipucu kaybolur (`IntrinsicWidth`
        //    `hintText`i OLCMEZ, yalniz mevcut metni olcer).
        // ⚠️ Tavan BICIMLENDIRICIDE (bkz. serhi).
        inputFormatters: const [AuthTelefonBicimlendirici()],
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration:
            authAlan(
              widget.etiket,
              hataliMi: kirmizi,
              sade: widget.sade,
              // ⚠️ Cizgi de doluyken koyulasir (kullanici: *"numara
              //    yazarken alt cizgi gri kaliyor"*).
              sadeKoyuCizgi: dolu,
            ).copyWith(
              // ⚠️ IKI BOSLUK: kullanici *"arasinda biraz bosluk"* dedi. Tek
              //    bosluk `+90532...` gibi bitisik okunuyordu.
              prefixText: '$authUlkeKodu ',
              // ⚠️ On ek DEGERLE AYNI STILDE (kullanici: *"ayni font size
              //    ile"*) ve hatada O DA kirmizi olur — numara tek bir butun
              //    olarak okunmali.
              prefixStyle: onEkStili,
              hintText: '512 345 67 89',
            ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        alan,
        if ((bicimHatasi ?? widget.not) != null)
          authNot((bicimHatasi ?? widget.not)!),
      ],
    );
  }
}

// ═══════════════════════ SIFRE ALANI ═══════════════════════

/// ⚠️⚠️⚠️ TURU 120 — SIFRE ALANI (kullanici emri: *"sifrede daireler daha
///	buyuk, biraz bosluk olsun"*).
///
/// ⚠️⚠️ **`letterSpacing` KULLANILDI — PROJE YASAGININ BILINCLI ISTISNASI.**
///	CLAUDE.md *"harf araligi YASAK"* der; o kural **GORUNEN METIN**
///	basliklari icindir (turu 96u: "Kategoriler" gibi). Belgeli iki
///	istisna zaten vardi: **OTP hane araligi** ve hikaye metni. Gizli
///	sifre alani OTP ile AYNI SINIFTA — okunan sey harf degil, SAYILABILIR
///	SEMBOL; aralik olmadan noktalar tek bir bulanik seride donusur.
///	⚠️ Aralik YALNIZ GIZLIYKEN uygulanir: kullanici gozu acinca gercek
///	   sifresini normal aralikla gorur (aralikli metin okunmasi zor).
///
/// ⚠️ `obscuringCharacter` varsayilani `•` (U+2022) — kucuk. `●` (U+25CF)
///    gorsel olarak belirgin daha buyuk bir daire.
///    ⚠️ EMULATORDE DOGRULANACAK: yazi tipi bu glifi tasimazsa kutu (tofu)
///       cizilir; o durumda `•`ye donulur ve boy artisiyla yetinilir.
class AuthSifreAlani extends StatefulWidget {
  const AuthSifreAlani({
    super.key,
    required this.controller,
    this.etiket = 'Şifre',
    this.ipucu,
    this.hataliMi = false,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.sade = false,
  });

  final TextEditingController controller;
  final String etiket;
  final String? ipucu;
  final bool hataliMi;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// Cizgisiz + ortali + 24 px gorunum (bkz. `authAlan` sade serhi).
  final bool sade;

  @override
  State<AuthSifreAlani> createState() => _AuthSifreAlaniState();
}

class _AuthSifreAlaniState extends State<AuthSifreAlani> {
  bool _gizli = true;

  @override
  Widget build(BuildContext context) {
    final tabanBoy = widget.sade ? authSadeDegerBoy : authDegerBoy;
    final temel = authDegerStili(
      hatali: widget.hataliMi,
      boy: tabanBoy,
      sade: widget.sade,
    );
    return TextField(
      controller: widget.controller,
      obscureText: _gizli,
      obscuringCharacter: '●',
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      // ⚠️ TURU 126 — SIFRE DE SOLA DAYALI: kardes telefon alani (on ek
      //    yuzunden) ortalanamiyor; ikisi farkli hizada olsaydi ust uste
      //    duran iki satir birbirinden KACIK gorunurdu.
      style: _gizli
          // ⚠️ Gizliyken daireler 3 px daha buyuk ve 5 px aralikli
          //    (kullanici olcusu: *"daireler daha buyuk, biraz bosluk"*).
          ? temel.copyWith(fontSize: tabanBoy + 3, letterSpacing: 5)
          : temel,
      decoration: authAlan(
        widget.etiket,
        ipucu: widget.ipucu,
        hataliMi: widget.hataliMi,
        sade: widget.sade,
        sonek: IconButton(
          icon: Icon(
            _gizli ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 20,
            color: authAltYazi,
          ),
          onPressed: () => setState(() => _gizli = !_gizli),
        ),
      ),
    );
  }
}

/// Tam genislikte mor ana dugme.
///
/// ⚠️ `foregroundColor` ACIKCA beyaz: verilmezse `FilledButton` yazi rengini
///    `colorScheme.onPrimary`den alir ve koyu temada mor dugmede **~1.9:1**
///    kontrast cikar (turu 85b denetim bulgusu).
/// ⚠️ Devre disi renkleri de acikca verilir; temanin gri tonu beyaz zeminde
///    kayboluyordu.
/// ⚠️⚠️⚠️ TURU 126 — **[hap] KULLANICI REFERANSIYLA GELDI** ve turu 119'un
///	*"butonlari radus kaldir"* emriyle CELISIYOR gibi gorunur; celiski
///	YOKTUR cunku iki emir FARKLI EKRANLAR icindir:
///	  · turu 119 emri **alt cizgili "duz/minimal" dil** icin verildi ve
///	    kayit akisi HALA o dili konusuyor -> orada `hap: false` KALIR,
///	  · turu 126 referansi YALNIZ giris ekranini kapsiyor
///	    (*"tekrar hosgeldin sayfasini boyle yap"*).
/// ⚠️⚠️ **BU YUZDEN BAYRAK, GLOBAL DEGISIKLIK DEGIL.** `authAnaDugme` bes
///	ekran tarafindan cagriliyor (giris · kayit akisi · sifre unuttum ·
///	OTP · kayit); varsayilani degistirmek DORDUNU habersizce degistirirdi.
///	⚠️ YAPMA: varsayilani `true` yapma.
///
/// ⚠️ GLOW `BoxShadow` ile ve dugmenin ARKASINDAN gelir: `FilledButton`
///    golge rengini `shadowColor`dan alir ama Material 3 `elevation`i
///    varsayilan 0 tutar ve tint mantigi araya girer — sonuc referanstaki
///    yumusak renkli parilti DEGIL, sert bir gri golge olurdu.
/// ⚠️ Sarmalayicinin yaricapi dugmeyle **BIREBIR AYNI** olmak zorunda:
///    farkli olsaydi parilti kose diplerinde kalin, kenarlarda ince cikardi.
Widget authAnaDugme({
  required String etiket,
  required VoidCallback? basildi,
  required bool mesgul,
  bool hap = false,
}) {
  final yaricap = BorderRadius.circular(hap ? 28 : 0);
  final dugme = SizedBox(
    width: double.infinity,
    height: hap ? 56 : 52,
    child: FilledButton(
      onPressed: mesgul ? null : basildi,
      style: FilledButton.styleFrom(
        backgroundColor: morLogo,
        foregroundColor: Colors.white,
        disabledBackgroundColor: morLogo.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white,
        // ⚠️⚠️ TURU 119 — **RADIUS KALDIRILDI** (kullanici emri: *"giris yap
        //	vs butonlari radus kaldir"*). Onceden 26 dp (tam hap).
        //	Duz kose, ALT CIZGILI alanlarla ayni "duz/minimal" dili
        //	konusuyor; hap dugme o dilin yaninda yumusak kaliyordu.
        // ⚠️ `RoundedRectangleBorder` KALDIRILMADI, yaricapi SIFIRLANDI:
        //    tamamen kaldirilirsa `FilledButton` TEMA yaricapina duser
        //    (Material 3: tam hap) ve degisiklik SESSIZCE geri alinir.
        shape: RoundedRectangleBorder(borderRadius: yaricap),
      ),
      child: mesgul
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              etiket,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
    ),
  );
  // ⚠️⚠️ TURU 126b — **MESGULKEN PARILTI CIZILMEZ (denetim bulgusu).**
  //	`BoxDecoration` golgeyi dugmenin ALTINI da boyayacak sekilde cizer
  //	(kirpmaz); devre disi zemin `%45 alfali` oldugu icin yukleme
  //	sirasinda parilti **DUGMENIN ICINDEN** gorunuyordu — spinner mor bir
  //	bulutun icinde kaliyordu.
  if (!hap || mesgul) return dugme;
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: yaricap,
      boxShadow: [
        BoxShadow(
          color: morLogo.withValues(alpha: 0.42),
          blurRadius: 26,
          spreadRadius: -6,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: dugme,
  );
}
