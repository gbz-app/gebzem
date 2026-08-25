import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show morLogo, kAiZemin, kAiKartYuzey;
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricap;

/// ⚠️⚠️⚠️ TURU 131 — **MAC DETAY EKRANI** (kullanici emri: *"o slider'a
///	tikladigimda guzel bir arayuz yap, detay sayfasini"*).
///
/// ═══════════ ⚠️⚠️⚠️ DURUST SINIR — OKUMADAN DEGISTIRME ═══════════
///
///	**BU EKRANDAKI HER SAYI UYDURMADIR.** Projede mac verisi HICBIR
///	YERDE yok: ne tablo, ne uc, ne dis kaynak (ne `backend/` altinda
///	bir mac paketi, ne bir spor API anahtari). Skor, dakika, goller,
///	istatistikler ve diziliş SABIT METINDIR ve GERCEK BIR MACI TEMSIL
///	ETMEZ.
///
///	Ekran YALNIZCA `kSkorOnizleme` bayragi acikken ulasilabilir
///	(`hizmet_menusu.dart`); bayrak kapaninca slider gercek vitrin
///	slaytlarina doner ve buraya giden YOL KALMAZ.
///
/// ⚠️⚠️ **YAYIN ONCESI YAPILACAKLAR:**
///	· `kSkorOnizleme = false`  -> ekran ulasilamaz olur, ya da
///	· gercek bir mac ucu yazilir ve `_MacVerisi` ORADAN doldurulur.
///	Ikisi de yapilmadan bu ekran YAYINA CIKMAMALI.
///
/// ⚠️ En altta kullaniciya da soylenen bir ibare var ("Örnek içerik").
///    Kaldirilmasi ancak veri GERCEK olunca dogru olur.
///
/// ═══════════ TASARIM ═══════════
///
///	· ust: kapak gorseli + skor bloğu (geri/paylas ustte yuzer)
///	· GOLLER   — top ikonu + oyuncu + dakika
///	· ISTATISTIK — iki yonlu oranli cubuklar
///	· DIZILIS  — iki takim, yan yana
///
/// ⚠️ Zemin menu/GebzemAI ile AYNI (`kAiZemin`) ve ekran `ThemeData.dark`
///    ile sarili: aksi halde koyu zeminde SIYAH yazi cizilirdi (turu 129'da
///    menude birebir bu yasandi).
class SkorDetayEkrani extends StatelessWidget {
  const SkorDetayEkrani({super.key});

  /// ⚠️ Tek kaynak: kart ile detay AYNI gorseli kullanir.
  static const kapak = 'assets/vitrin/re1.jpg';

