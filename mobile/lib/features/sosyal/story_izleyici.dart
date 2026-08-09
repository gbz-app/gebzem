import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import 'gonderi_karti.dart' show gonderiZamani, sayiBicimle;
import 'medya_video.dart';
import 'story_katman.dart';
import 'story_servisi.dart';

/// ⚠️⚠️ TURU 76b — HIKAYE IZLEYICI (Instagram deseni).
///
/// DAVRANIS:
///   · ustte her hikaye icin bir ILERLEME CUBUGU
///   · SAG YARIYA dokun -> sonraki · SOL YARIYA dokun -> onceki
///   · BASILI TUT -> duraklat (parmagi cekince devam)
///   · asagi kaydir / X -> kapat
///   · son hikaye bitince kapanir
///
/// ⚠️⚠️ VIDEO SURESI: `MedyaVideo` suresini DISARI VERMIYOR. Bu yuzden video
///    hikayeler SABIT 15 saniye gosterilir (Instagram tavani da 15 sn).
///    Daha kisa videoda son kare donar — DURUST bir davranis, ve kullanici
///    dokununca zaten gecer.
/// ⚠️ YAPMA: sure icin `MedyaVideo`ya gizli bir kanal acma; oynatici zaten
///    kirilgan (iOS ses oturumu). Gerekirse once oynaticiya ACIK bir
///    `onSure` geri cagrimi eklenir.
///
/// ⚠️⚠️ SES: hikaye videosu SESLI acilir (Instagram) AMA `MedyaVideo` icindeki
///    kapi arama/oda/yayin canliyken sesi ZORLA kapatir — o kapi KALDIRILAMAZ.
class StoryIzleyici extends ConsumerStatefulWidget {
  const StoryIzleyici({super.key, required this.kullanici, this.onIzlendi});

  final StoryKullanici kullanici;

  /// Serit halkasini GRIYE cevirmek icin (hepsi izlendi).
  final VoidCallback? onIzlendi;

  @override
  ConsumerState<StoryIzleyici> createState() => _StoryIzleyiciState();
}

