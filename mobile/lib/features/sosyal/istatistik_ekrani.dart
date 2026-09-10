import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../isletme/kategori_kabuk.dart' show YemekHeader;
import '../medya/medya_gorsel.dart';
import 'gonderi_karti.dart' show sayiBicimle;
import 'sosyal_servisi.dart';

/// ⚠️⚠️⚠️ TURU 180ae — **ISTATISTIK EKRANI** (kullanici emri: *"disin soluna
/// istatistik alani ekle ve istatistik sayfasini olustur"*).
///
/// ═══════════ ONCE OLCULDU: HANGI VERI GERCEKTEN VAR ═══════════
///
/// · **Kullanici bazli istatistik UCU YOK** (backend grep): yalnizca
///   `GET /posts/{id}/istatistik` var ve o TEK gonderiye ait.
/// · `Profil` -> `gonderiSayisi` · `takipciSayisi` · `takipSayisi` GERCEK.
/// · `Gonderi` -> `begeniSayisi` · `yorumSayisi` · `goruntulenme` GERCEK
///   (turu 76'da eklendi, sunucu donduruyor).
///
/// **KARAR:** yeni uc ACILMADI (bu bir ARAYUZ turu). Toplamlar kullanicinin
/// KENDI gonderilerinden **ISTEMCIDE** turetiliyor — sayfa hicbir sayiyi
/// UYDURMUYOR.
///
/// ⚠️⚠️ **YAZILMAYANLAR ve SEBEBI** (turu 135 "uydurma veri" dersi):
///	profil ziyareti · erisim · demografik dagilim · haftalik grafik —
///	HICBIRININ sunucuda karsiligi YOK. Sahte bir grafik cizmek, uzerine
///	karar verilen bir YALAN olurdu. Ekran bunu ACIKCA soyluyor.
/// ⚠️ DURUST SINIR: yalniz YUKLENEN sayfa (ilk 30 gonderi) taranir; sayfa
///	bunu da yaziyor.
class IstatistikEkrani extends ConsumerStatefulWidget {
  const IstatistikEkrani({super.key, this.profil});

  /// ⚠️ Profil DISARIDAN gecirilir: cagiran ekran onu ZATEN yuklemis
  ///	durumda ve ikinci bir istek gereksiz olurdu. `null` ise ekran
  ///	yalniz gonderi toplamlarini gosterir (celiski yaratmaz).
  final Profil? profil;

  @override
  ConsumerState<IstatistikEkrani> createState() => _IstatistikEkraniState();
}

class _IstatistikEkraniState extends ConsumerState<IstatistikEkrani> {
  List<Gonderi>? _gonderiler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    try {
      final p = widget.profil;
      final id = p?.id ?? '';
      if (id.isEmpty) {
        // ⚠️ Kimlik yoksa gonderi cekilemez; ekran BOS ama DURUST kalir.
        setState(() => _gonderiler = const []);
        return;
      }
      final liste = await ref.read(sosyalServisiProvider).kullaniciGonderileri(id);
      if (!mounted) return;
      setState(() => _gonderiler = liste);
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    final p = widget.profil;
    final g = _gonderiler;

    // ⚠️ Toplamlar YUKLENEN gonderilerden; sayfa bunu alt bilgide yaziyor.
    var begeni = 0, yorum = 0, goruntulenme = 0;
    for (final x in g ?? const <Gonderi>[]) {
      begeni += x.begeniSayisi;
      yorum += x.yorumSayisi;
      goruntulenme += x.goruntulenme;
    }
    // ⚠️ En cok begenilenler: kopya liste uzerinde siralanir — gelen liste
    //	yerinde degistirilseydi cagiranin sirasi da BOZULURDU.
    final populer = [...(g ?? const <Gonderi>[])]
      ..sort((a, b) => b.begeniSayisi.compareTo(a.begeniSayisi));

    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'İstatistik',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: _hata != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hata!),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _yukle, child: const Text('Tekrar dene')),
                ],
              ),
            )
          : g == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                if (p != null) ...[
                  _baslik(c, 'Hesap'),
                  Row(
                    children: [
                      _kutu(c, sayiBicimle(p.gonderiSayisi), 'Gönderi',
                          LucideIcons.grid2x2),
                      _kutu(c, sayiBicimle(p.takipciSayisi), 'Takipçi',
                          LucideIcons.users),
                      _kutu(c, sayiBicimle(p.takipSayisi), 'Takip',
                          LucideIcons.userPlus),
                    ],
                  ),
                ],
                _baslik(c, 'Gönderi etkileşimi'),
                Row(
                  children: [
                    _kutu(c, sayiBicimle(goruntulenme), 'Görüntülenme',
                        LucideIcons.eye),
                    _kutu(c, sayiBicimle(begeni), 'Beğeni', LucideIcons.heart),
                    _kutu(c, sayiBicimle(yorum), 'Yorum',
                        LucideIcons.messageCircle),
                  ],
                ),
                if (populer.isNotEmpty) ...[
                  _baslik(c, 'En çok beğenilenler'),
                  for (final x in populer.take(5)) _satir(c, x),
                ],
                // ⚠️⚠️ DURUST SINIR — EKRANDA, serhte DEGIL.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ks.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.info,
                            size: 17,
                            color: ks.onSurface.withValues(alpha: 0.55)),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Toplamlar son ${g.length} gönderiden hesaplandı. '
                            'Profil ziyareti ve erişim verisi henüz '
                            'toplanmıyor.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: ks.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _baslik(BuildContext c, String metin) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    child: Text(
      metin,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Theme.of(c).colorScheme.onSurface,
      ),
    ),
  );

  /// ⚠️ `Expanded`: uc kutu alani ESIT boler — sabit genislik verilseydi
  ///	360 dp'de tasardi ve "1,2 bin" gibi uzun sayilar kirpilirdi.
  Widget _kutu(BuildContext c, String deger, String etiket, IconData ikon) {
    final ks = Theme.of(c).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: kYuzeyKoyu,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(ikon, size: 18, color: ks.primary),
            const SizedBox(height: 7),
            // ⚠️ `FittedBox`: dar hucrede uzun sayi KIRPILMAZ, kuculur.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                deger,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                etiket,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: ks.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _satir(BuildContext c, Gonderi g) {
    final ks = Theme.of(c).colorScheme;
    final kapak = g.mediaIds.isNotEmpty ? g.mediaIds.first : '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(
        width: 46,
        height: 46,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          // ⚠️ Medyasi olmayan gonderide KIRIK GORSEL cizilmez: notr kutu.
          child: kapak.isEmpty
              ? ColoredBox(
                  color: ks.onSurface.withValues(alpha: 0.08),
                  child: Icon(LucideIcons.type,
                      size: 18, color: ks.onSurface.withValues(alpha: 0.5)),
                )
              : MedyaGorsel(mediaId: kapak, kucuk: true, fit: BoxFit.cover),
        ),
      ),
      title: Text(
        g.metin.trim().isEmpty ? 'Görsel gönderi' : g.metin.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14.5),
      ),
      subtitle: Text(
        '${sayiBicimle(g.begeniSayisi)} beğeni · '
        '${sayiBicimle(g.yorumSayisi)} yorum',
        style: TextStyle(
          fontSize: 12.5,
          color: ks.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
