import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../sosyal/gonderi_karti.dart' show gonderiZamani, sayiBicimle;
import 'kanal_ekrani.dart';
import 'kanal_olustur.dart';
import 'kanal_servisi.dart';

/// ⚠️⚠️ TURU 75 — KANALLAR (WhatsApp "Kanallar" sekmesi).
///
/// ⚠️ Akis sekmesinin ICINDE bir bolme olarak yasar (`AkisEkrani` ustundeki
///    segment). AYRI ALT SEKME ACILMADI: alt menude 6 hedef var ve 7.'si
///    etiketleri okunmaz hale getirir.
class KanallarSekmesi extends ConsumerStatefulWidget {
  const KanallarSekmesi({super.key});

  @override
  ConsumerState<KanallarSekmesi> createState() => _KanallarSekmesiState();
}

class _KanallarSekmesiState extends ConsumerState<KanallarSekmesi>
    with AutomaticKeepAliveClientMixin {
  List<Kanal> _benim = [];
  List<Kanal> _kesfet = [];
  bool _yukleniyor = true;
  String? _hata;
  final _arama = TextEditingController();
  Timer? _aramaGecikme;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaGecikme?.cancel();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final s = ref.read(kanalServisiProvider);
      // ⚠️ Iki istek PARALEL (`Future.wait`) — seri olsaydi acilis iki gidis
      //    donus surerdi. Biri patlarsa ikisi de patlar; kismi basari icin
      //    ayri try gerekirdi ama iki liste de ayni ekranin parcasi.
      final sonuc = await Future.wait([s.listem(), s.kesfet()]);
      if (!mounted) return;
      setState(() {
        _benim = sonuc[0];
        _kesfet = sonuc[1];
        _yukleniyor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Kanallar yüklenemedi';
      });
    }
  }

  void _aramaDegisti(String q) {
    // ⚠️ 350ms GECIKME: her harfte istek atmak hem sunucuyu hem mobil veriyi
    //    bosuna yorar (`LIKE` sorgusu ucuz degil).
    _aramaGecikme?.cancel();
    _aramaGecikme = Timer(const Duration(milliseconds: 350), () async {
      try {
        final l = await ref.read(kanalServisiProvider).kesfet(q: q.trim());
        if (mounted) setState(() => _kesfet = l);
      } catch (_) {}
    });
  }

  Future<void> _kanalAc(Kanal k) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KanalEkrani(kanalId: k.id, onIsim: k.ad),
      ),
    );
    // Donuste okunmamis rozeti ve abonelik durumu degismis olabilir.
    if (mounted) unawaited(_yukle());
  }

  Future<void> _olustur() async {
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const KanalOlustur()));
    if (id != null && mounted) {
      await _yukle();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KanalEkrani(kanalId: id, onIsim: 'Kanal'),
        ),
      );
      if (mounted) unawaited(_yukle());
    }
  }

  Future<void> _aboneOl(Kanal k) async {
    final eski = k.aboneMiyim;
    setState(() {
      k.aboneMiyim = !eski;
      k.aboneSayisi = (k.aboneSayisi + (eski ? -1 : 1)).clamp(0, 1 << 30);
    });
    try {
      final s = ref.read(kanalServisiProvider);
      eski ? await s.abonelikBirak(k.id) : await s.aboneOl(k.id);
      if (mounted) unawaited(_yukle());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        k.aboneMiyim = eski;
        k.aboneSayisi = (k.aboneSayisi + (eski ? 1 : -1)).clamp(0, 1 << 30);
      });
      // ⚠️ Sunucunun GERCEK sebebini goster — genel "işlem tamamlanamadı"
      //    kullaniciyi cozumden uzaklastirir (kanal_ekrani ile AYNI davranis).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('400')
                ? 'Kendi kanalınızdan çıkamazsınız'
                : 'İşlem tamamlanamadı',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _olustur,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Kanal aç'),
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
            : ListView(
                padding: const EdgeInsets.only(bottom: 90),
                children: [
                  if (_benim.isNotEmpty) ...[
                    _baslik('Kanallarım'),
                    ..._benim.map(_benimSatir),
                    const Divider(height: 24),
                  ],
                  _baslik('Keşfet'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: TextField(
                      controller: _arama,
                      onChanged: _aramaDegisti,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LucideIcons.search, size: 18),
                        hintText: 'Kanal ara',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_kesfet.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Kanal bulunamadı',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ..._kesfet.map(_kesfetSatir),
                ],
              ),
      ),
    );
  }

  Widget _baslik(String m) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
    child: Text(
      m,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );

  Widget _benimSatir(Kanal k) => ListTile(
    leading: Avatar(ad: k.ad, mediaId: k.avatarMediaId, cap: 46),
    title: Row(
      children: [
        Expanded(
          child: Text(
            k.ad,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (k.sessiz)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(LucideIcons.bellOff, size: 14, color: Colors.grey),
          ),
        if (k.sonZaman.isNotEmpty)
          Text(
            gonderiZamani(k.sonZaman),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    ),
    subtitle: Text(
      k.sonMetin.isEmpty ? 'Henüz gönderi yok' : k.sonMetin,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    ),
    trailing: k.okunmamis > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              k.okunmamis > 99 ? '99+' : '${k.okunmamis}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : null,
    onTap: () => _kanalAc(k),
  );

  Widget _kesfetSatir(Kanal k) => ListTile(
    leading: Avatar(ad: k.ad, mediaId: k.avatarMediaId, cap: 46),
    title: Text(
      k.ad,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(
      k.aciklama.isEmpty
          ? '${sayiBicimle(k.aboneSayisi)} abone'
          : '${sayiBicimle(k.aboneSayisi)} abone · ${k.aciklama}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
    trailing: OutlinedButton(
      onPressed: () => _aboneOl(k),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        k.aboneMiyim ? 'Abonesin' : 'Abone ol',
        style: const TextStyle(fontSize: 12),
      ),
    ),
    onTap: () => _kanalAc(k),
  );
}
