import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'auth_provider.dart';

/// Dogrulama ekrani — kodu sunucu uretir:
/// - SMS saglayicisi acikken: kod telefona SMS ile gelir
/// - Test modunda: [devOtp] gelir ve kod otomatik doldurulur
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.devOtp,
  });

  final String phone;
  final String? devOtp;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  /// Kod yanitta gelmediyse gercek SMS gonderilmis demektir
  bool get _realSms => widget.devOtp == null;

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
      await ref.read(authProvider.notifier).verify(widget.phone, code);
      // basarili — router redirect ana ekrana atar
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
