import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show kAiKartYuzey;
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap;

/// ⚠️⚠️⚠️ TURU 132/134 — **DOVIZ / ALTIN / BITCOIN SERIDI + GRAFIK PANELI.**
///
/// ═══════════ ⚠️⚠️⚠️ DURUST SINIR — OKUMADAN DEGISTIRME ═══════════
///
///	**BURADAKI HER SAYI UYDURMADIR.** Projede kur/emtia verisi HICBIR
///	YERDE yok: ne tablo, ne uc, ne dis servis anahtari. Fiyatlar, seri
///	noktalari ve birim cevrimleri URETILMIS veridir; GERCEK PIYASAYI
///	TEMSIL ETMEZ.
///
/// ⚠️⚠️ **PARA SOZ KONUSU: `kKurOnizleme = false` YAPILMADAN YAYINA
///	CIKMAMALI.** Yanlis bir kura bakip islem yapan kullanici PARA
///	KAYBEDER.
///	📌 Kullanici (turu 134) ekrandaki "Örnek veri" ibaresini ACIKCA
///	   KALDIRTTI. Karar ONUN; ama bayrak DURUYOR ve yayin oncesi
///	   kapatilacak. ⚠️ Ibareyi geri koymadan bayragi acik birakma.
/// ⚠️ Gercek veri baglanirken: `_KurKalem` alanlari bir ucdan doldurulur
///    ve `kKurOnizleme` silinir.
const kKurOnizleme = true;

// ══════════════════════ VERI MODELI ══════════════════════

/// ⚠️⚠️ TURU 134 — **SERI ARTIK SAYISAL** (kullanici emri: *"sahte de olsa
///	degerler degissin, degisken degerler gorunsun"*).
///
///	Onceden seri 0..1 arasi NORMALIZE degerlerdi ve tooltip HER noktada
///	AYNI fiyati (kartin fiyatini) yaziyordu — imlec kaysa da sayi
///	degismiyordu. Artik her nokta GERCEK bir fiyat tasiyor; grafik de,
///	tooltip de, baslikttaki buyuk sayi da ONDAN okuyor.
class _KurKalem {
  const _KurKalem({
    required this.ad,
    required this.kod,
    required this.simge,
    required this.ikon,
    required this.seri,
    required this.birimler,
  });

  final String ad;
  final String kod;

  /// Fiyatin para birimi simgesi ('₺' / r'$').
  final String simge;
  final IconData ikon;

  /// ⚠️ GERCEK fiyat serisi (uydurma ama SAYISAL). Son eleman GUNCEL fiyat.
  final List<double> seri;

  /// ⚠️⚠️ TURU 134 — **CEVRIM BIRIMLERI** (kullanici emri: *"altinda gram
  ///	ceyrek scroll olsun secsin, 1 gram altin altinda 6500 turk lirasi,
  ///	12 bin turk lirasi 2 gram altin diye"*).
  ///
  ///	`carpan` = 1 birimin KAC TANE temel birim ettigi. Ornek: ceyrek
  ///	altin 1,75 gram -> carpan 1.75; 100 USD -> carpan 100.
  /// ⚠️ Cevrim TEK KAYNAKTAN turetilir (`guncel * carpan * adet`): iki ayri
  ///    tablo tutulsaydi biri degisince oteki geride kalirdi.
  final List<({String ad, double carpan})> birimler;

  double get guncel => seri.last;

  /// ⚠️ Degisim SERIDEN hesaplanir, ayri bir alan DEGIL: elle yazilan bir
  ///    yuzde seriyle celisebilirdi.
  double get degisim {
    if (seri.length < 2) return 0;
    final ilk = seri.first;
    if (ilk == 0) return 0;
    return (seri.last - ilk) / ilk * 100;
  }
}

