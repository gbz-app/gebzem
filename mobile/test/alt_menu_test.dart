import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';
import 'package:gebzem/features/chats/chats_provider.dart';
import 'package:gebzem/features/chats/models.dart';
import 'package:gebzem/features/home/alt_menu.dart';
import 'package:gebzem/features/sosyal/hizmet_menusu.dart';
import 'package:gebzem/features/home/home_screen.dart' show myProfileProvider;
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// ⚠️⚠️⚠️ TURU 96m — ALT MENU MUHAFIZI.
///
///	Kullanici emri (15 Agu): *"alt menu siyah olacak, ikonlar aktif beyaz
///	pasif hafif gri, iconlardaki anasayfa vb alt yazi olmayacak, iconu yukari
///	kaldir biraz daha, icon tam daire olmasi gerekiyor yani logoyu bir
///	dairenin icine koyman gerekiyor bir tik daha buyuk"* + *"profilde a vb
///	yazmasin, eger resim yoksa o da pasif icon renginde olsun"*.
///
/// ⚠️⚠️ **BU KURALLAR SESSIZCE BOZULABILIR.** Hepsi `flutter analyze`den
///	temiz gecer, uygulama COKMEZ; bozulduklarinda tek belirti EKRANDIR:
///	· zemin temaya baglanirsa acik temada SIYAH ikon SIYAH zemine cizilir
///	  ve menu tamamen KAYBOLUR,
///	· logo dairesine ic dolgu geri konursa daire yine "kosesi yuvarlatilmis
///	  KARE" olur (turu 96m'de olculen tam hata buydu),
///	· `Avatar` fotografsiz kullaniciya BAS HARF cizer ve alt menude yazi
///	  olmamasi kuralini deler.
///
/// ⚠️ Bu dosyayi silme. Olculer degisirse `alt_menu.dart`taki sabitlerle
///    BIRLIKTE guncelle — testin okudugu sayilar sabitlerin KENDISIDIR, yani
///    "sayiyi teste de yaz" hatasi yapisal olarak imkansizdir.

