// ⚠️ TURU 87 — adres -> koordinat. Isletim sisteminin geocoder'ini kullanir,
//    API anahtari GEREKTIRMEZ (bkz. `_adrestenKoordinat` serhi).
// ⚠️⚠️ SURUM 5.x SART: 3.0.0 android-33'e derlenmis ve ANDROID BUILD'I
//    PATLATIYOR (`:geocoding_android:checkReleaseAarMetadata` — mevcut
//    androidx bagimliliklarimiz daha yuksek compileSdk istiyor).
// ⚠️ 5.x'te API **SINIF TABANLI**: ust duzey `locationFromAddress`
//    fonksiyonu KALDIRILDI, `Geocoding().locationFromAddress(...)` oldu.
import 'package:geocoding/geocoding.dart' show Geocoding;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../home/home_screen.dart' show myProfileProvider;
import '../home/profil_duzenle.dart';
// ⚠️ Konum alma TEK KAYNAK (turu 81) — izin/servis kontrolu orada.
import '../medya/konum_servisi.dart';
import 'isletme_servisi.dart';

/// ⚠️⚠️ TURU 77 — ISLETME PROFILINE GEC / BILGILERI DUZENLE.
///
/// Kullanici emri: "normal ve isletme profilleri olacak".
///
/// ⚠️ TEK EKRAN hem "gecis" hem "duzenleme" yapar. Ayri bir "isletmeye gec"
///    dugmesi olsaydi kullanici gecip alanlari bos birakabilir ve profili BOS
///    bir isletme olarak gorunurdu.
/// ⚠️ GIRIS NOKTASI: Profil sekmesi -> "İşletme hesabı". Bu projede "kod var
///    ama hicbir dugmeye bagli degil" hatasi BES kez yasandi; giris noktasi
///    ozellikle eklendi.
class IsletmeDuzenleEkrani extends ConsumerStatefulWidget {
  const IsletmeDuzenleEkrani({super.key});

  @override
  ConsumerState<IsletmeDuzenleEkrani> createState() =>
      _IsletmeDuzenleEkraniState();
}

class _IsletmeDuzenleEkraniState extends ConsumerState<IsletmeDuzenleEkrani> {
  final _adres = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _telefon = TextEditingController();
  final _web = TextEditingController();

  String _kategori = 'yemek';
  List<CalismaGunu> _calisma = [
    for (var g = 1; g <= 7; g++) CalismaGunu(gun: g),
  ];
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  /// ⚠️ Yukleme hatasi: form CIZILMEZ (bkz. build serhi — veri kaybi kapisi).
  bool _yuklemeHatasi = false;

  /// ⚠️⚠️ TURU 85 — ISLETMENIN KOORDINATI.
  ///
  ///	`isletmeler.enlem/boylam` sutunlari **028'den beri VARDI** ama
  ///	**HICBIR KAYITTA DOLU DEGILDI ve DOLDURACAK ARAYUZ YOKTU** — turu
  ///	78'de "harita ve yakinimda YOK, once koordinat girisi lazim" diye
  ///	acikca not edilmisti. Bu alanlar o bosluğu kapatiyor.
  /// ⚠️⚠️⚠️ TURU 85b — ALANLAR **NULLABLE** (denetim bulgusu, VERI KAYBI).
  ///
  ///	Ustteki eski serh *"`toJson` sifiri GONDERMEZ"* diyordu — bu ARTIK
  ///	DOGRU DEGIL: model `!= 0`dan `!= null`a cevrildi (cunku `!= 0` olcutu
  ///	"Konumu kaldır" dugmesini OLU birakiyordu). Ekran ise hala `double`
  ///	tutup `i.enlem ?? 0` yaziyordu, yani konumu OLMAYAN her kayitta
  ///	sunucuya ACIKCA `0` gonderiyordu = **"KONUMU SIFIRLA"** emri.
  ///
  ///	SOMUT KAYIP: kisisel hesaba donen bir isletmenin `isletmeler` satiri
  ///	SILINMEZ (veri politikasi) ve koordinati orada DURUR. Kullanici tekrar
  ///	isletmeye gecerken `detay()` 404 doner, form BOS acilir, `_enlem` 0
  ///	olur ve ilk kaydetmede **eski koordinat SILINIR** — geri alma yolu yok.
  ///
  /// SOZLESME: `null` = "bu alana DOKUNMA" · `0` = "SIFIRLA" (kaldir dugmesi).
  /// ⚠️ YAPMA: bu alanlari tekrar non-nullable yapma ya da `?? 0` ile doldurma.
  double? _enlem;
  double? _boylam;
  bool _konumAliniyor = false;
  bool _zatenIsletme = false;

