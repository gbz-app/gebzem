/// ⚠️⚠️⚠️ TURU 90b — IS ILANI BASVURUSU (ISTEMCI TARAFI).
///
/// ═══════════ NEDEN AYRI BIR TURDA YAZILDI ═══════════
///
/// Turu 90 sunucu tarafini eksiksiz yazdi: `ilan_basvurular` tablosu, BES
/// uc, yetki kapilari, bildirim. Ama ISTEMCIDE **TEK SATIR YOKTU** —
/// `grep -rn "basvur" mobile/lib/` SIFIR donuyordu. Yayin oncesi denetimde
/// UC BAGIMSIZ AJAN ayni sonuca vardi: kullanicinin bu turdaki acik emri
/// (*"herkes is ilani verebilmeli, NORMAL KULLANICILAR BASVURU
/// YAPABILMELI"*) sahada **%100 OLU DOGACAKTI**.
///
/// ⚠️ DERS (bu projede DOKUZUNCU tekrar): bir uc/sutun/servis ekledigin AN
///    onu KULLANAN yolu da yaz. "Sunucu hazir" YARIM istir ve kullanici
///    icin SIFIR degerdir.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import 'ilan_servisi.dart';

/// Kullanicinin yazdigi tutari KURUSA cevirir.
///
/// ⚠⚠ TEK KAYNAK ve TOLERANSLI: "1.500,50" · "1500" · "1500,5"
///    hepsi kabul edilir. Ciplak `int.parse` YASAK — turu 78b'de AI
///    menusu tam bu yuzden **"0 URUN EKLENDI"** diyordu: model `"1250"`
///    (METIN) donduruyor, ciplak cast `null` veriyor ve `catch(_){}`
///    yutuyordu.
/// ⚠️ Bozuk girdide **0** doner; cagiran taraf 0'i HATA sayar ve
///    kullaniciya soyler (sessizce 0 TL teklif GONDERILMEZ).
/// Kurusu okunur TL metnine cevirir (binlik ayiricili).
///
/// ⚠️ `intl` KULLANILMAZ: `NumberFormat` yerel ayar yuklemesi ister ve
///    uygulama acilisina yuk bindirir (`ilan_servisi.fiyatMetni` ile AYNI
///    gerekce).
String _tl(int kurus) {
  final tam = (kurus ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < tam.length; i++) {
    if (i > 0 && (tam.length - i) % 3 == 0) buf.write('.');
    buf.write(tam[i]);
  }
  return '${buf.toString()} ₺';
}

int _kurusOku(String s) {
  var t = s.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (t.isEmpty) return 0;
  // Binlik ayirici olarak nokta kullanilmis olabilir: "1.500,50".
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  final v = double.tryParse(t);
  if (v == null || v <= 0) return 0;
  return (v * 100).round();
}

/// Basvuru durumunun rengi — UC EKRANDA da ayni.
Color basvuruRengi(String durum) => switch (durum) {
  'olumlu' => const Color(0xFF2ECC71),
  'olumsuz' => const Color(0xFFE74C3C),
  'goruldu' => const Color(0xFF3AA9FF),
  'geri_cekildi' => Colors.grey,
  // ⚠️ TURU 91 — TEKLIF kararlari.
  'secildi' => const Color(0xFF2ECC71),
  'elendi' => const Color(0xFFE74C3C),
  _ => const Color(0xFFF39C12),
};

Widget _rozet(String durum, String etiket) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: basvuruRengi(durum).withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(etiket,
      style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: basvuruRengi(durum))),
);

// ═══════════════════════ 1) BASVUR (alttan sheet) ═══════════════════════

