import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/tercihler.dart';
import '../../core/theme.dart';
import '../../router.dart' show rootMessengerKey;
import '../isletme/kategori_kabuk.dart' show YemekHeader;
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import '../sosyal/sosyal_servisi.dart';
import 'chats_provider.dart';
import 'grup_olustur.dart' show GrupOlusturEkrani;
import 'moderasyon_sheet.dart';
import 'sohbet_ayarlari.dart';

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
    // ⚠️⚠️ TURU 180ab — TAKMA AD **GERCEK ADIN ONUNDE**: kullanici bir takma
    //	ad verdiyse bu ekranin her yerinde onu gormeli, yoksa "kaydettim ama
    //	gorunmuyor" der. Takma ad YOKSA sunucudan gelen ad, o da yoksa
    //	cagiranin verdigi baslik.
    final takma = tercihler.takmaAd(widget.peerId);
    final gercekAd = p?.ad.isNotEmpty == true ? p!.ad : widget.baslik;
    final ad = takma.isNotEmpty ? takma : gercekAd;
    return Scaffold(
      backgroundColor: kAiZemin,
      // ⚠️⚠️⚠️ TURU 180ab — **BASLIK KALDIRILDI** (kullanici ekran goruntusu:
      //	Instagram sohbet ayarlari). Ekranin basligini AVATAR + AD tasiyor;
      //	ustte ayrica "Kişi bilgisi" yazmak ayni bilgiyi IKI KEZ soylerdi.
      appBar: YemekHeader(
        baslik: '',
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
          // ⚠️⚠️⚠️ TURU 180ab — HIZLI EYLEMLER **INSTAGRAM DUZENI**:
          //	Profil · Ara · Sessize al · Seçenekler.
          // ⚠️ Sesli/Goruntulu arama BURADAN CIKARILMADI, sohbet ekraninin
          //	header'inda ZATEN duruyor (turu 180z). Ayni eylemi iki yerde
          //	cizmek yerine Instagram'in dordunu koyduk.
          // ⚠️ `sesliAra`/`goruntuluAra` parametreleri DURUYOR: cagiran
          //	`chat_screen` onlari geciyor ve ileride geri konabilir.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
            children: [
              _hizli(c, LucideIcons.userRound, 'Profil', () {
                Navigator.of(c).push(
                  MaterialPageRoute(
                    builder: (_) => ProfilSayfasi(userId: widget.peerId),
                  ),
                );
              }),
              _hizli(c, LucideIcons.search, 'Ara', () {
                Navigator.of(c).push(
                  MaterialPageRoute(
                    builder: (_) => MesajAramaEkrani(
                      chatId: widget.chatId,
                      baslik: ad,
                    ),
                  ),
                );
              }),
              // ⚠️ "Sessize al" bir ANAHTAR degil BUTON: Instagram duzeninde
              //	dort eylem de ayni dilde. Durum ikonda gorunur (zil /
              //	ustu cizili zil) ve dokunusla ters cevrilir.
              _hizli(
                c,
                _sessiz ? LucideIcons.bell : LucideIcons.bellOff,
                _sessiz ? 'Sesi aç' : 'Sessize al',
                () => _ayar(sessiz: !_sessiz),
              ),
              _hizli(
                c,
                LucideIcons.ellipsis,
                'Seçenekler',
                () => _secenekleriAc(c, ad),
              ),
            ],
            ),
          ),
          const SizedBox(height: 22),
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
          // ══════════ AYAR LISTESI (Instagram duzeni) ══════════
          _satir(
            c,
            ikon: LucideIcons.palette,
            baslik: 'Tema',
            deger: _temaAdi(),
            onTap: () async {
              await Navigator.of(c).push(
                MaterialPageRoute(
                  builder: (_) => SohbetTemaEkrani(chatId: widget.chatId),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          _satir(
            c,
            ikon: LucideIcons.userPen,
            baslik: 'Takma adlar',
            deger: takma.isNotEmpty ? takma : null,
            onTap: () async {
              await Navigator.of(c).push(
                MaterialPageRoute(
                  builder: (_) => TakmaAdEkrani(
                    peerId: widget.peerId,
                    gercekAd: gercekAd,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          _satir(
            c,
            ikon: LucideIcons.timer,
            baslik: 'Süreli mesajlar',
            deger: _sureliAdi(),
            onTap: () async {
              await Navigator.of(c).push(
                MaterialPageRoute(
                  builder: (_) => SureliMesajlarEkrani(chatId: widget.chatId),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          _satir(
            c,
            ikon: LucideIcons.messageCircle,
            baslik: 'Sohbet kontrolleri',
            onTap: () async {
              await Navigator.of(c).push(
                MaterialPageRoute(
                  builder: (_) => SohbetKontrolleriEkrani(
                    chatId: widget.chatId,
                    sessiz: _sessiz,
                    arsiv: _arsiv,
                  ),
                ),
              );
              // ⚠️ Alt ekran ayni uclara yaziyor; donuste durumu YENIDEN
              //	OKU, yoksa bu ekranin anahtarlari BAYAT kalir.
              if (mounted) _yukle();
            },
          ),
          _satir(
            c,
            ikon: LucideIcons.lock,
            baslik: 'Gizlilik ve emniyet',
            onTap: () async {
              await Navigator.of(c).push(
                MaterialPageRoute(
                  builder: (_) => GizlilikEmniyetEkrani(
                    peerId: widget.peerId,
                    ad: ad,
                    kullaniciAdi: p?.username ?? '',
                    engelli: _engelli,
                  ),
                ),
              );
              if (mounted) _yukle();
            },
          ),
          _satir(
            c,
            ikon: LucideIcons.usersRound,
            baslik: 'Grup sohbeti oluştur',
            onTap: () => Navigator.of(
              c,
            ).push(MaterialPageRoute(builder: (_) => const GrupOlusturEkrani())),
          ),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(LucideIcons.eraser),
            title: const Text('Sohbeti temizle'),
            subtitle: const Text('Yalnızca sende gizlenir'),
            onTap: _temizle,
          ),
          // ⚠️⚠️ ENGELLE/SIKAYET **BURADAN KALDIRILMADI, TASINDI**: ikisi de
          //	"Seçenekler" popup'inda ve "Gizlilik ve emniyet" ekraninda.
          //	App Store Review Guideline 1.2 (UGC) ikisini de kullanicinin
          //	ULASABILECEGI bir yerde sart kosuyor — iki ayri yol var.
        ],
      ),
    );
  }

  /// Instagram "Seçenekler" popup'i: Kısıtla · Engelle · Şikayet Et.
  ///
  /// ⚠️⚠️ **"Kısıtla" CIZILMEDI**: sunucuda karsiligi YOK (olculdu, 9 Eyl)
  ///	ve engellemeden FARKLI bir sey vaat eder ("sessizce kisitla" =
  ///	mesajlar isteklere duser). Gorunen ama calismayan bir satir turu
  ///	66b dersinin tekrari olurdu; yerine ne oldugu SOYLENIYOR.
  void _secenekleriAc(BuildContext c, String ad) {
    final ks = Theme.of(c).colorScheme;
    showModalBottomSheet<void>(
      context: c,
      backgroundColor: kAiZemin,
      showDragHandle: true,
      builder: (bc) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _engelli ? LucideIcons.userCheck : LucideIcons.ban,
                color: _engelli ? ks.onSurface : const Color(0xFFE0523F),
              ),
              title: Text(
                _engelli ? 'Engeli kaldır' : 'Engelle',
                style: _engelli
                    ? null
                    : const TextStyle(color: Color(0xFFE0523F)),
              ),
              onTap: () async {
                Navigator.pop(bc);
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
              leading: const Icon(LucideIcons.flag, color: Color(0xFFE0523F)),
              title: const Text(
                'Şikâyet et',
                style: TextStyle(color: Color(0xFFE0523F)),
              ),
              onTap: () {
                Navigator.pop(bc);
                sikayetSheetAc(
                  c,
                  ref,
                  hedefTur: 'kullanici',
                  hedefId: widget.peerId,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _temaAdi() {
    final a = tercihler.sohbetTemasi(widget.chatId);
    // ⚠️ Ad `kSohbetTemalari`ndan cozulur, ELLE YAZILMAZ: listeye eklenen
    //	bir renk burada sessizce "Varsayılan" gorunmesin.
    for (final t in kSohbetTemalari) {
      if (t.anahtar == a) return t.ad;
    }
    return 'Varsayılan';
  }

  String _sureliAdi() => switch (tercihler.sureliMesaj(widget.chatId)) {
    'goruldukten' => 'Görüldükten sonra',
    '24saat' => '24 saat',
    '7gun' => '7 gün',
    _ => 'Kapalı',
  };

  /// Instagram ayar satiri: ikon · baslik · (alt satirda deger) · chevron.
  Widget _satir(
    BuildContext c, {
    required IconData ikon,
    required String baslik,
    String? deger,
    required VoidCallback onTap,
  }) {
    final ks = Theme.of(c).colorScheme;
    return ListTile(
      leading: Icon(ikon, size: 22, color: ks.onSurface),
      title: Text(
        baslik,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle: deger == null
          ? null
          : Text(
              deger,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: ks.onSurface.withValues(alpha: 0.55),
              ),
            ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 20,
        color: ks.onSurface.withValues(alpha: 0.45),
      ),
      onTap: onTap,
    );
  }

  Widget _hizli(
    BuildContext c,
    IconData ikon,
    String ad,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(c).colorScheme;
    // ⚠️⚠️⚠️ TURU 180ab — **SABIT 84 dp GENISLIK KALDIRILDI, `Expanded`**.
    //	Eylem sayisi UCTEN DORDE cikti: 4 x 84 = 336 dp ve 360 dp'lik
    //	ekranda kenar bosluklariyla birlikte TASIYORDU. `Expanded` ile dort
    //	hucre alani ESIT boler — tasma YAPISAL OLARAK imkansiz.
    // ⚠️ Ikon dairesi SABIT 52 dp kalir: hucre daralinca daire de kuculseydi
    //	dokunma hedefi Material'in 48 dp tabaninin ALTINA duserdi.
    // ⚠️⚠️ Etiket `FittedBox(scaleDown)` icinde: "Sessize al" ve "Seçenekler"
    //	dar hucrede (360 dp'de ~82 dp) yazi olcegi buyudugunde KIRPILIYORDU.
    //	`ellipsis` de var ama once KUCULUR, kirpma son care.
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                ad,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
