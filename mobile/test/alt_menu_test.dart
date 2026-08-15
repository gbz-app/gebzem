import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';
import 'package:gebzem/features/chats/chats_provider.dart';
import 'package:gebzem/features/chats/models.dart';
import 'package:gebzem/features/home/alt_menu.dart';
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

/// Alt menunun zemin kutusu (`ColoredBox`) — rengi olcmek icin.
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

  testWidgets('ikonlar cubuk MERKEZININ USTUNDE (yukari kaldirildi)',
      (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final cubuk = t.getRect(find.byType(AltMenu));
    final ikon = t.getCenter(find.byIcon(LucideIcons.house));
    final logo = t.getCenter(find.byType(Image));
    // ⚠️ Pay 1px: "tam merkezde" de gecmesin diye ACIKCA kucuk tutuldu.
    expect(cubuk.center.dy - ikon.dy, greaterThan(1),
        reason: 'ikon merkezi cubuk merkezinin USTUNDE olmali');
    expect((cubuk.center.dy - ikon.dy - kAltMenuIkonKaldir).abs(), lessThan(0.6),
        reason: 'kaldirma miktari kAltMenuIkonKaldir olmali');
    expect((cubuk.center.dy - logo.dy - kAltMenuIkonKaldir).abs(), lessThan(0.6),
        reason: 'logo da ayni miktarda kaldirilmali (satir hizasi)');
  });

  testWidgets('LOGO tam daire · ic dolgu YOK · ikondan buyuk', (t) async {
    await t.pumpWidget(_kur(secili: 0));
    await t.pump();

    final kap = t.widget<Container>(find.byWidgetPredicate(
        (w) => w is Container && w.child is Image));
    final sus = kap.decoration as BoxDecoration;
    expect(sus.shape, BoxShape.circle, reason: 'logo kabi DAIRE olmali');
    expect(kap.clipBehavior, isNot(Clip.none),
        reason: 'daire KIRPMALI, yoksa gorsel kareden tasar');
    expect(kap.padding, isNull,
        reason: 'IC DOLGU YASAK: dolgu daireyi "yuvarlatilmis kare" yapar');

    // ⚠️ ASIL KANIT: gorsel dairenin TAMAMINI doldurmali. Dolgu geri konursa
    //    gorsel kucuk kalir ve bu satir KIRMIZI duser.
    final gorsel = t.getSize(find.byType(Image));
    expect(gorsel.width, kAltMenuLogoCap);
    expect(gorsel.height, kAltMenuLogoCap);
    expect(kAltMenuLogoCap, greaterThan(kAltMenuIkonBoy),
        reason: 'logo ikonlardan BUYUK olmali');
  });

  testWidgets('PROFIL: fotograf yoksa HARF degil IKON cizilir', (t) async {
    await t.pumpWidget(_kur(secili: null, profil: {'name': 'Ahmet'}));
    await t.pump();

    expect(find.text('A'), findsNothing,
        reason: 'fotografsiz profilde BAS HARF yazilmamali');
    expect(find.byType(CircleAvatar), findsNothing);
    final ikon = t.widget<Icon>(find.byIcon(LucideIcons.circleUserRound));
    expect(ikon.color, kAltMenuPasifIkon,
        reason: 'fotografsiz profil ikonu pasif gri olmali');
    expect(ikon.size, kAltMenuIkonBoy,
        reason: 'kardes sekmelerle ayni boyda olmali');
  });

  testWidgets('PROFIL: secili iken ikon BEYAZ', (t) async {
    await t.pumpWidget(_kur(secili: 5, profil: {'name': 'Ahmet'}));
    await t.pump();
    expect(t.widget<Icon>(find.byIcon(LucideIcons.circleUserRound)).color,
        kAltMenuAktifIkon);
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
