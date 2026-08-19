library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYuzeyGri, kYanBosluk;
import 'gonderi_karti.dart' show sayiBicimle;

/// ⚠️⚠️⚠️ TURU 98i — **MOCKUP YORUMLAR** (kullanici emri + Threads ekran
///	goruntuleri: *"gonderiye tikladigimda boyle istiyorum gonderi
///	detayini, yorum mekanizmalari da boyle olmali, mockup yorumlar ekle,
///	gonderi sahibi begenisi / gonderi sahibi yorumu gibi"*).
///
/// ⚠️ **BU BIR GORUNUM DEMOSUDUR.** Sunucudaki gercek yorum hatti
///	(`post_comments` + `YorumlarSayfasi`) DEGISMEDI; bu dosya yalnizca
///	`kDemoAkis` acikken cizilir.
/// ⚠️ Gercek ozellik yazilirken sunucunun donmesi gerekenler: yorumun
///	`onayli` (mavi tik) bayragi · `sahibi` (gonderi sahibi mi) ·
///	repost/paylas sayaclari · "yanitlari goster" icin ALT YANIT SAYISI.
///	Bugun bunlarin HICBIRI donmuyor.
class DemoYorum {
  const DemoYorum({
    required this.ad,
    required this.kullaniciAdi,
    required this.zaman,
    required this.metin,
    this.onayli = false,
    this.sahibi = false,
    this.begeni = 0,
    this.yorum = 0,
    this.repost = 0,
    this.paylas = 0,
    this.begendim = false,
    this.yanitAdedi = 0,
    this.yanitlar = const [],
    this.medya = const [],
    this.medyaTur = const [],
  });

  final String ad;
  final String kullaniciAdi;
  final String zaman;
  final String metin;

  /// Mavi tik.
  final bool onayli;

  /// ⚠️ Gonderi SAHIBININ yorumu — Threads bunu ayrica isaretler; kullanici
  ///    *"gonderi sahibi yorumu gibi"* diyerek bunu istedi.
  final bool sahibi;

  final int begeni;
  final int yorum;
  final int repost;
  final int paylas;

  /// ⚠️ Gonderi SAHIBI bu yorumu begendi mi (Threads: "Yazar begendi").
  final bool begendim;

  /// "Yanıtları göster" satiri icin.
  final int yanitAdedi;

  final List<DemoYorum> yanitlar;

  /// ⚠️ TURU 101 — YORUMDA MEDYA (kullanici referansi: Threads yorumlarinda
  ///    fotograf/video var). Kimlikler `demo-` onekli oldugu icin gri yer
  ///    tutucu cizilir; sahte fotograf uretilmez.
  final List<String> medya;
  final List<String> medyaTur;
}

/// Demo yorumlari — gonderi kimligine gore.
List<DemoYorum> demoYorumlar(String gonderiId) => const [
  DemoYorum(
    ad: 'Mehmet Kaya',
    kullaniciAdi: 'mehmetkaya',
    zaman: '6dk',
    onayli: true,
    metin: 'Bu manzara için Gebze’ye gelmeye değer.',
    begeni: 825,
    yorum: 49,
    repost: 3,
    paylas: 20,
    begendim: true,
    yanitAdedi: 2,
    yanitlar: [
      DemoYorum(
        ad: 'Zeynep Ak',
        kullaniciAdi: 'zeynepak',
        zaman: '4dk',
        metin: 'Aynen, akşamüstü çok güzel oluyor.',
        begeni: 31,
      ),
    ],
  ),
  // ⚠️ TURU 101 — GORSELLI YORUM (Threads referansi).
  DemoYorum(
    ad: 'Selma Duman',
    kullaniciAdi: 'selma.dman',
    zaman: '23s',
    metin: 'Çok güzelmiş, biz de geçen hafta oradaydık.',
    begeni: 870,
    yorum: 28,
    repost: 2,
    begendim: true,
    medya: ['demo-yorum-1'],
    medyaTur: ['image'],
    yanitAdedi: 3,
    yanitlar: [
      DemoYorum(
        ad: 'Ayşe Demir',
        kullaniciAdi: 'aysedemir',
        zaman: '20s',
        sahibi: true,
        metin: 'Çok iyi olmuş!',
        begeni: 36,
        yorum: 1,
      ),
    ],
  ),
  DemoYorum(
    ad: 'Ayşe Demir',
    kullaniciAdi: 'aysedemir',
    zaman: '5dk',
    sahibi: true,
    metin: 'Teşekkürler! Sahil yolunun sonundan çektim.',
    begeni: 96,
    yorum: 4,
    paylas: 2,
  ),
  // ⚠️ VIDEOLU YORUM
  DemoYorum(
    ad: 'Enes Varol',
    kullaniciAdi: 'eenesvarol',
    zaman: '2g',
    metin: 'Hayat detaylarla güzel',
    begeni: 194,
    yorum: 3,
    begendim: true,
    medya: ['demo-yorum-2'],
    medyaTur: ['video'],
  ),
  DemoYorum(
    ad: 'Ali Yıldız',
    kullaniciAdi: 'aliyildiz',
    zaman: '12dk',
    metin: 'Hangi saatte gittin? Kalabalık mıydı?',
    begeni: 9,
    yorum: 1,
  ),
  DemoYorum(
    ad: 'Gebze Kebap Salonu',
    kullaniciAdi: 'gebzekebap',
    zaman: '20dk',
    metin: 'Dönüşte bekleriz',
    begeni: 4,
  ),
];