/// ⚠️ Seriler 24 nokta: 1G/1H/1A/1Y dilimleri buradan KESILIR, ikinci bir
///    uydurma veri seti uretilmez.
const _kKalemler = <_KurKalem>[
  _KurKalem(
    ad: 'Dolar',
    kod: 'USD',
    simge: '₺',
    ikon: LucideIcons.dollarSign,
    seri: [
      33.42, 33.51, 33.38, 33.60, 33.72, 33.55, 33.81, 33.94,
      33.76, 34.02, 33.88, 34.10, 34.21, 34.05, 34.30, 34.12,
      33.98, 34.24, 34.41, 34.19, 34.36, 34.08, 34.25, 34.18,
    ],
    birimler: [
      (ad: '1 USD', carpan: 1),
      (ad: '10 USD', carpan: 10),
      (ad: '50 USD', carpan: 50),
      (ad: '100 USD', carpan: 100),
      (ad: '500 USD', carpan: 500),
      (ad: '1.000 USD', carpan: 1000),
    ],
  ),
  _KurKalem(
    ad: 'Euro',
    kod: 'EUR',
    simge: '₺',
    ikon: LucideIcons.euro,
    seri: [
      36.10, 36.32, 36.18, 36.45, 36.28, 36.61, 36.44, 36.72,
      36.55, 36.88, 36.70, 37.01, 36.84, 37.15, 36.96, 37.22,
      37.08, 37.31, 37.12, 36.94, 37.20, 37.35, 37.16, 37.04,
    ],
    birimler: [
      (ad: '1 EUR', carpan: 1),
      (ad: '10 EUR', carpan: 10),
      (ad: '50 EUR', carpan: 50),
      (ad: '100 EUR', carpan: 100),
      (ad: '500 EUR', carpan: 500),
      (ad: '1.000 EUR', carpan: 1000),
    ],
  ),
  _KurKalem(
    ad: 'Altın',
    kod: 'GRAM',
    simge: '₺',
    ikon: LucideIcons.gem,
    seri: [
      2880, 2905, 2892, 2934, 2918, 2961, 2947, 2988,
      2970, 3012, 2995, 3034, 3018, 3001, 2978, 2996,
      2964, 2982, 2951, 2969, 2938, 2957, 2929, 2947,
    ],
    // ⚠️ Carpanlar GERCEK altin standardindan: ceyrek 1,75 g · yarim 3,5 g
    //    · tam 7 g · cumhuriyet 7,216 g · kilo 1000 g. Yalniz FIYAT uydurma.
    birimler: [
      (ad: '1 Gram', carpan: 1),
      (ad: 'Çeyrek', carpan: 1.75),
      (ad: 'Yarım', carpan: 3.5),
      (ad: 'Tam', carpan: 7),
      (ad: 'Cumhuriyet', carpan: 7.216),
      (ad: 'Kilo', carpan: 1000),
    ],
  ),
  _KurKalem(
    ad: 'Bitcoin',
    kod: 'BTC',
    simge: r'$',
    ikon: LucideIcons.bitcoin,
    seri: [
      62400, 63120, 62880, 64010, 63540, 64720, 64180, 65330,
      64890, 66040, 65510, 66720, 66180, 67350, 66810, 67940,
      67290, 68120, 67480, 66950, 67610, 68240, 67830, 67420,
    ],
    birimler: [
      (ad: '1 BTC', carpan: 1),
      (ad: '0,5 BTC', carpan: 0.5),
      (ad: '0,1 BTC', carpan: 0.1),
      (ad: '0,01 BTC', carpan: 0.01),
    ],
  ),
];

// ══════════════════════ BICIMLEME ══════════════════════

/// ⚠️⚠️ Turkce sayi bicimi: binlik NOKTA, ondalik VIRGUL. `intl` paketi
///	EKLENMEDI — tek bir bicimleyici icin yeni bagimlilik orantisiz.
/// ⚠️ Ondalik basamak DEGERE gore: 10.000 TL`lik altinda kurus anlamsiz,
///    34,18 TL`lik dolarda ZORUNLU.
String _sayi(double v) {
  final basamak = v >= 1000 ? 0 : 2;
  final s = v.toStringAsFixed(basamak);
  final parca = s.split('.');
  final tam = parca[0];
  final tampon = StringBuffer();
  for (var i = 0; i < tam.length; i++) {
    if (i > 0 && (tam.length - i) % 3 == 0) tampon.write('.');
    tampon.write(tam[i]);
  }
  return parca.length > 1 ? '$tampon,${parca[1]}' : tampon.toString();
}

String _fiyat(double v, String simge) =>
    simge == r'$' ? '$simge${_sayi(v)}' : '${_sayi(v)} $simge';

String _yuzde(double v) =>
    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2).replaceAll('.', ',')}%';

// ══════════════════════ SERIT ══════════════════════

