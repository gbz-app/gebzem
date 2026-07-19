import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';

/// ARAMAYA KISI EKLEME sheet'i (Faz-B B6): isim/@kullaniciadi ara, kisiye dokun -> onEkle.
/// Sheet ACIK KALIR (art arda birden fazla kisi eklenebilir). Cagiran ekran _sheetAcik
/// bayragini yonetir (K7: _leave once sheet'i kapatir).
class AddParticipantSheet extends ConsumerStatefulWidget {
  const AddParticipantSheet({super.key, required this.onEkle});

  /// Secilen kisiyi aramaya ekler; hata firlatirsa snackbar burada gosterilir.
  final Future<void> Function(String userId, String name) onEkle;

  @override
  ConsumerState<AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends ConsumerState<AddParticipantSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  final Set<String> _eklenenler = {}; // bu oturumda eklenenler (buton "Eklendi ✓")
  bool _loading = false;
  bool _isleniyor = false;

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

  Future<void> _ekle(Map<String, dynamic> u) async {
    if (_isleniyor) return;
    setState(() => _isleniyor = true);
    final id = u['id'] as String;
    try {
      await widget.onEkle(id, u['name'] as String? ?? '');
      if (mounted) setState(() => _eklenenler.add(id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isleniyor = false);
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
          Text('Aramaya kişi ekle', style: Theme.of(context).textTheme.titleLarge),
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
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final u = _results[i];
                      final id = u['id'] as String;
                      final eklendi = _eklenenler.contains(id);
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(LucideIcons.user)),
                        title: Text(u['name'] as String? ?? ''),
                        subtitle: Text('@${u['username'] ?? ''}'),
                        trailing: eklendi
                            ? const Text('Eklendi ✓',
                                style: TextStyle(color: Colors.green))
                            : FilledButton(
                                onPressed: _isleniyor ? null : () => _ekle(u),
                                child: const Text('Ekle'),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
