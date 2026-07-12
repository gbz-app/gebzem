import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'chats_provider.dart';

/// Kisi arama: isim veya @kullaniciadi ile ara, sohbet baslat
class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _searched = false;
        _error = null;
      });
      return;
    }
    // her tusa basista degil, yazma bitince ara
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/users/search', queryParameters: {'q': q});
      if (!mounted) return;
      setState(() {
        _results = (res.data as List).cast<Map<String, dynamic>>();
        _searched = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    try {
      final chat = await ref
          .read(apiProvider)
          .post('/chats/direct', data: {'user_id': user['id']});
      ref.read(chatsProvider.notifier).load();
      if (mounted) {
        context.pop(); // arama ekranini kapat
        context.push('/chat/${chat.data['chat_id']}',
            extra: {'title': user['name'] ?? user['username']});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Isim veya @kullaniciadi ara',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_error != null) {
      return Center(child: Text(_error!, textAlign: TextAlign.center));
    }
    if (_query.text.trim().length < 2) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.search, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text('Arkadaslarini isim ya da\n@kullaniciadi ile bul',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.outline)),
          ],
        ),
      );
    }
    if (_searched && _results.isEmpty && !_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.userX, size: 56, color: scheme.outline),
            const SizedBox(height: 12),
            Text('Kullanici bulunamadi', style: TextStyle(color: scheme.outline)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final u = _results[i];
        final avatar = (u['avatar_url'] as String?) ?? '';
        return ListTile(
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty ? const Icon(LucideIcons.user) : null,
          ),
          title: Text(u['name'] as String? ?? ''),
          subtitle: Text('@${u['username'] ?? ''}'),
          trailing: FilledButton.tonal(
            onPressed: () => _startChat(u),
            child: const Text('Mesaj'),
          ),
          onTap: () => _startChat(u),
        );
      },
    );
  }
}
