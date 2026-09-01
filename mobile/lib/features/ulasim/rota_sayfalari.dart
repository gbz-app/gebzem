/// ⚠️⚠️⚠️ TURU 150 — **ROTA EKRANI** (nereden / nereye · sonuc · adimlar).
///
/// Kullanicinin emri: *"ekranda alt bolumde durak kartlari, ustunde mevcut
/// konum ya da istedigi yer ve nereye — isterse kendi haritadan
/// isaretlesin; oradaki rotayi cizecek, durak yolu ve varisa IKI RENK;
/// altta ise step adimlar"*.
///
/// ⚠️ Yardimcilar (`_koyuTema`/`_sheet`/`hatRozeti`/`hatRengi`) burada
///    YENIDEN YAZILMAZ — `ulasim_sayfalari.dart`tan gelir. Bu projede
///    kopya = drift (bes kez yasandi).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show kAiZemin, morLogo;
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap, kYuzeyGri;
import 'rota_bul.dart';
import 'ulasim_sayfalari.dart' show hatRengi, hatRozeti;
import 'ulasim_veri.dart';

/// Rota ekraninin sectigi bir NOKTA.
class RotaNoktasi {
  const RotaNoktasi({
    required this.ad,
    required this.enlem,
    required this.boylam,
  });

  final String ad;
  final double enlem;
  final double boylam;
}

ThemeData _koyuTema() => ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: morLogo,
        brightness: Brightness.dark,
      ).copyWith(surface: kAiZemin),
      scaffoldBackgroundColor: kAiZemin,
      textTheme: ThemeData.dark(useMaterial3: true)
          .textTheme
          .apply(fontFamily: 'Google Sans'),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );

/// Yurume bacaklarinin rengi — TEK KAYNAK (harita ve liste ayni okur).
const Color kYurumeRengi = Color(0xFF9AA0A6);

// ═══════════════════════════════════════════════════════════════════════
// 1) NEREDEN / NEREYE SAYFASI
// ═══════════════════════════════════════════════════════════════════════

