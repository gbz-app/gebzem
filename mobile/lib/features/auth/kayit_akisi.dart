/// ⚠️⚠️⚠️ TURU 84 — ADIMLI KAYIT EKRANI.
///
/// Kullanici emri: *"kayit sayfasi da step step: ilk telefon, sonra otp, sonra
/// kisisel bilgiler seklinde olacak; izinleri step sayfasinda alalim, video ses
/// icin aciklama yapalim ki kullanicilar anlasin"*.
///
/// ═══════════ UC ADIM ═══════════
///   0 · TELEFON        -> `/auth/kayit/telefon`  (hesap OLUSTURULMAZ)
///   1 · KOD            -> `/auth/kayit/dogrula`  (kayit jetonu alinir)
///   2 · KISISEL BILGI  -> `/auth/kayit/tamamla`  (hesap olusur, OTURUM ACILIR)
///
/// ⚠️⚠️⚠️ TURU 89 — **IZIN ADIMI KALDIRILDI.** Kullanici emri: *"sana
///    onboardingde izin al demistim; o izin ekrani icin AYRI SAYFAYI KALDIR,
///    onboardingte SIRAYLA GECERKEN izin alinsin"*.
///    Izinler artik `onboarding_ekrani.dart`ta aliniyor — her sayfa kendi
///    iznini istiyor ve aciklamasi da o sayfanin metninde.
///    Kurtarma yolu: **Ayarlar > IZINLER** (onboarding bayragi kalici
///    oldugu icin reddeden kullanicinin baska donus yolu kalmazdi).
///    ⚠️ YAPMA: buraya 4. adim olarak izin ekrani geri koyma.
///
/// ═══════════ TASARIM ═══════════
/// Onboarding ile AYNI dil: **beyaz zemin · yazilar SOLDA · baslik + kisa
/// aciklama**. Renkler SABIT (temadan alinmaz) — zemin sabit beyaz oldugu icin
/// koyu temada beyaz-uzeri-beyaz yazi cikardi (turu 81b kontrast dersi).
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'auth_provider.dart';
import 'auth_stil.dart';

const Color _yazi = Color(0xFF14141A);
const Color _altYazi = Color(0xFF6B6B76);
const Color _cizgi = Color(0xFFE3E3EA);

class KayitAkisi extends ConsumerStatefulWidget {
  const KayitAkisi({super.key});

  @override
  ConsumerState<KayitAkisi> createState() => _KayitAkisiState();
}

class _KayitAkisiState extends ConsumerState<KayitAkisi> {
  // ⚠️⚠️ TURU 119 — **DORT ADIM** (kullanici emri: *"kayit esnasinda step
  //	step olsun, PROFIL FOTOGRAFI EKLEME olsun, KIRPMA olsun, ortada
  //	resmi surukleyelim, istedigimiz gibi resmi ayarlayabilelim"*).
  //	0 telefon · 1 kod · 2 bilgiler · **3 fotograf**
  int _adim = 0;

  /// Secilen ham fotograf (kirpilmamis).
  File? _fotoHam;

  /// ⚠️ Kirpma alanini YAKALAMAK icin. `RepaintBoundary` + `toImage()`
  ///    ile daire viewport oldugu gibi goruntulenir — yani kullanicinin
  ///    EKRANDA GORDUGU kare ne ise yuklenen o olur.
  ///    Alternatif (matrisi elle cozup `image` paketiyle kirpmak) ayni
  ///    sonucu IKINCI bir hesapla uretirdi ve ikisi kacinilmaz olarak
  ///    ayrisirdi ("gordugum kirpim bu degil").
  final _kirpAnahtar = GlobalKey();

  /// Surukleme/yakinlastirma durumu.
  final _kirpKontrol = TransformationController();
  bool _mesgul = false;

