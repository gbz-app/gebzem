import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import 'chats_provider.dart';

/// ⚠️⚠️ TURU 76b — GRUP BILGISI / UYE YONETIMI.
///
/// **NEDEN SONRADAN EKLENDI (kullanici bulgusu: "grup olusturma nerede?"):**
/// FAZ 6 grup sohbetini ekledi ve sunucuya UC uc yazildi —
/// `GET /chats/{id}/members`, `POST .../members`, `DELETE .../members/{userID}` —
/// ama ISTEMCIDEN HICBIRI CAGRILMIYORDU. Yani grup KURULABILIYOR, fakat
/// uyeleri GORULEMIYOR, uye EKLENEMIYOR, CIKARILAMIYORDU. Uclar yazilmis,
/// test edilmis ve **hicbir dugmeye baglanmamisti**.
///
/// Bu, bu projenin tekrar eden hatasinin (CLAUDE.md: "bir sutun/servis/dugme
/// ekledigin AN onu OKUYAN yolu da yaz" — `deleted_for_all`, `blocks`,
/// `post_saves`, `gizlilikAyarla` ornekleri) BESINCI tekrariydi.
/// ⚠️ YAPMA: yeni bir grup ucu eklerken bu ekrana girisini de yaz.
///
/// ⚠️ YETKI: ekleme/cikarma YALNIZ owner/admin'de (sunucu da ayni kurali
///    uyguluyor — istemci kapisi YALNIZ arayuz temizligi icin, guvenlik
///    sunucudadir). Kendini cikarma HERKESTE serbest (= gruptan ayril),
///    **sahip HARIC** (grup sahipsiz kalirsa yonetilemez bir kalinti olur).
class GrupBilgiEkrani extends ConsumerStatefulWidget {
  const GrupBilgiEkrani({
    super.key,
    required this.chatId,
    required this.baslik,
    this.avatarMediaId,
  });

  final String chatId;
  final String baslik;
  final String? avatarMediaId;

  @override
  ConsumerState<GrupBilgiEkrani> createState() => _GrupBilgiEkraniState();
}

class _GrupBilgiEkraniState extends ConsumerState<GrupBilgiEkrani> {
  List<Map<String, dynamic>>? _uyeler;
  String? _hata;
  bool _isleniyor = false;

  /// Kendi kimligim — "sen" etiketi + ayrilma dugmesi icin.
  String? _benimId;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final api = ref.read(apiProvider);
      final me = await api.get('/users/me');
      final r = await api.get('/chats/${widget.chatId}/members');
      if (!mounted) return;
      setState(() {
        _benimId = (me.data as Map)['id'] as String?;
        _uyeler = ((r.data as List?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _hata = null;
      });
    } catch (_) {
      if (mounted) setState(() => _hata = 'Üyeler alınamadı');
    }
  }

  /// Kendi rolum. `owner` / `admin` / `member`.
  String get _rolum {
    final u = _uyeler?.firstWhere(
      (e) => e['id'] == _benimId,
      orElse: () => const <String, dynamic>{},
    );
    return (u?['role'] ?? 'member').toString();
  }

  bool get _yetkiliyim => _rolum == 'owner' || _rolum == 'admin';

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Sunucunun hata metnini AYNEN gosterir — sessiz basarisizlik YASAK.
  String _hataMetni(Object e) {
    final s = e.toString();
    final i = s.indexOf('"error":"');
    if (i >= 0) {
      final j = s.indexOf('"', i + 9);
      if (j > i) return s.substring(i + 9, j);
    }
    return 'İşlem yapılamadı';
  }