/// ⚠️⚠️ TURU 134 — **IKON KUTUSU KART YUZEYINDEN BIR TIK KOYU** (kullanici
///	emri: *"ikonlarin arka plan rengi kart renginden 1 tik kapali
///	olsun"*).
///
/// ⚠️ Siyah uzerine opaklik: kart yuzeyi zaten yari saydam mor: uzerine
///    yine mor koymak onu ACARDI, koyulastirmazdi.
/// ⚠️ TEK KAYNAK: YAKINIMDA kartlari da bunu kullanir.
Color kIkonKutusu(BuildContext c) => Colors.black.withValues(alpha: 0.22);

/// ⚠️ Lucide bir FONT`tur (glif), SVG DEGIL — `strokeWidth` YOKTUR.
///    Kalinlik ayni renkte ±0.4 px kaydirilmis DORT GOLGE ile simule edilir
///    (turu 93 teknigi). ⚠️ `Icon`a `strokeWidth` yazarsan DERLENMEZ.
class KalinIkon extends StatelessWidget {
  const KalinIkon({
    super.key,
    required this.ikon,
    required this.boy,
    required this.renk,
  });

  final IconData ikon;
  final double boy;
  final Color renk;

  @override
  Widget build(BuildContext context) => Icon(
    ikon,
    size: boy,
    color: renk,
    shadows: [
      Shadow(color: renk, offset: const Offset(0.4, 0)),
      Shadow(color: renk, offset: const Offset(-0.4, 0)),
      Shadow(color: renk, offset: const Offset(0, 0.4)),
      Shadow(color: renk, offset: const Offset(0, -0.4)),
    ],
  );
}

/// Menude YAKINIMDA seridinin ALTINDA cizilen tek satirlik kur seridi.
///
/// ⚠️ Kartlar YAKINIMDA kartlariyla AYNI DILDE (ayni yuzey, ayni yaricap,
///    ayni ikon kutusu): iki serit alt alta duruyor ve farkli gorunselerdi
///    ekran dagilirdi.
class KurSeridi extends StatelessWidget {
  const KurSeridi({super.key});

  @override
  Widget build(BuildContext context) {
    final olcek = MediaQuery.textScalerOf(context);
    // ⚠️ Yukseklik yazi olceginden TURETILIR ve `height` carpanlari
    //    `Text`lerde ACIKCA verilir — tahmine dayali butce turu 129`da
    //    2.7 px tasmisti.
    const satir = 1.2;
    final yazi = olcek.scale(12) * satir + olcek.scale(14.5) * satir;
    // ⚠️ TURU 134 — ad ile deger arasi bosluk artti (kullanici emri): +4 dp.
    final boy = (yazi > 34 ? yazi : 34.0) + 26.0;
    return SizedBox(
      height: boy,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
        physics: const BouncingScrollPhysics(),
        itemCount: _kKalemler.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _KurKarti(kalem: _kKalemler[i]),
      ),
    );
  }
}

class _KurKarti extends StatelessWidget {
  const _KurKarti({required this.kalem});

  final _KurKalem kalem;

