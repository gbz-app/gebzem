import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../medya/medya_gorsel.dart';

/// TURU 74 — ENGELLENEN KİŞİLER.
///
/// ⚠️ App Store Review Guideline 1.2 (UGC) engellemeyi şart koşuyor; engellemek
///     kadar **engeli görebilmek ve kaldırabilmek** de gerekli. Sohbet ekranından
///     engellenen biriyle bir daha o sohbete girmeden engeli kaldırmanın yolu
///     olmalı.
class EngellenenlerEkrani extends ConsumerStatefulWidget {
  const EngellenenlerEkrani({super.key});

  @override
  ConsumerState<EngellenenlerEkrani> createState() =>
      _EngellenenlerEkraniState();
}

class _EngellenenlerEkraniState extends ConsumerState<EngellenenlerEkrani> {
  List<Map<String, dynamic>>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final res = await ref.read(apiProvider).get('/users/me/blocks');
      final l = ((res.data as List?) ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      if (mounted) setState(() => _liste = l);
    } catch (e) {
      if (mounted) setState(() => _hata = apiErrorMessage(e));
    }
  }

  Future<void> _kaldir(Map<String, dynamic> k) async {
    try {
      await ref.read(apiProvider).delete('/users/${k['id']}/block');
      if (mounted) {
        setState(() => _liste?.removeWhere((x) => x['id'] == k['id']));
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('${k['name']} için engel kaldırıldı')),
        );
      }
    } catch (e) {
      if (mounted) {
        rootMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget govde;
    if (_hata != null) {
      govde = Center(child: Text(_hata!));
    } else if (_liste == null) {
      govde = const Center(child: CircularProgressIndicator());
    } else if (_liste!.isEmpty) {
      govde = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Engellediğiniz kimse yok.', textAlign: TextAlign.center),
        ),
      );
    } else {
      govde = ListView.separated(
        itemCount: _liste!.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final k = _liste![i];
          return ListTile(
            leading: Avatar(
              ad: k['name'] as String? ?? '',
              // ⚠️ TURU 74b: `avatar_media_id` verilmiyordu -> liste DAIMA harf
              //    avatari gosteriyordu (avatar_url artik eski alan).
              mediaId: k['avatar_media_id'] as String?,
              avatarUrl: k['avatar_url'] as String? ?? '',
              cap: 40,
            ),
            title: Text(k['name'] as String? ?? ''),
            subtitle: Text('@${k['username'] ?? ''}'),
            trailing: TextButton(
              onPressed: () => _kaldir(k),
              child: const Text('Engeli kaldır'),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Engellenen kişiler')),
      body: govde,
    );
  }
}