  /// ⚠️⚠️⚠️ TURU 114 — **ADIM ADIM ISLETME HESABI** (kullanici emri:
  ///	*"isletme hesabi olusturma step step olsun"*).
  ///
  /// ⚠️⚠️ SIHIRBAZ **YALNIZ YENI HESAPTA** (`!_zatenIsletme`). Mevcut
  ///	isletme bilgisini duzenleyen biri tek bir alani degistirmek icin
  ///	uc adim gezmek zorunda kalmamali; orada TEK SAYFA form DOGRU
  ///	davranistir. Ayni ekranin iki modu var, ikinci bir ekran YAZILMADI
  ///	(iki kopya kacinilmaz olarak drift eder).
  ///
  /// ⚠️⚠️ **VERI TEK ISTEKTE GIDER**: adimlar yalnizca GORUNUMU boluyor;
  ///	sunucu `PUT /users/me/isletme` ile hepsini birlikte aliyor. Adim
  ///	basina kaydetseydik yarim kalan akista isletme kaydi EKSIK olusur
  ///	ve kullanici "hesabim bozuk" derdi.
  /// ⚠️ Yeni bir adim eklerken `_adimSayisi` ve `_adimGovde` BIRLIKTE
  ///    guncellenir.
  int _adim = 0;
  static const _adimSayisi = 3;
  static const _adimAdlari = ['Temel bilgiler', 'Adres & konum', 'Çalışma saatleri'];

