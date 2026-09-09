import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';

/// ⚠️⚠️⚠️ TURU 180ad — **YAZI TIPI MUHAFIZI** (kullanici emri: *"yazi tipini
/// Google Sans olarak duzenle, TUM SAYFALARIN bu yazi tipinde calistigina
/// TAM OLARAK EMIN OL"*).
///
/// ═══════════ NEDEN BU TEST VAR ═══════════
///
/// Turu 180i'de olculdu: aile adi kod genelinde **ON YERDE** geciyordu (tema
/// + kendi `ThemeData`sini kuran dokuz ekran). Elle degistirilseydi biri
/// atlanir ve o ekran **SESSIZCE SISTEM FONTUNA** duserdi — derleme temiz,
/// hicbir uyari yok, yalnizca EKRANDA gorunur.
///
/// Ayrica turu 180r'de olculdu: `kKoyuTema`da `fontFamily` YOKTU ve
/// `Theme(data: kKoyuTema)` `MaterialApp.theme`daki aileyi **EZIYORDU** —
/// `koyuSayfa` ile sarilan HER ekran sistem fontuna dusuyordu.
///
/// Bu dosya iki riski de YAPISAL olarak kapatir.
void main() {
  test('font dosyalari VAR ve aile adi GERCEKTEN "Google Sans"', () {
    // ⚠️ Aile adi `pubspec.yaml`daki etiketten DEGIL, TTF'in kendi `name`
    //	tablosundan okunur: pubspec'e yanlis ad yazmak fontu sessizce
    //	yuklenmez yapar (Flutter uyarmaz, sistem fontuna duser).
    for (final w in [400, 500, 600, 700]) {
      final f = File('assets/fonts/GoogleSans-$w.ttf');
      expect(f.existsSync(), isTrue, reason: 'GoogleSans-$w.ttf YOK');
      // ⚠️ `startsWith`: agirlik dosyalarinin nameID 1 degeri aileyi
      //	agirlikla birlikte tasir ("Google Sans Medium"). Flutter
      //	pubspec'teki `family` adini kullanir; onemli olan dosyanin
      //	AYNI AILEDEN olmasi.
      expect(_aileAdi(f.readAsBytesSync()), startsWith('Google Sans'),
          reason: 'GoogleSans-$w.ttf farkli bir aile tasiyor');
    }
  });

  test('kYaziAilesi ile pubspec AILE ADI BIREBIR AYNI', () {
    // ⚠️⚠️⚠️ **BU TESTIN VARLIK SEBEBI**: ilk yazimda muhafiz yalnizca
    //	"tema `kYaziAilesi`ni tasiyor mu" diye bakiyordu — sabit ile pubspec
    //	AYRI AYRI degistiginde ikisi de kendi icinde tutarli kalir ve test
    //	YESIL gecerdi. Oysa ikisi ayrisirsa Flutter o aileyi BULAMAZ ve
    //	uygulama SESSIZCE SISTEM FONTUNA duser (uyari YOK, derleme temiz) —
    //	kullanicinin *"tum sayfalarin bu yazi tipinde calistigina emin ol"*
    //	dedigi riskin ta kendisi.
    //	Bozarak bulundu: `kYaziAilesi` eski degere donduruldu, test YINE
    //	gecti. Olcut artik PUBSPEC ile KARSILASTIRMA.
    final p = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'family:\s*(.+?)\s*$', multiLine: true).firstMatch(p);
    expect(m, isNotNull, reason: 'pubspec\'te `family:` satiri YOK');
    expect(kYaziAilesi, m!.group(1),
        reason: 'kod ile pubspec AYRISMIS — font YUKLENMEZ, sistem fontuna '
            'duser (sessiz hata)');
  });

  test('pubspec DORT agirligi da kaydediyor', () {
    final p = File('pubspec.yaml').readAsStringSync();
    // ⚠️⚠️ Satir sonu KONTROL EDILMEZ: bu repoda satir sonlari KARISIK
    //	(bazi dosyalar CRLF) — `\n` beklemek testi CRLF'te kirmizi
    //	dusururdu (CLAUDE.md'de DORT kez yasanmis tuzak).
    expect(RegExp(r'family:\s*Google Sans\s*$', multiLine: true).hasMatch(p),
        isTrue,
        reason: 'pubspec aile adi "Google Sans" olmali');
    for (final w in [400, 500, 600, 700]) {
      expect(p, contains('GoogleSans-$w.ttf'),
          reason: '$w agirligi pubspec\'te YOK');
      // ⚠️ Kayitli OLMAYAN bir agirlik sessizce en yakinina duser:
      //	turu 157'de olculdu — `w800` yazan her yer FIILEN 700 cizilyordu.
    }
  });

  test('kYaziAilesi TEK KAYNAK: kod ELLE font adi yazmiyor', () {
    // ⚠️⚠️ Turu 180i dersi: aile adi ON YERDE duz dize olarak yaziliydi.
    //	Artik `kYaziAilesi` disinda hicbir GOVDE satiri UYGULAMA FONTUNU
    //	elle yazmamali (yorumlar serbest — gecmisi anlatiyorlar).
    //
    // ⚠️⚠️⚠️ **JENERIK AILELER MUAF** (`serif` · `monospace` ·
    //	`sans-serif`): hikaye editorundeki YAZI STILI secenekleri bunlar
    //	(`story_katman.dart`) ve KULLANICININ sectigi stildir, uygulamanin
    //	genel fontu DEGIL. Muhafiz ilk kosuda o dosyayi yanlislikla
    //	isaretledi; olcut daraltildi.
    const jenerik = {'serif', 'monospace', 'sans-serif', 'cursive'};
    final hatalar = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((e) => e.path.endsWith('.dart'))) {
      if (f.path.endsWith('theme.dart')) continue; // sabitin kendi evi
      final govde = _yorumsuz(f.readAsStringSync());
      for (final m in RegExp("fontFamily:\\s*'([^']*)'").allMatches(govde)) {
        if (!jenerik.contains(m.group(1))) hatalar.add('${f.path} -> ${m.group(1)}');
      }
    }
    expect(hatalar, isEmpty,
        reason: 'bu dosyalar font adini ELLE yaziyor (tek kaynagi atliyor): '
            '${hatalar.join(", ")}');
  });

  test('UC TEMA DA aileyi tasiyor (koyuSayfa ile sarilan ekranlar dahil)', () {
    // ⚠️⚠️⚠️ TURU 180r — `kKoyuTema`da `fontFamily` YOKTU ve `Theme(data:
    //	kKoyuTema)` `MaterialApp.theme`daki aileyi EZIYORDU: `koyuSayfa`
    //	ile sarilan HER ekran (menu · kategori · profil · katalog · urun
    //	formu · isletme sihirbazi · arama) sessizce SISTEM FONTUNA
    //	dusuyordu. Muhafiz o regresyonu kilitler.
    for (final t in <(String, ThemeData)>[
      ('lightTheme', lightTheme),
      ('darkTheme', darkTheme),
      ('kKoyuTema', kKoyuTema),
    ]) {
      final stil = t.$2.textTheme.bodyMedium;
      expect(stil?.fontFamily, kYaziAilesi,
          reason: '${t.$1} `bodyMedium` aileyi TASIMIYOR');
      final baslik = t.$2.textTheme.titleLarge;
      expect(baslik?.fontFamily, kYaziAilesi,
          reason: '${t.$1} `titleLarge` aileyi TASIMIYOR');
    }
  });

  test('KOYU KATMAN MERDIVENI: alt menu < yuzey < input', () {
    // ⚠️⚠️⚠️ TURU 180ad — kullanici emri: *"alt menu tam siyahin bir tik
    //	ustu, ic renk onun bir tik acigi, inputlar onun bir tik acigi"*.
    //	Muhafiz SIRAYI kilitler; degerler degisebilir, SIRA degismemeli.
    double parlaklik(Color c) =>
        (c.r * 0.299 + c.g * 0.587 + c.b * 0.114);
    final altMenu = parlaklik(kAltMenuZemin);
    final yuzey = parlaklik(kYuzeyKoyu);
    final input = parlaklik(kInputZemin);
    final sayfa = parlaklik(kAiZemin);

    expect(sayfa, lessThan(altMenu),
        reason: 'sayfa zemini merdivenin ALTINDA kalmali');
    expect(altMenu, lessThan(yuzey),
        reason: 'alt menu, kart yuzeyinden KOYU olmali');
    expect(yuzey, lessThan(input),
        reason: 'kart yuzeyi, input zemininden KOYU olmali');
    // ⚠️ Alt menu TAM SIYAH OLMAMALI (kullanici emri: "bir tik ustu");
    //	tam siyahta uzerindeki kart ayirt edilemiyordu ve %14 beyaz ust
    //	kenarlik "beyaz serit" gibi parliyordu.
    expect(altMenu, greaterThan(0.0),
        reason: 'alt menu TAM SIYAH olmamali (kullanici emri)');
  });

  test('koyu temada input zemini TEMADAN geliyor', () {
    // ⚠️ `fillColor` VERMEYEN her `TextField` dogru rengi kendiliginden
    //	alsin diye tema seviyesinde tanimli.
    // ⚠️⚠️ `filled: true` ZORUNLU: `fillColor` tek basina HICBIR SEY
    //	YAPMAZ (`InputDecorator` dolguyu yalniz `filled` ile cizer).
    final d = kKoyuTema.inputDecorationTheme;
    expect(d.filled, isTrue, reason: '`filled` acik olmali');
    expect(d.fillColor, kInputZemin,
        reason: 'input zemini `kInputZemin` olmali');
  });
}

