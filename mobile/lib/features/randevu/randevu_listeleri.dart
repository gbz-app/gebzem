import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../router.dart' show rootMessengerKey;
import '../medya/medya_gorsel.dart';
import 'randevu_servisi.dart';

/// ⚠️⚠️ TURU 80 — RANDEVU LISTELERI (musteri + isletme).
///
/// ⚠️ TEK EKRAN, `isletmeGorunumu` BAYRAGIYLA: iki ayri ekran yazmak satir
///    cizimi, durum etiketleri, bos durum ve tazeleme mantiginin IKI KOPYASI
///    demekti — bu projede ALTI kez zarar goren sinif. Fark yalnizca (a) hangi
///    ucun cagrildigi, (b) hangi eylem dugmelerinin cizildigi.
class RandevuListesiEkrani extends ConsumerStatefulWidget {
  const RandevuListesiEkrani({super.key, this.isletmeGorunumu = false});

  /// false = "Randevularım" (musteri) · true = isletmenin GELEN KUTUSU.
  final bool isletmeGorunumu;

  @override
  ConsumerState<RandevuListesiEkrani> createState() =>
      _RandevuListesiEkraniState();
}

class _RandevuListesiEkraniState
    extends ConsumerState<RandevuListesiEkrani> {
  List<Randevu>? _liste;
  String? _hata;
  bool _gecmis = false;

  /// ⚠️ Islem suren randevunun id'si — ayni satirda cift dokunmayi engeller.
  String? _mesgul;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _hata = null);
    // ⚠️ Servis await'ten ONCE.
    final svc = ref.read(randevuServisiProvider);
    final gecmis = _gecmis;
    try {
      final l = widget.isletmeGorunumu
          ? await svc.isletmeRandevulari(gecmis: gecmis)
          : await svc.randevularim(gecmis: gecmis);
      if (!mounted || gecmis != _gecmis) return;
      setState(() => _liste = l);
    } catch (e) {
      if (!mounted || gecmis != _gecmis) return;
      setState(() => _hata = apiErrorMessage(e));
    }
  }

  /// ⚠️⚠️ TURU 80b — RED/IPTAL SEBEBI SORULUR (denetim: `not_isletme` OLU IDI).
  ///
  ///	Sunucudaki `not_isletme` alaninin YAZAN yolu yoktu; musteri red
  ///	bildirimini sebepsiz aliyor, cogu zaman ayni talebi tekrar
  ///	gonderiyordu. Sebep OPSIYONEL (bos gecilebilir) — zorunlu kilmak
  ///	isletmeyi yavaslatirdi.
  /// ⚠️ YALNIZ olumsuz gecislerde sorulur; "Onayla"/"Geldi" akisini
  ///    yavaslatmak anlamsiz olurdu.
  static const _sebepSorulan = {'reddedildi', 'iptal_isletme'};

  Future<void> _durum(Randevu r, String yeni) async {
    if (_mesgul != null) return;
    var not = '';
    if (widget.isletmeGorunumu && _sebepSorulan.contains(yeni)) {
      final s = await _sebepSor(yeni == 'reddedildi' ? 'Reddet' : 'İptal et');
      // ⚠️ `null` = VAZGECTI (bos dize = "sebep yazmadan devam et").
      if (s == null || !mounted) return;
      not = s;
    }
    setState(() => _mesgul = r.id);
    final svc = ref.read(randevuServisiProvider);
    try {
      await svc.durum(r.id, yeni, notIsletme: not);
      if (!mounted) return;
      // ⚠️ Yerel nesneyi YAMAMAK yerine listeyi SUNUCUDAN tazeliyoruz:
      //    durum gecisi sunucuda reddedilmis olabilir (yaris).
      await _yukle();
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
      // ⚠️ Hata 409 ise satir BAYAT demektir — tazele.
      if (mounted) unawaited(_yukle());
    } finally {
      if (mounted) setState(() => _mesgul = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isletmeGorunumu ? 'Gelen randevular' : 'Randevularım',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Yaklaşan')),
                ButtonSegment(value: true, label: Text('Geçmiş')),
              ],
              selected: {_gecmis},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                setState(() {
                  _gecmis = s.first;
                  _liste = null;
                });
                unawaited(_yukle());
              },
            ),
          ),
          Expanded(
            child: _hata != null
                ? Center(child: Text(_hata!))
                : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Text(
                        widget.isletmeGorunumu
                            ? (_gecmis
                                  ? 'Geçmiş randevu yok.'
                                  : 'Bekleyen randevu yok.')
                            : (_gecmis
                                  ? 'Geçmiş randevun yok.'
                                  : 'Yaklaşan randevun yok.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _yukle,
                    child: ListView.separated(
                      // ⚠️ Icerik ekrani doldurmasa da asagi-cek calissin
                      //    (turu 77b dersi).
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 30),
                      itemCount: l.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) => _satir(l[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _satir(Randevu r) {
    final bekliyor = r.durum == 'bekliyor';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(
                ad: r.karsiAd,
                mediaId: r.karsiAvatarMediaId,
                cap: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.karsiAd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      randevuZamani(r.baslangic),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              _durumRozeti(r),
            ],
          ),
          const SizedBox(height: 6),
          // ⚠️ REZERVASYONDA kisi sayisi, RANDEVUDA hizmet gosterilir —
          //    sunucudan gelen `tur` karar verir (istemci TAHMIN ETMEZ).
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.rezervasyonMu)
                  Text(
                    '${r.kisiSayisi} kişi',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  )
                else if (r.hizmet.isNotEmpty)
                  Text(
                    r.hizmet,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                if (r.notMusteri.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      r.notMusteri,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                // ⚠️⚠️ TURU 80b — ISLETME NOTU ARTIK CIZILIYOR (denetim).
                //    `not_isletme` sutunu, istek alani, SQL'i, yaniti ve Dart
                //    modeli VARDI ama ne YAZAN ne CIZEN bir yol vardi. Isletme
                //    "Reddet" derken sebep yaziyor (asagidaki `_durumSor`) ve
                //    musteri o sebebi BURADA goruyor — aksi halde red sebepsiz
                //    gorunur ve musteri tekrar tekrar talep gonderir.
                if (r.notIsletme.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          LucideIcons.messageSquare,
                          size: 13,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            r.notIsletme,
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ---- EYLEMLER
          if (r.aktif)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 6),
              child: Wrap(
                spacing: 8,
                children: [
                  // ⚠️ ONAY/RED YALNIZ ISLETMEDE ve YALNIZ 'bekliyor'da.
                  //    Sunucu da ayni kapiyi uyguluyor (gecis tablosu) —
                  //    burasi yalnizca ARAYUZ; yetki kontrolu sunucuda.
                  if (widget.isletmeGorunumu && bekliyor) ...[
                    FilledButton(
                      onPressed: _mesgul == r.id
                          ? null
                          : () => _durum(r, 'onaylandi'),
                      child: const Text('Onayla'),
                    ),
                    OutlinedButton(
                      onPressed: _mesgul == r.id
                          ? null
                          : () => _durum(r, 'reddedildi'),
                      child: const Text('Reddet'),
                    ),
                  ],
                  // ⚠️⚠️⚠️ TURU 80b — "Geldi / Gelmedi" DUGMELERI (denetim:
                  //    OLU OZELLIK). Iki durum da `sabit.go`daki gecis
                  //    tablosunda TANIMLI, `durumMetni`nde METNI VAR ve
                  //    `_durumRozeti` 'geldi'yi YESIL ciziyordu — ama bu
                  //    durumlari YAZAN HICBIR DUGME YOKTU, yani isletme
                  //    katilimi hicbir zaman isaretleyemiyordu.
                  // ⚠️ Gecis tablosu ikisini de YALNIZ 'onaylandi'dan kabul
                  //    eder; arayuz de ayni kapiyi uygular (sunucu OTORITE).
                  if (widget.isletmeGorunumu && r.durum == 'onaylandi') ...[
                    FilledButton.tonal(
                      onPressed: _mesgul == r.id
                          ? null
                          : () => _durum(r, 'geldi'),
                      child: const Text('Geldi'),
                    ),
                    OutlinedButton(
                      onPressed: _mesgul == r.id
                          ? null
                          : () => _durum(r, 'gelmedi'),
                      child: const Text('Gelmedi'),
                    ),
                  ],
                  if (widget.isletmeGorunumu && !bekliyor)
                    OutlinedButton(
                      onPressed: _mesgul == r.id
                          ? null
                          : () => _durum(r, 'iptal_isletme'),
                      child: const Text('İptal et'),
                    ),
                  // ⚠️ MUSTERI yalniz IPTAL edebilir (gecis tablosu).
                  if (!widget.isletmeGorunumu)
                    OutlinedButton(
                      onPressed: _mesgul == r.id
                          ? null
                          : () => _durum(r, 'iptal'),
                      child: const Text('İptal et'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Sebep diyalogu. `null` = vazgecildi · `''` = sebepsiz devam.
  Future<String?> _sebepSor(String eylem) async {
    final c = TextEditingController();
    final s = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('$eylem — sebep'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 200,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Örn. o saat doldu, başka saat önerebiliriz',
            helperText: 'İsteğe bağlı — müşteri bu notu görür',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: Text(eylem),
          ),
        ],
      ),
    );
    c.dispose();
    return s;
  }

  Widget _durumRozeti(Randevu r) {
    final renk = switch (r.durum) {
      'onaylandi' || 'geldi' => const Color(0xFF2BB673),
      'bekliyor' => const Color(0xFFFFB03A),
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        r.durumMetni,
        style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// ⚠️⚠️ TURU 80 — ISLETMENIN RANDEVU AYARLARI.
///
/// ⚠️ Ozellik VARSAYILAN OLARAK KAPALI: isletme acikca acmadan profilinde
///    randevu dugmesi CIZILMEZ. Aksi halde calisma saatlerini girmemis bir
///    isletme "randevu aliyor" gorunur ve musteri bos slot listesiyle karsilasir.
class RandevuAyarEkrani extends ConsumerStatefulWidget {
  const RandevuAyarEkrani({super.key});

  @override
  ConsumerState<RandevuAyarEkrani> createState() => _RandevuAyarEkraniState();
}

class _RandevuAyarEkraniState extends ConsumerState<RandevuAyarEkrani> {
  RandevuAyar? _a;
  String? _hata;
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final svc = ref.read(randevuServisiProvider);
    try {
      final a = await svc.ayar();
      if (mounted) setState(() => _a = a);
    } catch (e) {
      if (mounted) setState(() => _hata = apiErrorMessage(e));
    }
  }

  /// ⚠️ YALNIZ DEGISEN alan gonderilir; gonderilmeyeni sunucu KORUR
  ///    (`COALESCE`). Tum alanlari kosulsuz gondermek, kullanicinin
  ///    dokunmadigi ayari ezme riskidir (turu 78 koordinat dersi).
  Future<void> _kaydet({
    bool? acik,
    int? slotDakika,
    int? slotKapasite,
    int? ileriGun,
    bool? otomatikOnay,
  }) async {
    if (_kaydediliyor) return;
    setState(() => _kaydediliyor = true);
    final svc = ref.read(randevuServisiProvider);
    try {
      final a = await svc.ayarKaydet(
        acik: acik,
        slotDakika: slotDakika,
        slotKapasite: slotKapasite,
        ileriGun: ileriGun,
        otomatikOnay: otomatikOnay,
      );
      if (mounted) setState(() => _a = a);
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return Scaffold(
      appBar: AppBar(title: const Text('Randevu ayarları')),
      body: _hata != null
          ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Text(_hata!)))
          : a == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    a.rezervasyonMu
                        ? 'Rezervasyon al'
                        : 'Randevu al',
                  ),
                  subtitle: Text(
                    a.rezervasyonMu
                        ? 'Müşteriler profilinden masa ayırtabilir'
                        : 'Müşteriler profilinden randevu alabilir',
                  ),
                  value: a.acik,
                  onChanged: _kaydediliyor
                      ? null
                      : (v) => _kaydet(acik: v),
                ),
                const Divider(),
                // ⚠️ Ayarlar YALNIZ ozellik ACIKKEN gosterilir — kapaliyken
                //    cizmek "bunlar bir ise yariyor" izlenimi verirdi.
                if (a.acik) ...[
                  _sayiSatiri(
                    'Randevu süresi',
                    '${a.slotDakika} dakika',
                    const [15, 20, 30, 45, 60, 90],
                    a.slotDakika,
                    (v) => _kaydet(slotDakika: v),
                    ek: 'dk',
                  ),
                  _sayiSatiri(
                    a.rezervasyonMu ? 'Aynı saatte kaç masa' : 'Aynı saatte kaç kişi',
                    '${a.slotKapasite}',
                    const [1, 2, 3, 5, 8, 10, 15, 20],
                    a.slotKapasite,
                    (v) => _kaydet(slotKapasite: v),
                  ),
                  _sayiSatiri(
                    'Kaç gün ileriye',
                    '${a.ileriGun} gün',
                    const [3, 7, 14, 30],
                    a.ileriGun,
                    (v) => _kaydet(ileriGun: v),
                    ek: 'gün',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Otomatik onayla'),
                    subtitle: const Text(
                      'Kapalıysa her talebi sen onaylarsın',
                    ),
                    value: a.otomatikOnay,
                    onChanged: _kaydediliyor
                        ? null
                        : (v) => _kaydet(otomatikOnay: v),
                  ),
                  // ⚠️⚠️⚠️ TURU 80b — KAPALI GUNLERIN GIRISI (denetim: OLU OZELLIK).
                  //    `randevu_kapali` tablosu (migration 038), IKI backend ucu
                  //    (GET/PUT /isletme/randevu-kapali), `Slotlar` icindeki
                  //    kapali-gun dali ve IKI servis metodu (`kapaliGunler`,
                  //    `kapaliGunAyarla`) HEPSI vardi — ama CAGIRAN ARAYUZ YOKTU.
                  //    Yani tablo hicbir zaman dolamiyor, dolayisiyla isletme
                  //    bayramda/tatilde randevu almayi DURDURAMIYORDU.
                  //    Bu, CLAUDE.md'de ALTI kez yasandigi yazili "olu ozellik"
                  //    sinifinin YEDINCI tekrariydi.
                  // ⚠️ DERS (tekrar): bir sutun/uc/servis ekledigin AN onu
                  //    KULLANAN yolu da yaz.
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(LucideIcons.calendarOff),
                    title: const Text('Kapalı günler'),
                    subtitle: const Text(
                      'Bayram, tatil ya da izin günlerinde randevu verilmez',
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const KapaliGunlerEkrani(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Saatler işletme profilindeki çalışma saatlerinden '
                    'üretilir. Kapalı olduğun günlerde randevu verilmez.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                // ⚠️⚠️ TURU 80b — "Gelen randevular" ARTIK `a.acik` KAPISININ
                //    DISINDA (denetim bulgusu). Iceride oldugunda isletme
                //    randevu almayi KAPATIR KAPATMAZ dugme kayboluyor ve
                //    ZATEN ALINMIS, HENUZ ONAYLANMAMIS randevular
                //    **ULASILAMAZ** hale geliyordu: musteri bekliyor, isletme
                //    goremiyor, kimse iptal edemiyor.
                //    ⚠️ Ozelligi kapatmak GELECEK talepleri durdurur; MEVCUT
                //       taahhutleri yok saymaz (sunucudaki "engel mevcut
                //       randevuyu gizlemez" karariyla ayni ilke).
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const RandevuListesiEkrani(isletmeGorunumu: true),
                    ),
                  ),
                  icon: const Icon(LucideIcons.calendarCheck, size: 18),
                  label: const Text('Gelen randevular'),
                ),
              ],
            ),
    );
  }

  Widget _sayiSatiri(
    String baslik,
    String deger,
    List<int> secenekler,
    int mevcut,
    void Function(int) sec, {
    String ek = '',
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(baslik),
    trailing: Text(deger, style: const TextStyle(fontWeight: FontWeight.w700)),
    onTap: _kaydediliyor
        ? null
        : () async {
            final v = await showModalBottomSheet<int>(
              context: context,
              builder: (c) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in secenekler)
                      ListTile(
                        title: Text('$s${ek.isEmpty ? '' : ' $ek'}'),
                        trailing: s == mevcut
                            ? const Icon(LucideIcons.check, size: 18)
                            : null,
                        onTap: () => Navigator.pop(c, s),
                      ),
                  ],
                ),
              ),
            );
            if (v != null) sec(v);
          },
  );
}

