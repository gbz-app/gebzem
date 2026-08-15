import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chats/chats_provider.dart';
import '../medya/medya_gorsel.dart';
import 'home_screen.dart' show myProfileProvider;

/// Alt menu — **3 sol · LOGO · 3 sag**.
///
/// ⚠️⚠️⚠️ TURU 96l — `home_screen` ICINDEN BURAYA TASINDI (TEK KAYNAK).
///	Kullanici kategori ekraninda da alt menuyu istedi (*"alt menuyu getir,
///	alt menu gorunmesi gerekiyor"*). Menu `home_screen`in private bir
///	metoduydu; ikinci ekrana KOPYALANSAYDI rozet sayaci, logo davranisi ve
///	"bir tik yukarida" dolgusu birinde guncellenip otekinde geride kalirdi
///	— bu projede "ayni kuralin iki kopyasi drift eder" sinifi ALTI kez
///	sahaya cikti.
///
/// ⚠️ [secili] `null` ise HICBIR oge secili cizilmez: kategori ekrani bir
///	sekme DEGILDIR, uzerine PUSH edilmis bir route'tur. Orada "Anasayfa"yi
///	secili gostermek kullaniciya YALAN soylerdi.
/// ⚠️ Sekme INDEKSLERI (0..5) DEGISMEZ: `aktifSekme` ve akistaki videolarin
///    ses guvenligi kapisi bunlara bagli (bkz. `home_screen` serhi).
class AltMenu extends ConsumerWidget {
  const AltMenu({super.key, required this.secili, required this.onSec});

  /// Secili sekme; `null` = bu ekran bir sekme degil.
  final int? secili;
  final void Function(int sira) onSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final koyu = Theme.of(context).brightness == Brightness.dark;
    final okunmamis = ref
            .watch(chatsProvider)
            .valueOrNull
            ?.where((c) => !c.archived)
            .fold<int>(0, (a, c) => a + c.unread) ??
        0;
    return ClipRRect(
      // ALT MENU sol/sag (ust kose) RADIUS (test turu 7).
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: [
                _oge(context, 0, LucideIcons.house, 'Anasayfa'),
                _oge(context, 1, LucideIcons.search, 'Ara'),
                _oge(context, 2, LucideIcons.clapperboard, 'Reels'),
                _logo(context, koyu),
                // ⚠️ OKUNMAMIS ROZETI: mesaj sekmesi alt menude ve kullanici
                //    surekli akista/reels'te olacagi icin rozet OLMADAN yeni
                //    mesaji HIC fark etmezdi.
                _oge(context, 3, LucideIcons.messageCircle, 'Mesaj',
                    rozet: okunmamis),
                _oge(context, 4, LucideIcons.radio, 'Canlı'),
                _oge(context, 5, null, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tek menu ogesi. [ikon] `null` ise PROFIL RESMI cizilir.
  ///
  /// ⚠️ Secili/secili degil ayrimi RENKLE: secilide tam opak + kalin etiket.
  /// ⚠️ **DALGA YOK** (`GestureDetector`): kullanici "tikladiginda titreme
  ///    olmasin" dedi ve bu kural tum uygulamaya tasindi.
  Widget _oge(BuildContext context, int sira, IconData? ikon, String etiket,
      {int rozet = 0}) {
    final aktif = secili == sira;
    final renk = Theme.of(context).colorScheme.onSurface;
    return Expanded(
      child: Semantics(
        button: true,
        selected: aktif,
        label: etiket,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSec(sira),
          child: Padding(
            // ⚠️ Ikonlar "bir tik yukarida": alt dolgu ustten BUYUK.
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: aktif ? 1 : 0.5,
                  child: ikon == null
                      ? _ProfilIkonu(secili: aktif)
                      : (rozet > 0
                          ? _RozetliIkon(ikon: ikon, sayi: rozet)
                          : Icon(ikon, size: 24, color: renk)),
                ),
                const SizedBox(height: 3),
                Text(
                  etiket,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                    color: renk.withValues(alpha: aktif ? 1 : 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️⚠️ ORTADAKI LOGO — **ikonlarin 2 KATI** (kullanici emri): ikon 24,
  ///	logo dairesi **48**.
  ///
  /// ⚠️ Logo dosyasi TEK KAYNAK: `assets/icon/logo.png`.
  /// ⚠️ **DAVRANIS: ANASAYFA.** Dokununca hicbir sey yapmayan bir dugme bu
  ///    projede "olu ozellik" sinifidir.
  Widget _logo(BuildContext context, bool koyu) => Semantics(
        button: true,
        label: 'Anasayfa',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSec(0),
          child: Padding(
            padding:
                const EdgeInsets.only(top: 6, bottom: 12, left: 4, right: 4),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    koyu ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Image.asset('assets/icon/logo.png', fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ),
      );
}

// ⚠️⚠️ TURU 96l — ASAGIDAKI IKI SINIF `home_screen.dart`tan **TASINDI**,
//    yeniden yazilmadi: govdeleri kopyalansaydi avatar cercevesi, rozet
//    rengi ve capi iki dosyada AYRI AYRI yasar ve drift ederdi.
// ⚠️ YAPMA: bunlari `home_screen`e geri kopyalama.

class _ProfilIkonu extends ConsumerWidget {
  const _ProfilIkonu({required this.secili});

  /// Secili sekmede ikon RENGI degistirilemedigi icin (avatar bir fotograf)
  /// ayrim CERCEVE ile yapilir.
  final bool secili;

  static const double _cap = 26;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(myProfileProvider).valueOrNull;
    final avatar = Avatar(
      ad: (p?['name'] ?? '').toString(),
      mediaId: p?['avatar_media_id'] as String?,
      avatarUrl: (p?['avatar_url'] ?? '').toString(),
      cap: _cap,
    );
    if (!secili) return avatar;
    // ⚠️ Cerceve DISARIDAN cizilir (avatarin capini KUCULTMEZ): `Container`in
    //    kendi kenarligi cocugu iceri iterdi ve secili/secili-degil arasinda
    //    fotograf boyutu OYNAR, alt menu titrerdi.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(1.5), child: avatar),
    );
  }
}

class _RozetliIkon extends StatelessWidget {
  const _RozetliIkon({required this.ikon, required this.sayi});

  final IconData ikon;
  final int sayi;

  @override
  Widget build(BuildContext context) {
    if (sayi <= 0) return Icon(ikon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(ikon),
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 17),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              sayi > 99 ? '99+' : '$sayi',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
