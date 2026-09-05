import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../sosyal/demo_veri.dart' show demoKimlik;
import 'medya_servisi.dart';

/// ⚠️⚠️ TURU 74 — İMZALI MEDYA GÖRÜNTÜLEYİCİ.
///
/// Sorun: bucket **private**, indirme adresi **600 saniye ömürlü imzalı URL**.
/// Bu yüzden doğrudan `Image.network(url)` KULLANILAMAZ:
///   · URL her çağrıda değişir → `cached_network_image` onu YENİ görsel sanar ve
///     aynı fotoğrafı **her açılışta yeniden indirir** (kullanıcının mobil verisi
///     + R2 Class B ücreti),
///   · URL süresi dolunca görsel kırık görünür.
///
/// Çözüm: adres `media_id`'ye göre alınır, **önbellek anahtarı `media_id`'dir**
/// (URL değil). Böylece imza değişse de dosya bir kez inip cihazda kalır.
/// ⚠️ YAPMA: `cacheKey`i kaldırma; URL'i önbellek anahtarı yapma.
///
/// ⚠️ Adres 600 sn geçerli olduğu için bellekte kısa süreli tutulur; süresi
///     dolmadan yeniden istenmez (`_adresOnbellek`).
/// ⚠️⚠️ TURU 91 — DECODE GENISLIGI (performans).
///
/// Bir gorselin BELLEGE KAC PIKSEL genisliginde cozulecegini soyler.
/// `CachedNetworkImage.memCacheWidth` bunu alir ve gorseli o boyutta
/// cozer — dosya diskte tam cozunurlukte kalir, yalnizca RAM'deki kopya
/// kucultulur.
///
/// ⚠️ FIZIKSEL PIKSEL: `devicePixelRatio` ile carpilir. Mantiksal dp
///    kullanilsaydi retina ekranda gorsel BULANIK cikardi.
/// ⚠️ Tavan 2048: cok buyuk bir `width` verilse bile decode maliyeti
///    patlamasin.
int _decodeGenisligiHesapla(BuildContext c, double? width, bool kucuk) {
  final dpr = MediaQuery.devicePixelRatioOf(c);
  final w = width ?? (kucuk ? 320.0 : 1080.0);
  return (w * dpr).round().clamp(64, 2048);
}

class MedyaGorsel extends ConsumerStatefulWidget {
  const MedyaGorsel({
    super.key,
    required this.mediaId,
    this.kucuk = false,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.radius = 0,
  });

  final String mediaId;

  /// Küçük resim (thumb) mi istensin. Liste/balon için `true` — tam çözünürlüklü
  /// dosyayı indirmek gereksiz veri harcar.
  final bool kucuk;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double radius;

  @override
  ConsumerState<MedyaGorsel> createState() => _MedyaGorselState();
}

/// media_id -> (url, sonKullanma). Süreç ömürlü, küçük.
final _adresOnbellek = <String, ({String url, DateTime bitis})>{};

/// ⚠️ TURU 74b: çıkışta temizlenir — hesap değişince önceki hesabın imzalı
///     adresleri 600 sn bellekte kalıyordu.
void medyaAdresOnbelleginiTemizle() => _adresOnbellek.clear();

