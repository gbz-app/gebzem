import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'medya_kapisi.dart';
import 'medya_servisi.dart';
import 'ses_notu_kontrol.dart';

/// ⚠️⚠️ TURU 74 — SES NOTU BALONU (dalga formu + oynat/durdur + hız).
///
/// ⚠️ **OYNATMA DA SERT KAPIYA TABİ:** aktif arama/oda/yayın varken ses notu
///     ÇALMAZ. `audioplayers` iOS'ta ses bağlamını **GLOBAL** uygular; çalarsa
///     görüşmenin sesi bozulur.
///
/// ⚠️ **AYRI `playerId`** (`gebzem_sesnotu`): `CallSounds` kendi oynatıcısını
///     kullanır (zil/çalma tonu). Aynı id paylaşılsaydı ses notu çalmak zili
///     durdururdu.
///
/// ⚠️ **iOS'ta `setAudioContext` ÇAĞRILMAZ** — bağlam PROSES GENELİDİR ve
///     `call_sounds.dart` da bu yüzden yalnız Android'de çağırıyor. iOS'ta
///     çağırmak süren aramanın oturumunu yeniden yapılandırırdı.
class SesNotuBalon extends ConsumerStatefulWidget {
  const SesNotuBalon({
    super.key,
    required this.mediaId,
    required this.sureMs,
    required this.dalga,
    required this.benimMi,
    this.akista = false,
  });

  /// ⚠️⚠️ TURU 104 — **GORUNUM VARYANTI (mantik DEGISMEZ).**
  ///
  ///	Kullanici emri: *"ses instagram tarzi olsun"*. Akis karti tam
  ///	geniştir, temadan boyanir ve dokunarak ileri sarilir; sohbet balonu
  ///	230 dp sabit genislikte ve SABIT renklerle kalir (balon zemini de
  ///	sabittir — temadan boyanirsa acik temada kontrast coker, turu 81b).
  /// ⚠️⚠️ **IKINCI BIR OYNATICI YAZMAK YASAK**: oynatma, tek-slot devralma
  ///	ve `SesNotuKontrol` kaydi (gelen arama sesi susturabilsin diye)
  ///	TEK govdededir. Bu bayrak yalnizca CIZIMI degistirir.
  final bool akista;

  final String mediaId;
  final int sureMs;
  final String dalga; // "12,40,88,..." (60 kova)
  final bool benimMi;

  @override
  ConsumerState<SesNotuBalon> createState() => _SesNotuBalonState();
}

class _SesNotuBalonState extends ConsumerState<SesNotuBalon> {
  static final _oynatici = AudioPlayer(playerId: 'gebzem_sesnotu');

  /// ⚠️ Aynı anda TEK ses notu çalar. Başka balon başlarsa bu durur.
  static String? _calanId;

  /// TURU 74b: SesNotuKontrol sahiplik jetonu + tek-slot devralma icin.
  final Object _sahip = Object();

  /// TURU 74b: yeniden-girme kilidi (cift dokunus = cift play).
  bool _mesgul = false;

  StreamSubscription<Duration>? _konumSub;

  /// ⚠️⚠️⚠️ TURU 104 — **SURE OYNATICIDAN OGRENILIR.**
  ///
  ///	`gonderi_karti.dart` bu balonu `sureMs: 0, dalga: ''` ile cagiriyor
  ///	(gonderi hattinda sure/dalga sutunu YOK) ve serhi *"balon sureyi
  ///	oynaticidan ogrenir"* diyordu — **GOVDEDE OYLE BIR SATIR YOKTU.**
  ///	Sonuc: akistaki her ses karti **00:00** yaziyor ve ilerleme cubugu
  ///	HIC dolmuyordu (`oran` `sureMs == 0` dalinda daima 0.0).
  /// ⚠️ Sohbette `sureMs` DOLU gelir; orada bu deger yalnizca yedektir.
  Duration? _ogrenilenSure;
  StreamSubscription<Duration>? _sureSub;
  StreamSubscription<void>? _bittiSub;
  bool _caliyor = false;
  Duration _konum = Duration.zero;
  double _hiz = 1.0;

  @override
  void dispose() {
    // ⚠️ TURU 113 (denetim) — statik isaretci temizlenir; aksi halde
    //    dispose edilmis State ve tum alt agaci KALICI tutulur.
    if (_aktifState == this) _aktifState = null;
    _konumSub?.cancel();
    _sureSub?.cancel();
    _bittiSub?.cancel();
    if (_calanId == widget.mediaId) {
      _oynatici.stop();
      _calanId = null;
      SesNotuKontrol.kapat(_sahip);
    }
    super.dispose();
  }

