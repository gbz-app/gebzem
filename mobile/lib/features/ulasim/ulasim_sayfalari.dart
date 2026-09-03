/// ⚠️⚠️⚠️ TURU 149 — **TOPLU TASIMA SAYFALARI** (durak listesi · durak
///	detayi · taksi duraklari). Hepsi **GERCEK GTFS verisinden** beslenir
///	(bkz. `ulasim_veri.dart`); tek bir sayi uydurulmadi.
///
/// ⚠️ Bu dosya AYRI: `yakinimda_ekrani.dart` zaten ~4400 satir ve bu
///    projede o dosyada yapilan silme/ekleme islemleri DORT kez komsu
///    uyeleri goturdu. Yeni yuzey buraya yaziliyor, harita ekrani yalnizca
///    CAGIRIYOR.
///
/// ⚠️⚠️ Sheet'ler kardesleriyle AYNI dili kullanir: `kAiZemin` zemin +
///	ZORLA KOYU TEMA + `Builder` + `Material` sarmali (turu 129/136/140
///	dersleri). Biri eksik kalirsa siyah zeminde SILIK GRI yazi cikar.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show kAiZemin, morLogo;
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap, kYuzeyGri;
import 'ulasim_veri.dart';

/// Sheet'lerin ORTAK koyu temasi — panelinkiyle ayni kaynak.
ThemeData _koyuTema() => ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: morLogo,
        brightness: Brightness.dark,
      ).copyWith(surface: kAiZemin),
      scaffoldBackgroundColor: kAiZemin,
      textTheme: ThemeData.dark(useMaterial3: true)
          .textTheme
          .apply(fontFamily: 'Google Sans'),
      // ⚠️ `ThemeData.dark()` uygulamanin "dokunma dairesi YOK" kararini
      //    (turu 7 kullanici emri) SIFIRLAR; acikca geri konur.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );

/// Ortak sheet kabugu (%70, arkadaki harita GORUNUR).
Future<T?> _sheet<T>(
  BuildContext context,
  Widget Function(BuildContext) govde, {
  double boy = 0.70,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      // ⚠️ TURU 142 dersi: arkadaki harita gorunsun (varsayilan perde %54).
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (c) => FractionallySizedBox(
        heightFactor: boy,
        child: Theme(
          data: _koyuTema(),
          child: Material(
            type: MaterialType.transparency,
            // ⚠️⚠️ TURU 165 - Sheet KAYARAK aciliyordu ama ICERIK sert giriyordu
            //    (kullanici: *"hafif bir animasyonla girsin"*). Icerik
            //    artik 220 msde belirip 12 dp yukari suzuluyor.
            // ⚠️ `TweenAnimationBuilder` secildi: sheet kendi
            //    `AnimationController`ini tasiyor, ikinci bir controller
            //    kurmak `TickerProvider` ister ve bu yardimci
            //    STATELESS bir fonksiyon.
            // ⚠️ Deger 0dan baslar ama agac HER ZAMAN kurulur; opaklik
            //    0 iken bile yerlesim yapilir, yani 0-boyut tuzagi YOK
            //    (turu 136/156 dersi).
            child: Builder(
              builder: (tc) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, t, cocuk) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - t)),
                    child: cocuk,
                  ),
                ),
                child: SafeArea(top: false, child: govde(tc)),
              ),
            ),
          ),
        ),
      ),
    );

/// Hattin rengi — GTFS'ten gelir, yoksa notr mor.
///
/// ⚠️ Renk okunabilirlik icin KOYU zeminde kullanilacak; GTFS renkleri
///    kurumsal ve genelde koyu (006633 gibi). Cok koyu gelirse ACILIR ki
///    siyah panelde kaybolmasin — OLCUT parlaklik, tahmin degil.
Color hatRengi(Hat h) {
  final r = h.renk.replaceAll('#', '').trim();
  if (r.length != 6) return morLogo;
  final v = int.tryParse(r, radix: 16);
  if (v == null) return morLogo;
  var c = Color(0xFF000000 | v);
  // ⚠️ `computeLuminance` 0..1; 0.18 altinda siyah panelde ayirt edilemez.
  if (c.computeLuminance() < 0.18) {
    c = Color.lerp(c, Colors.white, 0.45)!;
  }
  return c;
}

/// Hat numarasi rozeti ("563").
Widget hatRozeti(Hat h, {double boy = 26}) {
  final renk = hatRengi(h);
  return Container(
    height: boy,
    constraints: BoxConstraints(minWidth: boy + 10),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: renk,
      borderRadius: BorderRadius.circular(kYaricap(boy)),
    ),
    child: Text(
      h.kisaAd,
      maxLines: 1,
      style: TextStyle(
        fontSize: boy * 0.5,
        height: 1,
        fontWeight: FontWeight.w800,
        // ⚠️ On plan DOLGUDAN turetilir: sabit beyaz yazsaydik acik renkli
        //    hatlarda (sari/turuncu) 1,x:1 ile OKUNMAZDI (turu 140 dersi).
        color: ThemeData.estimateBrightnessForColor(renk) == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),
    ),
  );
}

