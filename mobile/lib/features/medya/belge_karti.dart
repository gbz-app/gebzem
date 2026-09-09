import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import 'medya_servisi.dart';

/// ⚠️⚠️⚠️ TURU 180z — **BELGE KARTI** (kullanici emri: *"kanalda sadece gorsel
/// degil video BELGE vs de paylasiliyor"*).
///
/// Kanal gonderisinde / sohbette bir `document` medyasini temsil eder:
/// ikon + ad + "Aç" ipucu. Dokununca imzali adres alinip **CIHAZIN KENDI
/// uygulamasinda** acilir.
///
/// ⚠️⚠️ **UYGULAMA ICI GORUNTULEYICI YOK VE BU BILINCLI.** PDF/Word/Excel
///	goruntuleyici gomsek (`flutter_pdfview` vb.) her tur icin AYRI paket
///	ve platform kodu gerekirdi; `.docx`/`.xlsx` icin Flutter'da calisan
///	bir cozum zaten YOK. Cihazin kendi uygulamasina devretmek DURUST ve
///	her turu acar.
///
/// ⚠️ **AD SUNUCUDAN GELMIYOR**: `GET /channels/{id}/posts` yalniz `media_ids`
///	+ `media_kinds` donduruyor; `media_assets.file_name` sutunu VAR ama
///	hicbir liste ucu onu tasimiyor. Bu yuzden kart, `/media/{id}/url`
///	yanitindaki **`mime`** alanindan tur adini turetir ("PDF belgesi",
///	"Word belgesi"...) ve UYDURMA bir dosya adi YAZMAZ (turu 135 dersi:
///	sunucuda karsiligi olmayan veriyi gercekmis gibi gosterme).
///	⏳ Gercek dosya adi icin sunucunun `file_name`i liste yanitlarina
///	  eklemesi gerekir — AYRI IS (backend turu).
class BelgeKarti extends ConsumerStatefulWidget {
  const BelgeKarti({
    super.key,
    required this.mediaId,
    this.ad = '',
    this.kompakt = false,
  });

  final String mediaId;

  /// Biliniyorsa gercek dosya adi (sohbette `content` alani tasiyabilir).
  /// Bos ise MIME'den turetilen notr bir ad kullanilir.
  final String ad;

  /// Liste satiri gorunumu (kanal profili "Belgeler" bolumu) — kart yerine
  /// tek satir cizer.
  final bool kompakt;

  @override
  ConsumerState<BelgeKarti> createState() => _BelgeKartiState();
}

class _BelgeKartiState extends ConsumerState<BelgeKarti> {
  bool _mesgul = false;
  String _tur = '';

  @override
  void initState() {
    super.initState();
    _turuCoz();
  }

  /// MIME'i cekip insan okunur tur adina cevirir.
  ///
  /// ⚠️ Bu istek DOSYAYI INDIRMEZ — yalnizca imzali adres + mime doner
  ///	(`/media/{id}/url`). Yine de hata YUTULUR: tur adi bir SUS, kartin
  ///	calismasi buna bagli DEGIL.
  Future<void> _turuCoz() async {
    try {
      final d = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      final m = (d['mime'] as String?) ?? '';
      if (!mounted) return;
      setState(() => _tur = _mimeAdi(m));
    } catch (_) {
      // sessiz: tur adi olmadan da kart calisir
    }
  }

  static String _mimeAdi(String m) {
    if (m.contains('pdf')) return 'PDF belgesi';
    if (m.contains('word') || m.contains('msword')) return 'Word belgesi';
    if (m.contains('sheet') || m.contains('excel')) return 'Excel belgesi';
    if (m.startsWith('text/')) return 'Metin dosyası';
    return 'Belge';
  }

  Future<void> _ac() async {
    // ⚠️ Yeniden girme kapisi: cift dokunus IKI imzali adres istegi ve IKI
    //	harici uygulama acilisi uretirdi (turu 141 dersi).
    if (_mesgul) return;
    setState(() => _mesgul = true);
    try {
      final d = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      final u = d['url'] as String?;
      if (u == null) throw Exception('adres yok');
      final uri = Uri.parse(u);
      // ⚠️ `externalApplication`: dosyayi cihazin kendi uygulamasi acsin.
      //	`platformDefault` Android'de uygulama ici WebView'e dusebilir ve
      //	orada PDF acilmaz.
      final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!acildi) {
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Bu dosyayı açacak uygulama bulunamadı')),
        );
      }
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baslik = widget.ad.isNotEmpty
        ? widget.ad
        : (_tur.isEmpty ? 'Belge' : _tur);
    final alt = widget.ad.isNotEmpty && _tur.isNotEmpty ? _tur : 'Açmak için dokun';

    if (widget.kompakt) {
      return ListTile(
        onTap: _mesgul ? null : _ac,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: _ikon(scheme),
        title: Text(
          baslik,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          alt,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: _mesgul
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
      );
    }

    return Material(
      color: scheme.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _mesgul ? null : _ac,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _ikon(scheme),
              const SizedBox(width: 12),
              // ⚠️ `Expanded` + ellipsis: uzun dosya adi satiri TASIRDI
              //	(kart bir `AspectRatio` icinde cizilebiliyor).
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      baslik,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alt,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (_mesgul)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  LucideIcons.download,
                  size: 18,
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ikon(ColorScheme scheme) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(LucideIcons.fileText, size: 21, color: scheme.primary),
  );
}
