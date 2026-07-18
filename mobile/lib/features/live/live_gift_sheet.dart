import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../home/home_screen.dart' show myProfileProvider;
import 'live_provider.dart';

/// Hediye sheet'i: bakiye + katalog (SUNUCUDAN — fiyat UI'da sabit degil) + gonder.
/// Animasyon ISTEMCIDEN TETIKLENMEZ: herkese (gonderen dahil) sunucu SendData'siyla gelir.
class LiveGiftSheet extends ConsumerStatefulWidget {
  const LiveGiftSheet({super.key, required this.streamId});
  final String streamId;

  @override
  ConsumerState<LiveGiftSheet> createState() => _LiveGiftSheetState();
}

class _LiveGiftSheetState extends ConsumerState<LiveGiftSheet> {
  bool _gonderiliyor = false;

  Future<void> _gonder(Map<String, dynamic> g) async {
    if (_gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    try {
      final idem =
          '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(this)}';
      await ref.read(liveApiProvider).hediye(widget.streamId, g['id'] as String, idem);
      ref.invalidate(myProfileProvider); // bakiye tazelensin
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final katalog = ref.watch(giftKatalogProvider);
    final profil = ref.watch(myProfileProvider);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('Hediye gönder', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          const Icon(LucideIcons.coins, size: 18, color: Colors.amber),
          const SizedBox(width: 4),
          Text('${profil.valueOrNull?['coin_balance'] ?? '...'} jeton',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),
        katalog.when(
          loading: () => const Padding(
              padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
          error: (_, _) => const Text('Katalog yüklenemedi'),
          data: (list) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final g in list)
                InkWell(
                  onTap: _gonderiliyor ? null : () => _gonder(g),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Column(children: [
                      Text(g['emoji'] as String? ?? '🎁',
                          style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 6),
                      Text(g['ad'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${g['jeton']} jeton',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}
