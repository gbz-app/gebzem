import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/denetleyici_sahibi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

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
    this.modul = Modul.varsayilan,
  });

  final String isletmeId;
  final String isletmeAd;
  final bool benimMi;

  /// TURU 89 — kategoriye ozel katalog modulu (Odalar/Hizmetler/Menü).
  /// ⚠️ Cagiran vermezse varsayilan 'Ürünler' kullanilir; ekran HICBIR
  ///    durumda kategoriden TAHMIN yurutmez.
  final Modul modul;

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
                  MaterialPageRoute(
                    builder: (_) => UrunDuzenleEkrani(modul: widget.modul),
                  ),
                );
                if (ok == true) _yukle();
              },
              icon: const Icon(LucideIcons.plus),
              // TURU 89 - 'Oda ekle' / 'Hizmet ekle' / 'Ürün ekle'.
              label: Text('${widget.modul.tekil} ekle'),
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
          : YenileSarmali(
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
                          // ⚠️ TURU 113 — `letterSpacing` KALDIRILDI (kullanici emri).
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
              MaterialPageRoute(
                builder: (_) => UrunDuzenleEkrani(urun: u, modul: widget.modul),
              ),
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

    final bekleme = _beklemeAc('Menü okunuyor...');
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
      bekleme.kapat(context);
      // ⚠️ TURU 77b — KOTA SAYACI TAZELENIR. `aiDurumProvider` SUREC OMURLU ve
      //    hicbir yerde invalidate EDILMIYORDU: dugme etiketindeki "(20)" 20
      //    cagridan sonra bile "(20)" der, kullanici sonra 429 alirdi.
      ref.invalidate(aiDurumProvider);
      await _oneriGoster(sonuc);
    } catch (e) {
      if (mounted) bekleme.kapat(context);
      // ⚠️ KOK MESSENGER: cagri onlarca saniye surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
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
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [ctrl],
        child: AlertDialog(
        // ⚠️⚠️ TURU 78b — `scrollable: true` ZORUNLU (denetim bulgusu).
        //    `AlertDialog`in scrollable OLMAYAN dalinda icerik
        //    `Flexible(child: content)` icine konur ve klavye acilinca kalan
        //    yukseklik cok kucuk olur: 6 satirlik metin kutusu + uyari metni
        //    KIRPILIR, kullanici ne yazdigini goremez. Ozellikle kucuk
        //    ekranlarda (360x640) "Oluştur" dugmesi bile erisilemez olur.
        //    ⚠️ YAPMA: `scrollable`i kaldirma.
        scrollable: true,
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
      ),
    );
    // ⚠️ Metin SENKRON okunur (route hala cikis animasyonunda = denetleyici
    //    CANLI); birakmayi DenetleyiciSahibi yapar.
    final tarif = ctrl.text.trim();
    if (onay != true || tarif.isEmpty || !mounted) return;

    // ⚠️⚠️ TURU 78b — SERVIS **AWAIT'TEN ONCE** yakalanir (fotograf yolundaki
    //    ile AYNI gerekce: AI cagrisi 60 saniyeye kadar surer).
    final aiSvc = ref.read(aiServisiProvider);

    final bekleme = _beklemeAc('Menü oluşturuluyor...');
    try {
      final sonuc = await aiSvc.menu(metin: tarif);
      if (!mounted) return;
      bekleme.kapat(context);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir
      await _oneriGoster(sonuc);
    } catch (e) {
      if (mounted) bekleme.kapat(context);
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  /// ⚠️⚠️⚠️ TURU 78b — BEKLEME DIYALOGU **GERI TUSUNA KAPALI** + kapanisini
  /// KENDI izler (denetim: SEVK ENGELI).
  ///
  /// ESKI KOD: `var diyalogAcik = true;` + `barrierDismissible: false`.
  /// **`barrierDismissible` YALNIZ PERDEYE DOKUNMAYI engeller — ANDROID GERI
  /// TUSU diyalog route'unu YINE DE POP EDER.** Kullanici "Menü oluşturuluyor..."
  /// beklerken (AI cagrisi ONLARCA saniye surer) sabirsizlanip geri basarsa:
  ///   · diyalog kapanir, `diyalogAcik` bayragi HALA `true` (yalanci),
  ///   · cagri donunce basari dali KOSULSUZ `Navigator.pop()` cagirir,
  ///   · en ustteki route artik **KATALOG EKRANIDIR** -> kullanicinin urun
  ///     listesi ekrani KAPANIR, ustelik oneri diyalogu bir daha acilamaz.
  ///
  /// FIX IKI KATMANLI:
  ///   1. `PopScope(canPop: false)` — geri tusu diyalogu KAPATAMAZ, yani
  ///      "en ustteki route diyalogdur" varsayimi GARANTI olur.
  ///   2. `whenComplete` — diyalog HERHANGI bir yolla kapanirsa bayrak
  ///      GERCEKLE senkron kalir (savunma katmani).
  /// ⚠️ YAPMA: `PopScope`u kaldirma; bayragi elle yonetmeye geri donme.
  _BeklemeKapisi _beklemeAc(String mesaj) {
    final kapi = _BeklemeKapisi();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text(mesaj)),
            ],
          ),
        ),
      ),
    ).whenComplete(() => kapi.acik = false);
    return kapi;
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
                //
                // ⚠️⚠️ TURU 78b — AYRISTIRMA ARTIK **TEK KAYNAK** (`_kurusOku`).
                //    Turu 77b bu korumayi YALNIZ BURAYA (gosterim yoluna)
                //    koymustu; KAYDETME yolu ciplak `as num?` ile kalmisti.
                //    Sonuc sinsiydi: model fiyati METIN dondurdugunde diyalog
                //    urunleri DOGRU fiyatlariyla listeliyor, kullanici hepsini
                //    isaretleyip "Menüye ekle" diyor ve **"0 ürün eklendi"**
                //    goruyordu — hicbir ipucu olmadan.
                //    ⚠️ YAPMA: iki yolda ayri ayristirma yazma (drift eder).
                final kurus = _kurusOku(u['fiyat_kurus']);
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

    // ⚠️ Servis await'lerden ONCE (bkz. `_kaydet` serhi): dongu onlarca urun
    //    icin onlarca istek atar ve arada ekran dispose olabilir.
    final urunSvc = ref.read(urunServisiProvider);
    var eklenen = 0;
    var basarisiz = 0;
    for (var i = 0; i < urunler.length; i++) {
      if (!secili[i]) continue;
      try {
        await urunSvc.ekle({
          'ad': (urunler[i]['ad'] ?? '').toString(),
          'aciklama': (urunler[i]['aciklama'] ?? '').toString(),
          'bolum': (urunler[i]['bolum'] ?? '').toString(),
          // ⚠️ TEK KAYNAK (yukaridaki gosterim yoluyla AYNI ayristirma).
          'fiyat_kurus': _kurusOku(urunler[i]['fiyat_kurus']),
          'media_ids': <String>[],
        });
        eklenen++;
      } catch (_) {
        // ⚠️ SESSIZ YUTMA YOK: eskiden `catch (_) {}` idi ve bir sorun oldugunda
        //    kullanici yalnizca "0 ürün eklendi" goruyordu — sebebi anlamasinin
        //    HICBIR yolu yoktu.
        basarisiz++;
      }
    }
    if (!mounted) return;
    await _yukle();
    // ⚠️ KOK MESSENGER: dongu uzun surer, ekran degismis olabilir.
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          basarisiz == 0
              ? '$eklenen ürün eklendi'
              : '$eklenen ürün eklendi, $basarisiz tanesi eklenemedi',
        ),
      ),
    );
  }

  /// AI'nin dondurdugu fiyati kurusa cevirir — **TEK KAYNAK**.
  ///
  /// ⚠️⚠️ Dil modelleri talimata ragmen sik sik `"fiyat_kurus": "1250"` (METIN)
  ///    donduruyor. Ciplak `as num?` cast'i bu durumda `TypeError` atar.
  ///    Turu 77b bu korumayi gosterim yoluna koydu, KAYDETME yoluna koymadi ve
  ///    turu 78b denetimi bunu SEVK ENGELI olarak yakaladi ("0 ürün eklendi").
  /// ⚠️ YAPMA: cagiran yerlere ayri ayristirma yazma.
  static int _kurusOku(dynamic ham) {
    if (ham is num) return ham.toInt();
    return int.tryParse(ham?.toString() ?? '') ?? 0;
  }
}

