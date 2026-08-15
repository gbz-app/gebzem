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

  testWidgets('DOLU kalp beyaz konturu PEMBENIN USTUNE cizilir',
      (tester) async {
    // ⚠️⚠️⚠️ Kullanici **UC TUR** ust uste bildirdi: *"kalbe tikladigimda
    //	beyaz border gorunmuyor"*. Ilk iki denemede kontur `shadows` ile
    //	uretiliyordu, yani glifin **DISINA** — kapagin uzerine. Kapak yer
    //	tutucusu ACIK GRI (0xFFE7E7EA ≈ 231) oldugu icin beyaz halka piksel
    //	olarak VARDI ama GORUNMUYORDU.
    //	Cozum: kontur ZEMINE degil **PEMBE KUTLENIN USTUNE** cizilir.
    // ⚠️ Bu test "golge var mi" diye BAKMAZ — hata tam olarak "golge var ama
    //    gorunmuyor" idi. Onun yerine **UST USTE IKI GLIF** oldugunu ve
    //    ustekinin BEYAZ KENAR CIZGISI oldugunu dogrular.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IsletmeKapakKalbi(dolu: true, onTap: () {})),
    ));

    final ikonlar = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(ikonlar.length, 2,
        reason: 'dolu kalp IKI katmandan olusur: pembe dolgu + beyaz kenar '
            '(bulundu: ${ikonlar.length})');
    expect(ikonlar[0].icon, Icons.favorite);
    expect(ikonlar[0].color, const Color(0xFFE11D48),
        reason: 'alt katman pembe dolgu olmali');
    expect(ikonlar[1].icon, Icons.favorite_border,
        reason: 'ust katman KENAR CIZGISI olmali');
    expect(ikonlar[1].color, Colors.white,
        reason: 'kenar cizgisi BEYAZ olmali (kullanici emri)');
    // ⚠️ Ikisi de AYNI olcu: farkli olsalardi cizgi dolgunun sinirina
    //    oturmaz, bir yanda tasar obur yanda iceride kalirdi.
    expect(ikonlar[0].size, ikonlar[1].size);

    // BOS hal: yalniz beyaz kenar cizgisi, dolgu YOK.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IsletmeKapakKalbi(dolu: false, onTap: () {})),
    ));
    final bos = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(bos.length, 1, reason: 'bos kalpte dolgu CIZILMEMELI');
    // ⚠️ IKI HAL AYNI SILUET: farkli glif kullanilsaydi dokununca kalbin
    //    SEKLI ziplardi.
    expect(bos[0].icon, Icons.favorite_border);
    expect(bos[0].color, Colors.white);
  });

  test('gorunum secici kutusu FILTRE BUTONUYLA ayni yukseklikte', () {
    // ⚠️⚠️⚠️ Kullanici emri: *"filtre butonu genislik yuksekliginde olsun,
    //	gorunum alani cok buyuk"*. Onceki halde kutu 48 dp, `Filtre` cipi
    //	40 dp idi — ayni satirda iki cerceve ve biri 8 dp daha yuksek.
    //
    // ⚠️ Bu ARITMETIK bir kuraldir, gozle bakilarak korunamaz:
    //	  kutu = hucre + kSegDolgu*2 + kenarlik*2
    //	Biri degistiginde oteki elle guncellenmezse kutu SESSIZCE ayrisir
    //	(derleme de analiz de gormez).
    // ⚠️ YAPMA: bu testi silme; `kSegHucreBoy`/`kSegDolgu` degistirirken
    //    cip yuksekligini de DOGRULA.
    final kaynak = _yorumsuz(
        File('lib/features/isletme/isletme_listesi.dart').readAsStringSync());

    // ⚠️ Sabitlerin bir kismi DUZ SAYI (`= 32;`), bir kismi IFADE
    //    (`kCipPay = (40 - 32) / 2;`). Ayristirici ikisini de anlamali —
    //    ilk yazimda yalniz duz sayi aranmis ve test SAGLAM KODDA kirmizi
    //    dusmustu.
    double sabit(String ad) {
      final m = RegExp('const double $ad = ([^;]+);').firstMatch(kaynak);
      expect(m, isNotNull, reason: '`$ad` sabiti BULUNAMADI');
      final ifade = m!.group(1)!.trim();
      final duz = double.tryParse(ifade);
      if (duz != null) return duz;
      final e = RegExp(r'^\((\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\)\s*/\s*'
              r'(\d+(?:\.\d+)?)$')
          .firstMatch(ifade);
      expect(e, isNotNull, reason: '`$ad` ifadesi cozulemedi: $ifade');
      return (double.parse(e!.group(1)!) - double.parse(e.group(2)!)) /
          double.parse(e.group(3)!);
    }

    // ⚠️⚠️⚠️ OLCUT **GORUNEN** YUKSEKLIK (32), dokunma alani (40) DEGIL.
    //	Cip: gorsel govde 32 dp + `kCipPay` * 2 = 8 dp GORUNMEYEN dokunma
    //	payi -> dugum kutusu 40 dp.
    //	Ilk yazimda 40 ile karsilastirildi ve kutu goze HALA BUYUK geldi;
    //	ekrandan olculunce cipin murekkebi 31.6 dp cikti. Goz MUREKKEBI
    //	kiyasliyor, dokunma alanini DEGIL.
    // ⚠️ `kCipPay` yine de OKUNUR: degisirse bu testin dayandigi varsayim
    //    (gorsel 32 + pay) bozulmus demektir.
    final cipPay = sabit('kCipPay');
    expect(cipPay, 4.0,
        reason: 'kCipPay degismis — cipin gorsel yuksekligi artik 32 '
            'olmayabilir, ekrandan yeniden olc');
    const cipGorunen = 32.0;

    const kenarlik = 1.0; // Border.all varsayilani
    final kutuBoy = sabit('kSegHucreBoy') + sabit('kSegDolgu') * 2 + kenarlik * 2;

    expect(kutuBoy, cipGorunen,
        reason: 'gorunum kutusu ($kutuBoy dp) ile Filtre cipinin GORUNEN '
            'yuksekligi ($cipGorunen dp) AYNI olmali');

    // ⚠️ Hucre KARE: kullanici *"genislik yuksekliginde olsun"* dedi.
    expect(sabit('kSegHucre'), sabit('kSegHucreBoy'),
        reason: 'segment hucresi KARE olmali');
    // ⚠️ Aktif zemin hucreyi DOLDURUR (ikinci bir ic bosluk zemini
    //    "yuzen" gosterirdi).
    expect(sabit('kSegBoy'), sabit('kSegHucreBoy'));
    // ⚠️ Ikon hucreye SIGMALI, aksi halde kirpilir.
    expect(sabit('kSegIkon'), lessThan(sabit('kSegHucre')));
  });

  test('BOSLUK OLCEGI hiyerarsisi bozulmamis (8 < 12 < 16)', () {
    // ⚠️⚠️⚠️ Kullanici sordu: *"hepsinin arasindaki esitlik ayni olmali mi?"*
    //	CEVAP HAYIR. Hepsi esit olsaydi bir BASLIK, kendi kartlarina tam da
    //	ustundeki bolume oldugu kadar uzak dururdu ve goz neyin neye ait
    //	oldugunu ayirt edemezdi (yakinlik ilkesi).
    //
    // ⚠️ KORUNAN SEY SAYILAR DEGIL **SIRALAMA**: baslik boslugu izgara
    //	araligindan, o da bolum araligindan KUCUK olmali. Bu siralama
    //	bozulursa tasarim sessizce duzlesir.
    // ⚠️ Turu 96k'da olculen GERCEK hata: "Restoranlar" ustundeki suzgec
    //	seridine 16, KENDI listesine 19.8 dp uzaktaydi — yakinlik TERSTI.
    final kaynak = _yorumsuz(
        File('lib/features/isletme/isletme_listesi.dart').readAsStringSync());
    double sabit(String ad) {
      final m = RegExp('const double $ad = ([0-9.]+)').firstMatch(kaynak);
      expect(m, isNotNull, reason: '`$ad` sabiti BULUNAMADI');
      return double.parse(m!.group(1)!);
    }

    final baslik = sabit('kBaslikBosluk');
    final izgara = sabit('kIzgaraAralik');
    final bolum = sabit('kBosluk');

    expect(baslik, lessThan(izgara),
        reason: 'baslik ↔ kartlari boslugu ($baslik) izgara araligindan '
            '($izgara) KUCUK olmali');
    expect(izgara, lessThan(bolum),
        reason: 'izgara araligi ($izgara) bolum araligindan ($bolum) '
            'KUCUK olmali');
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