/// ⚠️⚠️⚠️ TURU 80b — KAPALI GUNLER (bayram/tatil/izin). **YENI EKRAN.**
///
/// Denetim bulgusu: `randevu_kapali` tablosu + iki uc + `Slotlar` icindeki
/// kapali-gun dali + iki servis metodu HAZIRDI, ama ONLARI CAGIRAN EKRAN
/// YOKTU — yani isletme tatilde randevu almayi DURDURAMIYORDU.
///
/// ⚠️ `showDatePicker` BURADA KULLANILABILIR: turu 80 `flutter_localizations`
///    ve `locale: Locale('tr')` ekledi, yani secici TURKCE aciliyor. (Eski
///    serhlerdeki "showDatePicker EKLEME" hukmu o eksiklige dayaniyordu ve
///    ARTIK GECERSIZ.)
/// ⚠️ Secici `firstDate` = BUGUN: gecmis bir gunu kapatmak anlamsiz, ustelik
///    `Slotlar` gecmis slotlari zaten eliyor.
/// ⚠️ `lastDate` = bugun + 1 yil: `ileri_gun` en fazla 60 olabilir, yani bir
///    yil fazlasiyla yeterli ve secicide sonsuz kaydirma olusmaz.
class KapaliGunlerEkrani extends ConsumerStatefulWidget {
  const KapaliGunlerEkrani({super.key});

