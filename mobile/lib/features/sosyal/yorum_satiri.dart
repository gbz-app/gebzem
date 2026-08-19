library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYuzeyGri, kYanBosluk;
import 'gonderi_karti.dart' show sayiBicimle, kBaslikAra, gonderiZamani;
import '../medya/medya_gorsel.dart';
import 'sosyal_servisi.dart' show Yorum;
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
/// ⚠️ **44** — Material/Apple dokunma minimumu. Turu 101'de 40 idi.
/// ⚠️ Kivrimin bitis noktasi bu sayinin YARISIDIR; degistirirsen cizgi de
///    otomatik uyar (sabit sayi yok).
const double kYanitSatirBoy = 44;

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
    // ⚠️ Cizgi KOSULLUDUR: yanit yoksa cizilmez (havada biten cizgi yasak).
    if (kok.yanitlar.isEmpty) {
      return YorumSatiri(
        key: ValueKey(kok.id),
        y: kok,
        onDokun: () => onDokun?.call(kok),
      );
    }
    final renk = threadCizgiRengi(context);
    final son = kok.yanitlar.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- KOK: cizgi avatarin ALTINDAN baslar, satir sonuna kadar iner
        _segment(
          renk: renk,
          bas: _cizgiBasi,
          cocuk: YorumSatiri(
            key: ValueKey(kok.id),
            y: kok,
            onDokun: () => onDokun?.call(kok),
          ),
        ),
        // ⚠️⚠️⚠️ ACIKKEN "Yanıtları göster" SATIRI KALKAR ve cizgi DUZ iner.
        //
        //	Kullanici: *"bizde yanitlari gizleye cizgi cekmissin, mantiksiz
        //	bir cizgi"* — HAKLIYDI. Kivrim bir SONLANDIRICIDIR: "burada
        //	GIZLI icerik var" der. Yanitlar acilinca gizli icerik kalmaz.
        if (acik)
          ...[
            for (var i = 0; i <= son; i++)
              _segment(
                renk: renk,
                // ⚠️⚠️ SON yanitta cizgi o satirin AVATAR MERKEZINDE biter.
                //	Turu 101'de tek katman + `bottom: 0` kullaniliyordu ve
                //	cizgi son yanitin ICERIGININ altina iniyordu; medyali
                //	bir yanitta ~200 dp bosluga sarkiyordu.
                boy: i == son ? _yanitOrtasi : null,
                cocuk: YorumSatiri(
                  key: ValueKey(kok.yanitlar[i].id),
                  y: kok.yanitlar[i],
                  derinlik: 1,
                  onDokun: () => onDokun?.call(kok.yanitlar[i]),
                ),
              ),
          ]
        else
          _segment(
            renk: renk,
            kivrimli: true,
            boy: kYanitSatirBoy / 2,
            cocuk: YanitlariGosterSatiri(onTap: onYanitlariGoster),
          ),
      ],
    );
  }

  /// Bir satiri, SOLUNDA cizgi parcasi olan bir yigina sarar.
  ///
  /// ⚠️⚠️ **CIZGI NEDEN TEK KATMAN DEGIL, PARCALI:** acik moddaki cizginin
  ///	SON YANITIN AVATAR MERKEZINDE bitmesi gerekir (kural: cizginin ucu
  ///	daima bir NESNEYE deger). Tek katmanda bu ancak son satirin yuksekligi
  ///	OLCULEREK yapilabilir; o yukseklik yanitin medyasina ve metin
  ///	uzunluguna gore degisir. Parcali cizimde her satir KENDI payini cizer,
  ///	son satir yalnizca avatar merkezine kadar iner ve hesap SABIT olur.
  /// ⚠️ Parcalar bitisiktir; ekranda TEK bir cizgi gorunur.
  Widget _segment({
    required Color renk,
    required Widget cocuk,
    double bas = 0,
    double? boy,
    bool kivrimli = false,
  }) => Stack(
    children: [
      Positioned(
        left: kYanBosluk,
        top: bas,
        bottom: boy == null ? 0 : null,
        height: boy,
        width: kYorumAvatar,
        child: CustomPaint(
          painter: ThreadCizgi(kivrimli: kivrimli, renk: renk),
        ),
      ),
      cocuk,
    ],
  );

  /// Kok satirin ust dolgusu (10) + avatar (34) + 6 dp nefes.
  static const double _cizgiBasi = 10 + kYorumAvatar + 6;

  /// Yanit satirinin ust dolgusu (10) + kucuk avatarin yarisi.
  static const double _yanitOrtasi = 10 + kYorumAvatarAlt / 2;
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

  /// ⚠️⚠️⚠️ TURU 113 (denetim) — **KALP YANLIS YORUMA YAPISIYORDU.**
  ///
  ///	`_begendim`/`_begeni` `late` ile BIR KEZ kurulur. Siralama
  ///	degistiginde ("Başlıca" <-> "Yakınlarda") liste GERCEKTEN yeniden
  ///	siralaniyor; Flutter key'siz cocuklari **KONUMA gore** yeniden
  ///	kullandigi icin ayni `State` yeni bir yoruma bagleniyor ve kirmizi
  ///	kalp + sayac ESKI yorumdan kaliyordu.
  ///	Cagri yerlerinde `ValueKey(y.id)` verildi; bu metot IKINCI KATMAN
  ///	(key unutulan yeni bir cagri yerinde de veri tazelensin).
  /// ⚠️ Kullanicinin O ANDA yaptigi dokunusu ezmemek icin yalniz KIMLIK
  ///    degistiginde sifirlanir.
  @override
  void didUpdateWidget(covariant YorumSatiri eski) {
    super.didUpdateWidget(eski);
    if (eski.y.id != widget.y.id) {
      _begendim = widget.y.begendim;
      _begeni = widget.y.begeni;
    }
  }

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
                child: MiniAvatar(cap: cap, mediaId: y.avatarMediaId),
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
                    _medya(y),
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

  /// ⚠️⚠️⚠️ TURU 102 — YORUM MEDYASINDA **TUR KONTROLU** (turu 83b dersinin
  ///	tekrari): `medyaTur` alani turu 101'de modelde TASINIYOR ama HICBIR
  ///	YERDE OKUNMUYORDU; videolu yorum dogrudan `MedyaGorsel`e dusuyor ve
  ///	**KIRIK GORSEL** ciziyordu. Video artik yer tutucu + OYNAT rozetiyle
  ///	cizilir.
  /// ⚠️ En-boy **16:11** (yatay): serhi 16:11 diyordu ama govdede 0.86
  ///    (DIKEY) yaziliydi; dikey kutu akistaki yaniti gonderiden daha uzun
  ///    gosteriyordu.
  Widget _medya(YorumGorunum y) {
    final videoMu =
        y.medyaTur.isNotEmpty && y.medyaTur.first.startsWith('video');
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 11,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MedyaGorsel(mediaId: y.medya.first, kucuk: true, fit: BoxFit.cover),
            if (videoMu)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x66000000),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
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

  /// ⚠️⚠️ **ISLEVI OLMAYAN IKON TAM OPAK CIZILMEZ** (turu 102 kurali).
  ///	Yanit · repost · paylas ucunun de sunucuda karsiligi YOK
  ///	(`post_comments` altina yanit yazan uc yok; repost/alinti diye bir
  ///	sey yok). Turu 101'de ucu de tam opak ciziliyor ve dokununca HICBIR
  ///	SEY olmuyordu — kullanici bunu KIRIK sanardi.
  /// ⚠️ Begeni de bugun YALNIZ EKRANDA artiyor (`comment_likes` tablosu var,
  ///    INSERT/DELETE ucu YOK) ama etkilesim gercek oldugu icin opak kalir.
  /// ⚠️⚠️⚠️ TURU 113 (denetim, YUKSEK) — **TASMA KORUMASI EKLENDI.**
  ///
  ///	Kardesi `gonderi_karti._eylem` turu 98c'de `FittedBox(scaleDown)` ile
  ///	korunmustu; BURADA hicbir koruma yoktu. Derinlik 1'de alan
  ///	360 - 60 - 16 - 34 - 10 = **240 dp**; dort sayac da "1,2 bin" olursa
  ///	gereken 292.8 dp (yazi olcegi 1.3'te **340 dp**) — yani **100 dp'ye
  ///	varan tasma**. Derinlik 0'da bile normal olcekte 8.8 dp tasiyor.
  ///
  /// ⚠️⚠️ **DEMO VERISI BU HATAYI GIZLIYORDU**: demo sayaclar (825/2/3/20)
  ///	203 dp tutuyor ve rahatca siyor. Hata ancak gercek hat baglanip
  ///	sayilar buyuyunce cikardi — turu 93b'nin *"dolu alan, IS GOREN alan
  ///	demek DEGILDIR"* dersinin aynisi.
  /// ⚠️ YAPMA: `FittedBox`i kaldirip sabit butce hesabina donme.
  Widget _eylemler() => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Row(
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
      _min(
        ikon: LucideIcons.messageCircle,
        sayi: widget.y.yorum,
        pasif: true,
        onTap: () => _yok('Yanıt yazma'),
      ),
      _min(
        ikon: LucideIcons.redo2,
        sayi: widget.y.repost,
        pasif: true,
        onTap: () => _yok('Yeniden paylaşma'),
      ),
      _min(
        ikon: LucideIcons.send,
        sayi: widget.y.paylas,
        pasif: true,
        onTap: () => _yok('Yorumu paylaşma'),
      ),
      ],
    ),
  );

  void _yok(String ne) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text('$ne özelliği henüz yok'),
    ),
  );

  Widget _min({
    required IconData ikon,
    int sayi = 0,
    Color? renk,
    VoidCallback? onTap,
    bool pasif = false,
  }) {
    final temel = renk ?? Theme.of(context).iconTheme.color;
    final c = pasif ? temel?.withValues(alpha: 0.45) : temel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        // ⚠️ TURU 113 (denetim) — dikey dolgu 5 -> 12: hedef 29 dp idi,
        //    kardesi `gonderi_karti._eylem` 44 dp kullaniyor. Ayni
        //    uygulamada iki farkli olcut olmasin.
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
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
  const MiniAvatar({super.key, required this.cap, this.mediaId});
  final double cap;

  /// ⚠️ TURU 102 — gercek profil fotografi. Turu 101'de `YorumGorunum`
  ///    `avatarMediaId` tasiyordu ama HICBIR YERDE OKUNMUYORDU; gercek
  ///    hatta baglaninca herkes duz gri daire olarak cizilirdi ve cizginin
  ///    gerekcesi ("bu KISI suna cevap veriyor") cokerdi.
  /// ⚠️ Demoda `null` gecer -> duz gri (kullanici emri: harf YOK).
  final String? mediaId;

  @override
  Widget build(BuildContext context) {
    final gri = Container(
      width: cap,
      height: cap,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kYuzeyGri(context),
      ),
    );
    final id = mediaId ?? '';
    if (id.isEmpty) return gri;
    return ClipOval(
      child: SizedBox(
        width: cap,
        height: cap,
        child: MedyaGorsel(mediaId: id, kucuk: true, fit: BoxFit.cover),
      ),
    );
  }
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
  // ⚠️ Turu 101'deki `adet` parametresi KALDIRILDI: cagri yerinde
  //    dolduruluyor ama govdede HIC okunmuyordu (olu parametre). Threads de
  //    bu satirda sayi yazmaz.
  const YanitlariGosterSatiri({super.key, required this.onTap});

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
                          // ⚠️ Turu 101'de burada `AnimatedRotation(turns: 0)`
                          //    vardi; deger hic degismedigi icin OLU
                          //    animasyondu (satir zaten acilinca kalkiyor).
                          child: Builder(
                            builder: (_) => Icon(
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


// ---------------------------------------------------------------------------
// ⚠️⚠️⚠️ TURU 102 — **GERCEK YORUM -> GORUNUM MODELI.**
//
//	Denetim bulgusu (sevk engeli): detay ekraninin TUM yorum bolumu bir
//	`if (kDemoAkis)` blogunun icindeydi. Demo kapatildigi gun ekranin alt
//	yarisi **SESSIZCE BOSALACAKTI** — bu projede kayitli en pahali hata
//	sinifi ("arayuz var, veri yok"in tersi: veri var, arayuz kayboluyor).
//
//	Artik ayni gorunum modeli GERCEK `Yorum` listesinden de uretilebiliyor;
//	boylece thread mimarisi demo icin yazilmis bir vitrin olmaktan cikip
//	gercek hatta da CALISAN bir bilesen oluyor.
// ---------------------------------------------------------------------------

/// Duz yorum listesini **TEK SEVIYE** agaca cevirir.
///
/// ⚠️ Sunucu `parent_id` donduruyor ama agaci DUZLESTIRIYOR (yanitin yaniti
///    da koke baglanir — `internal/social/etkilesim.go`). Bu yuzden istemci
///    de TEK KADEME girinti cizer; ikinci kademe cizmek OLMAYAN bir
///    hiyerarsiyi iddia etmek olurdu.
/// ⚠️ **Sunucuda OLMAYAN alanlar UYDURULMAZ**: `onayli` (mavi tik),
///	`sahipBegendi` (yazarin begenisi), `repost`, `paylas` alanlari
///	GERCEK veride DAIMA bos/false gecer — rozet cizilmez, sayi yazilmaz.
/// ⚠️ `yazarMi` demo ile AYNI yoldan (kullanici adi karsilastirmasi) turer.
List<YorumGorunum> yorumAgaci(
  List<Yorum> ham, {
  required String yazarKullaniciAdi,
}) {
  final kokler = <YorumGorunum>[];
  final yanitlar = <int, List<Yorum>>{};
  for (final y in ham) {
    if (y.parentId != null) {
      (yanitlar[y.parentId!] ??= <Yorum>[]).add(y);
    }
  }
  YorumGorunum cevir(Yorum y, List<YorumGorunum> alt) => YorumGorunum(
    id: 'y-${y.id}',
    ad: y.yazarAd.isEmpty ? y.yazarUsername : y.yazarAd,
    kullaniciAdi: y.yazarUsername,
    zaman: gonderiZamani(y.createdAt),
    metin: y.metin,
    avatarMediaId: y.yazarAvatarMediaId,
    yazarMi: y.yazarUsername == yazarKullaniciAdi,
    begeni: y.begeniSayisi,
    begendim: y.begendim,
    yanitlar: alt,
  );
  for (final y in ham) {
    if (y.parentId != null) continue;
    kokler.add(
      cevir(y, [for (final a in yanitlar[y.id] ?? const <Yorum>[]) cevir(a, const [])]),
    );
  }
  return kokler;
}
