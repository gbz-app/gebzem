import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../isletme/kategori_kabuk.dart' show YemekHeader;
import '../kanal/kanal_ekrani.dart' show KanalEkrani;
import '../kanal/kanal_olustur.dart' show KanalOlustur;
import '../kanal/kanal_servisi.dart' show Kanal, kanalServisiProvider;
import '../medya/medya_gorsel.dart';
import 'chats_provider.dart';
import 'grup_olustur.dart';
import 'models.dart';

/// ⚠️⚠️⚠️ TURU 180x — "YENI MESAJ" EKRANI (kullanici emri + ekran goruntusu:
///	*"sagda + tikladigimda whatsapp gibi ekran gelsin: Kime, Ara, grup
///	sohbeti, topluluk olustur; altinda onerilenler — kisiler, topluluk"*).
///
/// ⚠️⚠️ **ONCEKI HALI BIR ALT SAYFAYDI (bottom sheet)** ve dort maddesi vardi.
///	Sheet TAVANI (ekranin 9/16'si) yuzunden "Onerilen" listesi oraya
///	YAPISAL OLARAK sigmazdi (turu 90b'de olculdu: `isScrollControlled`
///	tavani kaldirir ama liste yine yarim ekranda kalir). Bu yuzden TAM
///	SAYFA route.
///
/// ⚠️⚠️ **BACKEND DEGISMEDI — YENI UC YOK.** Uc kaynak da MEVCUT:
///	  · kisi aramasi   -> `GET /users/search?q=`
///	  · oneri (kisi)   -> `chatsProvider` (gorustugun 1:1 sohbetler)
///	  · topluluk       -> `GET /channels/kesfet`
/// ⚠️ "Onerilen" bir SIRALAMA IDDIASI DEGIL: sunucuda oneri/skor diye bir sey
///	YOK. Liste "en son gorustuklerin + kesfedilebilir topluluklar"dir ve
///	baslik bilincli olarak notr. Uydurma bir skorla "senin icin secildi"
///	demek, turu 135'te silinen sahte kur seridiyle AYNI SINIF olurdu.
class YeniMesajEkrani extends ConsumerStatefulWidget {
  const YeniMesajEkrani({super.key});

  @override
  ConsumerState<YeniMesajEkrani> createState() => _YeniMesajEkraniState();
}

class _YeniMesajEkraniState extends ConsumerState<YeniMesajEkrani> {
  final _ctrl = TextEditingController();
  Timer? _gecikme;

  String _q = '';
  List<Map<String, dynamic>> _sonuc = const [];
  bool _araniyor = false;

  List<Kanal> _kanallar = const [];
  bool _kanalYuklendi = false;

