import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/isletme/isletme_kart.dart';
import 'package:gebzem/features/isletme/isletme_servisi.dart';

/// ⚠️⚠️⚠️ TURU 96j — KART META SATIRI (**puan · teslimat · min. tutar ·
///	mesafe**) YAZI KALINLIGI MUHAFIZI.
///
///	Kullanici emri: *"restoran altindaki kartlarin 25-35 dk vb. bunlari bir
///	tik kalinlastir, **filtre vb. gibi** olsun"*. Yani hedef bir tahmin
///	degil, **REFERANSA ESITLENME**: suzgec cipleri `fontSize: 13` +
///	`FontWeight.w600` kullaniyor.
///
/// ⚠️⚠️ **BU HATA GOZLE OLCULEMEZ.** Meta yazisi `soluk` (alpha .62) renkte
///	cizildigi icin ekran goruntusunden cizgi kalinligi olcmek YANILTICI
///	sonuc verir: ayni kalinliktaki soluk yazi, koyu yaziya gore daha INCE
///	olculur (bu turda ampirik olarak yasandi — meta 1.83 dp, cip 2.57 dp
///	olculdu ve ikisi de w600 idi). Bu yuzden kalinlik **AGACTAN** okunur.
///
/// ⚠️ YAPMA: bu testi silme. `kMetaKalinlik` degisirse burada da degistir —
///    ama once "cipler hala w600 mu" diye BAK, cunku kural ESITLIKTIR.
void main() {
  testWidgets('kart meta satiri suzgec cipleriyle AYNI kalinlikta (w600)',
      (tester) async {
    final o = IsletmeOzet(
      id: 'x',
      ad: 'Test',
      kullaniciAdi: 'test',
      avatarUrl: '',
      avatarMediaId: null,
      kategori: 'yemek',
      il: '',
      ilce: '',
      adres: '',
      dogrulandi: false,
      puan: 4.5,
      puanSayisi: 320,
      teslimatDkMin: 25,
      teslimatDkMax: 35,
      minTutarKurus: 26000,
    )..km = 1.5; // ⚠️ `mesafeMetni` bir GETTER — kaynak alan `km`.

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => vitrinSatiri(c, o, kompakt: false),
        ),
      ),
    ));

    final metinler = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(metinler, isNotEmpty, reason: 'meta satiri HIC cizilmedi');

    // Beklenen parcalarin hepsi var mi (satir sessizce kisalmasin).
    final govdeler = metinler.map((t) => t.data ?? '').toList();
    for (final beklenen in ['4,5', '(320)', '25-35 dk', 'Min. 260 TL', '1,5 km']) {
      expect(govdeler.any((g) => g.contains(beklenen)), isTrue,
          reason: '"$beklenen" meta satirinda YOK — cizim dali kopmus');
    }

    // ⚠️ PUAN DEGERI ("4,5") HARIC hepsi `kMetaKalinlik` olmali.
    //
    // ⚠️⚠️ PUAN BILINCLI OLARAK **DAHA KALIN VE YESIL** (`w700`,
    //	`0xFF16A34A`): satirdaki tek DEGERLENDIRME sinyalidir ve referans
    //	ekranlarda da vurgulanir. Turu 96j'de kullanici *"25-35 dk vb."* dedi
    //	— puanin vurgusunu KALDIRMAK istemedi.
    // ⚠️ YAPMA: puani da w600'e cekip "hepsi ayni olsun" deme; o zaman satir
    //    duzlesir ve puan kaybolur.
    for (final t in metinler) {
      final veri = t.data ?? '';
      if (veri == '4,5') {
        expect(t.style?.fontWeight, FontWeight.w700,
            reason: 'puan vurgusu KAYBOLMUS (${t.style?.fontWeight})');
        continue;
      }
      expect(t.style?.fontWeight, kMetaKalinlik,
          reason: '"$veri" parcasinin kalinligi $kMetaKalinlik degil '
              '(${t.style?.fontWeight})');
    }
  });

  testWidgets('kart meta IKONLARI da kalin cizilir (filtre cipleri gibi)',
      (tester) async {
    final o = IsletmeOzet(
      id: 'x',
      ad: 'Test',
      kullaniciAdi: 'test',
      avatarUrl: '',
      avatarMediaId: null,
      kategori: 'yemek',
      il: '',
      ilce: '',
      adres: '',
      dogrulandi: false,
      puan: 4.5,
      puanSayisi: 320,
      teslimatDkMin: 25,
      teslimatDkMax: 35,
      minTutarKurus: 26000,
    )..km = 1.5;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) => vitrinSatiri(c, o, kompakt: false)),
      ),
    ));

    final ikonlar = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(ikonlar.length, greaterThanOrEqualTo(4),
        reason: 'meta satirinda beklenen ikonlar yok '
            '(yildiz + saat + cuzdan + navigation)');

    // ⚠️⚠️ KULLANICI IKINCI KEZ SOYLEDI: *"25-35 gibi bunlarin IKONLARINI
    //	kalinlastirmamissin, filtre butonlari gibi yapar misin"*. Turu 96j'nin
    //	ilk yariminda yalniz YAZI kalinlastirilmisti; ikonlar ince kalmisti.
    // ⚠️ Lucide bir FONT oldugu icin kalinlik ancak GOLGE ile simule edilir
    //    (`strokeWidth` yok). Golge listesi bosalirsa ikon SESSIZCE incelir —
    //    derleme de analiz de bunu GORMEZ. Bu yuzden muhafiz sart.
    for (final i in ikonlar) {
      expect(i.shadows, isNotNull,
          reason: 'bir meta ikonu golgesiz (INCE) cizilmis');
      expect(i.shadows!.length, 4,
          reason: 'kalinlik dort yonlu golgeyle uretilir '
              '(bulundu: ${i.shadows!.length})');
      expect(i.shadows!.first.offset.distance, closeTo(0.4, 0.001),
          reason: 'yayilma suzgec cipleriyle AYNI olmali (0.4)');
    }
  });

  testWidgets('DOLU kalp beyaz konturunu KORUR', (tester) async {
    // ⚠️⚠️⚠️ Kullanici IKI TUR ust uste bildirdi: *"kalbe tikladigimda beyaz
    //	border kaybolmasin"*. Turu 96g'de golge EKLENMISTI ama ±0.5px ve
    //	dort yonluydu; masif `Icons.favorite` siluetinin yaninda OPTIK OLARAK
    //	GORUNMUYORDU. Turu 96j'de 8 yon x 1.1px'e cikarildi.
    // ⚠️ Bu test SAYIYI ve OFSETI olcer — "golge var mi" demek YETMEZ,
    //    cunku hata tam olarak "golge var ama gorunmuyor" idi.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IsletmeKapakKalbi(dolu: true, onTap: () {}),
      ),
    ));

    final kalp = tester.widget<Icon>(find.byType(Icon));
    expect(kalp.color, const Color(0xFFE11D48), reason: 'dolu kalp pembe olmali');
    expect(kalp.shadows, isNotNull, reason: 'beyaz kontur YOK');
    expect(kalp.shadows!.length, 8,
        reason: 'kontur 8 yonlu olmali (dort yonlu koselerde KESILIR)');
    for (final g in kalp.shadows!) {
      expect(g.color, Colors.white);
      expect(g.offset.distance, greaterThanOrEqualTo(1.0),
          reason: 'kontur cok ince — masif kalbin yaninda GORUNMEZ '
              '(${g.offset.distance})');
    }
  });

  test('kMetaKalinlik suzgec cipleriyle AYNI degerde', () {
    // ⚠️ Cip kalinligi kaynaktan OKUNUR (kopya sabit YAZILMAZ — drift eder).
    final kaynak = _yorumsuz(
        File('lib/features/isletme/isletme_listesi.dart').readAsStringSync());
    // Cip govdesi: fontSize: 13 ... fontWeight: FontWeight.wNNN
    final m = RegExp(r'fontSize:\s*13,\s*color:\s*_notrYazi,\s*'
            r'fontWeight:\s*FontWeight\.(w\d00)')
        .firstMatch(kaynak);
    expect(m, isNotNull,
        reason: 'suzgec cipinin metin stili BULUNAMADI — cip govdesi '
            'degistiyse bu muhafizi da guncelle');
    expect('FontWeight.${m!.group(1)}', kMetaKalinlik.toString(),
        reason: 'meta satiri ile suzgec cipleri AYRISMIS (kullanici emri: '
            '"filtre vb. gibi olsun")');
  });
}

String _yorumsuz(String kaynak) => kaynak
    .split('\n')
    .map((l) {
      final t = l.trimLeft();
      return (t.startsWith('//') || t.startsWith('///')) ? '' : l;
    })
    .join('\n');
