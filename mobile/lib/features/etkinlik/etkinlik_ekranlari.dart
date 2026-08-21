import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/denetleyici_sahibi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../home/home_screen.dart' show myProfileProvider;
// ⚠️ TURU 114 — kart dili kategori ekraniyla ORTAK (sabitler IMPORT edilir).
// ⚠️ TURU 121 — kategori ekranlarinin ORTAK KABUGU (Yemek referansi).
import '../isletme/kategori_kabuk.dart';
import '../isletme/isletme_kart.dart' show kYanBosluk, kYaricapBuyuk, kYuzeyGri;
import '../isletme/isletme_listesi.dart' show kBosluk;
import '../randevu/randevu_servisi.dart' show kAyAdlari;
import '../medya/medya_gorsel.dart';
import '../vitrin/vitrin_slider.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import '../sosyal/medya_video.dart';
import '../sosyal/profil_sayfasi.dart';
import 'etkinlik_servisi.dart';

/// ⚠️⚠️ TURU 77 — ETKINLIK LISTESI (kullanici emri: "etkinlikler soldaki menuye
/// tikladiginda ekranda olacak").
///
/// ⚠️ IKI SEKME: YAKLASAN / GECMIS. Gecmis etkinlikler SILINMEZ (veri
///    politikasi) — yalnizca sorgu suzgecinin diger tarafi.
class EtkinlikListesiEkrani extends ConsumerStatefulWidget {
  const EtkinlikListesiEkrani({super.key});

  @override
  ConsumerState<EtkinlikListesiEkrani> createState() =>
      _EtkinlikListesiEkraniState();
}

