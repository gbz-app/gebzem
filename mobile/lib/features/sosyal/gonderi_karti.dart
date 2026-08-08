import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../chats/moderasyon_sheet.dart';
import '../medya/tam_ekran_gorsel.dart';
import 'medya_video.dart';
import 'sosyal_servisi.dart';
import 'yorumlar_sayfasi.dart';

/// ⚠️⚠️ TURU 75 — AKISTAKI GONDERI KARTI (Instagram/Facebook duzeni).
///
/// ⚠️ IYIMSER GUNCELLEME (optimistic update): begeni/kaydetme dokunusta ANINDA
///    cizilir, REST arkada gider. Sunucu HATA donerse **GERI ALINIR** ve kullaniciya
///    soylenir. Bu projede "gonderdim sandim ama gitmemis" defalarca yasandi —
///    sessiz basarisizlik YASAK.
/// ⚠️ YAPMA: begeniyi REST donene kadar bekletme (dokunus 300-800ms olu hissedilir).
class GonderiKarti extends ConsumerStatefulWidget {
  const GonderiKarti({
    super.key,
    required this.gonderi,
    required this.benimId,
    this.onSilindi,
    this.profileGit,
  });

  final Gonderi gonderi;
  final String benimId;
  final VoidCallback? onSilindi;
  final void Function(String userId)? profileGit;

  @override
  ConsumerState<GonderiKarti> createState() => _GonderiKartiState();
}

class _GonderiKartiState extends ConsumerState<GonderiKarti> {
  /// ⚠️ Yeniden giris kilidi: hizli cift dokunus iki REST atar; sunucu idempotent
  ///    ama sayac yerel olarak iki kez oynar (gorsel tutarsizlik).
  bool _mesgul = false;
  int _sayfa = 0;

  /// Cift dokunusta ucan kalp animasyonu.
  bool _kalpGoster = false;

  Gonderi get g => widget.gonderi;

