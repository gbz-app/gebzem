import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'auth_provider.dart';

/// Dogrulama ekrani — iki mod:
/// - Gercek SMS (Firebase): [verificationId] dolu gelir, kod telefona gelir
/// - Test modu: [devOtp] dolu gelir, kod otomatik doldurulur
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.devOtp,
    this.verificationId,
    this.password = '',
    this.name = '',
    this.username = '',
  });

  final String phone;
  final String? devOtp;
  final String? verificationId;
  final String password;
  final String name;
  final String username;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  bool get _realSms => widget.verificationId != null;

  @override
  void initState() {
    super.initState();
    // Test modunda kodu otomatik doldur (prototip kolayligi)
    if (widget.devOtp != null) _code.text = widget.devOtp!;
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('6 haneli kodu girin')));
      return;
    }
    setState(() => _loading = true);
    try {
      if (_realSms) {
        await ref.read(authProvider.notifier).confirmSms(
              verificationId: widget.verificationId!,
              code: code,
              password: widget.password,
              name: widget.name,
              username: widget.username,
            );
      } else {
        await ref.read(authProvider.notifier).verify(widget.phone, code);
      }
      // basarili — router redirect ana ekrana atar
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('invalid-verification-code')
            ? 'Kod hatali'
            : apiErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dogrulama')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _realSms
                    ? '${widget.phone} numarasina SMS ile 6 haneli kod gonderdik'
                    : '${widget.phone} numarasi icin 6 haneli kodu girin',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (widget.devOtp != null) ...[
                const SizedBox(height: 8),
                Text('(Test modu — kod otomatik dolduruldu: ${widget.devOtp})',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ],
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: _realSms,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                  hintText: '______',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: _loading
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Dogrula'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
