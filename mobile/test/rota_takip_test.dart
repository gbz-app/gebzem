/// ⚠️⚠️⚠️ TURU 151 — **ROTA TAKIBI MUHAFIZI**.
///
/// Kullanicinin sorusu: *"telefonla yurudugumde arkamdan shape gidecek mi?"*
/// Cevap "evet" ise, o "evet"in DOGRU calistigi OLCULMEK zorunda: bu mantik
/// ekranda ancak GERCEK BIR YURUYUSLE gorulebilir ve emulatorde GPS fix'i
/// HIC gelmiyor. Yani bu dosya, ozelligin sinanabildigi TEK yer.
///
/// ⚠️ Kapsanan tuzaklar (hepsi bu projede DAHA ONCE sahaya cikmis siniflar):
///	· `cos(enlem)` duzeltmesi (turu 85b: %24 hata)
///	· NaN'in sessizce dusmesi (turu 85b)
///	· monotonluk (cizginin ileri geri oynamasi)
///	· dongusel rotada YANLIS segmente yapisma
///	· bos (bekleme) bacaginda KILITLENME
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/ulasim/rota_takip.dart';

/// Gebze civarinda dogu-bati uzanan duz bir yol (~40,80 enlem).
List<({double enlem, double boylam})> _duzYol() => const [
      (enlem: 40.8000, boylam: 29.4300),
      (enlem: 40.8000, boylam: 29.4310),
      (enlem: 40.8000, boylam: 29.4320),
      (enlem: 40.8000, boylam: 29.4330),
    ];

