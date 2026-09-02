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
import 'adres_servisi.dart';
import 'rota_bul.dart';
import 'ulasim_sayfalari.dart' show hatRengi, hatRozeti, mesafeMetni;
import 'ulasim_veri.dart';

/// Rota ekraninin sectigi bir NOKTA.
class RotaNoktasi {
  const RotaNoktasi({
    required this.ad,
    required this.enlem,
    required this.boylam,
    this.altAd = '',
  });

  final String ad;

  /// ⚠️⚠️ TURU 151 - **ADRESIN IKINCI SATIRI** (kullanici emri:
  ///	*"ben sectigim yerin ADRESI DE gorunmeli neredende ve
  ///	nereyede"*). Haritadan isaretlenen nokta artik "Seçilen
  ///	varış" degil, ters geocoding ile cozulmus gercek adresini
  ///	tasir. Cozulemezse BOS kalir ve satir yalnizca [ad] gosterir.
  final String altAd;

  final double enlem;
  final double boylam;

  /// Ekranda gosterilecek TAM etiket (alt ad varsa iki satirin birlesimi).
  String get tam => altAd.isEmpty ? ad : '$ad, $altAd';
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
/// ⚠️⚠️ TURU 155 — **YURUME RENGI LILA** (kullanici emri: *"burada
///	kesitler MOR tam yol icinde, aynisini istiyorum"* — referans
///	Yandex Navigator koyu temasi, ekran goruntusu verildi).
///
/// Onceki deger notr gri (`#9AA0A6`) idi ve koyu lacivert harita zemininde
/// (`#232a44`) yol seritlerinden (`#3e4c77`) ayirt edilemiyordu — kullanici
/// yurume bacagini GOREMIYORDU.
/// ⚠️ Renk hem haritadaki kesik cizgide hem panel ikonlarinda AYNI
///    sabitten gelir; ayri yazilsalardi biri degisince oteki geride kalirdi.
const Color kYurumeRengi = Color(0xFFA9AFF5);

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

  /// ⚠️⚠️⚠️ TURU 151 - sonuclar artik **DURAK + ADRES KARISIK**
  ///	(kullanici emri: *"durak adi arayi nereye gidiyorsundan
  ///	KALDIR"* + *"sokak adi cadde"*). Duraklar silinmedi, AYNI
  ///	kutuya alindi.
  List<AdresSonucu> _sonuc = const [];

  /// ⚠️⚠️ **GECIKTIRME (debounce) ZORUNLU:** adres aramasi cihaz
  ///	geocoder'ina AG ISTEGI atiyor. Her tusa basista istek
  ///	atilsaydi Android `Geocoder` bogulur ve "Service not
  ///	Available" ile SESSIZCE bos donerdi.
  Timer? _gecikme;

  /// Ucustaki aramanin nesli - **BAYAT YANIT KAPISI**.
  /// ⚠️⚠️ Adres cozumu saniyeler surebiliyor; kullanici bu arada
  ///	yazmaya devam ederse ESKI sorgunun yaniti YENISININ
  ///	uzerine yazardi (bu projede ayni sinif turu 85b/93b'de
  ///	yasandi).
  int _nesil = 0;

  /// ⚠️⚠️ **AUTOCOMPLETE OTURUM JETONU.**
  ///	Kullanici yazmaya baslayinca uretilir, **SECIMDEN SONRA
  ///	ATILIR**. Google, autocomplete isteklerini kapatan Place
  ///	Details cagrisini bu jetonla eslestirip TEK OTURUM sayar;
  ///	jeton tasinmazsa **her istek AYRI faturalanir**.
  String? _oturum;

  /// Secilen onerinin koordinati cozulurken true (liste kilitlenir).
  bool _cozuluyor = false;
  bool _araniyor = false;

  RotaNoktasi? _varis;

  @override
  void initState() {
    super.initState();
    _varis = widget.varis;
    if (_varis != null) _ara.text = _varis!.ad;
  }