  /// Sihirbaz modunda miyiz?
  bool get _sihirbaz => !_zatenIsletme;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _adres.dispose();
    _il.dispose();
    _ilce.dispose();
    _telefon.dispose();
    _web.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    // ⚠️⚠️⚠️ TURU 78b — KIMLIK YOKSA DA **HATA DALI** (denetim: VERI KAYBI).
    //
    //    Turu 77b bu veri kaybi icin `_yuklemeHatasi` kapisini yazmisti ama
    //    kapiyi YALNIZ `catch` dalina koydu; KARDES DAL (`id.isEmpty`) acik
    //    kaldi — CLAUDE.md'nin "ayni kuralin iki kopyasi drift eder" sinifi.
    //
    //    `myProfileProvider` bir `FutureProvider`dir ve `/users/me` bir kez
    //    hata verirse (mobil ag, sunucu restart'i) hata KALICI onbelleklenir;
    //    `valueOrNull` SUREC OMRU BOYUNCA null doner. Eski kod bu durumda
    //    formu BOS ve **Kaydet'i ETKIN** aciyordu. Kullanici tek alan doldurup
    //    kaydettiginde sunucudaki kosulsuz `ON CONFLICT DO UPDATE` adres, il,
    //    ilce ve web sitesini BOSA CEKIYOR; ustelik `_kategori` varsayilani
    //    'yemek' oldugu icin bir KUAFOR sessizce "Yemek" kategorisine gecip
    //    rehberde YER DEGISTIRIYOR ve calisma saatleri 09:00-18:00 varsayilanina
    //    dusuyordu (MAKUL GORUNDUGU icin tespiti daha da zor).
    //
    //    ⚠️ Once `.future` ile BEKLENIR: saglayici henuz cozulmemisse (yaris)
    //       eskiden bos form aciliyordu; artik gercek sonuc beklenir.
    //    ⚠️ YAPMA: bu dali sessiz `return`e dondurme.
    String id = (ref.read(myProfileProvider).valueOrNull?['id'] ?? '').toString();
    if (id.isEmpty) {
      try {
        final p = await ref.read(myProfileProvider.future);
        id = (p['id'] ?? '').toString();
      } catch (_) {
        id = '';
      }
    }
    if (!mounted) return;
    if (id.isEmpty) {
      setState(() {
        _yukleniyor = false;
        _yuklemeHatasi = true;
      });
      return;
    }
    // ⚠️⚠️ TURU 77b — YUKLEME HATASI **YUTULMAZ** (denetim bulgusu: VERI KAYBI).
    //    `detay()` artik 404 disindaki hatalarda FIRLATIYOR. Yakalanmazsa
    //    ekran BOS acilir, kullanici tek alan doldurup kaydeder ve sunucudaki
    //    `ON CONFLICT DO UPDATE` MEVCUT adres/telefon/calisma saatlerini
    //    BOSA CEKER. Bu dalda Kaydet KILITLENIR (bkz. `_yuklemeHatasi`).
    Isletme? i;
    try {
      i = await ref.read(isletmeServisiProvider).detay(id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _yuklemeHatasi = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      _yuklemeHatasi = false;
      if (i != null) {
        _zatenIsletme = true;
        _kategori = i.kategori;
        _adres.text = i.adres;
        _il.text = i.il;
        _ilce.text = i.ilce;
        _telefon.text = i.telefon;
        _web.text = i.web;
        // ⚠️ Mevcut konum FORMA YUKLENIR: yuklenmezse kullanici baska bir
        //    alani duzenleyip kaydettiginde `_enlem/_boylam` 0 kalir ve
        //    `toJson` onlari GONDERMEZ -> sunucudaki konum KORUNUR (COALESCE).
        //    Yani veri kaybi yok; ama ekranda "konum belirlenmedi" yazardi ve
        //    kullanici konumunu SILINMIS sanardi.
        // ⚠️ `?? 0` YOK — sozlesme korunur (bkz. alan serhi): sunucu konum
        //    dondurmediyse ekran da `null` tutar ve kaydetmede o alan
        //    GONDERILMEZ. `?? 0` yazilsaydi "sifirla" emri uretilirdi.
        _enlem = i.enlem;
        _boylam = i.boylam;
        // ⚠️ Sunucudan eksik gun gelebilir — 7 gunu TAMAMLA, yoksa listede
        //    bosluk olur ve kullanici o gunu hic ayarlayamaz.
        if (i.calisma.isNotEmpty) {
          _calisma = [
            for (var g = 1; g <= 7; g++)
              i.calisma.where((c) => c.gun == g).firstOrNull ??
                  CalismaGunu(gun: g),
          ];
        }
      }
    });
  }

  /// ⚠️⚠️⚠️ TURU 87 — ADRESTEN KOORDINAT (kullanici emri).
  ///
  ///	*"isletmeler adreslerinde yer isaretlemesi gerekiyor"* — turu 85'te
  ///	isletmenin haritada gorunmesi icin sahibinin ya DUKKANINDA olup
  ///	"Bulundugum konumu kullan"a basmasi ya da koordinati ELLE yazmasi
  ///	gerekiyordu. Ikisini de yapmayan isletme, adresini yazmis olsa bile
  ///	"Yakinimda" listesinde ve haritada **HIC GORUNMUYORDU** (sorgu
  ///	`enlem <> 0 OR boylam <> 0` suzgeciyle onu eliyor).
  ///
  ///	Artik konum BOSSA adres metninden otomatik cozumlenir. Cozumleme
  ///	ISLETIM SISTEMININ geocoder'ini kullanir (Android `Geocoder`, iOS
  ///	`CLGeocoder`) — **API anahtari GEREKTIRMEZ**.
  ///
  /// ⚠️ Yalnizca konum YOKKEN calisir: kullanici GPS ile ya da elle bir
  ///    koordinat belirlediyse ona DOKUNULMAZ (adres daha kaba bir bilgidir).
  /// ⚠️ Basarisizlik HATA DEGILDIR: ag yoksa ya da adres bulunamazsa kayit
  ///    normal surer, isletme yalnizca haritada gorunmez (elle giris durur).
  /// ⚠️ Sonuc ULKE ile sinirlanir ("..., Turkiye"): "Cumhuriyet Caddesi"
  ///    dunyada yuzlerce yerde var ve yanlis ulkeye pin dusmesi, hicbir pin
  ///    dusmemesinden DAHA KOTUDUR.
  Future<({double enlem, double boylam})?> _adrestenKoordinat() async {
    final parcalar = [
      _adres.text.trim(),
      _ilce.text.trim(),
      _il.text.trim(),
      'Türkiye',
    ].where((p) => p.isNotEmpty).toList();
    // ⚠️ Yalniz "Türkiye" kaldiysa arama anlamsizdir (ulke merkezine pin duser).
    if (parcalar.length < 2) return null;
    try {
      final sonuc = await Geocoding()
          .locationFromAddress(parcalar.join(', '))
          .timeout(const Duration(seconds: 12));
      if (sonuc.isEmpty) return null;
      final k = sonuc.first;
      if (k.latitude == 0 && k.longitude == 0) return null;
      return (enlem: k.latitude, boylam: k.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    // ⚠️ Konum belirlenmemisse ADRESTEN cozumle (bkz. `_adrestenKoordinat`).
    //    `_enlem` ACIKCA 0 ise kullanici "Konumu kaldir" demistir -> DOKUNMA.
    var enlem = _enlem, boylam = _boylam;
    if (enlem == null && boylam == null) {
      final k = await _adrestenKoordinat();
      if (k != null) {
        enlem = k.enlem;
        boylam = k.boylam;
      }
    }
    if (!mounted) return;
    try {
      await ref
          .read(isletmeServisiProvider)
          .kaydet(
            Isletme(
              kategori: _kategori,
              adres: _adres.text.trim(),
              il: _il.text.trim(),
              ilce: _ilce.text.trim(),
              telefon: _telefon.text.trim(),
              web: _web.text.trim(),
              calisma: _calisma,
              // ⚠️⚠️ TURU 85b — KOORDINAT SOZLESMESI: `null` gonderilmez
              //    (sunucu mevcudu korur), `0` ACIKCA sifirlar. Ayrintili
              //    gerekce `_enlem` alan serhinde.
              // ⚠️ TURU 87 — yerel degiskenler: adresten cozumlenmis olabilir.
              enlem: enlem,
              boylam: boylam,
            ),
          );
      if (!mounted) return;
      // ⚠️ Profil onbellegi TAZELENIR: `hesap_turu` degisti, profil ekrani
      //    isletme duzenini cizmeli. Tazelenmeseydi kullanici degisikligi
      //    ancak uygulamayi yeniden acinca gorurdu.
      ref.invalidate(myProfileProvider);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşletme profilin kaydedildi')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kaydedilemedi')));
    }
  }

  Future<void> _kisiselYap() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kişisel hesaba dön'),
        content: const Text(
          'İşletme bilgilerin silinmez, saklanır. İstediğin zaman tekrar '
          'işletme hesabına geçebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Geç'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await ref.read(isletmeServisiProvider).kisiselYap();
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem yapılamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // ⚠️⚠️ TURU 77b — YUKLEME HATASINDA FORM HIC GOSTERILMEZ.
    //    Bos form + etkin "Kaydet" = mevcut isletme bilgilerinin SESSIZCE
    //    SILINMESI (bkz. `_yukle` serhi). Tek cikis yolu tekrar denemek.
    if (_yuklemeHatasi) {
      return Scaffold(
        appBar: AppBar(title: const Text('İşletme bilgileri')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'İşletme bilgilerin yüklenemedi.\n'
                  'Mevcut bilgilerin kaybolmaması için form açılmadı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _yukleniyor = true;
                      _yuklemeHatasi = false;
                    });
                    _yukle();
                  },
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // ⚠️⚠️⚠️ TURU 114 (denetim) — **SIHIRBAZDA GERI TUSU ADIM ADIM.**
    //
    //	`_adim` bir State alani; geri gitmenin TEK yolu alt cubuktaki
    //	"Geri" dugmesiydi. Android donanim/jest geri tusu ve AppBar geri
    //	oku route'un TAMAMINI pop ediyor: ikinci adimda geri basan
    //	kullanici birinci adima DONMEK yerine ekrandan CIKIYOR ve
    //	doldurdugu her sey KAYBOLUYORDU (veri tek istekte gittigi icin
    //	hicbir sey kaydedilmemis oluyor).
    // ⚠️ Yalniz SIHIRBAZ modunda: tek sayfa formda geri tusu dogal olarak
    //    ekrani kapatmali.
    return PopScope(
      canPop: !_sihirbaz || _adim == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_sihirbaz && _adim > 0) setState(() => _adim--);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_zatenIsletme ? 'İşletme bilgileri' : 'İşletme hesabı'),
        // ⚠️ Sihirbazda ilerleme cubugu: kullanici KAC ADIM kaldigini
        //    gorsun (turu 91 talep sihirbaziyla ayni dil).
        bottom: _sihirbaz
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: (_adim + 1) / _adimSayisi,
                ),
              )
            : null,
        actions: [
          // ⚠️ Sihirbazda ust "Kaydet" YOK: kullanici ikinci adimdayken
          //    kaydetmesin — form YARIM giderdi ve kayit TEK istektir.
          if (!_sihirbaz)
            TextButton(
              onPressed: _kaydediliyor ? null : _kaydet,
              child: const Text('Kaydet'),
            ),
        ],
      ),
      bottomNavigationBar: _sihirbaz ? _adimCubugu() : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _sihirbaz ? _adimGovde() : _tumGovde(),
      ),
      ),
    );
  }

  /// Sihirbazin ALT CUBUGU — geri / devam / bitir.
  ///
  /// ⚠️⚠️⚠️ TURU 114 (denetim) — **ADIM ADI KENDI SATIRINDA.**
  ///
  ///	Ilk yazimda "Geri" + "1/3 · Temel bilgiler" + "İşletme hesabını aç"
  ///	TEK BIR `Row`daydi. 360 dp / yazi olcegi 1.3'te olculdu:
  ///	dugmenin sag kenari **441.9 dp**, ekran 360 dp — dugmenin yalnizca
  ///	**121 dp**'si gorunuyordu, yani *"İşletme hesabını aç"* dugmesi
  ///	EKRANIN DISINDA kaliyordu. `Spacer` sifira duser ve `Row` tasar.
  ///
  /// ⚠️ Adim adi **USTTE, KENDI SATIRINDA**; dugme satirinda yalnizca iki
  ///    dugme var ve etiket `FittedBox` ile kucultuluyor. Tasma artik
  ///    YAPISAL OLARAK imkansiz.
  /// ⚠️ YAPMA: adim adini tekrar dugme satirina koyma.
  Widget _adimCubugu() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_adim + 1}/$_adimSayisi · ${_adimAdlari[_adim]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // ⚠️ TURU 114 (denetim) — alfa 0.6 acik temada **4.35:1**;
            //    12 px normal metin icin esik 4.5:1. 0.75'e cikarildi.
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 6),
          Row(
        children: [
          if (_adim > 0)
            TextButton(
              onPressed: _kaydediliyor
                  ? null
                  : () => setState(() => _adim--),
              child: const Text('Geri'),
            ),
          const Spacer(),
          FilledButton(
            onPressed: _kaydediliyor
                ? null
                : () {
                    if (_adim < _adimSayisi - 1) {
                      setState(() => _adim++);
                    } else {
                      _kaydet();
                    }
                  },
            child: _kaydediliyor
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _adim < _adimSayisi - 1
                          ? 'Devam'
                          : 'İşletme hesabını aç',
                    ),
                  ),
          ),
        ],
          ),
        ],
      ),
    ),
  );

  /// ⚠️ Adim govdeleri TEK KAYNAKTAN (`_tumGovde` parcalari) uretilir:
  ///    alanlarin ikinci bir kopyasi yazilsaydi biri guncellenip oteki
  ///    geride kalirdi.
  List<Widget> _adimGovde() => switch (_adim) {
    0 => _bolumTemel(),
    1 => _bolumAdres(),
    _ => _bolumSaatler(),
  };

  List<Widget> _tumGovde() => [
    ..._bolumTemel(),
    const SizedBox(height: 20),
    ..._bolumAdres(),
    const SizedBox(height: 20),
    ..._bolumSaatler(),
    const SizedBox(height: 24),
    if (_zatenIsletme)
      OutlinedButton.icon(
        onPressed: _kisiselYap,
        icon: const Icon(LucideIcons.userRound, size: 18),
        label: const Text('Kişisel hesaba dön'),
      ),
    const SizedBox(height: 30),
  ];

  List<Widget> _bolumTemel() => [
          // ⚠️⚠️ TURU 78 — KAPAK VE LOGO **BURADAN DUZENLENMEZ**, yalnizca
          //    yonlendirilir. Gerekce yapisal:
          //      · Kapak ve avatar `users` tablosunda; bu ekran
          //        `POST /users/me/isletme` ile SADECE `isletmeler` tablosuna
          //        yaziyor ve `users`a HIC dokunmuyor. Kapagi buradan da
          //        yazdirmak TEK SUTUNA IKI YAZICI demekti = drift'in ta kendisi.
          //      · `ProfilDuzenleEkrani` presign -> R2 PUT -> commit zincirini,
          //        EXIF temizligini ve `MedyaKapisi` kamera kapisini ZATEN
          //        iceriyor; kopyalamak ~80 satir en kirilgan kodun ikizlenmesi
          //        olurdu.
          // ⚠️ YAPMA: buraya gorsel secici ekleme.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(LucideIcons.image),
            title: const Text('Kapak ve logo'),
            subtitle: const Text(
              'Profili düzenle ekranından değiştirilir',
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilDuzenleEkrani()),
            ),
          ),
    const Divider(height: 20),
    if (!_zatenIsletme)
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Text(
          'İşletme hesabına geçtiğinde profilinde kategori, adres, telefon '
          've çalışma saatlerin görünür; müşterilerin sana kolayca ulaşır.',
          // ⚠️ TURU 114 (denetim) — alfa 0.6 acik temada 4.35:1 (esik 4.5).
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    DropdownButtonFormField<String>(
            initialValue: _kategori,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in isletmeKategorileri.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _kategori = v ?? 'diger'),
          ),
    const SizedBox(height: 12),
    _alan(
      _telefon,
      'Telefon',
      LucideIcons.phone,
      tip: TextInputType.phone,
    ),
    const SizedBox(height: 12),
    _alan(_web, 'Web sitesi', LucideIcons.globe, tip: TextInputType.url),
  ];

  List<Widget> _bolumAdres() => [
    _alan(_adres, 'Adres', LucideIcons.mapPin, satir: 2),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(child: _alan(_il, 'İl', LucideIcons.building2)),
        const SizedBox(width: 10),
        Expanded(child: _alan(_ilce, 'İlçe', LucideIcons.map)),
      ],
    ),
    const SizedBox(height: 20),
    _konumBolumu(),
  ];

  List<Widget> _bolumSaatler() => [
    Text(
      'ÇALIŞMA SAATLERİ',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        // ⚠️ TURU 113 — `letterSpacing` KALDIRILDI (kullanici emri).
        // ⚠️ TURU 114 (denetim) — alfa 0.6 -> 0.75 (kontrast).
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
      ),
    ),
    const SizedBox(height: 6),
    for (final c in _calisma) _gunSatiri(c),
  ];

  /// ⚠️⚠️⚠️ TURU 85 — KONUM BOLUMU. **"Yakinimda"nin ON KOSULU.**
  ///
  /// Kullanici "yakinimda" ekrani istedi; o ekran isletmeleri MESAFEYE gore
  /// siralar. Ama `isletmeler.enlem/boylam` 028'den beri VAR olmasina ragmen
  /// **HICBIR KAYITTA DOLU DEGILDI** ve dolduracak bir arayuz YOKTU — turu
  /// 78'de bu acikca "once koordinat girisi lazim, yoksa harita bos tuval
  /// olur" diye not edilmisti. Bu bolum o boslugu kapatir.
  ///
  /// ⚠️ HARITADAN DOKUNARAK SECIM YOK (bilincli): "Yakınımda" ekranindaki
  ///    harita SALT GORUNUM (liste icinde oldugu icin kaydirma jesti kapali);
  ///    buraya ayri bir "haritadan sec" ekrani koymak yeni bir tam ekran
  ///    harita + kamera yonetimi demektir. Iki yol bugun YETIYOR:
  ///      · "Bulunduğum konumu kullan" — sahibi DUKKANINDAYKEN tek dokunus,
  ///      · **elle koordinat girisi** (asagida, `_ElleKonum`) — sahibi
  ///        dukkanda degilken ya da konum izni vermek istemiyorken.
  /// ⚠️⚠️ TURU 85b: elle giris serhte "BIRAKILDI" yaziyordu ama GOVDEDE YOKTU;
  ///    gercekten eklendi (ayrinti `_ElleKonum` bileseninde).
  Widget _konumBolumu() {
    final en = _enlem ?? 0, boy = _boylam ?? 0;
    final belirlendi = en != 0 || boy != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KONUM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            // ⚠️ TURU 113 — `letterSpacing` KALDIRILDI (kullanici emri).
          ),
        ),
        const SizedBox(height: 6),
        Text(
          belirlendi
              ? 'Konum belirlendi: ${en.toStringAsFixed(5)}, '
                    '${boy.toStringAsFixed(5)}'
              : 'Konum belirlenmedi. İşletmen “Yakınımda” listesinde '
                    'görünmesi için konumunu ekle.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: belirlendi
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _konumAliniyor ? null : _konumuAl,
                icon: _konumAliniyor
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.locateFixed, size: 18),
                label: Text(
                  belirlendi ? 'Konumu güncelle' : 'Bulunduğum konumu kullan',
                ),
              ),
            ),
            if (belirlendi) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Konumu kaldır',
                icon: const Icon(LucideIcons.x, size: 18),
                // ⚠️ ACIKCA 0 = "SIFIRLA" (bkz. `_enlem` alan serhi). `null`
                //    yazilsaydi sunucu mevcut konumu KORUR ve dugme yine OLU
                //    olurdu — turu 85'te tam bu hata yasandi.
                onPressed: () => setState(() {
                  _enlem = 0;
                  _boylam = 0;
                }),
              ),
            ],
          ],
        ),
        // ⚠️⚠️⚠️ TURU 85b — ELLE GIRIS **GERCEKTEN EKLENDI** (denetim bulgusu).
        //
        //	Ustteki serh yillardir *"Elle giris de BIRAKILDI"* diyordu ama
        //	govdede TEK BIR METIN ALANI BILE YOKTU — CLAUDE.md'nin defalarca
        //	yazdigi "yorumun anlattigi sey govdede yok" sinifi.
        //	SOMUT SONUC: konum iznini vermeyen ya da dukkaninda olmayan
        //	isletme sahibi koordinat GIREMIYOR, dolayisiyla isletmesi
        //	"Yakınımda" listesinde HIC gorunmuyordu. Tek yol GPS'ti.
        //
        // ⚠️ Alan `TextFormField` + `initialValue` DEGIL, controller'li:
        //    "Bulunduğum konumu kullan" degeri disaridan degistirdiginde
        //    `initialValue` guncellenmezdi (turu 77b hayalet-veri dersi).
        const SizedBox(height: 6),
        _ElleKonum(
          enlem: _enlem,
          boylam: _boylam,
          degisti: (e, b) => setState(() {
            _enlem = e;
            _boylam = b;
          }),
        ),
      ],
    );
  }

  Future<void> _konumuAl() async {
    setState(() => _konumAliniyor = true);
    try {
      // ⚠️ `KonumServisi` TEK KAYNAK (turu 81, sohbette konum paylasimi icin
      //    yazildi): izin isteme, servis kapali kontrolu ve hata mesajlari
      //    orada. Ikinci bir konum yolu yazmak o kapilari atlardi.
      final k = await KonumServisi.konumAl();
      if (!mounted) return;
      if (k == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum alınamadı — izin verildi mi?')),
        );
        return;
      }
      setState(() {
        _enlem = k.enlem;
        _boylam = k.boylam;
      });
    } finally {
      if (mounted) setState(() => _konumAliniyor = false);
    }
  }

  Widget _alan(
    TextEditingController c,
    String etiket,
    IconData ikon, {
    int satir = 1,
    TextInputType? tip,
  }) => TextField(
    controller: c,
    keyboardType: tip,
    minLines: satir,
    maxLines: satir,
    decoration: InputDecoration(
      labelText: etiket,
      prefixIcon: Icon(ikon, size: 19),
      border: const OutlineInputBorder(),
    ),
  );

  Widget _gunSatiri(CalismaGunu c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            gunAdlari[c.gun] ?? '',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        if (c.kapali)
          const Expanded(
            child: Text('Kapalı', style: TextStyle(color: Colors.grey)),
          )
        else ...[
          _saat(c.acilis, (v) => setState(() => c.acilis = v)),
          const Text('  –  '),
          _saat(c.kapanis, (v) => setState(() => c.kapanis = v)),
          const Spacer(),
        ],
        Switch(
          value: !c.kapali,
          onChanged: (v) => setState(() => c.kapali = !v),
        ),
      ],
    ),
  );

  /// ⚠️ `showTimePicker` KULLANILDI (elle metin girisi DEGIL): "9:5" gibi bozuk
  ///    degerler sunucuya gitmesin ve saat hesabi (`simdiAcik`) patlamasin.
  Widget _saat(String deger, void Function(String) onSec) => OutlinedButton(
    onPressed: () async {
      final p = deger.split(':');
      final ilk = TimeOfDay(
        hour: int.tryParse(p.isNotEmpty ? p[0] : '9') ?? 9,
        minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
      );
      final s = await showTimePicker(context: context, initialTime: ilk);
      if (s == null) return;
      onSec(
        '${s.hour.toString().padLeft(2, '0')}:'
        '${s.minute.toString().padLeft(2, '0')}',
      );
    },
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      minimumSize: const Size(0, 34),
    ),
    child: Text(deger, style: const TextStyle(fontSize: 13)),
  );
}

