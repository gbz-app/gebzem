library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../isletme/isletme_kart.dart' show kYuzeyGri, kYanBosluk;

/// ⚠️⚠️⚠️ TURU 98l — GONDERI ve REKLAM icin **••• MENUSU** (kullanici emri +
///	Threads/Facebook ekran goruntuleri: *"gonderi ve reklamlardaki 3 noktaya
///	bastigimizda bunlar cikmasi gerekiyor, mimari nasil olmasi gerekiyorsa
///	oyle yap"*).
///
/// **GORUNUM DILI (referanstan):** yuvarlak koseli GRUP KARTLARI, grup icinde
/// ince ayraclar, baslik SOLDA, ikon SAGDA; yikici maddeler (Engelle/Sikayet)
/// KIRMIZI. Reklam menusunde ikon SOLDA ve maddenin altinda aciklama satiri.
///
/// ⚠️⚠️ **HANGI MADDE GERCEKTEN CALISIYOR** (bu projede "arayuz var, veri yok"
///	en pahali hata sinifi — CLAUDE.md'de alti kez kayitli):
///	  · Baglantiyi kopyala · Kaydet · Engelle · Sikayet et · Duzenle ·
///	    Istatistik · Sil  -> **SUNUCUDA VAR**, gercekten calisir.
///	  · Ilgilenmiyorum · Sessize al · Kisitla -> **SUNUCUDA YOK.** Maddeler
///	    kullanici istedigi icin duruyor ama dokunulunca ne yaptigini
///	    DURUSTCE soyluyor; sessizce hicbir sey yapmiyor gibi davranmiyor.
///	  · Reklam maddelerinin TAMAMI demo: `reklamlar` tablosu ACILMADI
///	    (turu 78 karari — icerigini girecek yol yok).
/// ⚠️ YAPMA: calismayan bir maddeyi "calisiyormus gibi" sessizce kapatma.
enum MenuSecim {
  kopyala,
  kaydet,
  ilgilenmiyorum,
  sessize,
  kisitla,
  engelle,
  sikayet,
  duzenle,
  istatistik,
  sil,
  // ---- reklam
  reklamIlgimiCekiyor,
  reklamIlgimiCekmiyor,
  reklamGizle,
  reklamSikayet,
  reklamNeden,
  reklamHakkinda,
}

/// Gonderi ••• menusu.
///
/// [benimGonderim] true ise Duzenle/Istatistik/Sil grubu EN USTE gelir.
/// [sponsorlu] true ise **REKLAM MENUSU** cizilir (Facebook duzeni).
Future<MenuSecim?> gonderiMenusuAc(
  BuildContext context, {
  required bool benimGonderim,
  bool sponsorlu = false,
  bool kaydedildi = false,
}) {
  return showModalBottomSheet<MenuSecim>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    showDragHandle: true,
    // ⚠️ `isScrollControlled` ZORUNLU: yazi olcegi 1.5-2.0'da liste ekranin
    //    9/16'lik varsayilan tavanini asar ve son madde KIRPILIRDI
    //    (turu 90b'de "Olustur" sheet'inde birebir bu yasandi).
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            kYanBosluk,
            4,
            kYanBosluk,
            kYanBosluk,
          ),
          child: sponsorlu
              ? _reklamMenusu(c)
              : _gonderiMenusu(c, benimGonderim, kaydedildi),
        ),
      ),
    ),
  );
}

// ─────────────────────────── GONDERI MENUSU ───────────────────────────

Widget _gonderiMenusu(BuildContext c, bool benim, bool kaydedildi) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (benim)
      _grup(c, [
        _madde(c, 'Düzenle', LucideIcons.pencil, MenuSecim.duzenle),
        _madde(c, 'İstatistik', LucideIcons.trendingUp, MenuSecim.istatistik),
        _madde(c, 'Sil', LucideIcons.trash2, MenuSecim.sil, yikici: true),
      ]),
    _grup(c, [
      _madde(c, 'Bağlantıyı kopyala', LucideIcons.link, MenuSecim.kopyala),
    ]),
    _grup(c, [
      _madde(
        c,
        kaydedildi ? 'Kaydedilenlerden çıkar' : 'Kaydet',
        LucideIcons.bookmark,
        MenuSecim.kaydet,
      ),
      if (!benim)
        _madde(
          c,
          'İlgilenmiyorum',
          LucideIcons.eyeOff,
          MenuSecim.ilgilenmiyorum,
        ),
    ]),
    if (!benim)
      _grup(c, [
        _madde(c, 'Sessize al', LucideIcons.userX, MenuSecim.sessize),
        _madde(c, 'Kısıtla', LucideIcons.userMinus, MenuSecim.kisitla),
        _madde(c, 'Engelle', LucideIcons.ban, MenuSecim.engelle, yikici: true),
        _madde(
          c,
          'Şikayet Et',
          LucideIcons.circleAlert,
          MenuSecim.sikayet,
          yikici: true,
        ),
      ]),
  ],
);