  @override
  void dispose() {
    // ⚠️ Zamanlayici IPTAL edilmezse sheet kapandiktan sonra
    //    `setState` cagirilir ve OLU bir `State`e dokunulur.
    _gecikme?.cancel();
    _ara.dispose();
    super.dispose();
  }

  void _aramaDegisti(String q) {
    _gecikme?.cancel();
    final s = q.trim();
    if (s.length < 2) {
      setState(() {
        _sonuc = const [];
        _araniyor = false;
      });
      return;
    }
    // ⚠️ 350 ms: Turkce bir cadde adini yazmak ~1-2 sn suruyor;
    //    daha kisa esik her hecede istek uretirdi.
    // ⚠️ Jeton ILK tusla uretilir ve secime kadar AYNI kalir.
    _oturum ??= AdresServisi.yeniOturum();
    setState(() => _araniyor = true);
    _gecikme = Timer(const Duration(milliseconds: 350), () {
      unawaited(_aramayiKos(s));
    });
  }

  Future<void> _aramayiKos(String s) async {
    final nesil = ++_nesil;
    final liste = await AdresServisi.i.ara(
      s,
      yakinEnlem: widget.baslangic?.enlem,
      yakinBoylam: widget.baslangic?.boylam,
      oturum: _oturum,
    );
    // ⚠️ BAYAT YANIT KAPISI: yalniz EN SON sorgu ekrana yazabilir.
    if (!mounted || nesil != _nesil) return;
    setState(() {
      _sonuc = liste;
      _araniyor = false;
    });
  }

