import 'package:flutter/widgets.dart';

/// Bir diyalog/sheet icindeki `TextEditingController`lari **SAHIPLENIR** ve
/// route gercekten sokuldugunde birakir.
///
/// ⚠️⚠️⚠️ TURU 96i — SAHADA GORULEN KIRMIZI EKRANIN KOK NEDENI.
///	Yaygin (ve YANLIS) desen suydu:
///
///	    final ctrl = TextEditingController();
///	    final onay = await showDialog(... TextField(controller: ctrl) ...);
///	    ctrl.dispose();            // <-- COK ERKEN
///
///	`showDialog`/`showModalBottomSheet` future'i **`pop` cagrildigi AN**
///	cozulur; route'un **CIKIS ANIMASYONU** (~150-250 ms) daha surer ve o
///	sure boyunca alt agac CIZILMEYE DEVAM EDER. `EditableText` her karede
///	denetleyiciye dokundugu icin:
///
///	    A TextEditingController was used after being disposed.
///
///	Bu bir `build` istisnasidir -> `ErrorWidget` devreye girer ve diyalog
///	route'u tam ekran oldugu icin **EKRANIN TAMAMI KIRMIZI** olur
///	(ardindan "RenderFlex overflowed by 99750 pixels" ve
///	`_dependents.isEmpty` cokuntuleri gelir).
///	⚠️ Geri tusuna basilinca route pop edildigi icin ekran KENDILIGINDEN
///	   duzelir — bu yuzden hata "bazen oluyor" gibi gorunur ve tekil bir
///	   ekrana baglanamaz.
///
/// ⚠️ ISTISNA DEGERI OKUMA GUVENLI: cagiran taraf `await`ten hemen SONRA
///    `ctrl.text` okur; o an route hala cikis animasyonundadir, yani nesne
///    CANLIDIR. Metni **senkron** oku, baska bir `await`in arkasina birakma.
/// ⚠️ YAPMA: cagri yerlerine tekrar `ctrl.dispose()` koyma (cift dispose).
class DenetleyiciSahibi extends StatefulWidget {
  const DenetleyiciSahibi({
    super.key,
    required this.denetleyiciler,
    required this.child,
  });

  final List<TextEditingController> denetleyiciler;
  final Widget child;

  @override
  State<DenetleyiciSahibi> createState() => _DenetleyiciSahibiState();
}

class _DenetleyiciSahibiState extends State<DenetleyiciSahibi> {
  @override
  void dispose() {
    for (final d in widget.denetleyiciler) {
      d.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