class _StoryIzleyiciState extends ConsumerState<StoryIzleyici>
    with SingleTickerProviderStateMixin {
  List<Story>? _liste;
  String? _hata;
  int _i = 0;

  // ⚠️ `late final` DEGIL: `late final` TEMBEL baslar. `_yukle()` patlarsa
  //    `_basla()` hic kosmaz ve alana ILK DOKUNAN yer `dispose()` olur — orada
  //    `vsync: this` ile bir AnimationController YARATIP hemen dispose etmek
  //    (State cozulurken) kirilgan bir yol. Artik `initState`te kurulur.
  late AnimationController _ilerleme;

  @override
  void initState() {
    super.initState();
    _ilerleme =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _sonraki();
          });
    _yukle();
  }

  @override
  void dispose() {
    _ilerleme.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref
          .read(storyServisiProvider)
          .kullanici(widget.kullanici.userId);
      if (!mounted) return;
      if (l.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _liste = l);
      _basla();
    } catch (_) {
      if (mounted) setState(() => _hata = 'Hikâye açılamadı');
    }
  }

  Story? get _aktif {
    final l = _liste;
    if (l == null || _i < 0 || _i >= l.length) return null;
    return l[_i];
  }

  void _basla() {
    final s = _aktif;
    if (s == null) return;
    // ⚠️ Video 15 sn, fotograf 5 sn (bkz. sinif serhi).
    _ilerleme.duration = Duration(seconds: s.videoMu ? 15 : 5);
    _ilerleme
      ..reset()
      ..forward();
    // ⚠️ Izlendi isareti ATESLE-UNUT: basarisiz olsa da izleme akisini bozmaz.
    //    Sunucu idempotent.
    if (!s.izledim) {
      s.izledim = true;
      unawaited(
        ref.read(storyServisiProvider).izlendi(s.id).catchError((_) {}),
      );
    }
  }

  void _sonraki() {
    final l = _liste;
    if (l == null) return;
    if (_i >= l.length - 1) {
      widget.onIzlendi?.call();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _i++);
    _basla();
  }

  void _onceki() {
    if (_i <= 0) {
      // ⚠️ Ilk hikayede geri = BASA SAR (kapatma DEGIL) — kullanici yanlislikla
      //    sola dokununca izleyiciden atilmamali.
      _basla();
      return;
    }
    setState(() => _i--);
    _basla();
  }

  Future<void> _sil() async {
    final s = _aktif;
    if (s == null) return;
    _ilerleme.stop();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hikâye silinsin mi?'),
        content: const Text('Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (onay != true) {
      _ilerleme.forward();
      return;
    }
    try {
      await ref.read(storyServisiProvider).sil(s.id);
      if (!mounted) return;
      final l = _liste!..removeAt(_i);
      if (l.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_i >= l.length) _i = l.length - 1;
      setState(() {});
      _basla();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hikâye silinemedi')));
      _ilerleme.forward();
    }
  }

  Future<void> _izleyenler() async {
    final s = _aktif;
    if (s == null) return;
    _ilerleme.stop();
    List<Map<String, dynamic>>? l;
    try {
      l = await ref.read(storyServisiProvider).izleyenler(s.id);
    } catch (_) {
      l = null;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(c).size.height * 0.5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  l == null
                      ? 'Görüntüleyenler'
                      : '${sayiBicimle(l.length)} görüntüleme',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: (l == null || l.isEmpty)
                    ? Center(
                        child: Text(
                          l == null
                              ? 'Liste alınamadı'
                              : 'Henüz kimse izlemedi',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: l.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: Avatar(
                            ad: (l![i]['name'] ?? '').toString(),
                            mediaId: l[i]['avatar_media_id'] as String?,
                            cap: 40,
                          ),
                          title: Text((l[i]['name'] ?? '').toString()),
                          subtitle: Text(
                            '@${(l[i]['username'] ?? '').toString()}',
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) _ilerleme.forward();
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    final s = _aktif;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _hata != null
          ? Center(
              child: Text(
                _hata!,
                style: const TextStyle(color: Colors.white70),
              ),
            )
          : (l == null || s == null)
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              // ⚠️ BASILI TUT -> duraklat. `onLongPress` YETMEZ: parmak
              //    kalkinca devam etmesi icin BASMA/BIRAKMA olaylari gerekli.
              onTapDown: (_) => _ilerleme.stop(),
              onTapUp: (d) {
                final genislik = MediaQuery.of(context).size.width;
                if (d.localPosition.dx < genislik * 0.32) {
                  _onceki();
                } else {
                  _sonraki();
                }
              },
              onTapCancel: () => _ilerleme.forward(),
              onLongPressEnd: (_) => _ilerleme.forward(),
              // ⚠️ Asagi kaydirinca kapan (Instagram) — hiz esigi, kucuk
              //    kazara hareketlerde kapanmasin.
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 250) Navigator.of(context).pop();
              },
              child: Stack(
                children: [
                  // ⚠️⚠️ TURU 77b — MEDYA VE KATMANLAR **AYNI 9:16 TUVALINE**
                  //    cizilir (bkz. story_katman.dart `StoryTuvali` serhi).
                  //    ONCEDEN ikisi de EKRANIN TAMAMINA gore konumlaniyordu;
                  //    editorle izleyici ayni ekranda ayni sonucu verdigi icin
                  //    TEK CIHAZDA TEST EDILSE GORULMEZDI — ama medya `contain`
                  //    ciziliyor ve fotografin kapladigi dikey oran EKRAN
                  //    EN-BOYUNA gore degisiyor. Ayni hikaye 390x844'te ve
                  //    360x640'ta fotografa gore ~%19 kaymis cikiyordu; ucta
                  //    yazi letterbox bandina dusuyordu.
                  //    ⚠️ YAPMA: tuvali `MediaQuery.size`a geri baglama.
                  Positioned.fill(
                    child: StoryTuvali(
                      yap: (c, tuval) => Stack(
                        children: [
                          Positioned.fill(child: _icerik(s)),
                          // ⚠️⚠️ `storyKatmanCiz` EDITORUN KULLANDIGI AYNI
                          //    fonksiyondur; iki ayri cizim kodu DRIFT eder
                          //    ("yazdigim yerde durmuyor").
                          // ⚠️ Katmanlar dokunuslari YUTMAZ (`IgnorePointer`) —
                          //    yoksa ileri/geri dokunusu calismazdi.
                          for (final k in s.katmanlar) storyKatmanCiz(k, tuval),
                        ],
                      ),
                    ),
                  ),
                  // Ust karartma — cubuklar ve isim acik renkli medyada da okunur.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 140,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: Row(
                            children: [
                              for (var k = 0; k < l.length; k++)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: _cubuk(k),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
                          child: Row(
                            children: [
                              Avatar(
                                ad: widget.kullanici.ad,
                                mediaId: widget.kullanici.avatarMediaId,
                                cap: 34,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.kullanici.ad,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                gonderiZamani(s.createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (widget.kullanici.benim)
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                  onPressed: _sil,
                                ),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.x,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.metin.isNotEmpty)
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: widget.kullanici.benim ? 86 : 44,
                      child: IgnorePointer(
                        child: Text(
                          s.metin,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black87),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // ⚠️ IZLEYENLER YALNIZ SAHIBINE (Instagram) — baskasinin
                  //    hikayesinde kimlerin izledigi GORUNMEZ.
                  if (widget.kullanici.benim)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Center(
                          child: TextButton.icon(
                            onPressed: _izleyenler,
                            icon: const Icon(
                              LucideIcons.eye,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: Text(
                              s.izlenme >= 0
                                  ? '${sayiBicimle(s.izlenme)} görüntüleme'
                                  : 'Görüntüleyenler',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _icerik(Story s) {
    // ⚠️ TURU 77 — MEDYASIZ METIN HIKAYESI: gradyan zemin cizilir, medya
    //    istegi HIC atilmaz. `mediaId` bos oldugu icin `MedyaGorsel`e verilse
    //    KIRIK/BOS kare cizerdi.
    if (s.metinHikayesi) return storyZemin(s.arkaPlan);
    if (s.videoMu) {
      return MedyaVideo(
        mediaId: s.mediaId,
        otoOynat: true,
        sesli: true,
        // ⚠️ DONGU ACIK: hikaye penceresi SABIT 15 sn (bkz. sinif serhi) ama
        //    video daha kisa olabilir. Dongu olmasaydi son karede DONAR ve
        //    kullanici "bozuldu" sanardi. Donguyle kisa video tekrar oynar.
        dongu: true,
        dolgu: BoxFit.contain,
        // ⚠️⚠️ TURU 77b — **ZORUNLU (denetim bulgusu).** `kontrolGoster`
        //    varsayilani `true`; o zaman `MedyaVideo` tum ekrani kaplayan bir
        //    `GestureDetector(onTap: _duraklatCevir)` cizer ve jest arenasinda
        //    DISTAKI `onTapUp`tan ONCE kazanir (hit-test en ICTEN baslar).
        //    Sonuc: VIDEO hikayede saga dokununca sonraki hikayeye GECMIYOR,
        //    videoyu duraklatiyordu — fotograf hikayelerde geciyordu, yani
        //    davranis TUTARSIZDI. Ayrica Instagram'da olmayan oynat/hoparlor
        //    dugmeleri ve mor ilerleme cubugu hikayenin ustune ciziliyordu.
        //    ⚠️ YAPMA: burada kontrolleri geri acma.
        kontrolGoster: false,
      );
    }
    return MedyaGorsel(mediaId: s.mediaId, fit: BoxFit.contain);
  }

  /// Ust ilerleme cubugu: gecmisler DOLU, aktif animasyonlu, gelecekler BOS.
  Widget _cubuk(int k) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      height: 3,
      child: k < _i
          ? const ColoredBox(color: Colors.white)
          : k > _i
          ? ColoredBox(color: Colors.white.withValues(alpha: 0.3))
          : AnimatedBuilder(
              animation: _ilerleme,
              builder: (_, _) => LinearProgressIndicator(
                value: _ilerleme.value,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
    ),
  );
}