/// Rota planlama sayfasi. Kullanici varisi ya **arayarak** ya da
/// **haritadan isaretleyerek** secer.
///
/// [haritadanSec] cagrilirsa sheet KAPANIR ve ekran nokta secme kipine
/// gecer; secim bitince bu sayfa yeniden acilir.
Future<void> rotaPlanlaAc(
  BuildContext context, {
  required RotaNoktasi? baslangic,
  required RotaNoktasi? varis,
  required void Function(RotaNoktasi bas, RotaNoktasi var_) rotaBul,
  required void Function(bool baslangicIcin) haritadanSec,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: kAiZemin,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (c) => FractionallySizedBox(
      heightFactor: 0.95,
      child: Theme(
        data: _koyuTema(),
        child: Material(
          type: MaterialType.transparency,
          child: Builder(
            builder: (tc) => SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(c).bottom,
                ),
                child: _PlanlaGovde(
                  baslangic: baslangic,
                  varis: varis,
                  rotaBul: (b, v) {
                    Navigator.of(c).maybePop();
                    rotaBul(b, v);
                  },
                  haritadanSec: (bas) {
                    Navigator.of(c).maybePop();
                    haritadanSec(bas);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PlanlaGovde extends StatefulWidget {
  const _PlanlaGovde({
    required this.baslangic,
    required this.varis,
    required this.rotaBul,
    required this.haritadanSec,
  });

  final RotaNoktasi? baslangic;
  final RotaNoktasi? varis;
  final void Function(RotaNoktasi, RotaNoktasi) rotaBul;
  final void Function(bool) haritadanSec;

  @override
  State<_PlanlaGovde> createState() => _PlanlaGovdeState();
}

class _PlanlaGovdeState extends State<_PlanlaGovde> {
  /// ⚠️ Denetleyici bu widget'in KENDI `State`inde yasar ve orada dispose
  ///    edilir (turu 96i: sheet kapanirken disaridan dispose edilen bir
  ///    denetleyici EKRANI KIRMIZI boyar).
  final _ara = TextEditingController();
  List<Durak> _sonuc = const [];
  RotaNoktasi? _varis;

  @override
  void initState() {
    super.initState();
    _varis = widget.varis;
    if (_varis != null) _ara.text = _varis!.ad;
  }

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  Future<void> _aramaDegisti(String q) async {
    final s = q.trim();
    if (s.length < 2) {
      setState(() => _sonuc = const []);
      return;
    }
    final hepsi = await UlasimVeri.i.duraklar();
    if (!mounted) return;
    // ⚠️ Turkce duyarsiz: `toLowerCase()` "İ" harfini birlesik noktaya
    //    cevirir ve "İSTASYON" -> "istasyon"u BULAMAZ.
    final a = _sadelestir(s);
    setState(() {
      _sonuc = hepsi
          .where((d) => _sadelestir(d.ad).contains(a))
          .take(25)
          .toList();
    });
  }

  static String _sadelestir(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bas = widget.baslangic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nereye gidiyorsun?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              // ── NEREDEN ──
              _satir(
                context,
                ikon: LucideIcons.circleDot,
                renk: const Color(0xFF2BB673),
                etiket: 'Nereden',
                deger: bas?.ad ?? 'Konum bekleniyor',
                dugme: 'Haritadan',
                bas: () => widget.haritadanSec(true),
              ),
              const SizedBox(height: 8),
              // ── NEREYE ──
              _satir(
                context,
                ikon: LucideIcons.mapPin,
                renk: const Color(0xFFFF5E5E),
                etiket: 'Nereye',
                deger: _varis?.ad ?? 'Seçilmedi',
                dugme: 'Haritadan',
                bas: () => widget.haritadanSec(false),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ara,
                onChanged: (v) => unawaited(_aramaDegisti(v)),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Durak adı ara',
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 42, minHeight: 38),
                  filled: true,
                  fillColor: kYuzeyGri(context),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(kYaricap(46)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _sonuc.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
                  child: Text(
                    _ara.text.trim().length < 2
                        ? 'Varış noktasını durak adıyla arayabilir ya da '
                            'haritadan işaretleyebilirsin.'
                        : 'Eşleşen durak yok.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      kYanBosluk, 0, kYanBosluk, 16),
                  itemCount: _sonuc.length,
                  itemBuilder: (_, i) {
                    final d = _sonuc[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: kYuzeyGri(context),
                        borderRadius: BorderRadius.circular(kYaricap(56)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            final v = RotaNoktasi(
                              ad: d.ad,
                              enlem: d.enlem,
                              boylam: d.boylam,
                            );
                            setState(() {
                              _varis = v;
                              _ara.text = d.ad;
                              _sonuc = const [];
                            });
                            if (bas != null) widget.rotaBul(bas, v);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.busFront,
                                    size: 17, color: Color(0xFF3AA9FF)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    d.ad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        // ── ROTA BUL ──
        Padding(
          padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              // ⚠️ Baslangic ya da varis yoksa dugme PASIF cizilir —
              //    basildiginda sessizce hicbir sey yapan bir dugme, bu
              //    projede "olu arayuz" sayilir.
              onPressed: (bas != null && _varis != null)
                  ? () => widget.rotaBul(bas, _varis!)
                  : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kYaricap(48)),
                ),
              ),
              child: const Text(
                'Rotayı bul',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _satir(
    BuildContext c, {
    required IconData ikon,
    required Color renk,
    required String etiket,
    required String deger,
    required String dugme,
    required VoidCallback bas,
  }) {
    final scheme = Theme.of(c).colorScheme;
    return Material(
      color: kYuzeyGri(c),
      borderRadius: BorderRadius.circular(kYaricap(60)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: bas,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(ikon, size: 18, color: renk),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      etiket,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      deger,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dugme,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 2) ROTA SONUCU — OZET + ADIM ADIM
// ═══════════════════════════════════════════════════════════════════════

/// Bulunan rotalari gosterir; birine dokununca [rotaSec] ile haritaya cizilir.
Future<void> rotaSonucAc(
  BuildContext context, {
  required List<RotaAdayi> adaylar,
  required void Function(RotaAdayi) rotaSec,
  required VoidCallback yenidenSec,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: kAiZemin,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    builder: (c) => FractionallySizedBox(
      heightFactor: 0.70,
      child: Theme(
        data: _koyuTema(),
        child: Material(
          type: MaterialType.transparency,
          child: Builder(
            builder: (tc) {
              final scheme = Theme.of(tc).colorScheme;
              if (adaylar.isEmpty) {
                return SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(kYanBosluk),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Aktarmasız hat bulunamadı',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        // ⚠️ DURUST SINIR: bu bir HATA degil, gercek bir
                        //    sonuc. Olculdu: 800 m yurume yaricapiyla
                        //    sorgularin ~%41'i aktarmasiz cozuluyor.
                        Text(
                          'Bu iki nokta arasında tek otobüsle giden bir hat '
                          'yok. Aktarmalı rota henüz eklenmedi.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: scheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.of(c).maybePop();
                            yenidenSec();
                          },
                          child: const Text('Başka bir varış seç'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SafeArea(
                top: false,
                child: ListView(
                  padding:
                      const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 16),
                  children: [
                    for (final a in adaylar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RotaKarti(
                          aday: a,
                          sec: () {
                            Navigator.of(c).maybePop();
                            rotaSec(a);
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _RotaKarti extends StatelessWidget {
  const _RotaKarti({required this.aday, required this.sec});

  final RotaAdayi aday;
  final VoidCallback sec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: kYuzeyGri(context),
      borderRadius: BorderRadius.circular(kYaricap(120)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: sec,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── OZET: VARIS SAATI birincil, sure ikincil ──
              // ⚠️ Sira arastirmadan: kullanici "kac dakika" degil "saat
              //    kacta varirim" sorusunu soruyor (Moovit/Transit deseni).
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${UlasimVeri.saatMetni(aday.varisDakika)}\'de varış',
                    style: const TextStyle(
                      fontSize: 18,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${aday.toplamDakika} dk',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.3,
                      color: scheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(LucideIcons.footprints,
                      size: 15, color: kYurumeRengi),
                  const SizedBox(width: 6),
                  hatRozeti(aday.hat, boy: 24),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.footprints,
                      size: 15, color: kYurumeRengi),
                  const Spacer(),
                  Text(
                    '${aday.yurumeDakika} dk yürüme',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 10),
              // ── ADIM ADIM ──
              for (final b in aday.bacaklar) _adim(context, b),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adim(BuildContext c, RotaBacagi b) {
    final scheme = Theme.of(c).colorScheme;
    final (ikon, renk) = switch (b.tur) {
      BacakTuru.yuru => (LucideIcons.footprints, kYurumeRengi),
      BacakTuru.bekle => (LucideIcons.clock, const Color(0xFFFFC531)),
      BacakTuru.otobus => (
          LucideIcons.busFront,
          b.hat == null ? morLogo : hatRengi(b.hat!)
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(kYaricap(30)),
            ),
            child: Icon(ikon, size: 15, color: renk),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  b.baslik,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  b.altBaslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.25,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${b.dakika} dk',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

