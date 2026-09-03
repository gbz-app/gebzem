import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/ulasim/ulasim_veri.dart';
import 'package:gebzem/features/ulasim/rota_bul.dart' as rb;

String zin(rb.RotaAdayi a) => [
      for (final b in a.bacaklar)
        if (b.tur == rb.BacakTuru.otobus && b.hat != null) b.hat!.id
    ].join('>');
// SIRADAN BAGIMSIZ imza: (zincir@varis) kumesi
String kume(List<rb.RotaAdayi> r) =>
    (r.map((a) => '${zin(a)}@${a.varisDakika}').toList()..sort()).join('|');
// puan cok kumesi (siralamanin GERCEK olcutu)
String puanlar(List<rb.RotaAdayi> r) =>
    (r.map((a) => a.varisDakika + a.aktarma * 8).toList()..sort()).join(',');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('SIRA vs KUME', () async {
    final servis = UlasimVeri.bugunServis();
    final durakM = await UlasimVeri.i.durakHaritasi();
    final durakHat = await UlasimVeri.i.durakHatIndeksi(servis);
    final siralar = durakHat.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final yogun =
        siralar.take(400).map((e) => durakM[e.key]).whereType<Durak>().toList();
    final tum = durakM.values.toList();

    for (final K in [4, 8, 12, 24]) {
      for (final mod in ['yogun', 'rastgele']) {
        final rnd = math.Random(7);
        final ciftler = <(Durak, Durak)>[];
        while (ciftler.length < 400) {
          final kaynak = mod == 'yogun' ? yogun : tum;
          final a = kaynak[rnd.nextInt(kaynak.length)];
          final b = kaynak[rnd.nextInt(kaynak.length)];
          if (a.id == b.id) continue;
          ciftler.add((a, b));
        }
        var kumeFark = 0, puanFark = 0, puanKotu = 0, kayip = 0;
        var maksPuanKotu = 0;
        final orn = <String>[];
        for (final c in ciftler) {
          rb.olcK = 0;
          final r0 = await rb.rotaAra(
              baslangicEnlem: c.$1.enlem, baslangicBoylam: c.$1.boylam,
              varisEnlem: c.$2.enlem, varisBoylam: c.$2.boylam);
          rb.olcK = K;
          final r1 = await rb.rotaAra(
              baslangicEnlem: c.$1.enlem, baslangicBoylam: c.$1.boylam,
              varisEnlem: c.$2.enlem, varisBoylam: c.$2.boylam);
          if (r1.length < r0.length) kayip++;
          if (kume(r0) != kume(r1)) kumeFark++;
          if (puanlar(r0) != puanlar(r1)) {
            puanFark++;
            final p0 = r0.isEmpty ? 99999 : (r0.map((a) => a.varisDakika + a.aktarma * 8).reduce(math.min));
            final p1 = r1.isEmpty ? 99999 : (r1.map((a) => a.varisDakika + a.aktarma * 8).reduce(math.min));
            if (p1 > p0) { puanKotu++; maksPuanKotu = math.max(maksPuanKotu, p1 - p0); }
            if (orn.length < 3) orn.add('  ${c.$1.ad}->${c.$2.ad}\n    K=0 : ${kume(r0)}  puan=${puanlar(r0)}\n    K=$K: ${kume(r1)}  puan=${puanlar(r1)}');
          }
        }
        print('K=$K [$mod] n=400: KUME-farkli=$kumeFark  PUAN-COKKUMESI-farkli=$puanFark  EN-IYI-PUAN-KOTULESEN=$puanKotu (maks +$maksPuanKotu)  sonucKAYBI=$kayip');
        for (final o in orn) print(o);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 60)));
}
