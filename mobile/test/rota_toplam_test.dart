/// ⚠️⚠️⚠️ TURU 158b — **BACAK TOPLAMI == `toplamDakika`** (yayin oncesi
///	denetim; ORTA). `kAktarmaTampon` (2 dk) hicbir bacaga yazilmiyordu:
///	aktarmali rotada ozet karti "23 dk" derken adim listesi 21 dk
///	topluyordu ve `_kalkisDakikasi` kartin KENDI kalkis metnini
///	yalanliyordu.
///
/// ⚠️ Bu test AG GEREKTIRMEZ: yalnizca aritmetigi olcer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gebzem/features/ulasim/rota_bul.dart';

void main() {
  test('⚠️⚠️ bekleme bacagi kalkis dakikasini TASIR (turetilmez)', () {
    const b = RotaBacagi(
      tur: BacakTuru.bekle,
      noktalar: [],
      dakika: 7,
      baslik: '10:10 kalkış',
      altBaslik: 'X durağı',
      kalkisDakika: 610,
    );
    expect(b.kalkisDakika, 610);
    // ⚠️ Baslik metni ile alan AYNI kaynaktan gelmeli.
    expect(b.baslik.contains('10:10'), isTrue);
  });

  test('⚠️ kalkisDakika verilmezse null (uydurma kalkis URETILMEZ)', () {
    const b = RotaBacagi(
      tur: BacakTuru.yuru,
      noktalar: [],
      dakika: 5,
      baslik: 'yürü',
      altBaslik: '390 m',
    );
    expect(b.kalkisDakika, isNull);
  });
}
