import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;

/// ⚠️⚠️⚠️ TURU 81 — SOHBET ICI ANKET (istemci).
///
/// Sunucu: `backend/internal/chat/anket.go` · Sema: migration 040.
/// Tasarim: `docs/medya-arastirma/tasarim-anket.md`.

// ---------------------------------------------------------------- MODEL

class AnketSecenek {
  const AnketSecenek({
    required this.id,
    required this.metin,
    required this.oy,
    required this.benim,
  });

  factory AnketSecenek.fromJson(Map<String, dynamic> m) => AnketSecenek(
    id: (m['id'] as num?)?.toInt() ?? 0,
    metin: (m['text'] ?? '').toString(),
    oy: (m['votes'] as num?)?.toInt() ?? 0,
    benim: m['mine'] == true,
  );

  final int id;
  final String metin;
  final int oy;

  /// ⚠️ Yayin (WS) govdesinde bu alan ANLAMSIZDIR: sunucu ortak govdeyi bos
  ///    kullanici ile uretir, cunku "benim oylarim" kisiye ozeldir. Istemci
  ///    kendi secimini YEREL durumundan bilir.
  final bool benim;
}

class Anket {
  const Anket({
    required this.id,
    required this.soru,
    required this.olusturanId,
    required this.coklu,
    required this.kapali,
    required this.seq,
    required this.secenekler,
    required this.toplamOy,
  });

