import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import 'randevu_servisi.dart';
import '../../core/theme.dart';

/// ⚠️⚠️⚠️ TURU 80 — REZERVASYON / RANDEVU ALMA EKRANI.
///
/// Kullanici emri: *"restoran/yemek firmalarindan rezervasyon, doktor vs.den
/// randevu alinabilmeli"*.
///
/// ═══════════ ⚠️⚠️ NEDEN `showDatePicker` / `showTimePicker` YOK ═══════════
///
/// ⚠️⚠️ TURU 80b — GEREKCE (1) DUSTU, KARAR DEGISMEDI (denetim).
///     Bu blok eskiden birinci gerekce olarak *"uygulamada
///     `flutter_localizations` YOK, secici INGILIZCE acilir"* diyordu. Turu 80
///     bagimliligi ve `main.dart`taki uc delegeyi EKLEDI (`locale: Locale('tr')`),
///     yani o gerekce ARTIK GECERSIZ — nitekim `KapaliGunlerEkrani` Turkce
///     `showDatePicker` kullaniyor.
///     **AMA KARAR AYNI KALIYOR**, cunku asil gerekce (2) tek basina yeterli:
///
/// (2) Saat secici SERBEST saat verir; ama isletmenin calisma saatleri ve
///     kapasitesi var. Kullanicinin 03:00 secip "kapali" hatasi almasi kotu
///     bir deneyim — MUSAIT OLMAYAN saati HIC GOSTERMEMEK dogrusu.
///     ⚠️ Bu gerekce SAAT secicisi icindir; TARIH secicisi (kapali gun ekranı)
///        ayni sinirlamaya tabi degildir — orada her gun secilebilir olmali.
///
/// Bunun yerine: **isletmenin `ileri_gun` ayari kadar yatay gun seridi** +
/// **sunucudan gelen slot izgarasi**. Slotlari SUNUCU uretiyor (calisma saati +
/// kapasite + gecmis saat + kapali gun kurallari orada) — istemcide TEK BIR
/// KURAL YOK.
/// ⚠️ YAPMA: buraya `showTimePicker` ekleme (slot izgarasinin varlik sebebi
///    tam olarak budur).
class RandevuAlEkrani extends ConsumerStatefulWidget {
  const RandevuAlEkrani({
    super.key,
    required this.isletmeId,
    required this.isletmeAd,
  });

  final String isletmeId;
  final String isletmeAd;

  @override
  ConsumerState<RandevuAlEkrani> createState() => _RandevuAlEkraniState();
}

class _RandevuAlEkraniState extends ConsumerState<RandevuAlEkrani> {
  late DateTime _gun = _bugun();
  UygunGun? _veri;
  bool _yukleniyor = true;
  String? _hata;

  Slot? _secili;
  int _kisi = 2;
  final _hizmet = TextEditingController();
  final _not = TextEditingController();

  /// ⚠️ Cift dokunma kilidi: olusturma bir AG cagrisidir ve iki dokunus IKI
  ///    randevu acardi.
  bool _gonderiliyor = false;

