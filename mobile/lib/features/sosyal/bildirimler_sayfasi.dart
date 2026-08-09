import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../medya/medya_gorsel.dart';
import 'bildirim_sayaci.dart';
import 'gonderi_detay.dart';
import 'gonderi_karti.dart' show gonderiZamani;
import '../randevu/randevu_listeleri.dart';
import 'profil_sayfasi.dart';
import 'sosyal_servisi.dart';
import 'takip_listesi.dart';

/// ⚠️⚠️ TURU 75 — BILDIRIMLER.
///
/// ⚠️ NEDEN DB'DEN OKUNUYOR (WS varken)? Cunku istemci HER arka plana geciste
///    WebSocket'i kapatir (turu 33: kilit ekraninda arama calabilsin diye ZORUNLU).
///    WS ile gelen bildirim o boslukta KAYBOLUR. Turu 61'de `call.held` olayinin
///    tam olarak boyle kayboldugunu Sentry ile KANITLAMISTIK — ayni hatayi
///    bildirimlerde tekrarlamiyoruz.
///
/// ⚠️ "Okundu" isaretleme sayfa ACILINCA yapilir (girdiyse gormustur).
class BildirimlerSayfasi extends ConsumerStatefulWidget {
  const BildirimlerSayfasi({super.key});

  @override
  ConsumerState<BildirimlerSayfasi> createState() => _BildirimlerSayfasiState();
}

/// ⚠️ Surec omurlu: ayni bilinmeyen tur icin Sentry'i doldurma.
final _bilinmeyenTurler = <String>{};