  @override
  ConsumerState<KapaliGunlerEkrani> createState() => _KapaliGunlerEkraniState();
}

class _KapaliGunlerEkraniState extends ConsumerState<KapaliGunlerEkrani> {
  List<String>? _gunler;
  String? _hata;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    // ⚠️ Servis await'ten ONCE yakalanir (turu 78b: disposed State'te
    //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
    final svc = ref.read(randevuServisiProvider);
    try {
      final l = await svc.kapaliGunler();
      if (mounted) setState(() => _gunler = l);
    } catch (e) {
      if (mounted) setState(() => _hata = apiErrorMessage(e));
    }
  }

  /// ⚠️ Yeniden giris kilidi (`_mesgul`): cift dokunus iki PUT atardi.
  Future<void> _ayarla(String tarih, bool kapali) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    final svc = ref.read(randevuServisiProvider);
    try {
      await svc.kapaliGunAyarla(tarih, kapali);
      final l = await svc.kapaliGunler();
      // ⚠️ `_hata` DA TEMIZLENIR (turu 80b denetimi): ilk yukleme hata
      //    verdikten sonra kullanici "Gün ekle" ile BASARILI bir islem
      //    yaparsa ekran hala ESKI HATA METNINI cizerdi — islem tuttugu
      //    halde "yuklenemedi" gorunurdu.
      if (mounted) {
        setState(() {
          _gunler = l;
          _hata = null;
        });
      }
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _ekle() async {
    final bugun = DateTime.now();
    final s = await showDatePicker(
      context: context,
      initialDate: bugun,
      firstDate: DateTime(bugun.year, bugun.month, bugun.day),
      lastDate: bugun.add(const Duration(days: 365)),
      helpText: 'Kapatılacak günü seç',
      cancelText: 'Vazgeç',
      confirmText: 'Kapat',
    );
    if (s == null) return;
    final t =
        '${s.year.toString().padLeft(4, '0')}-'
        '${s.month.toString().padLeft(2, '0')}-'
        '${s.day.toString().padLeft(2, '0')}';
    await _ayarla(t, true);
  }

  /// "2026-08-30" -> "30 Ağustos 2026, Pazar"
  String _bicim(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day} ${kAyAdlari[d.month - 1]} ${d.year}, '
        '${kGunUzun[d.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final g = _gunler;
    return Scaffold(
      appBar: AppBar(title: const Text('Kapalı günler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mesgul ? null : _ekle,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Gün ekle'),
      ),
      body: _hata != null
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(_hata!)),
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _hata = null);
                      _yukle();
                    },
                    child: const Text('Tekrar dene'),
                  ),
                ),
              ],
            )
          : g == null
          ? const Center(child: CircularProgressIndicator())
          : g.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Icon(LucideIcons.calendarCheck, size: 48, color: Colors.grey),
                SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Kapalı gün yok.\nBayram ya da tatil günlerini buradan '
                    'kapatabilirsin; o günlerde randevu verilmez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: g.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => ListTile(
                leading: const Icon(LucideIcons.calendarOff),
                title: Text(_bicim(g[i])),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18),
                  tooltip: 'Kaldır',
                  onPressed: _mesgul ? null : () => _ayarla(g[i], false),
                ),
              ),
            ),
    );
  }
}
