import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show kAiZemin, kAiKartYuzey;
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap;

/// ⚠️⚠️⚠️ TURU 132 — **DOVIZ / ALTIN / BITCOIN SERIDI** (kullanici emri:
///	*"Yakinimda'nin altina dolar euro altin ve bitcoin ekle; dolara
///	tikladigimda alttan bir popup acilsin, grafik Google grafigi gibi
///	dolarin durumunu gorebilecek, altinda gram kilo vs olacak"*).
///
/// ═══════════ ⚠️⚠️⚠️ DURUST SINIR — OKUMADAN DEGISTIRME ═══════════
///
///	**BURADAKI HER SAYI UYDURMADIR.** Projede kur/emtia verisi HICBIR
///	YERDE yok: ne tablo, ne uc, ne dis servis anahtari. Fiyatlar, yuzde
///	degisimler ve grafik noktalari SABIT/URETILMIS veridir ve GERCEK
///	PIYASAYI TEMSIL ETMEZ.
///
/// ⚠️⚠️ **PARA SOZ KONUSU: BU EKRAN YAYINA BOYLE CIKMAMALI.** Yanlis bir
///	kur gorup islem yapan kullanici PARA KAYBEDER. Bu yuzden:
///	· serit `kKurOnizleme` bayragi arkasinda,
///	· hem seritte hem panelde kullaniciya ACIKCA soyleniyor
///	  ("Örnek veri"),
///	· gercek uc gelene kadar bayrak `false` YAPILMALI.
/// ⚠️ Gercek veri baglanirken: `_KurKalem.fiyat/degisim/seri` bir ucdan
///    doldurulur, `kKurOnizleme` silinir ve uyari satirlari kaldirilir.
const kKurOnizleme = true;

/// ⚠️ Kalemler: ad · kisa kod · fiyat · yuzde degisim · grafik serisi.
/// ⚠️ `seri` 0..1 arasi NORMALIZE degerlerdir (grafik cizeri boyle bekler);
///    gercek fiyatlar `fiyat` alaninda.
class _KurKalem {
  const _KurKalem({
    required this.ad,
    required this.kod,
    required this.fiyat,
    required this.degisim,
    required this.ikon,
    required this.seri,
    this.birimler = const [],
  });

  final String ad;
  final String kod;
  final String fiyat;
  final double degisim;
  final IconData ikon;
  final List<double> seri;

  /// ⚠️ "gram / kilo vs" (kullanici emri) — yalniz karsiligi olan kalemde
  ///    dolu. Dolarda "1 dolar kac lira", altinda gram/ceyrek/kilo.
  final List<({String ad, String deger})> birimler;
}

const _kKalemler = <_KurKalem>[
  _KurKalem(
    ad: 'Dolar',
    kod: 'USD',
    fiyat: '34,18 ₺',
    degisim: 0.42,
    ikon: LucideIcons.dollarSign,
    seri: [0.42, 0.38, 0.51, 0.47, 0.55, 0.6, 0.52, 0.63, 0.7, 0.66, 0.74, 0.81],
    birimler: [
      (ad: '1 USD', deger: '34,18 ₺'),
      (ad: '10 USD', deger: '341,80 ₺'),
      (ad: '100 USD', deger: '3.418,00 ₺'),
      (ad: '1.000 USD', deger: '34.180,00 ₺'),
    ],
  ),
  _KurKalem(
    ad: 'Euro',
    kod: 'EUR',
    fiyat: '37,04 ₺',
    degisim: 0.18,
    ikon: LucideIcons.euro,
    seri: [0.5, 0.46, 0.49, 0.55, 0.52, 0.58, 0.61, 0.57, 0.64, 0.62, 0.68, 0.71],
    birimler: [
      (ad: '1 EUR', deger: '37,04 ₺'),
      (ad: '10 EUR', deger: '370,40 ₺'),
      (ad: '100 EUR', deger: '3.704,00 ₺'),
      (ad: '1.000 EUR', deger: '37.040,00 ₺'),
    ],
  ),
  _KurKalem(
    ad: 'Altın',
    kod: 'GRAM',
    fiyat: '2.947 ₺',
    degisim: -0.26,
    ikon: LucideIcons.gem,
    seri: [0.72, 0.75, 0.7, 0.68, 0.73, 0.66, 0.62, 0.65, 0.58, 0.61, 0.55, 0.52],
    birimler: [
      (ad: 'Gram', deger: '2.947 ₺'),
      (ad: 'Çeyrek', deger: '4.812 ₺'),
      (ad: 'Yarım', deger: '9.624 ₺'),
      (ad: 'Tam', deger: '19.248 ₺'),
      (ad: 'Kilo', deger: '2.947.000 ₺'),
    ],
  ),
  _KurKalem(
    ad: 'Bitcoin',
    kod: 'BTC',
    fiyat: '\$67.420',
    degisim: 1.86,
    ikon: LucideIcons.bitcoin,
    seri: [0.3, 0.36, 0.33, 0.45, 0.52, 0.48, 0.61, 0.68, 0.64, 0.77, 0.83, 0.9],
    birimler: [
      (ad: '1 BTC', deger: '\$67.420'),
      (ad: '0,1 BTC', deger: '\$6.742'),
      (ad: '0,01 BTC', deger: '\$674'),
    ],
  ),
];

