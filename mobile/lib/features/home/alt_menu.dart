import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // SystemUiOverlayStyle (sistem cubugu)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart'
    show kAltMenuZemin, kAltMenuAktifIkon, kAltMenuPasifIkon;
import '../chats/chats_provider.dart';
import '../medya/medya_gorsel.dart';
import 'home_screen.dart' show myProfileProvider;

/// ⚠️ Cubuk yuksekligi (guvenli alanin USTUNDE). Tum hucrelerin dokunma
///    hedefi bu yukseklige ESITTIR (Material asgari 48 dp fazlasiyla saglanir).
const double kAltMenuBoy = 66;

/// ⚠️⚠️ TURU 96m — IKONLAR **BU KADAR YUKARI** cekilir (kullanici emri:
///	*"iconu yukari kaldir biraz daha"*).
///
/// ⚠️ Kaldirma `padding` ile DEGIL `Transform.translate` ile yapilir: dolguyla
///    yapilsaydi cocuga kalan yukseklik azalir ve logo (52) ile cubuk (66)
///    arasindaki pay eriyip **RenderFlex tasmasi** riski dogardi. Ceviri bir
///    CIZIM donusumudur, yerlesimi daraltmaz.
const double kAltMenuIkonKaldir = 5;

/// Ikon boyu — `theme.dart`taki `navigationBarTheme` ile AYNI (24).
const double kAltMenuIkonBoy = 24;

