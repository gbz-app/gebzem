/// ⚠️⚠️⚠️ TURU 179 — **URUN DETAY SAYFASI.**
///
/// Kullanici emri: *"son olarak urun detay sayfasi da olacakti, onu da ekle;
/// urun detay sayfasi POPUP DEGIL, direk icine girsin"*.
///
/// ⚠️ Bu yuzden `showModalBottomSheet` KULLANILMAZ — sayfa `Navigator.push`
///    ile TAM SAYFA acilir (kullanicinin acik tercihi).
/// ⚠️ Ekran SALT OKUMA: duzenleme sahibin `UrunDuzenleEkrani`nda kalir.
///    Ikisini birlestirmek, musteriye gorunen bir ekrana yazma yollari
///    acmak demekti.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../medya/medya_gorsel.dart';
import '../medya/tam_ekran_gorsel.dart';
import 'urun_servisi.dart';

Future<void> urunDetayAc(
  BuildContext context, {
  required Urun urun,
  required String isletmeAd,
  Modul modul = Modul.varsayilan,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => UrunDetayEkrani(
      urun: urun,
      isletmeAd: isletmeAd,
      modul: modul,
    ),
  ),
);

class UrunDetayEkrani extends StatefulWidget {
  const UrunDetayEkrani({
    super.key,
    required this.urun,
    required this.isletmeAd,
    this.modul = Modul.varsayilan,
  });

  final Urun urun;
  final String isletmeAd;
  final Modul modul;

  @override
  State<UrunDetayEkrani> createState() => _UrunDetayEkraniState();
}

class _UrunDetayEkraniState extends State<UrunDetayEkrani> {
  Urun get urun => widget.urun;
  String get isletmeAd => widget.isletmeAd;
  Modul get modul => widget.modul;

  ColorScheme get _ks => kKoyuTema.colorScheme;

  /// Galeri sayfa sayaci.
  /// ⚠️ `PageController` `initState`te kurulur: `build` icinde kurulsaydi
  ///    her cizimde YENISI olusur ve kaydirma konumu SIFIRLANIRDI
  ///    (turu 92 slider dersi).
  final _sayfaCtrl = PageController();
  int _sayfa = 0;

  @override
  void dispose() {
    _sayfaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tukendi = urun.durum == 'tukendi';
    return koyuSayfa(
      Scaffold(
        // ⚠️ Header menu/profil/yemek ekranlariyla AYNI: 44 dp · ortada
        //    baslik · solda `arrowLeft`.
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 44,
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Text(
                        modul.tekil,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(LucideIcons.arrowLeft, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _gorsel(context),
            const SizedBox(height: 18),
            if (urun.bolum.isNotEmpty) ...[
              _rozet(urun.bolum),
              const SizedBox(height: 10),
            ],
            Text(
              urun.ad,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isletmeAd,
              style: TextStyle(
                fontSize: 14,
                color: _ks.onSurface.withValues(alpha: 0.55),
              ),
            ),
            if (urun.aciklama.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                urun.aciklama,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: _ks.onSurface.withValues(alpha: 0.82),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _fiyatKarti(tukendi),
            // ⚠️⚠️ **OZELLIKLER SUNUCUDAN GELIR** (`Modul.alanlar` +
            //    `Urun.ozellikler`); istemcide TAHMIN EDILMEZ. Bos alanlar
            //    CIZILMEZ: "Kapasite: —" gibi satirlar kart kirletir.
            ..._ozellikler(),
            if (urun.durum == 'kaldirildi') ...[
              const SizedBox(height: 16),
              Text(
                'Bu ürün şu anda menüde görünmüyor.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: _ks.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ⚠️ Alan **DAIMA cizilir**: gorsel yoksa notr yer tutucu gelir. Kosullu
  ///    cizilseydi gorselli ve gorselsiz urunlerde sayfa yapisi degisirdi.
  /// ⚠️ 4:3 — kare degil: menu fotograflari genelde yatay ve kare kutu
  ///    onlari ustten/alttan KIRPARDI.
  ///
  /// ⚠️⚠️⚠️ TURU 180o — **GALERI** (kullanici: *"otel odasinda galeri vs bu
  ///    galeriler aciliyor mu"*). Onceden YALNIZ `mediaIds.first` ciziliyordu:
  ///    bir otel odasinin 5 fotografi yuklense bile musteri **BIRINI**
  ///    goruyordu ve digerlerine ulasmanin HICBIR yolu yoktu.
  /// ⚠️ Sutun ZATEN dizi (`isletme_urunleri.media_ids UUID[]`, migration
  ///    031) ve sunucu diziyi oldugu gibi donduruyordu — eksik olan
  ///    yalnizca ARAYUZDU. Backend'e DOKUNULMADI.
  /// ⚠️⚠️ Dokunus **TAM EKRAN** acar: fotograf 4:3 kutuda `cover` cizilir,
  ///    yani dikey bir oda fotografinin buyuk kismi KIRPIKTIR ve tam haline
  ///    ulasmanin baska yolu YOK (ilan galerisiyle birebir ayni gerekce,
  ///    turu 113).
  /// ⚠️ Urun medyasi **DAIMA fotograftir** (`kind: 'image'` sabit yazilir,
  ///    AI gorseli de oyle) — bu yuzden video dali YOK. Ileride video
  ///    eklenirse once sunucu `media_kinds` dondurmeli, yoksa video id'si
  ///    `MedyaGorsel`e gidip KIRIK GORSEL cizer (turu 83b dersi).
  Widget _gorsel(BuildContext context) {
    final n = urun.mediaIds.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: n == 0
            ? ColoredBox(
                color: _ks.onSurface.withValues(alpha: 0.08),
                child: Icon(
                  LucideIcons.image,
                  size: 44,
                  color: _ks.onSurface.withValues(alpha: 0.25),
                ),
              )
            : Stack(
                children: [
                  PageView.builder(
                    controller: _sayfaCtrl,
                    itemCount: n,
                    onPageChanged: (i) => setState(() => _sayfa = i),
                    itemBuilder: (_, k) => GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TamEkranGorsel(mediaId: urun.mediaIds[k]),
                        ),
                      ),
                      child: MedyaGorsel(
                        mediaId: urun.mediaIds[k],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (n > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            '${_sayfa + 1}/$n',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _rozet(String metin) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _ks.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        metin,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _ks.primary,
        ),
      ),
    ),
  );

  Widget _fiyatKarti(bool tukendi) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
      color: _ks.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fiyat',
                style: TextStyle(
                  fontSize: 12.5,
                  color: _ks.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                // ⚠️ `fiyatMetni` TEK KAYNAK (`kurusMetni`): burada elle
                //    `kurus ~/ 100` yazmak turu 77b'de kurusu KIRPMISTI.
                urun.fiyatKurus > 0 ? urun.fiyatMetni : 'Belirtilmemiş',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (tukendi)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Tükendi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.orange,
              ),
            ),
          ),
      ],
    ),
  );

  List<Widget> _ozellikler() {
    final satirlar = <Widget>[];
    for (final a in modul.alanlar) {
      final d = (urun.ozellikler[a.anahtar] ?? '').trim();
      if (d.isEmpty) continue;
      satirlar.add(
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _ks.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    a.ad,
                    style: TextStyle(
                      fontSize: 14,
                      color: _ks.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Text(
                  a.birim.isEmpty ? d : '$d ${a.birim}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (satirlar.isEmpty) return const [];
    return [const SizedBox(height: 8), ...satirlar];
  }
}
