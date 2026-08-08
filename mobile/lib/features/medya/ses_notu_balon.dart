import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'medya_kapisi.dart';
import 'medya_servisi.dart';
import 'ses_notu_kontrol.dart';

/// ⚠️⚠️ TURU 74 — SES NOTU BALONU (dalga formu + oynat/durdur + hız).
///
/// ⚠️ **OYNATMA DA SERT KAPIYA TABİ:** aktif arama/oda/yayın varken ses notu
///     ÇALMAZ. `audioplayers` iOS'ta ses bağlamını **GLOBAL** uygular; çalarsa
///     görüşmenin sesi bozulur.
///
/// ⚠️ **AYRI `playerId`** (`gebzem_sesnotu`): `CallSounds` kendi oynatıcısını
///     kullanır (zil/çalma tonu). Aynı id paylaşılsaydı ses notu çalmak zili
///     durdururdu.
///
/// ⚠️ **iOS'ta `setAudioContext` ÇAĞRILMAZ** — bağlam PROSES GENELİDİR ve
///     `call_sounds.dart` da bu yüzden yalnız Android'de çağırıyor. iOS'ta
///     çağırmak süren aramanın oturumunu yeniden yapılandırırdı.
class SesNotuBalon extends ConsumerStatefulWidget {
  const SesNotuBalon({
    super.key,
    required this.mediaId,
    required this.sureMs,
    required this.dalga,
    required this.benimMi,
  });

  final String mediaId;
  final int sureMs;
  final String dalga; // "12,40,88,..." (60 kova)
  final bool benimMi;

  @override
  ConsumerState<SesNotuBalon> createState() => _SesNotuBalonState();
}

class _SesNotuBalonState extends ConsumerState<SesNotuBalon> {
  static final _oynatici = AudioPlayer(playerId: 'gebzem_sesnotu');

  /// ⚠️ Aynı anda TEK ses notu çalar. Başka balon başlarsa bu durur.
  static String? _calanId;

  StreamSubscription<Duration>? _konumSub;
  StreamSubscription<void>? _bittiSub;
  bool _caliyor = false;
  Duration _konum = Duration.zero;
  double _hiz = 1.0;

  @override
  void dispose() {
    _konumSub?.cancel();
    _bittiSub?.cancel();
    if (_calanId == widget.mediaId) {
      _oynatici.stop();
      _calanId = null;
      SesNotuKontrol.kapat();
    }
    super.dispose();
  }

  Future<void> _oynatDurdur() async {
    if (_caliyor) {
      await _oynatici.pause();
      setState(() => _caliyor = false);
      SesNotuKontrol.birak();
      return;
    }
    // ⚠️ SERT KAPI — sınıf şerhi. Aksiyon yolunda (yan etkili kontrol serbest).
    if (!MedyaKapisi.izinVer(ref)) return;

    try {
      // Başka bir ses notu çalıyorsa durdur (tek slot).
      if (_calanId != null && _calanId != widget.mediaId) {
        await _oynatici.stop();
      }
      final d = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      final url = d['url'] as String?;
      if (url == null) return;

      // ⚠️ "ARAMA KAZANIR": arama kurulurken oynatma DURUR.
      //    ⚠️ `SesSahipligi`e YAZILMAZ (bkz. ses_notu_kontrol.dart şerhi).
      SesNotuKontrol.kaydol(() async {
        await _oynatici.stop();
        if (mounted) setState(() => _caliyor = false);
        _calanId = null;
      });

      await _oynatici.play(UrlSource(url));
      await _oynatici.setPlaybackRate(_hiz);
      _calanId = widget.mediaId;
      _konumSub?.cancel();
      _konumSub = _oynatici.onPositionChanged.listen((p) {
        if (mounted) setState(() => _konum = p);
      });
      _bittiSub?.cancel();
      _bittiSub = _oynatici.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _caliyor = false;
            _konum = Duration.zero;
          });
        }
        _calanId = null;
        SesNotuKontrol.birak();
      });
      if (mounted) setState(() => _caliyor = true);
    } catch (_) {
      if (mounted) setState(() => _caliyor = false);
      SesNotuKontrol.birak();
    }
  }

  Future<void> _hizDegistir() async {
    // ⚠️ 1x -> 1.5x -> 2x -> 1x döngüsü (WhatsApp deseni).
    final yeni = _hiz == 1.0 ? 1.5 : (_hiz == 1.5 ? 2.0 : 1.0);
    setState(() => _hiz = yeni);
    if (_caliyor) await _oynatici.setPlaybackRate(yeni);
  }

  List<int> get _kovalar {
    if (widget.dalga.isEmpty) return List.filled(30, 30);
    final p = widget.dalga
        .split(',')
        .map((x) => int.tryParse(x) ?? 0)
        .where((x) => x >= 0)
        .toList();
    return p.isEmpty ? List.filled(30, 30) : p;
  }

  String _sure(Duration d) {
    final sn = d.inSeconds;
    return '${(sn ~/ 60).toString().padLeft(2, '0')}:'
        '${(sn % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final kovalar = _kovalar;
    final toplam = Duration(milliseconds: widget.sureMs);
    final oran = widget.sureMs == 0
        ? 0.0
        : (_konum.inMilliseconds / widget.sureMs).clamp(0.0, 1.0);
    final aktifRenk =
        widget.benimMi ? const Color(0xFF0B7C4B) : const Color(0xFF7C4DFF);

    return SizedBox(
      width: 230,
      child: Row(children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(_caliyor ? LucideIcons.pause : LucideIcons.play, size: 22),
          onPressed: _oynatDurdur,
        ),
        Expanded(
          child: SizedBox(
            height: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < kovalar.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0.5),
                      child: Container(
                        // ⚠️ En az 3px: sessiz anlar tamamen kaybolmasın.
                        height: 3 + kovalar[i] / 99 * 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i / kovalar.length <= oran
                              ? aktifRenk
                              : aktifRenk.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(_sure(_caliyor ? _konum : toplam),
            style: const TextStyle(fontSize: 11.5)),
        if (_caliyor || _hiz != 1.0)
          GestureDetector(
            onTap: _hizDegistir,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('${_hiz == 1.0 ? '1' : _hiz.toString()}x',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: aktifRenk)),
            ),
          ),
      ]),
    );
  }
}