/// Urun ekle / duzenle (+ AI aciklama).
class UrunDuzenleEkrani extends ConsumerStatefulWidget {
  const UrunDuzenleEkrani({super.key, this.urun, this.modul = Modul.varsayilan});

  /// TURU 89 — kategoriye ozel alan tanimlari ve etiketler.
  final Modul modul;
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

  /// ⚠️⚠️ TURU 89 — MODULE OZEL ALANLARIN DEGERLERI (kapasite, yatak, süre...).
  ///
  /// Alan TANIMLARI sunucudan gelir (`widget.modul.alanlar`); burada yalnizca
  /// GIRILEN DEGERLER tutulur ve `ozellikler` JSONB'sine yazilir.
  /// ⚠️ Duzenlemede mevcut degerlerle DOLDURULUR — aksi halde kullanici
  ///    baska bir alani degistirip kaydettiginde girdigi kapasite/süre
  ///    SESSIZCE SILINIRDI.
  late final Map<String, String> _ozellikler = {
    ...?widget.urun?.ozellikler,
  };

  File? _gorsel;
  bool _kaydediliyor = false;
  bool _aiCalisiyor = false;

  /// ⚠️ TURU 79 — gorsel uretimi surerken dugmeyi KILITLER. Cift dokunus IKI
  ///    kotayi birden yakar ve uretim GERI ALINAMAZ (para harcanir).
  bool _gorselUretiliyor = false;

