import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../chats/chats_provider.dart';
import '../chats/moderasyon_sheet.dart';
import '../home/home_screen.dart' show myProfileProvider;
import '../home/profil_duzenle.dart';
import '../isletme/isletme_duzenle.dart';
import '../isletme/isletme_servisi.dart';
import '../isletme/urun_ekranlari.dart';
import '../medya/medya_gorsel.dart';
import 'gonderi_karti.dart' show sayiBicimle;
import '../medya/tam_ekran_gorsel.dart';
import 'gonderi_detay.dart';
import 'profil_basligi.dart';
import 'sosyal_servisi.dart';
import 'kaydedilenler_sayfasi.dart';
import 'takip_listesi.dart';

/// ⚠️⚠️ TURU 75 — KULLANICI PROFILI (Instagram duzeni).
///
/// ⚠️ GIZLI HESAP KAPISI: `icerikKilitli` ise gonderiler CEKILMEZ — sunucu zaten
///    403 doner ama bosuna istek atmak hem gecikme hem gurultu.
///
/// ⚠️ ENGELLEME BURADAN DA YAPILIR: App Store 1.2 engellemeyi kullanici uretimi
///    icerigin GORULDUGU her yerde erisilebilir kilmayi bekliyor; sohbete girmek
///    zorunda birakmak kabul edilmez.
class ProfilSayfasi extends ConsumerStatefulWidget {
  const ProfilSayfasi({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<ProfilSayfasi> createState() => _ProfilSayfasiState();
}

class _ProfilSayfasiState extends ConsumerState<ProfilSayfasi> {
  Profil? _p;
  List<Gonderi> _gonderiler = [];
  bool _yukleniyor = true;
  bool _takipMesgul = false;
  bool _gizlilikMesgul = false;

  /// ⚠️ Bu profil BENIM mi. myProfileProvider ASENKRON yuklenir; henuz gelmediyse
  ///    false olur ve o kisa anda yabanci dugmeleri cizilir — zararsiz, cunku
  ///    build provider degisiminde yeniden kosar.
  bool _benimMi = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final s = ref.read(sosyalServisiProvider);
      final p = await s.profil(widget.userId);
      if (!mounted) return;
      List<Gonderi> g = [];
      if (!p.icerikKilitli) {
        try {
          g = await s.kullaniciGonderileri(widget.userId);
        } catch (_) {
          // Gonderiler alinamadi ama PROFIL gorunmeli — kismi basari.
        }
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _gonderiler = g;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = e.toString().contains('404')
            ? 'Kullanıcı bulunamadı'
            : 'Profil yüklenemedi';
      });
    }
  }

  Future<void> _takipCevir() async {
    final p = _p;
    if (p == null || _takipMesgul) return;
    setState(() => _takipMesgul = true);
    final eskiTakip = p.takipEdiyorum;
    final eskiIstek = p.istekBekliyor;
    final eskiSayi = p.takipciSayisi;
    try {
      final s = ref.read(sosyalServisiProvider);
      if (eskiTakip || eskiIstek) {
        await s.takibiBirak(p.id);
        if (!mounted) return;
        setState(() {
          p.takipEdiyorum = false;
          p.istekBekliyor = false;
          // ⚠️ Sayac YALNIZ onayli takip dususe gecer (bekleyen istek sayaca
          //    hic girmemisti — backend de ayni kurali uyguluyor).
          if (eskiTakip) p.takipciSayisi = (eskiSayi - 1).clamp(0, 1 << 30);
        });
      } else {
        final onayli = await s.takipEt(p.id);
        if (!mounted) return;
        setState(() {
          p.takipEdiyorum = onayli;
          p.istekBekliyor = !onayli;
          if (onayli) p.takipciSayisi = eskiSayi + 1;
        });
        // Gizli hesabi yeni takip ettiysek gonderiler ARTIK gorulebilir.
        if (onayli && _gonderiler.isEmpty) unawaited(_yukle());
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        p.takipEdiyorum = eskiTakip;
        p.istekBekliyor = eskiIstek;
        p.takipciSayisi = eskiSayi;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('İşlem tamamlanamadı')));
    } finally {
      if (mounted) setState(() => _takipMesgul = false);
    }
  }

  Future<void> _menu() async {
    final p = _p;
    if (p == null) return;
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠️ Kendi profilimde engelle/sikayet ANLAMSIZ (denetim bulgusu).
            if (!_benimMi)
              ListTile(
                leading: Icon(
                  p.engelledim ? LucideIcons.userCheck : LucideIcons.ban,
                ),
                title: Text(p.engelledim ? 'Engeli kaldır' : 'Engelle'),
                onTap: () => Navigator.pop(c, 'engel'),
              ),
            if (!_benimMi)
              ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Şikayet et'),
                onTap: () => Navigator.pop(c, 'sikayet'),
              ),
            if (_benimMi)
              ListTile(
                leading: const Icon(LucideIcons.link),
                title: const Text('Profil bağlantısını kopyala'),
                onTap: () => Navigator.pop(c, 'link'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'link') {
      final ad = p.username.isEmpty ? p.id : p.username;
      await Clipboard.setData(ClipboardData(text: 'https://gebzem.app/u/$ad'));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
    } else if (secim == 'sikayet') {
      await sikayetSheetAc(context, ref, hedefTur: 'kullanici', hedefId: p.id);
    } else if (secim == 'engel') {
      final onay = await engelleOnayiAc(
        context,
        ref,
        kullaniciId: p.id,
        ad: p.ad,
        suAnEngelli: p.engelledim,
      );
      // ⚠️ Engelleme takibi de DUSURUR (backend `takibiKaldir` cagiriyor) —
      //    bu yuzden profili TAMAMEN yeniden yukluyoruz, yerel yamalama YOK.
      if (onay && mounted) unawaited(_yukle());
    }
  }

  @override
  Widget build(BuildContext context) {
    _benimMi =
        (ref.watch(myProfileProvider).valueOrNull?['id'] ?? '').toString() ==
        widget.userId;
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _p;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata ?? 'Profil açılamadı'),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _yukle,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(p.username.isEmpty ? p.ad : '@${p.username}'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.ellipsis), onPressed: _menu),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          children: [
            // ⚠️⚠️ TURU 78 — KAPAK + LOGO/AVATAR + ONAYLI ROZET.
            //    Ust `SizedBox(height: 16)` KALDIRILDI: kapak AppBar'a YAPISIK
            //    baslamali, arada bosluk olursa "arka plan resmi" hissi kaybolur.
            // ⚠️ `SliverAppBar`a GECILMEDI (bilincli): bu sayfa `ListView` +
            //    `RefreshIndicator` + `shrinkWrap` izgara + kilitli hesap dali
            //    uzerine kurulu; sliver'a gecmek 756 satirin cekirdegini bastan
            //    yazmak demek. Kazanc yalnizca "kapak kaydirirken cokme"
            //    animasyonu olurdu ve ayni turda kapak + rozet + sliver birlikte
            //    degisseydi bir ariza cikinca SEBEP AYIRT EDILEMEZDI (turu 67).
            ProfilBasligi(
              p: p,
              // ⚠️ Avatara dokunus YALNIZ gercek bir medya varsa is yapar.
              //    `avatarMediaId` bossa (harf avatari) `onTap` NULL gecilir —
              //    dokunulabilir gorunup hicbir sey yapmayan bir alan
              //    birakmak bu projede tekrar eden "olu dugme" sinifidir.
              onAvatarDokun: (p.avatarMediaId ?? '').isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            TamEkranGorsel(mediaId: p.avatarMediaId!),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            ProfilAdSatiri(ad: p.ad, onayli: p.onayli),
            if (p.gizli)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.lock, size: 13, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Gizli hesap',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            if (p.hakkinda.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 10, 30, 0),
                child: Text(p.hakkinda, textAlign: TextAlign.center),
              ),
            if (p.baglanti.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: Text(
                    p.baglanti,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ),
            // TURU 77 — ISLETME BILGI SERIDI. Profil bir ISLETME hesabiysa
            // kategori/adres/telefon/calisma saatleri ve Urunler/Menu girisi
            // burada cizilir. Kisisel hesapta HIC cizilmez.
            _isletmeSeridi(p),
            const SizedBox(height: 16),
            _sayaclar(p),
            const SizedBox(height: 14),
            _dugmeler(p),
            const SizedBox(height: 8),
            const Divider(height: 1),
            if (p.icerikKilitli)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                child: Column(
                  children: [
                    Icon(LucideIcons.lock, size: 42, color: Colors.grey),
                    SizedBox(height: 14),
                    Text(
                      'Bu hesap gizli',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gönderilerini görmek için takip isteği gönder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_gonderiler.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'Henüz gönderi yok',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              _izgara(),
          ],
        ),
      ),
    );
  }

  /// Isletme profiliyse bilgi seridi; degilse HIC yer kaplamaz.
  Widget _isletmeSeridi(Profil p) =>
      IsletmeSeridi(userId: p.id, ad: p.ad, benimMi: _benimMi);

  Widget _sayaclar(Profil p) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _sayac('Gönderi', p.gonderiSayisi, null),
      _sayac(
        'Takipçi',
        p.takipciSayisi,
        // ⚠️ Gizli hesabin listeleri kilitli (sunucu 403); dokunusu KAPAT.
        p.icerikKilitli
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakipListesi(
                    userId: p.id,
                    tur: 'followers',
                    baslik: 'Takipçiler',
                  ),
                ),
              ),
      ),
      _sayac(
        'Takip',
        p.takipSayisi,
        p.icerikKilitli
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TakipListesi(
                    userId: p.id,
                    tur: 'following',
                    baslik: 'Takip edilenler',
                  ),
                ),
              ),
      ),
    ],
  );

  Widget _sayac(String etiket, int deger, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          Text(
            sayiBicimle(deger),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            etiket,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _dugmeler(Profil p) {
    // ⚠️⚠️ TURU 75b (DENETIM BULGUSU): KENDI PROFILIMDE "Takip et" / "Mesaj" /
    //    "Engelle" / "Şikayet et" cikiyordu. Ekran kendi kimligimle de aciliyor
    //    (Profil sekmesi -> "Gönderilerim ve profilim") ama hicbir "bu benim"
    //    kapisi yoktu: kendini takip etmeye calisinca sunucu 400 doner, kendini
    //    engelleme/sikayet ise anlamsiz.
    if (_benimMi) return _kendiDugmelerim(p);

    final takipli = p.takipEdiyorum;
    final bekliyor = p.istekBekliyor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: _takipMesgul || p.engelledim ? null : _takipCevir,
              style: takipli || bekliyor
                  ? null
                  : FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
              child: Text(
                p.engelledim
                    ? 'Engellendi'
                    : bekliyor
                    ? 'İstek gönderildi'
                    : takipli
                    ? 'Takiptesin'
                    : (p.beniTakipEdiyor ? 'Geri takip et' : 'Takip et'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.messageCircle, size: 17),
              label: const Text('Mesaj'),
              // ⚠️ Engelledigimiz kisiyle sohbet ACILMAZ (sunucu da reddeder).
              onPressed: p.engelledim ? null : () => _sohbetAc(p),
            ),
          ),
        ],
      ),
    );
  }

  /// Kendi profilim: duzenle + kaydedilenler + GIZLI HESAP anahtari.
  ///
  /// ⚠️⚠️ GIZLI HESAP ANAHTARI BURADA OLMAK ZORUNDA: `gizlilikAyarla()` servisi
  ///    yazilmisti ama HICBIR YERDEN CAGRILMIYORDU. Sonucu zincirlemeydi —
  ///    hicbir kullanici gizli hesap OLAMADIGI icin su kodun HEPSI ULASILAMAZDI:
  ///    takip isteklerinin 'bekliyor' dali, FollowApprove/FollowReject uclari,
  ///    "Takip istekleri" ekrani ve profil/liste ekranlarindaki kilit dallari.
  ///    (Denetim bunu ORTA seviye "olu ozellik" olarak yakaladi.)
  Widget _kendiDugmelerim(Profil p) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Profili düzenle'),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfilDuzenleEkrani(),
                    ),
                  );
                  if (mounted) unawaited(_yukle());
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(LucideIcons.bookmark, size: 16),
                label: const Text('Kaydedilenler'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KaydedilenlerSayfasi(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      SwitchListTile(
        value: p.gizli,
        secondary: const Icon(LucideIcons.lock),
        title: const Text('Gizli hesap'),
        subtitle: const Text(
          'Gönderilerini yalnızca onayladığın takipçiler görür',
        ),
        onChanged: _gizlilikMesgul ? null : (v) => _gizlilikCevir(p, v),
      ),
    ],
  );

  Future<void> _gizlilikCevir(Profil p, bool yeni) async {
    setState(() => _gizlilikMesgul = true);
    try {
      await ref.read(sosyalServisiProvider).gizlilikAyarla(yeni);
      if (!mounted) return;
      // ⚠️ Profili TAMAMEN yenile: gizliden ACIGA gecerken sunucu BEKLEYEN TUM
      //    istekleri otomatik onaylar ve takipci sayisi DEGISIR — yerel yamalama
      //    yanlis sayi gosterirdi.
      await _yukle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gizlilik ayarı değiştirilemedi')),
      );
    } finally {
      if (mounted) setState(() => _gizlilikMesgul = false);
    }
  }

  /// ⚠️ Sohbet acma AYNI yolu kullanir (POST /chats/direct) — `user_search_screen`
  ///    desenininin birebir esi. Ayri bir uc/servis YAZILMADI (drift eder).
  Future<void> _sohbetAc(Profil p) async {
    try {
      final chat = await ref
          .read(apiProvider)
          .post('/chats/direct', data: {'user_id': p.id});
      if (!mounted) return;
      ref.read(chatsProvider.notifier).load();
      context.push(
        '/chat/${chat.data['chat_id']}',
        extra: {'title': p.ad.isEmpty ? p.username : p.ad, 'peer_id': p.id},
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sohbet açılamadı')));
    }
  }

  Widget _izgara() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(2),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
    ),
    itemCount: _gonderiler.length,
    itemBuilder: (_, i) {
      final g = _gonderiler[i];
      return GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => GonderiDetay(gonderi: g))),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (g.mediaIds.isNotEmpty)
              // ⚠️ Izgarada KUCUK RESIM (`kucuk: true`) — 3 sutunlu izgarada
              //    tam cozunurluk indirmek kullanicinin verisini yakar.
              MedyaGorsel(mediaId: g.mediaIds.first, kucuk: true)
            else
              Container(
                color: const Color(0xFF1A1A24),
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                child: Text(
                  g.metin,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            // ⚠️⚠️ TURU 76 — ROZET ARTIK **ILK MEDYANIN TURUNDEN** (gonderi
            //    seviyesindeki `videoMu`dan DEGIL). Karma galeri geldiginde
            //    `tur='foto'` olan ama ILK OGESI VIDEO olan gonderiler
            //    oynatma rozeti ALMIYORDU — kapak donuk bir kare gibi duruyordu.
            // ⚠️ `else if` ZORUNLU: iki rozet de `right:5, top:5` konumunda;
            //    ikisi birden cizilirse UST USTE BINER (okunmaz simge yigini).
            if (g.kind(0) == 'video')
              const Positioned(
                right: 5,
                top: 5,
                child: Icon(LucideIcons.play, size: 15, color: Colors.white),
              )
            else if (g.mediaIds.length > 1)
              const Positioned(
                right: 5,
                top: 5,
                child: Icon(LucideIcons.copy, size: 14, color: Colors.white),
              ),
          ],
        ),
      );
    },
  );
}

