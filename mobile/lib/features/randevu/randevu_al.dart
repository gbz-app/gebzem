import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import 'randevu_servisi.dart';

/// ⚠️⚠️⚠️ TURU 80 — REZERVASYON / RANDEVU ALMA EKRANI.
///
/// Kullanici emri: *"restoran/yemek firmalarindan rezervasyon, doktor vs.den
/// randevu alinabilmeli"*.
///
/// ═══════════ ⚠️⚠️ NEDEN `showDatePicker` / `showTimePicker` YOK ═══════════
///
/// (1) **UYGULAMADA `flutter_localizations` YOK** (`pubspec.yaml`de bagimlilik
///     ve `main.dart`ta `localizationsDelegates` YOK — kaynaktan dogrulandi).
///     Material takvim/saat secicileri bu durumda **INGILIZCE** acilir:
///     "August", "Mon", "AM/PM". Turkce bir uygulamada kabul edilemez.
/// (2) Saat secici SERBEST saat verir; ama isletmenin calisma saatleri ve
///     kapasitesi var. Kullanicinin 03:00 secip "kapali" hatasi almasi kotu
///     bir deneyim — MUSAIT OLMAYAN saati HIC GOSTERMEMEK dogrusu.
///
/// Bunun yerine: **14 gunluk yatay gun seridi** + **sunucudan gelen slot
/// izgarasi**. Slotlari SUNUCU uretiyor (calisma saati + kapasite + gecmis saat
/// + kapali gun kurallari orada) — istemcide TEK BIR KURAL YOK.
/// ⚠️ YAPMA: buraya `showDatePicker`/`showTimePicker` ekleme; yeni paket ekleme.
class RandevuAlEkrani extends ConsumerStatefulWidget {
  const RandevuAlEkrani({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
  });

  final String isletmeId;
  final String isletmeAd;

  @override
  ConsumerState<RandevuAlEkrani> createState() => _RandevuAlEkraniState();
}

class _RandevuAlEkraniState extends ConsumerState<RandevuAlEkrani> {
  late DateTime _gun = _bugun();
  UygunGun? _veri;
  bool _yukleniyor = true;
  String? _hata;

  Slot? _secili;
  int _kisi = 2;
  final _hizmet = TextEditingController();
  final _not = TextEditingController();

  /// ⚠️ Cift dokunma kilidi: olusturma bir AG cagrisidir ve iki dokunus IKI
  ///    randevu acardi.
  bool _gonderiliyor = false;

  static DateTime _bugun() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _hizmet.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _secili = null;
    });
    // ⚠️ Servis await'ten ONCE (turu 78b: disposed State'te `ref.read`
    //    StateError firlatir ve is SESSIZCE iptal olur).
    final svc = ref.read(randevuServisiProvider);
    final istenen = _gun;
    try {
      final v = await svc.uygunSaatler(widget.isletmeId, istenen);
      // ⚠️ Kullanici beklerken BASKA gune gectiyse gelen sonucu YAZMA.
      if (!mounted || istenen != _gun) return;
      setState(() {
        _veri = v;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || istenen != _gun) return;
      setState(() {
        _yukleniyor = false;
        _hata = apiErrorMessage(e);
      });
    }
  }

  Future<void> _gonder() async {
    final s = _secili;
    if (s == null || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final svc = ref.read(randevuServisiProvider);
    final rezervasyon = _veri?.rezervasyonMu ?? false;
    try {
      await svc.olustur(
        isletmeId: widget.isletmeId,
        zaman: s.zaman,
        kisiSayisi: rezervasyon ? _kisi : 1,
        hizmet: rezervasyon ? '' : _hizmet.text.trim(),
        not: _not.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            rezervasyon
                ? 'Rezervasyon talebin gönderildi'
                : 'Randevu talebin gönderildi',
          ),
        ),
      );
    } catch (e) {
      // ⚠️ KOK MESSENGER: ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
      // ⚠️ 409 (slot doldu) sonrasi listeyi TAZELE — kullanici dolu slotu
      //    tekrar secmesin.
      if (mounted) {
        setState(() => _gonderiliyor = false);
        unawaited(_yukle());
      }
      return;
    }
    if (mounted) setState(() => _gonderiliyor = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = _veri;
    final rezervasyon = v?.rezervasyonMu ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(rezervasyon ? 'Rezervasyon' : 'Randevu'),
        // ⚠️ Isletme adi ALT BASLIKTA: kullanici hangi isletmeye talep
        //    gonderdigini SON ANA kadar gormeli.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.isletmeAd,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _gunSeridi(),
          const Divider(height: 1),
          Expanded(child: _govde()),
        ],
      ),
      bottomNavigationBar: _secili == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _gonderiliyor ? null : _gonder,
                  icon: _gonderiliyor
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.check, size: 18),
                  label: Text(
                    _gonderiliyor
                        ? 'Gönderiliyor...'
                        : '${_secili!.saat} için talep gönder',
                  ),
                ),
              ),
            ),
    );
  }

  /// 14 gunluk yatay serit. ⚠️ Yeni paket YOK — sade `ListView`.
  Widget _gunSeridi() => SizedBox(
    height: 78,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: 14,
      itemBuilder: (_, i) {
        final g = _bugun().add(Duration(days: i));
        final secili = g == _gun;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () {
              if (g == _gun) return;
              setState(() => _gun = g);
              unawaited(_yukle());
            },
            child: Container(
              width: 54,
              decoration: BoxDecoration(
                color: secili
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    // ⚠️ `weekday` 1..7 -> dizi 0..6.
                    kGunKisa[g.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      color: secili ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${g.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: secili ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _govde() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _yukle,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    final v = _veri;
    if (v == null || !v.acik) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'Bu işletme şu anda randevu almıyor.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    if (v.slotlar.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            v.mesaj.isNotEmpty
                ? v.mesaj
                : 'Bu gün için uygun saat yok.\nBaşka bir gün seç.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'Saat seç',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in v.slotlar)
              // ⚠️ DOLU slot CIZILIR ama PASIF: gizlemek kullaniciya "bu saat
              //    hic yok" dedirtirdi; pasif gostermek "dolmuş" bilgisini verir.
              ChoiceChip(
                label: Text(s.saat),
                selected: _secili?.zaman == s.zaman,
                onSelected: s.musait
                    ? (_) => setState(() => _secili = s)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
        // ⚠️ REZERVASYON -> kisi sayisi · RANDEVU -> hizmet. Ikisi AYNI ANDA
        //    gosterilmez; sunucudan gelen `tur` karar verir.
        if (v.rezervasyonMu) ...[
          const Text('Kaç kişi?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _kisi > 1 ? () => setState(() => _kisi--) : null,
                icon: const Icon(LucideIcons.minus, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_kisi',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _kisi < 20 ? () => setState(() => _kisi++) : null,
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _hizmet,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Hangi hizmet? (isteğe bağlı)',
              hintText: 'Örnek: kontrol, saç kesimi',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _not,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Not (isteğe bağlı)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Talebin işletmeye iletilir. Onaylandığında bildirim alırsın.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

