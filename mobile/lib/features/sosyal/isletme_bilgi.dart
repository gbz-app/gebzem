/// ⚠️⚠️⚠️ TURU 179 — **ISLETME BILGI PANELI + YORUMLAR PANELI.**
///
/// Kullanici emri (tek mesajda iki panel):
///   · *"sag ustte hamburger menunun soluna SORU ISARETI, isletme hakkinda
///     bilgi ... gonderinin solundaki GENEL bilgileri oraya tikladiginda
///     %95 POPUP olarak acilsin, bu bilgilerin ARKA PLAN RENGI olacak,
///     SAAT IKONU eklemelisin, burada facebook whatsapp vb bilgiler de
///     olacak"*
///   · *"takip et ve mesaj arasina YORUMLAR olsun, yapay zeka tarafindan
///     yorumlarin analizi yapildi, buna tikladiginda yorumlar popup
///     acilacak, yildiz verme, mockup guzel turkce yorumlar olsun,
///     saatleri vs, bu yorumlari begenme sikayet"*
///
/// ⚠️ Panel `profil_sayfasi.dart`tan CIKARILDI: o dosya 1.600+ satir ve bu
///    projede orada uye silmek/eklemek BES kez komsu uyeyi goturdu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../isletme/isletme_servisi.dart';

const _gunAd = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];

