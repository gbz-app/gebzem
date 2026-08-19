library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYuzeyGri, kYanBosluk;
import 'gonderi_karti.dart' show sayiBicimle, kBaslikAra;
import '../medya/medya_gorsel.dart';
import 'thread_cizgi.dart';

/// ⚠️⚠️⚠️ TURU 99 — YORUM SATIRININ **TEK GORUNUM MODELI**.
///
///	Denetim bulgusu: ayni satirin IKI govdesi vardi (`DemoYorumSatiri` ve
///	`YorumlarSayfasi._satir`) — biri 34 dp avatar / 15 punto / 4 ikon,
///	oteki 32-26 dp / 13 punto / cizgi yok. Iki kopya KACINILMAZ olarak
///	drift eder. Artik gercek `Yorum` da demo da BU modele donusur.
class YorumGorunum {
  const YorumGorunum({
    required this.id,
    required this.ad,
    required this.kullaniciAdi,
    required this.zaman,
    required this.metin,
    this.avatarMediaId,
    this.onayli = false,
    this.yazarMi = false,
    this.sahipBegendi = false,
    this.begeni = 0,
    this.yorum = 0,
    this.repost = 0,
    this.paylas = 0,
    this.begendim = false,
    this.yanitlar = const [],
    this.medya = const [],
    this.medyaTur = const [],
  });

  final String id;
  final String ad;
  final String kullaniciAdi;
  final String zaman;
  final String metin;
  final String? avatarMediaId;

  /// Mavi tik.
  final bool onayli;

  /// Bu yorum GONDERININ SAHIBINE mi ait ("Gönderi Sahibi" hapi).
  final bool yazarMi;

  /// Gonderi sahibi bu yaniti **BEGENDI** (sagda kirmizi kalp + minik avatar).
  final bool sahipBegendi;

  final int begeni;
  final int yorum;
  final int repost;
  final int paylas;
  final bool begendim;

  final List<YorumGorunum> yanitlar;

  /// ⚠️ TURU 101 — yorumda medya (Threads referansi).
  final List<String> medya;
  final List<String> medyaTur;
}

/// ⚠️ Avatar capi ve girinti TEK KAYNAK — girinti CAPTAN turetilir.
const double kYorumAvatar = 34;
const double kYorumAvatarAlt = 28;
const double kYorumGirinti = kYorumAvatar + kBaslikAra;

/// "Yanıtları göster" satirindaki avatarin capi ve satir yuksekligi.
const double kYanitAvatar = 22;
const double kYanitSatirBoy = 40;

/// ⚠️⚠️⚠️ TURU 99b — **YANIT GRUBU** (kok yorum + "Yanıtları göster" + acilan
///	yanitlar). Kullanici: *"o ok nereye gidiyor? profil yok"* — HAKLIYDI.
///
///	ILK YAZIMDA cizgi `YorumSatiri`IN ICINDE ciziliyordu: satir bitince
///	cizgi de bitiyor, kivrim **BOSLUKTA** kaliyordu; asagidaki satir ayri
///	bir widget oldugu ve kendi dolgusunu tasidigi icin ikisi GORSEL OLARAK
///	BIRLESMIYORDU.
///
/// **DOGRU MIMARI (Threads):** cizgi bir SATIRA degil, GRUBUN SOLUNDAKI
/// **OLUGA** aittir. Tek `CustomPaint` katmani kok avatarin ALTINDAN baslar,
/// grubun dibine iner ve tam "Yanıtları göster" avatarinin MERKEZINDE saga
/// kivrilip ona DEGER.
///
/// ⚠️ Kivrimin bitis y'si `size.height - kYanitSatirBoy / 2` ile TURETILIR;
///    o satirin yuksekligi SABIT oldugu icin hesap deterministiktir.
/// ⚠️ YAPMA: cizgiyi tekrar `YorumSatiri` icine tasima.
class YorumGrubu extends StatelessWidget {
  const YorumGrubu({
    super.key,
    required this.kok,
    required this.acik,
    required this.onYanitlariGoster,
    this.onDokun,
  });

  final YorumGorunum kok;
  final bool acik;
  final VoidCallback onYanitlariGoster;
  final void Function(YorumGorunum)? onDokun;