  factory Anket.fromJson(Map<String, dynamic> m) => Anket(
    id: (m['id'] as num?)?.toInt() ?? 0,
    soru: (m['question'] ?? '').toString(),
    olusturanId: (m['creator_id'] ?? '').toString(),
    coklu: m['multi'] == true,
    kapali: m['closed'] == true,
    seq: (m['vote_seq'] as num?)?.toInt() ?? 0,
    secenekler: ((m['options'] as List?) ?? [])
        .map((e) => AnketSecenek.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    toplamOy: (m['total_votes'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String soru;
  final String olusturanId;
  final bool coklu;
  final bool kapali;

  /// ⚠️ Eskimis WS olayini elemek icin: `yeniSeq <= mevcutSeq` ise olay YOK
  ///    SAYILIR. WS bu projede KAYBOLABILIR/GECIKEBILIR (turu 61 `call.held`).
  final int seq;
  final List<AnketSecenek> secenekler;
  final int toplamOy;

  /// Bir secenegin yuzdesi (0..1). Toplam 0 ise 0.
  double oran(AnketSecenek s) => toplamOy == 0 ? 0 : s.oy / toplamOy;
}

// ---------------------------------------------------------------- SERVIS

class AnketServisi {
  AnketServisi(this._ref);
  final Ref _ref;

  Future<Map<String, dynamic>> olustur({
    required String chatId,
    required String soru,
    required List<String> secenekler,
    required bool coklu,
  }) async {
    final r = await _ref.read(apiProvider).post(
      '/chats/$chatId/polls',
      data: {'question': soru, 'options': secenekler, 'multi': coklu},
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  /// ⚠️ ISTENEN TAM KUME gonderilir (artimsal DEGIL): bos liste = tum oylarimi
  ///    geri cek. Boylece oy verme/degistirme/geri cekme TEK yoldan yurur.
  Future<Anket> oyVer(int pollId, List<int> secenekIds) async {
    final r = await _ref
        .read(apiProvider)
        .post('/polls/$pollId/vote', data: {'option_ids': secenekIds});
    return Anket.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<Anket> kapat(int pollId) async {
    final r = await _ref.read(apiProvider).post('/polls/$pollId/close');
    return Anket.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<Anket> getir(int pollId) async {
    final r = await _ref.read(apiProvider).get('/polls/$pollId');
    return Anket.fromJson((r.data as Map).cast<String, dynamic>());
  }
}

final anketServisiProvider = Provider<AnketServisi>(AnketServisi.new);

// ---------------------------------------------------------------- OLUSTURMA

class AnketTaslak {
  const AnketTaslak(this.soru, this.secenekler, this.coklu);
  final String soru;
  final List<String> secenekler;
  final bool coklu;
}

Future<AnketTaslak?> anketPaneliAc(BuildContext context) =>
    showModalBottomSheet<AnketTaslak>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AnketPanel(),
    );

class _AnketPanel extends StatefulWidget {
  const _AnketPanel();

  @override
  State<_AnketPanel> createState() => _AnketPanelState();
}

class _AnketPanelState extends State<_AnketPanel> {
  final _soru = TextEditingController();

  /// ⚠️ IKI BOS ALANLA baslar: anket TANIM GEREGI en az iki secenek ister,
  ///    kullaniciya "ekle"ye basmadan yazabilecegi iki kutu vermek gerekir.
  final _secenekler = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _coklu = false;
  String? _hata;

  @override
  void dispose() {
    _soru.dispose();
    for (final c in _secenekler) {
      c.dispose();
    }
    super.dispose();
  }

  void _gonder() {
    final soru = _soru.text.trim();
    // ⚠️ Dogrulama SUNUCUDA DA VAR (tek kaynak orasi); buradaki kopya yalnizca
    //    kullaniciya ANINDA geri bildirim icin. Sunucu son sozu soyler.
    if (soru.isEmpty) {
      setState(() => _hata = 'Anket sorusu boş olamaz');
      return;
    }
    final dolu = _secenekler
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (dolu.length < 2) {
      setState(() => _hata = 'En az 2 seçenek gerekli');
      return;
    }
    if (dolu.toSet().length != dolu.length) {
      setState(() => _hata = 'Seçenekler birbirinden farklı olmalı');
      return;
    }
    Navigator.of(context).pop(AnketTaslak(soru, dolu, _coklu));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.chartBar, size: 20),
                const SizedBox(width: 8),
                Text('Anket', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _soru,
              autofocus: true,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Soru',
                errorText: _hata,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_hata != null) setState(() => _hata = null);
              },
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < _secenekler.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _secenekler[i],
                        maxLength: 100,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Seçenek ${i + 1}',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    // ⚠️ SILME yalnizca IKIDEN FAZLA secenek varken: anket
                    //    tanim geregi en az iki secenek ister ve kullaniciyi
                    //    gecersiz duruma DUSURMEMELIYIZ.
                    if (_secenekler.length > 2)
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => setState(() {
                          _secenekler.removeAt(i).dispose();
                        }),
                      ),
                  ],
                ),
              ),
            if (_secenekler.length < 12)
              TextButton.icon(
                onPressed: () =>
                    setState(() => _secenekler.add(TextEditingController())),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Seçenek ekle'),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Birden fazla seçilebilsin'),
              value: _coklu,
              onChanged: (v) => setState(() => _coklu = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _gonder,
                child: const Text('Gönder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- BALON

/// Sohbetteki anket balonu.
///
/// ⚠️ KENDI DURUMUNU TUTAR: oy verilince tum mesaj listesini yeniden cekmek
///    (mevcut `send` deseni) 20 mesajlik bir istegi her dokunusta tetiklerdi.
///    Sunucu oy yanitinda ANKETIN TAM ANLIK GORUNTUSUNU donduruyor.
class AnketBalon extends ConsumerStatefulWidget {
  const AnketBalon({super.key, required this.anket, required this.benimMi});

  final Anket anket;

  /// ⚠️ Anketi olusturan = mesajin GONDERENIDIR, yani "benim mesajim mi"
  ///    sorusu "anketi ben mi olusturdum" ile AYNI SEYDIR. Ayrica kullanici
  ///    kimligi tasimak gereksiz bir bagimlilik olurdu.
  final bool benimMi;

  @override
  ConsumerState<AnketBalon> createState() => _AnketBalonState();
}

class _AnketBalonState extends ConsumerState<AnketBalon> {
  late Anket _a = widget.anket;
  bool _mesgul = false;

  @override
  void didUpdateWidget(AnketBalon eski) {
    super.didUpdateWidget(eski);
    // ⚠️⚠️ `vote_seq` KAPISI: disaridan (WS / liste tazeleme) gelen anlik
    //    goruntu ESKIMIS olabilir. Kucuk ya da esit sirali bir govdeyi
    //    uygulamak, kullanicinin AZ ONCE verdigi oyu geri alirdi.
    if (widget.anket.seq > _a.seq) _a = widget.anket;
  }

  Future<void> _oyVer(AnketSecenek s) async {
    if (_mesgul || _a.kapali) return;
    // ⚠️ Istenen TAM kume hesaplanir (sunucu artimsal istek KABUL ETMEZ).
    final secili = _a.secenekler.where((x) => x.benim).map((x) => x.id).toSet();
    if (_a.coklu) {
      secili.contains(s.id) ? secili.remove(s.id) : secili.add(s.id);
    } else {
      // Tek secimlik: ayni secenege tekrar dokunmak oyu GERI CEKER.
      secili.contains(s.id)
          ? secili.clear()
          : (secili
              ..clear()
              ..add(s.id));
    }
    setState(() => _mesgul = true);
    try {
      final yeni = await ref
          .read(anketServisiProvider)
          .oyVer(_a.id, secili.toList());
      if (mounted) setState(() => _a = yeni);
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _kapat() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Anketi bitir'),
        content: const Text('Bitirilen ankete bir daha oy verilemez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      final yeni = await ref.read(anketServisiProvider).kapat(_a.id);
      if (mounted) setState(() => _a = yeni);
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.chartBar, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                _a.kapali
                    ? 'Anket · bitti'
                    : (_a.coklu ? 'Anket · çoklu seçim' : 'Anket'),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _a.soru,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final s in _a.secenekler)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => _oyVer(s),
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  children: [
                    // ⚠️ ORAN CUBUGU secenegin ARKASINDA: ayri bir cubuk
                    //    cizmek balonu iki katina cikarirdi.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _a.oran(s),
                        minHeight: 38,
                        backgroundColor: scheme.onSurface.withValues(
                          alpha: 0.07,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          scheme.primary.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: [
                            Icon(
                              s.benim
                                  ? LucideIcons.circleCheck
                                  : LucideIcons.circle,
                              size: 16,
                              color: s.benim ? scheme.primary : scheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.metin,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: s.benim
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${s.oy}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            children: [
              Text(
                _a.toplamOy == 0 ? 'Henüz oy yok' : '${_a.toplamOy} oy',
                style: TextStyle(fontSize: 11.5, color: scheme.outline),
              ),
              const Spacer(),
              // ⚠️ "Bitir" YALNIZ olusturana ve YALNIZ acik ankette. Sunucu da
              //    ayni kapiyi uyguluyor (403) — burasi ARAYUZ, yetki orada.
              if (!_a.kapali && widget.benimMi)
                TextButton(
                  onPressed: _kapat,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Bitir', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
