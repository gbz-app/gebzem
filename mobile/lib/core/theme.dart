import 'package:flutter/material.dart';

// Gebzem marka rengi (yesil aksan) + logo moru (mor gradient FAB / vurgular)
const _seed = Color(0xFF128C7E); // WhatsApp yesiline yakin, kendi tonumuz
const morLogo = Color(0xFF6C2BD9); // logodaki mor
const morLogoAcik = Color(0xFF9D5CE9);
// Logo mor gradient'i (FAB + vurgu daireleri)
const morGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [morLogoAcik, morLogo],
);

// KOYU TEMA renkleri (test turu 5 redesign): alt menu SIYAH, icerik 1-2 ton acik.
const _icerikZemin = Color(0xFF161618); // icerik alani (siyahin acigi)
const _altMenuZemin = Color(0xFF000000); // alt menu SIYAH

/// KOYU TEMA (uygulama tek tema: koyu — kullanici istegi "alt menu siyah").
ThemeData _koyu() {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark)
      .copyWith(surface: _icerikZemin);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _icerikZemin,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: _icerikZemin,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // ALT MENU: siyah zemin, gosterge (daire) YOK, yazi YOK, ikon buyuk, aktif beyaz/pasif gri.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _altMenuZemin,
      indicatorColor: Colors.transparent, // ikon arkasi daire KALDIRILDI
      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // yazilar KALDIRILDI
      height: 62,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final aktif = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 28, // 1 tik daha buyuk
          color: aktif ? Colors.white : const Color(0xFF7A7A7E), // aktif beyaz / pasif hafif gri
        );
      }),
    ),
  );
}

final lightTheme = _koyu(); // tek tema: koyu (light istense de koyu servis edilir)
final darkTheme = _koyu();

// Mesaj balonu renkleri
extension ChatColors on ColorScheme {
  Color get bubbleMine => const Color(0xFF075E54);
  Color get bubbleOther => const Color(0xFF262D31);
  Color get tickRead => const Color(0xFF34B7F1); // mavi tik
}