  Future<void> _begeniCevir({bool yalnizBegen = false}) async {
    if (_mesgul) return;
    if (yalnizBegen && g.begendim) {
      _kalpAnimasyonu();
      return;
    }
    final eskiDurum = g.begendim;
    final eskiSayi = g.begeniSayisi;
    setState(() {
      g.begendim = !eskiDurum;
      g.begeniSayisi = eskiSayi + (g.begendim ? 1 : -1);
      if (g.begeniSayisi < 0) g.begeniSayisi = 0;
    });
    if (g.begendim) _kalpAnimasyonu();
    unawaited(HapticFeedback.lightImpact());
    _mesgul = true;
    try {
      final s = ref.read(sosyalServisiProvider);
      if (g.begendim) {
        await s.begen(g.id);
      } else {
        await s.begeniGeriAl(g.id);
      }
    } catch (_) {
      if (!mounted) return;
      // ⚠️ GERI AL — yalan bir "beğendin" durumu birakmak, kullanicinin bir daha
      //    begenememesi demek (sunucu ile istemci kalici olarak ayrisir).
      setState(() {
        g.begendim = eskiDurum;
        g.begeniSayisi = eskiSayi;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beğeni gönderilemedi')),
      );
    } finally {
      _mesgul = false;
    }
  }

  void _kalpAnimasyonu() {
    setState(() => _kalpGoster = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _kalpGoster = false);
    });
  }

  Future<void> _kaydetCevir() async {
    final eski = g.kaydettim;
    setState(() => g.kaydettim = !eski);
    try {
      final s = ref.read(sosyalServisiProvider);
      eski ? await s.kaydetKaldir(g.id) : await s.kaydet(g.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => g.kaydettim = eski);
    }
  }

  Future<void> _yorumlariAc() async {
    final yeni = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => YorumlarSayfasi(gonderi: g, benimId: widget.benimId),
    ));
    // ⚠️ Yorum sayfasi EKLENEN/SILINEN yorum farkini geri dondurur; kart sayaci
    //    boylece yenilemeye gerek kalmadan dogru kalir.
    if (yeni != null && mounted) {
      setState(() {
        g.yorumSayisi += yeni;
        if (g.yorumSayisi < 0) g.yorumSayisi = 0;
      });
    }
  }

  Future<void> _menu() async {
    final benim = g.yazarId == widget.benimId;
    final secim = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.link),
              title: const Text('Bağlantıyı kopyala'),
              onTap: () => Navigator.pop(c, 'link'),
            ),
            if (benim)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: const Text('Gönderiyi sil',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(c, 'sil'),
              ),
            if (!benim)
              ListTile(
                leading: const Icon(LucideIcons.flag),
                title: const Text('Şikayet et'),
                onTap: () => Navigator.pop(c, 'sikayet'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || secim == null) return;
    if (secim == 'link') {
      await Clipboard.setData(ClipboardData(text: 'https://gebzem.app/p/${g.id}'));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
    } else if (secim == 'sil') {
      final onay = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Gönderi silinsin mi?'),
          content: const Text('Bu işlem geri alınamaz.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Sil', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
      if (onay != true || !mounted) return;
      try {
        await ref.read(sosyalServisiProvider).gonderiSil(g.id);
        widget.onSilindi?.call();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gönderi silinemedi')));
      }
    } else if (secim == 'sikayet') {
      await sikayetSheetAc(context, ref, hedefTur: 'gonderi', hedefId: g.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- BASLIK
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: GestureDetector(
            onTap: () => widget.profileGit?.call(g.yazarId),
            child: Avatar(
              ad: g.yazarAd,
              mediaId: g.yazarAvatarMediaId,
              avatarUrl: g.yazarAvatar,
              cap: 38,
            ),
          ),
          title: GestureDetector(
            onTap: () => widget.profileGit?.call(g.yazarId),
            child: Text(g.yazarAd,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          subtitle: Text(
            g.yazarUsername.isEmpty
                ? gonderiZamani(g.createdAt)
                : '@${g.yazarUsername} · ${gonderiZamani(g.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(LucideIcons.ellipsis),
            onPressed: _menu,
          ),
        ),

        // ---- METIN (medya ustunde — Facebook duzeni)
        if (g.metin.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(g.metin, style: const TextStyle(fontSize: 15)),
          ),

        // ---- MEDYA
        if (g.mediaIds.isNotEmpty) _medya(),

        // ---- ETKILESIM CUBUGU
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              _dugme(
                ikon: g.begendim ? LucideIcons.heart : LucideIcons.heart,
                dolu: g.begendim,
                renk: g.begendim ? Colors.red : null,
                sayi: g.begeniSayisi,
                onTap: _begeniCevir,
              ),
              _dugme(
                ikon: LucideIcons.messageCircle,
                sayi: g.yorumSayisi,
                onTap: g.yorumKapali ? null : _yorumlariAc,
              ),
              _dugme(
                ikon: LucideIcons.send,
                onTap: () => _sohbeteGonder(context),
              ),
              const Spacer(),
              // ⚠️ GORUNTULENME YALNIZ YAZARINA gosterilir (Instagram deseni):
              //    baskasinin izlenme sayisi kullaniciya bir sey ifade etmez,
              //    ustelik dusuk sayi yazari utandirir.
              if (g.yazarId == widget.benimId && g.goruntulenme > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.eye, size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(sayiBicimle(g.goruntulenme),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              IconButton(
                icon: Icon(
                  LucideIcons.bookmark,
                  color: g.kaydettim ? tema.colorScheme.primary : null,
                ),
                onPressed: _kaydetCevir,
              ),
            ],
          ),
        ),
        if (g.yorumKapali)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Yorumlar kapalı',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _medya() {
    final coklu = g.mediaIds.length > 1;
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onDoubleTap: () => _begeniCevir(yalnizBegen: true),
          child: AspectRatio(
            // ⚠️ 4:5 (dikey) — telefonla cekilen fotograflarin cogunlugu dikey;
            //    1:1 kirpsaydik ustten/alttan kesilirdi. `contain` ile kirpma YOK.
            aspectRatio: g.tur == 'reels' ? 9 / 16 : 4 / 5,
            child: ColoredBox(
              color: const Color(0xFF0B0B12),
              child: coklu
                  ? PageView.builder(
                      itemCount: g.mediaIds.length,
                      onPageChanged: (i) => setState(() => _sayfa = i),
                      itemBuilder: (_, i) => _tekMedya(g.mediaIds[i], i),
                    )
                  : _tekMedya(g.mediaIds.first, 0),
            ),
          ),
        ),
        if (_kalpGoster)
          const IgnorePointer(
            child: Icon(LucideIcons.heart,
                size: 92, color: Color(0xEEFF3B5C)),
          ),
        if (coklu)
          Positioned(
            top: 10,
            right: 12,
            child: _rozet('${_sayfa + 1}/${g.mediaIds.length}'),
          ),
        if (coklu)
          Positioned(
            bottom: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                g.mediaIds.length,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _sayfa ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _tekMedya(String id, int sira) {
    if (g.videoMu) {
      return MedyaVideo(
        mediaId: id,
        // ⚠️ Akista video SESSIZ ve ELLE baslar: otomatik oynatma mobil veriyi
        //    hizla tuketir ve bu projede olcum/kota altyapisi henuz yok.
        otoOynat: false,
        sesli: false,
        dolgu: BoxFit.contain,
      );
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TamEkranGorsel(mediaId: id),
      )),
      child: MedyaGorsel(mediaId: id, fit: BoxFit.contain),
    );
  }

  Widget _rozet(String metin) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(metin,
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      );

  Widget _dugme({
    required IconData ikon,
    VoidCallback? onTap,
    int? sayi,
    bool dolu = false,
    Color? renk,
  }) =>
      TextButton.icon(
        onPressed: onTap,
        icon: Icon(ikon, size: 21, color: renk),
        label: Text(
          (sayi == null || sayi == 0) ? '' : sayiBicimle(sayi),
          style: TextStyle(color: renk, fontWeight: FontWeight.w600),
        ),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: renk ?? Theme.of(context).iconTheme.color,
        ),
      );

  Future<void> _sohbeteGonder(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bağlantı kopyalandı — sohbete yapıştırın')),
    );
    await Clipboard.setData(ClipboardData(text: 'https://gebzem.app/p/${g.id}'));
  }
}

/// 1.2B / 43,5B / 980 gibi kisa sayi.
String sayiBicimle(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final b = n / 1000;
    return '${b.toStringAsFixed(b < 10 ? 1 : 0)}B';
  }
  final m = n / 1000000;
  return '${m.toStringAsFixed(m < 10 ? 1 : 0)}M';
}

/// "3dk", "5sa", "2g", "12 Tem" — WhatsApp/Instagram tarzi.
/// ⚠️ Sunucu saati ile cihaz saati ARASINDAKI FARK kucuk negatif degerler
///    uretebilir; "şimdi" ile kapatiliyor (kullaniciya "-2dk" gostermek yerine).
String gonderiZamani(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final f = DateTime.now().difference(t);
  if (f.inSeconds < 60) return 'şimdi';
  if (f.inMinutes < 60) return '${f.inMinutes}dk';
  if (f.inHours < 24) return '${f.inHours}sa';
  if (f.inDays < 7) return '${f.inDays}g';
  const aylar = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  return '${t.day} ${aylar[t.month - 1]}';
}
