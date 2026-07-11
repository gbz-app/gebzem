import 'package:flutter/material.dart';

// Gebzem marka rengi
const _seed = Color(0xFF128C7E); // WhatsApp yesiline yakin, kendi tonumuz

final lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
  appBarTheme: const AppBarTheme(centerTitle: false),
);

final darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
  appBarTheme: const AppBarTheme(centerTitle: false),
);

// Mesaj balonu renkleri
extension ChatColors on ColorScheme {
  Color get bubbleMine =>
      brightness == Brightness.dark ? const Color(0xFF075E54) : const Color(0xFFDCF8C6);
  Color get bubbleOther =>
      brightness == Brightness.dark ? const Color(0xFF262D31) : Colors.white;
  Color get tickRead => const Color(0xFF34B7F1); // mavi tik
}
