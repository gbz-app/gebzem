/// ⚠️⚠️⚠️ TURU 180u — INSTAGRAM TARZI YORUM PANELI.
///
/// Kullanici emri: *"gonderilerdeki yoruma tikladiginda instagram yorum
/// paneli gibi acilsin"*. Onceden yorum dugmesi TAM SAYFA aciyordu
/// (gercek gonderide `YorumlarSayfasi`, demo gonderide `GonderiDetay`).
///
/// ═══════════ NEDEN AYRI DOSYA ═══════════
///
/// Panel yalnizca bir KABUK: yorum mantiginin ikinci bir kopyasi
/// YAZILMADI.
///   · gercek gonderi -> `YorumlarSayfasi(sheet: true)` (yukleme ·
///     gonderme · yanit · SILME · sikayet hepsi orada ve KORUNUR)
///   · demo gonderi   -> `_DemoGovde` (sunucuda karsiligi olmayan
///     `demo-` kimlikleri gercek uca gonderilemez)
///
/// ⚠️⚠️ **DEMO DALI ZORUNLU**: `YorumlarSayfasi` acilir acilmaz
///	`GET /posts/{id}/comments` cagirir. `demo-foto` gibi bir kimlikle
///	bu istek 404/400 doner ve panel "Yorumlar yuklenemedi" gosterirdi —
///	yani kullanicinin gordugu HER demo gonderide panel KIRIK olurdu.
///
/// ⚠️ Panel bir DEGER DONDURMEZ: yorum sayaci PAYLASILAN MUTABLE model
///    (`gonderi.yorumSayisi`) uzerinden guncellenir (turu 75b karari —
///    donus degeri icin gereken `PopScope(canPop:false)` iPhone'da kenar
///    kaydirmayi olduruyordu).
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart' show kAiZemin, kKoyuTema, koyuSayfa;
import '../../router.dart' show rootMessengerKey;
import 'demo_veri.dart' show demoKimlik;
import 'demo_yorum.dart' show demoYorumGorunumleri;
import 'sosyal_servisi.dart' show Gonderi;
import 'yorum_satiri.dart';
import 'yorumlar_sayfasi.dart';

/// Panelin ekrana orani.
///
/// ⚠️ Instagram paneli ekranin ~%75'ini kaplar ve arkadaki gonderi
///    GORUNUR kalir — "baska bir sayfaya gittim" hissi olusmaz.
/// ⚠️ SABIT oran BILINCLI: `DraggableScrollableSheet` + `TextField`
///    kombinasyonu bu projede HIC kurulmadi (tek ornek `room_screen.dart`
///    ve orada metin girisi YOK). Klavye acilinca surukleme ile viewInsets
///    birbirine karisir; kanitlanmis yol sabit oran + `viewInsets` dolgusu
///    (projede ALTI yerde calisiyor).
const double kYorumPaneliOran = 0.78;

/// Yorum panelini acar.
Future<void> yorumPaneliAc(
  BuildContext context, {
  required Gonderi gonderi,
  required String benimId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // ⚠️⚠️ `isScrollControlled` ZORUNLU: verilmezse tavan `ekran * 9/16`
    //	olur ve %78'lik panel SESSIZCE kirpilir (olustur_menusu.dart:62).
    isScrollControlled: true,
    // ⚠️ `useSafeArea` ZORUNLU: panel ekranin ustune kadar cikabildigi icin
    //	durum cubugunun ALTINA girmemeli.
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: kAiZemin,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (c) => koyuSayfa(
      FractionallySizedBox(
        heightFactor: kYorumPaneliOran,
        // ⚠️⚠️ `Material` sarmali ZORUNLU: sheet'in KENDI `Material`i DIS
        //	temayla kurulur, yani `DefaultTextStyle` ACIK temadan gelir ve
        //	renk vermeyen `Text`ler koyu zeminde KOYU cizilir (turu 180t'de
        //	olustur menusunde emulatorde OLCULDU).
        child: Material(
          color: kAiZemin,
          child: demoKimlik(gonderi.id)
              ? _DemoGovde(gonderi: gonderi)
              : YorumlarSayfasi(
                  gonderi: gonderi,
                  benimId: benimId,
                  sheet: true,
                ),
        ),
      ),
    ),
  );
}

/// Demo gonderilerin yorum govdesi.
///
/// ⚠️ `gonderi_detay.dart`taki demo dalinin AYNISI: `demoYorumGorunumleri`
///    + `YorumGrubu`. Cizim widget'lari ORTAK, yalniz kabuk farkli.
class _DemoGovde extends StatefulWidget {
  const _DemoGovde({required this.gonderi});
  final Gonderi gonderi;

  @override
  State<_DemoGovde> createState() => _DemoGovdeState();
}

class _DemoGovdeState extends State<_DemoGovde> {
  /// "Yanitlari goster" ile acilmis kok yorumlar.
  final Set<String> _acikYanitlar = {};

  /// ⚠️ State metotlari `build`in DONDURDUGU `Theme`i GORMEZ; bu widget'in
  ///    kendi context'i panelin `koyuSayfa`sinin ALTINDA oldugu icin burada
  ///    `Theme.of` da dogru calisirdi — yine de tek kaynak `kKoyuTema`.
  ColorScheme get _ks => kKoyuTema.colorScheme;

  @override
  Widget build(BuildContext context) {
    final g = widget.gonderi;
    final liste = demoYorumGorunumleri(g.id, g.yazarUsername);
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Stack(
            children: [
              Center(
                child: Text(
                  'Yorumlar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                    color: _ks.onSurface,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: _ks.onSurface.withValues(alpha: 0.10)),
        Expanded(
          child: liste.isEmpty
              ? Center(
                  child: Text(
                    'Henüz yorum yok',
                    style: TextStyle(
                      color: _ks.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
                  children: [
                    for (final y in liste)
                      YorumGrubu(
                        kok: y,
                        acik: _acikYanitlar.contains(y.id),
                        onYanitlariGoster: () => setState(() {
                          _acikYanitlar.contains(y.id)
                              ? _acikYanitlar.remove(y.id)
                              : _acikYanitlar.add(y.id);
                        }),
                      ),
                  ],
                ),
        ),
        // ⚠️⚠️⚠️ **DURUST SINIR**: demo gonderinin sunucuda karsiligi YOK,
        //	yani yazilan yorum HICBIR YERE gitmez. Kutu yine de cizilir
        //	(panelin tasarimi degerlendirilebilsin) ama dokunus ACIKCA
        //	"ornek gonderi" der — sessizce hicbir sey yapan bir gonder
        //	dugmesi kullaniciya uygulamayi KIRIK gosterirdi.
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              6,
              6,
              6 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: IgnorePointer(
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'Yorum yaz...',
                        isDense: true,
                        filled: true,
                        fillColor: _ks.onSurface.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.send),
                  // ⚠️ `rootMessengerKey`: sheet icinden `ScaffoldMessenger.of`
                  //    ile gosterilen SnackBar panelin ARKASINDA kalir.
                  onPressed: () =>
                      rootMessengerKey.currentState?.showSnackBar(
                        const SnackBar(
                          content: Text('Bu bir örnek gönderi.'),
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
