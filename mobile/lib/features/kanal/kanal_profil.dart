import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../router.dart' show rootMessengerKey;
import '../isletme/kategori_kabuk.dart' show YemekHeader;
import '../medya/medya_gorsel.dart';
import '../medya/tam_ekran_gorsel.dart';
import '../medya/tam_ekran_video.dart';
import '../sosyal/gonderi_karti.dart' show sayiBicimle;
import 'kanal_servisi.dart';

/// ⚠️⚠️⚠️ TURU 180z — **KANAL PROFILI** (kullanici emri: *"kanalda kanalin
///	ismine tikladigimda acilan profilde ayni kullanici profili gibi
///	olacak; gorseller, kanalda paylasilan dosyalar vs olacak"*).
///
/// Kullanici profiliyle AYNI dil: buyuk avatar · ad · @adres · aciklama ·
/// sayilar (abone / gonderi) · eylemler · **paylasilan medya izgarasi**.
///
/// ⚠️⚠️ **BACKEND DEGISMEDI — YENI UC YOK.** Iki mevcut uc yetiyor:
///	  · `GET /channels/{id}`        -> ad · adres · aciklama · sayilar
///	  · `GET /channels/{id}/posts`  -> `media_ids` + `media_kinds`
///	"Paylasilan gorseller" o gonderilerin medyasindan TURETILIR.
/// ⚠️ **"Dosyalar" BOLUMU CIZILMEDI**: kanal gonderisi yalniz gorsel/video
///	tasir (`kind` beyaz listesi) — belge yukleme yolu YOK. Bos ya da sahte
///	bir "Dosyalar" sekmesi, turu 66b'nin "gorunen ama calismayan dugme"
///	dersinin tekrari olurdu.
///	⏳ Gerekli: `document` medya turu + kanal gonderisine ekleme yolu.
class KanalProfilEkrani extends ConsumerStatefulWidget {
  const KanalProfilEkrani({super.key, required this.kanalId, this.onIsim = ''});

  final String kanalId;
  final String onIsim;

  @override
  ConsumerState<KanalProfilEkrani> createState() => _KanalProfilEkraniState();
}

class _KanalProfilEkraniState extends ConsumerState<KanalProfilEkrani> {
  Kanal? _k;
  bool _yukleniyor = true;
  String? _hata;

  /// (mediaId, tur) — gonderilerden TURETILEN paylasilan medya.
  List<({String id, String tur})> _medya = const [];
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final s = ref.read(kanalServisiProvider);
      // ⚠️ `Future.wait` — seri olsaydi ekran iki gidis donus beklerdi.
      final sonuc = await Future.wait([
        s.detay(widget.kanalId),
        s.gonderiler(widget.kanalId).catchError((_) => <KanalGonderi>[]),
      ]);
      final k = sonuc[0] as Kanal;
      final gonderiler = sonuc[1] as List<KanalGonderi>;
      final liste = <({String id, String tur})>[];
      for (final g in gonderiler) {
        for (var i = 0; i < g.mediaIds.length; i++) {
          final tur = i < g.mediaKinds.length ? g.mediaKinds[i] : 'image';
          // ⚠️ `'yok'` = medya SILINMIS (sunucu boyle isaretliyor); cizmek
          //	KIRIK GORSEL demek olurdu.
          if (tur == 'yok') continue;
          liste.add((id: g.mediaIds[i], tur: tur));
        }
      }
      if (!mounted) return;
      setState(() {
        _k = k;
        _medya = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = apiErrorMessage(e);
        _yukleniyor = false;
      });
    }
  }

  Future<void> _abonelikCevir() async {
    final k = _k;
    if (k == null || _mesgul) return;
    _mesgul = true;
    final eski = k.aboneMiyim;
    setState(() {
      k.aboneMiyim = !eski;
      k.aboneSayisi += eski ? -1 : 1;
    });
    try {
      final s = ref.read(kanalServisiProvider);
      if (eski) {
        await s.abonelikBirak(k.id);
      } else {
        await s.aboneOl(k.id);
      }
    } catch (e) {
      // ⚠️ Yerel durum GERI ALINIR: sessizce eski hale donmek "dokundum,
      //	bir sey olmadi" hissi verirdi.
      if (mounted) {
        setState(() {
          k.aboneMiyim = eski;
          k.aboneSayisi += eski ? 1 : -1;
        });
      }
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      _mesgul = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return koyuSayfa(Builder(builder: _govde));
  }

  Widget _govde(BuildContext c) {
    final scheme = Theme.of(c).colorScheme;
    final k = _k;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Kanal bilgisi',
        geriBasildi: () => Navigator.of(c).maybePop(),
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
                  TextButton(
                    onPressed: _yukle,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Avatar(
                    ad: k.ad,
                    mediaId: k.avatarMediaId,
                    cap: 108,
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    k.ad,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (k.kullaniciAdi.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '@${k.kullaniciAdi}',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // SAYILAR — kullanici profiliyle AYNI dil.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _sayi(c, sayiBicimle(k.aboneSayisi), 'Abone'),
                    const SizedBox(width: 36),
                    _sayi(c, sayiBicimle(k.gonderiSayisi), 'Gönderi'),
                    const SizedBox(width: 36),
                    _sayi(c, sayiBicimle(_medya.length), 'Görsel'),
                  ],
                ),
                if (k.aciklama.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      k.aciklama,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: scheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                // ⚠️ Sahibine "Abone ol" CIZILMEZ: kendi kanalindan cikmak
                //	anlamsiz ve sunucu zaten kurani otomatik abone yapiyor.
                if (!k.yetkiliMiyim)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      height: 44,
                      child: k.aboneMiyim
                          ? OutlinedButton(
                              onPressed: _abonelikCevir,
                              child: const Text('Abonelikten çık'),
                            )
                          : FilledButton(
                              onPressed: _abonelikCevir,
                              child: const Text('Abone ol'),
                            ),
                    ),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Paylaşılan görseller',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                if (_medya.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: Text(
                      'Bu kanalda henüz görsel paylaşılmamış.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                else
                  // ⚠️ `shrinkWrap` + `NeverScrollable`: izgara DIS `ListView`in
                  //	cocugu; kendi kaydirmasi olsaydi sayfada IKI dikey
                  //	kaydirma alani olurdu (turu 180j'de olculen "sayfa
                  //	takiliyor" hatasinin ta kendisi).
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                    itemCount: _medya.length,
                    itemBuilder: (gc, i) {
                      final m = _medya[i];
                      final video = m.tur == 'video';
                      return GestureDetector(
                        onTap: () => Navigator.of(gc).push(
                          MaterialPageRoute(
                            fullscreenDialog: true,
                            builder: (_) => video
                                ? TamEkranVideo(mediaId: m.id)
                                : TamEkranGorsel(mediaId: m.id),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // ⚠️ Video icin `MedyaGorsel` CIZILMEZ: kanal
                            //	videosunun kapak karesi YOK ve id dogrudan
                            //	verilseydi KIRIK GORSEL cizilirdi (turu 83b).
                            if (video)
                              ColoredBox(
                                color: Colors.white.withValues(alpha: 0.06),
                                child: const Center(
                                  child: Icon(LucideIcons.play, size: 26),
                                ),
                              )
                            else
                              MedyaGorsel(
                                mediaId: m.id,
                                kucuk: true,
                                fit: BoxFit.cover,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _sayi(BuildContext c, String deger, String etiket) => Column(
    children: [
      Text(
        deger,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 2),
      Text(
        etiket,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    ],
  );
}