/// ELLE KOORDINAT GIRISI — bkz. `_konumBolumu` icindeki serh.
///
/// ⚠️ AYRI BILESEN: iki `TextEditingController` gerekiyor ve bunlarin
///    `dispose` edilmesi ZORUNLU. Ana State'e konsaydi, "Bulunduğum konumu
///    kullan" ile gelen degeri controller'lara yansitmak icin ana State'in
///    her `setState`inde senkronizasyon kodu gerekirdi; burada
///    `didUpdateWidget` ile TEK YERDE hallediliyor.
/// ⚠️ Gecersiz/eksik giris SESSIZCE yok sayilmaz — kullaniciya hata yazilir;
///    aksi halde "yazdim ama kaydolmadi" sikayeti uretirdi.
class _ElleKonum extends StatefulWidget {
  const _ElleKonum({
    required this.enlem,
    required this.boylam,
    required this.degisti,
  });

  final double? enlem;
  final double? boylam;
  final void Function(double enlem, double boylam) degisti;

  @override
  State<_ElleKonum> createState() => _ElleKonumState();
}

class _ElleKonumState extends State<_ElleKonum> {
  late final TextEditingController _en = TextEditingController(
    text: _metin(widget.enlem),
  );
  late final TextEditingController _boy = TextEditingController(
    text: _metin(widget.boylam),
  );
  bool _acik = false;
  String? _hata;

