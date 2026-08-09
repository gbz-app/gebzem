import 'package:flutter/material.dart';

/// ⚠️⚠️ TURU 76b — ANASAYFA SOL UST MENU (kullanici emri: *"anasayfada sol
/// ustte menu ikonu olsun, 2 tane 2 satir cizgi hamburger tarzi; tikladigimda
/// yemek, restoran, alisveris kartlar olsun; ikon YOK, kart altinda yazi
/// sadece"*).
///
/// ⚠️⚠️ KARTLARDA IKON YOK — KULLANICI ACIKCA BOYLE ISTEDI. Kart bir gorsel
///    zemin + ALTINDA yazidir. Bir ikon/emoji eklemek emri ihlal eder.
///    ⚠️ YAPMA: kartlarin icine ikon koyma.
///
/// ⚠️ HENUZ ICERIK YOK: bu bolumler (Yemek / Restoran / Alisveris) urun olarak
///    tanimlanmadi. Bos bir ekrana goturup kullaniciyi cikmaza sokmak yerine
///    DURUST bir "yakinda" bildirimi gosteriliyor.
///    ⚠️ YAPMA: kartlari "calisiyormus gibi" bos bir sayfaya baglama —
///    bu projede "ozellik var gorunup fiilen yok" tekrarlayan bir hata.
class HizmetMenusu extends StatelessWidget {
  const HizmetMenusu({super.key});

  static const _kartlar = <_Hizmet>[
    _Hizmet('Yemek', [Color(0xFFFF7A45), Color(0xFFFF3B5C)]),
    _Hizmet('Restoran', [Color(0xFF8B3FFF), Color(0xFF5A1EBE)]),
    _Hizmet('Alışveriş', [Color(0xFF2BB673), Color(0xFF12805A)]),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Gebzem',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text(
              'Şehrindeki her şey',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // ⚠️ Uc kart YAN YANA — dikey liste, "kart" olarak istenen gorunumu
            //    vermez. Dar ekranda da (360dp) her kart ~100dp kalir.
            Row(
              children: [
                for (var i = 0; i < _kartlar.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _kart(context, _kartlar[i])),
                ],
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Bu bölümler yakında açılıyor.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kart(BuildContext context, _Hizmet h) => GestureDetector(
    onTap: () {
      final m = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      m.showSnackBar(SnackBar(content: Text('${h.ad} yakında')));
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ⚠️ IKONSUZ kart: yalnizca renk gecisli zemin (kullanici emri).
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: h.renkler,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ⚠️ Yazi KARTIN ALTINDA (icinde DEGIL) — kullanici emri.
        Text(
          h.ad,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _Hizmet {
  const _Hizmet(this.ad, this.renkler);
  final String ad;
  final List<Color> renkler;
}

/// Anasayfa AppBar'inin sol ustundeki hamburger dugmesi.
///
/// ⚠️ IKI CIZGI (kullanici emri: "2 tane 2 satir cizgi hamburger tarzi").
///    Lucide'in `menu` ikonu UC cizgidir; bu yuzden ikon KULLANILMADI, iki
///    cizgi ELLE cizildi.
/// ⚠️ YAPMA: `LucideIcons.menu` koyma (uc cizgi olur).
class HamburgerDugmesi extends StatelessWidget {
  const HamburgerDugmesi({super.key});

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).iconTheme.color;
    return IconButton(
      tooltip: 'Menü',
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: false,
        builder: (_) => const HizmetMenusu(),
      ),
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cizgi(renk, 20),
          const SizedBox(height: 5),
          _cizgi(renk, 14),
        ],
      ),
    );
  }

  Widget _cizgi(Color? renk, double genislik) => Container(
    width: genislik,
    height: 2,
    decoration: BoxDecoration(
      color: renk,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}