  Future<void> _uyeEkle() async {
    final secilen = await Navigator.of(context)
        .push<List<Map<String, dynamic>>>(
          MaterialPageRoute(
            builder: (_) => _KisiSecEkrani(
              // ⚠️ Zaten uye olanlar listede GORUNMEZ — eklemeye calisip
              //    "zaten uye" hatasi almak kotu bir deneyim.
              haric: (_uyeler ?? [])
                  .map((e) => (e['id'] ?? '').toString())
                  .toSet(),
            ),
          ),
        );
    if (secilen == null || secilen.isEmpty || !mounted) return;
    setState(() => _isleniyor = true);
    try {
      await ref
          .read(apiProvider)
          .post(
            '/chats/${widget.chatId}/members',
            data: {'user_ids': secilen.map((e) => e['id']).toList()},
          );
      await _yukle();
      // Sohbet listesindeki uye sayisi/baslik degismis olabilir.
      unawaited(ref.read(chatsProvider.notifier).load());
      _uyar('${secilen.length} kişi eklendi');
    } catch (e) {
      _uyar(_hataMetni(e));
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  Future<void> _cikar(Map<String, dynamic> u) async {
    final kendisi = u['id'] == _benimId;
    final ad = (u['name'] ?? '').toString();
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(kendisi ? 'Gruptan ayrıl' : 'Gruptan çıkar'),
        content: Text(
          kendisi
              ? 'Bu gruptan ayrılmak istiyor musun? Mesajları göremezsin.'
              : '$ad gruptan çıkarılsın mı?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              kendisi ? 'Ayrıl' : 'Çıkar',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    setState(() => _isleniyor = true);
    try {
      await ref
          .read(apiProvider)
          .delete('/chats/${widget.chatId}/members/${u['id']}');
      unawaited(ref.read(chatsProvider.notifier).load());
      if (!mounted) return;
      if (kendisi) {
        // ⚠️ Gruptan ayrildik: bu ekran DA sohbet ekrani DA anlamsiz.
        //    `popUntil(isFirst)` ile ana kabuga doneriz — aksi halde
        //    kullanici artik uyesi olmadigi sohbette kalir ve her istek
        //    403 doner (sessiz bozuk ekran).
        Navigator.of(context).popUntil((r) => r.isFirst);
        return;
      }
      await _yukle();
      _uyar('$ad çıkarıldı');
    } catch (e) {
      _uyar(_hataMetni(e));
    } finally {
      if (mounted) setState(() => _isleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _uyeler;
    return Scaffold(
      appBar: AppBar(title: const Text('Grup bilgisi')),
      body: _hata != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_hata!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _yukle,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            )
          : l == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 18),
                Center(
                  child: Avatar(
                    ad: widget.baslik,
                    mediaId: widget.avatarMediaId,
                    cap: 92,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    widget.baslik,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 14),
                    child: Text(
                      '${l.length} üye',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (_yetkiliyim)
                  ListTile(
                    leading: const Icon(LucideIcons.userPlus),
                    title: const Text('Üye ekle'),
                    onTap: _isleniyor ? null : _uyeEkle,
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    'ÜYELER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      // ⚠️ TURU 113 — `letterSpacing` KALDIRILDI (kullanici emri).
                      color: Colors.grey,
                    ),
                  ),
                ),
                for (final u in l) _uyeSatiri(u),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _uyeSatiri(Map<String, dynamic> u) {
    final ad = (u['name'] ?? '').toString();
    final rol = (u['role'] ?? 'member').toString();
    final kendisi = u['id'] == _benimId;
    // ⚠️ SAHIP kendini cikaramaz (sunucu da 400 doner) — dugmeyi hic gostermeyiz,
    //    yoksa kullanici basip anlamsiz bir hata alir.
    final cikarilabilir =
        (kendisi && rol != 'owner') ||
        (!kendisi && _yetkiliyim && rol != 'owner');
    return ListTile(
      leading: Avatar(
        ad: ad,
        mediaId: u['avatar_media_id'] as String?,
        cap: 42,
      ),
      title: Text(kendisi ? '$ad (sen)' : ad),
      subtitle: Text(
        [
          if ((u['username'] ?? '').toString().isNotEmpty) '@${u['username']}',
          if (rol == 'owner') 'Grup sahibi' else if (rol == 'admin') 'Yönetici',
        ].join(' · '),
      ),
      // ⚠️ Kendi satirimda profil acmak anlamsiz; baskasinda sosyal profile gider.
      onTap: kendisi
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ProfilSayfasi(userId: (u['id'] ?? '').toString()),
              ),
            ),
      trailing: cikarilabilir
          ? IconButton(
              tooltip: kendisi ? 'Gruptan ayrıl' : 'Gruptan çıkar',
              icon: Icon(
                kendisi ? LucideIcons.logOut : LucideIcons.userMinus,
                color: Colors.red,
                size: 20,
              ),
              onPressed: _isleniyor ? null : () => _cikar(u),
            )
          : null,
    );
  }
}

/// Uye eklemek icin kisi secici (coklu). `grup_olustur`daki birinci adimin
/// sadelestirilmis hali; ORTAK BIR BILESENE CIKARILMADI cunku oradaki surum
/// iki adimli akisin durumunu tasiyor ve birlestirmek ikisini de kirilgan yapar.
class _KisiSecEkrani extends ConsumerStatefulWidget {
  const _KisiSecEkrani({required this.haric});

  /// Zaten uye olanlar — listede GORUNMEZ.
  final Set<String> haric;

  @override
  ConsumerState<_KisiSecEkrani> createState() => _KisiSecEkraniState();
}

class _KisiSecEkraniState extends ConsumerState<_KisiSecEkrani> {
  final _arama = TextEditingController();
  Timer? _gecikme;
  List<Map<String, dynamic>> _sonuclar = [];
  final Map<String, Map<String, dynamic>> _secili = {};
  bool _araniyor = false;

  /// Bayat yanit kapisi — yanitlar SIRASIZ donebilir.
  int _istekNo = 0;

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  void _degisti(String v) {
    _gecikme?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        _sonuclar = [];
        _araniyor = false;
      });
      return;
    }
    setState(() => _araniyor = true);
    _gecikme = Timer(const Duration(milliseconds: 350), () => _ara(v.trim()));
  }