class _EtkinlikListesiEkraniState extends ConsumerState<EtkinlikListesiEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;
  int _istekNo = 0;

  List<Etkinlik>? _liste;

  /// ⚠️ TURU 121c — buyuk kart (liste) / kucuk kart (izgara).
  bool _izgara = false;

  /// ⚠️⚠️ TURU 121c — **UCRETSIZ** suzgeci (kullanici: *"filtreler
  ///	mantiken o kategoriye gore olmali"*). Yemek`teki "Min. tutar" /
  ///	"Teslimat" cipleri etkinlikte ANLAMSIZ; etkinligin dogal
  ///	suzgecleri ZAMAN, KATEGORI ve UCRET`tir.
  /// ⚠️ Sunucuda ucret suzgeci YOK -> **ISTEMCIDE** suzuluyor. Bu durust:
  ///    liste zaten tek istekte geliyor ve sayfalama yok.
  bool _ucretsiz = false;
  String? _hata;
  String _kategori = '';
  bool _gecmis = false;
  bool _benim = false;

  /// ⚠️⚠️ TURU 78b — ZAMAN HIZLI KARTLARI ('' | 'bugun' | 'haftasonu').
  ///    Sunucudaki `bas_min`/`bas_maks` suzgecleri turu 77'den beri VARDI ama
  ///    ONLARI CAGIRAN HICBIR EKRAN YOKTU (denetim: olu yetenek). Kullanicinin
  ///    istedigi "kucuk kartlar"in etkinlik karsiligi budur.
  String _zaman = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  /// Secili zaman kartinin [baslangic, bitis) araligi. Kart yoksa (null, null).
  ///
  /// ⚠️ YEREL saatle hesaplanir (kullanicinin "bugün"u kendi gunudur); servis
  ///    katmani UTC'ye cevirip gonderir.
  /// ⚠️ "Bu hafta sonu" = gelecek CUMARTESI 00:00 -> PAZARTESI 00:00. Bugun
  ///    zaten hafta sonuysa BUGUNDEN baslar (gecmis saatler zaten elenir).
  (DateTime?, DateTime?) get _zamanAraligi {
    final s = DateTime.now();
    final bugun = DateTime(s.year, s.month, s.day);
    if (_zaman == 'bugun') {
      return (bugun, bugun.add(const Duration(days: 1)));
    }
    if (_zaman == 'haftasonu') {
      // DateTime.saturday = 6, sunday = 7
      final cumarteyeKalan = (DateTime.saturday - s.weekday) % 7;
      final cmt = bugun.add(Duration(days: cumarteyeKalan));
      final bas = cumarteyeKalan == 0 || s.weekday == DateTime.sunday
          ? bugun
          : cmt;
      // Pazar gunundeysek bitis YARIN, degilse cumartesiden 2 gun sonra.
      final bitis = s.weekday == DateTime.sunday
          ? bugun.add(const Duration(days: 1))
          : cmt.add(const Duration(days: 2));
      return (bas, bitis);
    }
    return (null, null);
  }

  Future<void> _yukle() async {
    final jeton = ++_istekNo;
    final (basMin, basMaks) = _zamanAraligi;
    try {
      final l = await ref
          .read(etkinlikServisiProvider)
          .liste(
            kategori: _kategori,
            q: _arama.text.trim(),
            gecmis: _gecmis,
            benim: _benim,
            basMin: basMin,
            basMaks: basMaks,
          );
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() => _hata = 'Etkinlikler alınamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️⚠️ TURU 121c — "Ücretsiz" cipi GERCEKTEN SUZUYOR.
    //	Cipi cizip listeye uygulamamak, bu projede DOKUZ kez sahaya cikan
    //	"olu ozellik" sinifi olurdu: kullanici dokunur, sayi degismez ve
    //	suzgecin bozuk oldugunu sanir.
    // ⚠️ Suzme ISTEMCIDE: sunucuda ucret parametresi YOK ve liste tek
    //    istekte, sayfalamasiz geliyor — yani sayilar tutarli kalir.
    final ham = _liste;
    final l = (ham == null || !_ucretsiz)
        ? ham
        : ham.where((e) => e.ucretsiz || e.fiyatKurus <= 0).toList();
    // ⚠️⚠️ TURU 121 — **AppBar + Column KALDIRILDI**, Yemek ekranindaki
    //	kabuk kullaniliyor: 44 dp sabit header · `AltMenu` ·
    //	`CustomScrollView` (kullanici emri: *"diger tum kategoriler AYNI
    //	MANTIKTA olacak"*).
    // ⚠️⚠️ `Column` + `Expanded` YAPISI BILEREK BIRAKILDI: slider + arama +
    //	segment + iki cip seridi SABIT dikey butce yiyordu ve 360x640`ta
    //	listeye cok az yer kaliyordu — turu 93b`de kategori ekraninda
    //	OLCULEN sinifin aynisi. Artik hepsi LISTENIN PARCASI (sliver).
    return KategoriKabugu(
      baslik: 'Etkinlikler',
      sagIkon: _benim ? LucideIcons.users : LucideIcons.userRound,
      sagIpucu: _benim ? 'Tüm etkinlikler' : 'Benim etkinliklerim',
      sagBasildi: () {
        setState(() => _benim = !_benim);
        _yukle();
      },
      onYenile: _yukle,
      altDugme: FloatingActionButton.extended(
        heroTag: 'fabEtkinlikOlustur',
        onPressed: () async {
          final id = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const EtkinlikOlusturEkrani()),
          );
          if (id != null) _yukle();
        },
        icon: const Icon(LucideIcons.plus),
        label: const Text('Etkinlik oluştur'),
      ),
      slivers: [
          kabukBosluk(kBosluk - 10),
          // ⚠️ Arama KABUKTAN (Yemek ile birebir): 48 dp, notr kenarlik,
          //    kalinlastirilmis ikon, dolu iken temizle (X) dairesi.
          //    Onceki hal radius 24`lu, X`siz, 12 dp yan dolgulu AYRI bir
          //    kutuydu.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
            sliver: SliverToBoxAdapter(
              child: kabukArama(
                context: context,
                controller: _arama,
                ipucu: 'Ne Aramıştın?',
                onChanged: (_) {
                  setState(() {});
                  _gecikme?.cancel();
                  _gecikme = Timer(
                    const Duration(milliseconds: 320),
                    _yukle,
                  );
                },
              ),
            ),
          ),
          kabukBosluk(),
          // ---- UST VITRIN (yaklasan etkinlikler). Bos ise CIZILMEZ.
          const SliverToBoxAdapter(
            child: VitrinSlider(dikey: 'etkinlik'),
          ),
          kabukBosluk(),
          // ⚠️ "Yaklaşan / Geçmiş" artik CIP SERIDI (kabuk dili).
          //    `SegmentedButton` Material varsayilani, bu ekranda TEK
          //    basina duruyordu ve kategori ekranlarinin diline yabanciydi.
          SliverToBoxAdapter(
            child: kabukCipSeridi(context, [
              KabukCip('Yaklaşan', LucideIcons.calendarClock, !_gecmis, () {
                setState(() => _gecmis = false);
                _yukle();
              }),
              KabukCip('Geçmiş', LucideIcons.history, _gecmis, () {
                setState(() => _gecmis = true);
                _yukle();
              }),
            ]),
          ),
          // ⚠️ TURU 121 — iki cip seridi arasi nefes: yapisik durduklarinda
          //    tek bir sarmis serit gibi okunuyordu (emulatorde goruldu).
          kabukBosluk(6),
          // ---- ZAMAN HIZLI KARTLARI (turu 78b: `bas_min`/`bas_maks` CANLI)
          // ⚠️ YALNIZ "Yaklaşan" sekmesinde: gecmis etkinliklerde "Bugün"
          //    suzgeci mantiksal olarak BOS sonuc uretirdi.
          if (!_gecmis)
            SliverToBoxAdapter(
              child: kabukCipSeridi(context, [
                KabukCip('Bugün', LucideIcons.calendarDays,
                    _zaman == 'bugun', () => _zamanSec('bugun')),
                KabukCip('Bu hafta sonu', LucideIcons.calendarRange,
                    _zaman == 'haftasonu', () => _zamanSec('haftasonu')),
              ]),
            ),
          kabukBosluk(kBosluk - 4),
          // ⚠️ Kategori seridi de KUTU DILINDE degil CIP dilinde: bu ekranda
          //    kategori GORSELI yok, kutu bos kalirdi.
          SliverToBoxAdapter(
            child: kabukCipSeridi(context, [
              KabukCip('Tümü', LucideIcons.layoutGrid, _kategori.isEmpty,
                  () => _kategoriSec('')),
              // ⚠️ ETKINLIGE OZEL: ucretsiz etkinlikler. Suzgec ISTEMCIDE
              //    (sunucuda ucret parametresi YOK) — liste tek istekte
              //    geliyor ve sayfalama yok, yani durust bir suzgec.
              KabukCip('Ücretsiz', LucideIcons.ticket, _ucretsiz,
                  () => setState(() => _ucretsiz = !_ucretsiz)),
              for (final e in etkinlikKategorileri.entries)
                KabukCip(e.value, LucideIcons.tag, _kategori == e.key,
                    () => _kategoriSec(e.key)),
            ]),
          ),
          kabukBosluk(kBosluk - 4),
          // ⚠️ Liste basligi Yemek ekranindaki ile AYNI (17/w700 + sayi) ve
          //    saginda BUYUK/KUCUK KART secicisi.
          if (l != null && l.isNotEmpty)
            SliverToBoxAdapter(
              child: kabukBolumBasligi(
                context,
                'Etkinlikler (${l.length})',
                sag: KabukGorunumSecici(
                  izgara: _izgara,
                  onSec: (v) => setState(() => _izgara = v),
                ),
              ),
            ),
          if (_hata != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    _hata!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            )
          else if (l == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (l.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(30),
                // TURU 121c — DORDUNCU DAL: "suzgec bosaltti".
                // Onceki metin bir suzgec acikken de "Yaklasan etkinlik yok,
                // ILK ETKINLIGI SEN OLUSTUR" diyordu; oysa etkinlik VARDI,
                // yalnizca (ornegin) "Ucretsiz" cipi hepsini elemisti. Bu,
                // kullaniciya YANLIS BILGI vermekti ve kurtarma yolu da
                // yoktu (turu 93b/106 ile ayni sinif).
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _suzgecVar
                          ? 'Seçtiğin filtrelere uyan etkinlik bulunamadı.'
                          : _gecmis
                          ? 'Geçmiş etkinlik yok.'
                          : 'Yaklaşan etkinlik yok.\nİlk etkinliği sen oluştur!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (_suzgecVar)
                      TextButton(
                        onPressed: _filtreleriTemizle,
                        child: const Text('Filtreleri temizle'),
                      ),
                  ],
                ),
              ),
            )
          else if (_izgara)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
              sliver: SliverGrid(
                // Hucre yuksekligi ICERIKTEN turetilir (kapak + ad + tek
                // bilgi satiri); bkz. kabukIzgaraOlcu serhi.
                gridDelegate: kabukIzgaraOlcu(context),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _izgaraKarti(l[i]),
                  childCount: l.length,
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: l.length,
              itemBuilder: (_, i) => _kart(l[i]),
            ),
          // ⚠️ FAB payi: son kartin "Etkinlik oluştur" dugmesinin altinda
          //    kalmasini onler (turu 90b dersi).
          kabukBosluk(90),
      ],
    );
  }

  /// Bir suzgec acik mi? ("Filtreleri temizle" dugmesi buna bagli.)
  ///
  /// Arama metni DAHIL DEGIL: o zaten arama kutusunda GORUNUR ve temizleme
  /// yolu (X) orada duruyor. Cipler ise liste bosalinca ekranin gorunen
  /// kismindan kaymis olabilir.
  bool get _suzgecVar =>
      _kategori.isNotEmpty || _zaman.isNotEmpty || _ucretsiz || _gecmis;

  void _filtreleriTemizle() {
    setState(() {
      _kategori = '';
      _zaman = '';
      _ucretsiz = false;
      _gecmis = false;
    });
    _yukle();
  }

  /// ⚠️⚠️ TURU 121c — **KUCUK KART** (izgara gorunumu).
  ///
  /// Buyuk kartla AYNI iskelet, DAHA AZ satir: kapak + tarih rozeti -> ad
  /// -> tek satir zaman. Katilimci sayaci ve kategori cipi DUSURULDU —
  /// yarim genislikte okunmuyorlardi.
  Widget _izgaraKarti(Etkinlik e) => InkWell(
    borderRadius: BorderRadius.circular(kYaricapBuyuk),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(etkinlik: e)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(kYaricapBuyuk),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                e.mediaIds.isEmpty
                    ? ColoredBox(color: kYuzeyGri(context))
                    : KapakGorseli(
                        mediaIds: e.mediaIds,
                        mediaKinds: e.mediaKinds,
                        kucuk: true,
                      ),
                // ⚠️ Tarih rozeti KUCUK KARTTA DA kalir: etkinligin en
                //    onemli bilgisi tarihtir.
                if (e.baslangic != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${e.baslangic!.toLocal().day}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            kAyAdlari[e.baslangic!.toLocal().month - 1]
                                .substring(0, 3),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          e.baslik,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          etkinlikZamani(e.baslangic),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.62),
          ),
        ),
      ],
    ),
  );

  /// ⚠️ TEK SECIM: ikincisine basmak oncekini kapatir (iki tarih araligi
  ///    kesistiginde bos sonuc uretip "etkinlik yok" sanisina dusururdu).
  void _zamanSec(String anahtar) {
    setState(() => _zaman = _zaman == anahtar ? '' : anahtar);
    _yukle();
  }

  void _kategoriSec(String anahtar) {
    setState(() => _kategori = anahtar);
    _yukle();
  }

  /// ⚠️⚠️⚠️ TURU 114 — ETKINLIK KARTI **"YEMEK" KART DILINDE** (kullanici
  ///	emirleri: *"etkinlikler daha modern ve detayli olsun"* + *"hepsi
  ///	yemek mantiginda olsun"*).
  ///
  /// Degisenler:
  ///  · `Card` (golge + kendi kenar payi) KALDIRILDI -> kategori
  ///    ekranindaki gibi `kYanBosluk` yan payi + `ClipRRect(kYaricapBuyuk)`.
  ///  · Kapak **HER ZAMAN** cizilir: medya yoksa `kYuzeyGri` yuzey. Eskiden
  ///    medyasiz etkinlik kapaksiz cikiyor ve liste "delik deşik" duruyordu.
  ///  · Kapagin uzerine **TARIH ROZETI** (gun + ay). Etkinligin en onemli
  ///    bilgisi tarihtir ve metin satirinda kayboluyordu.
  ///  · `Colors.grey` -> temadan (`onSurface` alfa). `Colors.grey` acik
  ///    temada zeminle **2.40:1** kontrast veriyordu (turu 113 denetiminde
  ///    olculdu; 12 px metin icin 4.5:1 gerekiyor).
  ///  · Alt satir `Flexible` ile korunuyor: kategori adi uzun + yazi olcegi
  ///    1.3 iken eski `Row` TASIYORDU.
  Widget _kart(Etkinlik e) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurface.withValues(alpha: 0.62);
    final yer = [
      e.konum,
      e.ilce,
      e.il,
    ].where((s) => s.isNotEmpty).join(', ');

    Widget meta(IconData ikon, String metin) => Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(ikon, size: 14, color: soluk),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              metin,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: soluk),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 0, kYanBosluk, 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(kYaricapBuyuk),
        onTap: () async {
          final degisti = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => EtkinlikDetayEkrani(etkinlik: e)),
          );
          if (!mounted) return;
          // ⚠️ Silme/katilim degistiyse listeyi SUNUCUDAN tazele; salt
          //    `setState` bayat nesneyi yeniden cizerdi.
          if (degisti == true) {
            _yukle();
          } else {
            setState(() {});
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(kYaricapBuyuk),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (e.mediaIds.isNotEmpty)
                      // ⚠️ TEK KAYNAK (bkz. `KapakGorseli` serhi): ilk
                      //    FOTOGRAF secilir; yalniz-video etkinlikte INDIRME
                      //    YAPMADAN yer tutucu cizer.
                      KapakGorseli(
                        mediaIds: e.mediaIds,
                        mediaKinds: e.mediaKinds,
                        kucuk: false,
                      )
                    else
                      ColoredBox(color: kYuzeyGri(context)),
                    // ---- TARIH ROZETI
                    // ⚠️ `Etkinlik.baslangic` **NULLABLE** (sunucudan bozuk
                    //    tarih gelirse `tryParse` null doner). Rozet yalniz
                    //    tarih VARSA cizilir — aksi halde "null Oca" gibi
                    //    bir sey yazmak yerine HIC cizmemek dogru.
                    if (e.baslangic != null)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          // ⚠️ Kapak fotografi HER RENKTE olabilir; rozet
                          //    KOYU zemin + BEYAZ yazi ile her kapakta
                          //    okunur kalir (temaya baglanamaz).
                          color: Colors.black.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${e.baslangic!.day}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                            Text(
                              kAyAdlari[e.baslangic!.month - 1]
                                  .substring(0, 3),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              e.baslik,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            meta(LucideIcons.calendar, etkinlikZamani(e.baslangic)),
            if (yer.isNotEmpty) meta(LucideIcons.mapPin, yer),
            const SizedBox(height: 8),
            Row(
              children: [
                // ⚠️⚠️ TURU 114 (denetim) — cip ve fiyat **TEK BIR
                //	`Flexible` icinde**. Ilk yazimda ikisi AYRI `Flexible`
                //	idi ve yanlarinda `Spacer` vardi; Flutter bos alani
                //	flex faktorlerine gore UCE bolduyor, yani `Spacer`
                //	yalnizca 1/3'unu aliyor ve katilimci sayisi saga TAM
                //	dayanmiyordu. Simdi bos alanin TAMAMI `Spacer`in.
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tema.colorScheme.onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      e.kategoriAd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    e.fiyatMetni,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(LucideIcons.users, size: 14, color: soluk),
                const SizedBox(width: 4),
                Text(
                  '${e.katilanSayisi}'
                  '${e.kontenjan > 0 ? "/${e.kontenjan}" : ""}',
                  style: TextStyle(fontSize: 12, color: soluk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Etkinlik detayi + KATILIM.
class EtkinlikDetayEkrani extends ConsumerStatefulWidget {
  const EtkinlikDetayEkrani({super.key, required this.etkinlik});
  final Etkinlik etkinlik;

  @override
  ConsumerState<EtkinlikDetayEkrani> createState() =>
      _EtkinlikDetayEkraniState();
}

class _EtkinlikDetayEkraniState extends ConsumerState<EtkinlikDetayEkrani> {
  late Etkinlik e = widget.etkinlik;
  bool _mesgul = false;

  /// Galeri sayfa gostergesi (karma medya).
  int _sayfa = 0;

  /// ⚠️ TURU 78 — KADRO (sahnedekiler). `null` = henuz yuklenmedi.
  List<Kadro>? _kadro;

  @override
  void initState() {
    super.initState();
    _kadroYukle();
  }

  Future<void> _kadroYukle() async {
    try {
      final k = await ref.read(etkinlikServisiProvider).kadro(e.id);
      if (mounted) setState(() => _kadro = k);
    } catch (_) {
      // ⚠️ SESSIZ: kadro alinamamasi etkinlik detayini BLOKLAMAMALI.
      //    Bos liste cizilir, ozellik yokmus gibi gorunur — kabul edilebilir.
      if (mounted) setState(() => _kadro = const []);
    }
  }

  /// ⚠️ TURU 78 — DUZENLEME. Ayri ekran YOK: "Etkinlik oluştur" ekrani
  ///    `etkinlik:` parametresiyle duzenleme modunda acilir (tek kaynak).
  Future<void> _duzenle() async {
    final degisti = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EtkinlikOlusturEkrani(etkinlik: e)),
    );
    if (degisti != true || !mounted) return;
    // ⚠️ `Etkinlik` modelinin alanlari cogunlukla `final` — yerel yamalama
    //    yapilamaz, SUNUCUDAN taze nesne alinir.
    try {
      final yeni = await ref.read(etkinlikServisiProvider).detay(e.id);
      if (!mounted) return;
      setState(() => e = yeni);
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Etkinlik güncellendi')),
      );
    } catch (_) {
      // Guncelleme SUNUCUDA basarili oldu; yalniz tazeleme patladi.
      // ⚠️ Kullaniciya "guncellenemedi" DEMEK YANLIS olurdu.
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _katil(String durum) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    // ⚠️ IYIMSER GUNCELLEME + HATA'DA GERI ALMA (kart/gonderi ile ayni desen).
    final eskiDurum = e.benimDurumum;
    final eskiSayi = e.katilanSayisi;
    setState(() {
      e.benimDurumum = durum;
      if (durum == 'katiliyor' && eskiDurum != 'katiliyor') {
        e.katilanSayisi++;
      } else if (durum != 'katiliyor' && eskiDurum == 'katiliyor') {
        e.katilanSayisi = (e.katilanSayisi - 1).clamp(0, 1 << 30);
      }
    });
    try {
      await ref.read(etkinlikServisiProvider).katil(e.id, durum);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        e.benimDurumum = eskiDurum;
        e.katilanSayisi = eskiSayi;
      });
      // ⚠️ Sunucunun mesaji AYNEN gosterilir ("kontenjan doldu" gibi) —
      //    sessiz basarisizlik YASAK.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(err))));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Etkinlik kaldırılsın mı?'),
        content: const Text('Katılımcılar artık göremez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await ref.read(etkinlikServisiProvider).sil(e.id);
      // ⚠️ TURU 77b — SONUC DONDURULUR. Eskiden ciplak pop vardi ve liste
      //    yalniz setState yapip YENIDEN YUKLEMIYORDU: kullanici "kaldırdım
      //    ama listede duruyor" gorup tekrar basiyor, sunucu 404 donuyor ve
      //    ekranda "Kaldırılamadı" yaziyordu (oysa ZATEN kaldirilmisti).
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kaldırılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final benimId = (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '')
        .toString();
    final benimEtkinligim = e.olusturanId == benimId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik'),
        actions: [
          // ⚠️⚠️ TURU 78 — "Düzenle" GIRISI. Sunucu ucu ve ekran yazilip
          //    hicbir dugmeye baglanmasaydi ozellik ULASILAMAZ olurdu; bu
          //    projede "olu dogmus ozellik" hatasi BES kez tekrarladi.
          if (benimEtkinligim)
            IconButton(
              tooltip: 'Düzenle',
              icon: const Icon(LucideIcons.pencil),
              onPressed: _duzenle,
            ),
          if (benimEtkinligim)
            IconButton(icon: const Icon(LucideIcons.trash2), onPressed: _sil),
        ],
      ),
      body: ListView(
        children: [
          // ⚠️⚠️ TURU 78b — KARMA GALERI (denetim bulgusu). Detay TEK bir
          //    `MedyaGorsel` ciziyordu: coklu medya EKLENEBILIYOR ama YALNIZ
          //    ILKI gorunuyordu, ustelik o ilk medya VIDEO ise KIRIK GORSEL
          //    cizilirdi. Ilan detayindaki galeriyle AYNI yapi kullanildi.
          if (e.mediaIds.isNotEmpty)
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    itemCount: e.mediaIds.length,
                    onPageChanged: (p) => setState(() => _sayfa = p),
                    itemBuilder: (_, k) {
                      final tur = k < e.mediaKinds.length
                          ? e.mediaKinds[k]
                          : 'image';
                      if (tur == 'yok') {
                        return const ColoredBox(
                          color: Color(0xFF14101C),
                          child: Center(
                            child: Text(
                              'Bu içerik kaldırıldı',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        );
                      }
                      if (tur == 'video') {
                        // ⚠️⚠️ `otoOynat: false` + `sesli: false` ZORUNLU:
                        //    iOS'ta ses oturumu PROSES GENELINDE TEKTIR ve
                        //    kendiliginden calan bir video SUREN ARAMAYI
                        //    SAGIRLASTIRIR (turu 64/65/73).
                        return MedyaVideo(
                          mediaId: e.mediaIds[k],
                          otoOynat: false,
                          sesli: false,
                          // ⚠️ TURU 78b — ilan galerisiyle AYNI gerekce:
                          //    varsayilan `true` sonsuz donguye sokuyordu.
                          dongu: false,
                          dolgu: BoxFit.cover,
                        );
                      }
                      return MedyaGorsel(
                        mediaId: e.mediaIds[k],
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                  if (e.mediaIds.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${_sayfa + 1}/${e.mediaIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.baslik,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _satir(LucideIcons.calendar, etkinlikZamani(e.baslangic)),
                if (e.bitis != null)
                  _satir(
                    LucideIcons.clock,
                    'Bitiş: ${etkinlikZamani(e.bitis)}',
                  ),
                if ([e.konum, e.ilce, e.il].any((s) => s.isNotEmpty))
                  _satir(
                    LucideIcons.mapPin,
                    [
                      e.konum,
                      e.ilce,
                      e.il,
                    ].where((s) => s.isNotEmpty).join(', '),
                  ),
                _satir(LucideIcons.tag, e.kategoriAd),
                _satir(LucideIcons.ticket, e.fiyatMetni),
                _satir(
                  LucideIcons.users,
                  e.kontenjan > 0
                      ? '${e.katilanSayisi} / ${e.kontenjan} katılımcı'
                      : '${e.katilanSayisi} katılımcı',
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(
                    ad: e.olusturanAd,
                    mediaId: e.olusturanAvatarMediaId,
                    cap: 40,
                  ),
                  title: Text(e.olusturanAd),
                  subtitle: const Text('Düzenleyen'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: e.olusturanId),
                    ),
                  ),
                ),
                if (e.aciklama.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(e.aciklama, style: const TextStyle(fontSize: 15)),
                ],
                _kadroBolumu(benimEtkinligim),
                const SizedBox(height: 26),
                // ⚠️ GECMIS etkinlikte katilim dugmesi CIZILMEZ — basmanin
                //    anlami yok ve kullaniciyi yaniltir.
                if (!e.gecmisMi && !benimEtkinligim) _katilimDugmeleri(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️⚠️ TURU 78 — KADRO (oyuncu / sarkici / konusmaci).
  ///
  /// ⚠️ "Kadro" ile "katilimci" AYRI kavramlar: kadro SAHNEDEKILER, katilim
  ///    RSVP'dir. Ayni listede gosterilmeleri kullaniciyi yanilturdi.
  /// ⚠️ Kadro BOSSA ve etkinlik BENIM DEGILSE bolum HIC CIZILMEZ — bos bir
  ///    "Sahnede" basligi ozelligin var oldugunu ama kullanilmadigini
  ///    dusundururdu.
  Widget _kadroBolumu(bool benimEtkinligim) {
    final k = _kadro;
    if (k == null) return const SizedBox.shrink();
    if (k.isEmpty && !benimEtkinligim) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Row(
          children: [
            const Text(
              'Sahnede',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (benimEtkinligim)
              TextButton.icon(
                onPressed: _kadroEkleSor,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Ekle'),
              ),
          ],
        ),
        if (k.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Sanatçı, oyuncu ya da konuşmacı ekleyebilirsin.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        for (final kisi in k)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            // ⚠️ Kayitli kisi KENDI avatarini kullanir (medya dali (b) zaten
            //    herkese acik); kayitsiz kisi HARF avatari alir. Kadroya ayri
            //    fotograf alani EKLENMEDI — yeni bir medya sutunu
            //    `erisebilir()` icine yeni dal gerektirirdi ve o dal
            //    unutuldugunda medya yukleyenden baska herkese 403 donerdi.
            leading: Avatar(
              ad: kisi.ad,
              mediaId: kisi.avatarMediaId,
              avatarUrl: '',
              cap: 38,
            ),
            title: Text(kisi.ad),
            subtitle: kisi.rol.isEmpty ? null : Text(kisi.rol),
            // ⚠️ Kayitliysa profiline BAGLANIR; degilse dokunulamaz (olu
            //    dokunus alani birakmiyoruz).
            onTap: kisi.userId == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProfilSayfasi(userId: kisi.userId!),
                    ),
                  ),
            trailing: benimEtkinligim
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 17),
                    onPressed: () => _kadroSil(kisi),
                  )
                : null,
          ),
      ],
    );
  }

  Future<void> _kadroEkleSor() async {
    final ad = TextEditingController();
    final rol = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [ad, rol],
        child: AlertDialog(
        title: const Text('Sahneye ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ad,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'İsim',
                counterText: '',
              ),
            ),
            TextField(
              controller: rol,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Rol (sanatçı, oyuncu, DJ...)',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ekle'),
          ),
        ],
        ),
      ),
    );
    // ⚠️ Metin SENKRON okunur: route hala cikis animasyonunda, denetleyici
    //    CANLI. DenetleyiciSahibi birakmayi kendisi yapar.
    final isim = ad.text.trim();
    final gorev = rol.text.trim();
    if (onay != true || isim.isEmpty || !mounted) return;
    try {
      // ⚠️ `userId` GONDERILMIYOR: kadroya yazilan kisi genelde uygulamaya
      //    KAYITLI DEGIL (unlu bir sanatci). Kayitli kisiyi baglamak icin
      //    ayri bir "kullanici ara" akisi gerekir — o AYRI BIR IS.
      await ref
          .read(etkinlikServisiProvider)
          .kadroEkle(e.id, ad: isim, rol: gorev);
      await _kadroYukle();
    } catch (err) {
      if (!mounted) return;
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(err))),
      );
    }
  }

  Future<void> _kadroSil(Kadro kisi) async {
    try {
      await ref.read(etkinlikServisiProvider).kadroSil(e.id, kisi.id);
      await _kadroYukle();
    } catch (err) {
      if (!mounted) return;
      // ⚠️ Sessiz basarisizlik YASAK: kullanici sildigini sanmasin.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(err))),
      );
    }
  }

  Widget _katilimDugmeleri() {
    final katiliyor = e.benimDurumum == 'katiliyor';
    final ilgileniyor = e.benimDurumum == 'ilgileniyor';
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: (_mesgul || (e.kontenjanDoldu && !katiliyor))
                ? null
                : () => _katil(katiliyor ? 'vazgecti' : 'katiliyor'),
            icon: Icon(
              katiliyor ? LucideIcons.check : LucideIcons.userPlus,
              size: 18,
            ),
            label: Text(
              katiliyor
                  ? 'Katılıyorsun'
                  : (e.kontenjanDoldu ? 'Kontenjan doldu' : 'Katıl'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: _mesgul
              ? null
              : () => _katil(ilgileniyor ? 'vazgecti' : 'ilgileniyor'),
          icon: Icon(
            ilgileniyor ? LucideIcons.star : LucideIcons.starOff,
            size: 18,
          ),
          label: const Text('İlgileniyorum'),
        ),
      ],
    );
  }

  Widget _satir(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(metin, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );
}