void main() {
  turu158bMuhafizlari();
  group('yapistir', () {
    test('nokta cizginin USTUNDEYSE uzaklik ~0 ve dogru segment', () {
      final iz = yapistir(_duzYol(), 40.8000, 29.4315)!;
      expect(iz.segment, 1);
      expect(iz.t, closeTo(0.5, 0.01));
      expect(iz.uzaklikM, lessThan(1.0));
    });

    test('⚠️ BOYLAM `cos(enlem)` ILE OLCEKLENIR (turu 85b dersi)', () {
      // 40,8 enleminde 0,001 derece BOYLAM ~84 m, 0,001 derece ENLEM ~111 m.
      // Duzeltme yapilmasaydi ikisi ESIT cikardi ve izdusum kayardi.
      final boy = metre(40.80, 29.4300, 40.80, 29.4310);
      final en = metre(40.80, 29.4300, 40.8010, 29.4300);
      expect(boy, closeTo(84.2, 2.0));
      expect(en, closeTo(111.3, 2.0));
      // Oran cos(40.8) = 0,757
      expect(boy / en, closeTo(0.757, 0.02));
    });

    test('ardisik TEKRARLI nokta dogru segmenti bozmaz', () {
      // GTFS sekillerinde ayni koordinat iki kez gercekten var.
      final yol = <({double enlem, double boylam})>[
        (enlem: 40.8000, boylam: 29.4300),
        (enlem: 40.8000, boylam: 29.4300), // TEKRAR
        (enlem: 40.8000, boylam: 29.4320),
      ];
      final iz = yapistir(yol, 40.8000, 29.4310)!;
      expect(iz.t.isNaN, isFalse);
      expect(iz.segment, 1);
    });

    test('TAMAMEN TEKRARLI yol NaN uretmez, gercek uzaklik doner', () {
      // ⚠️⚠️ **DURUST NOT:** bu bir "kapi muhafizi" DEGIL, bir DAVRANIS
      //    testidir. `l2 > 0` kapisi bozularak denendi ve test YESIL
      //    KALDI; sebebi olculdu: `num.clamp` `<` degil `compareTo`
      //    kullanir, `double.compareTo`da NaN EN BUYUKtur ve
      //    `NaN.clamp(0.0, 1.0)` **1.0** doner. Yani NaN kapiya
      //    ULASMADAN yutuluyor.
      // ⚠️ Test yine de degerli: tekrarli noktali GERCEK bir GTFS
      //    seklinde sonucun SONLU ve DOGRU kaldigini olcuyor.
      final yol = <({double enlem, double boylam})>[
        (enlem: 40.8000, boylam: 29.4300),
        (enlem: 40.8000, boylam: 29.4300),
        (enlem: 40.8000, boylam: 29.4300),
      ];
      final iz = yapistir(yol, 40.8010, 29.4300)!;
      expect(iz.uzaklikM.isFinite, isTrue);
      expect(iz.uzaklikM, closeTo(111.3, 3.0));
      expect(iz.t.isNaN, isFalse);
    });

    test('⚠️ ARAMA PENCERESI: onceki segmentin GERISINE bakilmaz', () {
      // Kullanici 2. segmentteyken cizginin BASINA yakin bir nokta gelse
      // bile (GPS sicramasi), pencere geriye bakmadigi icin ilerleme
      // GERI DONMEZ.
      final iz = yapistir(_duzYol(), 40.8000, 29.4301, basSegment: 2)!;
      expect(iz.segment, greaterThanOrEqualTo(2));
    });

    test('iki noktadan kisa yol null doner', () {
      expect(yapistir(const [(enlem: 40.8, boylam: 29.4)], 40.8, 29.4), isNull);
    });
  });

  group('kalanYol / kalanMetre', () {
    test('kalan yol KULLANICININ BULUNDUGU yerden baslar', () {
      final yol = _duzYol();
      final iz = yapistir(yol, 40.8000, 29.4315)!;
      final k = kalanYol(yol, iz);
      // Ilk oge izdusumun kendisi, arkada kuyruk YOK.
      expect(k.first.boylam, closeTo(29.4315, 0.0001));
      expect(k.length, 3); // iz + 29.4320 + 29.4330
    });

    test('kalan mesafe yol boyunca AZALIR', () {
      final yol = _duzYol();
      final a = kalanMetre(yol, yapistir(yol, 40.8000, 29.4305)!);
      final b = kalanMetre(yol, yapistir(yol, 40.8000, 29.4325)!);
      expect(b, lessThan(a));
    });

    test('toplam uzunluk ~253 m (3 x 84 m)', () {
      expect(yolUzunlugu(_duzYol()), closeTo(252.6, 5.0));
    });
  });

  group('ilerlet', () {
    List<List<({double enlem, double boylam})>> bacaklar() => [
          _duzYol(),
          const [], // ⚠️ BEKLEME BACAGI - polyline YOK
          const [
            (enlem: 40.8000, boylam: 29.4330),
            (enlem: 40.8100, boylam: 29.4330),
          ],
        ];

    test('yol boyunca ilerledikce kalan mesafe AZALIR', () {
      var d = TakipDurumu.basla;
      d = ilerlet(d, bacaklar(), 40.8000, 29.4302);
      final ilk = d.kalanM;
      d = ilerlet(d, bacaklar(), 40.8000, 29.4318);
      expect(d.kalanM, lessThan(ilk));
      expect(d.bacak, 0);
      expect(d.rotaDisi, isFalse);
    });

    test('⚠️⚠️ MONOTON: GPS geri sicrarsa segment GERI GITMEZ '
        '(asil muhafiz ARAMA PENCERESI, math.max yedek)', () {
      var d = TakipDurumu.basla;
      d = ilerlet(d, bacaklar(), 40.8000, 29.4325); // segment 2
      final ileri = d.segment;
      expect(ileri, greaterThanOrEqualTo(2));
      d = ilerlet(d, bacaklar(), 40.8000, 29.4301); // basa sicrama
      expect(d.segment, greaterThanOrEqualTo(ileri));
    });

    test('⚠️ BOS (BEKLEME) BACAGI ATLANIR, takip KILITLENMEZ', () {
      var d = TakipDurumu.basla;
      // Birinci bacagin SONUNA gel -> ikinci bacak BOS, ucuncuye gecmeli.
      d = ilerlet(d, bacaklar(), 40.8000, 29.4330);
      expect(d.bacak, 2, reason: 'bos bacak atlanmali');
      expect(d.bitti, isFalse);
    });

    test('son bacagin sonunda BITTI', () {
      var d = TakipDurumu.basla;
      d = ilerlet(d, bacaklar(), 40.8000, 29.4330); // bacak 2'ye gec
      d = ilerlet(d, bacaklar(), 40.8100, 29.4330); // bacak 2'nin sonu
      expect(d.bitti, isTrue);
    });

    test('⚠️ ROTA DISINDA ilerleme YAZILMAZ ama durum doner', () {
      var d = TakipDurumu.basla;
      d = ilerlet(d, bacaklar(), 40.8000, 29.4305);
      final s = d.segment;
      // ~330 m kuzeye sap (esik 60 m)
      d = ilerlet(d, bacaklar(), 40.8030, 29.4305);
      expect(d.rotaDisi, isTrue);
      expect(d.segment, s, reason: 'rota disinda segment ILERLEMEZ');
    });

    test('⚠️⚠️ BAYAT DURUM BOS BACAGI GOSTERSE DE KILITLENMEZ', () {
      // ⚠️ `ilerlet` govdesinin BASINDAKI atlama dongusunu olcer.
      //    "Bacak bitti" dalindaki KARDES dongu bu vakayi GORMEZ:
      //    oraya ancak bir bacak TAMAMLANARAK gelinir.
      const bayat = TakipDurumu(
        bacak: 1, // BOS (bekleme) bacagi
        segment: 0,
        kalanM: 100,
        rotaDisi: false,
        bitti: false,
      );
      final d = ilerlet(bayat, bacaklar(), 40.8050, 29.4330);
      expect(d.bacak, 2,
          reason: 'bos bacakta KILITLENMEMELI');
    });

    test('bitmis durum bir daha ilerlemez', () {
      const bitmis = TakipDurumu(
        bacak: 0,
        segment: 0,
        kalanM: 0,
        rotaDisi: false,
        bitti: true,
      );
      final d = ilerlet(bitmis, bacaklar(), 40.8000, 29.4300);
      expect(d.bitti, isTrue);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════
// TURU 158b — YAYIN ONCESI DENETIMDE BULUNAN UC ARIZANIN MUHAFIZI.
// Ucu de once BOZULARAK kirmiziya dusuruldu (bkz. oturum.md).
// ═══════════════════════════════════════════════════════════════════
void turu158bMuhafizlari() {
  // duz, dogu-bati, ~11 m'lik segmentler
  List<({double enlem, double boylam})> duzYol(int n) => [
        for (var i = 0; i < n; i++) (enlem: 40.80, boylam: 29.40 + i * 0.0001),
      ];

  test('⚠️⚠️⚠️ ROTA DISI KALICI KILITLENMEZ (pencere ileri tasinir)', () {
    final yol = duzYol(200);
    // 0. segmentte basla
    var d = ilerlet(TakipDurumu.basla, [yol], 40.80, 29.4000);
    expect(d.rotaDisi, isFalse);
    // Kullanici IKI GPS olayi arasinda 40 segmentten COK ilerledi
    // (telefon cepte, akis kisildi). Eski govdede bu KALICI rotaDisi idi.
    final ileriBoylam = 29.40 + 120 * 0.0001;
    d = ilerlet(d, [yol], 40.80, ileriBoylam);
    expect(d.rotaDisi, isFalse,
        reason: 'global yeniden yakalama YAPILMADI -> kalici kilitlenme');
    expect(d.segment, greaterThan(100));
    // ve ilerlemeye DEVAM edebilmeli
    final d2 = ilerlet(d, [yol], 40.80, 29.40 + 150 * 0.0001);
    expect(d2.segment, greaterThan(d.segment));
  });

  test('⚠️⚠️ GERCEK GERI YURUME: mandal ust uste iki olcumde BIRAKILIR', () {
    final yol = duzYol(50);
    // segment 10'un ortasina git
    var d = ilerlet(TakipDurumu.basla, [yol], 40.80, 29.40 + 10.5 * 0.0001);
    final ileriKalan = d.kalanM;
    // ayni segmentte ~6 m geri (GPS gurultusu): YUTULMALI
    d = ilerlet(d, [yol], 40.80, 29.40 + 10.0 * 0.0001);
    expect(d.kalanM, closeTo(ileriKalan, 0.01),
        reason: 'tek gurultulu fix mandali BIRAKMAMALI');
    // ust uste IKI kez ~30 m geri: mandal BIRAKILMALI
    final geri = 29.40 + 7.0 * 0.0001;
    d = ilerlet(d, [yol], 40.80, geri);
    d = ilerlet(d, [yol], 40.80, geri);
    expect(d.kalanM, greaterThan(ileriKalan + 10),
        reason: 'gercek geri yurumede kalan mesafe TAKIP ETMELI');
  });

  test('⚠️⚠️ Monotonluk KORUNUR: TEK gurultulu geri fix kalan mesafeyi '
      'BUYUTMEZ', () {
    // ⚠️ Bu test ILK yazimda YANLIS kuruldu: gurultu (2,5 m) ileri adimdan
    //    (8,4 m) KUCUKTU, yani ham izdusum zaten geri gitmiyordu ve test
    //    monotonlugu KALDIRINCA DA YESIL KALIYORDU. Simdi gurultu adimdan
    //    BUYUK secildi ve bozarak kirmiziya dusuruldu.
    final yol = duzYol(60);
    // segment 20'nin sonuna dogru ilerle
    var d = ilerlet(TakipDurumu.basla, [yol], 40.80, 29.40 + 20.8 * 0.0001);
    final ileriKalan = d.kalanM;
    // TEK gurultulu fix: ~7 m geri (kGeriEsikM = 20'nin ALTINDA) -> YUTULMALI
    d = ilerlet(d, [yol], 40.80, 29.40 + 20.0 * 0.0001);
    expect(d.kalanM, lessThanOrEqualTo(ileriKalan + 0.01),
        reason: 'tek gurultulu fix kalan mesafeyi BUYUTTU (monotonluk YOK)');
    expect(d.t, closeTo(0.8, 0.01), reason: 'oran GERI GITTI');
  });
}
