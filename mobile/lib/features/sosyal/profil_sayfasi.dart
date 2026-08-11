import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../chats/chats_provider.dart';
import '../chats/moderasyon_sheet.dart';
import '../home/home_screen.dart' show myProfileProvider;
import '../home/profil_duzenle.dart';
import '../isletme/isletme_duzenle.dart';
import '../isletme/isletme_servisi.dart';
import '../randevu/randevu_al.dart';
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
    // ⚠️ TURU 82b — YENIDEN GIRME KAPISI. `_yukle` BES yerden cagriliyor
    //    (asagi-cek · takip · engelle · profil duzenlemeden donus · gizli
    //    hesap anahtari); ucusta bir istek varken ikincisini acmak iki paralel
    //    yukleme ve yaris demekti. `_p != null` sarti ZORUNLU: gercek ilk
    //    yuklemeyi ENGELLEMEMELI.
    if (_yukleniyor && _p != null) return;
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
    // ⚠️⚠️⚠️ TURU 82b — "PROFILDE YENILEDIGIMDE EKRAN PATLIYOR, BEYAZ OLUYOR"
    //    (kullanici bildirimi). **KOK NEDEN BURASIYDI.**
    //
    //    Bu satir `_yukleniyor` bayragina bakiyordu ve o bayrak SADECE ilk
    //    yuklemede degil **HER YENILEMEDE** true oluyor. Kosul asagidaki
    //    `Scaffold` + `AppBar` + `RefreshIndicator` + `ListView`in USTUNDE
    //    oldugu icin asagi-cek jesti sayfanin TAMAMINI agactan siliyordu:
    //      · AppBar gidiyor        -> geri dugmesi kayboluyor
    //      · RefreshIndicator gidiyor -> jestin sahibi yok oluyor
    //      · kapak/avatar/sayaclar/izgara gidiyor
    //    Geriye AppBar'siz bos bir `Scaffold` kaliyor ve **turu 81'in ACIK
    //    TEMASI** ile zemin `0xFFF2F2F5` oldugu icin ekran BEYAZ patliyor.
    //    (Koyu temada da ayni sey oluyordu, sadece "normal yukleme" gibi
    //    goründügü için fark edilmemisti — acik tema bedeli gorunur yapti.)
    //
    //    ⚠️ Ayni yol BES kullanici eyleminde tetikleniyordu: asagi-cek ·
    //       takip etme · engelleme · profili duzenleyip donme · gizli hesap
    //       anahtari. Yani hata "yenileme"den cok daha genis bir yuzeydeydi.
    //
    // FIX: tam sayfa bosaltma YALNIZ **gercek ilk yuklemede** (`_p == null`).
    // Yenilemede ESKI PROFIL EKRANDA KALIR; donen spinner'i zaten
    // `RefreshIndicator` ciziyor.
    // ⚠️ `AppBar()` KORUNDU — ilk yuklemede bile geri dugmesi kaybolmasin.
    // ⚠️ YAPMA: kosulu tekrar ciplak `_yukleniyor`a dondurme.
    if (_yukleniyor && _p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
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
      body: YenileSarmali(
        onRefresh: _yukle,
        child: ListView(
          // ⚠️ TURU 82b — `AlwaysScrollableScrollPhysics` ZORUNLU: icerigi
          //    ekrandan KISA profillerde (gonderisi olmayan hesap) Android'in
          //    varsayilan `ClampingScrollPhysics`i overscroll uretmedigi icin
          //    asagi-cek jesti HIC TETIKLENMIYORDU — yani o hesaplarda
          //    yenileme yolu FIILEN YOKTU. Turu 77b'de akis icin duzeltilen
          //    sinifin aynisi.
          physics: const AlwaysScrollableScrollPhysics(),
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
            else ...[
              // ⚠️ TURU 82b — INSTAGRAM TARZI SEKME SERIDI (kullanici emri:
              //    *"profilde gonderi, fotograf, video vb alan olsun Instagram
              //    gibi, hepsi bir yerde, tikladiginda ona gecsin"*).
              _sekmeSeridi(),
              if (_sekmeliListe.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      _bosMetin,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                _izgara(),
            ],
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

  /// ⚠️⚠️ TURU 82b — PROFIL SEKMELERI (Instagram deseni).
  ///
  /// 0 = Tümü · 1 = Fotoğraf · 2 = Video
  ///
  /// ⚠️ SUZGEC **ISTEMCIDE**, yeni bir uc ACILMADI: profil gonderileri zaten
  ///    TEK istekte geliyor ve `media_kinds` (turu 76) her medyanin turunu
  ///    TASIYOR. Sunucuya `?tur=` eklemek (a) sayfalama imlecini tur basina
  ///    ayirmayi, (b) `sutun_test.go` ailesine yeni bir sorgu daha eklemeyi
  ///    gerektirirdi — kazanci olmayan iki risk.
  /// ⚠️ Sekme degisimi AG ISTEGI ATMAZ; liste bellekte suzulur.
  int _sekme = 0;

  /// Aktif sekmenin listesi. ⚠️ `kind(0)` ILK medyanin turudur — izgara zaten
  /// ilk medyayi kapak olarak ciziyor (turu 76 karari), yani suzgec kullanicinin
  /// GORDUGU seyle birebir ortusur.
  List<Gonderi> get _sekmeliListe {
    if (_sekme == 1) {
      return _gonderiler
          .where((g) => g.mediaIds.isNotEmpty && g.kind(0) != 'video')
          .toList();
    }
    if (_sekme == 2) {
      return _gonderiler.where((g) => g.kind(0) == 'video').toList();
    }
    return _gonderiler;
  }

  String get _bosMetin => switch (_sekme) {
    1 => 'Henüz fotoğraf yok',
    2 => 'Henüz video yok',
    _ => 'Henüz gönderi yok',
  };

  Widget _sekmeSeridi() {
    final renk = Theme.of(context).colorScheme.onSurface;
    Widget sekme(int deger, IconData ikon, String etiket) {
      final secili = _sekme == deger;
      return Expanded(
        child: Semantics(
          button: true,
          selected: secili,
          label: etiket,
          child: InkWell(
            onTap: () => setState(() => _sekme = deger),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Icon(
                ikon,
                size: 21,
                // ⚠️ Aktif/pasif AYRIMI IKI ISARETLE (renk + alttaki cizgi) —
                //    tek isaret renk korlugunde ayirt edilemez (turu 80 karari).
                color: secili ? renk : renk.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            sekme(0, LucideIcons.layoutGrid, 'Tümü'),
            sekme(1, LucideIcons.image, 'Fotoğraflar'),
            sekme(2, LucideIcons.video, 'Videolar'),
          ],
        ),
        // Aktif sekmenin altindaki ince gosterge (Instagram deseni).
        // ⚠️ `AnimatedAlign` YERLESIMI DEGISTIRMEZ (yukseklik sabit 2dp),
        //    yalnizca yatay konumu kaydirir -> "ziplama" olusmaz.
        SizedBox(
          height: 2,
          child: LayoutBuilder(
            builder: (_, k) => Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: k.maxWidth / 3 * _sekme,
                  width: k.maxWidth / 3,
                  top: 0,
                  bottom: 0,
                  child: Container(color: renk),
                ),
              ],
            ),
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: renk.withValues(alpha: 0.08),
        ),
      ],
    );
  }

  Widget _izgara() {
    final liste = _sekmeliListe;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: liste.length,
      itemBuilder: (_, i) {
        final g = liste[i];
        return GestureDetector(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => GonderiDetay(gonderi: g))),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (g.mediaIds.isNotEmpty)
              // ⚠️⚠️⚠️ TURU 83 — **SEVK ENGELI DUZELTMESI** (denetim bulgusu).
              //
              //    Eskiden burada `MedyaGorsel(mediaId: g.mediaIds.first)`
              //    vardi ve TUR KONTROLU YAPMIYORDU. Yeni "Videolar" sekmesi
              //    TANIMI GEREGI yalniz `kind(0)=='video'` gonderileri
              //    listeledigi icin O SEKMEDEKI HER HUCRE bir VIDEO id'sini
              //    goruntu bileseni gonderiyordu:
              //      · thumb uretilmedigi icin (`kucukResim:` repodaki 17
              //        `yukle()` cagrisinin HICBIRINDE gecmiyor) ham `url`e
              //        dusuyor -> **mp4'un TAMAMI indiriliyor**,
              //      · ardindan goruntu cozucu patliyor -> **KIRIK GORSEL**.
              //    Yani sekme hem bozuk goruyor hem kullanicinin mobil
              //    verisini yakiyordu.
              //
              // ⚠️ `KapakGorseli` TAM BU IS ICIN yazilmis TEK KAYNAK:
              //    ILK FOTOGRAFI secer, yalniz-video gonderide `null` doner
              //    ve INDIRME YAPMADAN video yer tutucusu cizer.
              // ⚠️ YAPMA: buraya `MedyaGorsel(... mediaIds.first ...)` geri koyma.
              KapakGorseli(mediaIds: g.mediaIds, mediaKinds: g.mediaKinds)
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

  /// ⚠️⚠️ TURU 80b — HATA YUTULMAZ AMA EKRANI DA DUSURMEZ (denetim).
  ///
  ///	`detay()` turu 77b'de BILEREK "404'te null, digerlerinde FIRLAT"
  ///	yapilmisti (veri kaybi dersi). Ama burada `try/catch` YOKTU: mobil
  ///	agda tek bir kopma `initState`ten baslayan bu async akisi
  ///	YAKALANMAMIS ISTISNA ile bitiriyor, `_i` null kaliyor ve serit —
  ///	dolayisiyla **"Randevu al" dugmesi** — hic cizilmiyordu. Serit
  ///	`SizedBox.shrink()` dondugu icin kullaniciya HICBIR IPUCU da yoktu.
  ///
  /// ⚠️ TEK tekrar denemesi (1.2sn): serit YARDIMCI bir bilesendir, profilin
  ///    kendisi degil — sonsuz yeniden deneme mobil veriyi ve pili yakardi.
  /// ⚠️ Servis await'ten ONCE yakalanir (turu 78b: disposed State'te `ref.read`
  ///    StateError firlatir).
  Future<void> _yukle({bool tekrar = true}) async {
    final svc = ref.read(isletmeServisiProvider);
    try {
      final i = await svc.detay(widget.userId);
      if (mounted) setState(() => _i = i);
    } catch (_) {
      if (!mounted || !tekrar) return;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      await _yukle(tekrar: false);
    }
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
                            // TURU 89 - modul SUNUCUDAN gelir.
                            modul: i.modul,
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.bookOpen, size: 17),
                      // TURU 89 - kategoriye gore: Odalar / Hizmetler / Menü.
                      //    Kategoriden ISTEMCIDE tahmin edilmez.
                      label: Text(i.modul.ad),
                    ),
                  ),
                  // ⚠️⚠️ TURU 80 — REZERVASYON / RANDEVU DUGMESI.
                  //
                  //    Kullanici emri: "restoran/yemek firmalarindan
                  //    rezervasyon, doktor vs.den randevu alinabilmeli".
                  //
                  // ⚠️ YALNIZ `randevuAcik` TRUE iken cizilir ve bu bilgi
                  //    SUNUCUDAN gelir. Kategoriden tahmin edilseydi, ayari
                  //    ACMAMIS bir isletmede de dugme cizilir ve kullanici 404
                  //    alirdi — projede ALTI kez yasanan "ozellik var gorunup
                  //    calismiyor" sinifi.
                  // ⚠️ KENDI profilinde CIZILMEZ: kendi isletmenden randevu
                  //    alinamaz (sunucu da 400 doner). Sahip icin ayarlar
                  //    "İşletme bilgilerim" ekranindan ulasilir.
                  if (!widget.benimMi && i.randevuAcik) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RandevuAlEkrani(
                              isletmeId: widget.userId,
                              isletmeAd: widget.ad,
                            ),
                          ),
                        ),
                        icon: const Icon(LucideIcons.calendarPlus, size: 17),
                        label: Text(
                          i.rezervasyonMu ? 'Rezervasyon' : 'Randevu al',
                        ),
                      ),
                    ),
                  ],
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