/// Etkinlik olustur.
/// Etkinlik olustur **VE** duzenle — **TEK EKRAN**.
///
/// ⚠️⚠️ TURU 78 — AYRI "EtkinlikDuzenleEkrani" YAZILMADI. Iki ekran olsaydi
///    dogrulama, tarih secici, medya yonetimi ve fiyat/kontenjan mantigi IKI
///    KOPYA olurdu; bu projede "ayni kuralin iki kopyasi DRIFT eder" hatasi
///    ALTI kez tekrarladi. [etkinlik] doluysa DUZENLEME modu.
class EtkinlikOlusturEkrani extends ConsumerStatefulWidget {
  const EtkinlikOlusturEkrani({super.key, this.etkinlik});

  /// Doluysa DUZENLEME modu.
  final Etkinlik? etkinlik;

  @override
  ConsumerState<EtkinlikOlusturEkrani> createState() =>
      _EtkinlikOlusturEkraniState();
}

class _EtkinlikOlusturEkraniState extends ConsumerState<EtkinlikOlusturEkrani> {
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();
  final _konum = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _fiyat = TextEditingController();
  final _kontenjan = TextEditingController();

  String _kategori = 'konser';
  DateTime _baslangic = DateTime.now().add(const Duration(days: 1));

  /// ⚠️ TURU 78 — BITIS. Sutun 029'dan beri VARDI ve detay ekrani onu
  ///    CIZIYORDU, ama forma HIC KONULMAMISTI: yani "Bitiş: …" satiri sahada
  ///    ASLA gorunmuyordu (olu ozellik, bu projede besinci tekrar).
  DateTime? _bitis;

