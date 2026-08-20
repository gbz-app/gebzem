/// ⚠️⚠️ TURU 89 — GIRIS EKRANI **KAYIT AKISININ DILINE** cevrildi.
///
/// Kullanici emirleri:
///   · *"normal giris ekranindaki MESAJ IKONUNU ve GEBZEM yazisini kaldir"*
///   · *"kayit ekranindaki tarzin AYNISI giriste de olsun"*
///
/// ⚠️ Ortak parcalar **KOPYALANMADI**, `auth_stil.dart` TEK KAYNAGINDAN
///    geliyor (bkz. o dosyanin serhi: iki kopya kacinilmaz olarak drift eder).
/// ⚠️ HICBIR ISLEV KALDIRILMADI: telefon, sifre (goster/gizle), "Şifremi
///    unuttum", "Kayıt ol" ve hata mesajlari AYNEN duruyor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/tercihler.dart';
import 'auth_provider.dart';
import 'auth_stil.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// ⚠️⚠️ TURU 120 — DENETLEYICI **YALNIZ HANELERI** tutar (`5321234567`).
  ///	`+90` artik metnin parcasi DEGIL, `AuthTelefonAlani` icinde
  ///	`prefixText` ile CIZILIR ve silinmesi yapisal olarak imkansizdir
  ///	(kullanici emri: *"+90 SILINMESIN"*).
  /// ⚠️ Sunucuya giderken `authTamNumara()` KULLANILIR — elle `'+90' + text`
  ///    yazma; uc cagri yeri var ve biri `trim()` unuturdu.
  final _haneler = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  /// ⚠️⚠️ TURU 119 — GIRIS REDDEDILDIGINDE ALANLAR **KIRMIZI** olur
  ///	(kullanici emri: *"sifre hatali olunca input kirmizi olsun"*).
  ///
  /// ⚠️⚠️ Sunucu **"telefon veya şifre hatalı"** der; HANGISININ yanlis
  ///	oldugunu SOYLEMEZ (`internal/auth/handler.go:193` — bilincli: bir
  ///	numaranin kayitli olup olmadigini sizdirmamak icin). Bu yuzden:
  ///	  · IKI alan birden kirmizi olur,
  ///	  · aciklama da IKI IHTIMALI birden yazar.
  ///	*"Bu numarayla hesap yok"* demek, sunucunun SOYLEMEDIGI bir sey iddia
  ///	etmek olurdu — ustelik o cumle dogru olmadiginda kullanici sifresini
  ///	degil numarasini degistirmeye calisirdi.
  /// ⚠️ Kullanici YAZMAYA BASLAYINCA temizlenir (`_temizle`): kirmizi
  ///    kalirsa duzeltilmis bir alan hala hatali gorunur.
  bool _hatali = false;
  String? _hataNotu;

  /// Numara eksik/gecersizken alanin ALTINA konan aciklama.
  String? _telefonNotu;

  void _temizle() {
    if (_hatali || _hataNotu != null || _telefonNotu != null) {
      setState(() {
        _hatali = false;
        _hataNotu = null;
        _telefonNotu = null;
      });
    }
  }

  @override
  void dispose() {
    _haneler.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // ⚠️⚠️ TURU 120 — DOGRULAMA `Form`DAN ALINDI, ELLE YAPILIYOR.
    //	Alanlar artik paylasilan `AuthTelefonAlani`/`AuthSifreAlani`
    //	bilesenleri ve ikisi de `TextField` (FORM ALANI DEGIL). Eski
    //	`_formKey.currentState!.validate()` cagrisi burada **HER ZAMAN
    //	true** donerdi ve dogrulama SESSIZCE devre disi kalirdi.
    // ⚠️ YAPMA: bilesenleri `TextFormField`a cevirmeden `Form` dogrulamasina
    //    geri donme.
    if (!authTelefonTam(_haneler.text)) {
      setState(() {
        _telefonNotu = 'Numaranı eksiksiz yaz — 5 ile başlayan 10 hane.';
      });
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _hataNotu = 'Şifren en az 6 karakter olmalı.');
      return;
    }
    setState(() {
      _loading = true;
      _telefonNotu = null;
      _hataNotu = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .login(authTamNumara(_haneler.text), _password.text);
      // yonlendirmeyi router'in redirect'i yapar
    } catch (e) {
      if (mounted) {
        setState(() {
          _hatali = true;
          // ⚠️ Sunucunun mesaji SnackBar'da AYRICA gosterilir; alan altindaki
          //    satir NE YAPILACAGINI soyler (mesaj degil, YONLENDIRME).
          _hataNotu =
              'Numara ya da şifre hatalı. Numaranı kontrol et; '
              'şifreni unuttuysan aşağıdan sıfırlayabilirsin.';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// ⚠️⚠️ TURU 120 — TANITIMI YENIDEN GOSTER (kullanici emri: *"kullanici
  ///	girisine bir SIFIRLAMA butonu koy, YAZI OLARAK KUCUK; girdigimde
  ///	sifirlansin — onboarding bitince bir daha cikmiyor"*).
  ///
  /// ⚠️ Bayrak CIHAZ YERELIDIR (`shared_preferences`); sunucuya dokunmaz,
  ///    hesabi etkilemez. Yani bu bir "hesabi sifirla" DEGILDIR — etiket de
  ///    bunu acikca soyluyor.
  /// ⚠️ Yonlendirme `go('/onboarding')`: bayrak temizlendigi icin router'in
  ///    `redirect`i o rotada KALMASINA izin verir (`onboardingGoruldu` false
  ///    iken `/onboarding` disindaki her yol oraya donuyor).
  Future<void> _tanitimiSifirla() async {
    await tercihler.onboardingSifirla();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return AuthSayfa(
      child: SafeArea(
        child: Column(
          children: [
            // ⚠️ Kayit akisiyla AYNI ust bosluk: iki ekran arasinda gecerken
            //    baslik ZIPLAMASIN.
            const SizedBox(height: 48),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ⚠️ TURU 120 — aciklama "profesyonel"lestirildi (kullanici
                    //    emri). Onceki: *"Numaran ve şifrenle giriş yap."* —
                    //    ekranin ne oldugunu TEKRARLIYORDU. Yenisi ne
                    //    olacagini soyluyor.
                    authBaslik(
                      'Tekrar hoş geldin',
                      'Numaranı ve şifreni gir, kaldığın yerden devam et.',
                    ),
                    AuthTelefonAlani(
                      controller: _haneler,
                      hataliMi: _hatali,
                      not: _telefonNotu,
                      textInputAction: TextInputAction.next,
                      // ⚠️ `setState(_temizle)` YAZMA: `_temizle` KENDISI
                      //    `setState` cagiriyor; ic ice `setState` her tusta
                      //    GEREKSIZ ikinci bir yeniden kurulum yapardi.
                      onChanged: (_) => _temizle(),
                    ),
                    const SizedBox(height: 18),
                    AuthSifreAlani(
                      controller: _password,
                      hataliMi: _hatali,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => _temizle(),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_hataNotu != null) authNot(_hataNotu!),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => context.push('/forgot'),
                        style: TextButton.styleFrom(
                          foregroundColor: authAltYazi,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Şifremi unuttum'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ⚠️ Ana dugme ALTTA SABIT (kayit akisiyla ayni): klavye acikken
            //    de erisilir ve iki ekranda ayni yerde durur.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  authAnaDugme(
                    etiket: 'Giriş yap',
                    basildi: _submit,
                    mesgul: _loading,
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => context.push('/register'),
                    style: TextButton.styleFrom(foregroundColor: authAltYazi),
                    child: const Text('Hesabın yok mu? Kayıt ol'),
                  ),
                  // ⚠️ KUCUK ve SOLUK: kullanici *"yazi olarak KUCUK"* dedi.
                  //    Ana eylemlerle gorsel olarak yarismamali.
                  TextButton(
                    onPressed: _loading ? null : _tanitimiSifirla,
                    style: TextButton.styleFrom(
                      foregroundColor: authAltYazi.withValues(alpha: 0.75),
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Tanıtımı yeniden göster',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
