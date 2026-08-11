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

  test('harita stili hicbir katmani GIZLEMEZ (okunabilirlik muhafizi)', () {
    final govde = yorumsuz(dosya.readAsStringSync());

    // ⚠️⚠️ TURU 88 — MUHAFIZ **KATMAN BAZINDA** oldu (once TOPYEKUN yasakti).
    //
    //	Kullanici *"haritadaki isletmeler gorunmeyecek"* dedi; bu, Google'in
    //	kendi TICARI POI etiketlerini kapatmak demek ve MESRU. Ama turu 85'te
    //	haritayi okunamaz kilan sey POI DEGIL, **sokak adlari · toplu tasima ·
    //	simgeler · idari sinirlar** kapatilmasiydi.
    //	Bu yuzden yasak artik TEHLIKELI KATMANLARA ozgu: dar bir
    //	`poi.business` istisnasi gecer, haritayi bosaltan hicbir kural gecmez.
    //
    // ⚠️ TIRNAKLAR **KACISLI DA OLABILIR** (`'''` ham dize vs duz dize) —
    //    desen ikisini de kapsar (ilk yazimda yalniz ham dizeyi yakaliyordu).
    const yasakli = [
      'road',            // SOKAK ADLARI — turu 85'te en yikici olani
      'transit',         // metro/otobus
      'administrative',  // ilce/il sinirlari
      'landscape',       // zemin
      'water',           // su
    ];
    final kurallar = RegExp(
      r'\{[^{}]*\\?"featureType\\?"\s*:\s*\\?"([a-z._]+)\\?"[^{}]*'
      r'\\?"visibility\\?"\s*:\s*\\?"off\\?"',
    ).allMatches(govde.replaceAll(RegExp(r'\s+'), ' '));

    for (final k in kurallar) {
      final tur = k.group(1)!;
      // ⚠️ Alt tur BELIRTILMEDEN `poi` kapatmak TUM mekanlari (park, hastane,
      //    okul, otogar...) siler — bu da haritayi bosaltir.
      final tehlikeli = tur == 'poi' ||
          yasakli.any((y) => tur == y || tur.startsWith('$y.'));
      expect(
        tehlikeli,
        isFalse,
        reason: 'Harita stili "$tur" katmanini KAPATIYOR. Bu, haritayi '
            'okunamaz hale getirir (turu 85 hatasi: kullanici "bu nasil bir '
            'harita?" dedi). Yalniz `poi.business` gibi DAR bir kural kabul '
            'edilir; sokak adlari, toplu tasima, idari sinirlar ve zemin '
            'ASLA gizlenmez.',
      );
    }

    // ⚠️ `featureType` BELIRTMEDEN, yani TUM HARITAYA uygulanan bir
    //    `visibility: off` en yikici bicimdir; ayrica yakalanir.
    final genelKapatma = RegExp(
      r'\{\s*\\?"elementType\\?"[^{}]*\\?"visibility\\?"\s*:\s*\\?"off\\?"',
    ).allMatches(govde.replaceAll(RegExp(r'\s+'), ' '));
    expect(
      genelKapatma.isEmpty,
      isTrue,
      reason: 'Stilde `featureType` OLMADAN (yani TUM harita icin) '
          '`visibility: off` var — turu 85\'te `labels.icon` boyle '
          'kapatilmis ve tum simgeler silinmisti.',
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