  /// Ayni anda iki sohbet acilmasin (cift dokunus = iki `/chats/direct`).
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _kanallariYukle();
  }

  @override
  void dispose() {
    _gecikme?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// ⚠️⚠️ TURU 180x — **IKI KAYNAK BIRDEN** (emulatorde olculdu).
  ///
  ///	Ilk yazimda YALNIZ `kesfet()` cagriliyordu; o uc "ABONE OLMADIGIN"
  ///	topluluklari doner. Kendi kurdugun topluluga sunucu seni OTOMATIK
  ///	abone yaptigi icin (bkz. `Create`), tek toplulugu olan bir kullanici
  ///	bu ekranda **"Topluluklar" bolumunu HIC GORMUYORDU** — ozellik yokmus
  ///	gibi duruyordu.
  /// ⚠️ Sira: ONCE benimkiler (tanidik), SONRA kesfet. Tekilleme `id` ile:
  ///	iki uc ayni toplulugu dondurebilir ve liste CIFT cizerdi.
  /// ⚠️ `Future.wait` — seri olsaydi ekran iki gidis donus beklerdi.
  Future<void> _kanallariYukle() async {
    try {
      final s = ref.read(kanalServisiProvider);
      final sonuc = await Future.wait([
        s.listem().catchError((_) => <Kanal>[]),
        s.kesfet().catchError((_) => <Kanal>[]),
      ]);
      final gorulen = <String>{};
      final birlesik = <Kanal>[];
      for (final liste in sonuc) {
        for (final k in liste) {
          if (gorulen.add(k.id)) birlesik.add(k);
        }
      }
      if (mounted) setState(() => _kanallar = birlesik);
    } catch (_) {
      // sessiz: kisi onerileri CIZILMEYE DEVAM ETMELI
    } finally {
      if (mounted) setState(() => _kanalYuklendi = true);
    }
  }

  /// ⚠️ Her tusa basista degil, yazma durunca ara (350 ms). Debounce OLMADAN
  ///	"ahmet" yazmak BES istek atardi ve gec donen yanit erken doneni
  ///	EZERDI (turu 141/144 bayat-yanit sinifi).
  void _degisti(String v) {
    final q = v.trim();
    setState(() => _q = q);
    _gecikme?.cancel();
    if (q.length < 2) {
      setState(() {
        _sonuc = const [];
        _araniyor = false;
      });
      return;
    }
    _gecikme = Timer(const Duration(milliseconds: 350), () => _ara(q));
  }

  Future<void> _ara(String q) async {
    setState(() => _araniyor = true);
    try {
      final r = await ref
          .read(apiProvider)
          .get('/users/search', queryParameters: {'q': q});
      if (!mounted) return;
      // ⚠️ BAYAT YANIT KAPISI: kullanici aramayi degistirdiyse gec gelen
      //	yanit listeyi YANLIS veriyle doldururdu.
      if (_q != q) return;
      setState(() => _sonuc = (r.data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted) setState(() => _sonuc = const []);
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  Future<void> _kisiyeGit(String userId, String ad, String? avatar) async {
    if (_mesgul) return;
    _mesgul = true;
    try {
      final r = await ref
          .read(apiProvider)
          .post('/chats/direct', data: {'user_id': userId});
      ref.read(chatsProvider.notifier).load();
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(
        '/chat/${r.data['chat_id']}',
        extra: {'title': ad, 'peer_id': userId, 'avatar_media_id': avatar},
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      _mesgul = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider).valueOrNull ?? const <Chat>[];

    // ⚠️ ONERILEN KISILER = gorustugum 1:1 sohbetlerin karsi taraflari.
    //	`peerId` NULL olan kayit (grup/topluluk) elenir; en yeni once.
    final gecmis =
        chats
            .where((c) => c.type == 'direct' && (c.peerId ?? '').isNotEmpty)
            .toList()
          ..sort(
            (a, b) =>
                (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0)),
          );

    final aramaVar = _q.length >= 2;
    final oneriKisiler = aramaVar
        ? const <Chat>[]
        : gecmis.take(12).toList();
    final oneriKanallar = aramaVar
        ? _kanallar
              .where(
                (k) =>
                    k.ad.toLowerCase().contains(_q.toLowerCase()) ||
                    k.kullaniciAdi.toLowerCase().contains(_q.toLowerCase()),
              )
              .toList()
        : _kanallar.take(8).toList();

    return koyuSayfa(
      Builder(
        builder: (c) => Scaffold(
          backgroundColor: kAiZemin,
          appBar: YemekHeader(
            baslik: 'Yeni mesaj',
            geriBasildi: () => Navigator.of(c).maybePop(),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _kimeSatiri(c),
              const Divider(height: 1),
              // ⚠️ Iki kisayol ARAMA VARKEN DE cizilir: kullanici bir isim
              //	yazip "aslinda grup kuracaktim" diyebilir; gizlemek onu
              //	geri donup aramayi temizlemeye zorlardi.
              _kisayol(
                c,
                LucideIcons.usersRound,
                'Grup sohbeti',
                () => Navigator.of(c).push(
                  MaterialPageRoute(builder: (_) => const GrupOlusturEkrani()),
                ),
              ),
              _kisayol(
                c,
                LucideIcons.megaphone,
                'Kanal oluştur',
                () => _toplulukOlustur(c),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  aramaVar ? 'Sonuçlar' : 'Önerilen',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_araniyor)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              // ARAMA SONUCLARI (kisiler)
              for (final u in _sonuc)
                _kisiSatiri(
                  ad: (u['name'] as String?) ?? '',
                  kullaniciAdi: (u['username'] as String?) ?? '',
                  mediaId: u['avatar_media_id'] as String?,
                  onTap: () => _kisiyeGit(
                    u['id'] as String,
                    (u['name'] as String?) ??
                        (u['username'] as String?) ??
                        'Kişi',
                    u['avatar_media_id'] as String?,
                  ),
                ),
              // ONERILEN KISILER (gorustuklerim)
              for (final ch in oneriKisiler)
                _kisiSatiri(
                  ad: ch.title,
                  kullaniciAdi: '',
                  mediaId: ch.avatarMediaId,
                  onTap: () {
                    Navigator.of(c).pop();
                    context.push(
                      '/chat/${ch.id}',
                      extra: {
                        'title': ch.title,
                        'peer_id': ch.peerId,
                        'avatar_media_id': ch.avatarMediaId,
                      },
                    );
                  },
                ),
              // TOPLULUKLAR
              if (oneriKanallar.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Text(
                    'Kanallar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final k in oneriKanallar)
                  _kisiSatiri(
                    ad: k.ad,
                    kullaniciAdi: k.kullaniciAdi,
                    mediaId: k.avatarMediaId,
                    topluluk: true,
                    onTap: () => Navigator.of(c).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            KanalEkrani(kanalId: k.id, onIsim: k.ad),
                      ),
                    ),
                  ),
              ],
              // ⚠️ BOS DURUM: arama sonucu yoksa DURUSTCE soylenir; sessiz bos
              //	liste "ekran bozuk" gibi gorunur (turu 113 sinifi).
              if (!_araniyor &&
                  _sonuc.isEmpty &&
                  oneriKisiler.isEmpty &&
                  oneriKanallar.isEmpty &&
                  _kanalYuklendi)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Text(
                    aramaVar
                        ? 'Eşleşen kişi ya da kanal yok'
                        : 'Henüz görüştüğün kimse yok.\nYukarıdan isim ya da @kullanıcıadı ara.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(
                        c,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Kime:" + arama alani (ekran goruntusundeki satir).
  ///
  /// ⚠️ Etiket ve alan AYNI SATIRDA: ayri satirlar olsaydi listeye 40 dp daha
  ///	az yer kalirdi ve referans gorunumden ayrisirdi.
  Widget _kimeSatiri(BuildContext c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          const Text('Kime:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              onChanged: _degisti,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Ara',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          if (_q.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: () {
                _ctrl.clear();
                _degisti('');
              },
            ),
        ],
      ),
    );
  }

  Widget _kisayol(
    BuildContext c,
    IconData ikon,
    String metin,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(c).colorScheme;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(ikon, size: 20, color: scheme.primary),
      ),
      title: Text(metin, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
    );
  }

  Widget _kisiSatiri({
    required String ad,
    required String kullaniciAdi,
    required String? mediaId,
    required VoidCallback onTap,
    bool topluluk = false,
  }) {
    return ListTile(
      leading: Avatar(ad: ad, mediaId: mediaId, cap: 48),
      title: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: kullaniciAdi.isEmpty
          ? null
          : Text(
              topluluk ? '@$kullaniciAdi · Kanal' : '@$kullaniciAdi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }

  /// ⚠️ Topluluk kurulduktan SONRA icine girilir: kullanici kurdugu seyi
  ///	goremeden listeye donerse "olustu mu?" diye tekrar kurmaya calisir
  ///	(turu 114'te olculdu: arkada YETIM topluluklar birikti).
  Future<void> _toplulukOlustur(BuildContext c) async {
    final id = await Navigator.of(
      c,
    ).push<String>(MaterialPageRoute(builder: (_) => const KanalOlustur()));
    if (id == null || !mounted) return;
    if (!c.mounted) return;
    await Navigator.of(c).push(
      MaterialPageRoute(
        builder: (_) => KanalEkrani(kanalId: id, onIsim: 'Kanal'),
      ),
    );
  }
}
