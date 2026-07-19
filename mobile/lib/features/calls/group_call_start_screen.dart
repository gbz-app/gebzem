import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'active_call_controller.dart';
import 'call_provider.dart';

/// Grup aramasi baslat (sesli VEYA goruntulu): kisileri ara, coklu sec -> startGroup.
/// Kalici grup sohbeti gerekmez (anlik grup, backend member_ids yolu).
class GroupCallStartScreen extends ConsumerStatefulWidget {
  const GroupCallStartScreen({super.key});

  @override
  ConsumerState<GroupCallStartScreen> createState() => _GroupCallStartScreenState();
}

class _GroupCallStartScreenState extends ConsumerState<GroupCallStartScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Map<String, Map<String, dynamic>> _selected = {}; // id -> kullanici
  bool _loading = false;
  bool _starting = false;

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiProvider).get('/users/search', queryParameters: {'q': q});
      if (!mounted) return;
      setState(() => _results = (res.data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // sessiz gec
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Map<String, dynamic> u) {
    final id = u['id'] as String;
    setState(() {
      if (_selected.containsKey(id)) {
        _selected.remove(id);
      } else {
        _selected[id] = u;
      }
    });
  }

  Future<void> _basla({required bool video}) async {
    if (_selected.isEmpty || _starting) return;
    setState(() => _starting = true);
    final svc = ref.read(callServiceProvider.notifier);
    try {
      final info = await svc.startGroup(_selected.keys.toList(), video: video);
      if (!mounted) return;
      // FAZ-C: mantik controller'da. ONCE baslatma ekranini kapat, SONRA arama ekranini ac
      // (ters sira ekraniAc'in push'unu pop ile geri alirdi — pushReplacement dengi).
      final ctrl = ref.read(activeCallProvider);
      await ctrl.baslat(AramaBilgisi(
        callId: info['call_id'] as String,
        url: info['url'] as String,
        token: info['token'] as String,
        video: video,
        peerName: 'Grup araması',
        outgoing: true,
        isGroup: true,
        chatTitle: 'Grup araması',
      ));
      if (!mounted) return;
      Navigator.of(context).pop();
      ctrl.ekraniAc();
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grup araması')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Kişi ara (isim veya @kullanıcıadı)',
                prefixIcon: const Icon(LucideIcons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final u in _selected.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(u['name'] as String? ?? ''),
                        onDeleted: () => _toggle(u),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final u = _results[i];
                      final id = u['id'] as String;
                      final secili = _selected.containsKey(id);
                      final avatar = (u['avatar_url'] as String?) ?? '';
                      return CheckboxListTile(
                        value: secili,
                        onChanged: (_) => _toggle(u),
                        secondary: CircleAvatar(
                          backgroundImage:
                              avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? const Icon(LucideIcons.user)
                              : null,
                        ),
                        title: Text(u['name'] as String? ?? ''),
                        subtitle: Text('@${u['username'] ?? ''}'),
                      );
                    },
                  ),
          ),
        ],
      ),
      // SESLI / GORUNTULU secimi (grup goruntulu fazi). Goruntulu backend'de 8 kisiyle
      // sinirli (asilirsa net Turkce hata mesaji doner, snackbar'da gorunur).
      floatingActionButton: _selected.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'grupGoruntulu',
                  onPressed: _starting ? null : () => _basla(video: true),
                  icon: _starting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.video),
                  label: Text('Görüntülü (${_selected.length})'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'grupSesli',
                  onPressed: _starting ? null : () => _basla(video: false),
                  icon: _starting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.phone),
                  label: Text('Sesli (${_selected.length})'),
                ),
              ],
            ),
    );
  }
}