  @override
  Widget build(BuildContext context) {
    // ⚠️ `ThemeData.dark` SIFIRDAN kurulur ve uygulamanin `fontFamily`
    //    ayarini TASIMAZ — acikca veriliyor (turu 127 dersi).
    final tema = ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: morLogo,
            brightness: Brightness.dark,
          ).copyWith(surface: kAiZemin),
      scaffoldBackgroundColor: kAiZemin,
      textTheme: ThemeData.dark(
        useMaterial3: true,
      ).textTheme.apply(fontFamily: 'Google Sans'),
      primaryTextTheme: ThemeData.dark(
        useMaterial3: true,
      ).primaryTextTheme.apply(fontFamily: 'Google Sans'),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kAiZemin,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: tema,
        child: Scaffold(
          // ⚠️ `CustomScrollView`: kapak kaydirilinca kuculsun diye
          //    `SliverAppBar` kullaniliyor; `Column` ile bu yapilamazdi.
          body: CustomScrollView(
            slivers: [
              _kapakBolumu(context),
              SliverToBoxAdapter(child: _govde(context)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════ KAPAK ══════════════════════

  /// ⚠️⚠️ `SliverAppBar` + `expandedHeight`: kaydirinca kapak kuculur ve
  ///	ustte skor **kucuk basligiyla** sabitlenir — kullanici asagida
  ///	istatistige bakarken skoru KAYBETMEZ.
  /// ⚠️ `pinned: true` ZORUNLU: olmasaydi baslik tamamen kaybolurdu.
  Widget _kapakBolumu(BuildContext context) => SliverAppBar(
    pinned: true,
    expandedHeight: 300,
    backgroundColor: kAiZemin,
    // ⚠️ Kapak koyu; ikonlar BEYAZ olmali (tema zaten dark ama acikca
    //    yaziliyor: kapak gorseli her tonda olabilir).
    foregroundColor: Colors.white,
    leading: IconButton(
      icon: const Icon(LucideIcons.arrowLeft),
      onPressed: () => Navigator.of(context).maybePop(),
    ),
    // ⚠️ Kucuk baslik YALNIZ daraldiginda gorunur (`FlexibleSpaceBar`
    //    `title`i genisken de cizerdi ve buyuk skorla UST USTE binerdi).
    title: const Text(
      'Türkiye 1 - 0 Almanya',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    flexibleSpace: FlexibleSpaceBar(
      background: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(kapak, fit: BoxFit.cover),
          // ⚠️⚠️ IKI KATMAN: genel karartma + alttan gecis. Fotografin
          //	ortasi parlak ve kalabalik; tek katman metni okunur
          //	yapmiyordu (turu 130'da menu kartinda olculdu).
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x66000000)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x33000000),
                  Color(0xF2050308),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // ── SKOR ──
          Align(
            alignment: const Alignment(0, 0.42),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _canliRozeti(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(child: _takim('Türkiye', sag: false)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '1 - 0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            shadows: [
                              Shadow(
                                blurRadius: 12,
                                color: Color(0xE6000000),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: _takim('Almanya', sag: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// ⚠️ `Expanded` + `textAlign`: uzun takim adi ("Almanya" degil ama
  ///    ileride "Kuzey Makedonya" olabilir) skoru YERINDEN OYNATMASIN.
  Widget _takim(String ad, {required bool sag}) => Text(
    ad,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: sag ? TextAlign.left : TextAlign.right,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 17,
      height: 1.2,
      fontWeight: FontWeight.w700,
      shadows: [Shadow(blurRadius: 10, color: Color(0xCC000000))],
    ),
  );

  /// ⚠️ Renk TEK BASINA renk korlugu olana hicbir sey anlatmaz — yaninda
  ///    YAZI da var (turu 98b dersi). Dakika da rozetin icinde.
  Widget _canliRozeti() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFE11D48),
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 6,
          height: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: 6),
        Text(
          "CANLI  67'",
          style: TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  // ══════════════════════ GOVDE ══════════════════════

  Widget _govde(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(kYanBosluk, 18, kYanBosluk, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _baslik('GOLLER'),
        const SizedBox(height: 10),
        _kutu(
          context,
          child: const Column(
            children: [
              _GolSatiri(oyuncu: 'Arda Turan', dakika: "20'", evSahibi: true),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _baslik('MAÇ İSTATİSTİKLERİ'),
        const SizedBox(height: 10),
        _kutu(
          context,
          child: const Column(
            children: [
              _Istatistik(ad: 'Topla oynama', sol: 58, sag: 42, yuzde: true),
              _Istatistik(ad: 'Şut', sol: 12, sag: 7),
              _Istatistik(ad: 'İsabetli şut', sol: 5, sag: 2),
              _Istatistik(ad: 'Korner', sol: 6, sag: 3),
              _Istatistik(ad: 'Faul', sol: 9, sag: 14),
              _Istatistik(ad: 'Sarı kart', sol: 1, sag: 3, sonuncu: true),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _baslik('DİZİLİŞ'),
        const SizedBox(height: 10),
        _kutu(
          context,
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Dizilis(
                  takim: 'Türkiye',
                  sistem: '4-2-3-1',
                  oyuncular: [
                    'Uğurcan Çakır',
                    'Zeki Çelik',
                    'Merih Demiral',
                    'Kaan Ayhan',
                    'Ferdi Kadıoğlu',
                    'Hakan Çalhanoğlu',
                    'Arda Turan',
                  ],
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: _Dizilis(
                  takim: 'Almanya',
                  sistem: '4-3-3',
                  oyuncular: [
                    'Manuel Neuer',
                    'Joshua Kimmich',
                    'Antonio Rüdiger',
                    'Jonathan Tah',
                    'David Raum',
                    'Toni Kroos',
                    'Jamal Musiala',
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ⚠️⚠️ **KULLANICIYA SOYLENEN DURUST SINIR.** Bu ekrandaki veri
        //	gercek degil ve bunu YALNIZ kod serhinde yazmak yetmez —
        //	ekrana bakan kisi de bilmeli. Veri gerceklestiginde bu satir
        //	KALDIRILIR.
        Center(
          child: Text(
            'Örnek içerik — canlı maç verisi henüz bağlı değil',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _baslik(String metin) => Text(
    metin,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.grey,
    ),
  );

  /// ⚠️ Kutu yuzeyi menu kartlariyla AYNI (`kAiKartYuzey`): iki ekran ayni
  ///    dili konussun, ikinci bir gri tonu uretilmesin.
  Widget _kutu(BuildContext context, {required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: kAiKartYuzey(context),
      borderRadius: BorderRadius.circular(kYaricap(60)),
    ),
    child: child,
  );
}

// ══════════════════════ PARCALAR ══════════════════════

/// ⚠️ Gol satiri: top ikonu + oyuncu + dakika.
/// ⚠️ Lucide'de FUTBOL TOPU glifi YOK (kontrol edildi: yalniz `volleyball`,
///    `goal`, `circleDot`). `volleyball` en yakin TOP glifi.
/// ⚠️ [evSahibi] golun HANGI takima ait oldugunu soyler: ev sahibi solda,
///    deplasman sagda hizalanir — futbol arayuzlerinin ortak dili.
class _GolSatiri extends StatelessWidget {
  const _GolSatiri({
    required this.oyuncu,
    required this.dakika,
    required this.evSahibi,
  });

  final String oyuncu;
  final String dakika;
  final bool evSahibi;

  @override
  Widget build(BuildContext context) {
    final satir = [
      const Icon(LucideIcons.volleyball, size: 15, color: Colors.white),
      const SizedBox(width: 8),
      // ⚠️ `Flexible`: uzun oyuncu adi satiri TASIRMASIN.
      Flexible(
        child: Text(
          oyuncu,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        dakika,
        style: TextStyle(
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.62),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: evSahibi
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: evSahibi ? satir : satir.reversed.toList(),
      ),
    );
  }
}

/// ⚠️⚠️ Iki yonlu istatistik cubugu: ortada ad, iki yanda sayilar, altta
///	ORANLI cubuk. Cubuk `Expanded` + `flex` ile bolunur — sabit genislik
///	dar ekranda TASARDI.
/// ⚠️ `flex` TAM SAYI ister ve **SIFIR OLAMAZ** (Flutter assertion):
///    `clamp(1, ...)` ile taban 1'e cekilir. Bir istatistik 0-0 olabilir.
class _Istatistik extends StatelessWidget {
  const _Istatistik({
    required this.ad,
    required this.sol,
    required this.sag,
    this.yuzde = false,
    this.sonuncu = false,
  });

  final String ad;
  final int sol;
  final int sag;
  final bool yuzde;
  final bool sonuncu;

  @override
  Widget build(BuildContext context) {
    final mor = Theme.of(context).colorScheme.primary;
    final gri = Colors.white.withValues(alpha: 0.18);
    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: sonuncu ? 2 : 10),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  yuzde ? '%$sol' : '$sol',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  yuzde ? '%$sag' : '$sag',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 4,
            child: Row(
              children: [
                Expanded(
                  flex: sol.clamp(1, 100000),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: mor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Expanded(
                  flex: sag.clamp(1, 100000),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: gri,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ⚠️ Dizilis sutunu: takim adi + sistem + oyuncular.
/// ⚠️ Adlar `maxLines: 1` + ellipsis: iki sutun yan yana ve dar ekranda
///    uzun bir ad satiri TASIRIRDI.
class _Dizilis extends StatelessWidget {
  const _Dizilis({
    required this.takim,
    required this.sistem,
    required this.oyuncular,
  });

  final String takim;
  final String sistem;
  final List<String> oyuncular;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        takim,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        sistem,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: 8),
      for (final o in oyuncular)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            o,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.25,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
    ],
  );
}
