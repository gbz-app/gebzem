import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';

/// DAVET KISI SECIM sheet'i (Bolum 5 I2): arama + coklu secim (max 10);
/// "Davet gonder (n)" -> Navigator.pop(secilenIdListesi). GONDERIMI ARAYAN EKRAN yapar
/// (sheet API bilmez — yayin ve oda ayni sheet'i kullanir).
class DavetSecSheet extends ConsumerStatefulWidget {
  const DavetSecSheet({super.key});

  @override
  ConsumerState<DavetSecSheet> createState() => _DavetSecSheetState();
}

class _DavetSecSheetState extends ConsumerState<DavetSecSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Map<String, String> _secili = {}; // id -> ad
  bool _loading = false;

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
    _debounce = Timer(const Duration(milliseconds: 350), () => _ara(v.trim()));
  }

  Future<void> _ara(String q) async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiProvider).get('/users/search', queryParameters: {'q': q});
      if (!mounted) return;
      setState(() => _results = (res.data as List).cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Davet et', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _query,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Kişi ara (isim veya @kullanıcıadı)',
              prefixIcon: const Icon(LucideIcons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_secili.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final e in _secili.entries)
                    Chip(
                        label: Text(e.value),
                        onDeleted: () => setState(() => _secili.remove(e.key))),
                ],
              ),
            ),
          SizedBox(
            height: 260,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final u = _results[i];
                      final id = u['id'] as String;
                      return CheckboxListTile(
                        value: _secili.containsKey(id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            if (_secili.length >= 10) return; // sunucu siniri
                            _secili[id] = u['name'] as String? ?? '';
                          } else {
                            _secili.remove(id);
                          }
                        }),
                        title: Text(u['name'] as String? ?? ''),
                        subtitle: Text('@${u['username'] ?? ''}'),
                      );
                    },
                  ),
          ),
          FilledButton.icon(
            onPressed: _secili.isEmpty
                ? null
                : () => Navigator.of(context).pop(_secili.keys.toList()),
            icon: const Icon(LucideIcons.send),
            label: Text('Davet gönder (${_secili.length})'),
          ),
        ],
      ),
    );
  }
}
