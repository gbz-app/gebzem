import 'package:flutter/material.dart';

/// ⚠️⚠️ TURU 77 — HIKAYE METIN KATMANI (kullanici emri: "storyde AA gibi, renk
/// gibi, yazi tipi gibi ne varsa olacak").
///
/// Bu dosya EDITOR ile IZLEYICI arasindaki ORTAK SOZLESMEDIR. Ikisi de buradan
/// cizer — bu yuzden editorde gordugun sey izleyicide de BIREBIR aynidir.
/// ⚠️ YAPMA: cizimi editorde ve izleyicide AYRI AYRI yazma; iki kopya DRIFT eder
///    (CLAUDE.md turu 72b/H dersi) ve kullanici "yazdigim yerde durmuyor" der.
///
/// ⚠️ KONUM ORANDIR (0..1), PIKSEL DEGIL: hikaye farkli ekran boyutlarinda
///    cizilir. Piksel saklansaydi metin kucuk telefonda ekran disina taşardi.
/// ⚠️ BOYUT mantiksal puntodur ve `olcek()` ile ekrana uyarlanir — referans
///    genislik 390 (iPhone 14). Boylece 360dp'de de 430dp'de de metin AYNI
///    ORANDA gorunur.
class StoryKatman {
  StoryKatman({
    required this.metin,
    this.x = 0.5,
    this.y = 0.45,
    this.boyut = 28,
    this.renk = '#FFFFFF',
    this.font = 'sade',
    this.hiza = 'orta',
    this.kutu = 'yok',
    this.aci = 0,
  });

  String metin;

  /// 0..1 — metin kutusunun MERKEZI.
  double x;
  double y;

  /// Mantiksal punto (8..96). Sunucu da bu araliga kirpiyor.
  double boyut;

  /// #RRGGBB
  String renk;

  /// sade | kalin | ince | serif | daktilo | el
  String font;

  /// sol | orta | sag
  String hiza;

  /// yok | dolu | seffaf  (okunurluk kutusu)
  String kutu;

  /// Radyan.
  double aci;

  Map<String, dynamic> json() => {
    'metin': metin,
    'x': x,
    'y': y,
    'boyut': boyut,
    'renk': renk,
    'font': font,
    'hiza': hiza,
    'kutu': kutu,
    'aci': aci,
  };

  static StoryKatman fromJson(Map<String, dynamic> m) => StoryKatman(
    metin: (m['metin'] ?? '').toString(),
    x: (m['x'] as num?)?.toDouble() ?? 0.5,
    y: (m['y'] as num?)?.toDouble() ?? 0.45,
    boyut: (m['boyut'] as num?)?.toDouble() ?? 28,
    renk: (m['renk'] ?? '#FFFFFF').toString(),
    font: (m['font'] ?? 'sade').toString(),
    hiza: (m['hiza'] ?? 'orta').toString(),
    kutu: (m['kutu'] ?? 'yok').toString(),
    aci: (m['aci'] as num?)?.toDouble() ?? 0,
  );

  StoryKatman kopya() => StoryKatman.fromJson(json());
}

/// ⚠️⚠️ YAZI TIPLERI — **EK PAKET YOK** (`google_fonts` EKLENMEDI).
///
/// Sebep: bu projede her yeni bagimlilik iOS/Android derleme riski (CLAUDE.md:
/// sentry 8.x, firebase eski surumleri, pbxproj/BOM tuzaklari). Ustelik
/// `google_fonts` fontlari CALISMA ANINDA INDIRIR — hikaye editoru ag beklemek
/// zorunda kalirdi.
///
/// Bunun yerine SISTEM font ailelerinin + agirlik/egim/harf araligi
/// birlesimlerinden ALTI belirgin "yazi tipi hissi" uretiliyor. Kullanici
/// bunlari farkli yazi tipleri olarak gorur ve ARADAKI FARK GERCEKTEN BELIRGINDIR.
///
/// ⚠️ `fontFamily` degerleri: iOS'ta '.SF Pro Text' / Android'de 'Roboto' gibi
///    adlari ELLE VERMEK kirilgan. `null` birakip yalniz agirlik/egim/aralik
///    degistirmek HER IKI platformda da CALISIR; 'serif' ve 'monospace' ise
///    Flutter'in GARANTILI genel aile adlaridir.
const storyFontlari = <String, String>{
  'sade': 'Sade',
  'kalin': 'Kalın',
  'ince': 'İnce',
  'serif': 'Klasik',
  'daktilo': 'Daktilo',
  'el': 'El yazısı',
};

