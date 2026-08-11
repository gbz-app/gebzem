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

/// Metin alani bicimi.
InputDecoration authAlan(String etiket, {String? ipucu, Widget? sonek}) =>
    InputDecoration(
      labelText: etiket,
      hintText: ipucu,
      suffixIcon: sonek,
      labelStyle: const TextStyle(color: authAltYazi),
      hintStyle: TextStyle(color: authAltYazi.withValues(alpha: 0.6)),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: authCizgi),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: morLogo, width: 1.6),
      ),
      border: const OutlineInputBorder(),
    );

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
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
