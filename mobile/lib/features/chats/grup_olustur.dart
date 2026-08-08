import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../medya/medya_gorsel.dart';
import '../medya/medya_kapisi.dart';
import '../medya/medya_servisi.dart';
import 'chats_provider.dart';

/// ⚠️⚠️ TURU 76 — GRUP SOHBETI OLUSTURMA (kullanici emri: "grup olusturma yok").
///
/// ⚠️ IKI ADIM: (1) kisi sec, (2) grup adi + fotograf. WhatsApp deseni.
///    Tek ekranda birlestirmek dar telefonlarda listeyi kullanilmaz yapar.
///
/// ⚠️ ENGEL: sunucu engelli kisiyi gruba EKLEMEZ ve 403 doner. Arama ucu zaten
///    engellileri elediginden pratikte gorulmez, ama istemci sunucunun
///    hatasini AYNEN gosterir (sessiz basarisizlik YOK).
class GrupOlusturEkrani extends ConsumerStatefulWidget {
  const GrupOlusturEkrani({super.key});

  @override
  ConsumerState<GrupOlusturEkrani> createState() => _GrupOlusturEkraniState();
}

class _GrupOlusturEkraniState extends ConsumerState<GrupOlusturEkrani> {
  final _arama = TextEditingController();
  final _ad = TextEditingController();
  Timer? _gecikme;

  List<Map<String, dynamic>> _sonuclar = [];
  /// Secilenler — id -> kullanici. ⚠️ Map: ayni kisi iki kez eklenmesin.
  final Map<String, Map<String, dynamic>> _secili = {};

  bool _ikinciAdim = false;
  bool _araniyor = false;
  bool _kaydediliyor = false;
  File? _avatar;

  @override
  void dispose() {
    _gecikme?.cancel();
    _arama.dispose();
    _ad.dispose();
    super.dispose();
  }

  void _aramaDegisti(String v) {
    _gecikme?.cancel();
    if (v.trim().length < 2) {
      setState(() => _sonuclar = []);
      return;
    }
    // ⚠️ 350ms gecikme — her tusa basista istek atmak sunucuyu bosuna yorar
    //    (`user_search_screen` ile ayni desen).
    _gecikme = Timer(const Duration(milliseconds: 350), () => _ara(v.trim()));
  }

  Future<void> _ara(String q) async {
    setState(() => _araniyor = true);
    try {
      final r = await ref
          .read(apiProvider)
          .get('/users/search', queryParameters: {'q': q});
      if (!mounted) return;
      setState(() => _sonuclar = (r.data as List).cast<Map<String, dynamic>>());
    } catch (_) {
      // Sessiz: arama kritik degil, kullanici tekrar yazabilir.
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  Future<void> _avatarSec() async {
    if (!MedyaKapisi.izinVer(ref)) {
      _uyar(MedyaKapisi.engelSebebi(ref) ?? 'Şu anda fotoğraf seçilemez');
      return;
    }
    XFile? x;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (_) {
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    if (x == null || !mounted) return;
    setState(() => _avatar = File(x!.path));
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _olustur() async {
    final ad = _ad.text.trim();
    if (ad.isEmpty) {
      _uyar('Grup adı gerekli');
      return;
    }
    setState(() => _kaydediliyor = true);
    try {
      String avatarID = '';
      if (_avatar != null) {
        // ⚠️ EXIF (KONUM) TEMIZLIGI ZORUNLU — sunucu GPS bulursa 422 doner.
        final hazir = await MedyaServisi.gorseliHazirla(_avatar!);
        if (hazir == null) throw Exception('Fotoğraf hazırlanamadı');
        avatarID = await ref.read(medyaServisiProvider).yukle(
              dosya: hazir,
              kind: 'avatar',
              mime: 'image/jpeg',
            );
      }
      final r = await ref.read(apiProvider).post('/chats/group', data: {
        'title': ad,
        'avatar_media_id': avatarID,
        'member_ids': _secili.keys.toList(),
      });
      if (!mounted) return;
      await ref.read(chatsProvider.notifier).load();
      if (!mounted) return;
      Navigator.of(context).pop(r.data['chat_id'] as String?);
    } catch (e) {
      if (!mounted) return;
      setState(() => _kaydediliyor = false);
      // ⚠️ Sunucunun GERCEK metnini goster ("seçtiğiniz kişilerden biri gruba
      //    eklenemiyor" gibi) — genel hata kullaniciyi cozumden uzaklastirir.
      _uyar(apiErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_ikinciAdim ? 'Grup bilgileri' : 'Kişi seç'),
        actions: [
          if (!_ikinciAdim)
            TextButton(
              onPressed: _secili.isEmpty
                  ? null
                  : () => setState(() => _ikinciAdim = true),
              child: Text('İleri (${_secili.length})'),
            )
          else
            TextButton(
              onPressed: _kaydediliyor ? null : _olustur,
              child: const Text('Oluştur'),
            ),
        ],
      ),
      body: _ikinciAdim ? _bilgiAdimi() : _kisiAdimi(),
    );
  }

  // ---------------- ADIM 1: KISI SEC ----------------
  Widget _kisiAdimi() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              controller: _arama,
              autofocus: true,
              onChanged: _aramaDegisti,
              decoration: InputDecoration(
                hintText: 'İsim veya @kullanıcıadı ara',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _araniyor
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // Secilenler yatay serit — kimi sectigini surekli gorsun.
          if (_secili.isNotEmpty)
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: _secili.values.map((u) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: 62,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Avatar(
                                ad: (u['name'] ?? '').toString(),
                                mediaId: u['avatar_media_id'] as String?,
                                cap: 46,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => _secili.remove(u['id'] as String)),
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                        color: Color(0xCC000000),
                                        shape: BoxShape.circle),
                                    child: Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(LucideIcons.x,
                                          size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (u['name'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _sonuclar.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Text(
                        'Gruba eklemek istediğin kişileri ara ve seç.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _sonuclar.length,
                    itemBuilder: (_, i) {
                      final u = _sonuclar[i];
                      final id = (u['id'] ?? '').toString();
                      final seciliMi = _secili.containsKey(id);
                      return CheckboxListTile(
                        value: seciliMi,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _secili[id] = u;
                          } else {
                            _secili.remove(id);
                          }
                        }),
                        secondary: Avatar(
                          ad: (u['name'] ?? '').toString(),
                          mediaId: u['avatar_media_id'] as String?,
                          cap: 44,
                        ),
                        title: Text((u['name'] ?? '').toString()),
                        subtitle: Text('@${u['username'] ?? ''}'),
                      );
                    },
                  ),
          ),
        ],
      );

  // ---------------- ADIM 2: GRUP BILGILERI ----------------
  Widget _bilgiAdimi() => AbsorbPointer(
        absorbing: _kaydediliyor,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Center(
              child: GestureDetector(
                onTap: _avatarSec,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    if (_avatar != null)
                      ClipOval(
                        child: Image.file(_avatar!,
                            width: 96, height: 96, fit: BoxFit.cover),
                      )
                    else
                      Avatar(ad: _ad.text, cap: 96),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(LucideIcons.camera,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ad,
              autofocus: true,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Grup adı',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            Text('${_secili.length} kişi',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._secili.values.map((u) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Avatar(
                    ad: (u['name'] ?? '').toString(),
                    mediaId: u['avatar_media_id'] as String?,
                    cap: 40,
                  ),
                  title: Text((u['name'] ?? '').toString()),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () =>
                        setState(() => _secili.remove(u['id'] as String)),
                  ),
                )),
            if (_kaydediliyor) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      );
}
