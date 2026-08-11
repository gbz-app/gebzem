import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chats/anket.dart' show AnketTaslak, anketPaneliAc;
import '../medya/medya_kapisi.dart';
import '../medya/konum_servisi.dart';
import '../medya/medya_servisi.dart';
import '../medya/ses_notu_kaydedici.dart';
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — GONDERI OLUSTURUCU (foto / video / reels / yazi).
///
/// ⚠️⚠️ YUKLEME ILERLEMESI GORUNUR (kullanici emri): her dosya icin YUZDE cubugu,
///    toplam ilerleme ve IPTAL dugmesi. Bu projede "gonderdim sandim ama gitmemis"
///    tekrarlayan bir sikayet — yukleme SESSIZ olamaz.
///
/// ⚠️⚠️ EKRAN KAPANMASI YUKLEMEYI OLDURMEZ mi? OLDURUR — ve bu BILINCLI:
///    arka plan yuklemesi (WorkManager/BGTaskScheduler) ayri bir altyapi ister.
///    Bu yuzden yukleme SURERKEN `PopScope` ile cikis ONAY SORAR ve iptal edilirse
///    `CancelToken` ile ag istegi GERCEKTEN kesilir (yarim dosya R2'de kalirsa
///    sunucunun supurgesi 'beklemede' kaydi zaten temizler).
///
/// ⚠️ DONANIM KAPISI: kamera/galeri secici acilmadan `MedyaKapisi` sorulur —
///    arama/oda/yayin surerken kamera acmak iOS'ta paylasilan `videoCapturer`i
///    calar (turu 50 kok nedeni).
class GonderiOlustur extends ConsumerStatefulWidget {
  const GonderiOlustur({super.key, this.reels = false});

  /// `true` ise DIKEY kisa video (reels) modunda acilir.
  final bool reels;

  @override
  ConsumerState<GonderiOlustur> createState() => _GonderiOlusturState();
}

class _SecilenMedya {
  _SecilenMedya(this.dosya, this.video, {this.ses = false});
  final File dosya;
  final bool video;

  /// ⚠️ TURU 83 — SES kaydi. `video` ile BIRLIKTE true OLAMAZ.
  ///    Ayri bir bayrak secildi (enum yerine) cunku mevcut tum kod
  ///    `m.video` uzerinden dallaniyor; enum'a gecmek 14 dokunus yeri
  ///    demekti ve bu turda gereksiz risk.
  final bool ses;

  /// Yukleme icin medya turu — TEK KAYNAK.
  ///
  /// ⚠️ `kind` ve `mime` AYNI yerden turer: ikisi cagri yerinde ayri ayri
  ///    yazilsaydi biri guncellenip digeri unutulurdu (sunucu `kind` ile
  ///    `mime`in uyusmasini bekliyor — `sniff.go`).
  String get kind => ses
      ? 'audio'
      : video
      ? 'video'
      : 'image';
  /// ⚠️⚠️⚠️ SES MIME'I **`audio/mp4`** — `audio/m4a` DEGIL.
  ///
  ///    Ilk yazimda `audio/m4a` yazilmisti ve sunucu bunu REDDEDIYOR
  ///    (`sniff.go` beyaz listesi: `audio/mp4`, `audio/mpeg`). Yani gonderiye
  ///    ses ekleme **%100 OLU DOGACAKTI** — kullanici kaydi yapar, "Paylaş"a
  ///    basar ve "bu dosya türü desteklenmiyor" hatasi alirdi.
  ///    UCTAN UCA TESTI YAKALADI (`go build` + `flutter analyze` ikisi de
  ///    TEMIZ geciyordu — bu, projenin en sik hata sinifi).
  /// ⚠️ Sohbetteki ses notu ZATEN `audio/mp4` gonderiyor
  ///    (`chat_screen.dart`): kaydedici AAC-LC/m4a uretir ve o kabin
  ///    standart MIME'i `audio/mp4`tir.
  /// ⚠️ YAPMA: burayi `audio/m4a` ya da `audio/aac` yapma (ikincisi turu 74b'de
  ///    beyaz listeden CIKARILDI — ham ADTS `audio/mpeg` olarak taninir).
  String get mime => ses
      ? 'audio/mp4'
      : video
      ? 'video/mp4'
      : 'image/jpeg';

  /// 0.0-1.0. `null` = henuz baslamadi.
  double? ilerleme;
  String? mediaId;
  String? hata;
}

class _GonderiOlusturState extends ConsumerState<GonderiOlustur> {
  final _metin = TextEditingController();
  final List<_SecilenMedya> _medya = [];

  /// ⚠️ TURU 83 — gonderiye eklenen anket taslagi. `null` = anket YOK.
  ///    Sunucuya `gonderiOlustur(anket:)` ile GONDERININ KENDISIYLE
  ///    AYNI ISTEKTE gider (yarim kayit olmasin).
  AnketTaslak? _anket;
  bool _yorumKapali = false;

