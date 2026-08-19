/// ⚠️⚠️⚠️ TURU 91 — TEKLIF ISTEGI: AKIS + ADIM ADIM SIHIRBAZ.
///
/// Kullanici emri: *"dugun mu yapmak istiyorsun HIZMET mi almak istiyorsun,
/// burada STEP STEP — ornegin dugun yapmak istiyorum, salon sececek, misafir
/// sayisi, neler istiyor, dis mekan mi vs; sonra bu bilgiler ornegin KUAFORE
/// teklif gidecek, DIGERLERINE gidecek, onlar da KARSI TEKLIF verecekler"*.
///
/// ═══════════ FORM SUNUCUDAN URETILIR ═══════════
///
/// Adimlar ve alanlar `GET /ilan-kategoriler` -> `talep` turunden gelir
/// (`Alan.adim` ile gruplanir). Yani yeni bir soru eklemek ISTEMCI
/// GUNCELLEMESI GEREKTIRMEZ.
/// ⚠️ YAPMA: soru listesini Dart'a yazma (turu 77 kurali).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../ilan/ilan_ekranlari.dart' show IlanDetayEkrani, IlanListesiEkrani;
import '../ilan/ilan_servisi.dart';
import 'talep_servisi.dart';

// ═══════════════════ 1) DAL SECIMI + KATEGORI ═══════════════════

class TalepAkisiEkrani extends ConsumerWidget {
  const TalepAkisiEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agac = ref.watch(ilanAgaciProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teklif iste'),
        actions: [
          IconButton(
            tooltip: 'Taleplerim',
            icon: const Icon(LucideIcons.clipboardList),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IlanListesiEkrani(
                  tur: 'talep', benim: true, baslik: 'Taleplerim'),
              ),
            ),
          ),
        ],
      ),
      body: agac.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _hataGovde(context, ref),
        data: (turler) {
          final talep = turler.where((t) => t.anahtar == 'talep').firstOrNull;
          if (talep == null) {
            // ⚠️ DURUST HATA: sunucu `talep` turunu dondurmuyorsa ozellik
            //    KULLANILAMAZ. Bos liste gostermek "hicbir kategori yok" gibi
            //    YANLIS bir izlenim verirdi.
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Teklif isteği şu anda kullanılamıyor.\n'
                  'Uygulamayı güncellemen gerekebilir.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final dugun = talep.kategoriler
              .where((k) => dugunKategorileri.contains(k.anahtar))
              .toList();
          final hizmet = talep.kategoriler
              .where((k) => !dugunKategorileri.contains(k.anahtar))
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const Text(
                'Ne için teklif istiyorsun?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Birkaç soruya cevap ver, ilgili işletmeler sana teklif '
                'göndersin.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (dugun.isNotEmpty) ...[
                _dalBasligi('DÜĞÜN & ORGANİZASYON'),
                for (final k in dugun) _kategoriSatiri(context, talep, k),
                const SizedBox(height: 18),
              ],
              if (hizmet.isNotEmpty) ...[
                _dalBasligi('HİZMET'),
                for (final k in hizmet) _kategoriSatiri(context, talep, k),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _hataGovde(BuildContext context, WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Kategoriler yüklenemedi'),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => ref.invalidate(ilanAgaciProvider),
          child: const Text('Tekrar dene'),
        ),
      ],
    ),
  );

  Widget _dalBasligi(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      s,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        // ⚠️ TURU 113 — `letterSpacing` KALDIRILDI (kullanici emri).
        color: Colors.grey,
      ),
    ),
  );

  Widget _kategoriSatiri(
    BuildContext context,
    IlanTuru talep,
    ({String anahtar, String ad}) k,
  ) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(k.ad),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TalepSihirbaziEkrani(tur: talep, kategori: k),
          ),
        ),
      );
}

// ═══════════════════ 2) ADIM ADIM SIHIRBAZ ═══════════════════

class TalepSihirbaziEkrani extends ConsumerStatefulWidget {
  const TalepSihirbaziEkrani({
    super.key,
    required this.tur,
    required this.kategori,
  });

  final IlanTuru tur;
  final ({String anahtar, String ad}) kategori;

  @override
  ConsumerState<TalepSihirbaziEkrani> createState() => _SihirbazState();
}

class _SihirbazState extends ConsumerState<TalepSihirbaziEkrani> {
  int _adim = 0;
  bool _gonderiliyor = false;

  /// Alan anahtari -> deger. `cok_secim` icin `List<String>`.
  final Map<String, dynamic> _cevaplar = {};
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  final _not = TextEditingController();