/// ⚠️⚠️ ORTADAKI LOGO DAIRESI (kullanici emri: *"logoyu bir dairenin icine
///	koyman gerekiyor, bir tik daha buyuk olmasi gerekiyor"*): 48 -> **52**.
/// ⚠️ 66'lik cubukta 52 + 2x5 kaldirma = 62 < 66; buyutulurse once bu payi
///    kontrol et.
const double kAltMenuLogoCap = 52;

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
/// ⚠️⚠️⚠️ TURU 96m — **ETIKETLER KALDIRILDI** (kullanici emri: *"iconlardaki
///	anasayfa vb alt yazi olmayacak"*). Metin YALNIZCA ekrandan kalkti,
///	`Semantics(label:)` olarak **DURUYOR**: gorunur etiketi olmayan bir
///	ikon ekran okuyucuda "dugme" diye okunur ve TalkBack kullanicisi hangi
///	sekmede oldugunu ANLAYAMAZ.
/// ⚠️ YAPMA: `etiket` parametresini "kullanilmiyor" diye silme — a11y'nin
///    TEK kaynagi odur.
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
    final okunmamis = ref
            .watch(chatsProvider)
            .valueOrNull
            ?.where((c) => !c.archived)
            .fold<int>(0, (a, c) => a + c.unread) ??
        0;
    // ⚠️⚠️⚠️ TURU 96m — SISTEM GEZINME CUBUGU (alttaki "pill") IKONLARI ACIK.
    //
    //	Cubuk siyaha cevrilince Android'in kendi cizdigi gezinme cizgisi ACIK
    //	temada KOYU kaliyor ve siyah serit uzerinde **GORUNMEZ** oluyordu —
    //	yani bu satir kozmetik degil, degisikligin GEREKTIRDIGI kapatma.
    //
    // ⚠️ Flutter sistem stilini ekranin **EN UST** ve **EN ALT** noktasindaki
    //    `AnnotatedRegion`lardan ayri ayri okur (`RendererBinding
    //    ._updateSystemChrome`): buradaki deger yalniz GEZINME cubugu
    //    alanlarini etkiler, durum cubugu `main.dart`taki uygulama geneli
    //    varsayilandan gelmeye DEVAM eder (turu 85c).
    // ⚠️ YAPMA: buraya `statusBar*` alanlari ekleme — yaprak annotation
    //    kazanir ve koyu/acik tema mantigini SESSIZCE ezersin.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: kAltMenuZemin,
        systemNavigationBarDividerColor: kAltMenuZemin,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: ClipRRect(
        // ALT MENU sol/sag (ust kose) RADIUS (test turu 7).
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: ColoredBox(
          // ⚠️ TURU 96m — zemin TEMADAN DEGIL sabit siyah (bkz. `theme.dart`).
          color: kAltMenuZemin,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: kAltMenuBoy,
              child: Row(
                // ⚠️ `stretch`: her hucre cubugun TAM YUKSEKLIGINI kaplar, yani
                //    dokunma hedefi ikonun kendisi degil hucrenin tamamidir.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _oge(0, LucideIcons.house, 'Anasayfa'),
                  _oge(1, LucideIcons.search, 'Ara'),
                  _oge(2, LucideIcons.clapperboard, 'Reels'),
                  _logo(),
                  // ⚠️ OKUNMAMIS ROZETI: mesaj sekmesi alt menude ve kullanici
                  //    surekli akista/reels'te olacagi icin rozet OLMADAN yeni
                  //    mesaji HIC fark etmezdi.
                  _oge(3, LucideIcons.messageCircle, 'Mesaj', rozet: okunmamis),
                  _oge(4, LucideIcons.radio, 'Canlı'),
                  _profil(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bir menu hucresi: tam yukseklikte dokunma hedefi + yukari cekilmis icerik.
  ///
  /// ⚠️ **DALGA YOK** (`GestureDetector`): kullanici "tikladiginda titreme
  ///    olmasin" dedi ve bu kural tum uygulamaya tasindi.
  Widget _hucre({
    required int sira,
    required String etiket,
    required bool aktif,
    required Widget cocuk,
  }) =>
      Expanded(
        child: Semantics(
          button: true,
          selected: aktif,
          label: etiket,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSec(sira),
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -kAltMenuIkonKaldir),
                child: cocuk,
              ),
            ),
          ),
        ),
      );

  /// Tek menu ogesi.
  ///
  /// ⚠️ Secili/secili degil ayrimi **RENKLE**: aktif beyaz, pasif gri
  ///    (kullanici emri). Boyut DEGISMEZ — buyuyup kuculen ikon satiri
  ///    oynatir ve goz bunu titreme olarak okur.
  Widget _oge(int sira, IconData ikon, String etiket, {int rozet = 0}) {
    final aktif = secili == sira;
    final renk = aktif ? kAltMenuAktifIkon : kAltMenuPasifIkon;
    return _hucre(
      sira: sira,
      etiket: etiket,
      aktif: aktif,
      cocuk: rozet > 0
          ? _RozetliIkon(ikon: ikon, sayi: rozet, renk: renk)
          : Icon(ikon, size: kAltMenuIkonBoy, color: renk),
    );
  }

  /// Profil sekmesi (sira 5).
  ///
  /// ⚠️⚠️ TURU 96m — **FOTOGRAF YOKSA HARF YAZILMAZ** (kullanici emri: *"profilde
  ///	a vb yazmasin, eger resim yoksa o da pasif icon renginde olsun"*).
  ///	`Avatar` fotograf yokken `CircleAvatar` + BAS HARF cizer; alt menude bu
  ///	hem etiketleri kaldirdigimiz "yazisiz" dile aykiriydi hem de tema
  ///	renginde bir daire oldugu icin siyah seritte YAMA gibi duruyordu.
  ///	Fotografsiz kullanici artik diger sekmelerle AYNI dilde bir ikon gorur.
  Widget _profil() => _hucre(
        sira: 5,
        etiket: 'Profil',
        aktif: secili == 5,
        cocuk: _ProfilIkonu(secili: secili == 5),
      );

  /// ⚠️⚠️ ORTADAKI LOGO — **TAM DAIRE** (kullanici emri: *"icon tam daire olmasi
  ///	gerekiyor, yani logoyu bir dairenin icine koyman gerekiyor"*).
  ///
  /// ⚠️⚠️ ONCEKI HAL NEDEN DAIRE DEGILDI (olculdu): gorsel 48'lik `ClipOval`in
  ///	ICINDE **3 px dolguyla** ciziliyordu. Daire yaricapi 24 iken gorselin
  ///	kenar ortalari yalnizca 21'de kaliyor; yani kirpma SADECE koseleri
  ///	yiyor, kenarlar duz kaliyordu -> ekranda **kosesi yuvarlatilmis KARE**.
  ///	Cozum dolguyu kaldirip gorseli daireye **TAM DOLDURMAK** (`cover`).
  /// ⚠️ YAPMA: buraya tekrar ic dolgu koyma — kare gorunum geri gelir.
  ///
  /// ⚠️ Logo dosyasi TEK KAYNAK: `assets/icon/logo.png`.
  /// ⚠️ **DAVRANIS: ANASAYFA.** Dokununca hicbir sey yapmayan bir dugme bu
  ///    projede "olu ozellik" sinifidir.
  Widget _logo() => Semantics(
        button: true,
        label: 'Anasayfa',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSec(0),
          // ⚠️ Logo hucresi ESNEK DEGIL (sabit genislik): `Expanded` olsaydi
          //    dairenin cevresindeki bosluk ekran genisligine gore oynar ve
          //    "3 sol · logo · 3 sag" simetrisi dar telefonda bozulurdu.
          child: SizedBox(
            width: kAltMenuLogoCap + 12,
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -kAltMenuIkonKaldir),
                child: Container(
                  width: kAltMenuLogoCap,
                  height: kAltMenuLogoCap,
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: Image.asset(
                    'assets/icon/logo.png',
                    fit: BoxFit.cover,
                  ),
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
    final mediaId = p?['avatar_media_id'] as String?;
    final url = (p?['avatar_url'] ?? '').toString();
    final fotografVar = (mediaId != null && mediaId.isNotEmpty) || url.isNotEmpty;

    // ⚠️⚠️ TURU 96m — FOTOGRAF YOKSA IKON (harf DEGIL). Renk kardes
    //    sekmelerle BIREBIR ayni kaynaktan gelir, yoksa "pasif gri" tanimi
    //    iki yerde yasar ve drift eder.
    if (!fotografVar) {
      return Icon(
        LucideIcons.circleUserRound,
        size: kAltMenuIkonBoy,
        color: secili ? kAltMenuAktifIkon : kAltMenuPasifIkon,
      );
    }

    final avatar = Avatar(
      ad: (p?['name'] ?? '').toString(),
      mediaId: mediaId,
      avatarUrl: url,
      cap: _cap,
    );
    // ⚠️ Pasifken fotograf SOLDURULUR: renk veremedigimiz tek oge budur, o
    //    yuzden "pasif" hissi opaklikla verilir (siyah zemine karisir).
    if (!secili) return Opacity(opacity: 0.55, child: avatar);
    // ⚠️ Cerceve DISARIDAN cizilir (avatarin capini KUCULTMEZ): `Container`in
    //    kendi kenarligi cocugu iceri iterdi ve secili/secili-degil arasinda
    //    fotograf boyutu OYNAR, alt menu titrerdi.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // ⚠️ Cerceve de AKTIF IKON RENGI (beyaz): tema `primary`si siyah
        //    seritte diger aktif ikonlarla ayni dili konusmuyordu.
        border: Border.all(color: kAltMenuAktifIkon, width: 2),
      ),
      child: Padding(padding: const EdgeInsets.all(1.5), child: avatar),
    );
  }
}

class _RozetliIkon extends StatelessWidget {
  const _RozetliIkon({
    required this.ikon,
    required this.sayi,
    required this.renk,
  });

  final IconData ikon;
  final int sayi;

  /// ⚠️ TURU 96m — renk ARTIK ZORUNLU PARAMETRE. Onceden `Icon(ikon)` ambient
  ///    `IconTheme`den beslenirdi; cubuk siyaha cevrilince o renk (acik temada
  ///    KOYU) siyah zeminde GORUNMEZ olurdu.
  final Color renk;

  @override
  Widget build(BuildContext context) {
    final ikonu = Icon(ikon, size: kAltMenuIkonBoy, color: renk);
    if (sayi <= 0) return ikonu;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ikonu,
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
