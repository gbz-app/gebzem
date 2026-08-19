library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYuzeyGri, kYanBosluk;
import 'demo_veri.dart' show kDemoAkis;
import 'demo_yorum.dart' show demoYorumlar;
import 'gonderi_karti.dart' show sayiBicimle, gonderiZamani;
import 'sosyal_servisi.dart';

/// ⚠️⚠️⚠️ TURU 99 — **GONDERI HAREKETLERI** ekrani (kullanici emri + Threads
///	ekran goruntusu: *"Hareketi gor"*).
///
/// Threads duzeni: ustte gonderinin ozeti kutu icinde; altinda eylem satirlari
/// (avatar + sol altinda EYLEM ROZETI · kullanici adi + sure · gercek ad ·
/// takipci sayisi · sagda "Takip Et"); AppBar'da "Sırala".
///
/// ⚠️⚠️ **BU EKRAN BUGUN DEMO VERISIYLE CIZILIR.** Sunucuda:
///	· begenenler listesi VAR (`GET /posts/{id}/likes`) ama TAKIPCI SAYISI
///	  ve ORTAK TAKIPCI DONMEZ (backend'de `mutual`/`ortak` gecen tek satir
///	  bile yok),
///	· REPOST/ALINTI diye bir sey YOK (ne tablo ne uc) — bu yuzden Threads'in
///	  "Yeniden gönderiler" / "Alıntılar" sekmeleri **YAZILMADI**; kalici bos
///	  iki sekme, turu 93b'nin "dolu ama hicbir seyle eslesmeyen alan"
///	  hatasinin aynisi olurdu.
/// ⚠️ YAPMA: `kDemoAkis` kapaliyken buraya sahte satir cizme.
class GonderiHareketleri extends StatefulWidget {
  const GonderiHareketleri({super.key, required this.gonderi});

  final Gonderi gonderi;

  @override
  State<GonderiHareketleri> createState() => _GonderiHareketleriState();
}

class _GonderiHareketleriState extends State<GonderiHareketleri> {
  /// 'tumu' · 'begeni' · 'yanit'
  String _suzgec = 'tumu';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurface.withValues(alpha: 0.55);
    final satirlar = _satirlar();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Gönderi hareketleri',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _siralaSec,
            child: const Text('Sırala', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ---- GONDERININ OZETI (Threads: ustte kutu icinde)
          Padding(
            padding: const EdgeInsets.fromLTRB(kYanBosluk, 12, kYanBosluk, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tema.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _Daire(cap: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.gonderi.yazarUsername.isEmpty
                              ? widget.gonderi.yazarAd
                              : widget.gonderi.yazarUsername,
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
                        gonderiZamani(widget.gonderi.createdAt),
                        style: TextStyle(fontSize: 13, color: soluk),
                      ),
                    ],
                  ),
                  if (widget.gonderi.metin.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.gonderi.metin,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (satirlar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Text(
                  kDemoAkis
                      ? 'Henüz hareket yok'
                      : 'Hareket listesi henüz sunucudan gelmiyor',
                  style: TextStyle(fontSize: 15, color: soluk),
                ),
              ),
            )
          else
            for (final h in satirlar) _HareketSatiri(h: h),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// ⚠️ Demo satirlari mevcut demo yorumlarindan TURETILIR — ikinci bir sahte
  ///    kullanici listesi yazmak iki veri kaynagi demekti.
  List<_Hareket> _satirlar() {
    if (!kDemoAkis) return const [];
    final y = demoYorumlar(widget.gonderi.id);
    final l = <_Hareket>[
      for (final k in y)
        _Hareket(
          kullaniciAdi: k.kullaniciAdi,
          ad: k.ad,
          zaman: k.zaman,
          takipci: 60 + k.metin.length * 7,
          begeni: true,
        ),
      for (final k in y.take(2))
        _Hareket(
          kullaniciAdi: k.kullaniciAdi,
          ad: k.ad,
          zaman: k.zaman,
          takipci: 60 + k.metin.length * 7,
          begeni: false,
        ),
    ];
    return switch (_suzgec) {
      'begeni' => l.where((h) => h.begeni).toList(),
      'yanit' => l.where((h) => !h.begeni).toList(),
      _ => l,
    };
  }

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
              ('tumu', 'Tümü'),
              ('begeni', 'Beğeniler'),
              ('yanit', 'Yanıtlar'),
            ])
              ListTile(
                title: Text(o.$2, style: const TextStyle(fontSize: 16)),
                trailing: _suzgec == o.$1
                    ? const Icon(LucideIcons.check, size: 18)
                    : null,
                onTap: () => Navigator.pop(c, o.$1),
              ),
          ],
        ),
      ),
    );
    if (s != null && mounted) setState(() => _suzgec = s);
  }
}

class _Hareket {
  const _Hareket({
    required this.kullaniciAdi,
    required this.ad,
    required this.zaman,
    required this.takipci,
    required this.begeni,
  });

  final String kullaniciAdi;
  final String ad;
  final String zaman;
  final int takipci;

  /// true = begendi (pembe kalp rozeti) · false = yanitladi (balon rozeti)
  final bool begeni;
}

/// Threads hareket satiri: avatar + sol altinda EYLEM ROZETI · ad · takipci ·
/// sagda "Takip Et".
class _HareketSatiri extends StatefulWidget {
  const _HareketSatiri({required this.h});
  final _Hareket h;

  @override
  State<_HareketSatiri> createState() => _HareketSatiriState();
}

class _HareketSatiriState extends State<_HareketSatiri> {
  bool _takip = false;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final soluk = tema.colorScheme.onSurface.withValues(alpha: 0.55);
    final h = widget.h;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kYanBosluk, 10, kYanBosluk, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- AVATAR + EYLEM ROZETI (sol alt)
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const _Daire(cap: 46),
                Positioned(
                  left: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: h.begeni
                          ? const Color(0xFFFF3B5C)
                          : tema.colorScheme.primary,
                      border: Border.all(
                        color: tema.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      h.begeni ? Icons.favorite : LucideIcons.messageCircle,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        h.kullaniciAdi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(h.zaman, style: TextStyle(fontSize: 13, color: soluk)),
                  ],
                ),
                Text(
                  h.ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: soluk),
                ),
                const SizedBox(height: 4),
                // ⚠️ ORTAK TAKIPCI AVATARLARI **YOK**: backend'de mutual
                //    takipci sorgusu bulunmuyor. Sahte yuz dizmek yerine
                //    yalniz takipci sayisi yaziliyor.
                Text(
                  '${sayiBicimle(h.takipci)} takipçi',
                  style: TextStyle(fontSize: 13, color: soluk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // ---- TAKIP ET
          // ⚠️ Demo satirinda sunucuya GITMEZ; yalniz dugme durumu doner.
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => setState(() => _takip = !_takip),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                side: BorderSide(
                  color: tema.colorScheme.onSurface.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                _takip ? 'Takiptesin' : 'Takip Et',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fotografsiz avatar: **harf yok**, duz gri daire (turu 98d kurali).
class _Daire extends StatelessWidget {
  const _Daire({required this.cap});
  final double cap;

  @override
  Widget build(BuildContext context) => Container(
    width: cap,
    height: cap,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: kYuzeyGri(context),
    ),
  );
}
