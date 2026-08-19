library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYanBosluk;
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'demo_veri.dart' show kDemoAkis, demoKimlik;
import 'demo_yorum.dart';
import 'gonderi_karti.dart' show sayiBicimle, gonderiZamani;
import 'sosyal_servisi.dart';
import 'yorum_satiri.dart';

/// ⚠️⚠️⚠️ TURU 100 — **ALTTAN ACILAN YORUM PANELI** (kullanici emri +
///	X/Twitter ekran goruntusu: *"yoruma basinca alttan gelecek, thread
///	mantigi da var"*).
///
/// X duzeni: ustte gonderinin ozeti (yazar · metin · zaman · sayilar),
/// altinda **Alakalı ⌄ / Alıntıları görüntüle ›** satiri, sonra threadli
/// yanitlar, en altta **"Yanıtını gönder"** kutusu.
///
/// ⚠️⚠️ **VERI DURUSTLUGU:** yorumlar bugun DEMO verisinden geliyor
///	(`kDemoAkis`). Gercek hat `YorumlarSayfasi`da duruyor ve DEGISMEDI;
///	buraya baglanmasi icin sunucunun donmesi gerekenler:
///	  · yorum begenisi (`comment_likes` tablosu VAR ama INSERT/DELETE ucu
///	    YOK — bugun `begendim` DAIMA false),
///	  · alt yanit SAYISI, · siralama parametresi, · alinti sayaci.
/// ⚠️ YAPMA: `kDemoAkis` kapaliyken buraya sahte yorum cizme.
class YorumPaneli extends ConsumerStatefulWidget {
  const YorumPaneli({super.key, required this.gonderi, required this.benimId});

  final Gonderi gonderi;
  final String benimId;

  @override
  ConsumerState<YorumPaneli> createState() => _YorumPaneliState();
}

class _YorumPaneliState extends ConsumerState<YorumPaneli> {
  final Set<String> _acik = <String>{};

  /// ⚠️ TURU 102 — GERCEK gonderide gercek yorumlar. Panel Reels'ten aciliyor
  ///    ve Reels **gercek** videolari listeliyor; turu 101'de burada
  ///    `kDemoAkis` genel bayragina bakiliyordu, yani GERCEK bir videonun
  ///    altinda DEMO yorumlari cizilebiliyordu.
  List<YorumGorunum>? _gercek;

  /// 'alakali' · 'yakin'
  String _sirala = 'alakali';

  @override
  void initState() {
    super.initState();
    if (!demoKimlik(widget.gonderi.id)) unawaited(_cek());
  }

  Future<void> _cek() async {
    try {
      final l = await ref.read(sosyalServisiProvider).yorumlar(widget.gonderi.id);
      if (!mounted) return;
      setState(
        () => _gercek = yorumAgaci(
          l,
          yazarKullaniciAdi: widget.gonderi.yazarUsername,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _gercek = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gonderi;
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurface.withValues(alpha: 0.55);
    final yorumlar = _yorumlar();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ---- GONDERI OZETI
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kYanBosluk,
                  4,
                  kYanBosluk,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const MiniAvatar(cap: 34),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            g.yazarAd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          gonderiZamani(g.createdAt),
                          style: TextStyle(fontSize: 13, color: soluk),
                        ),
                      ],
                    ),
                    if (g.metin.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(g.metin, style: const TextStyle(fontSize: 15)),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _sayi(LucideIcons.messageCircle, g.yorumSayisi, soluk),
                        const SizedBox(width: 18),
                        _sayi(LucideIcons.redo2, g.repostSayisi, soluk),
                        const SizedBox(width: 18),
                        _sayi(LucideIcons.heart, g.begeniSayisi, soluk),
                        const SizedBox(width: 18),
                        _sayi(LucideIcons.eye, g.goruntulenme, soluk),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.5,
                color: tema.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              // ---- SIRALAMA + ALINTILAR (X duzeni)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  kYanBosluk,
                  8,
                  kYanBosluk,
                  4,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _siralaSec,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sirala == 'alakali' ? 'Alakalı' : 'Yakınlarda',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(LucideIcons.chevronDown, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // ⚠️ ALINTI ALTYAPISI YOK (ne tablo ne uc): satir yalniz
                    //    demo modunda cizilir ve durustce "yok" der.
                    if (kDemoAkis)
                      InkWell(
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Alıntı altyapısı henüz yok — tasarım demosu',
                            ),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Alıntıları görüntüle',
                                style: TextStyle(fontSize: 14, color: soluk),
                              ),
                              Icon(
                                LucideIcons.chevronRight,
                                size: 16,
                                color: soluk,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (yorumlar.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50),
                  child: Center(
                    child: Text(
                      'Henüz yanıt yok',
                      style: TextStyle(fontSize: 15, color: soluk),
                    ),
                  ),
                )
              else
                for (final y in yorumlar) ...[
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: tema.colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                  YorumGrubu(
                    kok: y,
                    acik: _acik.contains(y.id),
                    onYanitlariGoster: () => setState(() {
                      _acik.contains(y.id)
                          ? _acik.remove(y.id)
                          : _acik.add(y.id);
                    }),
                  ),
                ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        // ---- "Yanıtını gönder"
        Divider(
          height: 1,
          thickness: 0.5,
          color: tema.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kYanBosluk, 8, kYanBosluk, 8),
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: tema.colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                'Yanıtını gönder',
                style: TextStyle(fontSize: 15, color: soluk),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sayi(IconData ikon, int n, Color renk) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(ikon, size: 17, color: renk),
      if (n > 0) ...[
        const SizedBox(width: 5),
        Text(
          sayiBicimle(n),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: renk,
          ),
        ),
      ],
    ],
  );

  /// ⚠️ Cevrim + siralama TEK KAYNAKTAN (`demoYorumGorunumleri`).
  List<YorumGorunum> _yorumlar() => demoKimlik(widget.gonderi.id)
      ? demoYorumGorunumleri(
          widget.gonderi.id,
          widget.gonderi.yazarUsername,
          begeniyeGore: _sirala == 'alakali',
        )
      : (_gercek ?? const []);

  Future<void> _siralaSec() async {
    final s = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in const [
              ('alakali', 'Alakalı'),
              ('yakin', 'Yakınlarda'),
            ])
              ListTile(
                title: Text(o.$2, style: const TextStyle(fontSize: 16)),
                trailing: _sirala == o.$1
                    ? const Icon(LucideIcons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(c, o.$1),
              ),
          ],
        ),
      ),
    );
    if (s != null && mounted) setState(() => _sirala = s);
  }
}
