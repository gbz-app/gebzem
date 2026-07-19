import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'live_provider.dart';

/// YAYIN BILGI SHEET'LERI (Bolum 6 I2): izleyiciler + hediye leaderboard + katil istekleri.
/// Hepsi REST'ten okur (SendData degil) — sheet acikken guncel liste, kapaliyken maliyet yok.

Widget _avatarBas(String? ad) => CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFF6C2BD9),
      child: Text((ad ?? '?').isNotEmpty ? ad![0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white)),
    );

/// IZLEYICILER — yayinciysa "Canliya al" (konuk yap) + "At" aksiyonlari.
class IzleyicilerSheet extends ConsumerStatefulWidget {
  const IzleyicilerSheet(
      {super.key, required this.streamId, required this.yayinciyim});

  final String streamId;
  final bool yayinciyim;

  @override
  ConsumerState<IzleyicilerSheet> createState() => _IzleyicilerSheetState();
}

class _IzleyicilerSheetState extends ConsumerState<IzleyicilerSheet> {
  List<Map<String, dynamic>>? _liste;
  int _toplam = 0;
  String? _hata;
  bool _isleniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final r = await ref.read(liveApiProvider).izleyiciler(widget.streamId);
      if (!mounted) return;
      setState(() {
        _toplam = (r['total'] as num?)?.toInt() ?? 0;
        _liste = ((r['viewers'] as List?) ?? const [])
            .cast<Map<String, dynamic>>();
        _hata = null;
      });
    } catch (e) {
      if (mounted) setState(() => _hata = apiErrorMessage(e));
    }
  }

  Future<void> _aksiyon(Future<void> Function() f) async {
    if (_isleniyor) return;
    setState(() => _isleniyor = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isleniyor = false);
        _yukle();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(LucideIcons.eye, size: 20),
              const SizedBox(width: 8),
              Text('İzleyiciler ($_toplam)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  onPressed: _yukle, icon: const Icon(LucideIcons.refreshCw, size: 18)),
            ]),
          ),
          if (_hata != null)
            Expanded(child: Center(child: Text(_hata!)))
          else if (liste == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (liste.isEmpty)
            const Expanded(child: Center(child: Text('Henüz izleyici yok')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final u = liste[i];
                  final uid = u['user_id'] as String? ?? '';
                  final konuk = u['is_guest'] == true;
                  return ListTile(
                    leading: _avatarBas(u['name'] as String?),
                    title: Text(u['name'] as String? ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: konuk
                        ? const Text('KONUK',
                            style: TextStyle(
                                color: Color(0xFF6C2BD9),
                                fontSize: 11,
                                fontWeight: FontWeight.w700))
                        : null,
                    trailing: !widget.yayinciyim
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            if (konuk)
                              TextButton(
                                onPressed: _isleniyor
                                    ? null
                                    : () => _aksiyon(() => ref
                                        .read(liveApiProvider)
                                        .konukCikar(widget.streamId, uid)),
                                child: const Text('Yayından al'),
                              )
                            else
                              TextButton(
                                onPressed: _isleniyor
                                    ? null
                                    : () => _aksiyon(() => ref
                                        .read(liveApiProvider)
                                        .konukAl(widget.streamId, uid)),
                                child: const Text('Canlıya al'),
                              ),
                            IconButton(
                              tooltip: 'Yayından at',
                              icon: const Icon(LucideIcons.userX,
                                  size: 18, color: Colors.redAccent),
                              onPressed: _isleniyor
                                  ? null
                                  : () => _aksiyon(() => ref
                                      .read(liveApiProvider)
                                      .kick(widget.streamId, uid)),
                            ),
                          ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// HEDIYE LEADERBOARD — gonderene gore toplanmis, ExpansionTile ile kirilim
/// (kim hangi hediyeden kac defa). Emoji/ad SUNUCU katalogundan gelir.
class HediyeLeaderboardSheet extends ConsumerStatefulWidget {
  const HediyeLeaderboardSheet({super.key, required this.streamId});

  final String streamId;

  @override
  ConsumerState<HediyeLeaderboardSheet> createState() =>
      _HediyeLeaderboardSheetState();
}

class _HediyeLeaderboardSheetState
    extends ConsumerState<HediyeLeaderboardSheet> {
  List<Map<String, dynamic>>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final r = await ref.read(liveApiProvider).hediyeListesi(widget.streamId);
      if (mounted) setState(() => _liste = r);
    } catch (e) {
      if (mounted) setState(() => _hata = apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Icon(LucideIcons.gift, size: 20, color: Colors.amber),
              SizedBox(width: 8),
              Text('Hediye gönderenler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (_hata != null)
            Expanded(child: Center(child: Text(_hata!)))
          else if (liste == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (liste.isEmpty)
            const Expanded(
                child: Center(child: Text('Henüz hediye gönderilmedi')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final g = liste[i];
                  final kirilim = ((g['gifts'] as List?) ?? const [])
                      .cast<Map<String, dynamic>>();
                  return ExpansionTile(
                    leading: _avatarBas(g['name'] as String?),
                    title: Text(g['name'] as String? ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text('🪙 ${g['total'] ?? 0}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    children: [
                      for (final k in kirilim)
                        ListTile(
                          dense: true,
                          leading: Text(k['emoji'] as String? ?? '🎁',
                              style: const TextStyle(fontSize: 20)),
                          title: Text(k['ad'] as String? ?? ''),
                          trailing: Text(
                              '×${k['adet'] ?? 0} · ${k['coins'] ?? 0} jeton'),
                        ),
                    ],
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

/// KATIL ISTEKLERI — yalniz yayinci: bekleyen istekler; Kabul -> konuk al, Reddet.
class IstekSheet extends ConsumerStatefulWidget {
  const IstekSheet({super.key, required this.streamId});

  final String streamId;

  @override
  ConsumerState<IstekSheet> createState() => _IstekSheetState();
}

class _IstekSheetState extends ConsumerState<IstekSheet> {
  List<Map<String, dynamic>>? _liste;
  String? _hata;
  bool _isleniyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final r = await ref.read(liveApiProvider).istekler(widget.streamId);
      if (mounted) {
        setState(() {
          _liste = r;
          _hata = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hata = apiErrorMessage(e));
    }
  }

  Future<void> _aksiyon(Future<void> Function() f, {bool kapat = false}) async {
    if (_isleniyor) return;
    setState(() => _isleniyor = true);
    try {
      await f();
      if (kapat && mounted) {
        Navigator.of(context).pop();
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isleniyor = false);
        _yukle();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = _liste;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(LucideIcons.hand, size: 20),
              const SizedBox(width: 8),
              const Text('Katılma istekleri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  onPressed: _yukle, icon: const Icon(LucideIcons.refreshCw, size: 18)),
            ]),
          ),
          if (_hata != null)
            Expanded(child: Center(child: Text(_hata!)))
          else if (liste == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (liste.isEmpty)
            const Expanded(child: Center(child: Text('Bekleyen istek yok')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: liste.length,
                itemBuilder: (context, i) {
                  final u = liste[i];
                  final uid = u['user_id'] as String? ?? '';
                  return ListTile(
                    leading: _avatarBas(u['name'] as String?),
                    title: Text(u['name'] as String? ?? '',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      FilledButton(
                        onPressed: _isleniyor
                            ? null
                            // Kabul basarili -> sheet kapanir (konuk PiP ekranda gorunur)
                            : () => _aksiyon(
                                () => ref
                                    .read(liveApiProvider)
                                    .konukAl(widget.streamId, uid),
                                kapat: true),
                        child: const Text('Canlıya al'),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.redAccent),
                        onPressed: _isleniyor
                            ? null
                            : () => _aksiyon(() => ref
                                .read(liveApiProvider)
                                .konukReddet(widget.streamId, uid)),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}