/// Akista gosterilecek TEK yanit (Threads: gonderinin altinda bir yanit
/// gorunur ve sola dogru bir baglanti cizgisi ceker).
DemoYorum? demoAkisYaniti(String gonderiId) {
  final l = demoYorumlar(gonderiId);
  // ⚠️ Her gonderide degil: kullanici *"anasayfada BAZEN yorumlari
  //    gosteriyor"* dedi. Kimligin uzunluguna gore basit bir dagitim.
  if (gonderiId.length % 2 == 1) return null;
  return l.first;
}

/// ⚠️⚠️ TURU 98i — THREADS TARZI YORUM SATIRI. Detay ekrani ve akistaki
///	tek-yanit blogu AYNI govdeyi kullanir (iki kopya drift ederdi).
class DemoYorumSatiri extends StatefulWidget {
  const DemoYorumSatiri({
    super.key,
    required this.y,
    this.cizgi = false,
    this.girinti = 0,
    this.yanitlariGoster = true,
  });

  final DemoYorum y;

  /// Sol tarafta THREAD CIZGISI (alttaki yanitlara baglanir).
  final bool cizgi;
  final double girinti;
  final bool yanitlariGoster;

  @override
  State<DemoYorumSatiri> createState() => _DemoYorumSatiriState();
}

class _DemoYorumSatiriState extends State<DemoYorumSatiri> {
  late bool _begendim = widget.y.begendim;
  late int _begeni = widget.y.begeni;

  static const double _avatar = 34;

  @override
  Widget build(BuildContext context) {
    final y = widget.y;
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kYanBosluk + widget.girinti,
        10,
        kYanBosluk,
        4,
      ),
      // ⚠️⚠️⚠️ TURU 98i — `IntrinsicHeight` ZORUNLU (emulatorde COKME).
      //
      //	Thread cizgisi avatarin ALTINDA `Expanded` ile uzuyor; ama o
      //	Column, `Row(crossAxisAlignment: start)` icinde **SINIRSIZ**
      //	yukseklik kisiti aliyordu. Sinirsiz kisitta `Expanded` dagitacak
      //	alan bulamaz: *"RenderBox was not laid out"* -> ardindan
      //	"child.hasSize is not true" -> **DETAY EKRANI TAMAMEN BOS** cikti.
      // ⚠️ `IntrinsicHeight` satirin dogal yuksekligini olcup cocuklara
      //    SIKI kisit verir; cizgi de o yuksekligi doldurur.
      // ⚠️ YAPMA: `IntrinsicHeight`i kaldirip `Expanded`i birakma.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- AVATAR + thread cizgisi
            Column(
              children: [
                Container(
                  width: _avatar,
                  height: _avatar,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kYuzeyGri(context),
                  ),
                ),
                if (widget.cizgi)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 6),
                      color: tema.colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          y.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (y.onayli) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          LucideIcons.badgeCheck,
                          size: 14,
                          color: Color(0xFF1D9BF0),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        y.zaman,
                        style: TextStyle(fontSize: 12, color: soluk),
                      ),
                      // ⚠️ GONDERI SAHIBI rozeti (kullanici emri).
                      if (y.sahibi) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: tema.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Gönderi sahibi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tema.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(y.metin, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 6),
                  // ---- ETKILESIM (akis kartiyla AYNI dil, daha kucuk)
                  Row(
                    children: [
                      _minEylem(
                        ikon: _begendim ? Icons.favorite : LucideIcons.heart,
                        sayi: _begeni,
                        renk: _begendim ? const Color(0xFFFF3B5C) : null,
                        onTap: () => setState(() {
                          _begendim = !_begendim;
                          _begeni += _begendim ? 1 : -1;
                        }),
                      ),
                      _minEylem(ikon: LucideIcons.messageCircle, sayi: y.yorum),
                      _minEylem(ikon: LucideIcons.redo2, sayi: y.repost),
                      _minEylem(ikon: LucideIcons.send, sayi: y.paylas),
                    ],
                  ),
                  if (widget.yanitlariGoster && y.yanitAdedi > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(
                        'Yanıtları göster',
                        style: TextStyle(fontSize: 13, color: soluk),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ Kart cubugunun KUCUK kardesi: ayni ikon dili, 20 px.
  Widget _minEylem({
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
              // ⚠️ Sayi degisince YUKARI kayar (kart cubuguyla ayni efekt).
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
