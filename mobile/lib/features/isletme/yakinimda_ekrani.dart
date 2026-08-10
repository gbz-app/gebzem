/// ⚠️⚠️⚠️ TURU 85 — "YAKINIMDA": USTTE HARITA, ALTTA KARTLAR.
///
/// Kullanici emri: *"menuye tikladigimizda acilan pencereye yakinimda
/// eklemeliyiz; ustte harita altta kartlar olacak — isletmeler, eczane vs;
/// harita uber tarzi grimsi beyaz olsun"*.
///
/// ═══════════ HARITA HAKKINDA DURUST DURUM ═══════════
///
/// **GERCEK bir harita SDK'si bu projede KURULU DEGIL** ve kurulmasi
/// kullanicinin bir adimina baglidir:
///   · `google_maps_flutter` pubspec'e BILINCLI olarak eklenmemis
///     (pubspec serhi: API anahtari + faturalandirma + iki platformda kurulum),
///   · Repoda hicbir yerde Maps API anahtari YOK,
///   · CLAUDE.md `cloudMapId` kullanimini YASAKLIYOR (ucretsiz kalmasi icin) —
///     ama YEREL JSON stil ucretsizdir ve "uber tarzi grimsi beyaz" gorunum
///     tam olarak odur (Google'in "silver/light" stili).
///
/// Bu yuzden ekran **harita ALANI** ile geliyor: alan gercek boyutunda,
/// gercek konumda ve isletmeleri **konumlarina gore** yerlestiriyor; yalnizca
/// altindaki KARO KATMANI yok. Anahtar eklendigi anda `_HaritaAlani`
/// govdesi gercek haritayla degistirilir — cagri yerleri DEGISMEZ.
///
/// ⚠️ YAPMA: anahtar olmadan `google_maps_flutter` ekleme. Anahtarsiz harita
///    Android'de "For development purposes only" filigranli GRI bir kutu,
///    iOS'ta ise BOS ekran cizer — yani ozellik BOZUK gorunur. Yer tutucu
///    en azindan DURUSTTUR ve konumlari dogru gosterir.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/yenile.dart';
import '../medya/konum_servisi.dart';
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import 'isletme_servisi.dart';

/// Uber tarzi acik-gri harita paleti.
///
/// ⚠️ Renkler Google'in "silver" stiliyle ayni aileden secildi: zemin kirli
///    beyaz, yollar beyaz, su acik gri-mavi. Gercek harita geldiginde AYNI
///    palet JSON stil olarak verilecek — yer tutucu ile harita arasinda
///    gorsel SICRAMA olmasin.
const _zemin = Color(0xFFF2F3F5);
const _yol = Color(0xFFFFFFFF);
const _yolCizgi = Color(0xFFE4E6EA);
const _su = Color(0xFFDDE6EC);
const _yesil = Color(0xFFE8EDE6);

class YakinimdaEkrani extends ConsumerStatefulWidget {
  const YakinimdaEkrani({super.key});

  @override
  ConsumerState<YakinimdaEkrani> createState() => _YakinimdaEkraniState();
}

