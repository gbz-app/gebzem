import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../router.dart' show rootMessengerKey;
import '../isletme/kategori_kabuk.dart' show YemekHeader;
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import '../sosyal/sosyal_servisi.dart';
import 'chats_provider.dart';
import 'moderasyon_sheet.dart';

/// ⚠️⚠️⚠️ TURU 180z — **KISI BILGISI** (kullanici emri: *"mesajdaki sagdaki
///	3 noktayi sil, direk profile tikladigimiz yerde olsun"* + *"profile
///	tikladiginda bu sekilde olmasi gerekiyor, mantigi biliyorsun zaten
///	Instagram/WhatsApp'tan"*).
///
/// WhatsApp deseni: buyuk avatar · ad · @kullaniciadi · hizli eylemler
/// (Sesli ara · Goruntulu ara · Profil) · ayarlar listesi.
///
/// ⚠️⚠️ **BACKEND DEGISMEDI** — her satir MEVCUT bir uca baglidir:
///	  · profil        -> `GET /users/{id}/profile`
///	  · sessize al    -> `PATCH /chats/{id}` {muted}
///	  · arsivle       -> `PATCH /chats/{id}` {archived}
///	  · sohbeti temizle -> `DELETE /chats/{id}`
///	  · engelle/sikayet -> `moderasyon_sheet` (turu 74 uclari)
/// ⚠️ Karsiligi OLMAYAN hicbir satir CIZILMEDI ("Medya, baglantilar",
///	"Ortak gruplar", "Kaybolan mesajlar" gibi): gorunen ama calismayan
///	dugme turu 66b dersinin tekrari olurdu.
class KisiBilgiEkrani extends ConsumerStatefulWidget {
  const KisiBilgiEkrani({
    super.key,
    required this.chatId,
    required this.peerId,
    required this.baslik,
    this.avatarMediaId,
    this.sesliAra,
    this.goruntuluAra,
  });

  final String chatId;
  final String peerId;
  final String baslik;
  final String? avatarMediaId;

  /// ⚠️ Arama akisini bu ekran BASLATMAZ: `ActiveCallController` zaten sohbet
  ///	ekranindan suruluyor ve ikinci bir kopya kacinilmaz olarak drift
  ///	ederdi (bu projede ALTI kez yasandi). Cagri geri verilir.
  final VoidCallback? sesliAra;
  final VoidCallback? goruntuluAra;

  @override
  ConsumerState<KisiBilgiEkrani> createState() => _KisiBilgiEkraniState();
}

class _KisiBilgiEkraniState extends ConsumerState<KisiBilgiEkrani> {
  Profil? _profil;
  bool _yukleniyor = true;
  bool _engelli = false;
  bool _sessiz = false;
  bool _arsiv = false;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final s = ref.read(sosyalServisiProvider);
      final p = await s.profil(widget.peerId);
      // ⚠️ Engel durumu AYRI uctan: profil yanitinda yok.
      final engeller = await ref
          .read(apiProvider)
          .get('/users/me/blocks')
          .then((r) => ((r.data as List?) ?? []).map((e) => (e as Map)['id']))
          .catchError((_) => const Iterable.empty());
      // ⚠️ Sohbet ayarlari LISTEDEN okunur: tekil sohbet ayari donduren bir uc
      //	YOK ve yalniz bunun icin uc acmak BACKEND TURU olurdu.
      final sohbet = ref
          .read(chatsProvider)
          .valueOrNull
          ?.where((c) => c.id == widget.chatId)
          .firstOrNull;
      if (!mounted) return;
      setState(() {
        _profil = p;
        _engelli = engeller.contains(widget.peerId);
        _sessiz = sohbet?.sessiz ?? false;
        _arsiv = sohbet?.archived ?? false;
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _uyar(String m) =>
      rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));