/// Basvuru sheet'ini acar; basvuru GONDERILDIYSE `true` doner.
///
/// ⚠️ `isScrollControlled` + `viewInsets` ZORUNLU: icinde `TextField` var ve
///    klavye acilinca sheet'in altini yerdi.
Future<bool> basvurSheet(BuildContext context, WidgetRef ref, String ilanID,
    String baslik, {bool teklifModu = false}) async {
  final not = TextEditingController();
  // ⚠️ TURU 91 — TEKLIF TUTARI (yalniz talep ilanlarinda). Sunucu
  //    fiyatsiz teklifi 400 ile REDDEDER: liste fiyata gore siralaniyor.
  final fiyat = TextEditingController();
  var gonderiliyor = false;
  // ⚠️ TURU 90c — KENDI ROUTE'UM. `Navigator.pop()` EN USTTEKI route'u
  //    kapatir, "beni" DEGIL: istek ucustayken kullanici baska bir sey
  //    acarsa (or. klavye ustu bir menu) `pop(true)` YANLIS ROUTE'U
  //    kapatirdi. Turu 59b'de aynen yasandi ve oradaki cozum route'u
  //    ADRESLEMEKTI.
  ModalRoute<Object?>? rota;
  // ⚠️ SONUC POP DEGERINDEN DEGIL, BURADAN okunur: route'u `removeRoute` ile
  //    kaldirmak zorunda kalirsak pop degeri `null` doner ve cagiran taraf
  //    basariyi KACIRIRDI ("Başvurun gönderildi" bildirimi cikmaz, dugme
  //    guncellenmezdi).
  var basarili = false;

  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, yenile) {
        rota ??= ModalRoute.of(c);
        return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        // ⚠️ TURU 90c — KAYDIRMA SARMALI: buyuk yazi olceginde klavye
        //    acikken `Column` (baslik + aciklama + 4 satirlik TextField +
        //    sayac + dugme) kalan yeri asiyordu -> RenderFlex tasmasi.
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(baslik,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('İlan sahibi adını, kullanıcı adını ve notunu görür.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),
            if (teklifModu) ...[
              TextField(
                controller: fiyat,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Teklif tutarı (₺) *',
                  helperText: 'Müşteri teklifleri fiyata göre sıralı görür',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: not,
              maxLines: 4,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kısa not (isteğe bağlı)',
                hintText: 'Deneyimin, ne zaman başlayabileceğin...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: gonderiliyor
                  ? null
                  : () async {
                      // ⚠️ CIFT DOKUNMA KAPISI: sunucu idempotent olsa da
                      //    iki istek iki bildirim dogurabilir.
                      yenile(() => gonderiliyor = true);
                      final nav = Navigator.of(c);
                      final mesajci = ScaffoldMessenger.of(c);
                      try {
                        // ⚠️ KURUSA CEVIRME **TEK KAYNAK**: virgul de kabul
                        //    edilir (kullanici "1.500,50" yazabilir).
                        //    Ciplak `int.parse` YASAK — turu 78b'de "0 URUN
                        //    EKLENDI" hatasi tam bu yuzden olusmustu.
                        final k = teklifModu ? _kurusOku(fiyat.text) : 0;
                        if (teklifModu && k <= 0) {
                          yenile(() => gonderiliyor = false);
                          mesajci.showSnackBar(const SnackBar(
                              content: Text('Teklif tutarı gerekli')));
                          return;
                        }
                        await ref
                            .read(ilanServisiProvider)
                            .basvur(ilanID, not.text.trim(), fiyatKurus: k);
                        basarili = true;
                        // ⚠️ KENDI route'umu ADRESLE (bkz. `rota` serhi).
                        //    En ustteysem normal pop; degilsem (istek
                        //    ucustayken uste bir sey acilmis) KENDI route'umu
                        //    kaldiririm — BASKASINI kapatmam.
                        final r = rota;
                        if (r == null || r.isCurrent) {
                          nav.pop(true);
                        } else if (r.isActive) {
                          nav.removeRoute(r);
                        }
                      } catch (e) {
                        yenile(() => gonderiliyor = false);
                        mesajci.showSnackBar(
                            const SnackBar(content: Text('Başvuru gönderilemedi')));
                      }
                    },
              child: gonderiliyor
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(teklifModu ? 'Teklifi gönder' : 'Başvuruyu gönder'),
            ),
          ],
        ),
        ),
        );
      },
    ),
  );
  not.dispose();
  fiyat.dispose();
  return basarili;
}

