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

  // ══════════ 4) GALERI: UC PROFIL EKRANINDA DA VAR ══════════

  const profilEkranlari = [
    'lib/features/chats/kisi_bilgi.dart',
    'lib/features/chats/grup_bilgi.dart',
    'lib/features/kanal/kanal_profil.dart',
  ];

  test('kisi · grup · kanal profillerinin UCUNDE DE paylasilan medya var', () {
    // ⚠️⚠️⚠️ TURU 180ac — kullanici: *"profillere tikladigimda galeri vs
    //	gorunmuyor, hem kisiselde hem grup kanalda; BUNU ATLIYORSUN
    //	SUREKLI"*. Muhafiz o atlamayi YAPISAL olarak kapatir: uc ekranin
    //	ucu de ORTAK bileseni kullanmak ZORUNDA.
    //
    // ⚠️⚠️ **BU TEST ILK YAZIMDA YALANCI-YESILDI** (bozularak bulundu):
    //	yalnizca `PaylasilanMedyaBolumu` METNINI ariyordu. Grup ekranindan
    //	CAGRI YERI (`_paylasilanMedya()`) silindiginde bolum ARTIK
    //	CIZILMIYOR ama metin yardimci metodun GOVDESINDE durdugu icin test
    //	YINE GECIYORDU — tam da "olu ozellik" riskinin kendisi.
    //	Olcut artik CAGRI YERI: yardimci metot tanimliysa adi EN AZ IKI KEZ
    //	gecmeli (tanim + cagri).
    for (final yol in profilEkranlari) {
      final govde = _yorumsuz(_oku(yol));
      expect(govde, contains('PaylasilanMedyaBolumu'),
          reason: '$yol icinde paylasilan medya bolumu YOK');
      final adet = RegExp('_paylasilanMedya').allMatches(govde).length;
      if (adet > 0) {
        expect(adet, greaterThanOrEqualTo(2),
            reason:
                '$yol: `_paylasilanMedya` tanimli ama HIC CAGRILMIYOR '
                '(olu kod — galeri ekranda cizilmez)');
      }
    }
  });

  test('izgara KOPYALANMADI (tek kaynak)', () {
    // ⚠️ Uc kopya kacinilmaz olarak DRIFT ederdi (turu 78 dersi). Izgarayi
    //	kuran widget YALNIZ ortak dosyada olmali.
    for (final yol in profilEkranlari) {
      expect(_yorumsuz(_oku(yol)).contains('GridView.builder'), isFalse,
          reason: '$yol kendi izgarasini kuruyor — ortak bilesen kullanilmali');
    }
    expect(_oku('lib/features/medya/paylasilan_medya.dart'),
        contains('GridView.builder'));
  });

  // ══════════ 5) SISTEM SOHBETLERI ══════════

  test('GebzemAI ve Gebzem App sohbet listesinde, sag alt balon YOK', () {
    final s = _oku('lib/features/chats/chats_screen.dart');
    expect(s, contains("'GebzemAI'"), reason: 'GebzemAI satiri YOK');
    expect(s, contains("'Gebzem App'"), reason: 'Gebzem App satiri YOK');
    expect(s, contains('GebzemAiEkrani'),
        reason: 'GebzemAI dokununca AI ekranina GITMELI');
    expect(s, contains('GebzemAppEkrani'),
        reason: 'Gebzem App dokununca bilgilendirme ekranina GITMELI');
    // ⚠️ Kullanici emri: *"sagdaki balonu kaldir"*. Govde duruyor ama
    //	CAGRI YERI olmamali.
    expect(_yorumsuz(s).contains('child: _aiDugmesi('), isFalse,
        reason: 'sag alttaki GebzemAI balonu KALDIRILMALI');
  });

  test('Gebzem App sohbeti SALT OKUNUR ve durustce soyluyor', () {
    final s = _oku('lib/features/chats/gebzem_app_sohbeti.dart');
    // ⚠️ Gorunen ama calismayan bir giris kutusu turu 66b dersinin tekrari.
    expect(_yorumsuz(s).contains('TextField'), isFalse,
        reason: 'bilgilendirme sohbetinde mesaj kutusu OLMAMALI');
    expect(s, contains('mesaj gönderilemez'),
        reason: 'salt okunur oldugu kullaniciya SOYLENMELI');
  });
}

String _oku(String yol) => File(yol).readAsStringSync();

/// ⚠️ Kaynagi YORUMLARDAN temizler: bir serhte gecen ornek metin testi
///	YANLIS ALARMA dusururdu (turu 80b/83'te birebir yasandi).
String _yorumsuz(String s) => s
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');
