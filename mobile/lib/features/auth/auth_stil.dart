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
class AuthSayfa extends StatelessWidget {
  const AuthSayfa({super.key, required this.child});

  final Widget child;

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
        child: Scaffold(backgroundColor: Colors.white, body: child),
      ),
    );
  }
}

/// Sola dayali baslik + altinda aciklama (kayit akisinin dili).
///
/// ⚠️ TURU 120 — kullanici emri: *"Tekrar hos geldin altindaki aciklamayi daha
///    profesyonel yap, IKISINI DE 2px daha buyuk yap"* -> 26 -> **28**,
///    14.5 -> **16.5**.
Widget authBaslik(String baslik, String aciklama) => Column(
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
    const SizedBox(height: 9),
    Text(
      aciklama,
      textAlign: TextAlign.left,
      style: const TextStyle(fontSize: 16.5, height: 1.45, color: authAltYazi),
    ),
    const SizedBox(height: 28),
  ],
);

/// Alan icindeki DEGERIN stili (etiketin altindaki asil yazi).
///
/// ⚠️ TURU 120 — hatada YAZI DA kirmizi olur (kullanici emri: *"5 ile
///    baslamazsa kirmizi olsun HEM YAZI HEM CIZGI"*). Turu 119'da yalnizca
///    cizgi ve etiket kirmiziya donuyordu; kullanicinin yazdigi rakamlar
///    siyah kaliyordu ve hatanin NEREDE oldugu belirsizdi.
TextStyle authDegerStili({bool hatali = false}) => TextStyle(
  color: hatali ? authHata : authYazi,
  fontSize: authDegerBoy,
  fontWeight: FontWeight.w500,
);

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
InputDecoration authAlan(
  String etiket, {
  String? ipucu,
  Widget? sonek,
  bool hataliMi = false,
}) {
  UnderlineInputBorder cizgi(Color renk) =>
      UnderlineInputBorder(borderSide: BorderSide(color: renk, width: 2));
  final normal = hataliMi ? authHata : authCizgi;
  final odak = hataliMi ? authHata : morLogo;
  final etiketStili = TextStyle(
    color: hataliMi ? authHata : authAltYazi,
    fontSize: authEtiketBoy,
    fontWeight: FontWeight.w600,
  );
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
          size: 14,
          color: renk,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            mesaj,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: renk),
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
String authTamNumara(String haneler) => '$authUlkeKodu${haneler.trim()}';

/// Numarayi EKRANDA gostermek icin bicimlendirir: `+90 532 123 45 67`.
///
/// ⚠️⚠️ **`authTamNumara` ILE KARISTIRMA.** Bu yalniz GORUNUM icindir;
///	sunucuya BOSLUKLU numara gonderilirse dogrulama basarisiz olur.
///	Sunucuya giden TEK yol `authTamNumara`dir.
/// ⚠️ 10 hane degilse OLDUGU GIBI dondurulur: yarim yazilmis bir numarayi
///    zorla gruplamak ("+90 55 " gibi) kullaniciya bozuk gorunurdu.
String authNumaraGoster(String haneler) {
  final h = haneler.trim();
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
  final h = haneler.trim();
  if (h.isEmpty) return null;
  if (!h.startsWith('5')) {
    return 'Numara 5 ile başlamalı — alan kodu olmadan yaz (örnek: 532 123 45 67).';
  }
  return null;
}

/// Gonderilebilir mi (10 hane ve 5 ile basliyor).
bool authTelefonTam(String haneler) {
  final h = haneler.trim();
  return h.length == authTelefonHane && h.startsWith('5');
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
    final stil = authDegerStili(hatali: kirmizi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.phone,
          textInputAction: widget.textInputAction,
          style: stil,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(authTelefonHane),
          ],
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          decoration: authAlan(widget.etiket, hataliMi: kirmizi).copyWith(
            // ⚠️ IKI BOSLUK: kullanici *"arasinda biraz bosluk"* dedi. Tek
            //    bosluk `+90532...` gibi bitisik okunuyordu.
            prefixText: '$authUlkeKodu  ',
            // ⚠️ On ek DEGERLE AYNI STILDE (kullanici: *"ayni font size
            //    ile"*) ve hatada O DA kirmizi olur — numara tek bir butun
            //    olarak okunmali.
            prefixStyle: stil,
            hintText: '5xx xxx xx xx',
          ),
        ),
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
  });

  final TextEditingController controller;
  final String etiket;
  final String? ipucu;
  final bool hataliMi;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  State<AuthSifreAlani> createState() => _AuthSifreAlaniState();
}

class _AuthSifreAlaniState extends State<AuthSifreAlani> {
  bool _gizli = true;

  @override
  Widget build(BuildContext context) {
    final temel = authDegerStili(hatali: widget.hataliMi);
    return TextField(
      controller: widget.controller,
      obscureText: _gizli,
      obscuringCharacter: '●',
      textInputAction: widget.textInputAction,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: _gizli
          // ⚠️ Gizliyken daireler 3 px daha buyuk ve 5 px aralikli
          //    (kullanici olcusu: *"daireler daha buyuk, biraz bosluk"*).
          ? temel.copyWith(fontSize: authDegerBoy + 3, letterSpacing: 5)
          : temel,
      decoration: authAlan(
        widget.etiket,
        ipucu: widget.ipucu,
        hataliMi: widget.hataliMi,
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
Widget authAnaDugme({
  required String etiket,
  required VoidCallback? basildi,
  required bool mesgul,
}) => SizedBox(
  width: double.infinity,
  height: 52,
  child: FilledButton(
    onPressed: mesgul ? null : basildi,
    style: FilledButton.styleFrom(
      backgroundColor: morLogo,
      foregroundColor: Colors.white,
      disabledBackgroundColor: morLogo.withValues(alpha: 0.45),
      disabledForegroundColor: Colors.white,
      // ⚠️⚠️ TURU 119 — **RADIUS KALDIRILDI** (kullanici emri: *"giris yap
      //	vs butonlari radus kaldir"*). Onceden 26 dp (tam hap).
      //	Duz kose, yeni ALT CIZGILI alanlarla ayni "duz/minimal" dili
      //	konusuyor; hap dugme o dilin yaninda yumusak kaliyordu.
      // ⚠️ `RoundedRectangleBorder` KALDIRILMADI, yaricapi SIFIRLANDI:
      //    tamamen kaldirilirsa `FilledButton` TEMA yaricapina duser
      //    (Material 3: tam hap) ve degisiklik SESSIZCE geri alinir.
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