TextStyle storyMetinStili(StoryKatman k, double olcek) {
  final renk = storyRenk(k.renk);
  final boyut = k.boyut * olcek;
  switch (k.font) {
    case 'kalin':
      return TextStyle(
        fontSize: boyut,
        color: renk,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        height: 1.1,
      );
    case 'ince':
      return TextStyle(
        fontSize: boyut,
        color: renk,
        fontWeight: FontWeight.w200,
        letterSpacing: 2.5,
        height: 1.2,
      );
    case 'serif':
      return TextStyle(
        fontFamily: 'serif',
        fontSize: boyut,
        color: renk,
        fontWeight: FontWeight.w600,
        height: 1.15,
      );
    case 'daktilo':
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: boyut,
        color: renk,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.2,
      );
    case 'el':
      // ⚠️ Gercek bir el yazisi fontu YOK (paket eklemiyoruz). Egik + ince +
      //    genis aralikli serif, "el yazisi hissi" veren en yakin birlesim.
      return TextStyle(
        fontFamily: 'serif',
        fontSize: boyut,
        color: renk,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.2,
        height: 1.2,
      );
    default:
      return TextStyle(
        fontSize: boyut,
        color: renk,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );
  }
}

Color storyRenk(String hex) {
  final s = hex.replaceAll('#', '');
  if (s.length != 6) return Colors.white;
  final v = int.tryParse(s, radix: 16);
  return v == null ? Colors.white : Color(0xFF000000 | v);
}

TextAlign storyHiza(String h) => switch (h) {
  'sol' => TextAlign.left,
  'sag' => TextAlign.right,
  _ => TextAlign.center,
};

/// Metin paleti — hem editor hem izleyici ayni listeyi kullanir.
const storyRenkleri = <String>[
  '#FFFFFF',
  '#000000',
  '#FF3B5C',
  '#FFB03A',
  '#FFE84A',
  '#2BB673',
  '#3AA9FF',
  '#8B3FFF',
  '#FF7AC6',
  '#7A5C3E',
];

/// ⚠️ ZEMIN GRADYANLARI **ANAHTARLA** saklanir (bkz. migration 027): boylece
///    palet ileride degistirilebilir ve ESKI hikayeler de yeni paletle dogru
///    cizilir. Ham renk saklansaydi palet degisince eskiler paletin disinda kalirdi.
const storyArkaPlanlari = <String, List<Color>>{
  'mor': [Color(0xFF8B3FFF), Color(0xFF4A1E9E)],
  'gun_batimi': [Color(0xFFFF7A45), Color(0xFFFF3B5C)],
  'okyanus': [Color(0xFF3AA9FF), Color(0xFF12547A)],
  'orman': [Color(0xFF2BB673), Color(0xFF0E5A3A)],
  'gece': [Color(0xFF2B2B3A), Color(0xFF0B0B12)],
  'seftali': [Color(0xFFFFB6A3), Color(0xFFFF7AC6)],
  'kor': [Color(0xFFFFE84A), Color(0xFFFF7A45)],
  'gumus': [Color(0xFFDDDDE6), Color(0xFF8A8A99)],
};

const storyArkaPlanAdlari = <String, String>{
  'mor': 'Mor',
  'gun_batimi': 'Gün batımı',
  'okyanus': 'Okyanus',
  'orman': 'Orman',
  'gece': 'Gece',
  'seftali': 'Şeftali',
  'kor': 'Kor',
  'gumus': 'Gümüş',
};