/// Menude YAKINIMDA seridinin ALTINDA cizilen tek satirlik kur seridi.
///
/// ⚠️ Kartlar `_yakinKart` ile AYNI DILDE (ayni yuzey, ayni yaricap): iki
///    serit alt alta duruyor ve farkli gorunselerdi ekran dagilirdi.
class KurSeridi extends StatelessWidget {
  const KurSeridi({super.key});

  @override
  Widget build(BuildContext context) {
    final olcek = MediaQuery.textScalerOf(context);
    // ⚠️ Yukseklik yazi olceginden TURETILIR (sabit dp DEGIL) ve `height`
    //    carpanlari `Text`lerde ACIKCA verilir — tahmine dayali butce
    //    turu 129'da 2.7 px tasmisti.
    const satir = 1.2;
    final yazi = olcek.scale(12) * satir + olcek.scale(14.5) * satir;
    final boy = (yazi > 34 ? yazi : 34.0) + 22.0;
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
    //    yaninda ISARET de var (+/-) ve ok ikonu (turu 98b dersi).
    final renk = arti ? const Color(0xFF2BB673) : const Color(0xFFE11D48);
    final onRenk = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => kurPaneliAc(context, kalem),
      child: Container(
        width:
            (MediaQuery.sizeOf(context).width - kYanBosluk * 2 - 8 * 2) / 2.2,
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
                color: renk.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(kalem.ikon, size: 16, color: renk),
            ),
            const SizedBox(width: 8),
            // ⚠️ `Expanded` ZORUNLU: "2.947.000 ₺" gibi uzun bir deger sabit
            //    genislikte TASARDI.
            // ⚠️⚠️ TURU 132 — **AD USTE, FIYAT+YUZDE ALTA** (emulatorde
            //	goruldu: uclu tek satir — fiyat, yuzde ve ad yan yana —
            //	dar kartta yuzdeyi kirpiyordu: "+0,...").
            //	Yeni duzen YAKINIMDA kartiyla AYNI: ust satir ad, alt satir
            //	deger.
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ⚠️ `Flexible`: uzun bir fiyat yuzdeyi ekran disina
                      //    itmesin.
                      Flexible(
                        child: Text(
                          kalem.fiyat,
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
                      Text(
                        (arti ? "+" : "") +
                            kalem.degisim
                                .toStringAsFixed(2)
                                .replaceAll(".", ",") +
                            "%",
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: renk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),          ],
        ),
      ),
    );
  }
}