class _YakinimdaEkraniState extends ConsumerState<YakinimdaEkrani> {
  ({double enlem, double boylam})? _konum;
  List<IsletmeOzet> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _kategori = '';
  double _km = 10;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    // ⚠️ Yeniden girme kapisi: `_yukle` uc yerden cagriliyor (acilis,
    //    asagi-cek, kategori/mesafe degisimi).
    if (!mounted) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
      final svc = ref.read(isletmeServisiProvider);
      final k = _konum ?? await KonumServisi.konumAl();
      if (!mounted) return;
      if (k == null) {
        setState(() {
          _yukleniyor = false;
          _hata = 'Konumun alınamadı. Yakındakileri görebilmek için '
              'konum iznine ihtiyacımız var.';
        });
        return;
      }
      final l = await svc.yakinimda(
        enlem: k.enlem,
        boylam: k.boylam,
        km: _km,
        kategori: _kategori,
      );
      if (!mounted) return;
      setState(() {
        _konum = k;
        _liste = l;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _hata = 'Yakındaki işletmeler alınamadı';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yakınımda')),
      body: YenileSarmali(
        onRefresh: _yukle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ---- USTTE HARITA
            _HaritaAlani(merkez: _konum, isletmeler: _liste),
            _suzgecSeridi(),
            // ---- ALTTA KARTLAR
            if (_yukleniyor)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hata != null)
              _bilgi(LucideIcons.mapPinOff, _hata!, dugme: 'Tekrar dene')
            else if (_liste.isEmpty)
              _bilgi(
                LucideIcons.store,
                'Bu mesafede işletme bulunamadı.\n'
                'Mesafeyi artırmayı dene.',
              )
            else
              ..._liste.map(_kart),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _bilgi(IconData ikon, String metin, {String? dugme}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
    child: Column(
      children: [
        Icon(ikon, size: 40, color: Colors.grey),
        const SizedBox(height: 14),
        Text(
          metin,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, height: 1.45),
        ),
        if (dugme != null) ...[
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _yukle, child: Text(dugme)),
        ],
      ],
    ),
  );

  /// Kategori cipleri + mesafe secici.
  ///
  /// ⚠️ Kategori listesi `isletmeKategorileri` TEK KAYNAGINDAN gelir —
  ///    burada elle yazilsaydi sunucuya eklenen 'eczane'/'otel' gibi yeni
  ///    kategoriler bu ekranda GORUNMEZDI.
  Widget _suzgecSeridi() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _cip('Tümü', _kategori.isEmpty, () {
              setState(() => _kategori = '');
              _yukle();
            }),
            for (final e in isletmeKategorileri.entries)
              _cip(e.value, _kategori == e.key, () {
                setState(() => _kategori = e.key);
                _yukle();
              }),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: Row(
          children: [
            const Icon(LucideIcons.ruler, size: 15, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              '${_km.round()} km içinde',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            Expanded(
              child: Slider(
                value: _km,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_km.round()} km',
                onChanged: (v) => setState(() => _km = v),
                // ⚠️ Istek YALNIZ birakinca atilir: her piksel hareketinde
                //    atsaydi tek surukleme onlarca sorgu uretirdi.
                onChangeEnd: (_) => _yukle(),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _cip(String etiket, bool secili, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(etiket),
      selected: secili,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _kart(IsletmeOzet i) => ListTile(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: i.id)),
    ),
    leading: Avatar(
      ad: i.ad,
      mediaId: i.avatarMediaId,
      avatarUrl: i.avatarUrl,
      cap: 46,
    ),
    title: Row(
      children: [
        Flexible(
          child: Text(
            i.ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (i.dogrulandi) ...[
          const SizedBox(width: 4),
          const Icon(LucideIcons.badgeCheck, size: 15, color: Color(0xFF3AA9FF)),
        ],
      ],
    ),
    subtitle: Text(
      [
        isletmeKategoriAdi(i.kategori),
        if (i.ilce.isNotEmpty) i.ilce,
        if (i.adres.isNotEmpty) i.adres,
      ].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12.5),
    ),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          i.mesafeMetni,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        // ⚠️ "Yol tarifi" TELEFONUN KENDI harita uygulamasini acar
        //    (`KonumServisi.haritadaAc`) — uygulama ici harita gerekmez ve
        //    yol tarifi orada zaten calisir (turu 81 karari).
        GestureDetector(
          onTap: () => KonumServisi.haritadaAc(i.enlem, i.boylam),
          child: const Text(
            'Yol tarifi',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF3AA9FF)),
          ),
        ),
      ],
    ),
  );
}

/// ⚠️⚠️ HARITA ALANI — su an **YER TUTUCU** (bkz. dosya basindaki serh).
///
/// Gercek konumu ve isletmeleri DOGRU GORECELI KONUMDA cizer: merkez
/// kullanici, cevresinde isletme igneleri. Karo (tile) katmani yoktur.
///
/// ⚠️ Gercek haritaya gecerken SADECE bu sinifin `build`i degisir; ekranin
///    geri kalani ve cagri yeri AYNEN kalir.
class _HaritaAlani extends StatelessWidget {
  const _HaritaAlani({required this.merkez, required this.isletmeler});

