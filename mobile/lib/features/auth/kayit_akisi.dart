/// ⚠️⚠️⚠️ TURU 84 — ADIMLI KAYIT EKRANI.
///
/// Kullanici emri: *"kayit sayfasi da step step: ilk telefon, sonra otp, sonra
/// kisisel bilgiler seklinde olacak; izinleri step sayfasinda alalim, video ses
/// icin aciklama yapalim ki kullanicilar anlasin"*.
///
/// ═══════════ DORT ADIM ═══════════
///   0 · TELEFON        -> `/auth/kayit/telefon`  (hesap OLUSTURULMAZ)
///   1 · KOD            -> `/auth/kayit/dogrula`  (kayit jetonu alinir)
///   2 · KISISEL BILGI  -> `/auth/kayit/tamamla`  (hesap olusur, OTURUM ACILIR)
///   3 · IZINLER        -> sistem diyaloglari + NEDEN gerekli aciklamasi
///
/// ⚠️ **IZIN ADIMI OTURUM ACILDIKTAN SONRA** gelir. Sebep: izin diyaloglari
///    reddedilse bile hesap ZATEN kurulmus olmali — aksi halde izni reddeden
///    kullanici kayit olamamis sayilirdi.
///
/// ⚠️⚠️ `PermissionsScreen` REPODA VARDI AMA **HICBIR YERDEN CAGRILMIYORDU**
///    (yalnizca kendi dosyasinda gecen bir sinif). Yani izin ekrani ONUNCU
///    "olu ozellik" ornegiydi: yazilmis, test edilmemis, ulasilamaz.
///    Bu akis onu nihayet gercek bir yola bagliyor.
///
/// ═══════════ TASARIM ═══════════
/// Onboarding ile AYNI dil: **beyaz zemin · yazilar SOLDA · baslik + kisa
/// aciklama**. Renkler SABIT (temadan alinmaz) — zemin sabit beyaz oldugu icin
/// koyu temada beyaz-uzeri-beyaz yazi cikardi (turu 81b kontrast dersi).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import 'auth_provider.dart';

const Color _yazi = Color(0xFF14141A);
const Color _altYazi = Color(0xFF6B6B76);
const Color _cizgi = Color(0xFFE3E3EA);

class KayitAkisi extends ConsumerStatefulWidget {
  const KayitAkisi({super.key});

  @override
  ConsumerState<KayitAkisi> createState() => _KayitAkisiState();
}

class _KayitAkisiState extends ConsumerState<KayitAkisi> {
  int _adim = 0;
  bool _mesgul = false;

  final _telefon = TextEditingController(text: '+90');
  final _kod = TextEditingController();
  final _ad = TextEditingController();
  final _kullaniciAdi = TextEditingController();
  final _sifre = TextEditingController();
  bool _sifreGizli = true;

  /// ⚠️ Adim 2'de alinir, adim 3'te kullanilir. 15 dk gecerli.
  String _kayitJetonu = '';