/// ⚠️⚠️ TURU 77 — PROFILDEKI ISLETME SERIDI.
///
/// Kullanici emri: "normal ve isletme profilleri olacak".
///
/// ⚠️ AYRI BIR WIDGET (profil_sayfasi'nin state'ine gomulmedi): isletme
///    bilgisi AYRI bir uctan (`/users/{id}/isletme`) geliyor ve profilin
///    yuklenmesini BEKLETMEMELI. Bilgi gelene kadar serit CIZILMEZ, profil
///    normal gorunur.
/// ⚠️ Isletme DEGILSE hicbir sey cizilmez (404 -> null).
class IsletmeSeridi extends ConsumerStatefulWidget {
  const IsletmeSeridi({
    super.key,
    required this.userId,
    required this.ad,
    required this.benimMi,
  });

  final String userId;
  final String ad;
  final bool benimMi;

  @override
  ConsumerState<IsletmeSeridi> createState() => _IsletmeSeridiState();
}

class _IsletmeSeridiState extends ConsumerState<IsletmeSeridi> {
  Isletme? _i;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final i = await ref.read(isletmeServisiProvider).detay(widget.userId);
    if (mounted) setState(() => _i = i);
  }

  @override
  Widget build(BuildContext context) {
    final i = _i;
    // ⚠️ Isletme degilse (ya da henuz yuklenmediyse) HIC yer kaplamaz.
    if (i == null) return const SizedBox.shrink();
    final bugun = i.calisma
        .where((c) => c.gun == DateTime.now().weekday)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(
                      isletmeKategoriAdi(i.kategori),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  // ⚠️⚠️ TURU 78 — BURADAKI IKINCI TIK KALDIRILDI.
                  //    Onayli rozeti artik profil BASLIGINDA, adin yaninda
                  //    ciziliyor (`ProfilAdSatiri`). Ayni bilgi iki yerde
                  //    cizilseydi -- ki ZATEN DRIFT ETMISTI, burada 16px,
                  //    isletme listesinde 15px -- kullanici "iki cesit onay mi
                  //    var?" diye sorardi.
                  // ⚠️ YAPMA: buraya tekrar rozet ekleme; rozet TEK yerde
                  //    (`ProfilAdSatiri`) cizilir ve rengi `kOnayliRengi`.
                  const Spacer(),
                  // ⚠️ "Şu an açık" YALNIZ calisma saati GIRILMISSE cizilir;
                  //    bos veriyle "kapalı" demek YANILTICI olurdu.
                  if (i.calisma.isNotEmpty)
                    Text(
                      i.simdiAcik ? 'Şu an açık' : 'Şu an kapalı',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i.simdiAcik
                            ? const Color(0xFF2BB673)
                            : Colors.grey,
                      ),
                    ),
                ],
              ),
              if (i.adres.isNotEmpty || i.ilce.isNotEmpty)
                _satir(
                  LucideIcons.mapPin,
                  [i.adres, i.ilce, i.il].where((s) => s.isNotEmpty).join(', '),
                ),
              if (bugun != null && !bugun.kapali)
                _satir(
                  LucideIcons.clock,
                  'Bugün ${bugun.acilis} - ${bugun.kapanis}',
                ),
              if (i.telefon.isNotEmpty) _satir(LucideIcons.phone, i.telefon),
              if (i.web.isNotEmpty) _satir(LucideIcons.globe, i.web),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UrunKatalogEkrani(
                            isletmeId: widget.userId,
                            isletmeAd: widget.ad,
                            benimMi: widget.benimMi,
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.bookOpen, size: 17),
                      label: const Text('Ürünler / Menü'),
                    ),
                  ),
                  if (widget.benimMi) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const IsletmeDuzenleEkrani(),
                          ),
                        );
                        if (mounted) _yukle();
                      },
                      child: const Icon(LucideIcons.pencil, size: 17),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _satir(IconData ikon, String metin) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 15, color: Colors.grey),
        const SizedBox(width: 7),
        Expanded(child: Text(metin, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