// ═══════════════════ 2) BASVURANLAR (ilan sahibi) ═══════════════════

class BasvuranlarEkrani extends ConsumerStatefulWidget {
  const BasvuranlarEkrani({
    super.key,
    required this.ilanID,
    this.baslik = '',
    this.teklifModu = false,
  });
  final String ilanID;
  final String baslik;

  /// ⚠⚠ TURU 91 — TEKLIF MODU: fiyat büyük puntoyla çizilir ve
  ///    "Teklifi seç" düğmesi çıkar. Ayrı bir ekran YAZILMADI: liste,
  ///    yetki kapısı ve yenileme mantığı BİREBİR AYNI; ikinci kopya
  ///    kaçınılmaz olarak drift ederdi.
  final bool teklifModu;

  @override
  ConsumerState<BasvuranlarEkrani> createState() => _BasvuranlarState();
}

class _BasvuranlarState extends ConsumerState<BasvuranlarEkrani> {
  List<Basvuru>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(ilanServisiProvider).basvurular(widget.ilanID);
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Başvurular alınamadı');
    }
  }

  /// ⚠⚠ TURU 91 — TEKLIF SECIMI GERI ALINAMAZ.
  ///    Sunucu TEK ISLEMDE: kazanani `secildi` yapar · DIGER tum teklifleri
  ///    `elendi` yapar · talebi `satildi`ya kapatir. Onay diyalogu olmadan
  ///    tek dokunusla bu karar verilemez.
  Future<void> _teklifSec(Basvuru b) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Teklifi seç'),
        content: Text(
          '${b.ad.isEmpty ? "Bu işletme" : b.ad} seçilecek.\n\n'
          'Diğer teklifler kapanacak ve talebin sonlanacak. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Seç')),
        ],
      ),
    );
    if (onay == true) await _durum(b, 'secildi');
  }

  Future<void> _durum(Basvuru b, String yeni) async {
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(ilanServisiProvider)
          .basvuruDurum(widget.ilanID, b.id, yeni);
      await _yukle();
    } catch (e) {
      mesajci.showSnackBar(
          const SnackBar(content: Text('Güncellenemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Başvuranlar'),
        bottom: widget.baslik.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 16, right: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(widget.baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _hata != null
            ? _bosDurum(LucideIcons.circleAlert, _hata!, 'Tekrar dene', _yukle)
            : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? _bosDurum(LucideIcons.inbox, 'Henüz başvuru yok',
                        'Yenile', _yukle)
                    : ListView.separated(
                        // ⚠️ Bos/hata dallarinda da kaydirma SART, yoksa
                        //    asagi-cek-yenile CALISMAZ (turu 83b dersi).
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: l.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) => _satir(l[i]),
                      ),
      ),
    );
  }

  Widget _satir(Basvuru b) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ProfilSayfasi(userId: b.userID))),
                  child: Avatar(ad: b.ad, mediaId: b.avatarID, cap: 42),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.ad.isEmpty ? '@${b.kullaniciAdi}' : b.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (b.kullaniciAdi.isNotEmpty)
                        Text('@${b.kullaniciAdi}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (widget.teklifModu && b.fiyatKurus > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _tl(b.fiyatKurus),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                _rozet(b.durum, b.durumEtiketi),
              ],
            ),
            // ⚠️ TURU 91 — "revize edildi" ETIKETI. `guncellendi_at`
            //    sutunu bunun icin eklendi; cizilmezse projenin SEKIZ kez
            //    yasadigi "sutun var, okuyan yol yok" sinifina yeni ornek
            //    olurdu.
            if (widget.teklifModu && b.guncellendiAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('revize edildi',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ),
            if (b.not.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(b.not, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 6),
            // ⚠⚠ TEKLIF MODU: "Seç" GERI ALINAMAZ bir karardir (sunucu
            //    tek islemde kazanani isaretler, digerlerini eler ve talebi
            //    kapatir) — bu yuzden ONAY DIYALOGU zorunlu.
            if (widget.teklifModu)
              Row(
                children: [
                  if (b.durum != 'secildi' && b.durum != 'elendi')
                    FilledButton.icon(
                      onPressed: () => _teklifSec(b),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('Teklifi seç'),
                    ),
                  TextButton.icon(
                    onPressed: () => _durum(b, 'goruldu'),
                    icon: const Icon(LucideIcons.eye, size: 16),
                    label: const Text('Görüldü'),
                  ),
                ],
              )
            else
              Row(
              children: [
                TextButton.icon(
                  onPressed: () => _durum(b, 'olumlu'),
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Olumlu'),
                ),
                TextButton.icon(
                  onPressed: () => _durum(b, 'olumsuz'),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('Olumsuz'),
                ),
              ],
            ),
          ],
        ),
      );
}