  /// ⚠️⚠️ TURU 74b (DENETİM BULGUSU): statik oynatıcı PAYLAŞILIYOR ama her State
  ///     kendi aboneliğini tutuyordu ve BAŞKASI devraldığında iptal edilmiyordu.
  ///     A çalarken B'ye basılınca: A'nın `_caliyor` bayrağı TRUE kalıyor, A'nın
  ///     konum dinleyicisi B'nin konumunu alıyordu → iki balon birden ilerliyor.
  ///     Dahası B bitince A'nın `onPlayerComplete` dinleyicisi `birak()` çağırıp
  ///     **B'nin arama-kazanır kaydını siliyordu.**
  /// ⚠️ YAPMA: bu devralma kancasını kaldırma.
  static _SesNotuBalonState? _aktifState;

  void _devret() {
    _sureSub?.cancel();
    _konumSub?.cancel();
    _konumSub = null;
    _bittiSub?.cancel();
    _bittiSub = null;
    if (mounted && _caliyor) setState(() => _caliyor = false);
  }

  Future<void> _oynatDurdur() async {
    // ⚠️ YENİDEN-GİRME KİLİDİ (proje kuralı: kullanıcı-tetiklemeli async akışa
    //    kilit koy). Çift dokunuş çift `play()` + çift abonelik üretiyordu.
    if (_mesgul) return;
    _mesgul = true;
    try {
      await _oynatDurdurGovde();
    } finally {
      _mesgul = false;
    }
  }

