import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/core/theme.dart';

/// ⚠️⚠️⚠️ TURU 180ab — SOHBET AYARLARI MUHAFIZI.
///
/// Bu turda EKLENEN bes ayarin (tema · takma ad · sureli mesaj · yazma
/// gostergesi · okundu bilgisi) sunucuda karsiligi YOK ve deger CIHAZDA
/// tutuluyor. Boyle bir ozellikte EN BUYUK risk **OLU OZELLIK**: deger
/// yazilir ama onu OKUYAN yol yazilmaz (bu projede DOKUZ kez sahaya cikti).
///
/// Bu dosya o riski YAPISAL olarak kapatir: her ayarin bir TUKETICISI
/// oldugunu KAYNAKTAN dogrular.
void main() {
  // ══════════════════ 1) PALET: OLU SECENEK YOK ══════════════════

  test('kSohbetTemalari icindeki HER renk balonda GERCEKTEN farkli cizilir',
      () {
    // ⚠️ `bubbleMineTema` bilinmeyen anahtari VARSAYILANA dusurur. Listeye
    //	eklenen ama `switch`e yazilmayan bir renk bu yuzden SESSIZCE
    //	varsayilan gorunurdu — gorunen ama calismayan secenek (turu 66b).
    for (final tema in [kKoyuTema, lightTheme]) {
      final ks = tema.colorScheme;
      final varsayilan = ks.bubbleMineTema('varsayilan');
      final gorulen = <Color, String>{};
      for (final t in kSohbetTemalari) {
        final renk = ks.bubbleMineTema(t.anahtar);
        if (t.anahtar == 'varsayilan') {
          expect(renk, varsayilan);
          continue;
        }
        expect(renk, isNot(varsayilan),
            reason:
                '"${t.ad}" balonda varsayilana dusuyor — `bubbleMineTema` '
                'switch\'ine eklenmemis (OLU SECENEK)');
        expect(gorulen.containsKey(renk), isFalse,
            reason: '"${t.ad}" ile "${gorulen[renk]}" AYNI rengi veriyor');
        gorulen[renk] = t.ad;
      }
    }
  });

  test('bilinmeyen tema anahtari VARSAYILANA duser (sohbet renksiz kalmaz)',
      () {
    final ks = kKoyuTema.colorScheme;
    // ⚠️ Eski bir tercih dosyasi ya da ileride kaldirilan bir renk sohbeti
    //	RENKSIZ birakmamali.
    expect(ks.bubbleMineTema('boyle-bir-renk-yok'), ks.bubbleMine);
    expect(ks.bubbleMineTema(''), ks.bubbleMine);
  });

  test('acik ve koyu tonlar AYRI (koyu ton acik temada kullanilmaz)', () {
    // ⚠️ Ayni tonu iki temada kullanmak "koyu zemine koyu yazi" sinifini
    //	geri getirirdi (turu 115b'de olculdu).
    final koyu = kKoyuTema.colorScheme;
    final acik = lightTheme.colorScheme;
    for (final t in kSohbetTemalari) {
      expect(koyu.bubbleMineTema(t.anahtar),
          isNot(acik.bubbleMineTema(t.anahtar)),
          reason: '"${t.ad}" acik ve koyu temada AYNI ton');
    }
  });

  // ══════════════ 2) OLU OZELLIK YOK: HER AYARIN TUKETICISI VAR ══════════

  test('her ayarin OKUYAN bir yolu var (olu ozellik muhafizi)', () {
    // ⚠️⚠️ Kaynak DOSYADAN okunur (kopya YOK -> drift imkansiz —
    //	`harita_stili_test.dart` ve `sutun_test.go` ile ayni desen).
    final chatEkran = _oku('lib/features/chats/chat_screen.dart');
    final chatListe = _oku('lib/features/chats/chats_screen.dart');
    final kisiBilgi = _oku('lib/features/chats/kisi_bilgi.dart');

    // (a) TEMA -> balon rengi
    expect(chatEkran, contains('tercihler.sohbetTemasi('),
        reason: 'sohbet temasi HICBIR YERDEN okunmuyor (balon rengi olu)');
    expect(chatEkran, contains('bubbleMineTema('),
        reason: 'balon rengi tema anahtarini KULLANMIYOR');

    // (b) TAKMA AD -> sohbet basligi VE liste satiri
    expect(chatEkran, contains('tercihler.takmaAd('),
        reason: 'takma ad sohbet basliginda okunmuyor');
    expect(chatListe, contains('tercihler.takmaAd('),
        reason: 'takma ad sohbet LISTESINDE okunmuyor (iki yuzey ayrisir)');

    // (c) YAZMA GOSTERGESI -> typing olayi
    expect(chatEkran, contains('tercihler.yazmaGostergesi'),
        reason: 'yazma gostergesi tercihi HICBIR YERDE uygulanmiyor');

    // (d) SURELI MESAJ + TEMA -> kisi bilgisi ekraninda DEGER gosterilir
    expect(kisiBilgi, contains('tercihler.sureliMesaj('),
        reason: 'sureli mesaj secimi hicbir yerde GORUNMUYOR');
    expect(kisiBilgi, contains('tercihler.sohbetTemasi('),
        reason: 'tema secimi kisi bilgisi ekraninda GORUNMUYOR');
  });

  test('yazma gostergesi kapisi KISMALAMANIN USTUNDE', () {
    // ⚠️ Kapi `_typingThrottle` kontrolunun ALTINA konsaydi, ayar kapaliyken
    //	de zamanlayici kurulur ve ayar acildiginda ilk 2 saniye SESSIZ
    //	kalirdi.
    final s = _oku('lib/features/chats/chat_screen.dart');
    final kapi = s.indexOf('if (!tercihler.yazmaGostergesi) return;');
    final kisma = s.indexOf('_typingThrottle?.isActive');
    expect(kapi, greaterThan(0), reason: 'yazma gostergesi kapisi YOK');
    expect(kapi, lessThan(kisma),
        reason: 'kapi kismalamanin USTUNDE olmali');
  });

  // ══════════════ 3) DURUSTLUK: KARSILIGI OLMAYAN AYAR SOYLENIR ══════════

  test('sunucuda karsiligi olmayan HER ayar ekranda DURUST SINIR tasir', () {
    final s = _oku('lib/features/chats/sohbet_ayarlari.dart');
    // ⚠️⚠️ Sessizce yerelde tutup "ayarlandi" demek turu 135'te (uydurma kur
    //	seridi) reddedilen sinifin ta kendisi. Her ekranin altinda kullaniciya
    //	NE OLDUGUNU soyleyen bir serit olmali.
    final serit = RegExp(r'_durustSinir\(').allMatches(s).length;
    // Sureli mesajlar · Tema · Takma adlar · Gizlilik · Mesaj arama = 5 cagri
    // + 1 tanim.
    expect(serit, greaterThanOrEqualTo(6),
        reason: 'karsiligi olmayan ayarlarin altinda DURUST SINIR eksik');
    expect(s, contains('yalnızca bu cihazda'),
        reason: 'kullaniciya "yalnizca bu cihazda" ACIKCA soylenmeli');
  });

  test('"Kisitla" CIZILMEDI (sunucuda karsiligi yok)', () {
    // ⚠️ Instagram ekran goruntusunde VAR ama bizde uc/sutun YOK (olculdu).
    //	Gorunen ama calismayan bir satir koymak yerine ne oldugu SOYLENIYOR.
    final s = _oku('lib/features/chats/sohbet_ayarlari.dart');
    final k = _oku('lib/features/chats/kisi_bilgi.dart');
    for (final kaynak in [s, k]) {
      final govde = _yorumsuz(kaynak);
      expect(govde.contains("'Kısıtla'"), isFalse,
          reason: '"Kisitla" satiri CIZILMEMELI — sunucuda karsiligi YOK');
    }
    expect(s, contains('Kısıtlama seçeneği henüz yok'),
        reason: 'kullaniciya kisitlamanin OLMADIGI soylenmeli');
  });
}

String _oku(String yol) => File(yol).readAsStringSync();

/// ⚠️ Kaynagi YORUMLARDAN temizler: bir serhte gecen ornek metin testi
///	YANLIS ALARMA dusururdu (turu 80b/83'te birebir yasandi).
String _yorumsuz(String s) => s
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');