// ═══════════════════ 3) BASVURULARIM (kullanici) ═══════════════════

class BasvurularimEkrani extends ConsumerStatefulWidget {
  const BasvurularimEkrani({super.key, this.tur = ''});

  /// `'talep'` -> "Tekliflerim", `'is'` -> "Başvurularım", boş -> hepsi.
  final String tur;

  @override
  ConsumerState<BasvurularimEkrani> createState() => _BasvurularimState();
}

class _BasvurularimState extends ConsumerState<BasvurularimEkrani> {
  List<Basvuru>? _liste;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final l = await ref.read(ilanServisiProvider)
          .basvurularim(tur: widget.tur);
      if (!mounted) return;
      setState(() {
        _liste = l;
        _hata = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _hata = 'Başvurular alınamadı');
    }
  }

  Future<void> _geriCek(Basvuru b) async {
    final mesajci = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Başvuruyu geri çek'),
        content: Text('"${b.baslik}" ilanına yaptığın başvuru geri çekilecek. '
            'İstersen daha sonra yeniden başvurabilirsin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Geri çek')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(ilanServisiProvider).basvuruGeriCek(b.ilanID);
      await _yukle();
    } catch (e) {
      mesajci.showSnackBar(const SnackBar(content: Text('Geri çekilemedi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: Text(
          widget.tur == 'talep' ? 'Tekliflerim' : 'Başvurularım')),
      body: RefreshIndicator(
        onRefresh: _yukle,
        child: _hata != null
            ? _bosDurum(LucideIcons.circleAlert, _hata!, 'Tekrar dene', _yukle)
            : l == null
                ? const Center(child: CircularProgressIndicator())
                : l.isEmpty
                    ? _bosDurum(LucideIcons.briefcase,
                        'Henüz bir işe başvurmadın', 'Yenile', _yukle)
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: l.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final b = l[i];
                          return ListTile(
                            title: Text(
                                b.baslik.isEmpty ? 'İlan' : b.baslik,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _rozet(b.durum, b.durumEtiketi),
                              ),
                            ),
                            // ⚠️ GERI CEKME YOLU ZORUNLU: sunucuda uc VAR ve
                            //    onu cagiran ekran olmasaydi bu, kapatmaya
                            //    calistigimiz "olu ozellik" sinifinin
                            //    KENDI ICINDE tekrari olurdu.
                            // ⚠️ Teklifse TUTARI da goster.
                            leading: b.fiyatKurus > 0
                                ? Text(_tl(b.fiyatKurus),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))
                                : null,
                            trailing: b.durum == 'geri_cekildi'
                                ? null
                                : IconButton(
                                    tooltip: 'Geri çek',
                                    icon: const Icon(LucideIcons.trash2,
                                        size: 18),
                                    onPressed: () => _geriCek(b),
                                  ),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Bos/hata durumu — UC EKRANDA ortak.
///
/// ⚠️ `AlwaysScrollableScrollPhysics` + `ListView`: bos ekranda da
///    asagi-cek-yenile calissin (turu 83b'de BES ekranda atlanmisti).
Widget _bosDurum(
        IconData ikon, String metin, String dugme, VoidCallback basinca) =>
    ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(ikon, size: 44, color: Colors.grey),
        const SizedBox(height: 12),
        Center(child: Text(metin, style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: basinca, child: Text(dugme))),
      ],
    );