  static String _metin(double? d) =>
      (d == null || d == 0) ? '' : d.toStringAsFixed(6);

  @override
  void didUpdateWidget(covariant _ElleKonum eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Disaridan (GPS dugmesi / "Konumu kaldır") gelen degisiklik alanlara
    //    YANSITILIR. Kullanicinin O ANDA yazdigi metni EZMEMEK icin yalniz
    //    gercekten degistiginde yazilir.
    if (eski.enlem != widget.enlem) _en.text = _metin(widget.enlem);
    if (eski.boylam != widget.boylam) _boy.text = _metin(widget.boylam);
  }

  @override
  void dispose() {
    _en.dispose();
    _boy.dispose();
    super.dispose();
  }

  /// Yazarken sessizce ebeveyne tasir: gecerliyse yazar, degilse DOKUNMAZ.
  ///
  /// ⚠️ Burada hata GOSTERILMEZ — kullanici "40." yazarken kirmizi uyari
  ///    gormemeli. Acik geri bildirim "Uygula" dugmesinin isidir.
  void _yazdikca() {
    final e = double.tryParse(_en.text.trim().replaceAll(',', '.'));
    final b = double.tryParse(_boy.text.trim().replaceAll(',', '.'));
    if (e == null || b == null) return;
    if (e < -90 || e > 90 || b < -180 || b > 180) return;
    if (_hata != null) setState(() => _hata = null);
    widget.degisti(e, b);
  }

