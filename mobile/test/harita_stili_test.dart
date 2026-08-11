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

import 'dart:convert';
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

  // ═══════════════════════════════════════════════════════════════════════
  // ⚠️⚠️⚠️ TURU 87 — EN PAHALI MUHAFIZ: **DERLEME BAYRAGI ↔ KOD**.
  //
  //	UC SURUM boyunca gercek Google haritasi HIC CIZILMEDI. Sebep:
  //	  CI   : --dart-define=HARITA=1
  //	  Dart : bool.fromEnvironment('HARITA')   // "1" KABUL ETMEZ -> false
  //	Yani kapi hic acilmadi, uygulama hep elle boyanmis yer tutucuyu
  //	gosterdi. Kullanici UC KEZ "bu nasil bir harita?" dedi.
  //
  //	⚠️ **HICBIR DENETIM BUNU GOREMEDI** (52 + 24 ajan): hepsi kod↔kod ve
  //	   kod↔serh tutarliligina bakti. Bu hata **KOD ILE DERLEME
  //	   YAPILANDIRMASI ARASINDA** duruyordu ve o siniri kimse denetlemedi.
  //	   Ustelik anahtarin APK'ya enjekte edildigini dogrulamak "harita
  //	   calisiyor" KANITI SANILDI — oysa enjeksiyon ile bayrak AYRI IKI SEY.
  //
  // ⚠️ Bu test o siniri kapatir: CI dosyalarindaki degeri KODUN kabul ettigi
  //    kumeyle karsilastirir. Ikisi ayrisirsa DERLEME KIRMIZIYA DUSER.
  // ⚠️ YAPMA: bu testi silme; `--dart-define` degerini kodun kabul kumesini
  //    genisletmeden degistirme.
  // ═══════════════════════════════════════════════════════════════════════
  group('derleme bayragi <-> kod', () {
    final akislar = [
      File('../.github/workflows/android.yml'),
      File('../.github/workflows/ios.yml'),
    ];

    test('CI dosyalari bulunuyor', () {
      for (final f in akislar) {
        expect(f.existsSync(), isTrue, reason: '${f.path} yok');
      }
    });

    test('CI HARITA degeri KODUN kabul ettigi bir deger', () {
      // Koddaki kabul kumesi KAYNAKTAN okunur (elle kopyalanmaz -> drift yok).
      final kod = yorumsuz(dosya.readAsStringSync());
      final kabul = RegExp(r"_haritaBayragi\s*==\s*'([^']*)'")
          .allMatches(kod)
          .map((m) => m.group(1)!)
          .toSet();
      expect(kabul, isNotEmpty,
          reason: 'kodda `_haritaBayragi == ...` karsilastirmasi bulunamadi — '
              'bayrak cozumleme bicimi degismis olabilir');

      for (final f in akislar) {
        final ci = f.readAsStringSync();
        final m = RegExp(r'--dart-define=HARITA=([^\s"\x27]+)').firstMatch(ci);
        expect(m, isNotNull,
            reason: '${f.path} icinde --dart-define=HARITA=... YOK — '
                'harita bayragi hic gecilmiyorsa GERCEK HARITA CIZILMEZ');
        final deger = m!.group(1)!;
        expect(
          kabul.contains(deger),
          isTrue,
          reason:
              '${f.path}: --dart-define=HARITA=$deger geciliyor ama kod yalniz '
              '$kabul degerlerini kabul ediyor. Bayrak FALSE kalir ve uygulama '
              'GERCEK GOOGLE HARITASINI HIC CIZMEZ (turu 85-86 hatasi: '
              'CI "1" geciyordu, `bool.fromEnvironment` yalniz "true" kabul eder).',
        );
      }
    });

    test('kod ciplak bool.fromEnvironment KULLANMIYOR', () {
      final kod = yorumsuz(dosya.readAsStringSync());
      expect(
        RegExp(r"bool\.fromEnvironment\(\s*'HARITA'").hasMatch(kod),
        isFalse,
        reason: '`bool.fromEnvironment` YALNIZCA "true"/"false" dizesini kabul '
            'eder; "1" gibi bir deger SESSIZCE false olur. Bayrak DIZEDEN '
            'turetilmeli (bkz. `_haritaBayragi`).',
      );
    });
  });

  test('Yakinimda kaynagi bulunuyor', () {
    expect(dosya.existsSync(), isTrue,
        reason: 'test proje kokunden (mobile/) kosulmali');
  });

  // ═════════════════════════════════════════════════════════════════════
  // ⚠️⚠️⚠️ TURU 89 — MUHAFIZ **KORDU**, GERCEK JSON AYRISTIRMASIYLA ONARILDI.
  //
  //	Turu 86-88 surumu regex'liydi ve `featureType` ile `visibility`nin
  //	AYNI kume parantezinde olmasini bekliyordu. Gercek Google Maps stil
  //	JSON'unda ise `visibility` DAIMA bir ALT nesnededir:
  //	    {"featureType":"poi","stylers":[{"visibility":"off"}]}
  //	                                    ^^^^^ AYRI kume
  //	Desendeki `[^{}]*` bir `{` gecemedigi icin muhafiz **HICBIR SEYI**
  //	eslestiriyordu; kodda duran mevcut kural bile eslesmiyordu. Yani test
  //	YESILDI ama **YANLIS SEBEPTEN**: turu 85'i onlemek icin yazilmis
  //	muhafiz, turu 85'in ta kendisini YAKALAYAMIYORDU.
  //
  // ⚠️ Artik stil METIN olarak degil **jsonDecode ile** okunuyor: yapinin
  //    kendisi geziliyor, bicimlendirmeden (bosluk, satir sonu, tirnak)
  //    TAMAMEN bagimsiz.
  // ⚠️ Stil SAYISI artabilir (sistem/gri/gece) — muhafiz tek bir sabite
  //    baglanmaz, kaynaktaki JSON gibi gorunen HER ham dizeyi dogrular.
  // ⚠️ YAPMA: bunu tekrar regex'e dondurme.
  // ═════════════════════════════════════════════════════════════════════
  test('harita stilleri hicbir kritik katmani GIZLEMEZ', () {
    final govde = yorumsuz(dosya.readAsStringSync());

    final dizeler = RegExp(r"'''([\s\S]*?)'''").allMatches(govde);
    final stiller = <List<dynamic>>[];
    for (final d in dizeler) {
      final ham = d.group(1)!.trim();
      if (!ham.startsWith('[')) continue;
      try {
        final c = jsonDecode(ham);
        if (c is List) stiller.add(c);
      } catch (e) {
        fail('Harita stili GECERLI JSON DEGIL: $e\n$ham');
      }
    }

    expect(
      stiller,
      isNotEmpty,
      reason: 'Kaynakta hicbir harita stili JSON bulunamadi — stil '
          'sabitlerinin bicimi degismis olabilir. Muhafiz KOR kalmasin '
          '(turu 89: onceki desen tam da boyle hicbir seyi eslestirmiyordu).',
    );

    // Kapatilmasi YASAK katmanlar: turu 85'te haritayi okunamaz kilanlar.
    const yasakli = ['road', 'transit', 'administrative', 'landscape', 'water'];

    for (final stil in stiller) {
      for (final kural in stil) {
        if (kural is! Map) continue;
        final stylers = kural['stylers'];
        if (stylers is! List) continue;
        if (!stylers.any((s) => s is Map && s['visibility'] == 'off')) continue;

        final tur = (kural['featureType'] ?? '').toString();
        final oge = (kural['elementType'] ?? '').toString();

        // (1) `featureType` YOKSA kural TUM HARITAYA uygulanir — en yikici hal.
        expect(
          tur.isNotEmpty,
          isTrue,
          reason: 'Stilde `featureType` OLMADAN `visibility: off` var '
              '(elementType: "$oge"). Bu kural TUM haritaya uygulanir; '
              'turu 85te `labels.icon` boyle kapatilmis ve butun simgeler '
              'silinmisti.',
        );

        // (2) Alt tur belirtmeden `poi` -> park/hastane/okul/otogar HEPSI gider.
        // (3) Yol, toplu tasima, idari sinir, zemin ve su ASLA gizlenmez.
        final tehlikeli = tur == 'poi' ||
            yasakli.any((y) => tur == y || tur.startsWith('$y.'));
        expect(
          tehlikeli,
          isFalse,
          reason: 'Harita stili "$tur" katmanini KAPATIYOR '
              '(elementType: "${oge.isEmpty ? "hepsi" : oge}"). Bu, haritayi '
              'okunamaz hale getirir — turu 85te tam bu yapildi ve kullanici '
              'UC KEZ "bu nasil bir harita?" dedi. Yalniz `poi.business` gibi '
              'DAR kurallar kabul edilir.',
        );
      }
    }
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
