/// ⚠️⚠️ TURU 89 — GIRIS EKRANI **KAYIT AKISININ DILINE** cevrildi.
///
/// Kullanici emirleri:
///   · *"normal giris ekranindaki MESAJ IKONUNU ve GEBZEM yazisini kaldir"*
///   · *"kayit ekranindaki tarzin AYNISI giriste de olsun"*
///
/// ⚠️ Ortak parcalar **KOPYALANMADI**, `auth_stil.dart` TEK KAYNAGINDAN
///    geliyor (bkz. o dosyanin serhi: iki kopya kacinilmaz olarak drift eder).
/// ⚠️⚠️ TURU 126 — **BU SERH GUNCELLENDI.** Eskiden *"hicbir islev
///	kaldirilmadi"* diyordu; artik DOGRU DEGIL:
///	  · "Şifremi unuttum" EKRANDAN KALKTI (kullanici emri) -> sifresini
///	    unutan kullanicinin kurtarma yolu YOK,
///	  · "Hesabın yok mu? Kayıt ol" EKRANDAN KALKTI -> kayit akisina giden
///	    ITME kalmadi, yeni kullanici hesap ACAMAZ.
///	Iki rota da router'da DURUYOR; yalniz girisleri yok.
/// ⚠️ BEKLEYEN: ikisinin nereye konacagi kullanici karari.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  /// ⚠️⚠️⚠️ TURU 126 — **GIRIS VE KAYIT TEK KAPI** (kullanici emri:
  ///	*"telefon kayitli degilse kayit otpden sonra ad soyad vb devam
  ///	edecek"*). Kullanici artik "giris mi kayit mi" secmiyor: numarayi
  ///	yazar, gerisini uygulama karar verir.
  ///
  /// ⚠️⚠️ **"BU NUMARA KAYITLI MI" DIYE SORAN AYRI BIR UC YOK.**
  ///	`/auth/kayit/telefon` bu isi ZATEN yapiyor:
  ///	  · **409** -> numara KAYITLI (OTP GONDERMEZ) -> sifre asamasi,
  ///	  · **200** -> numara YENI ve OTP GONDERILDI -> kayit akisi.
  ///	Yani tek istekle hem kontrol hem kod gonderimi yapiliyor; ikinci
  ///	bir uc acmak ARAYUZ TURUNDA yasak (CLAUDE.md kural 9) ve gereksiz.
  /// ⚠️ Numaranin kayitli olup olmadigi ZATEN sizdiriliyordu (o ucun 409
  ///    metni acikca soyluyor); bu degisiklik yeni bir sizinti ACMIYOR.
  Future<void> _submit() async {
    if (_sifreGorundu) return _girisYap();
    if (!authTelefonTam(_haneler.text)) {
      setState(() {
        _telefonNotu = 'Numaranı eksiksiz yaz — 5 ile başlayan 10 hane.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _telefonNotu = null;
    });
    try {
      final devOtp = await ref
          .read(authProvider.notifier)
          .kayitTelefon(authTamNumara(_haneler.text));
      // 200 -> numara YENI, kod gonderildi: kayit akisina DEVRET.
      if (!mounted) return;
      context.push(
        '/register',
        extra: {'telefon': _haneler.text, 'otp': devOtp},
      );
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        // 409 -> numara KAYITLI: sifre asamasina gec.
        setState(() => _sifreGorundu = true);
        return;
      }
      _hataGoster(apiErrorMessage(e));
    } catch (e) {
      if (mounted) _hataGoster(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _hataGoster(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _girisYap() async {
    // ⚠️⚠️ TURU 120 — DOGRULAMA `Form`DAN ALINDI, ELLE YAPILIYOR.
    //	Alanlar artik paylasilan `AuthTelefonAlani`/`AuthSifreAlani`
    //	bilesenleri ve ikisi de `TextField` (FORM ALANI DEGIL). Eski
    //	`_formKey.currentState!.validate()` cagrisi burada **HER ZAMAN
    //	true** donerdi ve dogrulama SESSIZCE devre disi kalirdi.
    // ⚠️ YAPMA: bilesenleri `TextFormField`a cevirmeden `Form` dogrulamasina
    //    geri donme.
    // ⚠️⚠️⚠️ TURU 126 — **NUMARA BOZUKSA BIRINCI ASAMAYA DONULUR.**
    //	Ilk yazimda burada yalniz `_telefonNotu` set ediliyordu; ama ikinci
    //	asamada `AuthTelefonAlani` CIZILMIYOR (yerine sifre alani geliyor),
    //	yani not HICBIR YERDE gorunmuyordu: dugmeye basan kullanici icin
    //	ekran SESSIZCE hicbir sey yapmiyordu.
    if (!authTelefonTam(_haneler.text)) {
      setState(() {
        _sifreGorundu = false;
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
          // ⚠️⚠️ TURU 126 — **'aşağıdan sıfırlayabilirsin' KALDIRILDI.**
          //	O cumle 'Şifremi unuttum' baglantisini isaret ediyordu;
          //	baglanti bu turda ekrandan KALKTI, yani metin OLMAYAN bir
          //	yolu tarif ediyordu.
          // ⚠️ BEKLEYEN: sifre sifirlama girisi geri konunca cumle de geri gelmeli.
          _hataNotu = 'Numara ya da şifre hatalı. İkisini de kontrol et.';
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

  /// ⚠️⚠️⚠️ TURU 126 — **GERI ICIN TEK KAYNAK** (kardes `kayit_akisi` ile
  ///	ayni desen). Ekrandaki ok ikinci asamadan NUMARAYA donuyordu ama
  ///	SISTEM GERI TUSU dogrudan route`u pop ediyor, yani kullanici sifre
  ///	asamasindayken geri jesti yapinca **numarayi da kaybedip**
  ///	onboarding`e dusuyordu. Iki geri yolu ayni davranmali.
  void _geri() {
    if (_sifreGorundu) {
      // ⚠️ Ikinci asamadaysak once NUMARAYA don: kullanicinin bekledigi
      //    "geri" budur.
      setState(() => _sifreGorundu = false);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️⚠️ Sistem geri jesti de `_geri`den gecer (bkz. serh).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bittiMi, _) {
        if (bittiMi || _loading) return;
        _geri();
      },
      child: _govde(),
    );
  }

  Widget _govde() {
    // ⚠️⚠️⚠️ TURU 126 — **`viewInsets` BURADA OKUNMAZ** (kullanici:
    //	*"bos bir yere tikladigimda tus takimi kapanirken ekranda donma
    //	yapiyor"*).
    //
    //	`MediaQuery.viewInsetsOf(context)` bu `build`i klavyeye ABONE eder
    //	ve klavye acilip kapanirken deger HER KAREDE degisir — yani ~15-20
    //	kare boyunca **TUM SAYFA** yeniden kuruluyordu: baslik, 28 px'lik
    //	metinler, `AuthTelefonAlani` (kendi dinleyicisi olan bir
    //	`StatefulWidget`), `authNot`... Kapanma animasyonundaki takilmanin
    //	sebebi buydu.
    // ⚠️ Deger artik YALNIZ alt dugme blogundaki `Builder` icinde okunuyor;
    //    aboneligi o kucuk alt agac tasir, ust icerik HIC yeniden cizilmez.
    // ⚠️ YAPMA: `viewInsets`i tekrar `build`in basina tasima.
    return AuthSayfa(
      klavyeyeGoreKuculme: false,
      child: SafeArea(
        child: Column(
          children: [
            // ⚠️⚠️⚠️ TURU 126 — **SOL USTTE GERI OKU** (kullanici emri).
            //
            // ⚠️⚠️ **`context.pop()` KULLANILAMAZ**: `/login` yigindaki TEK
            //	sayfadir (`go` ile gelinir, `push` ile degil) ve GoRouter
            //	bos yiginda `pop()` cagirilinca **GoError FIRLATIR** —
            //	release'de de. Bu yuzden ok, gidilecek YER VARSA pop eder;
            //	yoksa tanitima doner (`/onboarding`), yani HER ZAMAN bir
            //	isi vardir. Islevsiz bir ok koymak, dokunup hicbir sey
            //	olmadigini goren kullaniciya "uygulama takildi" dedirtirdi.
            // ⚠️ Yukseklik 44: dokunma hedefi Material tavanina yakin ve
            //    ustteki 28 dp'lik bosluk KALDIRILDI (ok o boslugu doldurur),
            //    yani baslik asagi KAYMADI.
            // ⚠️ TURU 126 — OK **BASLIKLA AYNI HIZADA** (kullanici emri:
            //	*"ok disarida kalmis, ayni hizaya koy"*). `IconButton`
            //	varsayilan 48 dp kutuda ikonu ORTALAR, yani 24 dp ikon sola
            //	12 dp uzakta cizilir ve govde dolgusundan (28) **16 dp DAHA
            //	SOLDA** kalirdi. Dolgu sifirlanip disaridan 16 verilerek
            //	ikonun GORSEL sol kenari 28'e oturuyor.
            // ⚠️ Dokunma hedegi 44x44 KORUNUYOR (`constraints`).
            SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    // ⚠️⚠️ **`strokeWidth` YOKTUR**: `lucide_icons_flutter`
                    //	ikonlari bir FONT olarak sunar (glif), SVG DEGIL.
                    //	Kalinlik, ayni renkte ±0.4 px kaydirilmis DORT GOLGE
                    //	ile simule edilir (turu 93'te kurulan desen;
                    //	`isletme_listesi.dart` arama ikonu ayni yontemi
                    //	kullaniyor). `Icon`a `strokeWidth` yazarsan DERLENMEZ.
                    icon: const Icon(
                      LucideIcons.arrowLeft,
                      color: authYazi,
                      shadows: [
                        Shadow(color: authYazi, offset: Offset(0.4, 0)),
                        Shadow(color: authYazi, offset: Offset(-0.4, 0)),
                        Shadow(color: authYazi, offset: Offset(0, 0.4)),
                        Shadow(color: authYazi, offset: Offset(0, -0.4)),
                      ],
                    ),
                    onPressed: _loading ? null : _geri,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 17, 28, 24),
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
                    // ⚠️⚠️ TURU 126 — ASAMA 2 DE **HANGI NUMARA** OLDUGUNU
                    //	SOYLER (emulatorde goruldu). Numara asama 1 ekraninda
                    //	kaliyor ve asama 2 acilinca EKRANDA HICBIR IZI
                    //	kalmiyordu: yanlis numara yazan kullanici sifresini
                    //	yanlis saniyor, kontrol etmek icin geri donmek
                    //	zorunda kaliyordu. WhatsApp/Instagram da numarayi
                    //	bu adimda gosterir.
                    // ⚠️ Bicimlendirme  ile — SUNUCUYA
                    //    GIDEN numara DEGIL, yalniz gorunum.
                    Text(
                      _sifreGorundu
                          ? '${authNumaraGoster(_haneler.text)} için'
                          : 'Seni görmek ne güzel',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.35,
                        color: authAltYazi.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ⚠️ TURU 126 — baslik-alan araligi 28 -> 23 (kullanici:
                    //    *"numara 5 px daha yukarida"*). Parametre PAYLASILAN
                    //    `authBaslik`in varsayilanini DEGISTIRMEZ: kayit akisi
                    //    28'de kalir.
                    authBaslik(
                      _sifreGorundu ? 'Şifreni gir' : 'Hadi başlayalım',
                      null,
                      23,
                    ),
                    // ⚠️⚠️ TURU 126 — **IKI ASAMA, TEK EKRAN.** Sifre alani
                    //	telefonun ALTINDA DEGIL, YERINE gelir (kullanici
                    //	emri: *"sifre alanini kaldir"*). Boylece her asamada
                    //	ekranda TEK alan durur.
                    // ⚠️ Sifre SILINEMEZ: `/auth/login` telefon VE sifreyi
                    //    zorunlu tutuyor, sifresiz oturum jetonu ureten uc
                    //    YOK. Silinseydi kimse giris yapamazdi.
                    if (_sifreGorundu)
                      AuthSifreAlani(
                        controller: _password,
                        hataliMi: _hatali,
                        // ⚠️ SADE MODDA IPUCU ZORUNLU: etiket cizilmiyor,
                        //    alanin ne istedigini soyleyen tek sey bu.
                        ipucu: 'Şifren',
                        textInputAction: TextInputAction.done,
                        sade: true,
                        onChanged: (_) => _temizle(),
                        onSubmitted: (_) => _submit(),
                      )
                    else
                      AuthTelefonAlani(
                        controller: _haneler,
                        hataliMi: _hatali,
                        not: _telefonNotu,
                        textInputAction: TextInputAction.next,
                        sade: true,
                        // ⚠️ `setState(_temizle)` YAZMA: `_temizle` KENDISI
                        //    `setState` cagiriyor; ic ice `setState` her
                        //    tusta GEREKSIZ ikinci bir kurulum yapardi.
                        onChanged: (_) => _temizle(),
                      ),
                    if (_hataNotu != null) authNot(_hataNotu!),
                  ],
                ),
              ),
            ),
            // ⚠️ Ana dugme ALTTA SABIT (kayit akisiyla ayni): klavye acikken
            //    de erisilir ve iki ekranda ayni yerde durur.
            Builder(
              builder: (context) => Padding(
                padding: EdgeInsets.fromLTRB(
                  28,
                  8,
                  28,
                  10 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⚠️⚠️ TURU 126 — DUGMENIN USTUNDE **KISA NUMARA NOTU**
                    //	(kullanici emri: *"butonun ustune kisa prof bir
                    //	aciklama yaz istedigimiz telefon numarasi ile
                    //	ilgili"*).
                    // ⚠️ Metin YALNIZ birinci asamada (numara sorulurken)
                    //    cizilir; sifre asamasinda numarayla ilgisi kalmaz.
                    // ⚠️ *"Kod göndereceğiz"* DEMEZ: numara KAYITLIYSA kod
                    //    gitmez, sifre sorulur (bkz. `_submit` serhi). Vaat
                    //    edilen sey ancak GERCEKLESEN sey olmali.
                    // ⚠️ TURU 126 — IKON + **SOLA DAYALI** + 13.5 px (kullanici
                    //    emri). Ortali dururken sayfadaki tek ortali oge oydu;
                    //    ikon satiri bir "not" olarak isaretliyor.
                    if (!_sifreGorundu) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ⚠️ Ikon ILK SATIRIN ortasina hizali (satir
                          //    13.5 x 1.4 = 18.9; ikon 16) — `authNot` ile
                          //    ayni yontem.
                          const Padding(
                            padding: EdgeInsets.only(top: 1.45),
                            child: Icon(
                              LucideIcons.shieldCheck,
                              size: 16,
                              color: authAltYazi,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Numaran kimseyle paylaşılmaz.\n'
                              'Yalnızca hesabını doğrulamak için kullanılır.',
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: authAltYazi,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
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
                    // ⚠️⚠️⚠️ TURU 126 — **"Kayıt ol" GERI KONDU.**
                    //	Onceki adimda kullanici emriyle kaldirilmisti; ayni
                    //	turda kayit akisi 8 adima cikarilinca o akisa giden
                    //	TEK yol kapali kaldi — ne kullanici test edebiliyor
                    //	ne de yeni biri hesap acabiliyordu.
                    // ⚠️ Gorsel agirlik DUSUK tutuldu (12.5 px, %75 saydam):
                    //    ana eylemle yarismasin diye "Tanıtımı yeniden göster"
                    //    ile AYNI dilde.
                    // ⚠️⚠️ TURU 126 — **"Kayıt ol" ARTIK GEREKSIZ** (kullanici
                    //	emri). Numara kayitli DEGILSE "Giriş yap" kullaniciyi
                    //	ZATEN kayit akisina goturuyor (bkz. `_submit`), yani
                    //	ayri bir giris tutmak ayni ise IKI kapi acardi.
                    // ⚠️ Rota (`/register`) DURUYOR ve `_submit` icinden
                    //    push ediliyor — "olu kod" sanip silme.
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
            ),
          ],
        ),
      ),
    );
  }
}