  bool _ucretsiz = true;

  /// ⚠️ TURU 78 — COKLU MEDYA. Onceden TEK gorsel (`File? _gorsel`) vardi;
  ///    sunucu ZATEN 10 medya kabul ediyordu. Kullanici emri: "etkinlikte de
  ///    gorsel ve videolar olacak".
  final List<File> _gorseller = [];
  final List<File> _videolar = [];

  /// DUZENLEMEDE: sunucuda ZATEN duran medya id'leri (silinebilir).
  final List<String> _mevcutMedya = [];

  /// ⚠️⚠️ TURU 78b — `_mevcutMedya[k]` ile **AYNI SIRADA** tur bilgisi
  ///    (ilan ekranindaki ile birebir ayni gerekce: video id'si `MedyaGorsel`e
  ///    verilirse KIRIK GORSEL cizilir ve kullanici videosunu silebilir).
  /// ⚠️ IKI LISTE **BIRLIKTE** degisir.
  final List<String> _mevcutTurler = [];

  static const _enFazlaMedya = 10;
  static const _enFazlaVideo = 2;

  /// ⚠️ Gonderi/ilan tarafiyla AYNI tavan — yeni bir sure siniri UYDURULMADI.
  static const _videoSuresiTavani = Duration(minutes: 5);

