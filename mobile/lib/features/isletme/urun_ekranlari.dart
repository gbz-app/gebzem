import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'urun_servisi.dart';

/// ⚠️⚠️ TURU 77 — ISLETME KATALOGU / MENUSU.
///
/// Kullanici emri: "isletmeler urunlerini yukleyebilecek ya da ChatGPT
/// yardimiyla AI gorsel, AI menu, AI ile tek tek fotograftan problemleri ...".
///
/// ⚠️ AI DUGMELERI YALNIZ SUNUCUDA ACIKSA CIZILIR (`aiDurumProvider`).
///    Kapaliyken cizilseydi kullanici basar ve 503 alirdi.
class UrunKatalogEkrani extends ConsumerStatefulWidget {
  const UrunKatalogEkrani({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
    this.benimMi = false,
  });

  final String isletmeId;
  final String isletmeAd;
  final bool benimMi;

  @override
  ConsumerState<UrunKatalogEkrani> createState() => _UrunKatalogEkraniState();
}

class _UrunKatalogEkraniState extends ConsumerState<UrunKatalogEkrani> {
  List<Urun>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(urunServisiProvider).liste(widget.isletmeId);
      if (mounted) {
        setState(() {
          _liste = l;
          _hata = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _hata = 'Ürünler alınamadı');
    }
  }