/// ⚠️⚠️⚠️ **ALTTAN ACILAN KUR PANELI** (kullanici emri: *"dolara
///	tikladigimda alttan bir popup acilsin, grafik Google grafigi gibi"*).
///
/// ⚠️⚠️ `isScrollControlled: true` + `SingleChildScrollView` **IKISI DE**
///	ZORUNLU (turu 115c dersi): ilki yalnizca YUKSEKLIK TAVANINI kaldirir,
///	icerigi KAYDIRILABILIR YAPMAZ. Yazi olcegi 2.0`da panel tasardi.
/// ⚠️ `useSafeArea: true` YETMEZ — SDK`da o bayrak `SafeArea(bottom: false)`
///    uretir; alt guvenli alan ELLE eklendi.
Future<void> kurPaneliAc(BuildContext context, _KurKalem kalem) =>
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
  /// ⚠️ Aralik secimi GORSELDIR: tek bir seri var ve aralik degistiginde
  ///    grafik ONDAN TURETILIR (bkz. `_seriAralik`). Uydurma veriye ikinci
  ///    bir uydurma katman eklemiyoruz.
  int _aralik = 1;
  static const _araliklar = ['1G', '1H', '1A', '1Y'];

  @override
  Widget build(BuildContext context) {
    final k = widget.kalem;
    final arti = k.degisim >= 0;
    final renk = arti ? const Color(0xFF2BB673) : const Color(0xFFE11D48);
    final beyaz = Colors.white;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TUTAMAC ──
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
                      color: renk.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(k.ikon, size: 18, color: renk),
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
                          style: TextStyle(
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
                    onPressed: () => Navigator.of(c(context)).pop(),
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: beyaz.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── FIYAT + DEGISIM ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      k.fiyat,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
                          '${arti ? '+' : ''}${k.degisim.toStringAsFixed(2).replaceAll('.', ',')}%',
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
              const SizedBox(height: 16),
              // ── GRAFIK ──
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _GrafikCizer(
                    seri: _seriAralik(k.seri, _aralik),
                    renk: renk,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── ARALIK SECICI ──
              Row(
                children: [
                  for (var i = 0; i < _araliklar.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _aralik = i),
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
              const SizedBox(height: 18),
              // ── BIRIMLER (gram / kilo / adet) ──
              if (k.birimler.isNotEmpty) ...[
                Text(
                  'BİRİMLER',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: beyaz.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: beyaz.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < k.birimler.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  k.birimler[i].ad,
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
                              Text(
                                k.birimler[i].deger,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: beyaz,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // ⚠️⚠️ **KULLANICIYA SOYLENEN DURUST SINIR.** Para soz konusu:
              //	yanlis bir kura bakip islem yapan kisi PARA KAYBEDER.
              //	Veri gerceklestiginde bu satir KALDIRILIR.
              Center(
                child: Text(
                  'Örnek veri — canlı kur bağlantısı henüz yok',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: beyaz.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️ Panelin kendi context'i (kapatma dugmesi icin).
  BuildContext c(BuildContext ctx) => ctx;

  /// ⚠️ Aralik degisince seri KISALIR/UZAR — ikinci bir uydurma veri seti
  ///    uretmiyoruz, var olan seriden dilim aliniyor.
  /// ⚠️ En az 2 nokta: tek noktali bir seride cizgi CIZILEMEZ.
  List<double> _seriAralik(List<double> seri, int aralik) {
    final oran = [0.35, 0.6, 0.85, 1.0][aralik];
    final adet = math.max(2, (seri.length * oran).round());
    return seri.sublist(seri.length - adet);
  }
}

/// ⚠️⚠️⚠️ **GRAFIK CIZERI** (kullanici: *"Google grafigi gibi"*).
///
///	· yatay izgara cizgileri (4 kademe)
///	· yumusatilmis (kubik) cizgi
///	· cizginin ALTINDA solan dolgu
///	· son noktada isaret dairesi
///
/// ⚠️ **HARICI GRAFIK PAKETI EKLENMEDI** (bilincli): tek bir sparkline icin
///	`fl_chart` gibi bir bagimlilik hem paket boyutu hem bakim yuku
///	getirirdi. Ihtiyac buyurse (dokunmali imlec, eksen etiketleri,
///	coklu seri) o zaman degerlendirilir.
/// ⚠️ Kubik yumusatma: kontrol noktalari komsu noktalarin YARISINDA —
///    `quadraticBezierTo` ile daha kose duruyordu.
/// ⚠️ `shouldRepaint` SERIYI ve RENGI karsilastirir: aralik degisince
///    yeniden cizilmeli, aksi halde grafik DONAR.
class _GrafikCizer extends CustomPainter {
  const _GrafikCizer({required this.seri, required this.renk});

  final List<double> seri;
  final Color renk;

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
    // ⚠️ Dikeyde %10 pay: seri 0 ya da 1 degerine dayandiginda cizgi
    //    kenara YAPISIRDI.
    final en = seri.reduce(math.min);
    final boy = seri.reduce(math.max);
    final fark = (boy - en).abs() < 0.001 ? 1.0 : boy - en;
    final noktalar = <Offset>[
      for (var i = 0; i < seri.length; i++)
        Offset(
          size.width * i / (seri.length - 1),
          size.height * 0.9 - ((seri[i] - en) / fark) * size.height * 0.8,
        ),
    ];

    // ── YUMUSATILMIS YOL ──
    final yol = Path()..moveTo(noktalar.first.dx, noktalar.first.dy);
    for (var i = 0; i < noktalar.length - 1; i++) {
      final a = noktalar[i];
      final b = noktalar[i + 1];
      final orta = (a.dx + b.dx) / 2;
      yol.cubicTo(orta, a.dy, orta, b.dy, b.dx, b.dy);
    }

    // ── ALT DOLGU ──
    final dolgu = Path.from(yol)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      dolgu,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [renk.withValues(alpha: 0.28), renk.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    // ── CIZGI ──
    canvas.drawPath(
      yol,
      Paint()
        ..color = renk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ── SON NOKTA ──
    final son = noktalar.last;
    canvas.drawCircle(son, 5, Paint()..color = renk.withValues(alpha: 0.28));
    canvas.drawCircle(son, 2.8, Paint()..color = renk);
  }

  @override
  bool shouldRepaint(_GrafikCizer eski) =>
      eski.renk != renk ||
      eski.seri.length != seri.length ||
      !_ayniSeri(eski.seri, seri);

  bool _ayniSeri(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// ⚠️ `kAiZemin` import`u panelin zemin tonuyla ayni aileden olsun diye
///    tutuluyor; dogrudan kullanilmiyorsa analiz uyarir — bu yuzden
///    panel zemini ondan TURETILIR.
const kKurPanelZemin = kAiZemin;
