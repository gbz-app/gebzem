// ⚠️⚠️⚠️ TURU 86 — KALICI MUHAFIZ: HARITA STILI OKUNAMAZ HALE GETIRILEMEZ.
//
// NEDEN VAR:
//	Turu 85'te kullanicinin "uber tarzi grimsi beyaz" istegi bir Google Maps
//	stil JSON'una cevrildi ve o JSON haritanin TANIMLAYICI her unsurunu
//	kapatti: `poi` off, `road ... labels` off, `labels.icon` off,
//	`transit` off, `administrative geometry` off. Geriye beyaz cizgili GRI
//	BIR KAGIT kaldi. Kullanici sahada gordu:
//	    "bu nasil bir harita? normal google haritasi degil ki bu"
//
//	Bu hatanin SESSIZ olmasi kritik: `flutter analyze` temiz gecer, uygulama
//	COKMEZ, harita "calisiyor" gorunur — YALNIZCA KULLANILAMAZ olur. Yani
//	yalnizca GOZLE bakan biri yakalayabilir. Bu test o boslugu kapatir.
//
// NE DOGRULAR:
//	1) Harita stili ya YOK (normal Google haritasi) ya da varsa iceriginde
//	   hicbir `visibility: off` BULUNMAZ.
//	2) Harita jestleri (kaydirma/yakinlastirma) ACIK birakilir — kapaliyken
//	   harita canli bir harita degil EKRAN GORUNTUSU gibi durur.
//
// ⚠️ Kaynak DOSYADAN okunur (kopya tutulmaz) -> DRIFT YAPISAL OLARAK IMKANSIZ.
// ⚠️ YAPMA: bu testi silme. Renk tonu istenirse YALNIZCA `geometry` renkleri
//    degistirilir; `visibility: off` EKLENMEZ.
// ⚠️ Test kendi serhindeki ornekleri eslestirmesin diye kaynak once YORUMLARDAN
//    TEMIZLENIR (turu 80b `sutun_test.go` ve turu 83 `utf8_test.go` tuzagi:
//    ikisi de ILK YAZIMDA kendi aciklamasini eslestirip yanlis alarm verdi).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dart kaynagindan `//` ve `/* */` yorumlarini atar.
///
/// ⚠️ Dize icindeki `//` dizisini yorum sanmamak icin basit bir dize-farkindali
///    tarayici kullanilir; `'''` ham dizeleri de korunur.
String yorumsuz(String kaynak) {
  final cikti = StringBuffer();
  var i = 0;
  String? dizeSonu; // acik dizenin kapanis simgesi
  while (i < kaynak.length) {
    final kalan = kaynak.length - i;
    if (dizeSonu == null) {
      if (kalan >= 2 && kaynak.startsWith('//', i)) {
        while (i < kaynak.length && kaynak[i] != '\n') {
          i++;
        }
        continue;
      }
      if (kalan >= 2 && kaynak.startsWith('/*', i)) {
        final son = kaynak.indexOf('*/', i + 2);
        i = son < 0 ? kaynak.length : son + 2;
        continue;
      }
      for (final d in ["'''", '"""', "'", '"']) {
        if (kaynak.startsWith(d, i)) {
          dizeSonu = d;
          cikti.write(d);
          i += d.length;
          break;
        }
      }
      if (dizeSonu != null) continue;
    } else {
      if (kaynak[i] == r'\') {
        cikti.write(kaynak.substring(i, (i + 2).clamp(0, kaynak.length)));
        i += 2;
        continue;
      }
      if (kaynak.startsWith(dizeSonu, i)) {
        cikti.write(dizeSonu);
        i += dizeSonu.length;
        dizeSonu = null;
        continue;
      }
    }
    cikti.write(kaynak[i]);
    i++;
  }
  return cikti.toString();
}

void main() {
  final dosya = File('lib/features/isletme/yakinimda_ekrani.dart');

  test('Yakinimda kaynagi bulunuyor', () {
    expect(dosya.existsSync(), isTrue,
        reason: 'test proje kokunden (mobile/) kosulmali');
  });

  test('harita stili hicbir katmani GIZLEMEZ (okunabilirlik muhafizi)', () {
    final govde = yorumsuz(dosya.readAsStringSync());

    // ⚠️ `visibility` + `off` ayni stil kuralinda gecerse harita katmani
    //    KAPATILIYOR demektir. Normal Google haritasinda bu kelime HIC gecmez.
    // ⚠️⚠️ TIRNAKLAR **KACISLI DA OLABILIR**: stil `'''...'''` ham dizesinde
    //    `"visibility"`, duz `'...'` dizesinde ise `\"visibility\"` olarak
    //    yazilir. Desen ILK YAZIMDA yalniz ilkini yakaliyordu, yani ikinci
    //    bicimle yazilan bir gerileme muhafizdan SESSIZCE GECERDI.
    //    (Kanit: desen kirmiziya dusurulerek IKI BICIMDE de sinandi.)
    final gizleyen =
        RegExp(r'\\?"visibility\\?"\s*:\s*\\?"off\\?"').allMatches(govde);
    expect(
      gizleyen.isEmpty,
      isTrue,
      reason:
          'Harita stilinde ${gizleyen.length} adet "visibility":"off" var. '
          'Bu, sokak adlarini/mekanlari/simgeleri KAPATIR ve haritayi '
          'okunamaz gri bir kagida cevirir (turu 85 hatasi; kullanici '
          '"bu nasil bir harita?" dedi). Renk tonu istiyorsan YALNIZCA '
          '"geometry" renklerini degistir, hicbir katmani gizleme.',
    );
  });

  test('harita jestleri ACIK (harita canli olmali, ekran goruntusu degil)', () {
    final govde = yorumsuz(dosya.readAsStringSync());

    for (final alan in ['scrollGesturesEnabled', 'zoomGesturesEnabled']) {
      expect(
        RegExp('$alan\\s*:\\s*false').hasMatch(govde),
        isFalse,
        reason:
            '$alan: false — harita parmakla oynatilamaz ve kullaniciya '
            'EKRAN GORUNTUSU gibi gorunur (turu 85 hatasi). Liste ile '
            'catisma EagerGestureRecognizer ile cozuluyor; jestleri '
            'kapatarak "cozme".',
      );
    }

    // ⚠️ Jest catismasi kapatilarak degil, recognizer ile cozulmeli.
    expect(
      govde.contains('EagerGestureRecognizer'),
      isTrue,
      reason: 'Harita jestleri acik ama EagerGestureRecognizer YOK — '
          'liste ile dikey kaydirma catismasi geri gelir.',
    );
  });
}