  /// ⚠️ TURU 79 — kullanicinin ONAYLADIGI AI gorselinin id'si.
  ///    `_gorsel` (elle secilen dosya) ile AYNI ANDA dolu olamaz — onay
  ///    adiminda oteki dusurulur, yoksa `_kaydet` hangisini gonderecegini
  ///    bilemez ve biri SESSIZCE kaybolurdu.
  String? _uretilenMediaId;

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
    setState(() {
      _gorsel = File(x!.path);
      // ⚠️⚠️ TURU 79 — SIMETRI ZORUNLU: onay adimi elle secilen dosyayi
      //    dusuruyor, burasi da AI gorselini DUSURMELI. Ikisi ayni anda dolu
      //    kalsaydi `_kaydet` AI'i tercih eder ve kullanicinin YENI SECTIGI
      //    fotograf SESSIZCE kaybolurdu ("sectim ama eskisi kaldi").
      _uretilenMediaId = null;
    });
  }

  /// ⚠️⚠️⚠️ TURU 79 — YAPAY ZEKA ILE URUN GORSELI URETIR.
  ///
  /// Kullanici emri: *"yapay zeka ile görsel oluşturma nerede"* / *"hepsi olsun"*.
  ///
  /// ⚠️ SONUC **ONAY ADIMINDAN GECER**: uretilen gorsel dogrudan urune
  ///
  ///	baglanmaz, kullaniciya buyuk gosterilir ve "Kullan / Vazgeç" sorulur.
  ///	Model yanlis/alakasiz bir sey cizebilir; menu onerisindeki ILKENIN AYNISI.
  ///
  /// ⚠️ URETIM PARA HARCAR ve GERI ALINAMAZ: dugme cagri boyunca KILITLENIR
  ///
  ///	(`_gorselUretiliyor`), yoksa cift dokunus IKI kotayi birden yakar.
  ///
  /// ⚠️ Servis await'lerden ONCE yakalanir (bkz. `_kaydet` serhi): uretim
  ///
  ///	120 saniyeye kadar surebiliyor ve o pencerede ekran dispose olabilir.
  Future<void> _aiGorsel() async {
    if (_gorselUretiliyor) return;
    final ad = _ad.text.trim();
    final tarif = await _gorselTarifiSor(ad);
    if (tarif == null || !mounted) return;
    // ⚠️ TURU 79b — BOS TARIF **SESSIZCE GECILMEZ** (denetim bulgusu).
    //    Eskiden bos metinle "Oluştur"a basmak hicbir sey yapmiyordu ve
    //    kullanici dugmenin bozuk oldugunu saniyordu.
    if (tarif.isEmpty) {
      rootMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Ne çizilmesini istediğini yaz')),
      );
      return;
    }

    final aiSvc = ref.read(aiServisiProvider);
    setState(() => _gorselUretiliyor = true);
    try {
      final mediaId = await aiSvc.gorsel(metin: tarif);
      if (!mounted) return;
      if (mediaId.isEmpty) {
        rootMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Görsel oluşturulamadı')),
        );
        return;
      }
      await _uretilenGorseliOnayla(mediaId, aiSvc);
    } catch (e) {
      // ⚠️ KOK MESSENGER: uretim uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      // ⚠️⚠️ TURU 79b — KOTA SAYACI **`finally` ICINDE** TAZELENIR (denetim).
      //    Eskiden yalniz BASARI dalindaydi; zaman asimi ya da 502 sonrasi
      //    etiketteki hak sayisi BAYAT kaliyordu. Ustelik basarisiz istek de
      //    (faturalanmis olabilecegi icin) kotadan DUSUYOR — yani sayacin
      //    guncellenmesi gereken en onemli an tam da HATA aniydi.
      if (mounted) {
        setState(() => _gorselUretiliyor = false);
        ref.invalidate(aiDurumProvider);
      }
    }
  }

  /// Ne cizilecegini sorar. ⚠️ Urun adi VARSA hazir gelir — kullanicinin
  ///    coguna dokunmadan onaylamasi icin.
  Future<String?> _gorselTarifiSor(String ad) async {
    final ctrl = TextEditingController(text: ad);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => DenetleyiciSahibi(
        denetleyiciler: [ctrl],
        child: AlertDialog(
        // ⚠️ `scrollable`: klavye acilinca icerik kirpilmasin (turu 78b dersi).
        scrollable: true,
        title: const Text('Yapay zekâ ile görsel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText:
                    'Ne çizilsin?\n'
                    'Örnek: tabakta Adana kebap, yanında bulgur pilavı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Görsel yapay zekâ tarafından ÜRETİLİR; gerçek bir fotoğraf '
              'değildir. Beğenmezsen kullanmak zorunda değilsin.',
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
      ),
    );
    // ⚠️ Metin SENKRON okunur; birakmayi DenetleyiciSahibi yapar.
    final metin = ctrl.text.trim();
    return onay == true ? metin : null;
  }

  /// Uretilen gorseli BUYUK gosterir ve onay ister.
  ///
  /// ⚠️ Onaylanirsa `_uretilenMediaId` doldurulur; `_kaydet` bunu `media_ids`e
  ///    koyar.
  /// ⚠️⚠️ TURU 79b — REDDEDILIRSE **SUNUCUDAN SILINIR** (denetim bulgusu).
  ///    Eskiden hicbir sey yapilmiyordu: medya R2'de 'aktif' kaliyor, hicbir
  ///    yere baglanmiyor ve kullanicinin AYLIK DEPOLAMA KOTASINDAN kalici
  ///    olarak dusuyordu. Birkac denemeden sonra kota, kullanicinin HIC
  ///    GORMEDIGI dosyalarla dolar ve temizleyecek bir yol da YOKTU.
  ///    ⚠️ AI hakki iade EDILMEZ (uretim gercekten para harcadi) — yalnizca
  ///       depolama geri verilir. Aksi halde "begenene kadar sinirsiz deneme"
  ///       olurdu.
  Future<void> _uretilenGorseliOnayla(String mediaId, AiServisi aiSvc) async {
    final kullan = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Görsel hazır'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: MedyaGorsel(mediaId: mediaId, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),
            // ⚠️ TURU 79b — KARAR ANINDA BILGI (denetim bulgusu). Uyari ilk
            //    diyalogda vardi ama ONAY aninda yoktu; kullanicinin "bu gercek
            //    bir fotograf mi" sorusunu sorabilecegi TEK an burasi.
            const Text(
              'Bu görsel yapay zekâ ile üretildi; gerçek bir fotoğraf değildir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kullan'),
          ),
        ],
      ),
    );
    if (kullan != true) {
      // ⚠️ TURU 79b: reddedilen gorsel SUNUCUDAN SILINIR (depolama kotasi iade).
      //    `mounted` KONTROLU YOK ve `unawaited` DEGIL: kullanici ekrandan
      //    cikmis olsa bile temizlik TAMAMLANMALI. Servis await'ten ONCE
      //    yakalandigi icin `ref` erisimi guvenli.
      await aiSvc.gorselVazgec(mediaId);
      return;
    }
    if (!mounted) return;
    setState(() {
      _uretilenMediaId = mediaId;
      // ⚠️ Elle secilmis dosya varsa DUSURULUR: iki kaynak birden olursa
      //    `_kaydet` hangisini yollayacagini bilemez ve sessizce biri kaybolur.
      _gorsel = null;
    });
  }

  /// ⚠️ AI ACIKLAMA — urunun fotografindan/adindan satis metni yazar.
  ///    Sonuc alana YAZILIR ama kullanici duzenleyebilir.
  Future<void> _aiAciklama() async {
    setState(() => _aiCalisiyor = true);
    // ⚠️ Servisler await'lerden ONCE (bkz. `_kaydet` serhi) — AI cagrisi uzun.
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);
    try {
      var mediaId = '';
      if (_gorsel != null) {
        final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
        if (hazir != null) {
          mediaId = await medyaSvc.yukle(
            dosya: hazir,
            kind: 'image',
            mime: 'image/jpeg',
          );
        }
      }
      final metin = await aiSvc.urunMetni(
        mediaId: mediaId,
        metin: _ad.text.trim(),
      );
      if (!mounted) return;
      setState(() => _aciklama.text = metin);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir (turu 77b)
    } catch (e) {
      // ⚠️ KOK MESSENGER: AI cagrisi uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
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
        // TURU 89 - kategoriye ozel modul turu ve alanlari.
        // Sunucu `tur`u beyaz listeden gecirir; gecersizse 'urun'a duser.
        'tur': widget.modul.tur,
        'ozellikler': _ozellikler,
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
        // ⚠️⚠️ TURU 79 — AI GORSELI ZATEN SUNUCUDA: yeniden YUKLENMEZ, id
        //    dogrudan baglanir. (Uretim yolunda baytlar OpenAI'dan SUNUCUYA
        //    gelip R2'ye orada yazildi; istemcide dosya HIC YOK.)
        if (_uretilenMediaId != null) {
          idler.add(_uretilenMediaId!);
        } else if (_gorsel != null) {
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
          // ⚠️⚠️ TURU 79b — URETIM SURERKEN **KAYDET KILITLI** (denetim bulgusu).
          //    Eskiden yalniz `_kaydediliyor`a bakiyordu: kullanici gorsel
          //    "Çiziliyor..." iken Kaydet'e basabiliyordu. Sonuc: urun
          //    FOTOGRAFSIZ kaydedilir, ekran kapanir, saniyeler sonra biten
          //    (ve PARASI ODENMIS) gorsel HICBIR YERE baglanmadan yetim kalir.
          //    ⚠️ `_aiCalisiyor` (AI aciklama) da ayni gerekceyle eklendi:
          //       yazilan metin alana ulasmadan ekran kapaniyordu.
          TextButton(
            onPressed: (_kaydediliyor || _gorselUretiliyor || _aiCalisiyor)
                ? null
                : _kaydet,
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
                  // ⚠️ TURU 79 — UC DURUM: (a) AI gorseli onaylandi -> SUNUCUDAN
                  //    ciz, (b) elle dosya secildi -> dosyadan ciz, (c) hicbiri.
                  //    (a) ve (b) AYNI ANDA olamaz (onay adiminda oteki dusuyor).
                  child: _uretilenMediaId != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: MedyaGorsel(
                            mediaId: _uretilenMediaId!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : _gorsel == null
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
          // ---- ⚠️⚠️ TURU 79 — YAPAY ZEKA ILE GORSEL OLUSTUR
          //
          // Kullanici emri: "yapay zeka ile gorsel oluşturma nerede?" —
          // turu 77/78'de yalniz METIN uclari baglanmisti.
          //
          // ⚠️ YALNIZ YENI URUNDE ve YALNIZ `ai.gorsel` bayragi TRUE iken
          //    cizilir. `ai.acik` YETMEZ: anahtar var ama medya (R2) kapaliysa
          //    sunucu 503 doner ve dugme "var gorunup calismayan" olurdu.
          // ⚠️ Duzenlemede GIZLI: sunucu PATCH'te medyaya DOKUNMUYOR (mevcut
          //    davranis), yani uretilen gorsel kaydedilemezdi.
          if (widget.urun == null && (ai?.gorsel ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                // ⚠️⚠️ TURU 79b — HAK BITINCE DUGME **PASIF** ve SEBEP YAZILI
                //    (denetim bulgusu). Eskiden hak 0 olunca sayac etiketten
                //    TAMAMEN kayboluyor, dugme ise ETKIN kaliyordu: kullanici
                //    saglikli durumdan ayirt edemiyor, basiyor ve 429 aliyordu.
                //    Ayrica sayi artik KOSULSUZ yaziliyor — "(0)" gormek,
                //    hicbir sey gormemekten cok daha bilgilendirici.
                child: TextButton.icon(
                  onPressed:
                      (_gorselUretiliyor || (ai?.gorselKalan ?? 0) <= 0)
                      ? null
                      : _aiGorsel,
                  icon: _gorselUretiliyor
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.wandSparkles, size: 17),
                  label: Text(
                    _gorselUretiliyor
                        ? 'Çiziliyor...'
                        : (ai?.gorselKalan ?? 0) <= 0
                        ? 'Günlük görsel hakkın doldu'
                        : 'Yapay zekâ ile görsel oluştur (${ai!.gorselKalan})',
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
            decoration: InputDecoration(
              // TURU 89 - etiket KATEGORIYE gore (otelciye 'Ana Yemekler'
              //    ornegi gosterilmesi kullanicinin sikayetiydi).
              labelText: widget.modul.bolumEtiketi,
              border: const OutlineInputBorder(),
            ),
          ),
          // ⚠️⚠️⚠️ TURU 89 — KATEGORIYE OZEL ALANLAR (kullanici emri).
          //
          //	Otel -> kapasite / yatak / kahvaltı, doktor -> süre.
          //	Alan TANIMLARI **SUNUCUDAN** gelir; burada yalnizca ciziliyor.
          //	Boylece yeni bir alan eklemek ISTEMCI GUNCELLEMESI GEREKTIRMEZ
          //	(`ilan` tarafiyla ayni desen).
          //
          // ⚠️ `ValueKey` ZORUNLU: modul degisirse (kategori degistirildiginde)
          //    Flutter alan elemanlarini YENIDEN KULLANIR ve
          //    `FormField.didUpdateWidget` `initialValue` degisimini YOK
          //    SAYAR -> "Metrekare" kutusunda "Ford" kalir (turu 77b/78b
          //    HAYALET VERI hatasi).
          for (final a in widget.modul.alanlar) ...[
            if (a.tip == 'secim')
              Padding(
                key: ValueKey('sec:${widget.modul.tur}:${a.anahtar}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _ozellikler[a.anahtar]?.isNotEmpty == true
                      ? _ozellikler[a.anahtar]
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: a.ad,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in a.secenekler)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) => setState(() {
                    if (v == null) {
                      _ozellikler.remove(a.anahtar);
                    } else {
                      _ozellikler[a.anahtar] = v;
                    }
                  }),
                ),
              )
            else
              Padding(
                key: ValueKey('txt:${widget.modul.tur}:${a.anahtar}'),
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  initialValue: _ozellikler[a.anahtar] ?? '',
                  keyboardType: a.tip == 'sayi'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: a.birim.isEmpty ? a.ad : '${a.ad} (${a.birim})',
                    border: const OutlineInputBorder(),
                  ),
                  // ⚠️ `onChanged` — odak kaybi `onSubmitted` TETIKLEMEZ ve
                  //    kullanicinin yazdigi deger SESSIZCE ATILIRDI
                  //    (turu 85c'de elle koordinat girisinde tam bu yasandi).
                  onChanged: (v) {
                    final t = v.trim();
                    if (t.isEmpty) {
                      _ozellikler.remove(a.anahtar);
                    } else {
                      _ozellikler[a.anahtar] = t;
                    }
                  },
                ),
              ),
          ],
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
    // ⚠️⚠️ TURU 78b — GALERI YEDEGI DE AYNI KORUMAYI KULLANIR (denetim: bu
    //    cagri `pickerAcik` bayragini SET ETMIYOR ve `try/catch`SIZDI, yani
    //    ayni dosyadaki diger iki secicisiyle ASIMETRIKTI).
    //    `pickerAcik` bayragi, secici acikken gelen aramanin medya kapilarini
    //    dogru degerlendirmesi icin var; burada set edilmeyince kamera iptal
    //    edilip galeriye dusuldugunde bayrak YANLIS kaliyordu.
    if (x == null) {
      try {
        MedyaKapisi.pickerAcik = true;
        x = await ImagePicker().pickImage(source: ImageSource.gallery);
      } catch (_) {
        // secici acilamadi — asagidaki null kapisi devrali
      } finally {
        MedyaKapisi.pickerAcik = false;
      }
    }
    if (x == null || !mounted) return;
    setState(() => _gorsel = File(x!.path));
  }

  Future<void> _sor() async {
    if (_gorsel == null) return;
    setState(() {
      _calisiyor = true;
      _sonuc = '';
    });
    // ⚠️ Servisler await'lerden ONCE (bkz. `_kaydet` serhi) — AI cagrisi uzun.
    final medyaSvc = ref.read(medyaServisiProvider);
    final aiSvc = ref.read(aiServisiProvider);
    try {
      final hazir = await MedyaServisi.gorseliHazirla(_gorsel!);
      if (hazir == null) throw Exception('Görsel hazırlanamadı');
      final mediaId = await medyaSvc.yukle(
        dosya: hazir,
        kind: 'image',
        mime: 'image/jpeg',
      );
      final s = await aiSvc.danisma(
        mediaId: mediaId,
        metin: _not.text.trim(),
      );
      if (!mounted) return;
      setState(() => _sonuc = s);
      ref.invalidate(aiDurumProvider); // kota sayaci tazelenir (turu 77b)
    } catch (e) {
      // ⚠️ KOK MESSENGER: AI cagrisi uzun surer, ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
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

/// Bekleme diyalogunun canliligini tutan kucuk kapi (bkz. `_beklemeAc` serhi).
///
/// ⚠️ Ayri bir SINIF olmasinin sebebi: `bool`u closure'da tutmak, kapatma
///    sorumlulugunu cagirana birakir ve turu 77b/78b'de tam bu yuzden iki ayri
///    yerde birbirinden bagimsiz (ve biri YANLIS) bayrak yonetimi olusmustu.
class _BeklemeKapisi {
  bool acik = true;

  /// Diyalog HALA aciksa kapatir. Kapali ise HICBIR SEY YAPMAZ.
  ///
  /// ⚠️ Bu kontrol olmadan `Navigator.pop()` EN USTTEKI route'u kapatir ve
  ///    diyalog zaten kapanmissa **CAGIRAN EKRANI** kapatir.
  void kapat(BuildContext context) {
    if (!acik) return;
    acik = false;
    Navigator.of(context).pop();
  }
}