  /// ⚠️ TURU 81 — ILERI TARIHLI PAYLASIM. `null` = HEMEN yayinla.
  DateTime? _yayinAt;

  /// "12 Ağustos 19:30"
  String _zamanMetni(DateTime d) {
    const aylar = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final s = d.hour.toString().padLeft(2, '0');
    final dk = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${aylar[d.month - 1]} $s:$dk';
  }

  /// ⚠️ Tarih + saat AYRI iki adimda seciliyor (Material'in tek bir
  ///    "tarih-saat" secicisi yok). Kullanici ikisinden birini iptal ederse
  ///    zamanlama KURULMAZ — yarim bir deger yazmak "ne zaman yayinlanacak"
  ///    sorusunu belirsiz birakirdi.
  /// ⚠️ `flutter_localizations` turu 80'de eklendi, yani secici TURKCE acilir.
  Future<void> _zamanSec() async {
    final simdi = DateTime.now();
    final gun = await showDatePicker(
      context: context,
      initialDate: simdi.add(const Duration(hours: 1)),
      firstDate: simdi,
      // ⚠️ Sunucu tavani 1 YIL — burasi onunla AYNI olmali, yoksa kullanici
      //    secebildigi bir tarihte 400 yerdi.
      lastDate: simdi.add(const Duration(days: 365)),
      helpText: 'Yayın tarihi',
      cancelText: 'Vazgeç',
      confirmText: 'Devam',
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(simdi.add(const Duration(hours: 1))),
      helpText: 'Yayın saati',
      cancelText: 'Vazgeç',
      confirmText: 'Zamanla',
    );
    if (saat == null || !mounted) return;
    final secilen = DateTime(
      gun.year,
      gun.month,
      gun.day,
      saat.hour,
      saat.minute,
    );
    // ⚠️ GECMIS kontrolu ISTEMCIDE DE var: sunucu gecmisi sessizce "hemen"e
    //    cevirir, ama kullaniciya BURADA soylemek daha durust.
    if (!secilen.isAfter(DateTime.now())) {
      _uyar('Geçmiş bir zamana paylaşım yapılamaz');
      return;
    }
    setState(() => _yayinAt = secilen);
  }
  bool _yukleniyor = false;

  /// ⚠️⚠️ TURU 90 — GONDERI KONUMU (kullanici emri).
  ///
  /// `_konumAd` bos + koordinatlar 0 ise KONUM YOK demektir; sunucu da ayni
  /// sozlesmeyi kullanir (migration 044 serhi).
  /// ⚠️ Ad ISTEMCIDE uretilir (cihazin geocoder'i); sunucu DOGRULAMAZ.
  String _konumAd = '';
  double _konumEnlem = 0;
  double _konumBoylam = 0;

  /// ⚠️ TURU 90b — "KONUM EKLI Mi" **TEK OLCUT**.
  ///    Onceden dugme yalniz `_konumAd`a, kaldirma sheet'i ise koordinata da
  ///    bakiyordu: ad cozumlenemedigi (ag yok / adres bulunamadi) ama
  ///    koordinat KAYDEDILDIGI durumda dugme "konum yok" gorunumundeydi.
  bool get _konumVar =>
      _konumAd.isNotEmpty || _konumEnlem != 0 || _konumBoylam != 0;
  CancelToken? _iptal;

  /// ⚠️ KENDI ROUTE'UM. `Navigator.pop()` en usteki route'u kapatir, "beni" degil —
  ///    ustumde bir onay diyalogu aciksa yanlis seyi kapatirdi (turu 59b dersi).
  ModalRoute<Object?>? _rota;

  /// Paylasim TAMAMLANDI mi. `PopScope`un onay diyalogu bundan sonra anlamsizdir.
  bool _bitti = false;