class _MedyaGorselState extends ConsumerState<MedyaGorsel> {
  String? _url;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    _adresAl();
  }

  @override
  void didUpdateWidget(covariant MedyaGorsel eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Liste geri dönüşümünde (ListView) aynı widget farklı media_id ile
    //     yeniden kullanılır — adresi TAZELEMEZSEK yanlış görsel çizilir.
    if (eski.mediaId != widget.mediaId || eski.kucuk != widget.kucuk) {
      _url = null;
      _hata = false;
      _adresAl();
    }
  }

  /// ⚠️⚠️⚠️ TURU 104 — **DEMO MEDYASI AGA CIKMAZ.**
  ///
  ///	Denetim bulgusu: demo kimlikleri (`demo-...`) sunucuda YOK; istek
  ///	404 donuyor, `_hata` true oluyor ve kutuya **KIRIK GORSEL ikonu**
  ///	(`imageOff`) ciziliyordu. Kullanicinin istedigi *"gri icerikler"*
  ///	yerine ekran BOZUK gorunuyordu — demoya bakan biri bunu GERCEK HATA
  ///	sanar (bu projede kayitli bir hata sinifi).
  /// ⚠️ Ayrica her akis cizimi ~10 BOSA ISTEK atiyordu.
  /// ⚠️ Yer tutucu **BOS**: ikon/harf/desen YOK — demo icerigi gercek
  ///    icerikle karistirilamasin.
  bool get _demoMedya => demoKimlik(widget.mediaId);

  Future<void> _adresAl() async {
    if (_demoMedya) return;
    final anahtar = '${widget.mediaId}:${widget.kucuk}';
    // ⚠️ TURU 74b: süresi geçmiş kayıtları ayıkla — global harita hiç
    //    tahliye edilmiyordu, uzun oturumda monoton büyüyordu.
    if (_adresOnbellek.length > 200) {
      final simdi = DateTime.now();
      _adresOnbellek.removeWhere((_, v) => v.bitis.isBefore(simdi));
    }
    final onbellek = _adresOnbellek[anahtar];
    // ⚠️ 60 sn pay: indirme başlarken imzanın dolmasına yakın olmasın.
    if (onbellek != null &&
        onbellek.bitis.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      if (mounted) setState(() => _url = onbellek.url);
      return;
    }
    try {
      final d = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      final u = (widget.kucuk ? d['thumb_url'] : d['url']) as String? ??
          d['url'] as String?;
      if (u == null) throw Exception('adres yok');
      final sn = (d['expires_sec'] as num?)?.toInt() ?? 600;
      _adresOnbellek[anahtar] =
          (url: u, bitis: DateTime.now().add(Duration(seconds: sn)));
      if (mounted) setState(() => _url = u);
    } catch (_) {
      if (mounted) setState(() => _hata = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget ic;
    if (_demoMedya) {
      ic = _kutu(const SizedBox.shrink());
    } else if (_hata) {
      ic = _kutu(const Icon(LucideIcons.imageOff, size: 22, color: Colors.white54));
    } else if (_url == null) {
      ic = _kutu(const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2)));
    } else {
      ic = CachedNetworkImage(
        imageUrl: _url!,
        // ⚠️⚠️ SABIT ANAHTAR — bkz. sınıf şerhi. URL değişse de aynı dosya.
        cacheKey: medyaOnbellekAnahtari(widget.mediaId, kucuk: widget.kucuk),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        // ⚠️⚠️⚠️ TURU 91 PERFORMANS — **DECODE COZUNURLUGU SINIRLANIR.**
        //
        //    Kullanici: *"uygulama sanki bir tik kasiyor gibi"*.
        //    Bu bayrak VERILMEDIGINDE 1600x1600 bir fotograf, 120dp'lik bir
        //    izgara hucresi icin TAM COZUNURLUKTE cozuluyordu: kare basina
        //    ~10 MB gecici RAM + CPU. Bir izgarada 12 hucre varsa bedel
        //    ~120 MB'lik decode isidir ve takilma BURADAN gelir.
        //
        // ⚠️ `devicePixelRatio` ILE CARPILIR: yoksa retina ekranda gorsel
        //    BULANIK cikardi (mantiksal dp degil FIZIKSEL piksel gerekir).
        // ⚠️ `width` verilmediyse iki makul taban: kucuk mod (izgara/avatar)
        //    icin 320, tam genislik icin 1080. Sinirsiz birakmak, tam da
        //    duzeltmeye calistigimiz sorunu geri getirirdi.
        // ⚠️ YAPMA: bu satiri kaldirma ya da `null` yapma.
        memCacheWidth:
            _decodeGenisligiHesapla(context, widget.width, widget.kucuk),
        placeholder: (_, _) => _kutu(const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, _, _) =>
            _kutu(const Icon(LucideIcons.imageOff, size: 22, color: Colors.white54)),
      );
    }
    if (widget.radius > 0) {
      return ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: ic);
    }
    return ic;
  }

  Widget _kutu(Widget cocuk) => Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0x22000000),
        alignment: Alignment.center,
        child: cocuk,
      );
}

