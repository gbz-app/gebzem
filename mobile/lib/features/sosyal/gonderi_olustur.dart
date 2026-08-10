import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
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
  _SecilenMedya(this.dosya, this.video);
  final File dosya;
  final bool video;

  /// 0.0-1.0. `null` = henuz baslamadi.
  double? ilerleme;
  String? mediaId;
  String? hata;
}

class _GonderiOlusturState extends ConsumerState<GonderiOlustur> {
  final _metin = TextEditingController();
  final List<_SecilenMedya> _medya = [];
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
    if (_medya.isEmpty && metin.isEmpty) {
      _uyar('Bir şeyler yaz ya da fotoğraf/video seç');
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
        if (!m.video) {
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
          kind: m.video ? 'video' : 'image',
          mime: m.video ? 'video/mp4' : 'image/jpeg',
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
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            tooltip: 'Geri',
            onPressed: _yukleniyor ? null : () => Navigator.of(context).pop(),
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
        body: AbsorbPointer(
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
              if (_yukleniyor) ...[
                const SizedBox(height: 16),
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
            ],
          ),
        ),
      ),
    );
  }

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

    void yakinda(String ad) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$ad gönderilerde yakında — şimdilik sohbette')),
      );
    }

    return SizedBox(
      height: 74,
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
            ek(LucideIcons.mic, 'Ses', _yukleniyor ? null : () => yakinda('Ses')),
            ek(
              LucideIcons.chartNoAxesColumn,
              'Anket',
              _yukleniyor ? null : () => yakinda('Anket'),
            ),
            ek(
              LucideIcons.mapPin,
              'Konum',
              _yukleniyor ? null : () => yakinda('Konum'),
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
                child: m.video
                    ? Container(
                        width: 100,
                        height: 140,
                        color: const Color(0xFF1A1A24),
                        alignment: Alignment.center,
                        child: const Icon(
                          LucideIcons.video,
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