/// Gercek `ChatsNotifier` yapicisinda REST + WebSocket'e dokunur; widget
/// testinde bekleyen timer birakip testi patlatirdi.
/// ⚠️ `implements` (extends DEGIL): amac govdeyi degil YALNIZ tipi saglamak.
class _SahteChats extends StateNotifier<AsyncValue<List<Chat>>>
    implements ChatsNotifier {
  _SahteChats() : super(const AsyncValue.data(<Chat>[]));

  @override
  Future<void> load() async {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _kur({
  required int? secili,
  Map<String, dynamic> profil = const <String, dynamic>{},
  ThemeData? tema,
}) =>
    ProviderScope(
      overrides: [
        chatsProvider.overrideWith((ref) => _SahteChats()),
        myProfileProvider.overrideWith((ref) async => profil),
      ],
      child: MaterialApp(
        theme: tema ?? lightTheme,
        home: Scaffold(
          bottomNavigationBar: AltMenu(secili: secili, onSec: (_) {}),
        ),
      ),
    );

/// ⚠️ TURU 96o — LOGO BULUCU. Logo artik bir `Image` WIDGET'I DEGIL: daire
/// `BoxShape.circle` olarak cizilir ve gorsel `DecorationImage` ile
/// doldurulur. Bu yuzden `find.byType(Image)` HICBIR SEY bulmaz.
Finder get _logoBulucu => find.byWidgetPredicate((w) =>
    w is Container &&
    w.decoration is BoxDecoration &&
    (w.decoration as BoxDecoration).image != null);

/// 66 dp'lik SIYAH CUBUK (zemin kutusu ARTIK logonun tasma payini da kapsadigi
/// icin olcut olarak KULLANILAMAZ — merkezi yukari kayar).
Finder get _cubukBulucu =>
    find.byWidgetPredicate((w) => w is SizedBox && w.height == kAltMenuBoy);

/// Alt menunun zemin kutusu (ColoredBox) — rengi olcmek icin.
Color _zeminRengi(WidgetTester t) {
  final kutu = t.widget<ColoredBox>(
    find.descendant(of: find.byType(AltMenu), matching: find.byType(ColoredBox)),
  );
  return kutu.color;
}

void main() {
  testWidgets('zemin SIYAH — acik temada da (temaya baglanmaz)', (t) async {
    for (final tema in [lightTheme, darkTheme]) {
      await t.pumpWidget(_kur(secili: 0, tema: tema));
      await t.pump();
      expect(_zeminRengi(t), kAltMenuZemin,
          reason: 'alt menu zemini iki temada da siyah olmali');
    }
  });

  testWidgets('etiketler EKRANDA YOK ama ekran okuyucuda VAR', (t) async {
    final semantik = t.ensureSemantics();
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    for (final e in ['Anasayfa', 'Ara', 'Reels', 'Mesaj', 'Canlı', 'Profil']) {
      expect(find.text(e), findsNothing, reason: '"$e" METNI cizilmemeli');
      // ⚠️ Gorunur etiket kalkinca a11y etiketi TEK kaynaktir.
      expect(find.bySemanticsLabel(e), findsWidgets,
          reason: '"$e" semantik etiketi DURMALI');
    }
    semantik.dispose();
  });

  testWidgets('aktif ikon BEYAZ, pasif ikon GRI', (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    expect(t.widget<Icon>(find.byIcon(LucideIcons.house)).color,
        kAltMenuAktifIkon);
    for (final i in [
      LucideIcons.search,
      LucideIcons.clapperboard,
      LucideIcons.messageCircle,
      LucideIcons.radio,
    ]) {
      expect(t.widget<Icon>(find.byIcon(i)).color, kAltMenuPasifIkon);
    }
  });

  testWidgets('secili YOKKEN (kategori ekrani) hicbir ikon beyaz degil',
      (t) async {
    await t.pumpWidget(_kur(secili: null));
    await t.pump();
    for (final i in [LucideIcons.house, LucideIcons.search]) {
      expect(t.widget<Icon>(find.byIcon(i)).color, kAltMenuPasifIkon);
    }
  });

  testWidgets('ikonlar SIYAH CUBUK merkezinin USTUNDE (yukari kaldirildi)',
      (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final ikon = t.getCenter(find.byIcon(LucideIcons.house));
    // ⚠️ Olcut AltMenu'nun TAMAMI DEGIL siyah cubuk: widget artik logonun
    //    tasmasi icin ustte saydam bir serit tasiyor.
    final cubuk = t.getRect(_cubukBulucu);
    expect(cubuk.center.dy - ikon.dy, greaterThan(1),
        reason: 'ikon merkezi cubuk merkezinin USTUNDE olmali');
    expect((cubuk.center.dy - ikon.dy - kAltMenuIkonKaldir).abs(), lessThan(0.6),
        reason: 'kaldirma miktari kAltMenuIkonKaldir olmali');
  });

  testWidgets('LOGO ikonlardan DAHA YUKARIDA (kaldirma sabitiyle ayni)', (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final ikon = t.getCenter(find.byIcon(LucideIcons.house));
    final logo = t.getCenter(_logoBulucu);
    // Istenen 10 dp'ydi; cubuk 66 ve logo 52 oldugu icin TASMADAN
    // saglanabilecek EN BUYUK kaldirma (66-52)/2 = 7 dp'dir. Test sabitle
    // karsilastirir, sayiyi TEKRAR YAZMAZ.
    expect((ikon.dy - logo.dy - (kAltMenuLogoKaldir - kAltMenuIkonKaldir)).abs(),
        lessThan(0.6));
    expect(logo.dy, lessThan(ikon.dy), reason: 'logo ikonlardan YUKARIDA olmali');
    expect(kAltMenuLogoKaldir, (kAltMenuBoy - kAltMenuLogoCap) / 2,
        reason: 'kaldirma tasmayacak en buyuk deger olmali');
  });

  testWidgets('LOGO daire icinde, KIRPILMADAN cizilir', (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final gorsel = _logoBulucu;
    // ⚠️⚠️⚠️ **KIRPMA YASAK, DAIRE SERBEST.** Kullanici once *"daire yapma"*
    //	dedi, sonra *"logodan 5px kucuk daire icine doldur"* dedi — yani
    //	istenmeyen sey DAIRE DEGIL, **`ClipOval` ile KIRPMAK**ti: kirpma
    //	kenarda gorunur artefakt birakiyordu (*"cevresinde tirtiklar"*).
    //	Cozum daireyi SEKIL olarak cizmek (`BoxShape.circle` +
    //	`DecorationImage`), boylece kenar yumusatmasini GPU'nun daire cizimi
    //	yapar.
    // ⚠️ YAPMA: logoyu tekrar `ClipOval`/`ClipRRect` icine alma.
    for (final kirpici in [ClipOval, ClipPath]) {
      expect(
        find.ancestor(of: gorsel, matching: find.byType(kirpici)),
        findsNothing,
        reason: '$kirpici logoyu SARMAMALI (kirpma artefakt uretiyor)',
      );
    }
    final sus = t.widget<Container>(gorsel).decoration as BoxDecoration;
    expect(sus.shape, BoxShape.circle, reason: 'logo DAIRE icinde olmali');
    expect(sus.image, isNotNull);
    expect(sus.image!.fit, BoxFit.cover,
        reason: 'gorsel daireyi TAM doldurmali (bosluk/ic dolgu yok)');

    final boyut = t.getSize(gorsel);
    expect(boyut.width, kAltMenuLogoCap);
    expect(boyut.height, kAltMenuLogoCap);
    expect(kAltMenuLogoCap, greaterThan(kAltMenuIkonBoy),
        reason: 'logo ikonlardan BUYUK olmali');
  });

  testWidgets('LOGO CUBUGUN ICINDE kalir — cubuk uzamaz, radius durur',
      (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final cerceve = t.getRect(find.byType(AltMenu));
    final cubuk = t.getRect(_cubukBulucu);
    final logo = t.getRect(_logoBulucu);

    // ⚠️⚠️⚠️ TURU 96p — ASIL KURAL: **logo cubuktan TASMAZ.**
    //	96o'da tasmasina izin verilmis, tasan pay da cubugun ustune SAYDAM
    //	bir serit olarak eklenmisti; kullanici bunu *"alt menu ustunde
    //	5-10px bir alan, kesit gibi"* diye bildirdi. Ardindan cubuk komple
    //	siyaha boyanip radius kaldirilinca *"radius nerede, yuksekligi neden
    //	artirdin"* dedi. Bu test ikisini birden kilitler.
    expect(logo.top, greaterThanOrEqualTo(cubuk.top - 0.01),
        reason: 'logo cubugun UST KENARINDAN TASMAMALI');
    expect(logo.bottom, lessThanOrEqualTo(cubuk.bottom + 0.01),
        reason: 'logo cubugun ALT KENARINDAN TASMAMALI');
    // ⚠️ Widget'in KENDISI de cubuktan uzun OLMAMALI: uzunsa ustte sayfa
    //    zemininin gorundugu o "serit" geri gelmis demektir.
    expect((cerceve.top - cubuk.top).abs(), lessThan(0.01),
        reason: 'cubugun USTUNDE ek bir serit/alan OLMAMALI');

    // ⚠️ UST KOSE RADIUSU **KULLANICI ISTEGI** — kaldirilamaz.
    final kirpici = t.widget<ClipRRect>(find.descendant(
        of: find.byType(AltMenu), matching: find.byType(ClipRRect)));
    final r = kirpici.borderRadius as BorderRadius;
    expect(r.topLeft.x, greaterThan(0), reason: 'sol ust radius DURMALI');
    expect(r.topRight.x, greaterThan(0), reason: 'sag ust radius DURMALI');

    // ⚠️ "Kenarlik yok" (kullanici: *"sadece alt menude border vb kalinlik
    //    olmayacak"*): zemin duz renk, `Border`/`BoxShadow` YOK.
    expect(
      find.descendant(
          of: find.byType(AltMenu),
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).border != null ||
                  (w.decoration as BoxDecoration).boxShadow != null))),
      findsNothing,
      reason: 'alt menude kenarlik/golge OLMAMALI',
    );
  });

  testWidgets('CANLI (radio) ikonu optik olarak BUYUK cizilir', (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final canli = t.widget<Icon>(find.byIcon(LucideIcons.radio)).size!;
    final ev = t.widget<Icon>(find.byIcon(LucideIcons.house)).size!;
    // ⚠️ Kullanici: "canli yayin ikonu kucuk kalmis". Lucide `radio` dikeyde
    //    kisa oldugu icin ayni `size`da KUCUK gorunur (turu 82 optik boy
    //    dersi). Esitlemek sikayeti GERI GETIRIR.
    expect(canli, greaterThan(ev),
        reason: 'radio nominal olarak kardeslerinden BUYUK olmali');
  });

  /// Profil hucresindeki daire (fotograf yokken cizilen).
  Container _profilDairesi(WidgetTester t) => t.widget<Container>(
        find.byWidgetPredicate((w) =>
            w is Container &&
            w.child == null &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).image == null &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle),
      );

  testWidgets('PROFIL: fotograf yoksa HARF de IKON da DEGIL — DUZ DAIRE',
      (t) async {
    await t.pumpWidget(_kur(secili: null, profil: {'name': 'Ahmet'}));
    await t.pump();

    // ⚠️ Kullanici ONCE harfi, SONRA insan siluetli ikonu reddetti:
    //    *"sagdaki profil ikon olmayacak ... yoksa hafif gri renkte daire"*.
    expect(find.text('A'), findsNothing, reason: 'BAS HARF yazilmamali');
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(LucideIcons.circleUserRound), findsNothing,
        reason: 'insan silueti ikonu KULLANILMAMALI');
    expect(find.byIcon(LucideIcons.user), findsNothing);

    final daire = _profilDairesi(t);
    expect((daire.decoration as BoxDecoration).color, kAltMenuPasifIkon,
        reason: 'fotografsiz daire pasif gri olmali');
    // ⚠️ Cap avatarla AYNI olmali: aksi halde fotografi olan/olmayan
    //    kullanici arasinda daire boyu oynar.
    expect(t.getSize(find.byWidget(daire)), const Size(26, 26));
  });

  testWidgets('PROFIL: secili iken daire BEYAZ', (t) async {
    await t.pumpWidget(_kur(secili: 5, profil: {'name': 'Ahmet'}));
    await t.pump();
    expect((_profilDairesi(t).decoration as BoxDecoration).color,
        kAltMenuAktifIkon);
  });

  testWidgets('LOGO cevresinde nefes payi VAR (ikonlar yapisik degil)',
      (t) async {
    // ⚠️⚠️ EKRAN GENISLIGI ACIKCA VERILIR. `flutter test` varsayilani
    //	**800x600**tur; o genislikte hucreler o kadar genis olur ki logonun
    //	yaninda ZATEN bosluk kalir ve test HER DURUMDA gecer.
    //	Bu, muhafizin ILK YAZIMINDA gercekten yasandi: `kAltMenuLogoBosluk`
    //	sifira cekilip bozma denendiginde test **YESIL KALDI**.
    //	**DERS: bir yerlesim kuralini GERCEK TELEFON genisliginde olc.**
    t.view.physicalSize = const Size(411 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final logo = t.getRect(_logoBulucu);
    final reels = t.getRect(find.byIcon(LucideIcons.clapperboard));
    final mesaj = t.getRect(find.byIcon(LucideIcons.messageCircle));
    // ⚠️ Kullanici: "ikonlar ortadaki menuye cok yaklasmis". Olcut ikonun
    //    KENARI ile logonun KENARI arasidir (merkez degil).
    expect(logo.left - reels.right, greaterThanOrEqualTo(16.0),
        reason: 'sol komsu ile logo arasinda en az 16dp bosluk olmali');
    expect(mesaj.left - logo.right, greaterThanOrEqualTo(16.0),
        reason: 'sag komsu ile logo arasinda en az 16dp bosluk olmali');
  });

  testWidgets('DAR TELEFONDA (360dp) hucre dokunma hedefi ezilmez', (t) async {
    // ⚠️ Logo boslugu 6 esnek hucreden CALINIR. Bu test, boslugu buyutmenin
    //    dokunma hedefini Material esiginin (48dp) cok altina dusurmesini
    //    engeller — 360dp en yaygin dar Android genisligi.
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final hucre = t.getRect(find.ancestor(
        of: find.byIcon(LucideIcons.house),
        matching: find.byType(GestureDetector)));
    expect(hucre.width, greaterThanOrEqualTo(40.0),
        reason: 'dar telefonda hucre 40dp altina dusmemeli '
            '(kAltMenuLogoBosluk cok buyuk)');
    expect(hucre.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('LOGOYA dokunmak SEKME DEGISTIRMEZ (menu acar)', (t) async {
    // ⚠️ Kullanici emri: *"alt menudeki logo tiklandiginda menu gelecek"*.
    //    Onceden `onSec(0)` cagiriyordu (anasayfaya gidiyordu).
    final secilenler = <int>[];
    await t.pumpWidget(ProviderScope(
      overrides: [
        chatsProvider.overrideWith((ref) => _SahteChats()),
        myProfileProvider.overrideWith((ref) async => const {}),
      ],
      child: MaterialApp(
        theme: lightTheme,
        home: Scaffold(
          bottomNavigationBar:
              AltMenu(secili: 0, onSec: secilenler.add),
        ),
      ),
    ));
    await t.pump();

    await t.tap(_logoBulucu);
    // ⚠️ `pumpAndSettle` ZORUNLU: sheet acilis animasyonu bitmeden test
    //    biterse "timers pending" ile patlar (ilk yazimda oldu).
    await t.pumpAndSettle();

    expect(secilenler, isEmpty,
        reason: 'logo bir SEKME DEGIL: dokunus onSec tetiklememeli');
    // ⚠️ ASIL KANIT: hamburgerin actigi menunun TA KENDISI acilmali.
    expect(find.byType(HizmetMenusu), findsOneWidget,
        reason: 'logoya dokununca hizmet menusu acilmali');
  });

  test('pasif gri siyah zeminde OKUNUR (kontrast >= 3:1)', () {
    // ⚠️ Esik WCAG 1.4.11 (grafik/arayuz bileseni). Pasif rengi karartmak
    //    "daha sik durur" diye cazip gelir; 3:1'in altina inince pasif
    //    sekmeler zayif gozde ve gunes altinda GORUNMEZ olur.
    double dogrusal(double k) =>
        k <= 0.03928 ? k / 12.92 : math.pow((k + 0.055) / 1.055, 2.4).toDouble();

    final l = 0.2126 * dogrusal(kAltMenuPasifIkon.r) +
        0.7152 * dogrusal(kAltMenuPasifIkon.g) +
        0.0722 * dogrusal(kAltMenuPasifIkon.b);
    final oran = (l + 0.05) / 0.05; // zemin saf siyah -> dogrusal parlaklik 0
    expect(oran, greaterThanOrEqualTo(3.0),
        reason: 'pasif ikon grisi siyah zeminde en az 3:1 olmali');
    // ⚠️ Aktif ile pasif ACIKCA ayrismali; ikisi de beyaza yakin olursa
    //    "hangi sekmedeyim" bilgisi kaybolur.
    expect(kAltMenuPasifIkon.r, lessThan(kAltMenuAktifIkon.r - 0.2));
  });
}