  /// ⚠️⚠️⚠️ TURU 93b — ALANLAR **KATEGORIYE GORE SUNUCUDAN** (denetim).
  ///
  ///	Onceden `widget.tur.alanlar` kullaniliyordu ve o liste TEK'ti: 15
  ///	kategorinin HEPSINDE ayni sorular ciziliyordu. "Temizlik" talebi
  ///	acan kullaniciya *"Kişi sayısı"*, *"Mekân: KIR DÜĞÜNÜ"*,
  ///	*"İhtiyacın olanlar: GELİNLİK, GELİN ARABASI"* soruluyordu;
  ///	*"Diyet & Beslenme Programı"* talebinde de aynisi.
  ///	Kullanicinin emri acikca IKI DALDI.
  /// ⚠️ ILK CIZIM `widget.tur.alanlar` ile yapilir (ekran BOS ACILMAZ),
  ///    suzulmus liste gelince yerine gecer. Istek patlarsa TAM liste
  ///    kalir — fazla soru sormak, HIC soru sormamaktan iyidir.
  late List<TalepAdimi> _adimlar = adimlaraBol(widget.tur.alanlar);

  /// Sunucudan gelen adimlar + SON ADIM (konum/not/ozet).
  int get _toplam => _adimlar.length + 1;
  bool get _sonAdim => _adim >= _adimlar.length;

  @override
  void dispose() {
    _il.dispose();
    _ilce.dispose();
    _not.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _alanlariSuz();
  }

  Future<void> _alanlariSuz() async {
    try {
      final agac = await ref
          .read(ilanServisiProvider)
          .agac(kategori: widget.kategori.anahtar);
      final talep = agac.where((t) => t.anahtar == 'talep').firstOrNull;
      if (!mounted || talep == null || talep.alanlar.isEmpty) return;
      setState(() {
        _adimlar = adimlaraBol(talep.alanlar);
        // ⚠️ Adim indisi TASABILIR: suzulmus listede daha az adim olabilir.
        if (_adim >= _adimlar.length) _adim = _adimlar.length - 1;
      });
    } catch (_) {
      // ⚠️ SESSIZ: tam liste ekranda kalir (bkz. `_adimlar` serhi).
    }
  }