  @override
  Widget build(BuildContext context) {
    final yanitVar = kok.yanitlar.isNotEmpty;
    // ⚠️⚠️⚠️ TURU 101 — ACIKKEN "Yanıtları göster" SATIRI KALKAR.
    //
    //	Kullanici: *"bizde yanitlari gizleye cizgi cekmissin, mantiksiz bir
    //	cizgi"* — HAKLIYDI. Threads'te cizgi bir HEDEFE (gizli yanitlarin
    //	avatarina) isaret eder; yanitlar ACILINCA o hedef ortadan kalkar,
    //	cizgi de kivrilmadan yanitlarin yaninda DUZ iner.
    // ⚠️ Kapatma yolu: satir kalkinca yanitlar acik KALIR (Threads de
    //    boyle davranir — acilan yanit gizlenmez).
    final rozetVar = yanitVar && !acik;
    final govde = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YorumSatiri(y: kok, onDokun: () => onDokun?.call(kok)),
        if (yanitVar) ...[
          if (acik)
            for (final alt in kok.yanitlar)
              YorumSatiri(
                y: alt,
                derinlik: 1,
                onDokun: () => onDokun?.call(alt),
              ),
          if (rozetVar)
            YanitlariGosterSatiri(
              adet: kok.yanitlar.length,
              onTap: onYanitlariGoster,
            ),
        ],
      ],
    );
    if (!yanitVar) return govde;

    return Stack(
      children: [
        // ---- OLUK: tek parca baglanti cizgisi
        Positioned(
          left: kYanBosluk,
          top: _cizgiBasi,
          bottom: 0,
          width: kYorumAvatar,
          child: CustomPaint(
            painter: ThreadCizgi(
              // ⚠️ Kivrim YALNIZ rozet varken; acikken cizgi duz iner.
              kivrimli: rozetVar,
              renk: threadCizgiRengi(context),
              altPay: rozetVar ? kYanitSatirBoy / 2 : 0,
            ),
          ),
        ),
        govde,
      ],
    );
  }

  /// Kok satirin ust dolgusu (10) + avatar (34) + 6 dp nefes.
  static const double _cizgiBasi = 10 + kYorumAvatar + 6;
}

/// Threads tarzi yorum satiri.
///
/// ⚠️ Baglanti cizgisi BURADA CIZILMEZ (bkz. `YorumGrubu`); bu widget yalniz
///    avatar + icerik cizer.
class YorumSatiri extends StatefulWidget {
  const YorumSatiri({
    super.key,
    required this.y,
    this.derinlik = 0,
    this.onDokun,
  });

  final YorumGorunum y;

  /// 0 = kok yorum, 1 = yanit.
  /// ⚠️ Sunucu agaci **TEK SEVIYE** (yanitin yaniti koke baglanir).
  final int derinlik;

  final VoidCallback? onDokun;

  @override
  State<YorumSatiri> createState() => _YorumSatiriState();
}

class _YorumSatiriState extends State<YorumSatiri> {
  late bool _begendim = widget.y.begendim;
  late int _begeni = widget.y.begeni;

