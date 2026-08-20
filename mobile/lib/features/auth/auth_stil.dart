/// ⚠️⚠️⚠️ TURU 89 — KIMLIK EKRANLARININ **TEK GORSEL KAYNAGI**.
///
/// Kullanici emri: *"kayit ekranindaki tarzin aynisi giriste de olsun"*.
///
/// Bu dosya olmadan iki yol vardi:
///   (a) `login_screen`e ayni renkleri/bicimleri ELLE kopyalamak — bu projede
///       **"ayni kuralin iki kopyasi DRIFT EDER"** hatasi ALTI kez yasandi;
///       biri degistiginde oteki geride kalir ve iki ekran birbirinden
///       gorsel olarak ayrilirdi.
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
Widget authBaslik(String baslik, String aciklama) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      baslik,
      textAlign: TextAlign.left,
      style: const TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: authYazi,
      ),
    ),
    const SizedBox(height: 8),
    Text(
      aciklama,
      textAlign: TextAlign.left,
      style: const TextStyle(fontSize: 14.5, height: 1.5, color: authAltYazi),
    ),
    const SizedBox(height: 26),
  ],
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
///
/// ⚠️ Alt cizgi **2 px** (kullanici olcusu). Odakta MARKA MORU, hatada
///    KIRMIZI; kalinlik UC HALDE DE 2 px kalir — degisseydi alanin ic
///    yuksekligi oynar ve yazi 1 px ZIPLARDI.
/// ⚠️ [hataliMi] bir `errorText` DEGIL: kullanici yalnizca "input kirmizi
///    olsun" dedi, alanin altina ikinci bir hata satiri istemedi (mesaj
///    zaten SnackBar'da gosteriliyor). `errorText` verilseydi alanin
///    yuksekligi de degisir ve form ziplardi.
/// ⚠️ YAPMA: `OutlineInputBorder`a geri donme.
InputDecoration authAlan(
  String etiket, {
  String? ipucu,
  Widget? sonek,
  bool hataliMi = false,
}) {
  UnderlineInputBorder cizgi(Color renk) => UnderlineInputBorder(
    borderSide: BorderSide(color: renk, width: 2),
  );
  final normal = hataliMi ? authHata : authCizgi;
  final odak = hataliMi ? authHata : morLogo;
  return InputDecoration(
    labelText: etiket,
    hintText: ipucu,
    suffixIcon: sonek,
    // ⚠️ Etiket DAIMA USTTE (bkz. serh).
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: TextStyle(
      color: hataliMi ? authHata : authAltYazi,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: TextStyle(
      color: hataliMi ? authHata : authAltYazi,
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    ),
    hintStyle: TextStyle(color: authAltYazi.withValues(alpha: 0.45)),
    // ⚠️ Yan dolgu SIFIR: alt cizgili alanda ic dolgu, yaziyi cizginin
    //    baslangicindan iceri kaydirir ve hizalama bozulur.
    contentPadding: const EdgeInsets.only(top: 10, bottom: 10),
    enabledBorder: cizgi(normal),
    focusedBorder: cizgi(odak),
    errorBorder: cizgi(authHata),
    focusedErrorBorder: cizgi(authHata),
    disabledBorder: cizgi(authCizgi),
    border: cizgi(normal),
  );
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(
            etiket,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
  ),
);