  final ({double enlem, double boylam})? merkez;
  final List<IsletmeOzet> isletmeler;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _zemin),
            CustomPaint(painter: _SehirCizer()),
            if (merkez != null)
              CustomPaint(
                painter: _IgneCizer(merkez: merkez!, isletmeler: isletmeler),
              ),
            // Durust bilgi seridi.
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isletmeler.isEmpty
                      ? 'Konumun'
                      : '${isletmeler.length} işletme yakınında',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF3C3C43),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uber tarzi acik-gri sehir dokusu (yol agi + park + su).
///
/// ⚠️ Rastgelelik YOK: `Random` kullanilsaydi her cizimde farkli bir sehir
///    olusur ve kaydirmada TITRERDI. Desen deterministik bir formulden gelir.
class _SehirCizer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final su = Paint()..color = _su;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.72, 0)
        ..quadraticBezierTo(
          size.width * 0.86, size.height * 0.45,
          size.width * 0.78, size.height,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      su,
    );
    final park = Paint()..color = _yesil;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06, size.height * 0.58,
            size.width * 0.22, size.height * 0.28),
        const Radius.circular(10),
      ),
      park,
    );

    final yol = Paint()
      ..color = _yol
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cizgi = Paint()
      ..color = _yolCizgi
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Yatay + dikey yol agi (kalinliklar degisken -> ana/ara yol hissi).
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      yol.strokeWidth = i.isEven ? 9 : 5;
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.8, y), yol);
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.8, y), cizgi);
    }
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      if (x > size.width * 0.75) break;
      yol.strokeWidth = i == 2 ? 10 : 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), yol);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cizgi);
    }
  }

  @override
  bool shouldRepaint(_SehirCizer oldDelegate) => false;
}

/// Kullanici + isletme igneleri. Konumlar GERCEK koordinatlardan turer.
class _IgneCizer extends CustomPainter {
  _IgneCizer({required this.merkez, required this.isletmeler})
    : _adet = isletmeler.length;

  final ({double enlem, double boylam}) merkez;
  final List<IsletmeOzet> isletmeler;

  /// ⚠️ Uzunluk KURULUM ANINDA yakalanir — `shouldRepaint` icinde AYNI liste
  ///    nesnesinin uzunlugunu kendisiyle karsilastirmak DAIMA false doner
  ///    (turu 81b'de canli ses dalgasi tam bu yuzden hic cizilmemisti).
  final int _adet;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width / 2, size.height / 2);

    // En uzak isletme kenara denk gelsin diye olcek.
    var enUzak = 0.5;
    for (final i in isletmeler) {
      if (i.km > enUzak) enUzak = i.km;
    }
    final olcek = (math.min(size.width, size.height) / 2 - 26) / enUzak;

    final igne = Paint()..color = const Color(0xFF6C2BD9);
    for (final i in isletmeler) {
      if (i.enlem == 0 && i.boylam == 0) continue;
      // Kuzey yukari: enlem farki -Y, boylam farki +X (boylam cos ile daralir).
      final dy = (i.enlem - merkez.enlem) * 111.0;
      final dx = (i.boylam - merkez.boylam) *
          111.0 * math.cos(merkez.enlem * math.pi / 180);
      final p = o + Offset(dx * olcek, -dy * olcek);
      if (p.dx < 6 || p.dx > size.width - 6 ||
          p.dy < 6 || p.dy > size.height - 6) {
        continue;
      }
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, igne);
    }

    // Kullanici: mavi nokta + halka (harita uygulamalarinin ortak dili).
    canvas.drawCircle(o, 13, Paint()..color = const Color(0x333AA9FF));
    canvas.drawCircle(o, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(o, 5, Paint()..color = const Color(0xFF3AA9FF));
  }

  @override
  bool shouldRepaint(_IgneCizer eski) =>
      eski._adet != _adet ||
      eski.merkez.enlem != merkez.enlem ||
      eski.merkez.boylam != merkez.boylam;
}