  /// ⚠️⚠️⚠️ Bir oneriyi secer — **KOORDINAT BURADA COZULUR.**
  ///
  ///	Autocomplete koordinat DONDURMEZ; sunucudan gelen
  ///	onerilerin `enlem`/`boylam`i **0**'dir ve `yerId` tasirlar.
  ///	Bu metot Place Details ile gercek koordinati alir.
  ///
  /// ⚠️⚠️ **COZULEMEZSE SECIM KABUL EDILMEZ.** Aksi halde varis noktasi
  ///	(0,0) — **Gine Korfezi** — olur ve rota sessizce sacmalar
  ///	(bu projede turu 90b'de aynen yasandi).
  /// ⚠️ Duraklar `yerId` TASIMAZ: koordinatlari kendi verimizde zaten
  ///    var, Google'a gitmeye gerek yok (ve fatura olusmaz).
  Future<void> _sec(AdresSonucu d, RotaNoktasi? bas) async {
    var enlem = d.enlem;
    var boylam = d.boylam;
    final yid = d.yerId;
    if (yid != null && yid.isNotEmpty) {
      setState(() => _cozuluyor = true);
      final nk = await AdresServisi.i.yerCoz(yid, oturum: _oturum);
      if (!mounted) return;
      setState(() => _cozuluyor = false);
      if (nk == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu yerin konumu alınamadı.')),
        );
        return;
      }
      enlem = nk.enlem;
      boylam = nk.boylam;
    }
    // ⚠️ Jeton SECIMDEN SONRA ATILIR (bkz. `_oturum` serhi).
    _oturum = null;
    final v = RotaNoktasi(
      ad: d.ad,
      altAd: d.durak ? '' : d.altAd,
      enlem: enlem,
      boylam: boylam,
    );
    setState(() {
      _varis = v;
      _ara.text = d.ad;
      _sonuc = const [];
    });
    if (bas != null) widget.rotaBul(bas, v);
  }

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
                alt: bas?.altAd ?? '',
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
                alt: _varis?.altAd ?? '',
                dugme: 'Haritadan',
                bas: () => widget.haritadanSec(false),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ara,
                onChanged: _aramaDegisti,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  // ⚠️⚠️ TURU 151 - kullanici emri: *"DURAK ADI ARAYI
                  //	nereye gidiyorsundan KALDIR"*. Kutu artik
                  //	adres/cadde DE ariyor; duraklar ayni listede.
                  hintText: 'Adres, cadde ya da durak ara',
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
          // ⚠️⚠️ UC DAL: **araniyor** dali ZORUNLU. Adres cozumu
          //	saniyeler surebiliyor; ara durum cizilmeseydi kullanici
          //	"eslesme yok" gorup aramanin CALISMADIGINI sanardi.
          child: _araniyor && _sonuc.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: kYanBosluk),
                  child: Row(children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Aranıyor…', style: TextStyle(fontSize: 13.5)),
                  ]),
                )
              : _sonuc.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
                  child: Text(
                    _ara.text.trim().length < 2
                        ? 'Varış noktasını adres, cadde ya da durak adıyla '
                            'arayabilir; istersen haritadan işaretleyebilirsin.'
                        // ⚠️ DURUST SINIR: cihaz geocoder'i bir
                        //    "autocomplete" DEGIL, tam(a yakin) adres
                        //    ister. Kullaniciya bunu SOYLUYORUZ.
                        : 'Sonuç yok. Cadde/mahalle adını daha açık yazmayı '
                            'ya da haritadan işaretlemeyi dene.',
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
                          onTap: _cozuluyor ? null : () => unawaited(_sec(d, bas)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              children: [
                                // ⚠️ Ikon TURU soyler: otobus =
                                //    durak, konum ignesi = adres.
                                Icon(
                                  d.durak
                                      ? LucideIcons.busFront
                                      : LucideIcons.mapPin,
                                  size: 17,
                                  color: d.durak
                                      ? const Color(0xFF3AA9FF)
                                      : const Color(0xFFFF5E5E),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        d.ad,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (d.altAd.isNotEmpty)
                                        Text(
                                          // ⚠️ Mesafe sunucudan gelirse
                                          //    eklenir; Google `origin`
                                          //    olmadan dondurmuyor.
                                          // ⚠️ TURU 155 — bicim
                                          //    `ulasim.mesafeMetni` TEK
                                          //    KAYNAGINDAN; burada ayri bir
                                          //    kopya duruyordu ve ikisi
                                          //    kacinilmaz olarak DRIFT ederdi.
                                          d.mesafeM == null
                                              ? d.altAd
                                              : '${mesafeMetni(d.mesafeM!.toDouble())} · ${d.altAd}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            height: 1.25,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                    ],
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
    String alt = '',
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
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    // TURU 151 - ADRESIN IKINCI SATIRI (kullanici emri:
                    //   "sectigim yerin ADRESI DE gorunmeli"). Bos ise
                    //   satir HIC cizilmez; bos bir satir birakmak
                    //   kutuyu sebepsiz uzatirdi.
                    if (alt.isNotEmpty)
                      Text(
                        alt,
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
                        // ⚠️⚠️⚠️ TURU 157 - **BU METIN TURUN MANSET
                        //	OZELLIGINI INKAR EDIYORDU.**
                        //	Eski hali: *"Aktarmasız hat bulunamadı ...
                        //	Aktarmalı rota HENÜZ EKLENMEDİ."*
                        //	Aktarma AYNI TURDA eklendi ve bu ekran
                        //	ARTIK yalnizca aktarmayla DA cozulemeyen
                        //	vakalarda cizilir - yani metin kullaniciya
                        //	var olan bir ozelligin YOK oldugunu
                        //	soyluyordu.
                        const Text(
                          'Uygun rota bulunamadı',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        // ⚠️ DURUST SINIR: bu bir HATA degil, gercek bir
                        //    sonuc. Aktarmali arama ile kapsama OLCULDU:
                        //    **%96,6** (aktarmasiz motor %39,5 idi).
                        //    Kalan vakalarda ya 800 m icinde durak YOK
                        //    (ciftlerin ~%5,5'i) ya da o saatte sefer YOK.
                        Text(
                          'Bu iki nokta arasında aktarmayla bile uygun bir '
                          'sefer bulunamadı. Farklı bir saat ya da varış '
                          'noktası dene.',
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