  @override
  Widget build(BuildContext context) {
    final y = widget.y;
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurface.withValues(alpha: 0.55);
    final cap = widget.derinlik == 0 ? kYorumAvatar : kYorumAvatarAlt;

    return InkWell(
      onTap: widget.onDokun,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kYanBosluk + widget.derinlik * kYorumGirinti,
          10,
          kYanBosluk,
          4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: kYorumAvatar,
              child: Align(
                alignment: Alignment.topCenter,
                child: MiniAvatar(cap: cap),
              ),
            ),
            const SizedBox(width: kBaslikAra),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _baslik(y, soluk, tema),
                  const SizedBox(height: 3),
                  if (y.metin.isNotEmpty)
                    Text(y.metin, style: const TextStyle(fontSize: 15)),
                  // ⚠️ TURU 101 — YORUM MEDYASI. Threads'te yorum da
                  //    fotograf/video tasir; kutu 16:11 orana yakin, kose
                  //    yaricapi kartla ayni dilde (14).
                  if (y.medya.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 0.86,
                        child: MedyaGorsel(
                          mediaId: y.medya.first,
                          kucuk: true,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _eylemler(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baslik(YorumGorunum y, Color soluk, ThemeData tema) => Row(
    children: [
      Flexible(
        child: Text(
          y.ad,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      if (y.onayli) ...[
        const SizedBox(width: 4),
        const Icon(LucideIcons.badgeCheck, size: 14, color: Color(0xFF1D9BF0)),
      ],
      const SizedBox(width: 6),
      Text(y.zaman, style: TextStyle(fontSize: 13, color: soluk)),
      if (y.yazarMi) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: tema.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Gönderi Sahibi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tema.colorScheme.primary,
            ),
          ),
        ),
      ],
      const Spacer(),
      // ⚠️⚠️ GONDERI SAHIBININ BEGENISI. SABIT 20 dp kutuda yasar: rozet
      //	gelip gidince satir yuksekligi DEGISMEZ, liste ZIPLAMAZ.
      // ⚠️ Renk TEK BASINA bilgi tasimaz -> `Semantics` ZORUNLU.
      if (y.sahipBegendi)
        Semantics(
          label: 'Gönderi sahibi bu yanıtı beğendi',
          child: SizedBox(
            height: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 12, color: Color(0xFFFF3B5C)),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tema.scaffoldBackgroundColor,
                  ),
                  child: const MiniAvatar(cap: 16),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _eylemler() => Row(
    children: [
      _min(
        ikon: _begendim ? Icons.favorite : LucideIcons.heart,
        sayi: _begeni,
        renk: _begendim ? const Color(0xFFFF3B5C) : null,
        onTap: () => setState(() {
          _begendim = !_begendim;
          _begeni += _begendim ? 1 : -1;
        }),
      ),
      _min(ikon: LucideIcons.messageCircle, sayi: widget.y.yorum),
      _min(ikon: LucideIcons.redo2, sayi: widget.y.repost),
      _min(ikon: LucideIcons.send, sayi: widget.y.paylas),
    ],
  );

  Widget _min({
    required IconData ikon,
    int sayi = 0,
    Color? renk,
    VoidCallback? onTap,
  }) {
    final c = renk ?? Theme.of(context).iconTheme.color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 19, color: c),
            if (sayi > 0) ...[
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (cocuk, an) => ClipRect(
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.6),
                      end: Offset.zero,
                    ).animate(an),
                    child: FadeTransition(opacity: an, child: cocuk),
                  ),
                ),
                child: Text(
                  sayiBicimle(sayi),
                  key: ValueKey<int>(sayi),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ⚠️ Serit kuralinin aynisi: fotografsiz avatar **HARF DEGIL DUZ GRI DAIRE**
///    (kullanici emri, turu 98d).
class MiniAvatar extends StatelessWidget {
  const MiniAvatar({super.key, required this.cap});
  final double cap;

  @override
  Widget build(BuildContext context) => Container(
    width: cap,
    height: cap,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: kYuzeyGri(context),
    ),
  );
}

/// ⚠️⚠️⚠️ TURU 99b — **"YANITLARI GOSTER" SATIRI** — referans gorseldeki hali:
///	**TEK profil resmi** + resmin SAG ALT kosesine YAPISIK, icinde asagi ok
///	olan koyu yuvarlak rozet + yaninda metin.
///
/// ⚠️ Ilk yazimda uc gri daire (facepile) + AYRI bir ok rozeti vardi; kullanici
///    referansi gosterip *"profil yok, o ok nereye gidiyor"* dedi. Referans
///    TEK avatar + YAPISIK rozet.
/// ⚠️ Sol dolgu **TURETILIR**: oluktaki kivrimin bittigi x =
///    `kYanBosluk + kYorumAvatar/2 + yaricap + yatay`. Sabit sayi yazilirsa
///    avatar cizgiden KOPAR.
/// ⚠️ Satir yuksekligi `kYanitSatirBoy` SABIT — `YorumGrubu` kivrimin bitis
///    noktasini bu sayidan hesapliyor; degistirirsen ikisi birlikte degisir.
class YanitlariGosterSatiri extends StatelessWidget {
  const YanitlariGosterSatiri({
    super.key,
    required this.adet,
    required this.onTap,
  });

  final int adet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final soluk = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.55);
    final sol =
        kYanBosluk + kYorumAvatar / 2 + ThreadCizgi.yaricap + ThreadCizgi.yatay;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(left: sol, right: kYanBosluk),
        child: SizedBox(
          height: kYanitSatirBoy,
          child: Row(
            children: [
              // ---- AVATAR + YAPISIK OK ROZETI
              SizedBox(
                width: kYanitAvatar + 4,
                height: kYanitAvatar + 4,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const MiniAvatar(cap: kYanitAvatar),
                    // ⚠️ Rozet avatarin SAG ALT kosesine BINER (-2/-2);
                    //    sifirda kutunun icinde kalip "yanda duruyor" gibi
                    //    gorunuyordu.
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.onSurface,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: AnimatedRotation(
                            turns: 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              LucideIcons.chevronDown,
                              size: 9,
                              color: Theme.of(context).scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Yanıtları göster',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: soluk),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
