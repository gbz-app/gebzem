import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chats/moderasyon_sheet.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import '../medya/tam_ekran_gorsel.dart';
import '../sosyal/medya_video.dart';
import '../sosyal/gonderi_karti.dart' show gonderiZamani, sayiBicimle;
import 'kanal_servisi.dart';

/// ⚠️⚠️ TURU 75 — KANAL EKRANI (gonderi akisi + yetkili icin paylasim kutusu).
///
/// ⚠️ SIRALAMA WhatsApp gibi TERS (`reverse: true`): en yeni ALTTA ve ekran
///    en altta acilir. Sunucu yeniden eskiye donuyor; liste ters cizildigi icin
///    ek siralama YOK.
///
/// ✅ TURU 76b — VIDEO ARTIK DESTEKLENIYOR (kullanici emri: "kanallarda video
///    eklenebilmeli"). Eski sinirin sebebi sunucunun yasagi DEGILDI:
///    `channel_posts.media_ids` medyanin TURUNU tasimiyordu ve istemci bir
///    id'nin foto mu video mu oldugunu BILEMIYORDU (video id'sini
///    `MedyaGorsel`e verirse KIRIK GORSEL cizerdi). Sunucu artik gonderi
///    tarafiyla AYNI `media_kinds` dizisini donduruyor -> kisit KALKTI.
/// ⚠️ YAPMA: tur bilgisi olmadan medyayi video sanip oynatmaya calisma;
///    `mediaKinds` eksikse 'image' varsayilir (guvenli taraf).
/// ⚠️ Kanalda video ELLE baslar (akistaki gibi otomatik DEGIL): ekran TERS
///    sirali ve acilista en alta ziplar; orada otomatik oynatma kullanicinin
///    gormedigi bir videoyu calistirirdi.
///
/// ⚠️ OKUNDU: ekran acilir acilmaz `okundu()` cagrilir. Rozeti gormek icin
///    girmek YETER (WhatsApp kanallarinda da boyle).
class KanalEkrani extends ConsumerStatefulWidget {
  const KanalEkrani({super.key, required this.kanalId, this.onIsim = ''});

  final String kanalId;

  /// Liste ekranindan gelen ad — detay yuklenene kadar baslikta gorunur
  /// (bos AppBar yerine).
  final String onIsim;

  @override
  ConsumerState<KanalEkrani> createState() => _KanalEkraniState();
}

class _KanalEkraniState extends ConsumerState<KanalEkrani> {
  Kanal? _k;
  final List<KanalGonderi> _gonderiler = [];
  bool _yukleniyor = true;
  bool _dahaVar = true;
  bool _sonrakiGeliyor = false;
  String? _hata;

  final _metin = TextEditingController();
  final _kaydirma = ScrollController();

  /// ⚠️ TURU 76b: artik VIDEO da secilebiliyor, bu yuzden duz `File` YETMEZ —
  ///    her secimin turunu tasimak ZORUNDA (yukleme yolu farkli: fotograf
  ///    sikistirilir + EXIF temizlenir, video HAM gider).
  final List<_KanalMedya> _secilenler = [];
  bool _paylasiliyor = false;
  double _ilerleme = 0;
  CancelToken? _iptal;

  @override
  void initState() {
    super.initState();
    _yukle();
    _kaydirma.addListener(() {
      // Ters listede "eski" yon MAKSIMUMA dogru.
      if (_kaydirma.hasClients &&
          _kaydirma.position.pixels >
              _kaydirma.position.maxScrollExtent - 600) {
        unawaited(_dahaGetir());
      }
    });
  }