  Future<void> _ara(String q) async {
    final jeton = ++_istekNo;
    try {
      final r = await ref
          .read(apiProvider)
          .get('/users/search', queryParameters: {'q': q});
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _sonuclar = ((r.data as List?) ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .where((u) => !widget.haric.contains((u['id'] ?? '').toString()))
            .toList();
        _araniyor = false;
      });
    } catch (_) {
      if (!mounted || jeton != _istekNo) return;
      setState(() {
        _sonuclar = [];
        _araniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Üye ekle'),
      actions: [
        TextButton(
          onPressed: _secili.isEmpty
              ? null
              : () => Navigator.pop(context, _secili.values.toList()),
          child: Text('Ekle${_secili.isEmpty ? '' : ' (${_secili.length})'}'),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _arama,
            autofocus: true,
            onChanged: _degisti,
            decoration: InputDecoration(
              hintText: 'İsim veya @kullanıcıadı',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        if (_secili.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final u in _secili.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text((u['name'] ?? '').toString()),
                      onDeleted: () =>
                          setState(() => _secili.remove(u['id'] as String)),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _araniyor
              ? const Center(child: CircularProgressIndicator())
              : _sonuclar.isEmpty
              ? const Center(
                  child: Text(
                    'Eklemek için kişi ara',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _sonuclar.length,
                  itemBuilder: (_, i) {
                    final u = _sonuclar[i];
                    final id = (u['id'] ?? '').toString();
                    final secili = _secili.containsKey(id);
                    return ListTile(
                      leading: Avatar(
                        ad: (u['name'] ?? '').toString(),
                        mediaId: u['avatar_media_id'] as String?,
                        avatarUrl: (u['avatar_url'] ?? '').toString(),
                        cap: 42,
                      ),
                      title: Text((u['name'] ?? '').toString()),
                      subtitle: Text('@${(u['username'] ?? '').toString()}'),
                      trailing: Icon(
                        secili ? LucideIcons.circleCheck : LucideIcons.circle,
                        color: secili
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      onTap: () => setState(() {
                        secili ? _secili.remove(id) : _secili[id] = u;
                      }),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}
