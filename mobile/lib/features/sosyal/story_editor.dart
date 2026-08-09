import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'medya_video.dart';
import 'story_katman.dart';

/// ⚠️⚠️ TURU 77 — HIKAYE EDITORU (kullanici emri: "storyde AA gibi, renk gibi,
/// yazi tipi gibi ne varsa olacak").
///
/// KAPSAM:
///   · METIN katmani ekle / duzenle / sil
///   · YAZI TIPI (6 secenek — bkz. story_katman.dart, EK PAKET YOK)
///   · RENK (10 renk paleti)
///   · BOYUT ("AA" kaydiraci)
///   · HIZA (sol/orta/sag) ve OKUNURLUK KUTUSU (yok/dolu/seffaf)
///   · SURUKLEYEREK KONUMLANDIRMA
///   · SADECE METIN hikayesi icin ZEMIN gradyani
///
/// ⚠️⚠️ METIN GORUNTUYE PISIRILMEZ — meta veri olarak gonderilir (bkz.
///    migration 027 serhi). Sebep: VIDEO hikayeye yazi gomulemez; pisirme
///    secilseydi ozellik yalniz fotografta calisirdi = yarim ozellik.
///
/// ⚠️ CIZIM `storyKatmanCiz()` ILE YAPILIR — izleyicinin kullandigi AYNI
///    fonksiyon. Iki ayri cizim kodu yazilsaydi editorde gordugun yer ile
///    izleyicideki yer DRIFT ederdi ("yazdigim yerde durmuyor").
class StoryEditor extends StatefulWidget {
  const StoryEditor({
    super.key,
    this.dosya,
    this.video = false,
    this.metinHikayesi = false,
  });

  /// Secilen medya (metin hikayesinde `null`).
  final File? dosya;
  final bool video;

  /// Medyasiz, gradyan zeminli hikaye.
  final bool metinHikayesi;

