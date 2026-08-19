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

  /// `benim` alani DEGISTIRILMIS kopya (yayin govdesi birlestirilirken).
  AnketSecenek benimle(bool b) =>
      AnketSecenek(id: id, metin: metin, oy: oy, benim: b);
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

  /// ⚠️⚠️⚠️ TURU 81 (denetim bulgusu: SEVK ENGELI) — YAYIN GOVDESINI
  /// BIRLESTIR: sayimlar YENIDEN, `benim` secimleri ESKIDEN.
  ///
  /// WS yayini ORTAK bir govdedir ve sunucu onu SIFIR UUID ile uretir, yani
  /// `mine` **HER SECENEKTE false**tur. Gelen govde oldugu gibi uygulansaydi:
  /// baska biri oy verdiginde **KULLANICININ KENDI OYU EKRANDAN SILINIRDI**
  /// (isaret kaybolur, coklu secimde tum secimleri gider). Kullanici "oyum
  /// gitti" der ve tekrar oy verirdi.
  ///
  /// ⚠️ `benim` YEREL GERCEKTIR: kendi oyunu yalnizca kendi istegin belirler
  ///    (`oyVer` yaniti KISIYE OZELDIR ve `mine` tasir). Yayin yalnizca
  ///    SAYIMLARI ve KAPALI bilgisini tasir.
  /// ⚠️ YAPMA: yayin govdesini dogrudan atama.
  Anket yayinlaBirlestir(Anket yayin) {
    final benimSecimler = {
      for (final s in secenekler)
        if (s.benim) s.id,
    };
    return Anket(
      id: yayin.id,
      soru: yayin.soru,
      olusturanId: yayin.olusturanId,
      coklu: yayin.coklu,
      kapali: yayin.kapali,
      seq: yayin.seq,
      toplamOy: yayin.toplamOy,
      secenekler: yayin.secenekler
          .map((s) => s.benimle(benimSecimler.contains(s.id)))
          .toList(),
    );
  }
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
                const Icon(LucideIcons.vote, size: 20),
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
  const AnketBalon({
    super.key,
    required this.anket,
    required this.benimMi,
    this.enGenis = 280,
    this.soruGoster = true,
  });

  /// ⚠️⚠️ TURU 104 — **GORUNUM VARYANTI (mantik DEGISMEZ).**
  ///
  ///	Bu bilesen SOHBET ile AKISIN **TEK KAYNAGIDIR**: oylama, sayim,
  ///	kapatma ve `yayinlaBirlestir` (WS sayimlarini kendi oyumu EZMEDEN
  ///	birlestirme) hepsi burada. Akis icin ikinci bir anket bileseni
  ///	yazmak, bu projede ALTI kez sahaya cikmis "iki kopya drift eder"
  ///	hatasini davet ederdi.
  ///	Bu yuzden akis yalnizca **GENISLIK** verir: sohbet balonu 280 dp ile
  ///	sinirlidir (balon kartin tamamini kaplamamali), akis karti TAM
  ///	GENISLIK ister (`double.infinity`).
  /// ⚠️ YAPMA: akis icin ayri bir `AnketKarti` yazma.
  final double enGenis;

  /// ⚠️⚠️ TURU 104 — **SORU IKI KEZ YAZILMASIN.**
  ///
  ///	Akista anket sorusu cogu zaman gonderinin METNIDIR (Threads/X de
  ///	boyle kullanilir). Ikisi de cizilince ayni cumle ust uste iki kez
  ///	gorunuyordu (emulatorde olculdu). Kart, sorunun gonderi metniyle
  ///	ayni olup olmadigini BILEMEZ; karari cagiran verir.
  /// ⚠️ Sohbette DAIMA true (balonun ustunde metin yok).
  final bool soruGoster;

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
    // ⚠️⚠️ BIRLESTIRILEREK uygulanir, ATANMAZ: gelen govde WS yayinindan
    //    turemis olabilir ve o govde ORTAKTIR (`mine` her secenekte false).
    //    Dogrudan atansaydi baska biri oy verdiginde KULLANICININ KENDI OYU
    //    ekrandan SILINIRDI. `benim` secimleri YEREL gercektir.
    if (widget.anket.seq > _a.seq) _a = _a.yayinlaBirlestir(widget.anket);
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
    final oyVerdim = _a.secenekler.any((x) => x.benim);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: widget.enGenis),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- BASLIK SATIRI
            Row(
              children: [
                // ⚠️ TURU 104 — ikon `chartBar` -> **`vote`** (kullanici emri:
                //    *"ikonu degistirelim"*). Cubuk grafigi bir ISTATISTIK
                //    isaretidir; anket bir SECIMDIR. Ikonun `lucide_icons_flutter`
                //    3.1.14'te VAR OLDUGU kaynaktan dogrulandi.
                Icon(LucideIcons.vote, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                // ⚠️⚠️⚠️ TURU 113 (denetim, SEVK ENGELI) — **BASLIK SATIRI
                //	SOHBET BALONUNDA TASIYORDU.**
                //
                //	Iki `Text` de CIPLAKTI; `Spacer` esnek olmayan cocuklara
                //	SINIRSIZ genislik verdirir, metin ne sarar ne kisalir ve
                //	satir tasar. En kotu hal anketin ILK ACILDIGI an
                //	("Anket · çoklu seçim" + "Henüz oy yok"):
                //	  gereken 260.7 dp · balon ici 360 dp'de 230.8 dp
                //	  -> **29.9 dp TASMA** (411 dp'de bile 10.7 dp).
                //	Akis varyanti (`enGenis: infinity`) etkilenmiyordu, yani
                //	hata YALNIZ sohbette gorunuyordu.
                // ⚠️ `Expanded` + `ellipsis`: etiket kisalir, oy sayisi
                //    DAIMA tam gorunur (asil bilgi odur).
                // ⚠️ YAPMA: `Spacer` + ciplak `Text` ikilisine donme.
                Expanded(
                  child: Text(
                    _a.kapali
                        ? 'Anket bitti'
                        : (_a.coklu ? 'Anket · çoklu seçim' : 'Anket'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _a.toplamOy == 0 ? 'Henüz oy yok' : '${_a.toplamOy} oy',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            if (widget.soruGoster) ...[
              const SizedBox(height: 8),
              Text(
                _a.soru,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final s in _a.secenekler) ...[
              _secenek(s, scheme),
              const SizedBox(height: 8),
            ],
            // ---- ALT SATIR
            SizedBox(
              height: 26,
              child: Row(
                children: [
                  Text(
                    _a.kapali
                        ? 'Oylama kapandı'
                        : (oyVerdim ? 'Oyun kaydedildi' : 'Bir seçenek seç'),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const Spacer(),
                  // ⚠️ "Bitir" YALNIZ olusturana ve YALNIZ acik ankette. Sunucu
                  //    da ayni kapiyi uyguluyor (403) — burasi ARAYUZ, yetki orada.
                  if (!_a.kapali && widget.benimMi)
                    TextButton(
                      onPressed: _kapat,
                      // ⚠️⚠️ TURU 113 (denetim) — dokunma hedefi **20.3 dp**
                      //	idi (`shrinkWrap` Material'in 48 dp'lik hedefini
                      //	kapatiyor). "Anketi bitir" **GERI ALINAMAZ** bir
                      //	eylem; kucuk hedefte yanlislikla basilmasi da,
                      //	basamamak da kotu. Yukseklik 26 -> 44.
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text(
                        'Anketi bitir',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tek secenek satiri.
  ///
  /// ⚠️⚠️ Dolgu cubugu **`LinearProgressIndicator` DEGIL**: o bilesen yeni
  ///	degeri ANINDA uygular, yani oy verilince cubuk ZIPLAR.
  ///	`TweenAnimationBuilder` ile 320 ms'de akar — kullanici kendi oyunun
  ///	sonucu DEGISTIRDIGINI gorur.
  /// ⚠️ Yuzde METIN olarak da yazilir: dolgu uzunlugu TEK BASINA bilgi
  ///    tasimaz (renk korlugu / dusuk gorme).
  /// ⚠️ Satir yuksekligi **SABIT 46 dp**: oy verince ikon ve yazi kalinligi
  ///    degisiyor; esnek yukseklikte butun liste ZIPLARDI.
  Widget _secenek(AnketSecenek s, ColorScheme scheme) {
    final oran = _a.oran(s).clamp(0.0, 1.0);
    final yuzde = (oran * 100).round();
    final secili = s.benim;
    return GestureDetector(
      // ⚠️ Kapali ankette dokunus OLU: `_oyVer` zaten `_a.kapali`
      //    kapisiyla donuyor ama dokunma dalgasi (ripple) cizilince
      //    kullanici "oy verdim" saniyordu.
      onTap: _a.kapali ? null : () => _oyVer(s),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            // ---- ZEMIN
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.onSurface.withValues(alpha: 0.05),
                  border: Border.all(
                    color: secili
                        ? scheme.primary.withValues(alpha: 0.55)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // ---- DOLGU (oran)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: oran),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: v,
                    child: ColoredBox(
                      color: scheme.primary.withValues(
                        alpha: secili ? 0.26 : 0.13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ---- ICERIK
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    // ⚠️⚠️ **SECIM TURU SEKILDEN ANLASILIR**: tek secimlik
                    //    DAIRE, coklu secimlik KARE (sistem genelindeki
                    //    radyo/onay kutusu dili). Baslikta yazan
                    //    "coklu secim" tek basina yeterli degil.
                    Icon(
                      _a.coklu
                          ? (secili
                                ? LucideIcons.squareCheck
                                : LucideIcons.square)
                          : (secili
                                ? LucideIcons.circleCheckBig
                                : LucideIcons.circle),
                      size: 18,
                      color: secili
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.metin,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: secili
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    // ⚠️⚠️ **HIC OY YOKKEN "%0" YAZILMAZ**: sifir bir sonuc
                    //    DEGILDIR, sonucun HENUZ OLMADIGI anlamina gelir.
                    //    Oy oncesi satirlar dogal olarak duz secim
                    //    dugmesine duser.
                    if (_a.toplamOy > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '%$yuzde',
                        // ⚠️ **KONTRAST OLCULDU**: eski hal secili satirda
                        //    `primary` kullaniyordu ve acik temada 3.94:1
                        //    cikiyordu (esik 4.5). Secili durum ZATEN
                        //    kalinlik + cerceve + dolgu ile anlatiliyor;
                        //    yuzde metni her durumda `onSurface`.
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