  /// Bolume gore grupla (menu gorunumu).
  Map<String, List<Urun>> get _bolumler {
    final m = <String, List<Urun>>{};
    for (final u in _liste ?? const <Urun>[]) {
      m.putIfAbsent(u.bolum.isEmpty ? 'Diğer' : u.bolum, () => []).add(u);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isletmeAd.isEmpty ? 'Ürünler' : widget.isletmeAd),
        actions: [
          // ⚠️ AI MENU dugmesi: YALNIZ sahibine ve YALNIZ AI aciksa.
          if (widget.benimMi && (ai?.acik ?? false))
            IconButton(
              // ⚠️ TURU 78: artik IKI yol var (fotograf + yazili tarif), bu
              //    yuzden ipucu da genellestirildi. Eski metin kullaniciyi
              //    "yalnizca fotograf" sanisina dusururdu.
              tooltip: 'Yapay zekâ ile menü',
              icon: const Icon(LucideIcons.sparkles),
              onPressed: _aiMenu,
            ),
        ],
      ),
      floatingActionButton: widget.benimMi
          ? FloatingActionButton.extended(
              heroTag: 'fabUrunEkle',
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const UrunDuzenleEkrani()),
                );
                if (ok == true) _yukle();
              },
              icon: const Icon(LucideIcons.plus),
              label: const Text('Ürün ekle'),
            )
          : null,
      body: _hata != null
          ? Center(
              child: Text(_hata!, style: const TextStyle(color: Colors.grey)),
            )
          : l == null
          ? const Center(child: CircularProgressIndicator())
          : l.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                  widget.benimMi
                      ? 'Henüz ürün eklemedin.\nSağ alttan ilk ürününü ekle.'
                      : 'Bu işletme henüz ürün eklememiş.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  for (final b in _bolumler.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        b.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    for (final u in b.value) _satir(u),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _satir(Urun u) => ListTile(
    leading: u.mediaIds.isEmpty
        ? null
        : SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: MedyaGorsel(
                mediaId: u.mediaIds.first,
                kucuk: true,
                fit: BoxFit.cover,
              ),
            ),
          ),
    title: Text(u.ad),
    subtitle: u.aciklama.isEmpty
        ? null
        : Text(u.aciklama, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(u.fiyatMetni, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (u.durum == 'tukendi')
          const Text(
            'Tükendi',
            style: TextStyle(fontSize: 11, color: Colors.orange),
          )
        else if (u.durum == 'kaldirildi')
          const Text(
            'Kaldırıldı',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    ),
    onTap: widget.benimMi
        ? () async {
            final ok = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => UrunDuzenleEkrani(urun: u)),
            );
            if (ok == true) _yukle();
          }
        : null,
  );

  /// ⚠️⚠️ AI MENU — **IKI YOL**: menu FOTOGRAFINDAN oku ya da YAZILI TARIFTEN
  ///    olustur.
  ///
  /// ⚠️⚠️ TURU 78 — YAZILI TARIF YOLU EKLENDI. Sunucu (`POST /ai/menu`)
  ///    `metin` alanini BASINDAN BERI kabul ediyordu, ama istemci YALNIZCA
  ///    fotograf gonderiyordu: yani "menuyu AI ile OLUSTUR" yetenegi sunucuda
  ///    VAR, uygulamada ULASILAMAZ durumdaydi. Bu, projede BES kez tekrarlayan
  ///    "sunucuda var, ekranda yok" sinifiydi.
  ///    Kullanici emri acikca "menulerini yapay zeka ile OLUSTURABILMELI" idi;
  ///    fotograftan OKUMAK farkli bir istir.
  ///    ⚠️ YAPMA: bu secim sheet'ini kaldirip yalniz fotografa donme.
  ///
  /// ⚠️ Sonuc DOGRUDAN KAYDEDILMEZ — kullaniciya ONERI listesi gosterilir, o
  ///    onaylar. Otomatik kaydetmek yanlis okunan/uydurulan bir fiyati
  ///    sessizce menuye yazardi.
  Future<void> _aiMenu() async {
    final yol = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Menü fotoğrafından oku'),
              subtitle: const Text('Basılı menünün fotoğrafını seç'),
              onTap: () => Navigator.pop(c, 'foto'),
            ),
            ListTile(
              leading: const Icon(LucideIcons.penLine),
              title: const Text('Anlatarak oluştur'),
              subtitle: const Text(
                'Örnek: Adana usulü kebapçı, 15 çeşit, ortalama 250 TL',
              ),
              onTap: () => Navigator.pop(c, 'metin'),
            ),
          ],
        ),
      ),
    );
    if (yol == null || !mounted) return;
    if (yol == 'metin') {
      await _aiMenuMetinden();
      return;
    }

    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;

    // ⚠️⚠️ TURU 78b — SERVISLER **AWAIT'LERDEN ONCE** yakalanir.
    //    Buradaki pencere projedeki EN GENIS pencere: AI cagrisi **60 saniyeye
    //    kadar** surebiliyor. Kullanici bekleme diyalogunu geri tusuyla kapatip
    //    bir kez daha geri basarsa ekran dispose olur; `ref.read` `StateError`
    //    firlatir, catch yutar ve KOTA ZATEN HARCANMIS oldugu halde kullanici
    //    HICBIR SONUC GORMEZ (kota rezervasyonu cagridan ONCE yapiliyor).
    //    ⚠️ YAPMA: bu satirlari await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);

    // ⚠️ Bekleme diyalogunun ACIK olup olmadigini izler — bkz. catch dalindaki
    //    "yanlis route pop" serhi.
    var diyalogAcik = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Menü okunuyor...')),
          ],
        ),
      ),
    );
    try {
      final hazir = await MedyaServisi.gorseliHazirla(File(x.path));
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await medyaSvc.yukle(
        dosya: hazir,
        kind: 'image',
        mime: 'image/jpeg',
      );
      final sonuc = await aiSvc.menu(mediaId: mediaId);
      if (!mounted) return;
      Navigator.of(context).pop(); // bekleme diyalogu
      diyalogAcik = false;
      // ⚠️ TURU 77b — KOTA SAYACI TAZELENIR. `aiDurumProvider` SUREC OMURLU ve
      //    hicbir yerde invalidate EDILMIYORDU: dugme etiketindeki "(20)" 20
      //    cagridan sonra bile "(20)" der, kullanici sonra 429 alirdi.
      ref.invalidate(aiDurumProvider);
      await _oneriGoster(sonuc);
    } catch (e) {
      if (!mounted) return;
      // ⚠️⚠️ TURU 77b — KOSULSUZ `pop()` YANLIS ROUTE'U KAPATIYORDU.
      //    Basari dali bekleme diyalogunu ZATEN pop edip `_oneriGoster`i
      //    AWAIT ediyor; oradan bir istisna kacarsa buradaki ikinci pop
      //    **KATALOG EKRANINI** kapatirdi (turu 75b/(3) "yanlis route" sinifi).
      //    ⚠️ YAPMA: bayragi kaldirip kosulsuz pop'a donme.
      if (diyalogAcik) {
        Navigator.of(context).pop();
        diyalogAcik = false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  /// ⚠️ TURU 78 — YAZILI TARIFTEN MENU OLUSTURMA.
  ///
  /// ⚠️ Model UYDURUR: fotograftan okumada "yanlis okuma" riski varken burada
  ///    "hic olmayan urun" riski var. Bu yuzden onay adimi DAHA DA onemli ve
  ///    diyalogda kullaniciya ACIKCA soyleniyor.
  /// ⚠️ FIYAT: kullanici ortalama fiyat yazabilir ama model 2026 Gebze
  ///    fiyatlarini BILMEZ. Onerilen fiyatlar TASLAKTIR — kullanici onay
  ///    ekraninda gorur ve isterse duzenler.
  Future<void> _aiMenuMetinden() async {
    final ctrl = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Menüyü anlatarak oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              // ⚠️ Sunucu 2000 karaktere kirpiyor; istemcide de AYNI tavan
              //    gosterilsin ki kullanici sessizce kesilen metin yazmasin.
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText:
                    'İşletmeni ve menünü anlat.\n'
                    'Örnek: Adana usulü kebapçı, 15 çeşit, '
                    'ortalama 250 TL, çorba ve tatlı da var.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Yapay zekâ bir TASLAK üretir. Ürünleri ve fiyatları '
              'onaylamadan menüne eklenmez.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    final tarif = ctrl.text.trim();
    ctrl.dispose();
    if (onay != true || tarif.isEmpty || !mounted) return;

    // ⚠️⚠️ TURU 78b — SERVIS **AWAIT'TEN ONCE** yakalanir (fotograf yolundaki
    //    ile AYNI gerekce: AI cagrisi 60 saniyeye kadar surer).
    final aiSvc = ref.read(aiServisiProvider);

    // ⚠️ Bekleme diyalogunun ACIK olup olmadigini izler (yanlis route pop
    //    korumasi — fotograf yolundaki ile AYNI desen).
    var diyalogAcik = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Menü oluşturuluyor...')),
          ],
        ),
      ),
    );
    try {
      final sonuc = await aiSvc.menu(metin: tarif);
      if (!mounted) return;
      Navigator.of(context).pop();
      diyalogAcik = false;
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir
      await _oneriGoster(sonuc);
    } catch (e) {
      if (!mounted) return;
      if (diyalogAcik) {
        Navigator.of(context).pop();
        diyalogAcik = false;
      }
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _oneriGoster(String ham) async {
    // ⚠️ Model bazen bozuk JSON dondurebilir — PATLAMAK YERINE ham metni
    //    gosteriyoruz. Kullanici en azindan sonucu gorur.
    List<Map<String, dynamic>> urunler = [];
    try {
      final j = jsonDecode(ham);
      if (j is Map && j['urunler'] is List) {
        urunler = (j['urunler'] as List)
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;
    if (urunler.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Menü okunamadı'),
          content: SingleChildScrollView(child: Text(ham)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    final secili = List<bool>.filled(urunler.length, true);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, yenile) => AlertDialog(
          title: Text('${urunler.length} ürün bulundu'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: urunler.length,
              itemBuilder: (_, i) {
                final u = urunler[i];
                // ⚠️⚠️ TURU 77b — TIP KORUMASI ZORUNLU (denetim bulgusu).
                //    JSON *ayristirmasi* korunmustu ama ALAN TIPLERI
                //    korunmamisti. Dil modelleri talimata ragmen sik sik
                //    `"fiyat_kurus": "1250"` (METIN) donduruyor; ciplak
                //    `as num?` cast'i `itemBuilder` ICINDE `TypeError` atar ve
                //    oneri diyalogu KIRMIZI HATA KUTUSUNA doner -> kullanici
                //    HICBIR urunu ekleyemez. (Ayni cast bir alt satirda
                //    `catch(_)` ile korunuyordu = ASIMETRI.)
                //    ⚠️ YAPMA: ciplak cast'e geri donme.
                final ham = u['fiyat_kurus'];
                final kurus = ham is num
                    ? ham.toInt()
                    : int.tryParse(ham?.toString() ?? '') ?? 0;
                return CheckboxListTile(
                  dense: true,
                  value: secili[i],
                  onChanged: (v) => yenile(() => secili[i] = v ?? false),
                  title: Text((u['ad'] ?? '').toString()),
                  subtitle: Text(
                    [
                      if ((u['bolum'] ?? '').toString().isNotEmpty)
                        u['bolum'].toString(),
                      if (kurus > 0) kurusMetni(kurus),
                    ].join(' · '),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Menüye ekle'),
            ),
          ],
        ),
      ),
    );
    if (onay != true || !mounted) return;

    var eklenen = 0;
    for (var i = 0; i < urunler.length; i++) {
      if (!secili[i]) continue;
      try {
        await ref.read(urunServisiProvider).ekle({
          'ad': (urunler[i]['ad'] ?? '').toString(),
          'aciklama': (urunler[i]['aciklama'] ?? '').toString(),
          'bolum': (urunler[i]['bolum'] ?? '').toString(),
          'fiyat_kurus': (urunler[i]['fiyat_kurus'] as num?)?.toInt() ?? 0,
          'media_ids': <String>[],
        });
        eklenen++;
      } catch (_) {}
    }
    if (!mounted) return;
    await _yukle();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$eklenen ürün eklendi')));
    }
  }
}

/// Urun ekle / duzenle (+ AI aciklama).
class UrunDuzenleEkrani extends ConsumerStatefulWidget {
  const UrunDuzenleEkrani({super.key, this.urun});
  final Urun? urun;

  @override
  ConsumerState<UrunDuzenleEkrani> createState() => _UrunDuzenleEkraniState();
}

class _UrunDuzenleEkraniState extends ConsumerState<UrunDuzenleEkrani> {
  late final _ad = TextEditingController(text: widget.urun?.ad ?? '');
  late final _aciklama = TextEditingController(
    text: widget.urun?.aciklama ?? '',
  );
  late final _bolum = TextEditingController(text: widget.urun?.bolum ?? '');
  late final _fiyat = TextEditingController(
    text: widget.urun == null || widget.urun!.fiyatKurus == 0
        ? ''
        : (widget.urun!.fiyatKurus / 100).toStringAsFixed(2),
  );

  File? _gorsel;
  bool _kaydediliyor = false;
  bool _aiCalisiyor = false;

  /// yayinda | tukendi  (⚠️ 'kaldirildi' arayuzden AYARLANMAZ — o "Kaldır"
  /// dugmesinin isi; iki yol ayni durumu yazsaydi kullanici hangisinin ne
  /// yaptigini bilemezdi.)
  late String _durum = widget.urun?.durum == 'tukendi' ? 'tukendi' : 'yayinda';

  @override
  void dispose() {
    _ad.dispose();
    _aciklama.dispose();
    _bolum.dispose();
    _fiyat.dispose();
    super.dispose();
  }

  Future<void> _gorselSec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    setState(() => _gorsel = File(x!.path));
  }

  /// ⚠️ AI ACIKLAMA — urunun fotografindan/adindan satis metni yazar.
  ///    Sonuc alana YAZILIR ama kullanici duzenleyebilir.
  Future<void> _aiAciklama() async {
    setState(() => _aiCalisiyor = true);
    try {
      var mediaId = '';
      if (_gorsel != null) {
        final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
        if (hazir != null) {
          mediaId = await ref
              .read(medyaServisiProvider)
              .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg');
        }
      }
      final metin = await ref
          .read(aiServisiProvider)
          .urunMetni(mediaId: mediaId, metin: _ad.text.trim());
      if (!mounted) return;
      setState(() => _aciklama.text = metin);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir (turu 77b)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _aiCalisiyor = false);
    }
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ürün adı gerekli')));
      return;
    }
    setState(() => _kaydediliyor = true);
    // ⚠️⚠️ TURU 78b — SERVISLER **TUM AWAIT'LERDEN ONCE** (ayrinti icin
    //    `ilan_ekranlari.dart` `_kaydet` serhi). Kullanici fotograf yuklenirken
    //    geri basarsa `ref.read` `StateError` firlatir, catch yutar ve urun
    //    OLUSMAZ; medya yetim kalir.
    //    ⚠️ YAPMA: bu iki satiri await'lerin ALTINA tasima.
    final medyaSvc = ref.read(medyaServisiProvider);
    final urunSvc = ref.read(urunServisiProvider);
    try {
      final tl = double.tryParse(_fiyat.text.trim().replaceAll(',', '.')) ?? 0;
      final govde = <String, dynamic>{
        'ad': _ad.text.trim(),
        'aciklama': _aciklama.text.trim(),
        'bolum': _bolum.text.trim(),
        'fiyat_kurus': (tl * 100).round(),
      };
      // ⚠️⚠️ TURU 77b — "TUKENDI" OLU OZELLIKTI (denetim bulgusu).
      //    Sunucu `durum` PATCH'ini beyaz listeyle KABUL EDIYORDU ve katalog
      //    "Tükendi" rozetini CIZIYORDU, ama istemci `durum` alanini
      //    **HICBIR YERDE GONDERMIYORDU** -> rozet sahada ASLA gorunmez,
      //    isletme urununu tukendi isaretleyemezdi. Bu, projede BES kez
      //    tekrarlayan "sutun eklendi, yazan yol yok" sinifinin yenisi.
      //    ⚠️ Yalniz DUZENLEMEDE gonderilir (yeni urun zaten 'yayinda' dogar).
      if (widget.urun != null) govde['durum'] = _durum;
      if (widget.urun == null) {
        final idler = <String>[];
        if (_gorsel != null) {
          final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
          if (hazir == null) throw Exception('Görsel hazırlanamadı');
          idler.add(
            await medyaSvc.yukle(
              dosya: hazir,
              kind: 'image',
              mime: 'image/jpeg',
            ),
          );
        }
        govde['media_ids'] = idler;
        await urunSvc.ekle(govde);
      } else {
        // ⚠️ DUZENLEMEDE MEDYA DEGISMEZ (gonderi duzenlemesiyle ayni kural):
        //    medya degisecekse urun silinip yenisi eklenir.
        await urunSvc.guncelle(widget.urun!.id, govde);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // ⚠️ KOK MESSENGER: kullanici kaydetme surerken ekrandan cikmis olabilir.
      if (mounted) setState(() => _kaydediliyor = false);
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ürün kaldırılsın mı?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kaldır', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    // ⚠️ TURU 77b — try/catch YOKTU: ag hatasi/404 durumunda Future reddedilir
    //    (`onPressed` sonucu dusurur), ekran ACIK kalir ve HICBIR MESAJ
    //    CIKMAZDI — kullanici urunu sildigini sanardi.
    try {
      await ref.read(urunServisiProvider).sil(widget.urun!.id);
    } catch (_) {
      if (!mounted) return;
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Ürün kaldırılamadı')),
      );
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.urun == null ? 'Ürün ekle' : 'Ürünü düzenle'),
        actions: [
          if (widget.urun != null)
            IconButton(icon: const Icon(LucideIcons.trash2), onPressed: _sil),
          TextButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.urun == null)
            GestureDetector(
              onTap: _gorselSec,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _gorsel == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.imagePlus, size: 28),
                              SizedBox(height: 6),
                              Text('Ürün fotoğrafı'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_gorsel!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
          // ⚠️⚠️ TURU 77b — MEVCUT FOTOGRAF DUZENLEMEDE GORUNMUYORDU.
          //    Gorsel blogu tamamen `widget.urun == null` kapisi altindaydi;
          //    sahibi urununu acinca fotografini ne goruyor ne de oldugunu
          //    biliyordu -> "fotografim silindi" algisi. Sunucu PATCH'te
          //    medyaya DOKUNMUYOR (davranis dogru), eksik olan ILETISIMDI.
          if (widget.urun != null && widget.urun!.mediaIds.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: MedyaGorsel(
                  mediaId: widget.urun!.mediaIds.first,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Fotoğraf düzenlemede değiştirilemez. Değiştirmek için ürünü '
                'kaldırıp yeniden ekle.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
          // ⚠️ "Tükendi" anahtari — bkz. `_durum` ve `_kaydet` serhleri.
          if (widget.urun != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tükendi'),
              subtitle: const Text('Menüde "Tükendi" olarak görünür'),
              value: _durum == 'tukendi',
              onChanged: (v) =>
                  setState(() => _durum = v ? 'tukendi' : 'yayinda'),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _ad,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Ürün adı',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _aciklama,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Açıklama',
              border: OutlineInputBorder(),
            ),
          ),
          // ⚠️ AI dugmesi YALNIZ sunucuda AI aciksa cizilir.
          if (ai?.acik ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _aiCalisiyor ? null : _aiAciklama,
                icon: _aiCalisiyor
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.sparkles, size: 17),
                label: Text(
                  _aiCalisiyor
                      ? 'Yazılıyor...'
                      : 'Yapay zekâ ile açıklama yaz'
                            '${ai != null && ai.kalan > 0 ? " (${ai.kalan})" : ""}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _bolum,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Bölüm (Ana Yemekler, Tatlılar...)',
              border: OutlineInputBorder(),
            ),
          ),
          TextField(
            controller: _fiyat,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fiyat (₺)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_kaydediliyor)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// ⚠️ AI DANISMA — "fotograftan problemleri anlat" (kullanici emri).
///    Hamburger menuden acilir; isletme hesabi GEREKTIRMEZ.
class AiDanismaEkrani extends ConsumerStatefulWidget {
  const AiDanismaEkrani({super.key});

  @override
  ConsumerState<AiDanismaEkrani> createState() => _AiDanismaEkraniState();
}

class _AiDanismaEkraniState extends ConsumerState<AiDanismaEkrani> {
  final _not = TextEditingController();
  File? _gorsel;
  String _sonuc = '';
  bool _calisiyor = false;

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _sec() async {
    if (!MedyaKapisi.izinVer(ref)) return;
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.camera);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    x ??= await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null || !mounted) return;
    setState(() => _gorsel = File(x!.path));
  }

  Future<void> _sor() async {
    if (_gorsel == null) return;
    setState(() {
      _calisiyor = true;
      _sonuc = '';
    });
    try {
      final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await ref
          .read(medyaServisiProvider)
          .yukle(dosya: hazir, kind: 'image', mime: 'image/jpeg');
      final s = await ref
          .read(aiServisiProvider)
          .danisma(mediaId: mediaId, metin: _not.text.trim());
      if (!mounted) return;
      setState(() => _sonuc = s);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir (turu 77b)
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = ref.watch(aiDurumProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Yapay zekâ danışman')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ⚠️ AI kapaliyken DURUST mesaj — dugme cizip 503 aldirmiyoruz.
          if (!(ai?.acik ?? false))
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Yapay zekâ şu anda kullanılamıyor.\n'
                  'Bu özellik yakında açılacak.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else ...[
            const Text(
              'Bir fotoğraf çek, ne yapman gerektiğini anlatalım.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _sec,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _gorsel == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.camera, size: 30),
                              SizedBox(height: 6),
                              Text('Fotoğraf çek / seç'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_gorsel!, fit: BoxFit.cover),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _not,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Eklemek istediğin bilgi (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_gorsel == null || _calisiyor) ? null : _sor,
              icon: _calisiyor
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.sparkles, size: 18),
              label: Text(_calisiyor ? 'İnceleniyor...' : 'Sor'),
            ),
            if (_sonuc.isNotEmpty) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(_sonuc, style: const TextStyle(fontSize: 15)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Yapay zekâ yanılabilir. Önemli konularda uzmana danış.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