  @override
  State<StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends State<StoryEditor> {
  final List<StoryKatman> _katmanlar = [];
  int _secili = -1;
  String _arkaPlan = 'mor';

  /// Alt panelde ne acik: yok | yazi | renk | font
  String _panel = 'yok';

  StoryKatman? get _k => (_secili >= 0 && _secili < _katmanlar.length)
      ? _katmanlar[_secili]
      : null;

  @override
  void initState() {
    super.initState();
    // ⚠️ Metin hikayesi METINSIZ ANLAMSIZ — editor acilir acilmaz bir katman
    //    ve klavye gelir. Aksi halde kullanici bos gradyanla karsilasip
    //    "ne yapacagim" diye kalirdi.
    if (widget.metinHikayesi) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _yaziEkle());
    }
  }

  Future<void> _yaziEkle() async {
    final yeni = StoryKatman(metin: '');
    final sonuc = await _metinGir(yeni);
    if (!mounted || sonuc == null || sonuc.trim().isEmpty) return;
    yeni.metin = sonuc.trim();
    setState(() {
      _katmanlar.add(yeni);
      _secili = _katmanlar.length - 1;
      _panel = 'yazi';
    });
  }

  Future<void> _duzenle(int i) async {
    final k = _katmanlar[i];
    final sonuc = await _metinGir(k);
    if (!mounted || sonuc == null) return;
    setState(() {
      if (sonuc.trim().isEmpty) {
        // ⚠️ Metni tamamen silmek = katmani silmek. Bos katman birakmak
        //    ekranda gorunmez ama dokunulabilir bir hayalet birakirdi.
        _katmanlar.removeAt(i);
        _secili = -1;
        _panel = 'yok';
      } else {
        k.metin = sonuc.trim();
        _secili = i;
      }
    });
  }

  /// Tam ekran metin girisi (Instagram deseni: klavye + ortada canli onizleme).
  Future<String?> _metinGir(StoryKatman k) {
    final ctrl = TextEditingController(text: k.metin);
    return showDialog<String>(
      context: context,
      barrierColor: const Color(0xCC000000),
      builder: (c) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(c, ctrl.text),
                    child: const Text(
                      'Bitti',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      maxLines: null,
                      maxLength: 400,
                      textAlign: storyHiza(k.hiza),
                      // ⚠️ Girisin kendisi de SECILI STILDE gorunur — kullanici
                      //    "nasil gorunecegini" yazarken gorur.
                      style: storyMetinStili(k, 1),
                      cursorColor: storyRenk(k.renk),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: 'Yazmaya başla',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(ctrl.dispose);
  }

  void _bitir() {
    // ⚠️ Bos katmanlar ELENIR (sunucu da eliyor, ama bosuna ag trafigi olmasin).
    final temiz = _katmanlar.where((k) => k.metin.trim().isNotEmpty).toList();
    if (widget.metinHikayesi && temiz.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce bir şeyler yaz')));
      return;
    }
    Navigator.of(context).pop(
      StoryCikti(
        katmanlar: temiz,
        arkaPlan: widget.metinHikayesi ? _arkaPlan : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, kisit) {
          final alan = Size(kisit.maxWidth, kisit.maxHeight);
          return Stack(
            children: [
              Positioned.fill(child: _tuval()),

              // ---- METIN KATMANLARI (surukle + dokun-duzenle)
              for (var i = 0; i < _katmanlar.length; i++)
                _suruklenebilir(i, alan),

              // ---- UST CUBUK
              SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    _ustDugme(LucideIcons.type, 'Yazı ekle', _yaziEkle),
                    if (_k != null)
                      _ustDugme(
                        LucideIcons.palette,
                        'Renk',
                        () => setState(
                          () => _panel = _panel == 'renk' ? 'yok' : 'renk',
                        ),
                      ),
                    if (_k != null)
                      _ustDugme(
                        LucideIcons.caseSensitive,
                        'Yazı tipi',
                        () => setState(
                          () => _panel = _panel == 'font' ? 'yok' : 'font',
                        ),
                      ),
                    if (_k != null)
                      _ustDugme(LucideIcons.alignCenter, 'Hizala', () {
                        setState(() {
                          final k = _k!;
                          k.hiza = k.hiza == 'orta'
                              ? 'sol'
                              : k.hiza == 'sol'
                              ? 'sag'
                              : 'orta';
                        });
                      }),
                    if (_k != null)
                      _ustDugme(LucideIcons.square, 'Arka plan', () {
                        setState(() {
                          final k = _k!;
                          k.kutu = k.kutu == 'yok'
                              ? 'seffaf'
                              : k.kutu == 'seffaf'
                              ? 'dolu'
                              : 'yok';
                        });
                      }),
                  ],
                ),
              ),

              // ---- ALT PANELLER
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_panel == 'renk' && _k != null) _renkPaleti(),
                      if (_panel == 'font' && _k != null) _fontSecici(),
                      if (widget.metinHikayesi && _panel == 'yok')
                        _zeminSecici(),
                      if (_k != null) _boyutKaydiraci(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                        child: Row(
                          children: [
                            if (_k != null)
                              _altDugme(
                                LucideIcons.trash2,
                                'Sil',
                                () => setState(() {
                                  _katmanlar.removeAt(_secili);
                                  _secili = -1;
                                  _panel = 'yok';
                                }),
                              ),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _bitir,
                              icon: const Icon(LucideIcons.check, size: 18),
                              label: const Text('Paylaş'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Hikayenin zemini: medya ya da gradyan.
  Widget _tuval() {
    if (widget.metinHikayesi) return storyZemin(_arkaPlan);
    final d = widget.dosya;
    if (d == null) return const ColoredBox(color: Colors.black);
    if (widget.video) {
      // ⚠️ Editorde video SESSIZ ve DONGULU: kullanici yaziyi yerlestirirken
      //    ses calmasi rahatsiz eder ve iOS'ta ses oturumunu gereksiz mesgul eder.
      return MedyaVideo(
        yerelDosya: d,
        otoOynat: true,
        sesli: false,
        dongu: true,
        dolgu: BoxFit.contain,
      );
    }
    return Image.file(d, fit: BoxFit.contain, width: double.infinity);
  }

  /// ⚠️ Katman SURUKLENEBILIR. Konum ORAN olarak guncellenir (piksel DEGIL) —
  ///    bkz. story_katman.dart serhi.
  Widget _suruklenebilir(int i, Size alan) {
    final k = _katmanlar[i];
    final secili = i == _secili;
    return Positioned.fill(
      child: Align(
        alignment: Alignment(k.x * 2 - 1, k.y * 2 - 1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            if (secili) {
              _duzenle(i);
            } else {
              _secili = i;
            }
          }),
          onPanUpdate: (d) => setState(() {
            k.x = (k.x + d.delta.dx / alan.width).clamp(0.05, 0.95);
            k.y = (k.y + d.delta.dy / alan.height).clamp(0.06, 0.94);
          }),
          child: Container(
            // ⚠️ Secili katmana kesikli cerceve: hangi katmanin duzenlendigini
            //    gormeden coklu katman yonetilemez.
            decoration: secili
                ? BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            padding: const EdgeInsets.all(4),
            child: _katmanGovde(k, alan),
          ),
        ),
      ),
    );
  }

  /// ⚠️ IZLEYICI ILE AYNI STIL. `storyKatmanCiz` bir `Positioned` dondurdugu
  ///    icin burada govdesini AYNI kurallarla kuruyoruz (stil + kutu + golge).
  ///    ⚠️ YAPMA: buradaki stil hesabini elle degistirme; `storyMetinStili`
  ///    disina cikarsan editor ile izleyici DRIFT eder.
  Widget _katmanGovde(StoryKatman k, Size alan) {
    final olcek = alan.width / 390.0;
    final stil = storyMetinStili(k, olcek);
    final renk = storyRenk(k.renk);
    final acikMi = renk.computeLuminance() > 0.5;
    final kutuRengi = k.kutu == 'yok'
        ? null
        : (k.kutu == 'dolu'
              ? (acikMi ? const Color(0xEE000000) : const Color(0xEEFFFFFF))
              : (acikMi ? const Color(0x66000000) : const Color(0x66FFFFFF)));
    Widget metin = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: alan.width - 40),
      child: Text(
        k.metin,
        textAlign: storyHiza(k.hiza),
        style: k.kutu == 'yok'
            ? stil.copyWith(
                shadows: const [
                  Shadow(blurRadius: 10, color: Color(0xCC000000)),
                ],
              )
            : stil,
      ),
    );
    if (kutuRengi != null) {
      metin = Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10 * olcek,
          vertical: 5 * olcek,
        ),
        decoration: BoxDecoration(
          color: kutuRengi,
          borderRadius: BorderRadius.circular(8 * olcek),
        ),
        child: metin,
      );
    }
    return Transform.rotate(angle: k.aci, child: metin);
  }

  Widget _ustDugme(IconData ikon, String ipucu, VoidCallback onTap) =>
      IconButton(
        tooltip: ipucu,
        icon: Icon(ikon, color: Colors.white),
        onPressed: onTap,
      );

  Widget _altDugme(IconData ikon, String etiket, VoidCallback onTap) =>
      TextButton.icon(
        onPressed: onTap,
        icon: Icon(ikon, size: 17, color: Colors.white),
        label: Text(etiket, style: const TextStyle(color: Colors.white)),
      );

  /// "AA" kaydiraci — kullanicinin ozellikle istedigi boyut kontrolu.
  Widget _boyutKaydiraci() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        const Text('A', style: TextStyle(color: Colors.white, fontSize: 13)),
        Expanded(
          child: Slider(
            value: _k!.boyut,
            min: 12,
            max: 72,
            onChanged: (v) => setState(() => _k!.boyut = v),
          ),
        ),
        const Text('A', style: TextStyle(color: Colors.white, fontSize: 26)),
      ],
    ),
  );

  Widget _renkPaleti() => SizedBox(
    height: 54,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final h in storyRenkleri)
          GestureDetector(
            onTap: () => setState(() => _k!.renk = h),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              decoration: BoxDecoration(
                color: storyRenk(h),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _k!.renk == h ? Colors.white : Colors.white24,
                  width: _k!.renk == h ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _fontSecici() => SizedBox(
    height: 54,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final e in storyFontlari.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: OutlinedButton(
              onPressed: () => setState(() => _k!.font = e.key),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: _k!.font == e.key ? Colors.white : Colors.white24,
                  width: _k!.font == e.key ? 2 : 1,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              // ⚠️ Dugmenin KENDISI o yazi tipiyle yazilir — kullanici secmeden
              //    once nasil gorunecegini GORUR.
              child: Text(
                e.value,
                style: storyMetinStili(
                  StoryKatman(metin: '', font: e.key, boyut: 15),
                  1,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _zeminSecici() => SizedBox(
    height: 54,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final e in storyArkaPlanlari.entries)
          GestureDetector(
            onTap: () => setState(() => _arkaPlan = e.key),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: e.value,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _arkaPlan == e.key ? Colors.white : Colors.white24,
                  width: _arkaPlan == e.key ? 3 : 1,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Editorun donus degeri.
class StoryCikti {
  StoryCikti({required this.katmanlar, required this.arkaPlan});
  final List<StoryKatman> katmanlar;
  final String arkaPlan;
}