  bool _kaydediliyor = false;

  bool get _duzenleme => widget.etkinlik != null;

  @override
  void initState() {
    super.initState();
    final e = widget.etkinlik;
    if (e == null) return;
    _baslik.text = e.baslik;
    _aciklama.text = e.aciklama;
    _kategori = etkinlikKategorileri.containsKey(e.kategori)
        ? e.kategori
        : 'diger';
    if (e.baslangic != null) _baslangic = e.baslangic!;
    _bitis = e.bitis;
    _konum.text = e.konum;
    _il.text = e.il;
    _ilce.text = e.ilce;
    _ucretsiz = e.ucretsiz;
    if (!e.ucretsiz && e.fiyatKurus > 0) {
      final tl = e.fiyatKurus / 100;
      _fiyat.text = tl == tl.roundToDouble()
          ? tl.round().toString()
          : tl.toStringAsFixed(2);
    }
    if (e.kontenjan > 0) _kontenjan.text = e.kontenjan.toString();
    _mevcutMedya.addAll(e.mediaIds);
    // ⚠️⚠️ TURU 78b — TUR BILGISI DE TASINIR (eskiden `e.mediaKinds` ATILIYORDU).
    for (var k = 0; k < e.mediaIds.length; k++) {
      _mevcutTurler.add(k < e.mediaKinds.length ? e.mediaKinds[k] : 'image');
    }
  }

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _konum.dispose();
    _il.dispose();
    _ilce.dispose();
    _fiyat.dispose();
    _kontenjan.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    // ⚠️ DONANIM KAPISI: arama/oda/yayin surerken kamera acmak iOS'ta
    //    paylasilan `videoCapturer`i calar (turu 50 kok nedeni).
    if (!MedyaKapisi.izinVer(ref)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez',
          ),
        ),
      );
      return;
    }
    // ⚠️ TEK KAYNAK: `limit < 2` tuzagi + `take(kalan)` kirpmasi orada.
    //    Dogrudan `pickMultiImage` cagrilsaydi tavanin BIR ALTINDA dugme
    //    SESSIZCE olurdu (turu 77b bulgusu).
    final kalan =
        _enFazlaMedya -
        _mevcutMedya.length -
        _gorseller.length -
        _videolar.length;
    if (kalan <= 0) {
      _uyar('En fazla $_enFazlaMedya medya eklenebilir');
      return;
    }
    final secim = await MedyaSecici.coklu(kalan);
    if (secim.isEmpty || !mounted) return;
    setState(() => _gorseller.addAll(secim.map((x) => File(x.path))));
  }

  /// ⚠️ TURU 78 — ETKINLIGE VIDEO. Boyut + SURE kapisi `MedyaSecici.video`
  ///    icinde (ilan ve gonderi ile AYNI tek kaynak).
  Future<void> _videoSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    if (_videolar.length >= _enFazlaVideo) {
      _uyar('En fazla $_enFazlaVideo video eklenebilir');
      return;
    }
    if (_mevcutMedya.length + _gorseller.length + _videolar.length >=
        _enFazlaMedya) {
      _uyar('En fazla $_enFazlaMedya medya eklenebilir');
      return;
    }
    final dosya = await MedyaSecici.video(
      sureTavani: _videoSuresiTavani,
      uyar: _uyar,
      ref: ref,
    );
    if (dosya == null || !mounted) return;
    setState(() => _videolar.add(dosya));
  }

  /// ⚠️ Kok messenger: bu ekran bir alt-sayfadan acilmis olabilir.
  void _uyar(String m) {
    rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _tarihSec() async {
    // ⚠️⚠️ TURU 78 — ÇÖKME DÜZELTMESİ (araştırma bulgusu).
    //    `showDatePicker` `initialDate`in [firstDate, lastDate] ARALIĞINDA
    //    olmasını ASSERTION ile şart koşar. Sınırlar `DateTime.now()`a sabitti;
    //    GEÇMİŞ bir etkinlik düzenlenirken `initialDate < firstDate` olur ve
    //    ekran ASSERTION ile ÇÖKER. Aynı sınıf `lastDate` için de geçerli
    //    (2 yıldan uzak vadeli etkinlik).
    //    FIX: sınırlar mevcut değeri DE kapsayacak şekilde genişletilir.
    //    ⚠️ YAPMA: sınırları tekrar yalnız `now()`a bağlama.
    final simdi = DateTime.now();
    var ilk = simdi.subtract(const Duration(days: 1));
    var son = simdi.add(const Duration(days: 730));
    if (_baslangic.isBefore(ilk)) ilk = _baslangic;
    if (_baslangic.isAfter(son)) son = _baslangic;
    final g = await showDatePicker(
      context: context,
      initialDate: _baslangic,
      firstDate: ilk,
      lastDate: son,
    );
    if (g == null || !mounted) return;
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_baslangic),
    );
    if (!mounted) return;
    setState(() {
      _baslangic = DateTime(
        g.year,
        g.month,
        g.day,
        s?.hour ?? _baslangic.hour,
        s?.minute ?? _baslangic.minute,
      );
      // ⚠️ Baslangic ILERI alinip bitisin GERIDE kalmasi mumkun. Sunucu
      //    `b.After(bas)` sartiyla boyle bir bitisi zaten YOK SAYAR; kullanici
      //    "bitis girdim ama gorunmedi" demesin diye burada TEMIZLENIYOR.
      if (_bitis != null && !_bitis!.isAfter(_baslangic)) _bitis = null;
    });
  }

  /// Bitis saati (istege bagli).
  ///
  /// ⚠️ Sinirlar BASLANGICA gore: bitis baslangictan ONCE olamaz. Sunucu da
  ///    ayni kurali uyguluyor (`b.After(bas)`), burada kullaniciya ONCEDEN
  ///    gosteriliyor — sessizce yok sayilan bir giris kotu deneyimdir.
  Future<void> _bitisSec() async {
    final ilk = _baslangic;
    final son = _baslangic.add(const Duration(days: 30));
    var baslangicDegeri = _bitis ?? _baslangic.add(const Duration(hours: 2));
    if (baslangicDegeri.isBefore(ilk)) baslangicDegeri = ilk;
    if (baslangicDegeri.isAfter(son)) baslangicDegeri = son;
    final g = await showDatePicker(
      context: context,
      initialDate: baslangicDegeri,
      firstDate: ilk,
      lastDate: son,
    );
    if (g == null || !mounted) return;
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(baslangicDegeri),
    );
    if (!mounted) return;
    final secilen = DateTime(
      g.year,
      g.month,
      g.day,
      s?.hour ?? baslangicDegeri.hour,
      s?.minute ?? baslangicDegeri.minute,
    );
    if (!secilen.isAfter(_baslangic)) {
      _uyar('Bitiş, başlangıçtan sonra olmalı');
      return;
    }
    setState(() => _bitis = secilen);
  }

  Future<void> _kaydet() async {
    if (_baslik.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Başlık gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    // ⚠️⚠️ TURU 78b — SERVISLER **TUM AWAIT'LERDEN ONCE** (ayrinti icin
    //    `ilan_ekranlari.dart` `_kaydet` serhi). Ozeti: kaydetme uzun surer
    //    (fotograf sikistirma + yukleme + VIDEO), `PopScope` yok, kullanici
    //    geri basarsa `State` dispose olur ve `ref.read` `StateError` firlatir;
    //    catch yutar -> medya R2'ye YUKLENIR ama `POST /etkinlikler` HIC
    //    ATILMAZ. Turu 77b'deki hikaye hatasinin birebir aynisi.
    //    ⚠️ YAPMA: bu iki satiri await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final etkinlikSvc = ref.read(etkinlikServisiProvider);
    try {
      final idler = <String>[];
      for (final g in _gorseller) {
        // ⚠️ EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa 422 doner.
        final hazir = await MedyaServisi.gorseliHazirla(g);
        if (hazir == null) throw Exception('Görsel hazırlanamadı');
        idler.add(
          await medyaSvc.yukle(
            dosya: hazir,
            kind: 'image',
            mime: 'image/jpeg',
          ),
        );
      }
      // ⚠️ VIDEO HAM GIDER — `gorseliHazirla` bir GORSEL sikistiricisidir;
      //    videoya uygulanirsa dosya BOZULUR.
      for (final v in _videolar) {
        idler.add(
          await medyaSvc.yukle(dosya: v, kind: 'video', mime: 'video/mp4'),
        );
      }
      // ⚠️ Fiyat KURUS'a cevrilir (sunucu kurus bekliyor — INT tasmasi icin).
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final govde = <String, dynamic>{
        'baslik': _baslik.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'kategori': _kategori,
        'baslangic': _baslangic.toUtc().toIso8601String(),
        // ⚠️ Bos dize = BITISI KALDIR nobetcisi (sunucuda `null` "degistirme"
        //    demek; ayni tuzak kapak gorselinde de vardi).
        'bitis': _bitis?.toUtc().toIso8601String() ?? '',
        'konum': _konum.text.trim(),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        // ⚠️ DUZENLEMEDE: KALAN mevcut medyalar + YENI yuklenenler. Kullanicinin
        //    sildikleri bu listede olmadigi icin etkinlikten duser.
        'media_ids': [..._mevcutMedya, ...idler],
        'ucretsiz': _ucretsiz,
        'fiyat_kurus': _ucretsiz ? 0 : (tl * 100).round(),
        'kontenjan': int.tryParse(_kontenjan.text.trim()) ?? 0,
      };
      if (_duzenleme) {
        await etkinlikSvc.guncelle(widget.etkinlik!.id, govde);
        if (!mounted) return;
        // ⚠️ `true` doner: cagiran ekran SUNUCUDAN tazeler. `Etkinlik` modeli
        //    cogunlukla `final` oldugu icin yerel yamalama yapilamaz.
        Navigator.of(context).pop(true);
        return;
      }
      final id = await etkinlikSvc.olustur(govde);
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (err) {
      // ⚠️ KOK MESSENGER: kullanici kaydetme surerken ekrandan cikmis olabilir.
      if (mounted) setState(() => _kaydediliyor = false);
      _uyar(apiErrorMessage(err));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_duzenleme ? 'Etkinliği düzenle' : 'Etkinlik oluştur'),
      actions: [
        TextButton(
          onPressed: _kaydediliyor ? null : _kaydet,
          child: Text(_duzenleme ? 'Kaydet' : 'Yayınla'),
        ),
      ],
    ),
    body: AbsorbPointer(
      absorbing: _kaydediliyor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- MEDYA (coklu gorsel + video) — TURU 78
          // ⚠️ Onceden TEK kapak gorseli vardi; sunucu ZATEN 10 medya kabul
          //    ediyordu, yani sinir yalnizca ARAYUZDEYDI.
          _medyaSeridi(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gorselSec,
                  icon: const Icon(LucideIcons.imagePlus, size: 18),
                  label: Text(
                    'Görsel '
                    '(${_mevcutMedya.length + _gorseller.length + _videolar.length}'
                    '/$_enFazlaMedya)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _videoSec,
                  icon: const Icon(LucideIcons.video, size: 18),
                  label: Text('Video (${_videolar.length}/$_enFazlaVideo)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _baslik,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'Başlık',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _aciklama,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in etkinlikKategorileri.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _kategori = v ?? 'diger'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _tarihSec,
            icon: const Icon(LucideIcons.calendar, size: 18),
            label: Text('Başlangıç: ${etkinlikZamani(_baslangic)}'),
          ),
          const SizedBox(height: 8),
          // ⚠️⚠️ TURU 78 — BITIS SECICI. `etkinlikler.bitis` sutunu 029'dan
          //    beri VARDI, sunucu dogruluyordu ve DETAY EKRANI onu CIZIYORDU —
          //    ama FORMA HIC KONULMAMISTI. Yani "Bitiş: …" satiri sahada ASLA
          //    gorunmuyordu: klasik "olu ozellik" (bu projede besinci tekrar).
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _bitisSec,
                  icon: const Icon(LucideIcons.clock, size: 18),
                  label: Text(
                    _bitis == null
                        ? 'Bitiş saati (isteğe bağlı)'
                        : 'Bitiş: ${etkinlikZamani(_bitis)}',
                  ),
                ),
              ),
              // ⚠️ "Kaldır" YALNIZ deger varken cizilir — bos ekranda olu dugme.
              if (_bitis != null)
                IconButton(
                  tooltip: 'Bitişi kaldır',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => setState(() => _bitis = null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _konum,
            decoration: const InputDecoration(
              labelText: 'Yer (mekân adı / adres)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _il,
                  decoration: const InputDecoration(
                    labelText: 'İl',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ilce,
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _ucretsiz,
            onChanged: (v) => setState(() => _ucretsiz = v),
            title: const Text('Ücretsiz'),
          ),
          if (!_ucretsiz)
            TextField(
              controller: _fiyat,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Fiyat (₺)',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _kontenjan,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Kontenjan (boş = sınırsız)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_kaydediliyor)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );

  /// Secilmis/mevcut medyalarin yatay seridi.
  ///
  /// ⚠️ UC AYRI KAYNAK tek seritte: sunucudaki medyalar (silinebilir), yeni
  ///    secilen fotograflar, yeni secilen videolar. Tek listede tutulamazlardi
  ///    (biri `String` id, ikisi `File` ve yukleme `kind`leri farkli).
  /// ⚠️ VIDEO ONIZLEMESI CIZILMEZ (koyu kutu + film ikonu): formda oynatici
  ///    kurmak iOS'ta ses oturumuna dokunur ve SUREN ARAMAYI sagirlastirabilir
  ///    (turu 64/65/73).
  Widget _medyaSeridi() {
    if (_mevcutMedya.isEmpty && _gorseller.isEmpty && _videolar.isEmpty) {
      return const SizedBox.shrink();
    }
    // ⚠️⚠️ TURU 78b — DOKUNMA ALANI BUYUTULDU (denetim bulgusu).
    //    Eski hedef 13px ikon + 2px dolgu = **17x17 dp** idi; Material 48,
    //    Apple 44 dp minimum onerir. Ustelik hedef, YATAY KAYAN bir listenin
    //    icindeki 72x80 dp'lik kucuk resmin KOSESINDE: isabet etmeyen dokunus
    //    kaydirma jestine donusuyor, kullanici medyayi kaldiramiyordu.
    //    ⚠️ GORUNEN daire BUYUMEZ (tasarim bozulmaz); yalnizca SEFFAF dolgu
    //       ile vurulabilir alan genisletilir + `HitTestBehavior.opaque`.
    Widget kaldir(VoidCallback onTap) => Positioned(
      right: 0,
      top: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: const Padding(
          // gorunmez pay: 17x17 gorsel -> ~37x37 dokunma alani
          padding: EdgeInsets.only(left: 10, bottom: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xAA000000),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(2),
              child: Icon(LucideIcons.x, size: 13, color: Colors.white),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          for (var k = 0; k < _mevcutMedya.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 72,
                      height: 80,
                      // ⚠️ TURU 78b: ham `MedyaGorsel` DEGIL — video id'si
                      //    verilirse KIRIK GORSEL cizilirdi.
                      child: MedyaKucukResmi(
                        mediaId: _mevcutMedya[k],
                        tur: k < _mevcutTurler.length
                            ? _mevcutTurler[k]
                            : 'image',
                      ),
                    ),
                  ),
                  // ⚠️ Yalniz LISTEDEN cikarir; medya sunucuda SILINMEZ.
                  // ⚠️ IKI LISTE BIRLIKTE dusurulur (aksi halde kalan ogeler
                  //    YANLIS TIP cizer).
                  kaldir(() => setState(() {
                    _mevcutMedya.removeAt(k);
                    if (k < _mevcutTurler.length) _mevcutTurler.removeAt(k);
                  })),
                ],
              ),
            ),
          for (var k = 0; k < _gorseller.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _gorseller[k],
                      width: 72,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  kaldir(() => setState(() => _gorseller.removeAt(k))),
                ],
              ),
            ),
          for (var k = 0; k < _videolar.length; k++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Stack(
                children: [
                  Container(
                    width: 72,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14101C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.video,
                      color: Colors.white54,
                    ),
                  ),
                  kaldir(() => setState(() => _videolar.removeAt(k))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
