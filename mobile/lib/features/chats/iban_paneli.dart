import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// ⚠️⚠️⚠️ TURU 81 — IBAN PAYLASMA (kullanici emri: *"sohbette IBAN paylasma
/// olsun"*).
///
/// ═══════════ NEDEN DOGRULAMA VAR ═══════════
///
/// Yanlis IBAN'a yapilan havale **GERI DONMEZ**. Bicimsel dogrulama tum
/// hatalari yakalamaz (dogru bicimli ama BASKASINA ait bir IBAN'i ayirt
/// edemez) ama en sik hatayi — tek karakter dusmesi, eklenmesi ya da yer
/// degistirmesi — **mod-97 saglamasiyla** yakalar. Bu, IBAN standardinin
/// (ISO 13616) tam olarak bu is icin tasarladigi kontroldur.
/// ⚠️ YAPMA: dogrulamayi kaldirip "kullanici dikkat etsin" deme.
class IbanSonuc {
  const IbanSonuc(this.iban, this.ad);

  /// Bosluksuz, buyuk harf (or. "TR330006100519786457841326").
  final String iban;

  /// Hesap sahibinin adi (opsiyonel — bos olabilir).
  final String ad;
}

Future<IbanSonuc?> ibanPaneliAc(BuildContext context) =>
    showModalBottomSheet<IbanSonuc>(
      context: context,
      isScrollControlled: true, // klavye acilinca panel yukari kayar
      showDragHandle: true,
      builder: (_) => const _IbanPanel(),
    );

class _IbanPanel extends StatefulWidget {
  const _IbanPanel();

  @override
  State<_IbanPanel> createState() => _IbanPanelState();
}

class _IbanPanelState extends State<_IbanPanel> {
  final _iban = TextEditingController();
  final _ad = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _iban.dispose();
    _ad.dispose();
    super.dispose();
  }

  void _gonder() {
    final ham = ibanSadelestir(_iban.text);
    final h = ibanHatasi(ham);
    if (h != null) {
      setState(() => _hata = h);
      return;
    }
    Navigator.of(context).pop(IbanSonuc(ham, _ad.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // ⚠️ Klavye yuksekligi kadar bosluk: alanlar klavyenin ALTINDA kalmasin.
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.creditCard, size: 20),
              const SizedBox(width: 8),
              Text(
                'IBAN paylaş',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _iban,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            // ⚠️ Klavye HARF+RAKAM olmali: IBAN "TR" ile basliyor.
            keyboardType: TextInputType.text,
            inputFormatters: [
              // ⚠️ Bosluk ve tire KABUL EDILIR (kullanicilar IBAN'i gruplu
              //    yapistiriyor) — `ibanSadelestir` temizler.
              LengthLimitingTextInputFormatter(40),
            ],
            decoration: InputDecoration(
              labelText: 'IBAN',
              hintText: 'TR00 0000 0000 0000 0000 0000 00',
              errorText: _hata,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_hata != null) setState(() => _hata = null);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ad,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Hesap sahibi (isteğe bağlı)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _gonder,
              child: const Text('Gönder'),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'IBAN mesaj olarak gönderilir; karşı taraf tek dokunuşla kopyalayabilir.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Bosluk/tire temizler, buyuk harfe cevirir.
String ibanSadelestir(String s) =>
    s.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

/// IBAN gecerli mi? Gecerliyse `null`, degilse KULLANICIYA GOSTERILECEK hata.
///
/// ⚠️ TURKIYE'YE SABITLENDI (TR + 26 karakter): urun Turkiye pazari icin ve
///    yalniz TR kabul etmek, yanlis ulke kodu yazan kullaniciyi ERKEN uyarir.
///    Yurt disi IBAN gerekirse burasi genisletilir (uzunluk ulkeye gore degisir).
/// ⚠️ MOD-97 (ISO 13616): ilk 4 karakter sona tasinir, harfler sayiya cevrilir
///    (A=10..Z=35) ve kalan 1 olmalidir. Buyuk sayi oldugu icin PARCA PARCA
///    mod alinir — `int` tasmasi olmaz.
String? ibanHatasi(String iban) {
  if (iban.isEmpty) return 'IBAN girin';
  if (!iban.startsWith('TR')) return 'IBAN "TR" ile başlamalı';
  if (iban.length != 26) return 'TR IBAN 26 karakter olmalı (şu an ${iban.length})';
  if (!RegExp(r'^TR\d{24}$').hasMatch(iban)) {
    return 'IBAN yalnızca rakam içermeli (TR hariç)';
  }
  final tasinmis = iban.substring(4) + iban.substring(0, 4);
  final sb = StringBuffer();
  for (final c in tasinmis.codeUnits) {
    if (c >= 65 && c <= 90) {
      sb.write(c - 55); // A=10 ... Z=35
    } else {
      sb.writeCharCode(c);
    }
  }
  var kalan = 0;
  for (final ch in sb.toString().codeUnits) {
    kalan = (kalan * 10 + (ch - 48)) % 97;
  }
  if (kalan != 1) return 'IBAN geçersiz — kontrol edin';
  return null;
}