/// Profil fotoğrafı — `avatar_media_id` varsa R2'den, yoksa harfli yedek.
/// ⚠️ Eski kayıtlarda `avatar_url` dolu olabilir; o alan artık YALNIZCA sunucu
///     tarafından yazılır (turu 74 güvenlik kararı) ve okunmaya devam eder.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.ad,
    this.mediaId,
    this.avatarUrl = '',
    this.cap = 44,
    this.sade = false,
  });

  final String ad;
  final String? mediaId;
  final String avatarUrl;
  final double cap;

  /// TURU 171d - **SADE MOD** (kullanici emri: *"profil fotografi yoksa
  ///	da sagdaki gunes ve paranin arkasindaki o divin rengi olsun,
  ///	icinde a b karakter soru isareti olmasin"*).
  ///
  /// UYARI Varsayilan `false`: harfli avatar 20+ yerde kullaniliyor
  ///	(sohbet listesi, yorumlar, katilimcilar) ve orada harf
  ///	kisileri AYIRT ETMEYE yariyor. Yalniz anasayfa basliginda
  ///	sade istendi.
  final bool sade;

  @override
  Widget build(BuildContext context) {
    if (mediaId != null && mediaId!.isNotEmpty) {
      return SizedBox(
        width: cap,
        height: cap,
        child: MedyaGorsel(
          mediaId: mediaId!,
          kucuk: true,
          width: cap,
          height: cap,
          radius: cap / 2,
        ),
      );
    }
    final harf = ad.trim().isEmpty ? '?' : ad.trim()[0].toUpperCase();
    // TURU 171d - sade modda cip zemini + IC YAZI YOK (bkz. `sade` serhi).
    if (sade && avatarUrl.isEmpty) {
      return Container(
        width: cap,
        height: cap,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // UYARI Ciplerle AYNI ifade (`onSurface` %7): ayri bir sabit
          //    yazilsaydi biri degisince oteki geride kalirdi.
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.07),
        ),
      );
    }
    return CircleAvatar(
      radius: cap / 2,
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isNotEmpty
          ? null
          : Text(harf, style: TextStyle(fontSize: cap * 0.4)),
    );
  }
}

/// ⚠️⚠️⚠️ TURU 78b — LISTE/KART KAPAK GORSELI. **TEK KAYNAK** (denetim bulgusu).
///
/// **SORUN:** `media_kinds` FAZ 1/2/4'te tam olarak "video id'sini goruntu
/// bilesenine verme" hatasini onlemek icin eklendi — ama YALNIZ DETAY
/// ekranlarinda okunuyordu. Ilan liste satiri, etkinlik karti, duzenleme
/// seritleri ve `/vitrin` slayti hala `mediaIds.first`i dogrudan
/// `MedyaGorsel`e veriyordu.
///
/// **SAHADAKI SONUC:** yalnizca VIDEO iceren bir ilan/etkinlik (form buna izin
/// veriyor) listede **KIRIK GORSEL** cizerdi. Zincir: video yuklemesinde
/// kucuk resim GONDERILMIYOR -> `thumb_url` bos -> `MedyaGorsel` ham `url`e
/// duser -> o bir **video/mp4** adresidir -> `CachedNetworkImage` cozemez.
///
/// ⚠️ TEST SIRASI TUZAGI: form once fotograflari, sonra videolari yukluyor;
///    yani "once foto sonra video" eklenen her denemede `mediaIds[0]` HEP
///    fotograf olur ve hata HIC GORUNMEZ. Yalniz-video senaryosunda cikar.
///
/// ⚠️ LISTEDE OYNATICI KURULMAZ: her satirda `MedyaVideo` kurmak hem pahali
///    hem de iOS'ta ses oturumuna dokunup SUREN ARAMAYI sagirlastirir
///    (turu 64/65/73). Video icin sessiz bir YER TUTUCU cizilir.
class KapakGorseli extends StatelessWidget {
  const KapakGorseli({
    super.key,
    required this.mediaIds,
    required this.mediaKinds,
    this.width,
    this.fit = BoxFit.cover,
    this.kucuk = true,
  });

