import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'isletme_kart.dart' show kYanBosluk, kYaricap, kYuzeyGri;
import 'isletme_servisi.dart' show IsletmeOzet, isletmeKategorileri;

/// ⚠️⚠️⚠️ TURU 132 — **ARAMA PANELI** (kullanici emri: *"mekan ve adres araya
///	tikladiginda popup acilacak, orada kartlar olacak"*).
///
/// ⚠️⚠️ `DraggableScrollableSheet`: sonuc listesi UZUN olabilir; sabit
///	tavanli bir panel onu KIRPARDI. Kullanici paneli yukari cekip tum
///	sonuclari gorebilir.
/// ⚠️ Ic liste `controller`i ALMAK ZORUNDA: aksi halde panel yukari
///    cekilmisken ic kaydirma paneli KAPATIR (klasik tuzak).
/// ⚠️ `viewInsets.bottom` EKLENIR: klavye acilinca son kartlar onun altinda
///    kalirdi (`useSafeArea` klavyeyi OLCMEZ).
/// ⚠️⚠️ Denetleyici PANELIN KENDISINDE: ekranla paylasilan tek bir
///	denetleyici, panel kapanirken dispose sirasi yuzunden
///	*"A TextEditingController was used after being disposed"* uretebilir
///	(turu 96i'de TAM EKRAN KIRMIZI olarak sahaya cikti).
///
/// ⚠️ AYRI DOSYA: `yakinimda_ekrani.dart` 1400+ satir ve bu panel kendi
///    basina anlamli bir parca.
class AramaPaneli extends StatefulWidget {
  const AramaPaneli({
    super.key,
    required this.baslangic,
    required this.liste,
    required this.onSec,
    required this.onDegis,
  });

  final String baslangic;
  final List<IsletmeOzet> liste;
  final void Function(IsletmeOzet) onSec;
  final void Function(String) onDegis;

  @override
  State<AramaPaneli> createState() => _AramaPaneliState();
}

class _AramaPaneliState extends State<AramaPaneli> {
  late final TextEditingController _kutu;
  final _odak = FocusNode();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _kutu = TextEditingController(text: widget.baslangic);
    _q = widget.baslangic;
    // ⚠️ Odak KARE SONRASINA ertelenir: `initState`te istemek panel acilis
    //    animasyonuyla carpisir ve klavye bir an acilip kapanir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _odak.requestFocus();
    });
  }

  @override
  void dispose() {
    _kutu.dispose();
    _odak.dispose();
    super.dispose();
  }

  /// ⚠️ Suzgec ISTEMCIDE: liste ZATEN tek istekte gelmis durumda (yakindaki
  ///    isletmeler). Sunucuya ikinci bir arama istegi atmak gereksiz.
  /// ⚠️⚠️ Hem HAM hem KUCUK HARFLI hali denenir: Dart'in `toLowerCase`i
  ///	Turkce'de "İ" icin YANLIS sonuc verir (turu 93b dersi), bu yuzden
  ///	tek basina ona guvenilmiyor.
  List<IsletmeOzet> get _sonuc {
    final q = _q.trim();
    if (q.isEmpty) return widget.liste;
    final kq = q.toLowerCase();
    return widget.liste.where((i) {
      return i.ad.contains(q) ||
          i.ad.toLowerCase().contains(kq) ||
          i.ilce.toLowerCase().contains(kq) ||
          i.adres.toLowerCase().contains(kq);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final klavye = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.4, 0.75, 0.95],
      builder: (context, kaydirma) => DecoratedBox(
        decoration: BoxDecoration(
          color: tema.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: tema.colorScheme.onSurface.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── ARAMA ALANI ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kYanBosluk),
              child: SizedBox(
                height: 48,
                child: TextField(
                  controller: _kutu,
                  focusNode: _odak,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) {
                    setState(() => _q = v);
                    widget.onDegis(v);
                  },
                  decoration: InputDecoration(
                    hintText: 'Mekân ve adres ara',
                    prefixIcon: const Icon(LucideIcons.search, size: 19),
                    // ⚠️ `suffixIcon`e KALAN GENISLIGIN TAMAMI verilir (turu
                    //    96o tuzagi): genislik acikca verilmezse X inputun
                    //    ORTASINDA cikar ve metne yer kalmaz.
                    suffixIcon: _q.isEmpty
                        ? null
                        : SizedBox(
                            width: 44,
                            child: IconButton(
                              tooltip: 'Temizle',
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _kutu.clear();
                                setState(() => _q = '');
                                widget.onDegis('');
                              },
                            ),
                          ),
                    filled: true,
                    fillColor: kYuzeyGri(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(kYaricap(48)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── SONUC KARTLARI ──
            Expanded(
              child: Builder(
                builder: (_) {
                  final s = _sonuc;
                  if (s.isEmpty) {
                    // ⚠️ Bos durum IKI DALLI: arama bosalttiysa SEBEBINI
                    //    soyler, hic kayit yoksa BASKA sey der. Tek metin
                    //    kullaniciya yanlis sebep gosterirdi.
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _q.trim().isEmpty
                              ? 'Yakında kayıtlı işletme bulunamadı.'
                              : '“${_q.trim()}” için sonuç yok.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: tema.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: kaydirma,
                    padding: EdgeInsets.fromLTRB(
                      kYanBosluk,
                      0,
                      kYanBosluk,
                      16 + klavye,
                    ),
                    itemCount: s.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _SonucKarti(
                      isletme: s[i],
                      onTap: () => widget.onSec(s[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ⚠️ Sonuc karti: ikon + ad + kategori/ilce + mesafe.
/// ⚠️ Mesafe `IsletmeOzet.mesafeMetni` ile cizilir (TEK KAYNAK); bilinmiyorsa
///    HICBIR SEY yazilmaz — "0 m" yanlis bilgi olurdu.
class _SonucKarti extends StatelessWidget {
  const _SonucKarti({required this.isletme, required this.onTap});

  final IsletmeOzet isletme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mesafe = isletme.mesafeMetni;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: kYuzeyGri(context),
          borderRadius: BorderRadius.circular(kYaricap(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tema.colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.mapPin,
                size: 17,
                color: tema.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            // ⚠️ `Expanded` ZORUNLU: uzun bir isletme adi mesafeyi ekran
            //    disina iterdi.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isletme.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      isletmeKategorileri[isletme.kategori] ?? 'Diğer',
                      if (isletme.ilce.isNotEmpty) isletme.ilce,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: tema.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (mesafe.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                mesafe,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: tema.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