  /// ⚠️ Bu adimdaki ZORUNLU alanlarin hepsi dolu mu?
  bool get _devamEdilebilir {
    if (_sonAdim) return true;
    for (final a in _adimlar[_adim].alanlar) {
      if (!a.zorunlu) continue;
      final v = _cevaplar[a.anahtar];
      if (v == null || (v is String && v.trim().isEmpty) ||
          (v is List && v.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _gonder() async {
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final nav = Navigator.of(context);
    final mesajci = ScaffoldMessenger.of(context);
    try {
      // ⚠️ `ozellikler` SERBEST JSONB: sunucu alanlari DOGRULAMAZ, yalnizca
      //    saklar. Tur tanimi da sunucudan geldigi icin yeni alan eklemek
      //    ISTEMCI GUNCELLEMESI GEREKTIRMEZ.
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur —
      //    "gonderdim sandim, gitmemis").
      final svc = ref.read(ilanServisiProvider);
      final id = await svc.olustur({
        'tur': 'talep',
        'kategori': widget.kategori.anahtar,
        'baslik': widget.kategori.ad,
        'aciklama': _not.text.trim(),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'ozellikler': _cevaplar,
      });
      // ⚠️⚠️⚠️ TURU 93b — **TALEP OLUSTU, KULLANICI IKINCI KEZ GONDERIYORDU**
      //	(denetimde yakalandi).
      //
      //	Iki ag cagrisi TEK `try` icindeydi: `olustur` BASARILI olup
      //	talep sunucuda olusuyor ve fan-out bildirimleri GIDIYOR, ardindan
      //	`detay` bir ag hickirigiyla firlatinca `catch` "Talep
      //	olusturulamadi" basiyordu. Kullanici tekrar basiyor -> **IKINCI
      //	TALEP** + hedef isletmelere **IKINCI BILDIRIM**. `ilanlar`da
      //	tekillik kisiti YOK, yani kayit kaliciydi.
      //
      // ⚠️ FIX: `detay` AYRI bir `try` icinde. Basarisiz olursa talep
      //    YINE OLUSMUSTUR; kullaniciya oyle soylenir ve sihirbaz kapanir —
      //    "olusturulamadi" YALANI bir daha soylenmez.
      // ⚠️ `IlanDetayEkrani` bir `Ilan` NESNESI istiyor (id degil); nesne
      //    gecmek listeden acilan ilanla AYNI nesnenin paylasilmasini
      //    saglar (turu 76).
      final Ilan ilan;
      try {
        ilan = await svc.detay(id);
      } catch (_) {
        if (!mounted) return;
        nav.pop(true);
        mesajci.showSnackBar(const SnackBar(
          content: Text('Talebin oluşturuldu. Detayı "Taleplerim"den açabilirsin.'),
        ));
        return;
      }
      if (!mounted) return;
      // ⚠️ Sihirbazi YIGINDAN KALDIRIP detaya gidiyoruz: kullanici geri
      //    tusuna bastiginda doldurdugu forma DONMEMELI (talep zaten
      //    olusturuldu; ikinci kez gondermeye calisirdi).
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => IlanDetayEkrani(ilan: ilan)),
      );
      mesajci.showSnackBar(const SnackBar(
        content: Text('Talebin oluşturuldu — teklifler burada görünecek'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _gonderiliyor = false);
      mesajci.showSnackBar(
          const SnackBar(content: Text('Talep oluşturulamadı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kategori.ad),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_adim + 1) / _toplam),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: _sonAdim ? _sonAdimGovde() : _adimGovde(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (_adim > 0)
                    TextButton(
                      onPressed: _gonderiliyor
                          ? null
                          : () => setState(() => _adim--),
                      child: const Text('Geri'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: (!_devamEdilebilir || _gonderiliyor)
                        ? null
                        : () {
                            if (_sonAdim) {
                              _gonder();
                            } else {
                              setState(() => _adim++);
                            }
                          },
                    child: _gonderiliyor
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : Text(_sonAdim ? 'Talebi gönder' : 'Devam'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _adimGovde() => [
        for (final a in _adimlar[_adim].alanlar) ...[
          _alan(a),
          const SizedBox(height: 18),
        ],
      ];

  List<Widget> _sonAdimGovde() => [
        const Text('Nerede?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _il,
          decoration: const InputDecoration(
              labelText: 'İl', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _ilce,
          decoration: const InputDecoration(
              labelText: 'İlçe', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 22),
        const Text('Eklemek istediğin bir şey var mı?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _not,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Detaylar, özel istekler...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        // ⚠️⚠️ GORUNURLUK UYARISI **ZORUNLU** (migration 045 karari).
        //    Talep `ilanlar` tablosunda yasiyor ve o tablo HERKESE ACIK.
        //    Kullanici bunu bilmeden ozel bilgi yazarsa, yazdigi sey tum
        //    oturum sahiplerine gorunur. Uyariyi gostermemek, gizlilik
        //    beklentisini SESSIZCE ihlal etmek olurdu.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.info, size: 18, color: Colors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu talep herkese açıktır. Telefon veya adres yazma — '
                  'işletmeler sana uygulama üzerinden ulaşacak.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ];

  /// Tek bir alanin girisi — TIPE gore.
  ///
  /// ⚠️ `ValueKey` ZORUNLU: adim degisince Flutter ayni tipteki elementi
  ///    YENIDEN KULLANIR ve `TextField`in eski degeri yeni alanda gorunur
  ///    ("hayalet veri" — turu 77b'de ilan formunda tam bu yasandi:
  ///    "Metrekare" kutusunda "Ford" yaziyordu).
  Widget _alan(IlanAlani a) {
    final etiket = a.zorunlu ? '${a.ad} *' : a.ad;
    switch (a.tip) {
      case 'secim':
        return Column(
          key: ValueKey('secim:${a.anahtar}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in a.secenekler)
                  ChoiceChip(
                    label: Text(s),
                    selected: _cevaplar[a.anahtar] == s,
                    onSelected: (_) =>
                        setState(() => _cevaplar[a.anahtar] = s),
                  ),
              ],
            ),
          ],
        );
      case 'cok_secim':
        final secili = (_cevaplar[a.anahtar] as List?)?.cast<String>() ?? [];
        return Column(
          key: ValueKey('cok:${a.anahtar}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Birden fazla seçebilirsin',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in a.secenekler)
                  FilterChip(
                    label: Text(s),
                    selected: secili.contains(s),
                    onSelected: (v) => setState(() {
                      final l = [...secili];
                      v ? l.add(s) : l.remove(s);
                      _cevaplar[a.anahtar] = l;
                    }),
                  ),
              ],
            ),
          ],
        );
      case 'tarih':
        final v = (_cevaplar[a.anahtar] ?? '').toString();
        return Column(
          key: ValueKey('tarih:${a.anahtar}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.calendar, size: 18),
              label: Text(v.isEmpty ? 'Tarih seç' : v),
              onPressed: () async {
                final simdi = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: simdi.add(const Duration(days: 30)),
                  firstDate: simdi,
                  // ⚠️ Dugun genelde 1-2 yil once planlanir; tavan 2 yil.
                  lastDate: simdi.add(const Duration(days: 730)),
                  helpText: a.ad,
                  cancelText: 'Vazgeç',
                  confirmText: 'Seç',
                );
                if (d == null || !mounted) return;
                setState(() => _cevaplar[a.anahtar] =
                    '${d.day}.${d.month}.${d.year}');
              },
            ),
          ],
        );
      case 'sayi':
        return TextFormField(
          key: ValueKey('sayi:${a.anahtar}'),
          initialValue: (_cevaplar[a.anahtar] ?? '').toString(),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: etiket,
            suffixText: a.birim.isEmpty ? null : a.birim,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _cevaplar[a.anahtar] = v.trim()),
        );
      default:
        return TextFormField(
          key: ValueKey('metin:${a.anahtar}'),
          initialValue: (_cevaplar[a.anahtar] ?? '').toString(),
          decoration: InputDecoration(
            labelText: etiket,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _cevaplar[a.anahtar] = v.trim()),
        );
    }
  }
}
