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
  /// ⚠️ 0 = "belirlenmedi". `Isletme.toJson` sifiri GONDERMEZ ve sunucu
  ///    `COALESCE` ile eskisini korur — yani konumu olmayan bir isletme
  ///    baska bir alani duzenledi diye konumunu KAYBETMEZ.
  double _enlem = 0;
  double _boylam = 0;
  bool _konumAliniyor = false;
  bool _zatenIsletme = false;

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

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
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
              // ⚠️⚠️ TURU 85 — KOORDINAT. `Isletme.toJson` bunlari YALNIZ
              //    sifirdan farkliysa gonderir ve sunucu `COALESCE` ile eski
              //    degeri KORUR; yani konum belirlenmemisse mevcut konum
              //    BOSA CEKILMEZ (turu 78b'de yasanan "kaydet basinca veriler
              //    siliniyor" sinifi).
              enlem: _enlem,
              boylam: _boylam,
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_zatenIsletme ? 'İşletme bilgileri' : 'İşletme hesabı'),
        actions: [
          TextButton(
            onPressed: _kaydediliyor ? null : _kaydet,
            child: const Text('Kaydet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'İşletme hesabına geçtiğinde profilinde kategori, adres, telefon '
                've çalışma saatlerin görünür; müşterilerin sana kolayca ulaşır.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
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
          _alan(_adres, 'Adres', LucideIcons.mapPin, satir: 2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _alan(_il, 'İl', LucideIcons.building2)),
              const SizedBox(width: 10),
              Expanded(child: _alan(_ilce, 'İlçe', LucideIcons.map)),
            ],
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
          const SizedBox(height: 20),
          _konumBolumu(),
          const SizedBox(height: 20),
          const Text(
            'ÇALIŞMA SAATLERİ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          for (final c in _calisma) _gunSatiri(c),
          const SizedBox(height: 24),
          if (_zatenIsletme)
            OutlinedButton.icon(
              onPressed: _kisiselYap,
              icon: const Icon(LucideIcons.userRound, size: 18),
              label: const Text('Kişisel hesaba dön'),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// ⚠️⚠️⚠️ TURU 85 — KONUM BOLUMU. **"Yakinimda"nin ON KOSULU.**
  ///
  /// Kullanici "yakinimda" ekrani istedi; o ekran isletmeleri MESAFEYE gore
  /// siralar. Ama `isletmeler.enlem/boylam` 028'den beri VAR olmasina ragmen
  /// **HICBIR KAYITTA DOLU DEGILDI** ve dolduracak bir arayuz YOKTU — turu
  /// 78'de bu acikca "once koordinat girisi lazim, yoksa harita bos tuval
  /// olur" diye not edilmisti. Bu bolum o boslugu kapatir.
  ///
  /// ⚠️ HARITADAN SECIM YOK (bilincli): harita SDK'si projede kurulu degil
  ///    (bkz. pubspec serhi — API anahtari + faturalandirma gerektiriyor).
  ///    "Bulundugum konum" isletme sahibi DUKKANINDAYKEN tek dokunusla dogru
  ///    sonucu verir ve bugun calisan TEK yoldur.
  /// ⚠️ Elle giris de BIRAKILDI: sahibi dukkanda degilken (ya da konum izni
  ///    vermek istemiyorken) koordinatlari haritadan bakip yazabilsin.
  Widget _konumBolumu() {
    final belirlendi = _enlem != 0 || _boylam != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KONUM',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          belirlendi
              ? 'Konum belirlendi: ${_enlem.toStringAsFixed(5)}, '
                    '${_boylam.toStringAsFixed(5)}'
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
                onPressed: () => setState(() {
                  _enlem = 0;
                  _boylam = 0;
                }),
              ),
            ],
          ],
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
