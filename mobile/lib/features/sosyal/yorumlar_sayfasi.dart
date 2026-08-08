import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chats/moderasyon_sheet.dart';
import '../medya/medya_gorsel.dart';
import 'gonderi_karti.dart' show gonderiZamani, sayiBicimle;
import 'sosyal_servisi.dart';

/// ⚠️⚠️ TURU 75 — YORUMLAR.
///
/// ⚠️ GERI DONUS DEGERI: sayfa kapanirken **yorum sayisi FARKI** (`+1`, `-2`...)
///    dondurulur. Kart bunu sayacina ekler. Alternatif "tum akisi yenile" olurdu;
///    o da kaydirma konumunu SIFIRLAR (kullanici okudugu yeri kaybeder).
///
/// ⚠️ YANIT TEK SEVIYE (backend `parent_id` semasiyla ayni): sinirsiz ic ice
///    yorum hem okunmuyor hem sorguyu ozyinelemeli yapiyor.
class YorumlarSayfasi extends ConsumerStatefulWidget {
  const YorumlarSayfasi({
    super.key,
    required this.gonderi,
    required this.benimId,
  });

  final Gonderi gonderi;
  final String benimId;

  @override
  ConsumerState<YorumlarSayfasi> createState() => _YorumlarSayfasiState();
}

class _YorumlarSayfasiState extends ConsumerState<YorumlarSayfasi> {
  final _kutu = TextEditingController();
  final _odak = FocusNode();
  List<Yorum> _liste = [];
  bool _yukleniyor = true;
  bool _gonderiliyor = false;
  String? _hata;

  /// Yanitlanan yorum (tek seviye — yanitin yaniti ANA yoruma baglanir).
  Yorum? _yanitlanan;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _kutu.dispose();
    _odak.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final l = await ref
          .read(sosyalServisiProvider)
          .yorumlar(widget.gonderi.id);
      if (!mounted) return;
      setState(() {
        _liste = l;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Yorumlar yüklenemedi';
      });
    }
  }

  Future<void> _gonder() async {
    final metin = _kutu.text.trim();
    if (metin.isEmpty || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    try {
      // ⚠️ Yanitin yaniti: kok yoruma baglanir (`parentId ?? id`) — backend de
      //    ayni normalizasyonu yapar, iki taraf ayrisamaz.
      final ust = _yanitlanan == null
          ? null
          : (_yanitlanan!.parentId ?? _yanitlanan!.id);
      await ref
          .read(sosyalServisiProvider)
          .yorumYaz(widget.gonderi.id, metin, parentId: ust);
      if (!mounted) return;
      _kutu.clear();
      _yanitlanan = null;
      widget.gonderi.yorumSayisi++;
      // ⚠️ Listeyi TAM YENILE: sunucu yorumu normalize edebilir (kirpma, filtre)
      //    ve yerelde uydurdugumuz satir sunucudakinden FARKLI gorunurdu.
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_hataMetni(e))));
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  String _hataMetni(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'Bu gönderiye yorum yapamazsınız';
    if (s.contains('404')) return 'Gönderi bulunamadı';
    return 'Yorum gönderilemedi';
  }

  Future<void> _sil(Yorum y) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Yorum silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      await ref.read(sosyalServisiProvider).yorumSil(y.id);
      if (!mounted) return;
      setState(() {
        // Kok yorum silinince yanitlari da gider (DB'de ON DELETE CASCADE).
        final gidenSayi = _liste
            .where((x) => x.id == y.id || x.parentId == y.id)
            .length;
        _liste.removeWhere((x) => x.id == y.id || x.parentId == y.id);
        widget.gonderi.yorumSayisi = (widget.gonderi.yorumSayisi - gidenSayi)
            .clamp(0, 1 << 30);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yorum silinemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️⚠️ TURU 75b (DENETIM BULGUSU): `PopScope(canPop: false)` KALDIRILDI.
    //    Geri donus DEGERI acisindan dogruydu ama BEDELI agirdi: Flutter
    //    `CupertinoRouteTransitionMixin._isPopGestureEnabled` icinde
    //    `popDisposition == doNotPop` gorunce KENAR KAYDIRMA jestini KAPATIR
    //    -> iPhone'da yorumlardan cikmanin TEK yolu AppBar oku kalirdi.
    // ⚠️ COZUM: sayac PAYLASILAN MUTABLE MODEL uzerinden guncelleniyor
    //    (`widget.gonderi` cagiranla AYNI nesne). Geri donus degerine gerek YOK,
    //    dolayisiyla jesti kisitlamaya da gerek yok.
    // ⚠️ YAPMA: buraya tekrar `canPop: false` koyma.
    return Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Yorumlar')),
        body: Column(
          children: [
            Expanded(child: _govde()),
            if (_yanitlanan != null)
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '@${_yanitlanan!.yazarUsername} yanıtlanıyor',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => setState(() => _yanitlanan = null),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _kutu,
                        focusNode: _odak,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Yorum yaz...',
                          counterText: '',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: _gonderiliyor
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.send),
                      onPressed: _gonderiliyor ? null : _gonder,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _govde() {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hata != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_hata!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _yukle, child: const Text('Tekrar dene')),
          ],
        ),
      );
    }
    if (_liste.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Henüz yorum yok. İlk yorumu sen yaz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    // Kokler + altlarinda yanitlari (sunucu zaten kok-sonra-yanit siralar; yine de
    // burada gruplandiriyoruz ki siralamadan BAGIMSIZ dogru cizilsin).
    final kokler = _liste.where((y) => y.parentId == null).toList();
    return ListView.builder(
      itemCount: kokler.length,
      itemBuilder: (_, i) {
        final k = kokler[i];
        final yanitlar = _liste.where((y) => y.parentId == k.id).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _satir(k, girinti: 0),
            ...yanitlar.map((y) => _satir(y, girinti: 44)),
          ],
        );
      },
    );
  }

  Widget _satir(Yorum y, {required double girinti}) {
    final benim = y.yazarId == widget.benimId;
    final gonderiSahibi = widget.gonderi.yazarId == widget.benimId;
    return Padding(
      padding: EdgeInsets.fromLTRB(12 + girinti, 8, 12, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(
            ad: y.yazarAd,
            mediaId: y.yazarAvatarMediaId,
            avatarUrl: y.yazarAvatar,
            cap: girinti > 0 ? 26 : 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        y.yazarAd,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      gonderiZamani(y.createdAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(y.metin, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (girinti == 0)
                      _kucukDugme(
                        'Yanıtla',
                        () => setState(() {
                          _yanitlanan = y;
                          _odak.requestFocus();
                        }),
                      ),
                    if (y.begeniSayisi > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '${sayiBicimle(y.begeniSayisi)} beğeni',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    // ⚠️ GONDERI SAHIBI de silebilir — kendi gonderisindeki tacizi
                    //    kaldirabilmeli (App Store 1.2). Backend de ayni kurali uygular.
                    if (benim || gonderiSahibi)
                      _kucukDugme('Sil', () => _sil(y)),
                    if (!benim)
                      _kucukDugme(
                        'Şikayet',
                        () => sikayetSheetAc(
                          context,
                          ref,
                          hedefTur: 'yorum',
                          hedefId: '${y.id}',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kucukDugme(String metin, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 28),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      metin,
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    ),
  );
}