  /// ⚠️ Yerel durum ONCE yazilir (arayuz ANINDA tepki versin), istek patlarsa
  ///	GERI ALINIR ve sebep soylenir — sessizce eski hale donmek "dokundum,
  ///	bir sey olmadi" hissi verirdi.
  Future<void> _ayar({bool? sessiz, bool? arsiv}) async {
    if (_mesgul) return;
    _mesgul = true;
    final eskiS = _sessiz;
    final eskiA = _arsiv;
    setState(() {
      if (sessiz != null) _sessiz = sessiz;
      if (arsiv != null) _arsiv = arsiv;
    });
    try {
      await ref.read(apiProvider).patch(
        '/chats/${widget.chatId}',
        data: {
          if (sessiz != null) 'muted': sessiz,
          if (arsiv != null) 'archived': arsiv,
        },
      );
      ref.read(chatsProvider.notifier).load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessiz = eskiS;
          _arsiv = eskiA;
        });
      }
      _uyar(apiErrorMessage(e));
    } finally {
      _mesgul = false;
    }
  }

  Future<void> _temizle() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sohbeti temizle'),
        content: const Text(
          'Bu sohbetteki mesajlar SENİN tarafında gizlenir. '
          'Karşı taraftan silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(apiProvider).delete('/chats/${widget.chatId}');
      ref.read(chatsProvider.notifier).load();
      _uyar('Sohbet temizlendi');
    } catch (e) {
      _uyar(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return koyuSayfa(Builder(builder: _govde));
  }

  Widget _govde(BuildContext c) {
    final scheme = Theme.of(c).colorScheme;
    final p = _profil;
    final ad = p?.ad.isNotEmpty == true ? p!.ad : widget.baslik;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Kişi bilgisi',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Avatar(
              ad: ad,
              mediaId: p?.avatarMediaId ?? widget.avatarMediaId,
              cap: 108,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              ad,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
          ),
          if ((p?.username ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                '@${p!.username}',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          if ((p?.hakkinda ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                p!.hakkinda,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          // HIZLI EYLEMLER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _hizli(c, LucideIcons.phone, 'Sesli', () {
                Navigator.of(c).pop();
                widget.sesliAra?.call();
              }),
              const SizedBox(width: 14),
              _hizli(c, LucideIcons.video, 'Görüntülü', () {
                Navigator.of(c).pop();
                widget.goruntuluAra?.call();
              }),
              const SizedBox(width: 14),
              _hizli(c, LucideIcons.userRound, 'Profil', () {
                Navigator.of(c).push(
                  MaterialPageRoute(
                    builder: (_) => ProfilSayfasi(userId: widget.peerId),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 22),
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          // AYARLAR
          SwitchListTile(
            value: _sessiz,
            onChanged: (v) => _ayar(sessiz: v),
            secondary: const Icon(LucideIcons.bellOff),
            title: const Text('Sessize al'),
            subtitle: const Text('Bildirim gelmez, sohbet listede kalır'),
          ),
          SwitchListTile(
            value: _arsiv,
            onChanged: (v) => _ayar(arsiv: v),
            secondary: const Icon(LucideIcons.archive),
            title: const Text('Arşivle'),
            subtitle: const Text('"Arşivler" sekmesine taşınır'),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(LucideIcons.eraser),
            title: const Text('Sohbeti temizle'),
            subtitle: const Text('Yalnızca sende gizlenir'),
            onTap: _temizle,
          ),
          ListTile(
            leading: Icon(
              _engelli ? LucideIcons.userCheck : LucideIcons.ban,
              color: _engelli ? null : const Color(0xFFD32F2F),
            ),
            title: Text(
              _engelli ? 'Engeli kaldır' : 'Engelle',
              style: _engelli
                  ? null
                  : const TextStyle(color: Color(0xFFD32F2F)),
            ),
            onTap: () async {
              final degisti = await engelleOnayiAc(
                c,
                ref,
                kullaniciId: widget.peerId,
                ad: ad,
                suAnEngelli: _engelli,
              );
              if (degisti && mounted) setState(() => _engelli = !_engelli);
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.flag, color: Color(0xFFD32F2F)),
            title: const Text(
              'Şikâyet et',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
            onTap: () => sikayetSheetAc(
              c,
              ref,
              hedefTur: 'kullanici',
              hedefId: widget.peerId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hizli(
    BuildContext c,
    IconData ikon,
    String ad,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(c).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.16),
              ),
              child: Icon(ikon, size: 22, color: scheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              ad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