  final _telefon = TextEditingController(text: '+90');
  final _kod = TextEditingController();
  final _ad = TextEditingController();
  final _kullaniciAdi = TextEditingController();
  final _sifre = TextEditingController();
  bool _sifreGizli = true;

  /// ⚠️ Adim 2'de alinir, adim 3'te kullanilir. 15 dk gecerli.
  String _kayitJetonu = '';

  /// Sunucuda TUKETILEN OTP. Geri donup ayni kodu tekrar gondermeyi engeller
  /// (bkz. `_koduDogrula` basindaki kapi).
  String _dogrulananKod = '';

  @override
  void dispose() {
    _kirpKontrol.dispose();
    _telefon.dispose();
    _kod.dispose();
    _ad.dispose();
    _kullaniciAdi.dispose();
    _sifre.dispose();
    super.dispose();
  }

  void _uyar(String m) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(m)));

  // ------------------------------------------------------------ ADIM 0
  Future<void> _telefonGonder() async {
    final tel = _telefon.text.trim();
    if (tel.length < 10) {
      _uyar('Telefon numaranı yaz');
      return;
    }
    setState(() => _mesgul = true);
    try {
      final devOtp = await ref.read(authProvider.notifier).kayitTelefon(tel);
      if (!mounted) return;
      // ⚠️ Test modunda kod yanitta doner ve otomatik dolar (mevcut OTP
      //    ekraniyla AYNI kolaylik). Gercek SMS'te alan BOS kalir.
      if (devOtp != null) _kod.text = devOtp;
      setState(() => _adim = 1);
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  // ------------------------------------------------------------ ADIM 1
  Future<void> _koduDogrula() async {
    final kod = _kod.text.trim();
    if (kod.length != 6) {
      _uyar('6 haneli kodu gir');
      return;
    }
    // ⚠️⚠️ TURU 85c — ELIMDE GECERLI JETON VARSA SUNUCUYA CIKMA (denetim).
    //
    //	`consumeOTP` kodu **TUKETIR** (tek kullanimlik). Kullanici adim 2'ye
    //	gecip GERI okuyla adim 1'e donerse kod kutusu HALA DOLUDUR ve
    //	"Doğrula"ya basmak DETERMINISTIK olarak 400 dondururdu
    //	("Kod hatalı ya da süresi dolmuş") — ustelik `catch` dali calisip
    //	elindeki **GECERLI** kayit jetonunu da kullanilamaz hale getirirdi
    //	(kullanici kodu yeniden isteyip bastan baslamak zorunda kalirdi).
    // ⚠️ Ayni kod + elde jeton = zaten dogrulanmis demektir; ileri gec.
    // ⚠️ YAPMA: bu kisa devreyi kaldirma ya da kod karsilastirmasini atlama
    //    (farkli bir kod girildiyse GERCEKTEN sunucuya cikmali).
    if (_kayitJetonu.isNotEmpty && kod == _dogrulananKod) {
      setState(() => _adim = 2);
      return;
    }
    setState(() => _mesgul = true);
    try {
      final jeton = await ref
          .read(authProvider.notifier)
          .kayitDogrula(_telefon.text.trim(), kod);
      if (!mounted) return;
      if (jeton.isEmpty) {
        _uyar('Doğrulama tamamlanamadı, tekrar dene');
        return;
      }
      setState(() {
        _kayitJetonu = jeton;
        // ⚠️ Hangi kodun TUKETILDIGI kaydedilir — geri donulup ayni kodla
        //    ilerlenirse sunucuya cikilmaz (bkz. metodun basindaki kapi).
        _dogrulananKod = kod;
        _adim = 2;
      });
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  // ------------------------------------------------------------ ADIM 2
  /// ⚠️⚠️ TURU 119 — DOGRULAMA **HESAP KURMADAN AYRILDI**.
  ///	Artik 2. adim yalnizca alanlari dogrular ve 3. adima (fotograf)
  ///	gecer; hesap 3. adimda kurulur.
  ///	⚠️ Dogrulama BURADA da kalir (`_hesabiKur` icinde TEKRAR edilir):
  ///	   kullanici 3. adimda geri donup alani BOSALTIP tekrar ilerlerse
  ///	   sunucuya bos ad gitmesin. Iki kapi da UCUZ ve ikisi de gerekli.
  void _bilgileriDogrula() {
    if (!_bilgilerGecerli()) return;
    setState(() => _adim = 3);
  }

  bool _bilgilerGecerli() {
    final ad = _ad.text.trim();
    final kadi = _kullaniciAdi.text.trim().toLowerCase();
    if (ad.isEmpty) {
      _uyar('Adını yaz');
      return false;
    }
    if (kadi.length < 3) {
      _uyar('Kullanıcı adı en az 3 karakter olmalı');
      return false;
    }
    if (_sifre.text.length < 6) {
      _uyar('Şifre en az 6 karakter olmalı');
      return false;
    }
    return true;
  }

  /// ⚠️ Dogrulama TEK YERDE (`_bilgilerGecerli`): burada TEKRAR edilmesi
  ///    kopya olurdu ve ikisi kacinilmaz olarak ayrisirdi.
  Future<void> _hesabiKur() async {
    if (!_bilgilerGecerli()) return;
    final ad = _ad.text.trim();
    final kadi = _kullaniciAdi.text.trim().toLowerCase();
    setState(() => _mesgul = true);
    try {
      await ref
          .read(authProvider.notifier)
          .kayitTamamla(
            jeton: _kayitJetonu,
            name: ad,
            username: kadi,
            password: _sifre.text,
          );
      if (!mounted) return;
      // ⚠️⚠️⚠️ TURU 119 — PROFIL FOTOGRAFI **HESAPTAN SONRA** yuklenir.
      //
      //	SIRA ZORUNLU: yukleme `POST /media/presign` ile baslar ve o uc
      //	OTURUM ISTER. Hesap kurulmadan once denenirse 401 doner.
      //
      // ⚠️⚠️ **FOTOGRAF HATASI KAYDI BOZMAZ.** Hesap ZATEN kuruldu ve
      //	oturum acildi; burada firlatilan bir istisna disaridaki `catch`e
      //	duser ve kullaniciya "kayit basarisiz" gibi gorunurdu — oysa
      //	hesabi VAR. Bu yuzden kendi `try`i icinde ve sessiz.
      //	Kullanici fotografini profil ekranindan her zaman degistirebilir.
      await _avatariYukle();
      if (!mounted) return;
      // ⚠️ TURU 89 — izin adimi KALKTI: hesap kurulur kurulmaz ana ekrana.
      //    Izinler onboardingte ZATEN alindi (uygulamanin ilk acilisinda).
      _bitir();
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  void _bitir() {
    // Oturum zaten acik; router ana ekrana yonlendirir.
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // ⚠️⚠️ TURU 85b — DURUM CUBUGU IKONLARI **KOYU** (denetim bulgusu).
      //    Zemin sabit beyaz yapildi ama durum cubugu stili TEMADAN geliyordu:
      //    koyu temada (ve Android'in `values-night/styles.xml` yolunda)
      //    ikonlar BEYAZ kaliyor ve beyaz zeminde **saat/pil/sinyal
      //    GORUNMUYORDU**. `AnnotatedRegion` bu ekran icin stili ZORLAR ve
      //    ekrandan cikilinca otomatik geri alinir.
      // ⚠️ `statusBarIconBrightness` ANDROID, `statusBarBrightness` iOS icin —
      //    ikisi BIRLIKTE yazilir ve iOS'ta anlam TERSTIR (`light` = acik
      //    ZEMIN = koyu ikon).
      // ⚠️ YAPMA: bu sarmali kaldirma; zemin beyaz kaldigi surece gerekli.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      // ⚠️⚠️⚠️ TURU 85b — EKRAN **ACIK TEMAYA SARILIYOR** (kok cozum).
      //
      //	Zemin sabit beyaz yapilinca ekran temanin geri kalanindan KOPTU:
      //	koyu temadaki kullanicida imlec rengi, secim vurgusu, `TextField`
      //	etiketleri, `helperText`, hata rengi ve dugme yazisi HALA KOYU
      //	temadan geliyordu -> beyaz zeminde BEYAZ imlec/yazi = GORUNMEZ.
      //	Bes metin alanini TEK TEK boyamak yerine tum alt agac `lightTheme`
      //	ile sariliyor; boylece bugun eklenmemis bir bilesen bile yarin
      //	DOGRU renkle cizilir (turu 81b'nin "~500 sabit renk noktasi"
      //	dersinin yapisal cevabi).
      // ⚠️ YAPMA: bunu kaldirip tek tek `cursorColor` yazmaya donme; yeni
      //    eklenen her alan sessizce gorunmez olur.
      // ⚠️⚠️ TURU 85c — DONANIM GERI TUSU KAPISI (denetim bulgusu).
      //
      //	`_ustCubuk` serhi *"IZIN ADIMINDA GERI YOK"* diyordu ama govdede
      //	uygulanan TEK sey ARAYUZ OKUNUN CIZILMEMESIYDI. Android donanim
      //	geri tusu (ve iOS kenar cekmesi) route'u yine de pop ediyor:
      //	kullanici 4. adimdan cikiyor, `izinSorulduIsaretle()` HIC kosmuyor
      //	ve `HomeScreen` kapisi izin ekranini YENIDEN aciyordu — yani turu
      //	85b'de kapatilan "ayni ekran arka arkaya iki kez" hatasi bu yoldan
      //	geri geliyordu.
      // ⚠️ Geri tusu AKISI TERK ETMEZ; "Şimdilik geç" ile AYNI yolu kosar
      //    (isaretle + ana ekrana git), yani kullanici mahsur da kalmaz.
      // ⚠️ Yalniz 4. adimda kilitlenir; 1-3. adimlarda geri normal calisir.
      child: Theme(
        data: lightTheme,
        child: Scaffold(
        // ⚠️ Zemin SABIT BEYAZ — onboarding ile ayni dil (kullanici emri).
        backgroundColor: Colors.white,
        body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ustCubuk(),
            _ilerlemeCubugu(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: switch (_adim) {
                  0 => _adimTelefon(),
                  1 => _adimKod(),
                  2 => _adimBilgiler(),
                  _ => _adimFotograf(),
                },
              ),
            ),
            _altDugme(),
          ],
          ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ORTAK
  Widget _ustCubuk() => SizedBox(
    height: 48,
    child: Row(
      children: [
        // ⚠️ IZIN ADIMINDA GERI YOK: hesap ZATEN kuruldu, geri donmek
        //    kullaniciyi doldurulmus ama artik gecersiz bir forma dondururdu.
        if (_adim > 0)
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: _yazi),
            onPressed: _mesgul ? null : () => setState(() => _adim -= 1),
          )
        else if (_adim == 0)
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: _yazi),
            onPressed: _mesgul ? null : () => context.go('/login'),
          ),
      ],
    ),
  );

  /// Uc adimlik ince ilerleme cubugu.
  ///
  /// ⚠️ Yuzde YAZISI YOK: adim adimlarin kendisi zaten gorunuyor ve yuzde
  ///    kullaniciya bir sey katmiyor (gorsel gurultu).
  Widget _ilerlemeCubugu() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Row(
      // ⚠️ TURU 119 — 3 -> **4** adim (fotograf adimi eklendi).
      children: List.generate(4, (i) {
        final dolu = i <= _adim;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
            decoration: BoxDecoration(
              color: dolu ? morLogo : _cizgi,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    ),
  );

  /// Baslik + KISA aciklama — onboarding ile ayni dil.
  Widget _baslik(String b, String aciklama) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        b,
        textAlign: TextAlign.left,
        style: const TextStyle(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: _yazi,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        aciklama,
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 14.5, height: 1.5, color: _altYazi),
      ),
      const SizedBox(height: 26),
    ],
  );

  /// ⚠️⚠️ TURU 119 — ALAN BICIMI **`auth_stil.authAlan`A DEVREDILDI.**
  ///
  ///	Burada AYRI bir kopya vardi (cerceveli `OutlineInputBorder`) ve
  ///	kullanici alt-cizgili yeni bicimi isteyince GIRIS ekrani degisti,
  ///	KAYIT ekrani ESKI HALINDE KALDI — iki ekran yan yana farkli
  ///	gorunuyordu. `auth_stil.dart`in varlik sebebi TAM BUDUR
  ///	(*"ayni kuralin iki kopyasi DRIFT EDER"*).
  /// ⚠️ YAPMA: buraya tekrar bir `InputDecoration` govdesi yazma.
  InputDecoration _alan(String etiket, {String? ipucu, Widget? sonek}) =>
      authAlan(etiket, ipucu: ipucu, sonek: sonek);

  // ------------------------------------------------------------ ADIM GOVDELERI
  Widget _adimTelefon() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Telefon numaran',
        'Numaranı doğrulayalım. Sana 6 haneli bir kod göndereceğiz.',
      ),
      TextField(
        controller: _telefon,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: _yazi, fontSize: 16),
        decoration: _alan('Telefon', ipucu: '+905xxxxxxxxx'),
      ),
      const SizedBox(height: 14),
      const Text(
        'Numaran kimseyle paylaşılmaz; yalnızca hesabını doğrulamak ve '
        'seni tanıdıklarının bulabilmesi için kullanılır.',
        style: TextStyle(fontSize: 12.5, height: 1.45, color: _altYazi),
      ),
    ],
  );

  Widget _adimKod() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Kodu gir',
        '${_telefon.text.trim()} numarasına gönderdiğimiz 6 haneli kodu yaz.',
      ),
      TextField(
        controller: _kod,
        keyboardType: TextInputType.number,
        maxLength: 6,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: _yazi,
          fontSize: 24,
          letterSpacing: 8,
          fontWeight: FontWeight.w700,
        ),
        decoration: _alan('6 haneli kod').copyWith(counterText: ''),
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: _mesgul ? null : _telefonGonder,
        style: TextButton.styleFrom(
          foregroundColor: morLogo,
          padding: EdgeInsets.zero,
        ),
        child: const Text('Kod gelmedi mi? Tekrar gönder'),
      ),
    ],
  );

  Widget _adimBilgiler() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik('Seni tanıyalım', 'Bu bilgiler profilinde görünecek.'),
      TextField(
        controller: _ad,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(color: _yazi, fontSize: 16),
        decoration: _alan('Adın Soyadın'),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _kullaniciAdi,
        style: const TextStyle(color: _yazi, fontSize: 16),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
        ],
        decoration: _alan('Kullanıcı adı', ipucu: 'ornek_kullanici'),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _sifre,
        obscureText: _sifreGizli,
        style: const TextStyle(color: _yazi, fontSize: 16),
        decoration: _alan(
          'Şifre',
          ipucu: 'En az 6 karakter',
          sonek: IconButton(
            icon: Icon(
              _sifreGizli ? LucideIcons.eye : LucideIcons.eyeOff,
              color: _altYazi,
              size: 20,
            ),
            onPressed: () => setState(() => _sifreGizli = !_sifreGizli),
          ),
        ),
      ),
    ],
  );


  /// Kirpilmis fotografi yukler ve profile baglar. **En iyi caba.**
  ///
  /// ⚠️ `gorseliHazirla` ZORUNLU: EXIF (KONUM) temizligi yapar; sunucu
  ///    GPS bulursa **422** doner (grup/kanal avatarlariyla ayni yol).
  /// ⚠️ Fotograf secilmediyse hicbir sey yapilmaz — adim OPSIYONEL.
  Future<void> _avatariYukle() async {
    if (_fotoHam == null) return;
    try {
      final kirpik = await _kirpilaniYakala();
      if (kirpik == null) return;
      final hazir = await MedyaServisi.gorseliHazirla(kirpik);
      if (hazir == null) return;
      final id = await ref.read(medyaServisiProvider).yukle(
        dosya: hazir,
        kind: 'avatar',
        mime: 'image/jpeg',
      );
      await ref.read(apiProvider).patch(
        '/users/me',
        data: {'avatar_media_id': id},
      );
    } catch (_) {
      // ⚠️ SESSIZ: hesap kuruldu, fotograf en iyi cabadir (bkz. cagri yeri).
    }
  }

  // ------------------------------------------------------------ ADIM 3
  /// ⚠️⚠️⚠️ TURU 119 — **PROFIL FOTOGRAFI + KIRPMA** (kullanici emri:
  ///	*"profil fotografi ekleme olsun, KIRPMA olsun, ortada resmi surukleme,
  ///	istedigimiz gibi resmi ayarlayabilelim"*).
  ///
  /// ⚠️⚠️ **KIRPMA `InteractiveViewer` ILE**: surukleme (pan) ve iki parmakla
  ///	yakinlastirma (scale) hazir gelir. Elle `GestureDetector` + `Matrix4`
  ///	yazmak ayni davranisi ikinci kez uretmek olurdu ve sinir durumlari
  ///	(cift parmak, hizli fling, olcek siniri) elde kalirdi.
  /// ⚠️ `clipBehavior: none` + disaridan `ClipOval`: kirpma DAIRE olmali,
  ///    `InteractiveViewer`in kendi dikdortgen kirpmasi degil.
  /// ⚠️ `boundaryMargin` GENIS: dar birakilirsa gorsel dairenin kenarina
  ///    yapisir ve kullanici yuzu ortalayamaz.
  Widget _adimFotograf() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Profil fotoğrafın',
        'İstersen şimdi ekle — sürükleyip yakınlaştırarak ayarlayabilirsin.',
      ),
      Center(
        child: Column(
          children: [
            // ── DAIRE KIRPMA ALANI ──
            SizedBox(
              width: 240,
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: _fotoHam == null
                          ? _fotoBos()
                          : RepaintBoundary(
                              key: _kirpAnahtar,
                              child: InteractiveViewer(
                                transformationController: _kirpKontrol,
                                clipBehavior: Clip.none,
                                minScale: 1,
                                maxScale: 4,
                                boundaryMargin: const EdgeInsets.all(120),
                                child: Image.file(
                                  _fotoHam!,
                                  width: 240,
                                  height: 240,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // ⚠️ Halka `IgnorePointer`: dokunuslar ALTTAKI
                  //    `InteractiveViewer`a gecmeli, yoksa surukleme calismaz.
                  IgnorePointer(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _cizgi, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _fotoDugme(
                  ikon: LucideIcons.imageUp,
                  etiket: _fotoHam == null ? 'Fotoğraf seç' : 'Değiştir',
                  basildi: _mesgul ? null : _fotoSec,
                ),
                if (_fotoHam != null) ...[
                  const SizedBox(width: 10),
                  _fotoDugme(
                    ikon: LucideIcons.rotateCcw,
                    etiket: 'Sıfırla',
                    // ⚠️ Kirpma matrisini basa alir; fotografi KALDIRMAZ.
                    basildi: _mesgul
                        ? null
                        : () => setState(
                            () => _kirpKontrol.value = Matrix4.identity(),
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _fotoBos() => ColoredBox(
    color: const Color(0xFFF2F2F5),
    child: Center(
      child: Icon(LucideIcons.userRound, size: 74, color: _altYazi),
    ),
  );

  Widget _fotoDugme({
    required IconData ikon,
    required String etiket,
    required VoidCallback? basildi,
  }) => OutlinedButton.icon(
    onPressed: basildi,
    icon: Icon(ikon, size: 17),
    label: Text(etiket),
    style: OutlinedButton.styleFrom(
      foregroundColor: _yazi,
      side: const BorderSide(color: _cizgi),
      // ⚠️ TURU 119 — radius YOK (kullanici emri, ana dugmeyle ayni dil).
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );

  Future<void> _fotoSec() async {
    // ⚠️⚠️ `MedyaKapisi` KAPILARI ZORUNLU: arama/oda/yayin sirasinda galeri
    //    acmak donanimi cakistirir. `grup_olustur.dart` ile BIREBIR ayni
    //    desen — ham `ImagePicker` bu kapilarin DISINDA kalirdi (turu 77b).
    if (!MedyaKapisi.donanimSerbest(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda fotoğraf seçilemez');
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      // ⚠️ `finally` ZORUNLU: bayrak asili kalirsa uygulama bir daha
      //    galeri acamaz.
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    setState(() {
      _fotoHam = File(x!.path);
      // ⚠️ Yeni fotografta kirpma SIFIRLANIR: onceki resmin yakinlastirmasi
      //    yeni resimde anlamsiz bir cerceve birakirdi.
      _kirpKontrol.value = Matrix4.identity();
    });
  }

  /// Daire viewport'u PNG olarak yakalar.
  ///
  /// ⚠️ `pixelRatio: 2.5` -> 240 dp * 2.5 = **600 px**. Avatar icin fazlasiyla
  ///    yeterli; daha yuksegi dosyayi buyutur, dusugu profil ekraninda
  ///    bulaniklastirir.
  /// ⚠️ Hata halinde `null` doner ve KAYIT YINE TAMAMLANIR — fotograf
  ///    OPSIYONEL bir adim; yakalama hatasi hesabi engellememeli.
  Future<File?> _kirpilaniYakala() async {
    try {
      final sinir =
          _kirpAnahtar.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (sinir == null) return null;
      final resim = await sinir.toImage(pixelRatio: 2.5);
      final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
      resim.dispose();
      if (bayt == null) return null;
      final dizin = await getTemporaryDirectory();
      final dosya = File(
        '${dizin.path}/kayit_avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await dosya.writeAsBytes(bayt.buffer.asUint8List(), flush: true);
      return dosya;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------ ALT DUGME
  Widget _altDugme() {
    final (etiket, is_) = switch (_adim) {
      0 => ('Kodu gönder', _telefonGonder),
      1 => ('Doğrula', _koduDogrula),
      // ⚠️ TURU 119 — 2. adim artik hesabi KURMAZ, fotograf adimina
      //    gecer; hesap 3. adimda kurulur.
      2 => ('Devam', _bilgileriDogrula),
      _ => ('Hesabı oluştur', _hesabiKur),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _mesgul ? null : is_,
              style: FilledButton.styleFrom(
                backgroundColor: morLogo,
                // ⚠️⚠️ TURU 85b — BEYAZ ZORUNLU: verilmezse koyu temada yazi
                //    `colorScheme.onPrimary`den (KOYU) gelir ve mor dugmede
                //    ~1.9:1 kontrastla OKUNAMAZ. Bu ekranin zemini SABIT
                //    beyaz oldugu icin renkler de temadan BAGIMSIZ olmali.
                foregroundColor: Colors.white,
                // ⚠️ Devre disi (mesgul) halde de temanin gri tonu beyaz
                //    zeminde kaybolabiliyordu -> acikca soluk mor.
                disabledBackgroundColor: morLogo.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white,
                // ⚠️ TURU 119 — radius KALDIRILDI (kullanici emri;
                //    `auth_stil.authAnaDugme` ile ayni dil).
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              child: _mesgul
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      etiket,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
