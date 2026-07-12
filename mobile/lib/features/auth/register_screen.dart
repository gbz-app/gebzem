import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController(text: '+90');
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final phone = _phone.text.trim();
    final username = _username.text.trim().toLowerCase();
    final name = _name.text.trim();

    try {
      // 1) Kullanici adi/numara musait mi + (test modunda) kod uret
      final devOtp = await ref
          .read(authProvider.notifier)
          .register(phone, _password.text, name, username);

      if (useRealSms) {
        // 2) GERCEK SMS: Firebase telefona kod gonderir
        await ref.read(authProvider.notifier).sendSms(
          phone,
          onCodeSent: (verificationId) {
            if (!mounted) return;
            setState(() => _loading = false);
            context.push('/otp', extra: {
              'phone': phone,
              'verification_id': verificationId,
              'password': _password.text,
              'name': name,
              'username': username,
            });
          },
          onError: (msg) {
            if (!mounted) return;
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
          },
        );
        return; // yonlendirmeyi onCodeSent yapar
      }

      // Test modu: kod ekranda otomatik dolar
      if (mounted) {
        context.push('/otp', extra: {'phone': phone, 'dev_otp': devOtp});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted && !useRealSms) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayit Ol')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Adiniz',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Adinizi girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Kullanici adi',
                    hintText: 'ornek: mikail_s',
                    helperText: 'Arkadaslarin seni bu adla bulacak',
                    prefixText: '@',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.atSign),
                  ),
                  validator: (v) {
                    final u = (v ?? '').trim().toLowerCase();
                    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) {
                      return '3-20 karakter: harf, rakam, alt cizgi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefon numarasi',
                    hintText: '+905xxxxxxxxx',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(LucideIcons.phone),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 12) ? 'Gecerli numara girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  decoration: InputDecoration(
                    labelText: 'Sifre',
                    helperText: 'En az 6 karakter',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(LucideIcons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword ? LucideIcons.eye : LucideIcons.eyeOff),
                      onPressed: () => setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Sifre en az 6 karakter' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _loading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Devam Et — SMS Kodu Gonder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
