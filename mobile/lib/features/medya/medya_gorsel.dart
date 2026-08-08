import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'medya_servisi.dart';

/// ⚠️⚠️ TURU 74 — İMZALI MEDYA GÖRÜNTÜLEYİCİ.
///
/// Sorun: bucket **private**, indirme adresi **600 saniye ömürlü imzalı URL**.
/// Bu yüzden doğrudan `Image.network(url)` KULLANILAMAZ:
///   · URL her çağrıda değişir → `cached_network_image` onu YENİ görsel sanar ve
///     aynı fotoğrafı **her açılışta yeniden indirir** (kullanıcının mobil verisi
///     + R2 Class B ücreti),
///   · URL süresi dolunca görsel kırık görünür.
///
/// Çözüm: adres `media_id`'ye göre alınır, **önbellek anahtarı `media_id`'dir**
/// (URL değil). Böylece imza değişse de dosya bir kez inip cihazda kalır.
/// ⚠️ YAPMA: `cacheKey`i kaldırma; URL'i önbellek anahtarı yapma.
///
/// ⚠️ Adres 600 sn geçerli olduğu için bellekte kısa süreli tutulur; süresi
///     dolmadan yeniden istenmez (`_adresOnbellek`).
class MedyaGorsel extends ConsumerStatefulWidget {
  const MedyaGorsel({
    super.key,
    required this.mediaId,
    this.kucuk = false,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.radius = 0,
  });

  final String mediaId;

  /// Küçük resim (thumb) mi istensin. Liste/balon için `true` — tam çözünürlüklü
  /// dosyayı indirmek gereksiz veri harcar.
  final bool kucuk;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double radius;

  @override
  ConsumerState<MedyaGorsel> createState() => _MedyaGorselState();
}

/// media_id -> (url, sonKullanma). Süreç ömürlü, küçük.
final _adresOnbellek = <String, ({String url, DateTime bitis})>{};

/// ⚠️ TURU 74b: çıkışta temizlenir — hesap değişince önceki hesabın imzalı
///     adresleri 600 sn bellekte kalıyordu.
void medyaAdresOnbelleginiTemizle() => _adresOnbellek.clear();

class _MedyaGorselState extends ConsumerState<MedyaGorsel> {
  String? _url;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    _adresAl();
  }

  @override
  void didUpdateWidget(covariant MedyaGorsel eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Liste geri dönüşümünde (ListView) aynı widget farklı media_id ile
    //     yeniden kullanılır — adresi TAZELEMEZSEK yanlış görsel çizilir.
    if (eski.mediaId != widget.mediaId || eski.kucuk != widget.kucuk) {
      _url = null;
      _hata = false;
      _adresAl();
    }
  }

  Future<void> _adresAl() async {
    final anahtar = '${widget.mediaId}:${widget.kucuk}';
    // ⚠️ TURU 74b: süresi geçmiş kayıtları ayıkla — global harita hiç
    //    tahliye edilmiyordu, uzun oturumda monoton büyüyordu.
    if (_adresOnbellek.length > 200) {
      final simdi = DateTime.now();
      _adresOnbellek.removeWhere((_, v) => v.bitis.isBefore(simdi));
    }
    final onbellek = _adresOnbellek[anahtar];
    // ⚠️ 60 sn pay: indirme başlarken imzanın dolmasına yakın olmasın.
    if (onbellek != null &&
        onbellek.bitis.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      if (mounted) setState(() => _url = onbellek.url);
      return;
    }
    try {
      final d = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      final u = (widget.kucuk ? d['thumb_url'] : d['url']) as String? ??
          d['url'] as String?;
      if (u == null) throw Exception('adres yok');
      final sn = (d['expires_sec'] as num?)?.toInt() ?? 600;
      _adresOnbellek[anahtar] =
          (url: u, bitis: DateTime.now().add(Duration(seconds: sn)));
      if (mounted) setState(() => _url = u);
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget ic;
    if (_hata) {
      ic = _kutu(const Icon(LucideIcons.imageOff, size: 22, color: Colors.white54));
    } else if (_url == null) {
      ic = _kutu(const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2)));
    } else {
      ic = CachedNetworkImage(
        imageUrl: _url!,
        // ⚠️⚠️ SABIT ANAHTAR — bkz. sınıf şerhi. URL değişse de aynı dosya.
        cacheKey: medyaOnbellekAnahtari(widget.mediaId, kucuk: widget.kucuk),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (_, _) => _kutu(const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, _, _) =>
            _kutu(const Icon(LucideIcons.imageOff, size: 22, color: Colors.white54)),
      );
    }
    if (widget.radius > 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: ic);
    }
    return ic;
  }

  Widget _kutu(Widget cocuk) => Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0x22000000),
        alignment: Alignment.center,
        child: cocuk,
      );
}

/// Profil fotoğrafı — `avatar_media_id` varsa R2'den, yoksa harfli yedek.
/// ⚠️ Eski kayıtlarda `avatar_url` dolu olabilir; o alan artık YALNIZCA sunucu
///     tarafından yazılır (turu 74 güvenlik kararı) ve okunmaya devam eder.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.ad,
    this.mediaId,
    this.avatarUrl = '',
    this.cap = 44,
  });

  final String ad;
  final String? mediaId;
  final String avatarUrl;
  final double cap;

  @override
  Widget build(BuildContext context) {
    if (mediaId != null && mediaId!.isNotEmpty) {
      return SizedBox(
        width: cap,
        height: cap,
        child: MedyaGorsel(
          mediaId: mediaId!,
          kucuk: true,
          width: cap,
          height: cap,
          radius: cap / 2,
        ),
      );
    }
    final harf = ad.trim().isEmpty ? '?' : ad.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: cap / 2,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isNotEmpty
          ? null
          : Text(harf, style: TextStyle(fontSize: cap * 0.4)),
    );
  }
}
