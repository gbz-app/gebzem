library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// ⚠️⚠️⚠️ TURU 105 — **AYAR LISTESI BILESENLERI** (kullanici emri + referans
///	ekran goruntusu: *"profil ayarlarini boyle yap; profile tikladiginda
///	profile gitsin"*).
///
/// Referans duzen (iOS Ayarlar / gonderilen mockup):
///   · ustte **profil karti** — avatar + ad + alt bilgi, dokununca PROFILE gider
///   · altinda **gruplanmis kartlar**: her grubun ustunde kucuk bir bolum
///     basligi, grup icinde satirlar ve satirlar arasinda **ince ayrac**
///   · satir = ikon + baslik + (opsiyonel deger) + **chevron**
///
/// ⚠️ Eski hal duz bir `ListTile` yigindi: 20'den fazla satir hicbir gruplama
///    olmadan alt alta diziliyordu ve kullanici aradigini bulamiyordu.
///
/// ⚠️⚠️ **TEK KAYNAK:** bu bilesenler hem Profil sekmesinde hem Ayarlar
///	ekraninda kullanilir. Iki ekran ayri ayri stillenirse KACINILMAZ olarak
///	drift eder (bu projede kayitli en sik hata sinifi).
/// ⚠️ `letterSpacing` KULLANILMAZ (kullanici emri, CLAUDE.md).

/// Bolum basligi + gruplanmis kart.
///
/// ⚠️ Bos `satirlar` ile cagrilirsa **HICBIR SEY cizmez**: kosullu satirlari
///    (yalniz isletme hesabinda gorunenler gibi) filtreleyen cagri yerinde
///    bos bir baslik + bos bir kart kalmasin.
class AyarBolumu extends StatelessWidget {
  const AyarBolumu({super.key, required this.baslik, required this.satirlar});

  final String baslik;
  final List<Widget> satirlar;

  @override
  Widget build(BuildContext context) {
    if (satirlar.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(
            baslik,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
            border: Border.all(color: scheme.onSurface.withValues(alpha: 0.07)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                for (var i = 0; i < satirlar.length; i++) ...[
                  satirlar[i],
                  // ⚠️ Ayrac ikonun HIZASINDAN baslar (referans duzen): tam
                  //    genislikte cizilirse kart ikiye bolunmus gibi gorunur.
                  if (i != satirlar.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 52),
                      child: Divider(
                        height: 1,
                        thickness: 0.5,
                        color: scheme.onSurface.withValues(alpha: 0.08),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Tek ayar satiri: ikon + baslik + (alt baslik) + (deger) + chevron.
class AyarSatiri extends StatelessWidget {
  const AyarSatiri({
    super.key,
    required this.ikon,
    required this.baslik,
    this.altBaslik,
    this.deger,
    this.onTap,
    this.tehlikeli = false,
    this.secili = false,
  });

  final IconData ikon;
  final String baslik;
  final String? altBaslik;

  /// Sagda, chevron'un solunda gosterilen **mevcut deger** ("Açık", "Gece"...).
  final String? deger;

  final VoidCallback? onTap;

  /// Yikici eylem (Cikis yap) — kirmizi.
  final bool tehlikeli;

  /// Secim listesinde secili satir: chevron yerine **tik**.
  final bool secili;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final renk = tehlikeli ? scheme.error : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        // ⚠️ Dikey 14 + icerik ~24 = 52 dp: Material dokunma minimumunun (48)
        //    ustunde, referanstaki sik satir yuksekliginde.
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Icon(ikon, size: 22, color: renk.withValues(alpha: 0.85)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    baslik,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: renk,
                    ),
                  ),
                  if ((altBaslik ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      altBaslik!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if ((deger ?? '').isNotEmpty) ...[
              const SizedBox(width: 8),
              // ⚠️ Deger KISALABILIR (uzun sehir adi gibi) ama basligi
              //    ezmemeli: bu yuzden `Flexible` DEGIL sabit tavan.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  deger!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            // ⚠️ Secili satirda chevron YERINE tik: "buraya girilir" ile
            //    "bu secili" farkli seylerdir, ayni isaretle anlatilamaz.
            if (secili)
              Icon(LucideIcons.check, size: 18, color: scheme.primary)
            else if (onTap != null && !tehlikeli)
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.onSurface.withValues(alpha: 0.35),
              )
            else
              const SizedBox(width: 18),
          ],
        ),
      ),
    );
  }
}

/// Ustteki **profil karti** — dokununca kendi profiline gider.
///
/// ⚠️ Kullanici emri: *"profile tikladiginda profile gitsin"*. Eski halde
///    ustteki avatar + ad SALT DEKORATIFTI; profile gitmek icin listede ayri
///    bir satir aramak gerekiyordu.
class ProfilKarti extends StatelessWidget {
  const ProfilKarti({
    super.key,
    required this.cocuk,
    required this.onTap,
  });

  final Widget cocuk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.40),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: 0.07),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: cocuk,
        ),
      ),
    );
  }
}
