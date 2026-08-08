import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import 'medya_gorsel.dart';

/// ⚠️⚠️ TURU 76 — KIMLIKTEN AVATAR COZUCU (kullanici sikayeti: "profil
/// fotograflari her yerde gorunmuyor").
///
/// KOK NEDEN: bir yuzey avatari ancak elindeki veri `avatar_media_id` TASIYORSA
/// cizebilir. Arama katmani bunu tasimiyordu ve TASIYAMAZDI: gelen arama VoIP
/// push / CallKit yolundan geliyor ve orada elimizde YALNIZCA kimlik var.
/// Bu yuzden "her cagirana avatar alani ekle" yaklasimi o yolda YAPISAL OLARAK
/// COZMEZ.
///
/// COZUM: kimlik -> ozet cozen TEK onbellekli katman.
///
/// ⚠️ TOPLU ISTEK (batch): ayni karede istenen kimlikler 40ms'lik pencerede
///    BIRIKTIRILIP TEK istekte cozulur. Aksi halde 20 kisilik izleyici listesi
///    20 ayri REST atardi (CLAUDE.md turu 17: "presence ucunu liste ekranlarinda
///    kisi basina cagirma — N+1").
/// ⚠️ NEGATIF ONBELLEK: cozulemeyen kimlik de saklanir (engelli/silinmis kisi
///    icin sonsuz tekrar istek atmayalim).
/// ⚠️ Onbellek SUREC OMURLU ve `logout`ta temizlenir — baska hesapla girildiginde
///    eski avatarlar gorunmemeli.
class KullaniciOzeti {
  const KullaniciOzeti({
    required this.id,
    required this.ad,
    required this.kullaniciAdi,
    required this.avatarUrl,
    required this.avatarMediaId,
  });

  final String id;
  final String ad;
  final String kullaniciAdi;
  final String avatarUrl;
  final String? avatarMediaId;

  static KullaniciOzeti json(Map<String, dynamic> m) => KullaniciOzeti(
    id: (m['id'] ?? '').toString(),
    ad: (m['name'] ?? '').toString(),
    kullaniciAdi: (m['username'] ?? '').toString(),
    avatarUrl: (m['avatar_url'] ?? '').toString(),
    avatarMediaId: m['avatar_media_id'] as String?,
  );
}

class OzetDeposu {
  OzetDeposu(this._ref);

  final Ref _ref;

  final Map<String, KullaniciOzeti?> _onbellek = {};
  final Set<String> _bekleyen = {};
  final List<Completer<void>> _bekleyenler = [];
  Timer? _pencere;

  /// Onbellekteki deger (varsa). `null` = bilinmiyor VEYA cozulemedi.
  KullaniciOzeti? bak(String id) => _onbellek[id];

  bool biliniyorMu(String id) => _onbellek.containsKey(id);

  /// Kimligi cozer. Zaten biliniyorsa ISTEK ATMAZ.
  Future<KullaniciOzeti?> coz(String id) async {
    if (id.isEmpty) return null;
    if (_onbellek.containsKey(id)) return _onbellek[id];
    _bekleyen.add(id);
    final c = Completer<void>();
    _bekleyenler.add(c);
    // ⚠️ 40ms: bir kare (16ms) icinde olusan tum istekleri yakalamaya yeter,
    //    kullaniciya gecikme olarak HISSEDILMEZ.
    _pencere ??= Timer(const Duration(milliseconds: 40), _bosalt);
    await c.future;
    return _onbellek[id];
  }

  Future<void> _bosalt() async {
    _pencere = null;
    final idler = _bekleyen.toList();
    _bekleyen.clear();
    final bekleyenler = List<Completer<void>>.from(_bekleyenler);
    _bekleyenler.clear();
    if (idler.isEmpty) {
      for (final c in bekleyenler) {
        if (!c.isCompleted) c.complete();
      }
      return;
    }
    try {
      // ⚠️ Sunucu tavani 50 — daha fazlasi PARCA PARCA gonderilir.
      for (var i = 0; i < idler.length; i += 50) {
        final parca = idler.sublist(i, (i + 50).clamp(0, idler.length));
        final r = await _ref
            .read(apiProvider)
            .get('/users/ozet', queryParameters: {'ids': parca.join(',')});
        for (final e in (r.data as List?) ?? []) {
          final o = KullaniciOzeti.json((e as Map).cast<String, dynamic>());
          _onbellek[o.id] = o;
        }
        // ⚠️ NEGATIF ONBELLEK: yanitta gelmeyen kimlikler (engelli/silinmis)
        //    `null` olarak isaretlenir; aksi halde her cizimde tekrar sorulur.
        for (final id in parca) {
          _onbellek.putIfAbsent(id, () => null);
        }
      }
    } catch (_) {
      // ⚠️ HATA'DA ONBELLEGE YAZMA: gecici ag hatasi kaliciya donusmesin
      //    (bir sonraki cizimde tekrar denenir).
    } finally {
      for (final c in bekleyenler) {
        if (!c.isCompleted) c.complete();
      }
    }
  }

  /// ⚠️ Cikista ZORUNLU — baska hesapla girildiginde eski avatarlar gorunmemeli.
  void temizle() {
    _onbellek.clear();
    _bekleyen.clear();
    _pencere?.cancel();
    _pencere = null;
  }
}

final ozetDeposuProvider = Provider<OzetDeposu>(OzetDeposu.new);

/// Kimlikten avatar cizen widget. Ozet gelene kadar HARF avatari gosterir —
/// yani ekranda ASLA bosluk/atlama olmaz (yer tutucu ile ayni boyut).
class KimlikAvatar extends ConsumerStatefulWidget {
  const KimlikAvatar({
    super.key,
    required this.userId,
    this.yedekAd = '',
    this.cap = 40,
  });

  final String userId;
  final String yedekAd;
  final double cap;

  @override
  ConsumerState<KimlikAvatar> createState() => _KimlikAvatarState();
}

class _KimlikAvatarState extends ConsumerState<KimlikAvatar> {
  KullaniciOzeti? _ozet;

  @override
  void initState() {
    super.initState();
    _coz();
  }

  @override
  void didUpdateWidget(covariant KimlikAvatar eski) {
    super.didUpdateWidget(eski);
    if (eski.userId != widget.userId) {
      _ozet = null;
      _coz();
    }
  }

  Future<void> _coz() async {
    final depo = ref.read(ozetDeposuProvider);
    // Onbellekte varsa SENKRON kullan — gereksiz bir kare gecikmesi olmasin.
    if (depo.biliniyorMu(widget.userId)) {
      _ozet = depo.bak(widget.userId);
      return;
    }
    final o = await depo.coz(widget.userId);
    if (mounted) setState(() => _ozet = o);
  }

  @override
  Widget build(BuildContext context) => Avatar(
    ad: _ozet?.ad.isNotEmpty == true ? _ozet!.ad : widget.yedekAd,
    mediaId: _ozet?.avatarMediaId,
    avatarUrl: _ozet?.avatarUrl ?? '',
    cap: widget.cap,
  );
}