  static DateTime _bugun() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Serit kac gun gostersin. ⚠️ ISLETMENIN ayarindan (bkz. `_gunSeridi` serhi);
  ///    veri gelmeden once 14 varsayilir. ⚠️ Sunucu tavani 60 — savunma amacli
  ///    burada da sinirlaniyor ki bozuk bir deger devasa liste uretmesin.
  ///
  /// ⚠️⚠️ **+1** (turu 80b denetimi): sunucudaki `IleriGunDisi` yuklemi
  ///    `gun.After(bugun + ileriGun)` — yani **bugun + ileriGun** gunu HALA
  ///    IZINLIDIR. Serit `ileriGun` kadar oge cizerse (indeks 0 = bugun)
  ///    son gorunen gun `bugun + ileriGun - 1` olur ve **sunucunun izin
  ///    verdigi SON GUN kullaniciya HIC GOSTERILMEZ**: isletme "14 gun
  ///    ileriye" dese de musteri yalniz 14 gun (bugun dahil) gorur.
  /// ⚠️ Sunucudaki yuklem degisirse BURASI DA degismeli — ikisi ayni
  ///    pencereyi tarif etmek ZORUNDA.
  int get _gunSayisi => (_veri?.ileriGun ?? 14).clamp(1, 60) + 1;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _hizmet.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _secili = null;
    });
    // ⚠️ Servis await'ten ONCE (turu 78b: disposed State'te `ref.read`
    //    StateError firlatir ve is SESSIZCE iptal olur).
    final svc = ref.read(randevuServisiProvider);
    final istenen = _gun;
    try {
      final v = await svc.uygunSaatler(widget.isletmeId, istenen);
      // ⚠️ Kullanici beklerken BASKA gune gectiyse gelen sonucu YAZMA.
      if (!mounted || istenen != _gun) return;
      setState(() {
        _veri = v;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || istenen != _gun) return;
      setState(() {
        _yukleniyor = false;
        _hata = apiErrorMessage(e);
      });
    }
  }

  Future<void> _gonder() async {
    final s = _secili;
    if (s == null || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final svc = ref.read(randevuServisiProvider);
    final rezervasyon = _veri?.rezervasyonMu ?? false;
    try {
      await svc.olustur(
        isletmeId: widget.isletmeId,
        zaman: s.zaman,
        kisiSayisi: rezervasyon ? _kisi : 1,
        hizmet: rezervasyon ? '' : _hizmet.text.trim(),
        not: _not.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            rezervasyon
                ? 'Rezervasyon talebin gönderildi'
                : 'Randevu talebin gönderildi',
          ),
        ),
      );
    } catch (e) {
      // ⚠️ KOK MESSENGER: ekran degismis olabilir.
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
      // ⚠️ 409 (slot doldu) sonrasi listeyi TAZELE — kullanici dolu slotu
      //    tekrar secmesin.
      if (mounted) {
        setState(() => _gonderiliyor = false);
        unawaited(_yukle());
      }
      return;
    }
    if (mounted) setState(() => _gonderiliyor = false);
  }

  // ══════════════════════ ADIM ADIM AKIS (turu 178) ══════════════════════
  //
  // ⚠️⚠️⚠️ Kullanici emri: *"rezervasyonu STEP STEP yap, TAM SAYFA OLMASIN,
  //	POPUP tarzi acilsin ve arayuzu guzellestir"*.
  //
  // Eski hal TEK EKRANDI: gun seridi + saat izgarasi + kisi sayaci + iki
  // metin alani AYNI ANDA cizilyordu. Kullanici ilk bakista dort ayri karar
  // goruyor ve hangisinin ZORUNLU oldugunu anlamiyordu (yalniz SAAT
  // zorunlu; digerleri istege bagli).
  //
  // ⚠️ Adim gecisi **OTOMATIK**: gune dokununca saate, saate dokununca
  //	detaya gecilir. Ayrica "Ileri" dugmesi ARAMAK gerekmez — dokunusun
  //	kendisi zaten secimdir.
  // ⚠️ GERI YOLU HER ADIMDA ACIK (basliktaki ok): son adimda saati
  //	degistirmek isteyen kullanici sheet'i kapatip bastan baslamak
  //	zorunda kalmamali.

  /// 0 = tarih · 1 = saat · 2 = detay.
  int _adim = 0;

  static const _adimAdlari = ['Tarih', 'Saat', 'Detay'];

  void _adimaGit(int a) {
    if (a == _adim) return;
    // ⚠️ Klavye acikken adim degisirse alttaki dugme klavyenin arkasinda
    //    kalir; odak birakilir.
    FocusScope.of(context).unfocus();
    setState(() => _adim = a);
  }

  bool get _geriVar => _adim > 0;

  void _geri() {
    if (_geriVar) {
      _adimaGit(_adim - 1);
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️⚠️ `viewInsets` dolgusu ZORUNLU: detay adiminda iki metin alani var
    //	ve `showModalBottomSheet` klavyeyi KENDI KENDINE karsilamaz —
    //	dolgu olmadan "Talep gonder" dugmesi klavyenin ALTINDA kalir
    //	(hem gorunmez hem DOKUNULAMAZ).
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _baslik(),
          _adimSeridi(),
          // ⚠️ `Flexible` — `Expanded` DEGIL: sheet `mainAxisSize.min` ile
          //    calisiyor ve icerik kisaysa pencere de kisalmali.
          Flexible(child: _adimGovdesi()),
          _altBar(),
        ],
      ),
    );
  }

  /// ⚠️ Baslik YEMEK EKRANIYLA AYNI: 44 dp · ortada baslik · solda
  ///	`arrowLeft` (kullanici emri: *"rezervasyon sayfasinin header'i
  ///	aynen yemekteki gibi olsun"*).
  /// ⚠️ Isletme adi baslikta DEGIL adim seridinin altinda: 44 dp'lik satira
  ///	iki metin sigdirmak yazi olcegi buyudugunde TASAR (turu 80b'de bu
  ///	ekranda olculmustu).
  Widget _baslik() {
    final rezervasyon = _veri?.rezervasyonMu ?? false;
    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: Text(
                rezervasyon ? 'Rezervasyon' : 'Randevu',
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
              onTap: _geri,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  _geriVar ? LucideIcons.arrowLeft : LucideIcons.x,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adim gostergesi: 1 Tarih — 2 Saat — 3 Detay.
  ///
  /// ⚠️ Gecilmis adimlar TIKLANABILIR (geri donus), gelecek adimlar DEGIL:
  ///	saat secmeden detaya atlamak sunucuya gonderilecek zamani BOS
  ///	birakirdi.
  /// ⚠️ Baglayici cizgi `Expanded` ile esner; sabit genislik verilseydi dar
  ///	ekranda RenderFlex tasmasi olurdu.
  Widget _adimSeridi() {
    final scheme = kKoyuTema.colorScheme;
    Widget nokta(int i) {
      final gecildi = i < _adim;
      final aktif = i == _adim;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: gecildi ? () => _adimaGit(i) : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: aktif || gecildi
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.10),
              ),
              child: gecildi
                  ? Icon(LucideIcons.check, size: 15, color: scheme.onPrimary)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: aktif
                            ? scheme.onPrimary
                            : scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            Text(
              _adimAdlari[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: aktif ? FontWeight.w700 : FontWeight.w500,
                color: aktif
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // ⚠️⚠️ TURU 180d — **CUBUKLAR DAIRE MERKEZINE HIZALI** (kullanici:
    //	*"rezervasyon sayfasini biraz daha duzelt dedim, bak
    //	CUBUKLAR NEREDE"*).
    //
    //	Onceden hizalama `crossAxisAlignment: end` + `bottom: 22`
    //	ile yapiliyordu; ama satirin yuksekligi ETIKET metninden
    //	(dolayisiyla YAZI OLCEGINDEN) geliyor ve alttan sabit bir
    //	pay dairenin merkezini TUTTURAMIYORDU — cubuklar dairelerin
    //	ALTINDA kaliyordu.
    //
    // ⚠️ Yeni hizalama USTTEN: daire 26 dp, cubuk 3 dp -> ust pay
    //	(26 - 3) / 2 = 11,5. Bu deger yazi olceginden BAGIMSIZ,
    //	cunku daire sabit 26 dp.
    // ⚠️ Satir `crossAxisAlignment: start` olmali (asagida) — `end` ile
    //	ust pay hicbir sey yapmazdi.
    Widget cizgi(int i) => Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(top: 11.5, left: 6, right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          color: i < _adim
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.12),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 10),
      child: Row(
        // ⚠️ TURU 180d — `end` -> `start`: cubuklar artik USTTEN hizali
        //    (bkz. `cizgi` serhi).
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [nokta(0), cizgi(0), nokta(1), cizgi(1), nokta(2)],
      ),
    );
  }

  Widget _adimGovdesi() {
    if (_hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_hata!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _yukle,
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    return switch (_adim) {
      0 => _tarihAdimi(),
      1 => _saatAdimi(),
      _ => _detayAdimi(),
    };
  }

  // ─────────────────────────── ADIM 1: TARIH ───────────────────────────

  /// ⚠️⚠️ Gunler **IZGARA** (eski yatay serit degil): serit ayni anda 4-5 gun
  ///	gosteriyordu ve 30 gun ileriye acik bir isletmede kullanici
  ///	kaydirmadan hangi gunlerin oldugunu goremiyordu. Izgarada 4 sutun ile
  ///	iki haftanin tamami tek bakista gorunur.
  /// ⚠️ Hucre yuksekligi `mainAxisExtent` ile ICERIKTEN turetilir; sabit
  ///	`childAspectRatio` yazi olcegi buyudugunde TASARDI (turu 121 dersi).
  Widget _tarihAdimi() {
    final scheme = kKoyuTema.colorScheme;
    final olcek = MediaQuery.textScalerOf(context).scale(1.0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        Text(
          'Hangi gün?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.isletmeAd,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _gunSayisi,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 74 * olcek,
          ),
          itemBuilder: (_, i) {
            final g = _bugun().add(Duration(days: i));
            final secili = g == _gun;
            return GestureDetector(
              onTap: () {
                if (g != _gun) {
                  setState(() => _gun = g);
                  unawaited(_yukle());
                }
                _adimaGit(1);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: secili
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  // ⚠️ TURU 180 — BUGUN ince bir halka alir: kullanici
                  //    izgarada "hangi gundeyim" sorusunu tarih
                  //    sayarak cozmek zorunda kalmasin.
                  border: (!secili && i == 0)
                      ? Border.all(
                          color: scheme.primary.withValues(alpha: 0.55),
                          width: 1.4,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      // ⚠️ `weekday` 1..7 -> dizi 0..6.
                      kGunKisa[g.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        // ⚠️ TURU 115b — `primary` uzerinde gri 4,20:1 ile
                        //    esigin ALTINDA kaliyordu; `onPrimary` 7,9:1.
                        color: secili
                            ? scheme.onPrimary
                            : scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${g.day}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: secili ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                    Text(
                      kAyAdlari[g.month - 1].substring(0, 3),
                      style: TextStyle(
                        fontSize: 11,
                        color: secili
                            ? scheme.onPrimary.withValues(alpha: 0.85)
                            : scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────── ADIM 2: SAAT ────────────────────────────

  Widget _saatAdimi() {
    final scheme = kKoyuTema.colorScheme;
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    final v = _veri;
    if (v == null || !v.acik) {
      return _bosDurum('Bu işletme şu anda randevu almıyor.');
    }
    if (v.slotlar.isEmpty) {
      return _bosDurum(
        v.mesaj.isNotEmpty
            ? v.mesaj
            : 'Bu gün için uygun saat yok.\nBaşka bir gün seç.',
        eylem: 'Başka gün seç',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        Text(
          'Saat seç',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _gunMetni(_gun),
          style: TextStyle(
            fontSize: 13,
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in v.slotlar)
              // ⚠️ DOLU slot CIZILIR ama PASIF: gizlemek kullaniciya "bu saat
              //    hic yok" dedirtirdi; pasif gostermek "dolmuş" bilgisini verir.
              _saatCipi(s, scheme),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              LucideIcons.info,
              size: 14,
              color: scheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Soluk saatler dolu.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _saatCipi(Slot s, ColorScheme scheme) {
    final secili = _secili?.zaman == s.zaman;
    return GestureDetector(
      onTap: s.musait
          ? () {
              setState(() => _secili = s);
              _adimaGit(2);
            }
          : null,
      child: AnimatedContainer(
        // ⚠️ 140 ms: secim geri bildirimi ANI olmasin ama beklenmesin de.
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: secili
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: s.musait ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(14),
          // ⚠️ DOLU slotta kesikli gorunum yerine SOLUK KENARLIK: kesik
          //    desen kucuk cipte gurultu yapiyordu.
          border: s.musait
              ? null
              : Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.08),
                ),
        ),
        child: Text(
          s.saat,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: secili
                ? scheme.onPrimary
                : scheme.onSurface.withValues(alpha: s.musait ? 0.9 : 0.28),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── ADIM 3: DETAY ───────────────────────────

  Widget _detayAdimi() {
    final scheme = kKoyuTema.colorScheme;
    final v = _veri;
    final s = _secili;
    if (v == null || s == null) return _bosDurum('Önce bir saat seç.');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      children: [
        // ── SECIM OZETI ──────────────────────────────────────────────
        // ⚠️ Kullanici son adimda NEYI onayladigini gormeli; ozet olmadan
        //    "hangi saati sectim" diye geri donmek gerekirdi.
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // ⚠️ TURU 180 — ikon DAIRE ICINDE: duz ikon kartin icinde
              //    havada duruyordu.
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
                child: Icon(
                  LucideIcons.calendarCheck,
                  size: 21,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_gunMetni(_gun)} · ${s.saat}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isletmeAd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _adimaGit(1),
                child: const Text('Değiştir'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // ⚠️ REZERVASYON -> kisi sayisi · RANDEVU -> hizmet. Ikisi AYNI ANDA
        //    gosterilmez; sunucudan gelen `tur` karar verir.
        if (v.rezervasyonMu) ...[
          const Text(
            'Kaç kişi?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _kisi > 1 ? () => setState(() => _kisi--) : null,
                icon: const Icon(LucideIcons.minus, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  '$_kisi',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _kisi < 20 ? () => setState(() => _kisi++) : null,
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
            ],
          ),
        ] else ...[
          TextField(
            controller: _hizmet,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Hangi hizmet? (isteğe bağlı)',
              hintText: 'Örnek: kontrol, saç kesimi',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: _not,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Not (isteğe bağlı)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Talebin işletmeye iletilir. Onaylandığında bildirim alırsın.',
          style: TextStyle(
            fontSize: 12.5,
            color: scheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────── ORTAK ────────────────────────────────

  Widget _bosDurum(String metin, {String? eylem}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metin,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          if (eylem != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _adimaGit(0),
              child: Text(eylem),
            ),
          ],
        ],
      ),
    ),
  );

  /// ⚠️ Alt dugme YALNIZ detay adiminda cizilir: tarih ve saat adimlarinda
  ///	dokunusun kendisi zaten ilerletir, ikinci bir "Ileri" dugmesi
  ///	kullaniciyi "hangisine basmaliyim" ikilemine sokardi.
  Widget _altBar() {
    if (_adim != 2 || _secili == null) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _gonderiliyor ? null : _gonder,
            icon: _gonderiliyor
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.check, size: 18),
            label: Text(
              _gonderiliyor ? 'Gönderiliyor...' : 'Talebi gönder',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _gunMetni(DateTime g) =>
      '${g.day} ${kAyAdlari[g.month - 1]} ${kGunUzun[g.weekday - 1]}';
}

/// ⚠️⚠️ TURU 178 — **POPUP ACICI** (kullanici emri: *"tam sayfa olmasin,
///	popup tarzi acilsin"*).
///
/// ⚠️ `isScrollControlled: true` ZORUNLU: varsayilan tavan ekranin 9/16'si
///	ve tarih izgarasi orada KIRPILIRDI (turu 90b/115c dersi).
/// ⚠️ `useSafeArea: true`: centik/jest cubugu alanina tasmasin.
/// ⚠️ Yukseklik `heightFactor` ile SABIT: icerige gore degisseydi adim
///	degistikce pencere ZIPLARDI.
Future<bool?> randevuAlAc(
  BuildContext context, {
  required String isletmeId,
  required String isletmeAd,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  // ⚠️ TURU 178 — panel SIYAH: acan yuzey (isletme profili) siyah ve
  //    beyaz bir sheet uzerine binince ekran IKIYE BOLUNMUS gorunuyordu.
  backgroundColor: kAiZemin,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => koyuSayfa(
    FractionallySizedBox(
      heightFactor: 0.9,
      child: Material(
        // ⚠️ `Material` ZORUNLU: sheet govdesinde iki `TextField` var ve
        //    `Material` atasi olmadan cizilemez (turu 130 dersi).
        color: kAiZemin,
        child: RandevuAlEkrani(isletmeId: isletmeId, isletmeAd: isletmeAd),
      ),
    ),
  ),
);