  @override
  void dispose() {
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
        _adim = 2;
      });
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  // ------------------------------------------------------------ ADIM 2
  Future<void> _hesabiKur() async {
    final ad = _ad.text.trim();
    final kadi = _kullaniciAdi.text.trim().toLowerCase();
    if (ad.isEmpty) {
      _uyar('Adını yaz');
      return;
    }
    if (kadi.length < 3) {
      _uyar('Kullanıcı adı en az 3 karakter olmalı');
      return;
    }
    if (_sifre.text.length < 6) {
      _uyar('Şifre en az 6 karakter olmalı');
      return;
    }
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
      // ⚠️⚠️ OTURUM ACILDI ama YONLENDIRME YOK — izin adimina geciyoruz.
      //    `go_router` yonlendirmesi oturum acilinca ana ekrana atmak
      //    isteyecek; bu ekran yigindaki route oldugu icin izin adimi USTTE
      //    kalir ve kullanici "Devam"a basana kadar gorunur.
      setState(() => _adim = 3);
    } catch (e) {
      if (mounted) _uyar(apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  // ------------------------------------------------------------ ADIM 3
  Future<void> _izinleriIste() async {
    setState(() => _mesgul = true);
    try {
      // ⚠️ SIRA ONEMLI: bildirim -> mikrofon -> kamera. Diyaloglar SIRAYLA
      //    cikar; hepsini ayni anda istemek platformda TANIMSIZ davranistir.
      await Permission.notification.request();
      await Permission.microphone.request();
      await Permission.camera.request();
    } catch (_) {
      // Izin reddi HATA DEGIL — kullanici sonra Ayarlar'dan verebilir.
    }
    if (!mounted) return;
    setState(() => _mesgul = false);
    _bitir();
  }

  void _bitir() {
    // Oturum zaten acik; router ana ekrana yonlendirir.
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  _ => _adimIzinler(),
                },
              ),
            ),
            _altDugme(),
          ],
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
        if (_adim > 0 && _adim < 3)
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

  /// Dort adimlik ince ilerleme cubugu.
  ///
  /// ⚠️ Yuzde YAZISI YOK: adim adimlarin kendisi zaten gorunuyor ve yuzde
  ///    kullaniciya bir sey katmiyor (gorsel gurultu).
  Widget _ilerlemeCubugu() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Row(
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

  InputDecoration _alan(String etiket, {String? ipucu, Widget? sonek}) =>
      InputDecoration(
        labelText: etiket,
        hintText: ipucu,
        suffixIcon: sonek,
        labelStyle: const TextStyle(color: _altYazi),
        hintStyle: TextStyle(color: _altYazi.withValues(alpha: 0.6)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: _cizgi),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: morLogo, width: 1.6),
        ),
        border: const OutlineInputBorder(),
      );

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

  /// ⚠️⚠️ IZIN ADIMI — **HER IZNIN NEDENI YAZILI** (kullanici emri:
  ///    *"video ses icin aciklama yapalim ki kullanicilar anlasin"*).
  ///
  /// ⚠️ Sistem diyaloglari kendi metinlerini gosterir ve orada NEDEN
  ///    yazamayiz; bu yuzden gerekce diyalogdan ONCE burada anlatilir
  ///    (Apple'in ve Google'in onerdigi "pre-permission priming" deseni).
  ///    Aksi halde kullanici baglamsiz bir "mikrofona erisim" diyalogu gorup
  ///    reddediyor ve arama ozelligi SESSIZCE calismaz hale geliyor.
  Widget _adimIzinler() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _baslik(
        'Son bir adım',
        'Aramaların ve paylaşımların çalışması için birkaç izne ihtiyacımız var.',
      ),
      _izinSatiri(
        LucideIcons.mic,
        'Mikrofon',
        'Sesli arama, görüntülü arama ve sesli mesaj için. '
            'İzin vermezsen karşı taraf seni duyamaz.',
      ),
      _izinSatiri(
        LucideIcons.video,
        'Kamera',
        'Görüntülü arama, hikâye ve fotoğraf/video paylaşımı için. '
            'İzin vermezsen kameran açılmaz.',
      ),
      _izinSatiri(
        LucideIcons.bell,
        'Bildirim',
        'Mesaj ve arama geldiğinde haberin olsun diye. '
            'İzin vermezsen telefonun çalmaz.',
      ),
      const SizedBox(height: 8),
      const Text(
        'İzinleri sonra Ayarlar’dan da verebilirsin.',
        style: TextStyle(fontSize: 12.5, color: _altYazi),
      ),
    ],
  );

  Widget _izinSatiri(IconData ikon, String baslik, String aciklama) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: morLogo.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(ikon, size: 20, color: morLogo),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _yazi,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                aciklama,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: _altYazi,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------ ALT DUGME
  Widget _altDugme() {
    final (etiket, is_) = switch (_adim) {
      0 => ('Kodu gönder', _telefonGonder),
      1 => ('Doğrula', _koduDogrula),
      2 => ('Hesabı oluştur', _hesabiKur),
      _ => ('İzin ver ve başla', _izinleriIste),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
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
          // ⚠️ IZIN ADIMINDA "sonra" secenegi ZORUNLU: zorlamak App Store
          //    incelemesinde de kotu karsilanir ve kullaniciyi kaybettirir.
          if (_adim == 3)
            TextButton(
              onPressed: _mesgul ? null : _bitir,
              style: TextButton.styleFrom(foregroundColor: _altYazi),
              child: const Text('Şimdilik geç'),
            ),
        ],
      ),
    );
  }
}