  @override
  Widget build(BuildContext context) {
    final arti = kalem.degisim >= 0;
    // ⚠️ Yesil/kirmizi TEK BASINA renk korlugu olana hicbir sey anlatmaz —
    //    yaninda ISARET (+/-) de var (turu 98b dersi).
    final renk = arti ? const Color(0xFF2BB673) : const Color(0xFFE11D48);
    final onRenk = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _kurPaneliAc(context, kalem),
      child: Container(
        // ⚠️⚠️ Genislik hem EKRANDAN hem YAZI OLCEGINDEN turetilir: yalniz
        //	ekrana bakan eski hal 360 dp`de VARSAYILAN olcekte bile fiyati
        //	kirpiyordu (denetim font metriginden olctu).
        // ⚠️ TURU 134 — kullanici "kart genisligini biraz azalt" dedi:
        //    1.9 -> 2.05 (bolen buyudukce kart DARALIR).
        width:
            (MediaQuery.sizeOf(context).width - kYanBosluk * 2 - 8 * 2) /
            (MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1.4 : 2.05),
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
        decoration: BoxDecoration(
          color: kAiKartYuzey(context),
          borderRadius: BorderRadius.circular(kYaricap(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kIkonKutusu(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: KalinIkon(ikon: kalem.ikon, boy: 16, renk: renk),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kalem.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: onRenk.withValues(alpha: 0.6),
                    ),
                  ),
                  // ⚠️ TURU 134 — ad ile deger arasi bosluk (kullanici emri).
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _fiyat(kalem.guncel, kalem.simge),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // ⚠️ `Flexible` ZORUNLU: esnek olmayan bir yuzde metni,
                      //    olcek 2.0`da fiyati SIFIR GENISLIGE dusuruyordu.
                      Flexible(
                        child: Text(
                          _yuzde(kalem.degisim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: renk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════ PANEL ══════════════════════

/// ⚠️⚠️ `isScrollControlled: true` + `SingleChildScrollView` **IKISI DE**
///	ZORUNLU (turu 115c dersi): ilki yalnizca YUKSEKLIK TAVANINI kaldirir,
///	icerigi KAYDIRILABILIR YAPMAZ.
/// ⚠️ `useSafeArea: true` YETMEZ — SDK`da o bayrak `SafeArea(bottom: false)`
///    uretir; alt guvenli alan ELLE eklendi.
Future<void> _kurPaneliAc(BuildContext context, _KurKalem kalem) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15121F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (c) => _KurPaneli(kalem: kalem),
    );

class _KurPaneli extends StatefulWidget {
  const _KurPaneli({required this.kalem});

  final _KurKalem kalem;

  @override
  State<_KurPaneli> createState() => _KurPaneliState();
}

class _KurPaneliState extends State<_KurPaneli> {
  int _aralik = 1;
  static const _araliklar = ['1G', '1H', '1A', '1Y'];

  /// ⚠️⚠️⚠️ TURU 134 — **IMLEC DOKUNUNCA ORADA KALIR** (kullanici emri:
  ///	*"Google`da tikladiginda orada kaliyor gosteriyor, bunda tiklama
  ///	yok"*).
  ///
  ///	Onceki surumde parmak kalkinca imlec SILINIYORDU; kullanici degeri
  ///	okumaya firsat bulamiyordu. Artik secim KALIR ve yalnizca baska bir
  ///	noktaya dokununca ya da aralik degisince degisir.
  int? _secili;

  /// ⚠️⚠️ TURU 134 — **IKI PARMAKLA ARALIK SECIMI** (kullanici emri: *"iki
  ///	parmaklar sol sagda yapinca o araligi gosteriyor, arkadaki renk
  ///	sadece secili alanin arkasindaki rengi oluyor"*).
  ///
  /// ⚠️ `null` = aralik secimi YOK -> dolgu TUM grafikte.
  ({int bas, int son})? _bant;

  /// ⚠️⚠️ Ham pointer takibi ZORUNLU: `GestureDetector`in `onScaleUpdate`i
  ///	iki parmagin AYRI x`lerini VERMEZ (yalniz odak noktasi ve olcek).
  ///	Aralik icin iki ucun de konumu gerekiyor.
  final _parmaklar = <int, double>{};

  /// ⚠️ Titresim YALNIZ NOKTA/BANT DEGISINCE: her `move` olayinda titretmek
  ///    saniyede onlarca titresim demekti.
  /// ⚠️ `selectionClick` secilir, `mediumImpact` DEGIL: bu bir SECIM
  ///    hareketi, onay/uyari degil.
  void _titret() => HapticFeedback.selectionClick();

  List<double> get _seri {
    final tam = widget.kalem.seri;
    final oran = [0.25, 0.5, 0.75, 1.0][_aralik];
    final adet = math.max(2, (tam.length * oran).round());
    return tam.sublist(tam.length - adet);
  }

  /// ⚠️ Gosterilen deger: imlec varsa O NOKTA, yoksa GUNCEL fiyat.
  double get _gosterilen {
    final s = _seri;
    final i = _secili;
    if (i == null) return widget.kalem.guncel;
    return s[i.clamp(0, s.length - 1)];
  }

  /// ⚠️ Degisim de secili noktaya gore: kullanici gecmise bakiyorsa yuzde de
  ///    O ANA ait olmali, yoksa sayi ile yuzde CELISIR.
  double get _gosterilenDegisim {
    final s = _seri;
    if (s.length < 2 || s.first == 0) return 0;
    return (_gosterilen - s.first) / s.first * 100;
  }

  int _dxToIndis(double dx, double genislik, int adet) {
    if (genislik <= 0 || adet < 2) return 0;
    final oran = (dx / genislik).clamp(0.0, 1.0);
    return (oran * (adet - 1)).round();
  }

  void _tekParmak(double dx, double genislik) {
    final i = _dxToIndis(dx, genislik, _seri.length);
    if (i == _secili && _bant == null) return;
    _titret();
    setState(() {
      _secili = i;
      _bant = null;
    });
  }

  void _ikiParmak(double genislik) {
    if (_parmaklar.length < 2) return;
    final xler = _parmaklar.values.toList()..sort();
    final adet = _seri.length;
    var a = _dxToIndis(xler.first, genislik, adet);
    var b = _dxToIndis(xler.last, genislik, adet);
    if (a > b) {
      final t = a;
      a = b;
      b = t;
    }
    // ⚠️⚠️ En az IKI nokta: tek noktali bir bant "aralik" degildir.
    //	⚠️ Genisletme YONU onemli: iki parmak da SON noktadaysa `b = a + 1`
    //	   tavana takilir ve `b == a` KALIR -> `yolYap(a, a)` dongusu hic
    //	   donmez, dolgu SIFIR ALANLI cizilir ve kullanici bandi HIC
    //	   goremez. O halde bandi SOLA dogru acariz.
    if (b - a < 1) {
      if (b < adet - 1) {
        b = a + 1;
      } else {
        a = math.max(0, b - 1);
      }
    }
    // ⚠️ Iki noktali seri (adet == 1 olamaz ama) emniyeti: hala esitse bant
    //    kurulmaz — bozuk bir bant cizmektense hic cizmemek DURUST.
    if (b <= a) return;
    if (_bant?.bas == a && _bant?.son == b) return;
    _titret();
    setState(() {
      _bant = (bas: a, son: b);
      // ⚠️ Bant secilince imlec KALDIRILIR: iki isaret ayni anda "hangisi
      //    guncel" karisikligi yaratirdi.
      _secili = null;
    });
  }

  /// ⚠️⚠️ Etiketler ARALIGA gore uretilir. **UYDURMA** (bkz. dosya serhi):
  ///	`DateTime.now()` KULLANILMAZ — uydurma fiyatlara GERCEK bir zaman
  ///	damgasi vermek inandiriciligi haksiz yere artirirdi.
  String _etiket(int i, int adet) {
    final geri = adet - 1 - i;
    switch (_aralik) {
      case 0:
        final saat = (18 - geri) % 24;
        return '${saat.toString().padLeft(2, '0')}:00';
      case 1:
        const gunler = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
        return gunler[gunler.length - 1 - geri % gunler.length];
      case 2:
        return '${(28 - geri).clamp(1, 31)} Ağu';
      default:
        const aylar = [
          'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
          'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
        ];
        return aylar[aylar.length - 1 - geri % aylar.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kalem;
    final seri = _seri;
    final degisim = _gosterilenDegisim;
    final arti = degisim >= 0;
    final renk = arti ? const Color(0xFF2BB673) : const Color(0xFFE11D48);
    const beyaz = Colors.white;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: beyaz.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── BASLIK ──
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: beyaz.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: KalinIkon(ikon: k.ikon, boy: 18, renk: renk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          k.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: beyaz,
                          ),
                        ),
                        Text(
                          k.kod,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: beyaz.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: beyaz.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── FIYAT (IMLECE GORE DEGISIR) ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _fiyat(_gosterilen, k.simge),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: beyaz,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          arti
                              ? LucideIcons.trendingUp
                              : LucideIcons.trendingDown,
                          size: 15,
                          color: renk,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _yuzde(degisim),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: renk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // ── SECILI ZAMAN ──
              // ⚠️ Yukseklik SABIT: imlec gelip gidince baslik blogu ZIPLARDI.
              // ⚠️⚠️ Ama SABIT **dp** DEGIL — yazi olceginden TURETILIR:
              //	12.5 px yazi olcek 2.0`da 30 px olur ve sabit 18 dp`lik
              //	kutu TASARDI (sari-siyah serit). Kutu hep cizilir, icerigi
              //	bos olabilir; boylece ziplama da tasma da imkansiz.
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(12.5) * 1.2 + 3,
                child: (_secili == null && _bant == null)
                    ? null
                    : Text(
                        _bant != null
                            ? '${_etiket(_bant!.bas, seri.length)} — ${_etiket(_bant!.son, seri.length)}'
                            : _etiket(_secili!, seri.length),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: beyaz.withValues(alpha: 0.55),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              // ── GRAFIK ──
              LayoutBuilder(
                builder: (context, kisit) {
                  final g = kisit.maxWidth;
                  return Listener(
                    // ⚠️⚠️ Ham pointer: iki parmagin AYRI x`leri gerekiyor ve
                    //	`GestureDetector` bunu VERMEZ.
                    // ⚠️ `onPointerCancel` DE dinlenir: sistem jesti araya
                    //    girerse parmak defterde ASILI kalirdi.
                    onPointerDown: (e) {
                      _parmaklar[e.pointer] = e.localPosition.dx;
                      if (_parmaklar.length >= 2) {
                        _ikiParmak(g);
                      } else {
                        _tekParmak(e.localPosition.dx, g);
                      }
                    },
                    onPointerMove: (e) {
                      _parmaklar[e.pointer] = e.localPosition.dx;
                      if (_parmaklar.length >= 2) {
                        _ikiParmak(g);
                      } else {
                        _tekParmak(e.localPosition.dx, g);
                      }
                    },
                    onPointerUp: (e) => _parmaklar.remove(e.pointer),
                    onPointerCancel: (e) => _parmaklar.remove(e.pointer),
                    // ⚠️⚠️⚠️ **PARMAK KALKINCA SECIM SILINMEZ** (kullanici
                    //	emri): Google Finance deseni — deger ekranda KALIR.
                    child: SizedBox(
                      height: 150,
                      width: double.infinity,
                      // ⚠️⚠️ TURU 134 — **ARALIK DEGISINCE HAFIF GECIS**
                      //	(kullanici emri: *"gun ay degisirken chart
                      //	animasyon ekle, cok hafif tatli"*).
                      // ⚠️ `key` ZORUNLU: `TweenAnimationBuilder` yalnizca
                      //    `tween` DEGISINCE animasyon baslatir; aralik
                      //    degistiginde widget`i YENIDEN kurup 0`dan
                      //    baslatmak gerekiyor.
                      // ⚠️ 260 ms + `easeOutCubic`: "tatli" ama bekletmeyen
                      //    sure.
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_aralik),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, _) => CustomPaint(
                          painter: _GrafikCizer(
                            seri: seri,
                            renk: renk,
                            ilerleme: t,
                            secili: _secili,
                            bant: _bant,
                            etiket: _secili == null
                                ? null
                                : _etiket(_secili!, seri.length),
                            deger: _secili == null
                                ? null
                                : _fiyat(_gosterilen, k.simge),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // ── ARALIK SECICI ──
              Row(
                children: [
                  for (var i = 0; i < _araliklar.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_aralik == i) return;
                          _titret();
                          // ⚠️ Aralik degisince imlec/bant SIFIRLANIR: eski
                          //    indis yeni seride BASKA bir gune denk gelir.
                          setState(() {
                            _aralik = i;
                            _secili = null;
                            _bant = null;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _aralik == i
                                ? beyaz.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _araliklar[i],
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: _aralik == i
                                  ? beyaz
                                  : beyaz.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              // ── CEVRIM ──
              _Cevrim(kalem: k),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════ CEVRIM ══════════════════════

/// ⚠️⚠️⚠️ TURU 134 — **BIRIM CEVRIMI** (kullanici emri: *"altinda gram ceyrek
///	scroll olsun secsin; 1 karsida ABD dolari, altta 50 karsida turk
///	lirasi; 1 gram altin altinda 6500 turk lirasi, 12 bin turk lirasi
///	2 gram altin diye"*).
///
///	Ustte yatay kaydirmali birim secici (Gram · Çeyrek · Kilo ...), altta
///	SECILEN birimin katlarinin karsiligi.
///
/// ⚠️ Karsiliklar TEK FORMULDEN turetilir (`guncel * carpan * kat`): elle
///    yazilmis bir tablo, fiyat degistiginde geride kalirdi.
class _Cevrim extends StatefulWidget {
  const _Cevrim({required this.kalem});

  final _KurKalem kalem;

  @override
  State<_Cevrim> createState() => _CevrimState();
}

class _CevrimState extends State<_Cevrim> {
  int _secili = 0;

  /// ⚠️ Katlar: 1 · 2 · 5 · 10 — kullanicinin ornegi ("1 gram / 2 gram")
  ///    bu listenin ilk iki elemani.
  static const _katlar = [1, 2, 5, 10];

  @override
  Widget build(BuildContext context) {
    final k = widget.kalem;
    final birim = k.birimler[_secili.clamp(0, k.birimler.length - 1)];
    const beyaz = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÇEVİR',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: beyaz.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 8),
        // ── BIRIM SECICI (YATAY KAYDIRMA) ──
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: k.birimler.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (_, i) {
              final s = i == _secili;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (i == _secili) return;
                  HapticFeedback.selectionClick();
                  setState(() => _secili = i);
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: s
                        ? beyaz.withValues(alpha: 0.16)
                        : beyaz.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    k.birimler[i].ad,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: s ? beyaz : beyaz.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // ── KARSILIKLAR ──
        Container(
          decoration: BoxDecoration(
            color: beyaz.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final kat in _katlar)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      // ⚠️ Sol taraf: "Çeyrek" / "2 × Çeyrek" — kat 1 ise
                      //    birimin kendi adi ("1 Gram" zaten oyle yaziyor).
                      Expanded(
                        child: Text(
                          kat == 1 ? birim.ad : '$kat × ${birim.ad}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.2,
                            color: beyaz.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ⚠️ `Flexible` ZORUNLU: esnek olmayan bir `Text`,
                      //    "10 × Kilo" gibi buyuk bir karsilikta (29.470.000 ₺)
                      //    ve yazi olcegi 2.0`da satiri TASIRIRDI. Sol taraf
                      //    `Expanded` oldugu icin once BU metin yerini alir.
                      Flexible(
                        child: Text(
                          _fiyat(k.guncel * birim.carpan * kat, k.simge),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: beyaz,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════ GRAFIK ══════════════════════

/// ⚠️⚠️⚠️ **GRAFIK CIZERI** (kullanici: *"Google grafigi gibi"*).
///
///	· yatay izgara · yumusatilmis cizgi · altinda solan dolgu
///	· dokunulan noktada imlec + tooltip (KALICI)
///	· iki parmakla secilen BANT: dolgu YALNIZ o aralikta
///
/// ⚠️ **HARICI GRAFIK PAKETI EKLENMEDI** (bilincli): tek bir sparkline icin
///	`fl_chart` gibi bir bagimlilik paket boyutu ve bakim yuku getirirdi.
/// ⚠️ Kubik yumusatma: kontrol noktalari komsu noktalarin YARISINDA.
/// ⚠️ `shouldRepaint` TUM girdileri karsilastirir; biri unutulursa grafik
///    DONAR (imlec kaydigi halde cizilmez).
class _GrafikCizer extends CustomPainter {
  const _GrafikCizer({
    required this.seri,
    required this.renk,
    required this.ilerleme,
    this.secili,
    this.bant,
    this.etiket,
    this.deger,
  });

  final List<double> seri;
  final Color renk;

  /// 0..1 — aralik degisiminde cizginin acilma animasyonu.
  final double ilerleme;

  final int? secili;
  final ({int bas, int son})? bant;
  final String? etiket;
  final String? deger;

  @override
  void paint(Canvas canvas, Size size) {
    if (seri.length < 2) return;

    // ── IZGARA ──
    final izgara = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), izgara);
    }

    // ── NOKTALAR ──
    // ⚠️ Dikeyde %10 pay: seri uca dayandiginda cizgi kenara YAPISIRDI.
    final en = seri.reduce(math.min);
    final boy = seri.reduce(math.max);
    final fark = (boy - en).abs() < 0.0001 ? 1.0 : boy - en;
    // ⚠️⚠️ ANIMASYON: cizgi dikeyde ORTADAN acilir (`ilerleme` 0 -> 1).
    //	Yatay "cizilme" animasyonu, aralik degisince grafigin BOS baslamasi
    //	demek olurdu — kullanici bir an bos kutu gorurdu.
    final orta = size.height * 0.5;
    final noktalar = <Offset>[
      for (var i = 0; i < seri.length; i++)
        Offset(size.width * i / (seri.length - 1), () {
          final tam =
              size.height * 0.9 - ((seri[i] - en) / fark) * size.height * 0.8;
          return orta + (tam - orta) * ilerleme;
        }()),
    ];

    Path yolYap(int bas, int son) {
      final y = Path()..moveTo(noktalar[bas].dx, noktalar[bas].dy);
      for (var i = bas; i < son; i++) {
        final a = noktalar[i];
        final b = noktalar[i + 1];
        final o = (a.dx + b.dx) / 2;
        y.cubicTo(o, a.dy, o, b.dy, b.dx, b.dy);
      }
      return y;
    }

    final tamYol = yolYap(0, noktalar.length - 1);

    // ── DOLGU ──
    // ⚠️⚠️ Bant secilmisse dolgu YALNIZ o aralikta (kullanici emri: *"arkadaki
    //	renk sadece secili alanin arkasindaki rengi oluyor"*).
    final b = bant;
    final dolguYol = b == null
        ? (Path.from(tamYol)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close())
        : (yolYap(b.bas, b.son)
            ..lineTo(noktalar[b.son].dx, size.height)
            ..lineTo(noktalar[b.bas].dx, size.height)
            ..close());
    canvas.drawPath(
      dolguYol,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            renk.withValues(alpha: b == null ? 0.28 : 0.42),
            renk.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    // ── BANT KENARLARI ──
    if (b != null) {
      final kenar = Paint()
        ..color = renk.withValues(alpha: 0.45)
        ..strokeWidth = 1.5;
      for (final x in [noktalar[b.bas].dx, noktalar[b.son].dx]) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), kenar);
      }
    }

    // ── CIZGI ──
    canvas.drawPath(
      tamYol,
      Paint()
        ..color = b == null ? renk : renk.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // ⚠️ Bant varken o dilim TAM RENKTE ustune cizilir: "secili alan one
    //    cikar" hissi.
    if (b != null) {
      canvas.drawPath(
        yolYap(b.bas, b.son),
        Paint()
          ..color = renk
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // ── SON NOKTA (imlec/bant yokken) ──
    if (secili == null && b == null) {
      final son = noktalar.last;
      canvas.drawCircle(son, 5, Paint()..color = renk.withValues(alpha: 0.28));
      canvas.drawCircle(son, 2.8, Paint()..color = renk);
      return;
    }
    if (secili == null) return;

    // ── IMLEC ──
    final i = secili!.clamp(0, noktalar.length - 1);
    final n = noktalar[i];
    canvas.drawLine(
      Offset(n.dx, 0),
      Offset(n.dx, size.height),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(n, 7, Paint()..color = renk.withValues(alpha: 0.25));
    canvas.drawCircle(n, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(n, 3, Paint()..color = renk);

    // ── TOOLTIP ──
    if (etiket == null) return;
    final yazi = deger == null ? etiket! : '$deger\n$etiket';
    final tp = TextPainter(
      text: TextSpan(
        text: yazi,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w700,
          fontFamily: 'Google Sans',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    const ic = 8.0;
    final kutuG = tp.width + ic * 2;
    final kutuY = tp.height + ic * 2;
    // ⚠️⚠️ Kutu YATAYDA KISITLANIR: imlec kenardayken tooltip grafigin DISINA
    //	tasar ve yarisi kirpilirdi.
    // ⚠️⚠️⚠️ **`clamp` UST SINIRI ALT SINIRDAN KUCUKSE ArgumentError ATAR**
    //	(Dart `num.clamp` kaynagi: `if (lower.compareTo(upper) > 0) throw`).
    //	Kutu grafikten GENISSE `size.width - kutuG` NEGATIF olur ve cizer
    //	PATLAR -> ekranda kirmizi hata kutusu. Bugun tooltip ~70 dp ve
    //	`TextPainter` yazi olcegini UYGULAMAZ, ama bu kapi kaldirilirsa
    //	metin uzadigi gun SESSIZ bir cokme olur.
    final sol = kutuG >= size.width
        ? 0.0
        : (n.dx - kutuG / 2).clamp(0.0, size.width - kutuG);
    final kutu = Rect.fromLTWH(sol, 0, kutuG, kutuY);
    canvas.drawRRect(
      RRect.fromRectAndRadius(kutu, const Radius.circular(8)),
      Paint()..color = const Color(0xF21A1626),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(kutu, const Radius.circular(8)),
      Paint()
        ..color = renk.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, Offset(sol + ic, ic));
  }

  @override
  bool shouldRepaint(_GrafikCizer eski) =>
      eski.renk != renk ||
      eski.secili != secili ||
      eski.bant?.bas != bant?.bas ||
      eski.bant?.son != bant?.son ||
      eski.ilerleme != ilerleme ||
      eski.etiket != etiket ||
      eski.deger != deger ||
      eski.seri.length != seri.length ||
      !_ayniSeri(eski.seri, seri);

  bool _ayniSeri(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