/// ⚠️⚠️⚠️ HIKAYE TUVALI **SABIT 9:16**'DIR — EN KRITIK SOZLESME MADDESI.
///
/// **NEDEN (turu 77b denetim bulgusu):** onceki surumde hem editor hem izleyici
/// katmanlari **EKRANIN TAMAMINA** gore konumluyordu. Ikisi ayni ekranda ayni
/// sonucu verdigi icin tek cihazda test edilse SORUN GORULMEZDI — ama medya
/// `BoxFit.contain` ile ciziliyor ve fotografin kapladigi dikey oran EKRAN
/// EN-BOYUNA gore degisiyor. Somut: 390x844 telefonda (oran 0.462) 4:3 bir
/// fotografin ust kenari y=0.327'de; ayni hikaye 360x640'ta (oran 0.5625)
/// y=0.144'te baslar. Yani `y=0.35`e konan yazi ILK cihazda fotografin
/// tepesinden %2 asagida, IKINCISINDE %21 asagida cizilir — **fotografa gore
/// ~%19 kayma**. Yazi fotograftaki bir seyi isaret ediyorsa artik baska yeri
/// gosterir; ucta letterbox bandina duser.
///
/// COZUM: medya DA katmanlar DA **ayni 9:16 dikdortgenine** cizilir. Boylece
/// `x`,`y` oranlarinin cihazdan bagimsiz TEK anlami olur.
/// ⚠️ YAPMA: tuvali `MediaQuery.size` / ekran dikdortgeni yapma.
/// ⚠️ YAPMA: iki tarafta farkli `BoxFit` kullanma.
const storyEnBoy = 9 / 16;

/// Verilen alana `contain` mantigiyla oturan 9:16 tuvalin olculeri.
Size storyTuvalOlcusu(Size alan) {
  final h = alan.width / storyEnBoy;
  if (h <= alan.height) return Size(alan.width, h);
  return Size(alan.height * storyEnBoy, alan.height);
}

/// Hikaye tuvali — icerigi 9:16 dikdortgene oturtur ve olculeri geri verir.
/// **EDITOR ve IZLEYICI IKISI DE BUNU KULLANIR.**
class StoryTuvali extends StatelessWidget {
  const StoryTuvali({super.key, required this.yap});

  /// [tuval] — 9:16 dikdortgenin olculeri. Katman konumlari BU olculere goredir.
  final Widget Function(BuildContext context, Size tuval) yap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, box) {
      final t = storyTuvalOlcusu(Size(box.maxWidth, box.maxHeight));
      return Center(
        child: SizedBox(width: t.width, height: t.height, child: yap(c, t)),
      );
    },
  );
}