class _BildirimlerSayfasiState extends ConsumerState<BildirimlerSayfasi> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
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
      final l = await s.bildirimler();
      if (!mounted) return;
      setState(() {
        _liste = l;
        _yukleniyor = false;
      });
      // ⚠️ Okundu isaretlemesi BEKLENMEZ (`unawaited`): basarisiz olursa liste
      //    yine de gorunmeli. Hata rozeti bir sonraki acilista duzelir.
      unawaited(s.bildirimleriOkudum().catchError((_) {}));
      // ⚠️ Rozet YEREL olarak da sifirlanir: ekrana AKIS ustundeki zilden DEGIL,
      //    profil sekmesindeki "Bildirimler" satirindan da girilebiliyor.
      ref.read(bildirimSayaciProvider.notifier).sifirla();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Bildirimler yüklenemedi';
      });
    }
  }

  ({IconData ikon, Color renk, String metin}) _tur(Map<String, dynamic> b) {
    final ad = (b['aktor_ad'] ?? '').toString();
    switch ((b['tur'] ?? '').toString()) {
      case 'begeni':
        return (
          ikon: LucideIcons.heart,
          renk: const Color(0xFFFF3B5C),
          metin: '$ad gönderini beğendi',
        );
      case 'yorum':
        return (
          ikon: LucideIcons.messageCircle,
          renk: const Color(0xFF2196F3),
          metin: '$ad gönderine yorum yaptı',
        );
      case 'takip':
        return (
          ikon: LucideIcons.userPlus,
          renk: const Color(0xFF4CAF50),
          metin: '$ad seni takip etmeye başladı',
        );
      case 'takip_istegi':
        return (
          ikon: LucideIcons.userPlus,
          renk: const Color(0xFFFF9800),
          metin: '$ad takip isteği gönderdi',
        );
      case 'takip_onaylandi':
        // ⚠️ TURU 75b (DENETIM): backend bu turu IKI yerde uretiyor
        //    (FollowApprove + SetPrivacy'de bekleyenlerin toplu onayi) ama
        //    istemcide karsiligi YOKTU -> "bir işlem yaptı" yazisina dusuyordu.
        return (
          ikon: LucideIcons.userRoundCheck,
          renk: const Color(0xFF4CAF50),
          metin: '$ad takip isteğini onayladı',
        );
      case 'bahsetme':
        return (
          ikon: LucideIcons.atSign,
          renk: const Color(0xFF8B5CF6),
          metin: '$ad senden bahsetti',
        );
      // ⚠️⚠️⚠️ TURU 80b — RANDEVU TURLERI (denetim: SEVK ENGELI).
      //    Sunucu turu 80'de DORT yeni bildirim turu uretmeye basladi ama
      //    istemcide karsiliklari YOKTU: hepsi `default` dalina dusup
      //    "**bir işlem yaptı**" yaziyordu — yani rezervasyon onayi ile red
      //    AYIRT EDILEMIYORDU. Ustelik her tur icin Sentry'ye "bilinmeyen
      //    bildirim turu" olayi dusuyordu (gurultu).
      //    ⚠️ Bu, turu 75b'de `takip_onaylandi` icin YASANAN hatanin AYNISI ve
      //       uyarisi hemen yukarida yaziliydi.
      // ⚠️ YAPMA: sunucuya yeni bildirim turu eklerken bu switch'i atlama.
      case 'randevu_yeni':
        return (
          ikon: LucideIcons.calendarPlus,
          renk: const Color(0xFF3AA9FF),
          metin: '$ad randevu talebi gönderdi',
        );
      case 'randevu_onaylandi':
        return (
          ikon: LucideIcons.calendarCheck,
          renk: const Color(0xFF2BB673),
          metin: '$ad randevunu onayladı',
        );
      case 'randevu_reddedildi':
        return (
          ikon: LucideIcons.calendarX,
          renk: const Color(0xFFFF3B5C),
          metin: '$ad randevunu reddetti',
        );
      // ⚠️⚠️ IKI AYRI TUR — ALICIYA GORE (turu 80b denetimi).
      //    `randevu_iptal`         : ISLETME iptal etti, alici MUSTERI
      //    `randevu_iptal_musteri` : MUSTERI iptal etti, alici ISLETME
      //    Tek tur olsaydi istemci aliciyi turetemezdi ve yonlendirme
      //    (`_git`) isletmeyi KENDI musteri listesine dusururdu.
      case 'randevu_iptal':
        return (
          ikon: LucideIcons.calendarX,
          renk: Colors.orange,
          metin: '$ad randevunu iptal etti',
        );
      case 'randevu_iptal_musteri':
        return (
          ikon: LucideIcons.calendarX,
          renk: Colors.orange,
          metin: '$ad randevusunu iptal etti',
        );
      default:
        // ⚠️ SESSIZ DUSMEK YASAK (projenin 3. hata sinifi): sunucuya YENI bir
        //    bildirim turu eklendiginde istemci onu genel metne dusurur ve kimse
        //    fark etmez. Olcum birak — arama basina degil, TUR basina bir kez.
        if (_bilinmeyenTurler.add((b['tur'] ?? '').toString())) {
          unawaited(
            Sentry.captureMessage('bilinmeyen bildirim turu: ${b['tur']}'),
          );
        }
        return (
          ikon: LucideIcons.bell,
          renk: Colors.grey,
          metin: '$ad bir işlem yaptı',
        );
    }
  }

  void _git(Map<String, dynamic> b) {
    final tur = (b['tur'] ?? '').toString();
    final hedefTur = (b['hedef_tur'] ?? '').toString();
    final hedefId = (b['hedef_id'] ?? '').toString();
    final aktor = (b['aktor_id'] ?? '').toString();

    if (tur == 'takip_istegi') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const TakipIstekleri()));
      return;
    }
    // ⚠️⚠️ TURU 80b — RANDEVU BILDIRIMI RANDEVU LISTESINE GIDER (denetim).
    //    Eskiden asagidaki genel dala dusup AKTORUN PROFILINI aciyordu; yani
    //    "randevun onaylandi" bildirimine dokunan kullanici restoranin
    //    profiline gidiyor ve randevusunu GOREMIYORDU.
    // ⚠️ Randevu DETAY ekrani YOK (bilincli — liste satiri tum bilgiyi
    //    tasiyor), bu yuzden ILGILI LISTEYE goturuyoruz.
    //
    // ⚠️⚠️ YON, BILDIRIM TURUNDEN TURETILIR (turu 80b denetimi). Onceki
    //    surumde yalniz `randevu_yeni` isletmeye gidiyordu ve `randevu_iptal`
    //    KOSULSUZ musteri listesine dusuyordu. Ama iptal CIFT YONLU bir olay:
    //    musteri iptal ettiginde alici ISLETMEDIR. Sunucu artik iki AYRI tur
    //    gonderiyor; ISLETMEYE GIDEN turler burada listelenir.
    // ⚠️ YAPMA: sunucuya isletmeye giden yeni bir randevu bildirimi eklerken
    //    bu kumeyi guncellemeyi atlama.
    const isletmeyeGiden = {'randevu_yeni', 'randevu_iptal_musteri'};
    if (hedefTur == 'randevu') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RandevuListesiEkrani(
            isletmeGorunumu: isletmeyeGiden.contains(tur),
          ),
        ),
      );
      return;
    }
    // ⚠️ Gonderi hedefine gitmek icin gonderiyi TEK BASINA cekebilmeliyiz;
    //    `GonderiDetay` id ile acilabildigi icin akisi yenilemeye gerek yok.
    if ((hedefTur == 'gonderi' || hedefTur == 'reels') && hedefId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GonderiDetay(gonderiId: hedefId)),
      );
      return;
    }
    if (aktor.isNotEmpty) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: aktor)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userRoundCheck),
            tooltip: 'Takip istekleri',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TakipIstekleri())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : _hata != null
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(_hata!)),
                  const SizedBox(height: 10),
                  Center(
                    child: OutlinedButton(
                      onPressed: _yukle,
                      child: const Text('Tekrar dene'),
                    ),
                  ),
                ],
              )
            : _liste.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 140),
                  Icon(LucideIcons.bellOff, size: 44, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Henüz bildirim yok',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: _liste.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = _liste[i];
                  final t = _tur(b);
                  final okundu = b['okundu'] == true;
                  return ListTile(
                    tileColor: okundu
                        ? null
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.06),
                    leading: Stack(
                      children: [
                        Avatar(
                          ad: (b['aktor_ad'] ?? '').toString(),
                          mediaId: b['aktor_avatar_media_id'] as String?,
                          avatarUrl: (b['aktor_avatar'] ?? '').toString(),
                          cap: 42,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: t.renk,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(t.ikon, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    title: Text(t.metin, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      gonderiZamani((b['created_at'] ?? '').toString()),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => _git(b),
                  );
                },
              ),
      ),
    );
  }
}