  Future<void> _oynatDurdurGovde() async {
    if (_caliyor) {
      await _oynatici.pause();
      if (mounted) setState(() => _caliyor = false);
      SesNotuKontrol.birak(_sahip);
      return;
    }
    // ⚠️ SERT KAPI — sınıf şerhi. Aksiyon yolunda (yan etkili kontrol serbest).
    if (!MedyaKapisi.izinVer(ref)) return;

    try {
      // Başka bir ses notu çalıyorsa durdur (tek slot) VE onun aboneliklerini
      // İPTAL ET — yoksa o State bizim konumumuzu dinlemeye devam eder.
      if (_aktifState != null && _aktifState != this) {
        _aktifState!._devret();
      }
      if (_calanId != null && _calanId != widget.mediaId) {
        await _oynatici.stop();
      }
      _aktifState = this;
      final d = await ref.read(medyaServisiProvider).adres(widget.mediaId);
      // ⚠️⚠️⚠️ TURU 113 (denetim, YUKSEK) — **CANLILIK KAPISI ZORUNLU.**
      //
      //	`adres()` bir AG cagrisidir ve ustelik 6'li semafor kuyrugunda
      //	bekler (turu 91 performans fix'i), yani pencere GENISTIR.
      //	Kullanici oynat'a basip URL gelmeden geri donerse/karti listeden
      //	kaydirirsa `dispose()` kosar ama `_calanId != widget.mediaId`
      //	oldugu icin oynaticiyi DURDURMAZ; ardindan bu satirin altindaki
      //	`play()` calisir ve **ekranda hicbir oynatici yokken ses caimaya
      //	baslar** — durdurma yolu da kalmaz (yalniz gelen arama susturur).
      //	Ayrica asagidaki uc abonelik `dispose`tan SONRA kurulacagi icin
      //	HIC iptal edilmez: statik oynaticida kalici dinleyici birikir.
      // ⚠️ YAPMA: bu kapiyi kaldirma.
      if (!mounted) return;
      final url = d['url'] as String?;
      if (url == null) return;

      // ⚠️ "ARAMA KAZANIR": arama kurulurken oynatma DURUR.
      //    ⚠️ `SesSahipligi`e YAZILMAZ (bkz. ses_notu_kontrol.dart şerhi).
      SesNotuKontrol.kaydol(_sahip, () async {
        await _oynatici.stop();
        if (mounted) setState(() => _caliyor = false);
        _calanId = null;
      });

      await _oynatici.play(UrlSource(url));
      await _oynatici.setPlaybackRate(_hiz);
      _calanId = widget.mediaId;
      _konumSub?.cancel();
      _konumSub = _oynatici.onPositionChanged.listen((p) {
        if (mounted) setState(() => _konum = p);
      });
      _sureSub?.cancel();
      _sureSub = _oynatici.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _ogrenilenSure = d);
      });
      _bittiSub?.cancel();
      _bittiSub = _oynatici.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _caliyor = false;
            _konum = Duration.zero;
          });
        }
        _calanId = null;
        SesNotuKontrol.birak(_sahip);
      });
      if (mounted) setState(() => _caliyor = true);
    } catch (_) {
      if (mounted) setState(() => _caliyor = false);
      SesNotuKontrol.birak(_sahip);
    }
  }

  Future<void> _hizDegistir() async {
    // ⚠️ 1x -> 1.5x -> 2x -> 1x döngüsü (WhatsApp deseni).
    final yeni = _hiz == 1.0 ? 1.5 : (_hiz == 1.5 ? 2.0 : 1.0);
    setState(() => _hiz = yeni);
    if (_caliyor) await _oynatici.setPlaybackRate(yeni);
  }

  List<int> get _kovalar {
    if (widget.dalga.isEmpty) return List.filled(30, 30);
    final p = widget.dalga
        .split(',')
        // ⚠️ TURU 74b: UST SINIR da SART — sunucudan bozuk `waveform` gelirse
        //    28px'lik kutuda yuzlerce piksellik cubuk = RenderFlex tasmasi.
        .map((x) => (int.tryParse(x) ?? 0).clamp(0, 99))
        .toList();
    return p.isEmpty ? List.filled(30, 30) : p;
  }

  String _sure(Duration d) {
    final sn = d.inSeconds;
    return '${(sn ~/ 60).toString().padLeft(2, '0')}:'
        '${(sn % 60).toString().padLeft(2, '0')}';
  }

  /// ⚠️⚠️⚠️ TURU 104 — **ARANAN NOKTAYA ATLAMA (seek).**
  ///
  ///	Yalniz BU balon caliyorsa anlamlidir: oynatici PAYLASILAN statik bir
  ///	nesnedir (`gebzem_sesnotu`), baska bir balon calarken buradan `seek`
  ///	cagirmak ONUN konumunu degistirirdi.
  /// ⚠️ Toplam sure bilinmiyorsa (henuz `onDurationChanged` gelmediyse) hicbir
  ///    sey yapilmaz — 0 ms'e atlamak sesi basa sarardi.
  Future<void> _atla(double oran, Duration toplam) async {
    if (_calanId != widget.mediaId || toplam <= Duration.zero) return;
    final hedef = Duration(
      milliseconds: (toplam.inMilliseconds * oran.clamp(0.0, 1.0)).round(),
    );
    await _oynatici.seek(hedef);
    if (mounted) setState(() => _konum = hedef);
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Once SUNUCUDAN gelen sure, yoksa OYNATICIDAN ogrenilen.
    final toplam = widget.sureMs > 0
        ? Duration(milliseconds: widget.sureMs)
        : (_ogrenilenSure ?? Duration.zero);
    final toplamMs = toplam.inMilliseconds;
    final oran = toplamMs == 0
        ? 0.0
        : (_konum.inMilliseconds / toplamMs).clamp(0.0, 1.0);
    return widget.akista
        ? _akisKarti(context, toplam, oran)
        : _sohbetBalonu(context, toplam, oran);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AKIS KARTI (Instagram tarzi)
  //
  // ⚠️⚠️ **BU BIR GORUNUM VARYANTIDIR, IKINCI BIR OYNATICI DEGIL.** Oynatma,
  //	tek-slot devralma, `SesNotuKontrol` kaydi ve arama kapisi YUKARIDAKI
  //	TEK govdededir. Akis icin ayri bir bilesen yazmak, gelen aramanin
  //	gonderi sesini susturamamasi demekti (turu 73 defteri).
  // ⚠️ Sohbet balonunun olculeri (230 dp genislik, 11.5 punto, sabit yesil/mor)
  //    bir BALON icin secilmisti; akis karti tam genisliktir ve temadan boyanir.
  // ═══════════════════════════════════════════════════════════════════════
  Widget _akisKarti(BuildContext context, Duration toplam, double oran) {
    final scheme = Theme.of(context).colorScheme;
    final dalgaVar = widget.dalga.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // ---- OYNAT / DURAKLAT
          // ⚠️ 46 dp: Material dokunma minimumu 48'e komsu, kart yuksekligini
          //    sismeden karsiliyor.
          Semantics(
            button: true,
            label: _caliyor ? 'Duraklat' : 'Oynat',
            child: InkWell(
              onTap: _oynatDurdur,
              customBorder: const CircleBorder(),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                ),
                child: Icon(
                  _caliyor ? LucideIcons.pause : LucideIcons.play,
                  size: 20,
                  color: scheme.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- ILERLEME
                LayoutBuilder(
                  builder: (_, k) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        _atla(d.localPosition.dx / k.maxWidth, toplam),
                    onHorizontalDragUpdate: (d) =>
                        _atla(d.localPosition.dx / k.maxWidth, toplam),
                    child: SizedBox(
                      height: 26,
                      child: dalgaVar
                          ? _dalga(oran, scheme.primary)
                          : _serit(oran, scheme),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      // ⚠️⚠️ **SURE BILINMIYORSA "00:00" YAZILMAZ.**
                      //	Gonderi hattinda sure sunucudan GELMEZ ve
                      //	oynaticidan ancak CALINCA ogrenilir. Oynatilmamis
                      //	kartta "00:00" yazmak "bu ses sifir saniye" der —
                      //	yani YANLIS BILGI; kullanici da bunu bozuk sanar.
                      //	"--:--" bilinmedigini DURUSTCE soyler.
                      // ⚠️ Sureyi onceden ogrenmek icin her karta kaynak
                      //    yuklemek gerekirdi: akista onlarca ses = onlarca
                      //    bosa indirme.
                      toplam == Duration.zero && !_caliyor
                          ? '--:--'
                          : _sure(_caliyor || _konum > Duration.zero
                              ? _konum
                              : toplam),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const Spacer(),
                    // ⚠️ HIZ her zaman gorunur (sohbette yalniz calarken):
                    //    akis kartinda dugme kaybolup belirmesi satiri
                    //    ziplatiyordu.
                    GestureDetector(
                      onTap: _hizDegistir,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: scheme.onSurface.withValues(alpha: 0.07),
                        ),
                        child: Text(
                          '${_hiz == 1.0 ? '1' : _hiz}x',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dalga (yalniz `dalga` verisi VARSA — sohbet hatti).
  Widget _dalga(double oran, Color renk) {
    final kovalar = _kovalar;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < kovalar.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5),
              child: Container(
                height: 3 + kovalar[i] / 99 * 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: i / kovalar.length <= oran
                      ? renk
                      : renk.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ⚠️⚠️⚠️ **DALGA VERISI YOKKEN SERIT CIZILIR, SAHTE DALGA DEGIL.**
  ///
  ///	Gonderi hattinda ses dalgasi TASINMIYOR (`posts` tablosunda boyle bir
  ///	sutun yok; sohbette ayri sutunlar var). Eski kod bu durumda **30 adet
  ///	ESIT YUKSEKLIKTE cubuk** ciziyordu — hicbir gercek kaydin dalgasi
  ///	duz degildir, yani ekranda bir VERI VARMIS gibi duruyor ama o veri
  ///	UYDURMA. Bu projede sahte veri cizmek yasak.
  /// ⚠️ Serit ayrica DURUST: "burada bir ilerleme var" der, "ses su anda su
  ///    kadar yuksekti" DEMEZ.
  /// ⚠️ Gercek dalga icin gonderi olusturma akisi genligi kaydedip sunucuya
  ///    yollamali (sohbette ZATEN oyle yapiliyor) ve `posts` bir sutun
  ///    kazanmali. Yapilana kadar serit kalir.
  Widget _serit(double oran, ColorScheme scheme) => Center(
    child: SizedBox(
      height: 6,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                // ⚠️ Zemin **0.12 -> 0.30**: olculdu, eski deger ~1.2:1
                //    kontrast veriyordu ve seridin NEREYE kadar gittigi
                //    (yani sesin uzunlugu) gorunmuyordu.
                color: scheme.onSurface.withValues(alpha: 0.30),
              ),
            ),
          ),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: oran,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // SOHBET BALONU — turu 74'te sahada test edilmis hali. DOKUNULMADI.
  // ⚠️ Renkler BILEREK sabit: balon zemini de sabittir (`ChatColors`), temadan
  //    boyanirsa acik temada kontrast cokuyordu (turu 81b sevk engeli).
  // ═══════════════════════════════════════════════════════════════════════
  Widget _sohbetBalonu(BuildContext context, Duration toplam, double oran) {
    final kovalar = _kovalar;
    // ⚠️⚠️⚠️ TURU 113 (denetim, YUKSEK) — **KOYU TEMADA DALGA VE HIZ
    //	GORUNMUYORDU.**
    //
    //	Renkler "balon zemini de sabit" gerekcesiyle sabit birakilmisti; ama
    //	o gerekce ZEMIN icindi. Bunlar ON PLAN (dalga dolgusu + "1.5x"),
    //	ve balon zemini TEMAYA GORE DEGISIYOR (`ChatColors`). Olculen
    //	kontrast:
    //	  acik · benim  #D9FDD3 -> 4.74:1  ✓
    //	  acik · karsi  #FFFFFF -> 4.81:1  ✓
    //	  **koyu · benim #075E54 -> 1.46:1  ✗**
    //	  **koyu · karsi #262D31 -> 2.90:1  ✗**
    //	Varsayilan tema `ThemeMode.system` oldugu icin kullanicilarin buyuk
    //	kismi bu daldadir.
    // ⚠️ YAPMA: tek sabit renge donme; zemin temaya bagliyken on plan
    //    sabit kalamaz.
    final koyu = Theme.of(context).brightness == Brightness.dark;
    //
    // ⚠️⚠️⚠️ TURU 115b - **YUKARIDAKI OLCUMLER BAYAT, RENKLER YESILDI.**
    //	Bu iki ton (`#7FE9A8` / `#0B7C4B`) o zamanki **YESIL** balona gore
    //	secilmisti. Balon turu 115b'de MOR oldu (`ChatColors.bubbleMine`) ve
    //	sonuc su hale geldi: kendi ses notunda **MOR balonun icinde YESIL
    //	dalga formu ve YESIL "1.5x" yazisi**; karsi tarafin balonu ise mor.
    //	Ayni ekranda iki balon IKI FARKLI RENK AILESINDEYDI ve kullanicinin
    //	*"yesil renk yapma artik"* emriyle dogrudan celisiyordu.
    //	⚠️ Ustelik acik temada kontrast **4.29:1**'e dusmustu (11,5 px
    //	   "1.5x" yazisi icin 4.5 esiginin ALTI).
    //
    //	YENI OLCUM:
    //	  acik  #5B21B6 -> #EDE4FF uzerinde **7.06:1** · #FFFFFF **8.49:1**
    //	  koyu  #C0A8FF -> #3B2A63 uzerinde **6.28:1** · #262D31 **8.11:1**
    //
    // ⚠️⚠️ `benimMi` AYRIMI KALDIRILDI: iki balon da artik MOR ailede
    //    ve konusanin kim oldugu BALONUN KENDI ZEMININDEN belli (bubbleMine
    //    vs bubbleOther). Dalga formunu ayrica ayirmak ikinci bir renk
    //    kodu demekti ve o kod yesil olarak geride kalmisti.
    // ⚠️ YAPMA: yesil tonlari geri getirme.
    // ⚠️ YAPMA: tek SABIT renge donme; zemin temaya bagliyken on plan
    //    sabit kalamaz (bu satirin ustundeki serhin asil dersi budur).
    final aktifRenk = koyu
        ? const Color(0xFFC0A8FF)
        : const Color(0xFF5B21B6);

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              _caliyor ? LucideIcons.pause : LucideIcons.play,
              size: 22,
            ),
            onPressed: _oynatDurdur,
          ),
          Expanded(
            child: SizedBox(
              height: 28,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < kovalar.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Container(
                          // ⚠️ En az 3px: sessiz anlar tamamen kaybolmasın.
                          height: 3 + kovalar[i] / 99 * 22,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: i / kovalar.length <= oran
                                ? aktifRenk
                                : aktifRenk.withValues(alpha: 0.28),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _sure(_caliyor ? _konum : toplam),
            style: const TextStyle(fontSize: 11.5),
          ),
          if (_caliyor || _hiz != 1.0)
            GestureDetector(
              // ⚠️ TURU 113 (denetim) — `behavior` olmadan `Padding`in
              //    bos alani dokunus ALMIYORDU (kardes akis karti
              //    `opaque` kullaniyor).
              behavior: HitTestBehavior.opaque,
              onTap: _hizDegistir,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6,
                    vertical: 10),
                child: Text(
                  '${_hiz == 1.0 ? '1' : _hiz}x',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: aktifRenk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
