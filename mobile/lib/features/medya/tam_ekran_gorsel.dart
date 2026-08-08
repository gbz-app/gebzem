import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'medya_gorsel.dart';

/// TURU 74 — tam ekran fotoğraf görüntüleyici (yakınlaştırma + kaydırarak kapatma).
///
/// ⚠️ Burada **küçük resim değil TAM çözünürlük** indirilir (`kucuk: false`):
///     balonda küçüğü gösterip burada da küçüğü göstermek "büyüttüm ama bulanık"
///     demek olurdu.
/// ⚠️ Arayüzde emoji yok — Lucide.
class TamEkranGorsel extends StatelessWidget {
  const TamEkranGorsel({super.key, required this.mediaId});

  final String mediaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          // ⚠️ `minScale: 1` — küçültüp kaybetmeyi engeller.
          minScale: 1,
          maxScale: 4,
          child: MedyaGorsel(mediaId: mediaId, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