  final List<String> mediaIds;

  /// ⚠️ `mediaKinds[i]` <-> `mediaIds[i]`. Sunucu SIRA KORUYARAK donduruyor.
  ///    Bos gelirse (eski sunucu) hepsi FOTOGRAF sayilir — guvenli varsayilan.
  final List<String> mediaKinds;
  final BoxFit fit;
  final bool kucuk;

  /// ⚠️⚠️ TURU 106 — **DECODE GENISLIGI.** Verilmezse `MedyaGorsel`
  ///	`kucuk ? 320 : 1080` varsayar; 16:9 bir kart kapaginda 320 px
  ///	BULANIK, 1080 px ise gereksiz RAM demektir. Yemek karti bunu
  ///	acikca veriyor (serhi: yoksa 2048px decode, ~9 MB gecici RAM/kart).
  final double? width;

  /// ⚠️ ILK **FOTOGRAF**I secer, ilk MEDYAYI degil. Tur bilinmiyorsa
  ///    (liste bos) ilk medya fotograf varsayilir.
  static String? ilkGorsel(List<String> ids, List<String> kinds) {
    for (var i = 0; i < ids.length; i++) {
      final t = i < kinds.length ? kinds[i] : 'image';
      if (t == 'image') return ids[i];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final id = ilkGorsel(mediaIds, mediaKinds);
    if (id != null) {
      return MedyaGorsel(mediaId: id, kucuk: kucuk, fit: fit, width: width);
    }
    // Hic fotograf yok. Video VARSA durust bir video yer tutucusu; hicbir
    // medya yoksa notr kutu.
    final videoVar = mediaKinds.contains('video');
    return ColoredBox(
      color: const Color(0xFF14101C),
      child: Center(
        child: Icon(
          videoVar ? LucideIcons.video : LucideIcons.image,
          color: Colors.white38,
          size: 22,
        ),
      ),
    );
  }
}

/// ⚠️⚠️⚠️ TURU 78b — DUZENLEME SERIDINDE **TEK MEDYA** kucuk resmi.
///
/// `KapakGorseli` bir LISTEDEN ilk fotografi secer (kart/izgara icin dogru).
/// Duzenleme seridi ise medyalari **TEK TEK** cizer ve orada eskiden ham
/// `MedyaGorsel(mediaId: ...)` kullaniliyordu — yani bir VIDEO id'si dogrudan
/// gorsel yukleyiciye veriliyor ve **KIRIK GORSEL** ciziliyordu.
///
/// ⚠️ Neden onemli: turu 78'in manset ozelligi ilana/etkinlige VIDEO eklemek.
///    Videolu bir ilani duzenlemeye giren kullanici kendi videosunu "bozulmus"
///    sanip SILEBILIR — geri alinamaz bir kayip.
/// ⚠️ Video icin oynatici KURULMAZ: serit yatay kayan bir liste; her ogede
///    oynatici kurmak iOS'ta ses oturumuna dokunup SUREN ARAMAYI sagirlastirir
///    (turu 64/65/73). Durust bir video rozeti cizilir.
/// ⚠️ `tur` bos gelirse FOTOGRAF varsayilir (eski sunucu ile uyum).
class MedyaKucukResmi extends StatelessWidget {
  const MedyaKucukResmi({super.key, required this.mediaId, required this.tur});

  final String mediaId;
  final String tur;

  @override
  Widget build(BuildContext context) {
    if (tur != 'video') {
      return MedyaGorsel(mediaId: mediaId, kucuk: true, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFF14101C),
      child: Center(
        child: Icon(LucideIcons.video, color: Colors.white54, size: 20),
      ),
    );
  }
}
