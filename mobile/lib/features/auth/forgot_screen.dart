import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import 'auth_provider.dart';

/// Sifremi unuttum: 1) numara gir, kod iste  2) kod + yeni sifre gir
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});

  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _phone = TextEditingController(text: '+90');
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  bool _loading = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    setState(() => _loading = true);
    try {
      final devOtp = await ref.read(authProvider.notifier).forgot(_phone.text.trim());
      setState(() => _codeSent = true);
      if (devOtp != null) _code.text = devOtp;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(devOtp != null
                ? 'Test modu — kod otomatik dolduruldu'
                : 'Kod gonderildi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (_newPassword.text.length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Yeni sifre en az 6 karakter olmali')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .reset(_phone.text.trim(), _code.text.trim(), _newPassword.text);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sifre guncellendi, giris yapin')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sifremi Unuttum')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                enabled: !_codeSent,
                decoration: const InputDecoration(
                  labelText: 'Telefon numarasi',
                  hintText: '+905xxxxxxxxx',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              if (!_codeSent)
                FilledButton(
                  onPressed: _loading ? null : _requestCode,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Kod Gonder'),
                )
              else ...[
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'SMS kodu',
                    border: OutlineInputBorder(),
                    counterText: '',
                    prefixIcon: Icon(Icons.sms),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _newPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Yeni sifre',
                    helperText: 'En az 6 karakter',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _reset,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sifreyi Yenile'),
                ),
                TextButton(
                  onPressed: _loading ? null : _requestCode,
                  child: const Text('Kodu tekrar gonder'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