  @override
  void dispose() {
    _metin.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final s = ref.read(kanalServisiProvider);
      final d = await s.detay(widget.kanalId);
      final g = await s.gonderiler(widget.kanalId);
      if (!mounted) return;
      setState(() {
        _k = d;
        _gonderiler
          ..clear()
          ..addAll(g);
        _dahaVar = g.isNotEmpty;
        _yukleniyor = false;
      });
      // ⚠️ Okundu isaretlemesi BEKLENMEZ: basarisiz olsa da ekran acilmali.
      unawaited(s.okundu(widget.kanalId).catchError((_) {}));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString().contains('404')
            ? 'Kanal bulunamadı'
            : 'Kanal açılamadı';
      });
    }
  }

  Future<void> _dahaGetir() async {
    if (_sonrakiGeliyor || !_dahaVar || _gonderiler.isEmpty) return;
    _sonrakiGeliyor = true;
    try {
      final g = await ref
          .read(kanalServisiProvider)
          .gonderiler(widget.kanalId, before: _gonderiler.last.createdAt);
      if (!mounted) return;
      // ⚠️ TEKRAR SUZGECI (akis/reels ile ayni sebep): imlec sinirinda ayni
      //    zaman damgasina dusen kayitlar iki sayfada da gelebilir.
      final mevcut = _gonderiler.map((x) => x.id).toSet();
      setState(() {
        _gonderiler.addAll(g.where((x) => !mevcut.contains(x.id)));
        _dahaVar = g.isNotEmpty;
      });
    } catch (_) {
    } finally {
      _sonrakiGeliyor = false;
    }
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    final kalan = 10 - _secilenler.length;
    if (kalan <= 0) {
      _uyar('En fazla 10 görsel eklenebilir');
      return;
    }
    // ⚠️ TEK KAYNAK: limit<2 tuzagi + take(kalan) kirpmasi MedyaSecici'de.
    final secim = await MedyaSecici.coklu(kalan);
    if (secim.isEmpty || !mounted) return;
    setState(
      () => _secilenler.addAll(
        secim.map((x) => _KanalMedya(File(x.path), false)),
      ),
    );
  }

  /// ⚠️⚠️ TURU 76b — KANALA VIDEO (kullanici emri: "kanallarda video
  ///    eklenebilmeli"). Onceki surumde kanal yalniz fotograf aliyordu ve bu
  ///    bir SUNUCU yasagi degil, istemcinin medyanin turunu BILEMEMESIYDI.
  ///    Sunucu artik `media_kinds` donduruyor -> kisit KALKTI.
  /// ⚠️ Boyut tavani gonderi tarafiyla AYNI (100 MB) — istemcide kesmezsek
  ///    kullanici dosyayi bosuna yukler ve commit'te reddedilir.
  Future<void> _videoSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    if (_secilenler.length >= 10) {
      _uyar('En fazla 10 medya ekleyebilirsin');
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickVideo(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    final dosya = File(x.path);
    final bayt = await dosya.length();
    if (!mounted) return;
    final tavan = kTavanlar['video'] ?? (100 << 20);
    if (bayt > tavan) {
      _uyar('Video çok büyük (en fazla ${(tavan / (1 << 20)).round()} MB)');
      return;
    }
    setState(() => _secilenler.add(_KanalMedya(dosya, true)));
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _paylas() async {
    final metin = _metin.text.trim();
    if (metin.isEmpty && _secilenler.isEmpty) return;
    setState(() {
      _paylasiliyor = true;
      _ilerleme = 0;
    });
    _iptal = CancelToken();
    try {
      final medyaS = ref.read(medyaServisiProvider);
      final idler = <String>[];
      for (var i = 0; i < _secilenler.length; i++) {
        final m = _secilenler[i];
        // ⚠️ FOTOGRAF: EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa
        //    422 doner ve yuklenen veri BOSA gider.
        // ⚠️ VIDEO: sikistirilmaz/temizlenmez, HAM gider (gonderi tarafiyla
        //    ayni davranis; video EXIF temizligi ayri bir is).
        File gonderilecek = m.dosya;
        if (!m.video) {
          final hazir = await MedyaServisi.gorseliHazirla(m.dosya);
          if (hazir == null) throw Exception('Fotoğraf hazırlanamadı');
          gonderilecek = hazir;
        }
        final id = await medyaS.yukle(
          dosya: gonderilecek,
          kind: m.video ? 'video' : 'image',
          mime: m.video ? 'video/mp4' : 'image/jpeg',
          fileName: m.dosya.uri.pathSegments.last,
          iptal: _iptal,
          ilerleme: (p) {
            if (mounted) {
              setState(() => _ilerleme = (i + p) / _secilenler.length);
            }
          },
        );
        idler.add(id);
      }
      await ref
          .read(kanalServisiProvider)
          .gonderiPaylas(widget.kanalId, metin: metin, mediaIds: idler);
      if (!mounted) return;
      _metin.clear();
      _secilenler.clear();
      setState(() => _paylasiliyor = false);
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      setState(() => _paylasiliyor = false);
      if (e is DioException && CancelToken.isCancel(e)) {
        _uyar('Yükleme iptal edildi');
      } else {
        _uyar('Gönderi paylaşılamadı');
      }
    }
  }

  Future<void> _begeniCevir(KanalGonderi g) async {
    final eski = g.begendim;
    final eskiSayi = g.begeniSayisi;
    setState(() {
      g.begendim = !eski;
      g.begeniSayisi = (eskiSayi + (g.begendim ? 1 : -1)).clamp(0, 1 << 30);
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      final s = ref.read(kanalServisiProvider);
      g.begendim ? await s.begen(g.id) : await s.begeniGeriAl(g.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        g.begendim = eski;
        g.begeniSayisi = eskiSayi;
      });
    }
  }

  Future<void> _abonelikCevir() async {
    final k = _k;
    if (k == null) return;
    final eski = k.aboneMiyim;
    setState(() {
      k.aboneMiyim = !eski;
      k.aboneSayisi = (k.aboneSayisi + (eski ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      final s = ref.read(kanalServisiProvider);
      eski ? await s.abonelikBirak(k.id) : await s.aboneOl(k.id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        k.aboneMiyim = eski;
        k.aboneSayisi = (k.aboneSayisi + (eski ? 1 : -1)).clamp(0, 1 << 30);
      });
      _uyar(
        e.toString().contains('400')
            ? 'Kendi kanalınızdan çıkamazsınız'
            : 'İşlem tamamlanamadı',
      );
    }
  }

  Future<void> _menu() async {
    final k = _k;
    if (k == null) return;
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(k.sessiz ? LucideIcons.bell : LucideIcons.bellOff),
              title: Text(k.sessiz ? 'Sesi aç' : 'Sessize al'),
              onTap: () => Navigator.pop(c, 'sessiz'),
            ),
            if (k.kullaniciAdi.isNotEmpty)
              ListTile(
                leading: const Icon(LucideIcons.link),
                title: const Text('Bağlantıyı kopyala'),
                onTap: () => Navigator.pop(c, 'link'),
              ),
            if (!k.yetkiliMiyim)
              ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Şikayet et'),
                onTap: () => Navigator.pop(c, 'sikayet'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'sessiz') {
      final yeni = !k.sessiz;
      setState(() => k.sessiz = yeni);
      try {
        await ref.read(kanalServisiProvider).sessizAyarla(k.id, yeni);
      } catch (_) {
        if (mounted) setState(() => k.sessiz = !yeni);
      }
    } else if (secim == 'link') {
      await Clipboard.setData(
        ClipboardData(text: 'https://gebzem.app/k/${k.kullaniciAdi}'),
      );
      if (mounted) _uyar('Bağlantı kopyalandı');
    } else if (secim == 'sikayet') {
      await sikayetSheetAc(context, ref, hedefTur: 'kanal', hedefId: k.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _k;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              k?.ad.isNotEmpty == true ? k!.ad : widget.onIsim,
              style: const TextStyle(fontSize: 16),
            ),
            if (k != null)
              Text(
                '${sayiBicimle(k.aboneSayisi)} abone',
                style: const TextStyle(fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (k != null && !k.yetkiliMiyim)
            TextButton(
              onPressed: _abonelikCevir,
              child: Text(k.aboneMiyim ? 'Abonesin' : 'Abone ol'),
            ),
          IconButton(
            icon: const Icon(LucideIcons.ellipsis),
            onPressed: k == null ? null : _menu,
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : k == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hata ?? 'Kanal açılamadı'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _yukle,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(child: _liste(k)),
                // ⚠️ PAYLASIM KUTUSU YALNIZ YETKILILERE. Kanal TEK YONLU —
                //    abonenin yazacagi bir yer YOK (WhatsApp da boyle).
                if (k.yetkiliMiyim) _paylasimKutusu(),
              ],
            ),
    );
  }

  Widget _liste(Kanal k) {
    if (_gonderiler.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(ad: k.ad, mediaId: k.avatarMediaId, cap: 76),
              const SizedBox(height: 14),
              Text(
                k.ad,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (k.aciklama.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  k.aciklama,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                k.yetkiliMiyim
                    ? 'Henüz gönderi yok. İlk paylaşımı yap.'
                    : 'Bu kanalda henüz gönderi yok.',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _kaydirma,
      // ⚠️ TERS: sunucu yeniden eskiye donuyor; ters cizince en yeni ALTTA olur
      //    ve ekran en altta acilir (WhatsApp davranisi).
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _gonderiler.length,
      itemBuilder: (_, i) => _gonderiKarti(_gonderiler[i], k),
    );
  }

  /// Coklu medyali kanal gonderilerinde hangi sayfadayiz (gonderi id -> indeks).
  /// ⚠️ Kart durumsuz (`StatelessWidget` degil ama kendi state'i yok) oldugu
  ///    icin sayfa bilgisi EKRAN seviyesinde tutulur.
  final Map<int, int> _kanalSayfa = {};

  /// TURU 76b — kanal gonderisinin istatistigi (yalniz yetkili/kanal sahibi).
  Future<void> _istatistik(KanalGonderi g) async {
    Map<String, int>? veri;
    try {
      veri = await ref.read(kanalServisiProvider).gonderiIstatistik(g.id);
    } catch (_) {
      veri = null;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gönderi istatistikleri',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (veri == null)
                const Text(
                  'İstatistikler alınamadı',
                  style: TextStyle(color: Colors.grey),
                )
              else
                Row(
                  children: [
                    _istKutu(
                      LucideIcons.eye,
                      'Görüntülenme',
                      veri['goruntulenme'] ?? 0,
                    ),
                    _istKutu(LucideIcons.heart, 'Beğeni', veri['begeni'] ?? 0),
                  ],
                ),
              const SizedBox(height: 12),
              // ⚠️ DURUSTLUK: kanal goruntulenmesi KABA sayilir (ayni kisi
              //    tekrar bakinca yine artar). Yazmasak kullanici sayiyi
              //    "bozuk" sanardi.
              const Text(
                'Görüntülenme, gönderi listede her yüklendiğinde sayılır.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _istKutu(IconData ikon, String baslik, int deger) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 20),
          const SizedBox(height: 6),
          Text(
            sayiBicimle(deger),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          Text(
            baslik,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _gonderiKarti(KanalGonderi g, Kanal k) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (g.mediaIds.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: g.mediaIds.length == 1
                      ? _tekMedya(g, 0)
                      : PageView.builder(
                          itemCount: g.mediaIds.length,
                          onPageChanged: (i) =>
                              setState(() => _kanalSayfa[g.id] = i),
                          itemBuilder: (_, i) => _tekMedya(g, i),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (g.metin.isNotEmpty)
              Text(g.metin, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => _begeniCevir(g),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.heart,
                        size: 17,
                        color: g.begendim ? const Color(0xFFFF3B5C) : null,
                      ),
                      if (g.begeniSayisi > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          sayiBicimle(g.begeniSayisi),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // ⚠️⚠️ TURU 76b — ISTATISTIK (kullanici emri: "oradaki
                //    paylasimlarin da istatistikleri gorunmeli").
                //    YETKILIYE dokunulabilir bir ikon (detayli sayfa acilir);
                //    aboneye yalniz goruntulenme sayisi gosterilir.
                if (k.yetkiliMiyim)
                  GestureDetector(
                    onTap: () => _istatistik(g),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.chartNoAxesColumn,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sayiBicimle(g.goruntulenme),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const Icon(LucideIcons.eye, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    sayiBicimle(g.goruntulenme),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const Spacer(),
                Text(
                  gonderiZamani(g.createdAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (k.yetkiliMiyim)
                  GestureDetector(
                    onTap: () => _gonderiSil(g),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(
                        LucideIcons.trash2,
                        size: 15,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ⚠️⚠️ TURU 76b — KANALDA VIDEO (kullanici emri: "kanallarda video
  ///    eklenebilmeli"). Sunucu artik `media_kinds` donduruyor; her medyanin
  ///    turu AYRI biliniyor. Onceki surumdeki "kanal gonderisinde video YOK"
  ///    siniri KALKTI.
  /// ⚠️ Video AKISTAKI gibi degil ELLE baslar (`otoOynat: false`): kanal ekrani
  ///    TERS SIRALI (`reverse: true`) ve acilista en alta ziplar; orada
  ///    otomatik oynatma kullanicinin gormedigi bir videoyu calistirirdi.
  /// ⚠️ Video TAM EKRAN GORSELE gonderilmez — `TamEkranGorsel` yalniz fotograf
  ///    cizer; video icin dokunus oynaticinin KENDI kontrolune birakilir.
  Widget _tekMedya(KanalGonderi g, int i) {
    final id = g.mediaIds[i];
    final tur = i < g.mediaKinds.length ? g.mediaKinds[i] : 'image';
    if (tur == 'yok') {
      return const ColoredBox(
        color: Color(0xFF15151F),
        child: Center(
          child: Text(
            'Bu içerik kaldırıldı',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      );
    }
    if (tur == 'video') {
      return MedyaVideo(
        mediaId: id,
        otoOynat: false,
        sesli: false,
        dolgu: BoxFit.cover,
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TamEkranGorsel(mediaId: id))),
      child: MedyaGorsel(mediaId: id, fit: BoxFit.cover),
    );
  }

  Future<void> _gonderiSil(KanalGonderi g) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Gönderi kaldırılsın mı?'),
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
      await ref.read(kanalServisiProvider).gonderiSil(g.id);
      if (!mounted) return;
      setState(() => _gonderiler.removeWhere((x) => x.id == g.id));
    } catch (_) {
      _uyar('Gönderi kaldırılamadı');
    }
  }

  Widget _paylasimKutusu() => SafeArea(
    top: false,
    child: Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_secilenler.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _secilenler.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      // ⚠️ Video icin `Image.file` CIZILEMEZ (kirik kare) —
                      //    kapak yerine ikon gosterilir.
                      child: _secilenler[i].video
                          ? Container(
                              width: 56,
                              height: 64,
                              color: const Color(0xFF1A1A24),
                              alignment: Alignment.center,
                              child: const Icon(
                                LucideIcons.video,
                                color: Colors.white70,
                                size: 22,
                              ),
                            )
                          : Image.file(
                              _secilenler[i].dosya,
                              width: 56,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                    ),
                    if (!_paylasiliyor)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _secilenler.removeAt(i)),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0xAA000000),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                LucideIcons.x,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_paylasiliyor) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: LinearProgressIndicator(value: _ilerleme)),
                TextButton(
                  onPressed: () => _iptal?.cancel('kullanici iptal'),
                  child: const Text('İptal'),
                ),
              ],
            ),
          ],
          Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.image),
                tooltip: 'Fotoğraf',
                onPressed: _paylasiliyor ? null : _gorselSec,
              ),
              // ⚠️ TURU 76b — VIDEO dugmesi (kullanici emri: "kanallarda video
              //    eklenebilmeli"). Ayri dugme: fotograf secici COKLU, video
              //    secici TEKLI calisir; tek dugmede birlestirmek kullaniciya
              //    "hangisini secebiliyorum" belirsizligi yaratir.
              IconButton(
                icon: const Icon(LucideIcons.video),
                tooltip: 'Video',
                onPressed: _paylasiliyor ? null : _videoSec,
              ),
              Expanded(
                child: TextField(
                  controller: _metin,
                  enabled: !_paylasiliyor,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    hintText: 'Kanala gönderi yaz...',
                    counterText: '',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.send),
                onPressed: _paylasiliyor ? null : _paylas,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Kanal paylasiminda secilen tek medya.
/// ⚠️ TURU 76b: kanal artik VIDEO da kabul ediyor; duz `File` listesi turu
///    tasiyamadigi icin bu kucuk sarmalayici gerekti (yukleme yolu farkli:
///    fotograf sikistirilir + EXIF temizlenir, video HAM gider).
class _KanalMedya {
  _KanalMedya(this.dosya, this.video);
  final File dosya;
  final bool video;
}
