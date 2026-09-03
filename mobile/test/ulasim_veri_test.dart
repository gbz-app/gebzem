/// ⚠️⚠️⚠️ TURU 149 — **TOPLU TASIMA VERI ZINCIRI MUHAFIZI.**
///
/// Bu ozellik **emulatorde dogrulanamiyor**: emulatore GPS fix'i hic
/// gelmiyor (turu 140/142/145'te `adb emu geo fix` verilmesine ragmen
/// olculdu) ve durak/hat akisi konuma bagli. O yuzden zincir BURADA,
/// gercek varliklar okunarak sinaniyor:
///
///   varlik -> `polyCoz`/`dizeCoz` -> `yakinDuraklar` -> `duraginHatlari`
///   -> `guzergah`
///
/// ⚠️ Muhafiz GERCEK dosyalari okur (kopya/mock YOK): uretici betik
///    (`tools/ulasim_uret.js`) bozulursa ya da varliklar `pubspec`ten
///    dusersse test KIRMIZI olur. Bu, turu 140'ta yasanan "varliklar
///    diskte var ama git'te/pakette yok" sevk engelinin muhafizidir.
library;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/ulasim/ulasim_veri.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Gebze merkez — ornek kayitlarda da kullanilan referans nokta.
  const gEn = 40.8028;
  const gBoy = 29.4307;

  test('⚠️ VARLIKLAR PAKETTE VAR (bes dosyanin besi de okunabiliyor)', () async {
    for (final f in const [
      'duraklar',
      'hatlar',
      'sekiller',
      'seferler',
      'taksi',
    ]) {
      final s = await rootBundle.loadString('assets/ulasim/$f.json');
      expect(s.length, greaterThan(100), reason: '$f.json bos ya da eksik');
    }
  });

  test('duraklar okunuyor ve Gebze bolgesinde', () async {
    final d = await UlasimVeri.i.duraklar();
    expect(d.length, greaterThan(8000), reason: 'durak sayisi beklenenden az');
    // ⚠️⚠️ TURU 161 — **KUZEY SINIRI 40.92 -> 41.07.**
    //	Kullanici sahada gordu: *"Ovacik koyu, Mudarli koyu, buralarda
    //	duraklar hatlar VAR ama bulmuyor"*. Belediyenin listesindeki 15
    //	duragin 15'i de varlikta YOKTU: ham GTFS'te varlar ama enlemleri
    //	40,911-41,011, yani ureticinin eski kuzey siniri 40,90'in DISINDA.
    //	`tools/ulasim_uret.js` kutusu 41.05'e cikarildi; bu muhafiz da
    //	onunla BIRLIKTE guncellenmek ZORUNDA (yoksa kirmizi duser —
    //	nitekim dustu ve degisikligi DOGRULADI).
    // ⚠️ Sinir uretici kutusundan bir tik GENIS: kutu duragin KENDISINI
    //    filtreliyor, burada kirpma yok.
    for (final x in d.take(200)) {
      expect(x.enlem, inInclusiveRange(40.30, 41.40));
      expect(x.boylam, inInclusiveRange(28.80, 30.70));
      expect(x.ad.trim(), isNotEmpty);
    }
  });

  test('yakin duraklar EN YAKIN ONCE ve yaricap disi ELENIR', () async {
    final y = await UlasimVeri.i.yakinDuraklar(gEn, gBoy, adet: 20);
    expect(y, isNotEmpty, reason: 'Gebze merkezde durak bulunamadi');
    var onceki = -1.0;
    for (final d in y) {
      final m = UlasimVeri.kabaMetre(gEn, gBoy, d.enlem, d.boylam);
      expect(m, lessThanOrEqualTo(1500), reason: 'yaricap disi durak geldi');
      expect(m, greaterThanOrEqualTo(onceki), reason: 'sira bozuk');
      onceki = m;
    }
  });

  test('⚠️ KALKIS SAATLERI GERCEK: en yakin durakta hat + artan saat', () async {
    final y = await UlasimVeri.i.yakinDuraklar(gEn, gBoy, adet: 8);
    expect(y, isNotEmpty);

    // ⚠️ Servisi SABITLIYORUZ (1 = hafta ici): `bugunServis` kullanilsaydi
    //    test PAZAR gunu bambaska bir kumeye bakardi ve "bazen kirmizi"
    //    olurdu (turu 80b'de olculen "yesil, kodun degil TAKVIMIN sonucu"
    //    tuzagi).
    var bulundu = false;
    for (final d in y) {
      final hatlar = await UlasimVeri.i.duraginHatlari(d.id, 1);
      if (hatlar.isEmpty) continue;
      bulundu = true;
      for (final h in hatlar) {
        expect(h.kalkislar, isNotEmpty);
        // ARTAN sirali olmali (`sonrakiler` buna dayaniyor).
        for (var i = 1; i < h.kalkislar.length; i++) {
          expect(h.kalkislar[i], greaterThanOrEqualTo(h.kalkislar[i - 1]));
        }
        // Dakika degerleri makul (0..48 saat; GTFS 24'u asabilir).
        expect(h.kalkislar.first, inInclusiveRange(0, 2880));
        expect(h.hat.kisaAd.trim(), isNotEmpty);
      }
      break;
    }
    expect(bulundu, isTrue, reason: 'hicbir yakin durakta hafta ici sefer yok');
  });

  test('⚠️ GUZERGAH GERCEK: cok noktali ve bolge kutusunda', () async {
    final y = await UlasimVeri.i.yakinDuraklar(gEn, gBoy, adet: 8);
    var cizildi = false;
    for (final d in y) {
      final hatlar = await UlasimVeri.i.duraginHatlari(d.id, 1);
      for (final h in hatlar) {
        final g = await UlasimVeri.i.guzergah(h.hat.id, h.yon);
        if (g.isEmpty) continue;
        cizildi = true;
        // ⚠️ Duz cizgi DEGIL: gercek guzergah onlarca kirilma noktasi tasir.
        expect(g.length, greaterThan(20),
            reason: 'guzergah cok az noktali — sokak takibi kaybolmus olur');
        for (final n in g.take(50)) {
          expect(n.enlem, inInclusiveRange(40.2, 41.5));
          expect(n.boylam, inInclusiveRange(28.7, 30.8));
        }
        break;
      }
      if (cizildi) break;
    }
    expect(cizildi, isTrue, reason: 'hicbir hatta guzergah cizimi bulunamadi');
  });

  test('taksi duraklari cozuluyor (TM30 -> WGS84)', () async {
    final t = await UlasimVeri.i.taksiler();
    expect(t, isNotEmpty);
    for (final x in t) {
      // ⚠️ Projeksiyon donusumu yanlis olsaydi koordinatlar Kocaeli'nin
      //    disina duserdi — bu kapi tam onu yakalar.
      expect(x.enlem, inInclusiveRange(40.60, 41.00),
          reason: '${x.ad} yanlis enlemde: koordinat donusumu bozuk');
      expect(x.boylam, inInclusiveRange(29.20, 29.70),
          reason: '${x.ad} yanlis boylamda: koordinat donusumu bozuk');
      expect(x.ad.trim(), isNotEmpty);
    }
  });

  test('saat bicimi ve gun sarmasi dogru', () {
    expect(UlasimVeri.saatMetni(0), '00:00');
    expect(UlasimVeri.saatMetni(9 * 60 + 5), '09:05');
    expect(UlasimVeri.saatMetni(23 * 60 + 59), '23:59');
    // ⚠️ GTFS'te 25:10 gibi degerler VAR (gece yarisini gecen sefer).
    expect(UlasimVeri.saatMetni(25 * 60 + 10), '01:10');
  });

  test('⚠️ SONRAKI KALKIS: gun sonunda BASA SARAR', () {
    const dh = DurakHatti(
      hat: Hat(
        id: '1',
        kisaAd: '563',
        uzunAd: 'TEST',
        renk: '',
        yonBaslik: {},
        yonSekil: {},
      ),
      yon: 0,
      kalkislar: [330, 400, 500, 1200],
    );
    // Gun ortasinda: sirasi gelen ilk uc kalkis.
    expect(dh.sonrakiler(390, adet: 2), [400, 500]);
    // Gece 23:50 (1430): bugun kalkis YOK -> yarinin ilk seferi +1440.
    expect(dh.sonrakiler(1430, adet: 1), [330 + 1440]);
  });

  test('polyline cozucusu kodlayiciyla uyumlu', () {
    // Google referans ornegi (encoded polyline algorithm dokumani).
    final c = polyCoz('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(c.length, 3);
    expect(c[0].enlem, closeTo(38.5, 0.001));
    expect(c[0].boylam, closeTo(-120.2, 0.001));
    expect(c[2].enlem, closeTo(43.252, 0.001));
    expect(c[2].boylam, closeTo(-126.453, 0.001));
  });
}