// ─────────────────────────── REKLAM MENUSU ───────────────────────────

Widget _reklamMenusu(BuildContext c) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    _grup(c, [
      _reklamMadde(
        c,
        'İlgimi Çekiyor',
        'Reklamlarının daha fazlası bunun gibi olacak.',
        LucideIcons.circlePlus,
        MenuSecim.reklamIlgimiCekiyor,
      ),
      _reklamMadde(
        c,
        'İlgimi Çekmiyor',
        'Reklamlarının daha azı bunun gibi olacak.',
        LucideIcons.circleMinus,
        MenuSecim.reklamIlgimiCekmiyor,
      ),
    ]),
    _grup(c, [
      _reklamMadde(
        c,
        'Bağlantıyı kaydet',
        null,
        LucideIcons.bookmark,
        MenuSecim.kaydet,
      ),
      _reklamMadde(
        c,
        'Reklamı gizle',
        'Bu reklamı bir daha görmeyeceksin.',
        LucideIcons.circleX,
        MenuSecim.reklamGizle,
      ),
      _reklamMadde(
        c,
        'Reklamı şikayet et',
        'Bu reklamla ilgili bir sorunu bize bildir.',
        LucideIcons.messageSquareWarning,
        MenuSecim.reklamSikayet,
      ),
      _reklamMadde(
        c,
        'Bu reklamı neden görüyorum?',
        null,
        LucideIcons.info,
        MenuSecim.reklamNeden,
      ),
      _reklamMadde(
        c,
        'Bu reklam hakkında',
        null,
        LucideIcons.fileText,
        MenuSecim.reklamHakkinda,
      ),
    ]),
  ],
);

// ─────────────────────────── ORTAK PARCALAR ───────────────────────────

/// Yuvarlak koseli GRUP KARTI — icindeki maddeler ince ayracla ayrilir.
Widget _grup(BuildContext c, List<Widget> maddeler) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  decoration: BoxDecoration(
    color: kYuzeyGri(c),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Column(
    children: [
      for (var i = 0; i < maddeler.length; i++) ...[
        if (i > 0)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            endIndent: 16,
            color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.10),
          ),
        maddeler[i],
      ],
    ],
  ),
);

/// Gonderi maddesi: baslik SOLDA, ikon SAGDA (Threads).
Widget _madde(
  BuildContext c,
  String baslik,
  IconData ikon,
  MenuSecim secim, {
  bool yikici = false,
}) {
  final renk = yikici
      ? const Color(0xFFE0245E)
      : Theme.of(c).colorScheme.onSurface;
  return InkWell(
    onTap: () => Navigator.pop(c, secim),
    child: Padding(
      // ⚠️ Dikey 14: satir yuksekligi ~50 dp — Material asgari dokunma
      //    hedefinin (48) uzerinde.
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              baslik,
              style: TextStyle(
                fontSize: 16,
                fontWeight: yikici ? FontWeight.w600 : FontWeight.w500,
                color: renk,
              ),
            ),
          ),
          Icon(ikon, size: 20, color: renk),
        ],
      ),
    ),
  );
}

/// Reklam maddesi: ikon SOLDA, altinda aciklama (Facebook).
Widget _reklamMadde(
  BuildContext c,
  String baslik,
  String? aciklama,
  IconData ikon,
  MenuSecim secim,
) => InkWell(
  onTap: () => Navigator.pop(c, secim),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(ikon, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (aciklama != null) ...[
                const SizedBox(height: 2),
                Text(
                  aciklama,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(
                      c,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ),
);
