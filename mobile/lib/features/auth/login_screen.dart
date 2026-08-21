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

  /// ⚠️⚠️⚠️ TURU 126 — **SIFRE ALANI BASTA GIZLI** (kullanici emri:
  ///	*"hizli bir sekilde sifreyi de kaldir"*).
  ///
  /// ⚠️⚠️ **TAMAMEN KALDIRILAMAZ**: sunucunun `/auth/login` ucu telefon VE
  ///	sifreyi ZORUNLU tutuyor; sifresiz giris yapisal olarak imkansiz
  ///	(oturum jetonu ureten uc noktanin ucu de `bcrypt` karsilastirmasi
  ///	yapiyor). Alan silinseydi HIC KIMSE giris yapamazdi.
  ///	Bu yuzden EKRANDAN gizlendi, AKISTAN degil: acilista referanstaki
  ///	gibi TEK ALAN gorunur, numara tamamlaninca sifre belirir.
  /// ⚠️⚠️ **BIR KEZ GORUNDUKTEN SONRA GIZLENMEZ** (`_sifreGorundu` yalniz
  ///	false -> true doner): kullanici numarayi duzeltmek icin tek hane
  ///	silseydi alan kaybolur ve YAZDIGI SIFRE de giderdi.
  bool _sifreGorundu = false;

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

  /// ⚠️⚠️⚠️ TURU 126 — **SIFRE ILK GORUNUMDE YOK, DUGMEYLE GELIR**
  ///	(kullanici emri: *"sifre vb seyleri kaldir"*).
  ///
  /// ⚠️⚠️ Alan **SILINEMEZ**: `/auth/login` telefon VE sifreyi zorunlu
  ///	tutuyor (`bcrypt.CompareHashAndPassword`), sifresiz oturum jetonu
  ///	ureten HICBIR uc yok. Silinseydi kimse giris YAPAMAZDI.
  /// ⚠️ Bu yuzden ekran iki asamali: once numara, "Giriş yap"a basilinca
  ///    sifre BELIRIR ve dugme ayni kalir. Kullanici ikinci dokunusta
  ///    gercekten giris yapar.
  /// ⚠️ Kapi TEK YONLU: bir kez acilinca kapanmaz — numarayi duzeltmek icin
  ///    tek hane silen kullanicinin yazdigi sifre kaybolmasin.
  Future<void> _submit() async {
    if (!_sifreGorundu) {
      if (!authTelefonTam(_haneler.text)) {
        setState(() {
          _telefonNotu = 'Numaranı eksiksiz yaz — 5 ile başlayan 10 hane.';
        });
        return;
      }
      setState(() {
        _telefonNotu = null;
        _sifreGorundu = true;
      });
      return;
    }
    return _girisYap();
  }

  Future<void> _girisYap() async {
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
            const SizedBox(height: 28),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ⚠️⚠️ TURU 126 — **ACIKLAMA SATIRI KALDIRILDI**
                    //	(kullanici referansi + emri: *"buyuk yazinin altina
                    //	telefon olacak"*). Referans tasarimda baslik ile
                    //	giris alani DOGRUDAN komsu; aradaki aciklama o
                    //	komsulugu bozuyordu.
                    // ⚠️ Bilgi KAYBOLMADI: eski aciklama (*"Numaranı ve
                    //    şifreni gir"*) ekranin ne oldugunu TEKRARLIYORDU;
                    //    alanlarin kendi ipuclari ("5xx xxx xx xx" · "Şifren")
                    //    ayni seyi DURDUGU YERDE soyluyor.
                    // ⚠️ TURU 126 — baslik *"Tekrar hoş geldin"* DEGIL
                    //    **"Telefon Numarası"** (kullanici emri). Referans
                    //    tasarimda baslik bir KARSILAMA degil, altindaki
                    //    alanin ADIDIR ("Enter your email").
                    // ⚠️⚠️ TURU 126 — BASLIGIN **USTUNDE** ince ust satir
                    //	(kullanici emri: *"2 tik ince ... daha profesyonel
                    //	olsun kisa"*).
                    // ⚠️⚠️ **METIN "sana bir sifre gonderecegiz" DEGIL.**
                    //	Kullanicinin onerdigi cumle buydu ama uygulama sifre
                    //	GONDERMIYOR: `/auth/login` mevcut sifreyi `bcrypt`
                    //	ile karsilastirir, hicbir uc kullaniciya sifre/kod
                    //	yollamaz (yollayan tek uc `/auth/forgot` ve o SIFRE
                    //	SIFIRLAMA akisidir). Olmayan bir vaadi ekrana yazmak,
                    //	kullanicinin SMS beklemesine ve gelmeyince "uygulama
                    //	bozuk" demesine yol acardi.
                    // ⚠️ BEKLEYEN: "kod ile giris" istenirse iki yeni uc
                    //    gerekir; arayuz turu oldugu icin acilmadi.
                    Text(
                      // ⚠️ Turkce yazim: ozel ada gelen ek KESME ISARETIYLE
                      //    ayrilir -> "Gebzem'e". Dart'ta tek tirnakli dize
                      //    icinde kesme isareti tirnagi KAPATIR; bu yuzden
                      //    dize CIFT TIRNAKLI.
                      "Gebzem'e hoş geldin.",
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.35,
                        color: authAltYazi.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    authBaslik('Hadi başlayalım'),
                    AuthTelefonAlani(
                      controller: _haneler,
                      hataliMi: _hatali,
                      not: _telefonNotu,
                      textInputAction: TextInputAction.next,
                      sade: true,
                      // ⚠️ `setState(_temizle)` YAZMA: `_temizle` KENDISI
                      //    `setState` cagiriyor; ic ice `setState` her tusta
                      //    GEREKSIZ ikinci bir yeniden kurulum yapardi.
                      onChanged: (_) => _temizle(),
                    ),
                    // ⚠️ TURU 126 — sifre bloku YALNIZ numara tamamlaninca.
                    //    "Şifremi unuttum" de onunla BIRLIKTE gelir: sifre
                    //    alani gorunmeden sifre sifirlama teklif etmek
                    //    anlamsizdi.
                    if (_sifreGorundu) ...[
                      // ⚠️ TURU 126 — 18 -> 26: cizgi kalkinca iki alani
                      //    ayiran TEK sey BOSLUK. 18 dp'de 24 px'lik iki
                      //    satir tek bir blok gibi okunuyordu.
                      const SizedBox(height: 26),
                      AuthSifreAlani(
                        controller: _password,
                        hataliMi: _hatali,
                        // ⚠️ SADE MODDA IPUCU ZORUNLU: etiket ("Şifre")
                        //    cizilmiyor, alanin ne istedigini soyleyen tek
                        //    sey bu. Ipucusuz sade alan = bos bir satir.
                        ipucu: 'Şifren',
                        textInputAction: TextInputAction.done,
                        sade: true,
                        onChanged: (_) => _temizle(),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_hataNotu != null) authNot(_hataNotu!),
                      // ⚠️ TURU 126 — SOLA DAYALI: alanlar da (on ek
                      //    yuzunden) sola dayali; ortalansaydi sayfanin tek
                      //    "kacik" ogesi bu satir olurdu.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/forgot'),
                          style: TextButton.styleFrom(
                            foregroundColor: authAltYazi,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Şifremi unuttum'),
                        ),
                      ),
                    ],
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
                  // ⚠️⚠️ TURU 126 — **DUZ KOSE, GOLGESIZ** (kullanici emri:
                  //	*"butondaki radüs gölge vs olmasın"*). Bir onceki
                  //	adimda referans gorseline gore `hap: true` denenmisti,
                  //	kullanici GERI ALDI.
                  // ⚠️ `hap` bayragi `auth_stil.dart`ta DURUYOR ama artik
                  //    HICBIR YERDEN cagrilmiyor; boylece turu 119'un
                  //    *"butonlari radus kaldir"* emri TUM kimlik
                  //    ekranlarinda yine gecerli.
                  authAnaDugme(
                    etiket: 'Giriş yap',
                    basildi: _submit,
                    mesgul: _loading,
                  ),
                  // ⚠️⚠️⚠️ TURU 126 — **"Hesabın yok mu? Kayıt ol" KALDIRILDI**
                  //	(kullanici emri).
                  // ⚠️⚠️ **BEKLEYEN IS:** bu, kayit akisina giden TEK yoldu
                  //	(`grep "'/register'"` -> yalniz burasiydi). Kaldirilmasiyla
                  //	`kayit_akisi.dart` ULASILAMAZ hale geldi: yeni kullanici
                  //	hesap ACAMAZ. Rota (`/register`) router'da DURUYOR,
                  //	yalnizca ITME yok — girisi nereye koyacagimiz
                  //	soylenince tek satirla geri baglanir.
                  // ⚠️ YAPMA: bunu "olu kod" sanip `/register` rotasini
                  //    router'dan silme.
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
