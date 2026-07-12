import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart';
import 'call_provider.dart';
import 'call_screen.dart';
import 'call_sounds.dart';

/// Gelen arama ekrani — uygulama acikken her ekranin uzerinde belirir.
/// (Kilit ekraninda calma/CallKit sonraki asamada eklenecek.)
class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(callServiceProvider);

    return Stack(
      children: [
        child,
        if (incoming != null)
          Positioned.fill(
            child: _IncomingCallSheet(call: incoming),
          ),
      ],
    );
  }
}

class _IncomingCallSheet extends ConsumerStatefulWidget {
  const _IncomingCallSheet({required this.call});

  final IncomingCall call;

  @override
  ConsumerState<_IncomingCallSheet> createState() => _IncomingCallSheetState();
}

class _IncomingCallSheetState extends ConsumerState<_IncomingCallSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Zil + titresim. Bu sirada LiveKit odasina HENUZ baglanmadigimiz icin
    // ses oturumu bos — zil serbestce calar (iOS'ta LiveKit onu susturmaz).
    CallSounds.gelenArama();
  }

  @override
  void dispose() {
    CallSounds.durdur(); // ekran her kapandiginda zil MUTLAKA sussun
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    await CallSounds.durdur(); // once zili kes, sonra odaya gir

    // Bu widget Navigator'in DISINDA yasar (MaterialApp.builder), bu yuzden
    // Navigator.of(context) kullanilamaz — kok Navigator anahtarini kullaniyoruz.
    final notifier = ref.read(callServiceProvider.notifier);
    try {
      final info = await notifier.answer(widget.call.callId);

      final nav = rootNavigatorKey.currentState;
      if (nav == null) throw Exception('navigator hazir degil');

      // await ETME: push, sayfa kapanana kadar bekler; ekrani hemen acmaliyiz.
      unawaited(nav.push(MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: widget.call.callId,
          url: info['url'] as String,
          token: info['token'] as String,
          video: widget.call.video,
          peerName: widget.call.callerName,
          outgoing: false,
        ),
      )));
      notifier.dismiss(); // arama ekrani acildiktan SONRA gelen arama ekranini kaldir
    } catch (e) {
      rootMessengerKey.currentState
          ?.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      notifier.dismiss();
      await notifier.end(widget.call.callId); // arayan sonsuza kadar beklemesin
    }
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    await CallSounds.durdur();
    await ref.read(callServiceProvider.notifier).end(widget.call.callId);
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    return Material(
      color: const Color(0xFF0B141A),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            CircleAvatar(
              radius: 56,
              backgroundColor: Colors.white24,
              backgroundImage:
                  call.callerAvatar.isNotEmpty ? NetworkImage(call.callerAvatar) : null,
              child: call.callerAvatar.isEmpty
                  ? Text(
                      call.callerName.isNotEmpty ? call.callerName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 44, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(call.callerName,
                style: const TextStyle(
                    color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(call.video ? 'Goruntulu arama' : 'Sesli arama',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Spacer(flex: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bigButton(
                  color: const Color(0xFFE53935),
                  icon: LucideIcons.phoneOff,
                  label: 'Reddet',
                  onTap: _reject,
                ),
                _bigButton(
                  color: const Color(0xFF25D366),
                  icon: call.video ? LucideIcons.video : LucideIcons.phone,
                  label: 'Kabul et',
                  onTap: _accept,
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _bigButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _busy ? null : onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