/// ⚠️⚠️ TURU 155 — **MESAFE BICIMI TEK KAYNAK** (`_` oneki KALDIRILDI).
///
///	Kullanicinin ekran goruntusunde adim kartinda **"15240 m kaldı"**
///	yaziyordu: ham metre, binlik ayraci bile yok. Bu bicimleyici ZATEN
///	vardi ama **private** oldugu icin adim karti onu KULLANAMIYOR,
///	kendi ham `${m.round()} m` ifadesini yaziyordu.
/// ⚠️ 950 m esigi: 950-999 arasi "1,0 km" yazmak yaniltici olurdu.
/// ⚠️ Ondalik ayraci VIRGUL (Turkce).
// ⚠️⚠️ TURU 158b - govde `UlasimVeri`ye TASINDI (mantik katmani).
//	Burasi yalnizca yeniden disa acar: mevcut cagri yerleri (bu dosya,
//	`rota_sayfalari`) DEGISMEDEN calisir ve iki KOPYA olusmaz.
String mesafeMetni(double m) => UlasimVeri.mesafeMetni(m);

// ═══════════════════════════════════════════════════════════════════════
// 1) YAKINDAKI DURAKLAR
// ═══════════════════════════════════════════════════════════════════════

/// Yakindaki duraklarin listesi; birine dokununca [durakSec] cagrilir.
Future<void> durakListesiAc(
  BuildContext context, {
  required double enlem,
  required double boylam,
  required void Function(Durak) durakSec,
}) async {
  final duraklar = await UlasimVeri.i.yakinDuraklar(enlem, boylam, adet: 30);
  if (!context.mounted) return;
  await _sheet<void>(context, (c) {
    final scheme = Theme.of(c).colorScheme;
    if (duraklar.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(kYanBosluk),
        child: Text(
          'Yakınında kayıtlı durak bulunamadı.',
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 16),
      children: [
        const Text(
          'Yakındaki duraklar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${duraklar.length} durak · Kocaeli Büyükşehir verisi',
          style: TextStyle(
            fontSize: 12.5,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        for (final d in duraklar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: kYuzeyGri(c),
              borderRadius: BorderRadius.circular(kYaricap(72)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(c).maybePop();
                  durakSec(d);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3AA9FF).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(kYaricap(42)),
                        ),
                        child: const Icon(LucideIcons.busFront,
                            size: 20, color: Color(0xFF3AA9FF)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              d.ad,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mesafeMetni(UlasimVeri.kabaMetre(
                                  enlem, boylam, d.enlem, d.boylam)),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  });
}

// ═══════════════════════════════════════════════════════════════════════
// 2) DURAK DETAYI — GECEN HATLAR + GERCEK KALKIS SAATLERI
// ═══════════════════════════════════════════════════════════════════════

/// Duraktan gecen hatlar ve o duraktaki **gercek** kalkis saatleri.
///
/// [guzergahSec] bir hatta dokununca cagrilir (haritaya cizilsin diye) ve
/// sheet KAPANIR — yoksa kullanici cizgiyi goremezdi (turu 141 dersi).
Future<void> durakDetayAc(
  BuildContext context,
  Durak durak, {
  required void Function(Hat hat, int yon) guzergahSec,
  double? mesafeM,
  String? adres,
}) async {
  final servis = UlasimVeri.bugunServis();
  final hatlar = await UlasimVeri.i.duraginHatlari(durak.id, servis);
  if (!context.mounted) return;

  // ⚠️ SIRALAMA: en yakin kalkis ONCE. Kullanicinin ilk bakisi "hangisi
  //    daha once geliyor" sorusuna cevap versin.
  final an = UlasimVeri.suAnDakika();
  hatlar.sort((a, b) {
    final ax = a.sonrakiler(an, adet: 1);
    final bx = b.sonrakiler(an, adet: 1);
    final av = ax.isEmpty ? 1 << 30 : ax.first;
    final bv = bx.isEmpty ? 1 << 30 : bx.first;
    return av.compareTo(bv);
  });

  await _sheet<void>(context, (c) {
    final scheme = Theme.of(c).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 16),
      children: [
        Text(
          durak.ad,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        // ⚠️⚠️ TURU 151 - **DURAK HAKKINDA BILGI** (kullanici emri:
        //	*"hatlar gecen otobusler DURAK HAKKINDA BILGI
        //	gorunmuyor"*): hat sayisi + gun turu + MESAFE + ADRES.
        // ⚠️ Mesafe/adres OPSIYONEL: konum yoksa ya da ters
        //    geocoding cozemezse o parca satira GIRMEZ - "bilinmiyor"
        //    yazmak bos bir iddia olurdu.
        Text(
          [
            hatlar.isEmpty
                ? 'Bugün sefer görünmüyor'
                : '${hatlar.length} hat',
            '${_servisAdi(servis)} saatleri',
            if (mesafeM != null)
              mesafeM < 950
                  ? '${mesafeM.round()} m'
                  : '${(mesafeM / 1000).toStringAsFixed(1).replaceAll('.', ',')} km',
            if (adres != null && adres.isNotEmpty) adres,
          ].join(' · '),
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        for (final h in hatlar)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HatSatiri(
              dh: h,
              an: an,
              servis: servis,
              sec: () {
                Navigator.of(c).maybePop();
                guzergahSec(h.hat, h.yon);
              },
            ),
          ),
      ],
    );
  });
}

String _servisAdi(int s) => switch (s) {
      2 => 'cumartesi',
      3 => 'pazar',
      _ => 'hafta içi',
    };

class _HatSatiri extends StatelessWidget {
  const _HatSatiri({
    required this.dh,
    required this.an,
    required this.sec,
    this.servis = 1,
  });

  final DurakHatti dh;
  final int an;
  final VoidCallback sec;

  /// GTFS servis kimligi (1 hafta ici · 2 cumartesi · 3 pazar).
  final int servis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sonraki = dh.sonrakiler(an, adet: 3);
    final ilk = sonraki.isEmpty ? null : sonraki.first;
    final kalan = ilk == null ? null : ilk - an;
    final baslik = dh.hat.yonBaslik[dh.yon] ?? dh.hat.uzunAd;
    // ⚠️ Yalniz SIRASI GELMEMIS ilk kalkislar; gecmis saatleri
    //    listelemek "otobus var" izlenimi verirdi.
    final tumIlk = dh.hat.ilkKalkis[dh.yon]?[servis] ?? const <int>[];
    final ilkKalkis = tumIlk.where((x) => x >= an).take(3).toList();

    return Material(
      color: kYuzeyGri(context),
      borderRadius: BorderRadius.circular(kYaricap(80)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: sec,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  hatRozeti(dh.hat, boy: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      baslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (kalan != null)
                    Text(
                      // ⚠️ 60 dk'dan uzun bekleme "125 dk" diye yazilirsa
                      //    okunmaz; saat olarak gosterilir.
                      kalan <= 60
                          ? '$kalan dk'
                          : UlasimVeri.saatMetni(ilk!),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kalan <= 10
                            ? const Color(0xFF2BB673)
                            : scheme.onSurface,
                      ),
                    ),
                ],
              ),
              // ⚠️⚠️ **RESMI UYGULAMAYLA BIREBIR KARSILASTIRMA SATIRI.**
              //
              //	Kullanici: *"birebir ayni olsun, karsilastirma
              //	yaptiklarinda problem yasamayiz"*. Resmi uygulamanin
              //	hat sayfasi ACIKCA *"araclarin ILK DURAKTAN kalkis
              //	saatleri"* diyor; ustteki buyuk sayi ise BU DURAGA
              //	VARIS. Ikisi FARKLI BUYUKLUK oldugu icin kullanici
              //	yan yana koyunca "saatler uymuyor" saniyordu.
              // ⚠️ Ust satir DEGISMEDI: kullanicinin gercekten ihtiyac
              //    duydugu sey otobusun ONA ne zaman gelecegidir.
              //    Bu satir yalnizca KARSILASTIRMA icin eklendi.
              // ⚠️ Etiket resmi uygulamanin kendi ifadesiyle AYNI
              //    ("ilk duraktan kalkis") — baska bir sozcuk secmek
              //    kullanicida yine "ayni sey mi?" sorusu birakirdi.
              if (ilkKalkis.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'İlk duraktan kalkış: '
                  '${ilkKalkis.map(UlasimVeri.saatMetni).join(' · ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              if (sonraki.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Sonraki: ${sonraki.skip(1).map(UlasimVeri.saatMetni).join(' · ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 3) TAKSI DURAKLARI
// ═══════════════════════════════════════════════════════════════════════

/// En yakin taksi duraklari (Kocaeli Buyuksehir acik verisi).
///
/// ⚠️⚠️ **TELEFON NUMARASI VERIDE YOK** (dogrulandi: alanlar ad · ilce ·
///	mahalle · adres). Bu yuzden kartta "Ara" dugmesi CIZILMEZ — olmayan
///	bir numara icin dugme koymak olu arayuz olurdu.
Future<void> taksiListesiAc(
  BuildContext context, {
  required double enlem,
  required double boylam,
  required void Function(TaksiDuragi) haritadaGoster,
}) async {
  final liste = await UlasimVeri.i.yakinTaksiler(enlem, boylam, adet: 15);
  if (!context.mounted) return;
  await _sheet<void>(context, (c) {
    final scheme = Theme.of(c).colorScheme;
    if (liste.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(kYanBosluk),
        child: Text(
          'Yakınında kayıtlı taksi durağı bulunamadı.',
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 16),
      children: [
        const Text(
          'Taksi durakları',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Kocaeli Büyükşehir verisi · telefon numarası veride yok',
          style: TextStyle(
            fontSize: 12.5,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        for (final x in liste)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: kYuzeyGri(c),
              borderRadius: BorderRadius.circular(kYaricap(80)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(c).maybePop();
                  haritadaGoster(x.t);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC531).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(kYaricap(42)),
                        ),
                        child: const Icon(LucideIcons.carTaxiFront,
                            size: 20, color: Color(0xFFFFC531)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              x.t.ad,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${x.t.ilce} · ${mesafeMetni(x.m)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: scheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.map, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  });
}