  void _uygula() {
    // ⚠️ Virgul de kabul edilir: Turkce klavyede ondalik ayirici VIRGULDUR ve
    //    `double.tryParse` virgullu metni `null` dondurur -> kullanici dogru
    //    koordinati yazip "gecersiz" hatasi alirdi.
    final e = double.tryParse(_en.text.trim().replaceAll(',', '.'));
    final b = double.tryParse(_boy.text.trim().replaceAll(',', '.'));
    if (e == null || b == null) {
      setState(() => _hata = 'Enlem ve boylamı sayı olarak yaz.');
      return;
    }
    if (e < -90 || e > 90 || b < -180 || b > 180) {
      setState(() => _hata = 'Enlem -90/90, boylam -180/180 aralığında olmalı.');
      return;
    }
    setState(() => _hata = null);
    widget.degisti(e, b);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konum ayarlandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_acik) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _acik = true),
          icon: const Icon(LucideIcons.pencil, size: 15),
          label: const Text('Koordinatı elle gir'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _en,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                // ⚠️⚠️ TURU 85c — YAZDIKCA EBEVEYNE TASINIR (denetim bulgusu).
                //    Eskiden metin alanlariyla ekran arasindaki TEK kopru
                //    "Uygula" dugmesiydi. Kullanici koordinati yazip DOGRUDAN
                //    "Kaydet"e basinca girdigi konum **SESSIZCE ATILIYORDU**
                //    (Flutter'da odak kaybi `onSubmitted` TETIKLEMEZ) — hicbir
                //    uyari da cikmiyordu. "Uygula" DURUYOR (dogrulama +
                //    geri bildirim icin) ama artik ZORUNLU DEGIL.
                // ⚠️ `didUpdateWidget` ayni degeri yeniden YAZMAZ, dongu olmaz.
                onChanged: (_) => _yazdikca(),
                decoration: const InputDecoration(
                  labelText: 'Enlem',
                  hintText: '40.802000',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _boy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                // ⚠️⚠️ TURU 85c — YAZDIKCA EBEVEYNE TASINIR (denetim bulgusu).
                //    Eskiden metin alanlariyla ekran arasindaki TEK kopru
                //    "Uygula" dugmesiydi. Kullanici koordinati yazip DOGRUDAN
                //    "Kaydet"e basinca girdigi konum **SESSIZCE ATILIYORDU**
                //    (Flutter'da odak kaybi `onSubmitted` TETIKLEMEZ) — hicbir
                //    uyari da cikmiyordu. "Uygula" DURUYOR (dogrulama +
                //    geri bildirim icin) ama artik ZORUNLU DEGIL.
                // ⚠️ `didUpdateWidget` ayni degeri yeniden YAZMAZ, dongu olmaz.
                onChanged: (_) => _yazdikca(),
                decoration: const InputDecoration(
                  labelText: 'Boylam',
                  hintText: '29.435000',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: _uygula, child: const Text('Uygula')),
          ],
        ),
        if (_hata != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _hata!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Haritadan koordinat bakıp yazabilirsin (örn. Google Haritalar’da '
            'işletmene uzun bas).',
            style: TextStyle(fontSize: 11.5, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