/// TTF `name` tablosundan aile adini (nameID 1) okur.
String _aileAdi(List<int> bytes) {
  final data = _ByteReader(bytes);
  final n = data.u16(4);
  for (var i = 0; i < n; i++) {
    final o = 12 + i * 16;
    if (data.str(o, 4) == 'name') {
      final off = data.u32(o + 8);
      final cnt = data.u16(off + 2);
      final so = data.u16(off + 4);
      for (var j = 0; j < cnt; j++) {
        final r = off + 6 + j * 12;
        if (data.u16(r + 6) == 1) {
          final len = data.u16(r + 8);
          final ofs = data.u16(r + 10);
          final platID = data.u16(r);
          final basla = off + so + ofs;
          if (platID == 3) {
            // ⚠️ Windows platformu UTF-16 **BIG ENDIAN** yazar; `utf16le`
            //	ile okumak adi TERS/BOZUK verir.
            final sb = StringBuffer();
            for (var k = 0; k < len; k += 2) {
              sb.writeCharCode(data.u16(basla + k));
            }
            return sb.toString();
          }
          return data.str(basla, len);
        }
      }
    }
  }
  return '?';
}

class _ByteReader {
  _ByteReader(this.b);
  final List<int> b;
  int u16(int i) => (b[i] << 8) | b[i + 1];
  int u32(int i) => (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  String str(int i, int n) =>
      String.fromCharCodes(b.sublist(i, i + n));
}

/// ⚠️ Kaynagi YORUMLARDAN temizler: serhler gecmisi anlatiyor ve font adi
///	oralarda GECIYOR — temizlenmezse test YANLIS ALARMA duser (turu 80b/83).
String _yorumsuz(String s) => s
    .split('\n')
    .where((l) {
      final t = l.trimLeft();
      return !t.startsWith('//') && !t.startsWith('///') && !t.startsWith('*');
    })
    .join('\n');