  /// ⚠️ Sunucudaki sinirlarla AYNI olmali — istemcide kesmezsek kullanici 16 MB
  ///    videoyu yukler ve commit'te 422 yer (bosa giden veri + kotu deneyim).
  static const int _enFazlaGorsel = 10;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚠️ `ModalRoute.of` initState'te CAGRILAMAZ (bagimliliklar henuz kurulmadi).
    _rota ??= ModalRoute.of(context);
  }

  @override
  void dispose() {
    _metin.dispose();
    super.dispose();
  }

  bool get _reelsMi => widget.reels;

  /// ⚠️⚠️ TURU 76 — KARMA GALERI (kullanici emri: "birden fazla gorsel VE video
  ///    paylasabilelim, galeri seklinde sol sag").
  ///
  /// `foto` artik "GALERI (1-10 karma medya)" demek; her medyanin GERCEK turu
  /// `media_assets.kind`ten okunup istemciye `media_kinds` dizisiyle DONUYOR.
  /// ⚠️ YENI BIR `tur` DEGERI EKLENMEDI — `posts.tur` CHECK'ini DROP/ADD etmek
  ///    015'te yasanan migration tuzagini acar (bkz. 025 serhi).
  /// ⚠️ `video`/`reels` YALNIZ TEK medyada: reels sekmesi ve dikey oynatici
  ///    tek video varsayiyor; sunucu da `tur != 'foto' && len > 1` reddediyor.
  String get _tur {
    if (_medya.isEmpty) return 'yazi';
    if (_reelsMi) return 'reels';
    if (_medya.length == 1 && _medya.first.video) return 'video';
    return 'foto';
  }

  /// ⚠️⚠️ TURU 83 — GONDERIYE SES EKLE (kullanici emri).
  ///
  /// Kaydedici SOHBETTEKI BILESENIN AYNISI (`SesNotuKaydedici`) — ikinci bir
  /// kayit yolu yazmak izinleri, `SesNotuKontrol` sahiplik defterini (turu 73)
  /// ve genlik olcumunu iki yerde yasatmak demekti.
  ///
  /// ⚠️ SES **TEK BASINA** paylasilir: fotograf/video ile karistirilamaz.
  ///    Sebep YAPISAL — kart ses dalinda galeri seridi CIZMEZ (`sesliMi`
  ///    dali `_medya()`yi ATLAR), yani karma bir gonderide fotograflar
  ///    GORUNMEZ olurdu. Kullaniciya bu ACIKCA soyleniyor.
  Future<void> _sesEkle() async {
    if (_medya.isNotEmpty) {
      _uyar('Ses kaydı tek başına paylaşılır — önce diğer medyayı kaldır');
      return;
    }
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda kayıt yapılamaz');
      return;
    }
    final dosya = await showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (c) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(c).viewInsets.bottom,
          left: 12,
          right: 12,
          top: 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ses kaydı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mikrofona bir kez dokun — bitince gönder.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            SesNotuKaydedici(
              // ⚠️ `sureMs`/`dalga` gonderi hattinda TASINMIYOR (mesajdaki
              //    gibi ayri sutunlar yok). Dosya yeter; balon sureyi
              //    oynaticidan ogrenir.
              onKayit: (f, _, _) => Navigator.pop(c, f),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
    if (!mounted || dosya == null) return;
    setState(() => _medya.add(_SecilenMedya(dosya, false, ses: true)));
  }

  /// ⚠️⚠️ TURU 83 — GONDERIYE ANKET EKLE (kullanici emri).
  ///
  /// Panel SOHBETTEKI ILE AYNI (`anketPaneliAc`): soru + 2..12 secenek +
  /// tek/cok secim. Dogrulama sunucuda `chat.GonderiAnketiYaz` icinde ve
  /// SOHBETLE AYNI sabitlerle yapilir.
  /// ⚠️⚠️ TURU 90 — KONUM EKLE / KALDIR.
  ///
  /// ⚠️ `KonumServisi` TEK KAYNAK (turu 81, sohbette konum paylasimi icin
  ///    yazildi): izin isteme, servis kapali kontrolu ve hata mesajlari
  ///    ORADA. Ikinci bir konum yolu yazmak o kapilari ATLARDI.
  /// ⚠️ Yer adi cozumlenemezse (ag yok / geocoder bulamadi) koordinat YINE DE
  ///    kaydedilir ve "Konum eklendi" denir — ozellik yarim kalmaz.
  Future<void> _konumEkle() async {
    // Zaten eklenmisse: kaldirma secenegi sun.
    if (_konumVar) {
      final kaldir = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.mapPin, size: 20),
                title: Text(_konumAd.isEmpty ? 'Konum ekli' : _konumAd),
                subtitle: const Text('Gönderinde gösterilecek'),
              ),
              ListTile(
                leading: const Icon(LucideIcons.x, size: 20),
                title: const Text('Konumu kaldır'),
                onTap: () => Navigator.of(c).pop(true),
              ),
            ],
          ),
        ),
      );
      if (kaldir == true && mounted) {
        setState(() {
          _konumAd = '';
          _konumEnlem = 0;
          _konumBoylam = 0;
        });
      }
      return;
    }

    final k = await KonumServisi.konumAl();
    if (!mounted) return;
    if (k == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum alınamadı — izin verildi mi?')),
      );
      return;
    }
    final ad = await KonumServisi.yerAdi(k.enlem, k.boylam);
    if (!mounted) return;
    setState(() {
      _konumEnlem = k.enlem;
      _konumBoylam = k.boylam;
      _konumAd = ad;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ad.isEmpty ? 'Konum eklendi' : 'Konum: $ad')),
    );
  }

  Future<void> _anketEkle() async {
    if (_anket != null) {
      // Zaten anket varsa DEGISTIR (ikinci anket olamaz — `polls.post_id`
      // uzerinde kismi UNIQUE index var, migration 042).
      final sil = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Anket'),
          content: const Text('Bu gönderide zaten bir anket var.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text(
                'Anketi kaldır',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
      if (sil == true && mounted) setState(() => _anket = null);
      return;
    }
    final t = await anketPaneliAc(context);
    if (!mounted || t == null) return;
    setState(() => _anket = t);
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    final kalan = _enFazlaGorsel - _medya.length;
    if (kalan <= 0) {
      // ⚠️ TURU 81 — MEVCUT HATA: sayi ENTERPOLASYONU KAYIPTI, mesaj
      //    "En fazla  görsel eklenebilir" olarak cikiyordu (cift bosluk).
      _uyar('En fazla $_enFazlaGorsel görsel eklenebilir');
      return;
    }
    // ⚠️ TEK KAYNAK: limit<2 tuzagi + take(kalan) kirpmasi MedyaSecici'de.
    final secim = await MedyaSecici.coklu(kalan);
    if (secim.isEmpty || !mounted) return;
    // ⚠️ TURU 76: "video ile fotograf ayni gonderide olamaz" KAPISI KALDIRILDI —
    //    karma galeri artik hem sunucuda hem kartta destekleniyor.
    setState(() {
      for (final x in secim) {
        if (_medya.length >= _enFazlaGorsel) break;
        _medya.add(_SecilenMedya(File(x.path), false));
      }
    });
  }

  /// Reels 90 sn, normal video 5 dk.
  Duration get _sureTavani =>
      _reelsMi ? const Duration(seconds: 90) : const Duration(minutes: 5);

  // ⚠️ TURU 78: sure olcumu MedyaKapisi.videoSuresi()e TASINDI (tek kaynak).

  Future<void> _videoSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda medya seçilemez');
      return;
    }
    // ⚠️ TURU 76: karma galeride video da 10'luk tavana dahildir.
    if (!_reelsMi && _medya.length >= _enFazlaGorsel) {
      _uyar('En fazla $_enFazlaGorsel medya ekleyebilirsin');
      return;
    }
    // ⚠️ TEK KAYNAK: boyut + SURE kapisi MedyaSecici.video icinde.
    //    Ayni zincir burada ve ilan/etkinlik ekranlarinda iki kopya olsaydi
    //    kacinilmaz olarak drift ederdi (bu projede ALTI kez yasandi).
    final dosya = await MedyaSecici.video(
      sureTavani: _sureTavani,
      uyar: _uyar,
      ref: ref,
    );
    if (dosya == null || !mounted) return;
    setState(() {
      // ⚠️ TURU 76 — REELS'te TEK video (dikey oynatici tek kaynak varsayiyor),
      //    normal gonderide video GALERIYE EKLENIR (karma medya).
      if (_reelsMi) {
        _medya
          ..clear()
          ..add(_SecilenMedya(dosya, true));
      } else {
        _medya.add(_SecilenMedya(dosya, true));
      }
    });
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _paylas() async {
    final metin = _metin.text.trim();
    // ⚠️ TURU 83 — ANKET de tek basina icerik sayilir: anketin SORUSU zaten
    //    metin tasir ve kullaniciyi ayrica yazi yazmaya zorlamak anlamsiz.
    //    Sunucu tarafinda AYNI kural (`social.Create`: `metin bos && anket nil`).
    if (_medya.isEmpty && metin.isEmpty && _anket == null) {
      _uyar('Bir şeyler yaz, medya seç ya da anket ekle');
      return;
    }
    if (_reelsMi && _medya.isEmpty) {
      _uyar('Reels için video seçmelisin');
      return;
    }
    setState(() => _yukleniyor = true);
    _iptal = CancelToken();
    try {
      final servis = ref.read(medyaServisiProvider);
      final idler = <String>[];
      for (final m in _medya) {
        // ⚠️ Zaten yuklenmisse TEKRAR YUKLEME — "tekrar dene" akisinda ayni
        //    dosyayi ikinci kez yuklemek hem veri hem kota israfi.
        if (m.mediaId != null) {
          idler.add(m.mediaId!);
          continue;
        }
        setState(() {
          m.ilerleme = 0;
          m.hata = null;
        });
        File gonderilecek = m.dosya;
        // ⚠️ EXIF temizligi YALNIZ FOTOGRAFA uygulanir. Ses ve video dosyasi
        //    `gorseliHazirla`ya girseydi null doner ve paylasim "Fotoğraf
        //    hazırlanamadı" diye SESSIZCE olurdu.
        if (!m.video && !m.ses) {
          // ⚠️ EXIF (KONUM) TEMIZLIGI burada olur ve ZORUNLUDUR — sunucu GPS
          //    bulursa 422 doner. Sikistirma basarisiz olursa HAM dosya
          //    GONDERILMEZ (konum sizabilir).
          final hazir = await MedyaServisi.gorseliHazirla(m.dosya);
          if (hazir == null) {
            throw Exception('Fotoğraf hazırlanamadı');
          }
          gonderilecek = hazir;
        }
        final id = await servis.yukle(
          dosya: gonderilecek,
          // ⚠️ TEK KAYNAK: `_SecilenMedya.kind`/`.mime` (ses dali dahil).
          kind: m.kind,
          mime: m.mime,
          fileName: m.dosya.uri.pathSegments.last,
          iptal: _iptal,
          ilerleme: (p) {
            if (mounted) setState(() => m.ilerleme = p);
          },
        );
        if (!mounted) return;
        setState(() {
          m.mediaId = id;
          m.ilerleme = 1;
        });
        idler.add(id);
      }

      final postId = await ref
          .read(sosyalServisiProvider)
          .gonderiOlustur(
            tur: _tur,
            metin: metin,
            mediaIds: idler,
            yorumKapali: _yorumKapali,
            yayinAt: _yayinAt,
            anket: _anket,
            konum: _konumAd,
            enlem: _konumEnlem,
            boylam: _konumBoylam,
          );
      if (!mounted) return;
      // ⚠️⚠️ TURU 75b (DENETIM BULGUSU — SEVK ENGELIYDI):
      //    `Navigator.pop()` EN USTTEKI route'u kapatir, "beni" DEGIL.
      //    Bu ekranda `PopScope` yukleme surerken bir ONAY DIYALOGU aciyor;
      //    kullanici yukleme biterken geri tusuna basmissa o diyalog ACIK olur ve
      //    `pop(postId)` DIYALOGU kapatir — bu ekran EKRANDA KALIR, cagiran hicbir
      //    sonuc almaz, kullanici "paylasilmadi" sanip TEKRAR basar -> **CIFT GONDERI**.
      //    Ayni sinif hata turu 59b'de aramanin CANLI ekranini olduruyordu.
      // ⚠️ COZUM: kendi route'unu ADRESLE. `_bitti` bayragi PopScope diyalogunu da
      //    anlamsizlastirir (artik yukleme yok).
      _bitti = true;
      final nav = Navigator.of(context);
      nav.popUntil(
        (rota) => rota == _rota,
      ); // ustumdeki her seyi (diyalog) dusur
      nav.pop(postId); // simdi GERCEKTEN en ustteki benim
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      if (CancelToken.isCancel(e)) {
        _uyar('Yükleme iptal edildi');
      } else {
        _uyar(_hataMetni(e));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _yukleniyor = false);
      _uyar(_hataMetni(e));
    }
  }

  String _hataMetni(Object e) {
    if (e is DioException) {
      final d = e.response?.data;
      if (d is Map && d['error'] is String) return d['error'] as String;
      if (e.response?.statusCode == 413) return 'Dosya çok büyük';
      if (e.response?.statusCode == 422) {
        return 'Dosya doğrulanamadı (bozuk ya da desteklenmiyor)';
      }
    }
    final s = e.toString();
    return s.contains('Exception: ')
        ? s.split('Exception: ').last
        : 'Paylaşılamadı';
  }

  double get _toplamIlerleme {
    if (_medya.isEmpty) return 0;
    final t = _medya.fold<double>(0, (a, m) => a + (m.ilerleme ?? 0));
    return t / _medya.length;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // ⚠️ Yukleme surerken kazara geri tusu = yarim kalan gonderi.
      // ⚠️ `_bitti` sarti ZORUNLU: paylasim tamamlandiktan sonra kapi ACIK olmali,
      //    yoksa kendi `nav.pop(postId)` cagrimiz da bu kapiya takilirdi.
      canPop: !_yukleniyor || _bitti,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_yukleniyor || _bitti) return;
        // ⚠️ Navigator await'ten ONCE yakalanir: `showDialog` bir async bosluk
        //    acar ve sonrasinda `context` kullanmak (State dispose olduysa)
        //    patlar. Bu projede TAM AYNI sinif hata turu 67'de aramayi
        //    olduruyordu ("Cannot use ref after the widget was disposed").
        final nav = Navigator.of(context);
        final cik = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Yükleme sürüyor'),
            content: const Text(
              'Çıkarsan gönderi paylaşılmayacak. Çıkılsın mı?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Devam et'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Çık', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (cik == true && mounted) {
          _iptal?.cancel('kullanici cikti');
          nav.pop();
        }
      },
      child: Scaffold(
        // ⚠️⚠️ TURU 82b — BASLIK CUBUGU YENIDEN DUZENLENDI (kullanici emri:
        //    *"geri tusu arrow-left olacak; 'Yeni gönderi' 2px daha kucuk ve
        //    soldaki ikona biraz daha yakin; daha modern, daha profesyonel"*).
        //
        //    · Geri ikonu ACIKCA `arrow-left` (varsayilan platform ikonu
        //      Android'de `arrow_back`, iOS'ta `chevron` cizerdi — iki
        //      platformda FARKLI gorunuyordu).
        //    · `titleSpacing: 4` -> baslik ikona yaklasti (varsayilan 16).
        //    · Baslik 20 -> **18** (Material varsayilani 20'dir; "2px kucuk").
        //    · "Paylaş" duz `TextButton`dan **dolu haplı** dugmeye cevrildi:
        //      birincil eylemin metin gibi gorunmesi profesyonel durmuyordu.
        appBar: AppBar(
          // ⚠️⚠️⚠️ TURU 83 — **SEVK ENGELI DUZELTMESI** (denetim bulgusu).
          //
          //    Ilk yazimda `onPressed: _yukleniyor ? null : ... pop()` idi ve
          //    bu, yukleme sirasindaki TUM cikis yollarini birden kapatiyordu:
          //      · geri dugmesi OLU (`null`),
          //      · "İptal" dugmesi `AbsorbPointer(absorbing: _yukleniyor)`in
          //        ICINDE oldugu icin dokunus ALMIYOR,
          //      · `PopScope(canPop: !_yukleniyor || _bitti)` iOS kenar-cekme
          //        jestini de BLOKE ediyor.
          //    Sonuc: 100 MB'lik bir video yuklenirken kullanici ekranda
          //    KILITLI kaliyordu — uygulamayi oldurmekten baska cikis yoktu.
          //
          // ⚠️ `maybePop` SECILDI (`pop` DEGIL): `PopScope`a ugrar, yani
          //    yukleme surerken ONAY DIYALOGU acilir, yukleme yokken normal
          //    kapanir. Ciplak `pop()` ayrica bu dosyanin KENDI serhinin
          //    yasakladigi desendir (yanlis route'u kapatabilir).
          // ⚠️ YAPMA: buraya `_yukleniyor ? null :` kapisini geri koyma.
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 4,
          title: Text(
            _reelsMi ? 'Yeni Reels' : 'Yeni gönderi',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: FilledButton(
                onPressed: _yukleniyor ? null : _paylas,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Paylaş'),
              ),
            ),
          ],
        ),
        // ⚠️⚠️ `AbsorbPointer` YALNIZ FORMU sarar; ilerleme + IPTAL blogu
        //    ONUN DISINDA (bkz. `_ilerlemeBlogu` serhi — SEVK ENGELIYDI).
        body: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: _yukleniyor,
                child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              TextField(
                controller: _metin,
                minLines: 3,
                maxLines: 10,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText: _reelsMi
                      ? 'Reels açıklaması...'
                      : 'Neler oluyor? Bir şeyler yaz...',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_medya.isNotEmpty) _onizleme(),
              const SizedBox(height: 12),
              // ⚠️⚠️ TURU 82b — EKLER SATIRI (kullanici emri: *"yeni gonderide
              //    anket, ses, harita vb seyler olsun"*).
              //
              //    Iki `OutlinedButton.icon` (Fotograf | Video) yerine TEK
              //    kaydirilabilir serit: yeni ek turu geldiginde satir
              //    TASMAZ. Etiketler ikonun ALTINDA -> her ek AYNI genislikte
              //    ve serit duzenli gorunuyor ("daha profesyonel" istegi).
              // ⚠️ KAYDIRILABILIR olmasi ZORUNLU: bes ek + 360dp ekran +
              //    yazi olcegi 1.3'te sabit bir `Row` RenderFlex seridi
              //    cikarirdi (turu 82'de olculen sinif).
              _eklerSeridi(),
              // ⚠️ TURU 83 — SECILEN ANKET GORUNUR OLMALI. Gorunmeseydi
              //    kullanici anketi ekledigini UNUTUR ya da eklendigine emin
              //    olamazdi ("ekledim mi?" belirsizligi bu projede defalarca
              //    "iki kez gonderdim" hatasina yol acti).
              if (_anket != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.chartNoAxesColumn, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _anket!.soru,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_anket!.secenekler.length} seçenek'
                                '${_anket!.coklu ? ' · çoklu seçim' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Anketi kaldır',
                          icon: const Icon(LucideIcons.x, size: 18),
                          onPressed: _yukleniyor
                              ? null
                              : () => setState(() => _anket = null),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _yorumKapali,
                onChanged: _yukleniyor
                    ? null
                    : (v) => setState(() => _yorumKapali = v),
                title: const Text('Yorumları kapat'),
                secondary: const Icon(LucideIcons.messageCircleOff),
              ),
              // ⚠️⚠️ TURU 81 — ILERI TARIHLI PAYLASIM (kullanici emri).
              //    Zamanlanan gonderi yayin anina kadar HICBIR yuzeyde
              //    gorunmez; YALNIZ yazarin kendi profilinde (etiketli) durur.
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(LucideIcons.clock),
                title: Text(
                  _yayinAt == null ? 'Hemen paylaş' : 'Zamanlandı',
                ),
                subtitle: Text(
                  _yayinAt == null
                      ? 'İstersen ileri bir tarihe zamanlayabilirsin'
                      : _zamanMetni(_yayinAt!),
                ),
                trailing: _yayinAt == null
                    ? TextButton(
                        onPressed: _yukleniyor ? null : _zamanSec,
                        child: const Text('Zamanla'),
                      )
                    : IconButton(
                        tooltip: 'Zamanlamayı kaldır',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: _yukleniyor
                            ? null
                            : () => setState(() => _yayinAt = null),
                      ),
              ),
                    // ⚠️ ILERLEME + IPTAL BLOGU BURADAN CIKARILDI —
                    //    `AbsorbPointer` icindeydi ve "İptal" dugmesi dokunus
                    //    ALMIYORDU (bkz. `_ilerlemeBlogu` serhi).
                  ],
                ),
              ),
            ),
            if (_yukleniyor) _ilerlemeBlogu(),
          ],
        ),
      ),
    );
  }

  /// Yukleme ilerlemesi + **IPTAL** dugmesi.
  ///
  /// ⚠️⚠️⚠️ TURU 83 — BU BLOK `AbsorbPointer`IN **DISINDA** cizilmek ZORUNDA.
  ///
  ///    Onceden `ListView`in son cocuguydu ve `AbsorbPointer(absorbing:
  ///    _yukleniyor)` govdeyi sardigi icin **tam da gorundugu anda** (yani
  ///    `_yukleniyor == true` iken) dokunus alamiyordu: dugme EKRANDA
  ///    GORUNUYOR ama BASILAMIYORDU. Geri dugmesi de o sirada `null` idi ve
  ///    `PopScope` kenar-cekmeyi blokluyordu -> 100 MB video yuklenirken
  ///    kullanicinin uygulamayi OLDURMEKTEN baska cikisi yoktu.
  ///
  /// ⚠️ YAPMA: bu blogu tekrar `AbsorbPointer`in icine tasima.
  Widget _ilerlemeBlogu() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(value: _toplamIlerleme),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _toplamIlerleme >= 0.98
                    ? 'Sunucu doğruluyor...'
                    : 'Yükleniyor %${(_toplamIlerleme * 100).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => _iptal?.cancel('kullanici iptal'),
              child: const Text('İptal'),
            ),
          ],
        ),
      ],
    ),
  );

  /// ⚠️⚠️ TURU 82b — YENI GONDERI EKLER SERIDI.
  ///
  /// Kullanici: *"yeni gonderide anket, ses, harita vb seyler olsun"*.
  ///
  /// ⚠️⚠️⚠️ **DURUST SINIR — UCU DE BUGUN YALNIZCA SOHBETTE CALISIYOR.**
  ///
  ///    Ses · anket · konum **SOHBET hattina** baglidir:
  ///      · anket  -> `polls` (migration 040), `messages.type='poll'`
  ///      · konum  -> `messages.type='location'`
  ///      · ses    -> `messages.type='audio'` + `SesBalonu` cizimi
  ///
  ///    **GONDERI hatti bunlarin HICBIRINI cizemez.** `posts` yalnizca
  ///    `metin` + `media_ids` tasiyor ve `GonderiKarti._medyaKutusu` bir
  ///    medyayi YA `MedyaGorsel` YA `MedyaVideo` olarak ciziyor — ses icin
  ///    DAL YOK. Ses dosyasini `media_ids`e koymak DERLENIR ve YUKLENIR ama
  ///    kartta **HICBIR SEY** gorunmez; kullanici sesini paylastigini sanip
  ///    kaybeder.
  ///
  /// ⚠️ **YAPMA: bu ucunu "calisiyormus gibi" baglama.** Bu projede
  ///    "sutun/uc var ama kullanan yol yok" (ve tersi) hatasi **DOKUZ KEZ**
  ///    yasandi. Dugmeler ozelligin GELECEGINI gosteriyor, VARLIGINI degil;
  ///    basildiginda DURUST bir bilgi mesaji cikiyor.
  /// ⚠️ Gercekten baglamak icin gereken (AYRI IS): `posts` semasina ek alan
  ///    (ya da yeni `post_ekleri` tablosu) · gonderi sorgularina sutun (YEDI
  ///    sorgu — `medyaTurleri` sabiti gibi TEK KAYNAKTAN) · `GonderiKarti`e
  ///    cizim dali · `sutun_test.go` guncellemesi · uctan uca kontrol.
  Widget _eklerSeridi() {
    Widget ek(IconData ikon, String etiket, VoidCallback? onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(ikon, size: 21),
              const SizedBox(height: 6),
              Text(
                etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );

    // ⚠️ TURU 90b — `yakinda()` yardimcisi SILINDI: turu 90 konumu GERCEKTEN
    //    bagladi ve bu yardimciyi cagiran son yol da kalkti. Dart olu bir
    //    yerel fonksiyonu UYARI olarak bildirir; Go'da ayni sinif SESSIZ
    //    gecerdi (kullanilmayan FONKSIYON hata degildir) — bu yuzden olu
    //    kodu bulundugu ANDA silmek gerekiyor.

    return SizedBox(
      // ⚠️ TURU 90b — 74 -> 80 (olculdu). Icerik `10+21+6+11*1.252*olcek`;
      //    yazi olcegi 2.0'da 74.5dp gerekiyordu ve serit 0.5dp tasiyordu.
      //    (`Icon.applyTextScaling` varsayilan `false` — ikon olceklenmez.)
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (!_reelsMi)
            ek(LucideIcons.image, 'Fotoğraf', _yukleniyor ? null : _gorselSec),
          ek(
            LucideIcons.video,
            _reelsMi ? 'Video seç' : 'Video',
            _yukleniyor ? null : _videoSec,
          ),
          if (!_reelsMi) ...[
            ek(LucideIcons.mic, 'Ses', _yukleniyor ? null : _sesEkle),
            ek(LucideIcons.chartNoAxesColumn, 'Anket',
                _yukleniyor ? null : _anketEkle),
            // ⚠️⚠️ TURU 90 — KONUM ARTIK GERCEK (kullanici emri: 'normal
            //    paylasimda konum paylasamiyoruz, bunu eklememissin').
            //    Migration 044 `posts`a konum_ad/enlem/boylam ekledi.
            // ⚠️⚠️ TURU 90b — DURUM **IKONDAN** verilir, metne "✓" EKLENMEZ.
            //    Onceki hal (`'Konum ✓'`) uc kusur tasiyordu:
            //     (a) `✓` Lucide DEGIL — arayuzde yalniz Lucide 2B ikon kurali,
            //     (b) yazi olcegi 2.0'da etiket 96dp'ye cikip 74dp kutuda
            //         ellipsis'e giriyor ve KIRPILAN ILK KARAKTER "✓" oluyordu
            //         -> kullanici "Konum…" gorup konumun EKLI OLUP OLMADIGINI
            //         ANLAYAMIYORDU,
            //     (c) olcut YALNIZ `_konumAd`a bakiyordu; ad cozumlenemedigi
            //         halde koordinat KAYDEDILEN durumda dugme "Konum" diyordu
            //         (kaldirma sheet'i ise koordinata da bakiyor = IKI OLCUT).
            ek(
              _konumVar ? LucideIcons.mapPinCheck : LucideIcons.mapPin,
              'Konum',
              _yukleniyor ? null : _konumEkle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _onizleme() {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _medya.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = _medya[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                // ⚠️⚠️ TURU 83 — SES DALI **ZORUNLU**. Olmasaydi bir m4a
                //    dosyasi `Image.file`a gider ve onizlemede KIRIK GORSEL
                //    cizilirdi — turu 78b'de ilan/etkinlik seritlerinde tam
                //    bu olmus, kullanici videosunu "bozuk" sanip SILMISTI.
                child: (m.video || m.ses)
                    ? Container(
                        width: 100,
                        height: 140,
                        color: const Color(0xFF1A1A24),
                        alignment: Alignment.center,
                        child: Icon(
                          m.ses ? LucideIcons.mic : LucideIcons.video,
                          color: Colors.white70,
                          size: 30,
                        ),
                      )
                    : Image.file(
                        m.dosya,
                        width: 100,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
              ),
              // Yukleme yuzdesi — DOSYA BASINA (kullanici hangi dosyanin
              // takildigini gorebilmeli).
              if (m.ilerleme != null && m.ilerleme! < 1)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ColoredBox(
                      color: const Color(0x99000000),
                      child: Center(
                        child: Text(
                          '%${(m.ilerleme! * 100).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (m.mediaId != null)
                const Positioned(
                  right: 4,
                  bottom: 4,
                  child: Icon(
                    LucideIcons.circleCheck,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
                ),
              if (!_yukleniyor)
                Positioned(
                  right: 2,
                  top: 2,
                  child: GestureDetector(
                    onTap: () => setState(() => _medya.removeAt(i)),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xAA000000),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          LucideIcons.x,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