/// ⚠️ `%95` kullanicinin verdigi olcu. `isScrollControlled` OLMADAN tavan
///    ekranin 9/16'sidir ve panel KIRPILIRDI (turu 90b/115c dersi).
Future<void> isletmeBilgiAc(
  BuildContext context, {
  required String ad,
  required Isletme isletme,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: kAiZemin,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => koyuSayfa(
    FractionallySizedBox(
      heightFactor: 0.95,
      child: Material(
        color: kAiZemin,
        child: _BilgiPaneli(ad: ad, i: isletme),
      ),
    ),
  ),
);

class _BilgiPaneli extends ConsumerWidget {
  const _BilgiPaneli({required this.ad, required this.i});

  final String ad;
  final Isletme i;

  ColorScheme get _ks => kKoyuTema.colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ Katalog SUNUCUDAN (ad + ikon). Gelmemisse ozellik bolumleri
    //    CIZILMEZ — anahtari ham haliyle ("sigara_yok") gostermek
    //    kullaniciya anlamsiz gorunurdu.
    final katalog = ref.watch(isletmeKatalogProvider).valueOrNull;
    final adres = [i.adres, i.ilce, i.il].where((x) => x.isNotEmpty).join(', ');
    return Column(
      children: [
        _baslik(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _durumSeridi(),
              const SizedBox(height: 14),
              if (adres.isNotEmpty)
                _kart(
                  ikon: LucideIcons.mapPin,
                  etiket: 'Adres',
                  deger: adres,
                  // ⚠️ Dokunus YALNIZ koordinat VARSA: koordinatsiz bir
                  //    adresle harita acmak BOS ekran gosterirdi.
                  onTap: (i.enlem != null && i.boylam != null)
                      ? () => _haritaAc(i.enlem!, i.boylam!, ad)
                      : null,
                ),
              if (i.telefon.isNotEmpty)
                _kart(
                  ikon: LucideIcons.phone,
                  etiket: 'Telefon',
                  deger: i.telefon,
                  onTap: () => _ac('tel:${_sadeTel(i.telefon)}'),
                ),
              // ⚠️⚠️ WhatsApp **TELEFONDAN TURETILIR**, ayri bir alan YOK.
              //    `wa.me` numarayi ulke koduyla ve isaretsiz ister.
              // ⚠️ Numara yoksa satir HIC cizilmez — dokunulabilir gorunup
              //    hicbir sey yapmayan alan birakmak bu projede tekrar eden
              //    "olu dugme" sinifidir.
              if (i.telefon.isNotEmpty)
                _kart(
                  ikon: LucideIcons.messageCircle,
                  etiket: 'WhatsApp',
                  deger: 'Mesaj gönder',
                  onTap: () => _ac('https://wa.me/${_sadeTel(i.telefon)}'),
                ),
              if (i.web.isNotEmpty)
                _kart(
                  ikon: LucideIcons.globe,
                  etiket: 'Web',
                  deger: i.web,
                  onTap: () => _ac(_webAdresi(i.web)),
                ),
              if (i.calisma.isNotEmpty) ...[
                const SizedBox(height: 8),
                _bolumBasligi(LucideIcons.clock, 'Çalışma saatleri'),
                const SizedBox(height: 8),
                _saatlerKarti(),
              ],
              // ⚠️⚠️⚠️ TURU 180 — **OZELLIKLER VE ODEME SECENEKLERI.**
              //
              //	Turu 176/179'da BILEREK yazilmamisti: sunucuda alan
              //	YOKTU ve sabit bir liste basmak *"bu isletme kredi
              //	karti aliyor"* YALANI olurdu. Kullanici ozelligi
              //	IKINCI kez isteyince dogru yol arayuze sahte liste
              //	koymak DEGIL, **alani acmak** oldu: migration 050 +
              //	`GET /isletme-katalog` + duzenleme formu.
              //
              // ⚠️ Bos liste = bolum HIC cizilmez: "Özellikler: —" gibi bos
              //	bir baslik paneli kirletir.
              // ⚠️ Kullanicinin *"daha fazla iletisim kanali eklenmemis"*
              //	satirini KALDIR emri de burada uygulandi.
              if (katalog != null) ...[
                _cipBolumu(
                  LucideIcons.badgeCheck,
                  'Özellikler',
                  i.ozellikler,
                  katalog.harita,
                ),
                _cipBolumu(
                  LucideIcons.wallet,
                  'Ödeme seçenekleri',
                  i.odeme,
                  katalog.harita,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Yemek ekraniyla ayni 44 dp header.
  Widget _baslik(BuildContext context) => SizedBox(
    height: 44,
    child: Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Text(
              ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.0,
                leadingDistribution: TextLeadingDistribution.even,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(LucideIcons.x, size: 22),
            ),
          ),
        ),
      ],
    ),
  );

  /// Su an acik / kapali seridi.
  ///
  /// ⚠️ Calisma saati GIRILMEMISSE serit HIC cizilmez: "kapali" demek
  ///    olmayan bir veriyi iddia etmek olurdu.
  Widget _durumSeridi() {
    if (i.calisma.isEmpty) return const SizedBox.shrink();
    final acik = i.simdiAcik;
    final renk = acik ? const Color(0xFF2BB673) : const Color(0xFF8A6A4F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(acik ? LucideIcons.doorOpen : LucideIcons.doorClosed,
              size: 19, color: renk),
          const SizedBox(width: 10),
          Text(
            acik ? 'Şu an açık' : 'Şu an kapalı',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: renk,
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ Bilinmeyen anahtar ATLANIR (katalogda yoksa): sunucudan kaldirilmis
  ///	bir ozellik eski kayitlarda kalmis olabilir ve ham anahtari
  ///	("sigara_yok") ekrana basmak kullaniciya anlamsiz gorunurdu.
  Widget _cipBolumu(
    IconData ikon,
    String baslik,
    List<String> anahtarlar,
    Map<String, KatalogOge> katalog,
  ) {
    final ogeler = anahtarlar
        .map((a) => katalog[a])
        .whereType<KatalogOge>()
        .toList();
    if (ogeler.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bolumBasligi(ikon, baslik),
          const SizedBox(height: 10),
          // ⚠️ `Wrap` — `Row` DEGIL: 16 ozellik tek satira SIGMAZ ve `Row`
          //    RenderFlex tasma seridi cizerdi (turu 120 dersi).
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in ogeler)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: _ks.onSurface.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isletmeIkonBul(o.ikon),
                        size: 16,
                        color: _ks.primary,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        o.ad,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bolumBasligi(IconData ikon, String metin) => Row(
    children: [
      Icon(ikon, size: 17, color: _ks.onSurface.withValues(alpha: 0.75)),
      const SizedBox(width: 8),
      Text(
        metin,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: _ks.onSurface.withValues(alpha: 0.85),
        ),
      ),
    ],
  );

  /// ⚠️ Kullanici emri: *"bu bilgilerin ARKA PLAN RENGI olacak"* — her satir
  ///    kendi kutusunda.
  Widget _kart({
    required IconData ikon,
    required String etiket,
    required String deger,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: _ks.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(ikon, size: 19, color: _ks.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiket,
                      style: TextStyle(
                        fontSize: 12,
                        color: _ks.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      deger,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: _ks.onSurface.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  /// ⚠️ **YEDI GUNUN HEPSI** yazilir; bugun vurgulu.
  Widget _saatlerKarti() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: _ks.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        for (var g = 1; g <= 7; g++) _saatSatiri(g),
      ],
    ),
  );

  Widget _saatSatiri(int g) {
    final c = i.calisma.where((e) => e.gun == g).firstOrNull;
    final bugun = DateTime.now().weekday == g;
    final kapali = c == null || c.kapali;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              // ⚠️ `weekday` 1..7 -> dizi 0..6.
              _gunAd[g - 1],
              style: TextStyle(
                fontSize: 14,
                fontWeight: bugun ? FontWeight.w800 : FontWeight.w600,
                color: _ks.onSurface.withValues(alpha: bugun ? 1 : 0.6),
              ),
            ),
          ),
          Text(
            kapali ? 'Kapalı' : '${c.acilis} - ${c.kapanis}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: bugun ? FontWeight.w800 : FontWeight.w500,
              color: kapali
                  ? _ks.onSurface.withValues(alpha: 0.45)
                  : _ks.onSurface.withValues(alpha: bugun ? 1 : 0.6),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ `wa.me` ve `tel:` numarayi ISARETSIZ ister; kullanici bosluk/parantez
  ///    yazmis olabilir.
  static String _sadeTel(String t) => t.replaceAll(RegExp(r'[^0-9+]'), '');

  /// ⚠️ Kullanici sema yazmadan "gebzem.app" yazabilir; semasiz bir adres
  ///    `launchUrl`da HATA verir.
  static String _webAdresi(String w) =>
      w.startsWith('http') ? w : 'https://$w';

  static Future<void> _ac(String adres) async {
    final u = Uri.parse(adres);
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  /// ⚠️⚠️ **GOMULU HARITA YOK** (turu 176 karari): `GoogleMap` widget'i her
  ///    acilista bir **Dynamic Maps** yuklemesi demek ($7/1000). Cihazin
  ///    kendi harita uygulamasi acilir — kullanici icin ayni is, maliyet 0.
  static Future<void> _haritaAc(double lat, double lng, String ad) async {
    final etiket = Uri.encodeComponent(ad);
    final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng($etiket)');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo, mode: LaunchMode.externalApplication);
      return;
    }
    await _ac('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
  }
}

// ═══════════════════════════ YORUMLAR ═══════════════════════════════

/// ⚠️⚠️⚠️ **BU YORUMLAR MOCKUP** (kullanici emri: *"mockup guzel turkce
///" 	yorumlar olsun"*).
///
/// Projede **isletme yorumu diye bir tablo ya da uc YOK** (olculdu:
/// `backend/internal/isletme` altinda yorum/degerlendirme sorgusu yok;
/// `post_comments` GONDERI yorumudur, isletme degil).
///
/// ⚠️⚠️ Panelin EN USTUNDE bunun ornek veri oldugu ACIKCA yaziyor — sahte
/// yorumu gercekmis gibi gostermek kullaniciya YANLIS BILGI olurdu ve bu
/// proje boyle bir seyi turu 135'te (uydurma kur seridi) ve turu 176'da
/// (uydurma "ozellikler") ZATEN reddetti.
/// ⚠️ Yayin oncesi: gercek tablo + uc gelene kadar bu panel `kYorumOrnek`
///    bayragiyla kapatilabilir.
const bool kYorumOrnek = true;

typedef _Yorum = ({
  String ad,
  int yildiz,
  String zaman,
  String metin,
  int begeni,
  // ⚠️ TURU 180 — kullanici: *"yorumlarda resim de olmali"*.
  //    `0` = fotografsiz yorum; yer tutucu SAYISI kadar kare cizilir.
  //    Gercek medya YOK (yorumlar ornek kayit), bu yuzden yalniz ALAN.
  int gorsel,
});

const List<_Yorum> _ornekYorumlar = [
  (
    ad: 'Elif Yıldırım',
    yildiz: 5,
    zaman: '2 saat önce',
    metin:
        'Siparişim tam zamanında geldi, paketleme çok özenliydi. '
        'Patatesler sıcacıktı, çocuklar bayıldı. Kesinlikle tekrar '
        'sipariş vereceğim.',
    begeni: 24,
    gorsel: 2,
  ),
  (
    ad: 'Mert Kaya',
    yildiz: 4,
    zaman: '5 saat önce',
    metin:
        'Lezzet her zamanki gibi güzel ama akşam saatlerinde biraz '
        'kalabalık oluyor. Yine de personel çok ilgili, teşekkürler.',
    begeni: 11,
    gorsel: 0,
  ),
  (
    ad: 'Zeynep Arslan',
    yildiz: 5,
    zaman: 'Dün 19:40',
    metin:
        'Mekan tertemiz, masalar sürekli siliniyor. Çocuk oyun alanı '
        'olması bizim için büyük artı. Menüdeki fiyatlar da gayet uygun.',
    begeni: 37,
    gorsel: 3,
  ),
  (
    ad: 'Burak Şen',
    yildiz: 3,
    zaman: 'Dün 13:05',
    metin:
        'Yemekler güzeldi ama siparişimde bir ürün eksik çıktı. '
        'Aradığımda hemen ilgilendiler, o yüzden puanı çok düşürmedim.',
    begeni: 6,
    gorsel: 1,
  ),
  (
    ad: 'Selin Doğan',
    yildiz: 5,
    zaman: '2 gün önce',
    metin:
        'Gebze’de en sevdiğim yer. Kahvaltıya da gidiyoruz, akşam da. '
        'Personel güler yüzlü, sipariş bekleme süresi kısa.',
    begeni: 52,
    gorsel: 2,
  ),
  (
    ad: 'Ahmet Çelik',
    yildiz: 4,
    zaman: '3 gün önce',
    metin:
        'Fiyat performans olarak iyi. Otopark biraz dar ama yürüme '
        'mesafesinde park yeri bulunabiliyor.',
    begeni: 9,
    gorsel: 0,
  ),
];

Future<void> yorumlarAc(BuildContext context, {required String isletmeAd}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: kAiZemin,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => koyuSayfa(
        FractionallySizedBox(
          heightFactor: 0.95,
          child: Material(
            color: kAiZemin,
            child: _YorumPaneli(isletmeAd: isletmeAd),
          ),
        ),
      ),
    );

class _YorumPaneli extends StatefulWidget {
  const _YorumPaneli({required this.isletmeAd});

  final String isletmeAd;

  @override
  State<_YorumPaneli> createState() => _YorumPaneliDurumu();
}

class _YorumPaneliDurumu extends State<_YorumPaneli> {
  /// ⚠️ Begeni YALNIZ EKRANDA artar: sunucuda yorum tablosu YOK. Panelin
  ///    ustundeki "örnek" ibaresi bunu ACIKCA soyluyor.
  final _begenilen = <int>{};

  /// Yorum yazma alani (yerel durum).
  int _puanim = 0;
  final _yazi = TextEditingController();

  @override
  void dispose() {
    _yazi.dispose();
    super.dispose();
  }

  /// ⚠️ Gonderme ucu YOK — kullaniciya DURUSTCE soylenir.
  void _yorumYok() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Yorum gönderme henüz sunucuya bağlı değil.'),
      ),
    );
  }

  ColorScheme get _ks => kKoyuTema.colorScheme;

  double get _ortalama =>
      _ornekYorumlar.fold<int>(0, (t, y) => t + y.yildiz) /
      _ornekYorumlar.length;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _baslik(),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // ⚠️ TURU 180 — kullanici: *"yorumlarin popup'inda EN USTTE
            //    yorum yapma yeri yok, onu da ekle"*.
            _yorumYaz(),
            const SizedBox(height: 14),
            _ozet(),
            const SizedBox(height: 12),
            _aiKarti(),
            const SizedBox(height: 16),
            for (var s = 0; s < _ornekYorumlar.length; s++)
              _yorumKarti(s, _ornekYorumlar[s]),
          ],
        ),
      ),
    ],
  );

  Widget _baslik() => SizedBox(
    height: 44,
    child: Stack(
      children: [
        const Center(
          child: Text(
            'Yorumlar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.0,
              leadingDistribution: TextLeadingDistribution.even,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(LucideIcons.x, size: 22),
            ),
          ),
        ),
      ],
    ),
  );

  /// Puan ozeti + **ornek veri uyarisi**.
  /// ⚠️⚠️ TURU 180 — **YORUM YAZMA ALANI.**
  ///
  /// ⚠️ Gonderme ucu YOK (isletme yorumu icin tablo/uc yok — bkz.
  ///	`kYorumOrnek` serhi). Dugmeye basilinca kullaniciya
  ///	DURUSTCE soylenir; sessizce "gonderildi" demek yalan olurdu.
  /// ⚠️ Yildiz secimi CANLI calisir (yerel durum): tasarim boyle
  ///	degerlendirilebilsin.
  Widget _yorumYaz() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _ks.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deneyimini paylaş',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var y = 1; y <= 5; y++)
                  GestureDetector(
                    onTap: () => setState(() => _puanim = y),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        y <= _puanim
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 30,
                        color: y <= _puanim
                            ? const Color(0xFFFFB020)
                            : _ks.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _yazi,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Yorumunu yaz…',
                filled: true,
                fillColor: _ks.onSurface.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            Row(
              children: [
                // ⚠️ Fotograf ekleme de ucsuz: ayni durustluk kapisi.
                OutlinedButton.icon(
                  onPressed: _yorumYok,
                  icon: const Icon(LucideIcons.imagePlus, size: 17),
                  label: const Text('Fotoğraf'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _yorumYok,
                  child: const Text('Gönder'),
                ),
              ],
            ),
          ],
        ),
      );

  /// ⚠️ Gorseller ORNEK: gercek medya yok, yalniz ALAN cizilir (kullanici:
  ///	*"yorumlarda resim de olmali"*).
  Widget _yorumGorselleri(int adet) => SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: adet,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, _) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              color: _ks.onSurface.withValues(alpha: 0.11),
              child: Icon(
                LucideIcons.image,
                size: 24,
                color: _ks.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      );

  Widget _ozet() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _ks.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _ortalama.toStringAsFixed(1).replaceAll('.', ','),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _yildizlar(_ortalama.round(), 17),
                const SizedBox(height: 3),
                Text(
                  '${_ornekYorumlar.length} yorum',
                  style: TextStyle(
                    fontSize: 13,
                    color: _ks.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ⚠️⚠️ DURUSTLUK IBARESI — KALDIRMA. Yorumlar sunucudan GELMIYOR.
        Text(
          'Bu yorumlar tasarım amaçlı örnek kayıtlardır.',
          style: TextStyle(
            fontSize: 12,
            color: _ks.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    ),
  );

  /// Kullanici emri: *"yapay zeka tarafindan yorumlarin analizi yapildi"*.
  ///
  /// ⚠️⚠️ Metin **BU LISTEDEN TURETILIR** (ortalama + en sik gecen temalar),
  ///    bir MODEL CIKTISI DEGILDIR — ve alt satirda bu ACIKCA yaziyor.
  ///    Sahte bir "AI analizi" gostermek kullaniciya, olmayan bir yetenegi
  ///    varmis gibi anlatmak olurdu.
  Widget _aiKarti() {
    final olumlu =
        _ornekYorumlar.where((y) => y.yildiz >= 4).length;
    final oran = (olumlu / _ornekYorumlar.length * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ks.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.sparkles, size: 18, color: _ks.primary),
              const SizedBox(width: 8),
              Text(
                'Yapay zekâ özeti',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: _ks.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Yorumların %$oran’ı olumlu. Öne çıkanlar: lezzet, '
            'temizlik ve hızlı servis. En çok tekrar eden eleştiri '
            'yoğun saatlerdeki bekleme süresi.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            'Özet yorum puanlarından üretildi.',
            style: TextStyle(
              fontSize: 11.5,
              color: _ks.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yildizlar(int n, double boy) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var s = 1; s <= 5; s++)
        Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Icon(
            s <= n ? Icons.star_rounded : Icons.star_outline_rounded,
            size: boy,
            color: s <= n
                ? const Color(0xFFFFB020)
                : _ks.onSurface.withValues(alpha: 0.3),
          ),
        ),
    ],
  );

  Widget _yorumKarti(int sira, _Yorum y) {
    final begendim = _begenilen.contains(sira);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _ks.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _ks.primary.withValues(alpha: 0.25),
                  child: Text(
                    y.ad.characters.first,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        y.ad,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _yildizlar(y.yildiz, 14),
                          const SizedBox(width: 8),
                          Text(
                            y.zaman,
                            style: TextStyle(
                              fontSize: 12,
                              color: _ks.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(y.metin, style: const TextStyle(fontSize: 14, height: 1.45)),
            if (y.gorsel > 0) ...[
              const SizedBox(height: 10),
              _yorumGorselleri(y.gorsel),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _eylem(
                  ikon: begendim
                      ? Icons.thumb_up_alt
                      : Icons.thumb_up_alt_outlined,
                  metin: '${y.begeni + (begendim ? 1 : 0)}',
                  vurgulu: begendim,
                  onTap: () => setState(() {
                    begendim
                        ? _begenilen.remove(sira)
                        : _begenilen.add(sira);
                  }),
                ),
                const SizedBox(width: 6),
                _eylem(
                  ikon: LucideIcons.flag,
                  metin: 'Şikayet et',
                  onTap: () => _sikayet(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _eylem({
    required IconData ikon,
    required String metin,
    required VoidCallback onTap,
    bool vurgulu = false,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikon,
            size: 16,
            color: vurgulu
                ? _ks.primary
                : _ks.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            metin,
            style: TextStyle(
              fontSize: 13,
              fontWeight: vurgulu ? FontWeight.w700 : FontWeight.w500,
              color: vurgulu
                  ? _ks.primary
                  : _ks.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    ),
  );

  /// ⚠️ Sikayet ucu YORUM icin YOK (`/reports` `hedef_tur` serbest metin ama
  ///    yorumun bir KIMLIGI yok — ornek kayitlar). Kullaniciya durustce
  ///    soylenir; sessizce "gonderildi" demek YALAN olurdu.
  void _sikayet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kAiZemin,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => koyuSayfa(
        Material(
          color: kAiZemin,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.flag, size: 19, color: _ks.error),
                      const SizedBox(width: 9),
                      const Text(
                        'Yorumu şikayet et',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yorum şikayeti henüz sunucuya bağlı değil; bu ekrandaki '
                    'yorumlar örnek kayıtlardır.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: _ks.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(c).pop(),
                      child: const Text('Anladım'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