/// ⚠️⚠️ KATMAN GOVDESI — **TEK KAYNAK**. Editor ve izleyici BUNU cagirir.
///
/// **NEDEN (turu 77b denetim bulgusu):** onceki surumde iki taraf yalnizca
/// `storyMetinStili`yi paylasiyordu; SARMALAYICI DUZEN ayri ayri yazilmisti
/// (izleyicide `Padding(horizontal: 16*olcek)`, editorde `Container(padding: 4)`
/// + `ConstrainedBox(maxWidth: W - 40)` — **olceklenmemis sabit 40**). Sonuc:
///   · yatay kayma: 390dp'de kenarlarda ~11px,
///   · daha gorunuru: kutu acikken metin tavani editorde 350, izleyicide 338 ->
///     editorde TEK SATIRA sigan cumle izleyicide IKI SATIRA sariyordu.
/// Kullanici "yazdigim gibi durmuyor" der. Iki kopya DRIFT ETTI (CLAUDE.md
/// turu 72b/H dersinin tekrari).
/// ⚠️ YAPMA: editorde ayri bir govde yazma. Secim cercevesi LAYOUT'U
///    DEGISTIRMEYEN bir katman olmali (`foregroundDecoration`), dolgu DEGIL.
Widget storyKatmanGovdesi(StoryKatman k, Size tuval) {
  final olcek = tuval.width / 390.0;
  final stil = storyMetinStili(k, olcek);
  final renk = storyRenk(k.renk);
  // ⚠️ Kutu rengi metnin TERSI: beyaz yazida koyu kutu, koyu yazida acik kutu.
  //    Sabit siyah kutu, siyah metinle birlesince metni GORUNMEZ yapardi.
  final acikMi = renk.computeLuminance() > 0.5;
  final kutuRengi = k.kutu == 'yok'
      ? null
      : (k.kutu == 'dolu'
            ? (acikMi ? const Color(0xEE000000) : const Color(0xEEFFFFFF))
            : (acikMi ? const Color(0x66000000) : const Color(0x66FFFFFF)));

  Widget metin = Text(
    k.metin,
    textAlign: storyHiza(k.hiza),
    style: k.kutu == 'yok'
        // ⚠️ Kutusuz metinde GOLGE ZORUNLU: acik bir fotograf uzerinde beyaz
        //    yazi golgesiz OKUNMAZ.
        ? stil.copyWith(
            shadows: const [Shadow(blurRadius: 10, color: Color(0xCC000000))],
          )
        : stil,
  );
  if (kutuRengi != null) {
    metin = Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * olcek,
        vertical: 5 * olcek,
      ),
      decoration: BoxDecoration(
        color: kutuRengi,
        borderRadius: BorderRadius.circular(8 * olcek),
      ),
      child: metin,
    );
  }
  // ⚠️ Tavan TUVALE ORANLIDIR (sabit piksel DEGIL) — sabit deger tam da yukarida
  //    anlatilan sarma farkini uretiyordu.
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: tuval.width * 0.86),
    child: metin,
  );
}

/// Katmani tuvalde KONUMLANDIRIR. [cocuk] genelde [storyKatmanGovdesi] ciktisi.
///
/// ⚠️⚠️ **`Align` DEGIL `Positioned` + `FractionalTranslation` (turu 77b bulgusu).**
/// `Align` cocugu `(alan - cocuk) * x` noktasina koyar, yani cocugun GENISLIGI
/// arttikca hareket alani DARALIR. Metin sarip tuval genisligine yaklasinca
/// `(W - w)` sifira gider ve **YATAY SURUKLEME SESSIZCE OLURDU** — kullanici
/// parmagini surukler, yazi kimildamaz. `FractionalTranslation(-0.5,-0.5)`
/// cocugu KENDI boyutunun yarisi kadar geri kaydirir; boylece `left = x*W`
/// GERCEKTEN merkezdir ve metin ne kadar genis olursa olsun surukleme calisir.
/// (Modeldeki *"x,y = kutunun MERKEZI"* serhi de ancak boyle DOGRU olur.)
/// ⚠️ YAPMA: `Align`e geri donme.
///
/// ⚠️ `Transform.rotate` bir BOYAMA donusumudur, yerlesimi degistirmez ->
///    `FractionalTranslation` donmemis olcuyu kullanir, merkez (x,y)'de KALIR.
Widget storyKatmanYerlestir({
  required StoryKatman k,
  required Size tuval,
  required Widget cocuk,
}) => Positioned(
  left: k.x * tuval.width,
  top: k.y * tuval.height,
  child: FractionalTranslation(
    translation: const Offset(-0.5, -0.5),
    child: Transform.rotate(angle: k.aci, child: cocuk),
  ),
);

/// TEK bir metin katmanini cizer (IZLEYICI yolu — dokunusa kapali).
Widget storyKatmanCiz(StoryKatman k, Size tuval) => storyKatmanYerlestir(
  k: k,
  tuval: tuval,
  cocuk: IgnorePointer(child: storyKatmanGovdesi(k, tuval)),
);

/// Metin hikayesinin zemini (medyasiz hikaye).
Widget storyZemin(String anahtar) {
  final renkler = storyArkaPlanlari[anahtar] ?? storyArkaPlanlari['mor']!;
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: renkler,
      ),
    ),
  );
}
