import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import '../../core/tercihler.dart';
import '../../core/theme.dart';
import '../../router.dart' show rootMessengerKey;
import '../isletme/kategori_kabuk.dart' show YemekHeader;
import 'chats_provider.dart';
import 'moderasyon_sheet.dart';

/// ⚠️⚠️⚠️ TURU 180ab — **SOHBET AYARLARI ALT EKRANLARI** (kullanici dort
/// ekran goruntusu gonderdi: Instagram sohbet ayarlari · Sureli mesajlar ·
/// Secenekler popup · Gizlilik ve emniyet).
///
/// ═══════════ SUNUCU OLCUMU (9 Eyl, backend grep) ═══════════
///
/// Bu turda cizilen ayarlarin **HICBIRININ** sunucuda karsiligi YOK:
///   `nickname` 0 · `theme` 0 · `ephemeral` 0 · `read_receipt` 0 ·
///   `restrict` 0 eslesme.
/// VAR olanlar: `muted`/`archived` (PATCH /chats/{id}) · engelle
/// (`/users/{id}/block`) · sikayet (`/reports`) · sohbeti temizle
/// (`DELETE /chats/{id}`).
///
/// ⚠️⚠️ **KARAR (CLAUDE.md kural 9):** bu bir ARAYUZ TURU — arayuz YAPILIR,
///	deger CIHAZDA tutulur, sunucuya GONDERILMEZ, bekleyen is LISTEYE
///	yazilir. Her ekran **DURUST SINIRINI KENDI USTUNDE** soyler; sessizce
///	yerelde tutup "ayarlandi" demek turu 135'te (uydurma kur seridi)
///	reddedilen sinifin ta kendisi olurdu.
///
/// ⏳ **BEKLEYEN (BACKEND TURU):**
///	· `chat_members.tema` · `chat_members.takma_ad` (ya da ayri tablo)
///	· `chat_members.sureli_sn` + mesaj sup>urgesi (karsi tarafta da silinmeli)
///	· `users.okundu_kapali` · `users.yazma_kapali`
///	· "Kisitla" (engellemenin yumusak hali: mesaj isteklere duser)

// ══════════════════════════ SURELI MESAJLAR ══════════════════════════

/// Instagram "Süreli mesajlar" ekrani: Kapalı · Görüldükten sonra · 24 saat
/// · 7 gün.
///
/// ⚠️⚠️ **YALNIZ EKRANDA**: mesajin KARSI TARAFTA da kaybolmasi sunucu
///	isidir (`messages`ta sure sutunu YOK). Ekran bunu ACIKCA yaziyor —
///	yoksa kullanici mesajlarinin silindigini SANIR ve bu, gizlilik
///	beklentisi yaratan bir YALAN olurdu.
class SureliMesajlarEkrani extends StatefulWidget {
  const SureliMesajlarEkrani({super.key, required this.chatId});
  final String chatId;

  @override
  State<SureliMesajlarEkrani> createState() => _SureliMesajlarEkraniState();
}

class _SureliMesajlarEkraniState extends State<SureliMesajlarEkrani> {
  late String _secili = tercihler.sureliMesaj(widget.chatId);

  static const _secenekler = [
    (anahtar: 'kapali', ad: 'Kapalı'),
    (anahtar: 'goruldukten', ad: 'Görüldükten sonra'),
    (anahtar: '24saat', ad: '24 saat'),
    (anahtar: '7gun', ad: '7 gün'),
  ];

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Süreli mesajlar',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: ListView(
        children: [
          for (final s in _secenekler)
            // ⚠️ `RadioListTile` KULLANILMADI: Flutter'in yeni surumlerinde
            //	`groupValue`/`onChanged` kullanimdan kaldirildi ve
            //	`RadioGroup` sarmali istiyor. Elle cizilen daire hem
            //	ekran goruntusuyle birebir hem de bu gecise BAGIMSIZ.
            ListTile(
              title: Text(s.ad, style: const TextStyle(fontSize: 16)),
              trailing: _daire(c, _secili == s.anahtar),
              onTap: () async {
                setState(() => _secili = s.anahtar);
                await tercihler.sureliMesajYaz(widget.chatId, s.anahtar);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Text(
              'Mesajları ve ifadeleri, görüp sohbeti kapattığında kaybolacak '
              'şekilde ayarla veya biraz daha tut. Mesajlar ve ifadeler, '
              'gönderildikten sonra 7 güne kadar sohbette tutulabilir.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: ks.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          // ⚠️⚠️ DURUST SINIR — EKRANDA, serhte DEGIL. Kullanici bu ayarin
          //	karsi tarafta ne yaptigini bilmek ZORUNDA.
          _durustSinir(
            c,
            'Bu ayar şu an yalnızca bu cihazda saklanıyor; mesajlar karşı '
            'tarafta kaybolmaz. Sunucu tarafı hazırlanıyor.',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════ SOHBET TEMASI ══════════════════════════

/// Instagram "Tema" ekrani — sohbet balonunun rengi.
///
/// ⚠️ Bu ayar **GERCEKTEN CALISIR**: secim `ChatColors.bubbleMineTema` ile
///	balona uygulanir. Yerel olmasi onu YALAN yapmaz; karsi tarafta
///	gorunmedigi ekranda YAZILI.
class SohbetTemaEkrani extends StatefulWidget {
  const SohbetTemaEkrani({super.key, required this.chatId});
  final String chatId;

  @override
  State<SohbetTemaEkrani> createState() => _SohbetTemaEkraniState();
}

class _SohbetTemaEkraniState extends State<SohbetTemaEkrani> {
  late String _secili = tercihler.sohbetTemasi(widget.chatId);

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Tema',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: ListView(
        children: [
          // ⚠️ ONIZLEME: renk adi TEK BASINA yetmez — kullanici "Turuncu"nun
          //	bu ekranda hangi tonda cizildigini GORMEDEN secemez.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ks.bubbleMineTema(_secili),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('Örnek mesaj', style: TextStyle(fontSize: 15)),
              ),
            ),
          ),
          for (final t in kSohbetTemalari)
            ListTile(
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ks.bubbleMineTema(t.anahtar),
                  border: Border.all(
                    color: ks.onSurface.withValues(alpha: 0.18),
                  ),
                ),
              ),
              title: Text(t.ad, style: const TextStyle(fontSize: 16)),
              trailing: _daire(c, _secili == t.anahtar),
              onTap: () async {
                setState(() => _secili = t.anahtar);
                await tercihler.sohbetTemasiYaz(widget.chatId, t.anahtar);
              },
            ),
          _durustSinir(
            c,
            'Tema bu cihazda saklanır; karşı taraf sohbeti kendi seçtiği '
            'renkte görür.',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════ TAKMA ADLAR ══════════════════════════

/// Instagram "Takma adlar" ekrani.
///
/// ⚠️ Takma ad **GERCEKTEN** sohbet basliginda ve listede kullanilir
///	(cihazda). Sunucuya gitmez — karsi taraf HABERDAR OLMAZ, ki bu
///	Instagram'da da boyle DEGIL (orada iki taraf da gorur). Fark ekranda
///	ACIKCA yaziyor.
class TakmaAdEkrani extends StatefulWidget {
  const TakmaAdEkrani({
    super.key,
    required this.peerId,
    required this.gercekAd,
  });
  final String peerId;
  final String gercekAd;

  @override
  State<TakmaAdEkrani> createState() => _TakmaAdEkraniState();
}

class _TakmaAdEkraniState extends State<TakmaAdEkrani> {
  late final _ctrl = TextEditingController(
    text: tercihler.takmaAd(widget.peerId),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Takma adlar',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            widget.gercekAd,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            maxLength: 40,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Takma ad ekle',
              filled: true,
              // ⚠️ Dolgu ZORUNLU: siyah zeminde kenarliksiz ve dolgusuz bir
              //	`TextField` GORUNMEZ olur (turu 174 dersi).
              fillColor: ks.onSurface.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    _ctrl.clear();
                    await tercihler.takmaAdYaz(widget.peerId, '');
                    if (c.mounted) Navigator.of(c).pop(true);
                  },
                  child: const Text('Kaldır'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await tercihler.takmaAdYaz(widget.peerId, _ctrl.text);
                    if (c.mounted) Navigator.of(c).pop(true);
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
          _durustSinir(
            c,
            'Takma ad yalnızca bu cihazda görünür; karşı taraf bilmez.',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════ SOHBET KONTROLLERI ══════════════════════════

/// Instagram "Sohbet kontrolleri" ekrani.
///
/// ⚠️ Bu ekrandaki HER SATIRIN sunucuda karsiligi VAR (arsivle/sessize al
///	`PATCH /chats/{id}`, temizle `DELETE /chats/{id}`) — uydurma satir YOK.
class SohbetKontrolleriEkrani extends ConsumerStatefulWidget {
  const SohbetKontrolleriEkrani({
    super.key,
    required this.chatId,
    required this.sessiz,
    required this.arsiv,
  });
  final String chatId;
  final bool sessiz;
  final bool arsiv;

  @override
  ConsumerState<SohbetKontrolleriEkrani> createState() =>
      _SohbetKontrolleriEkraniState();
}

class _SohbetKontrolleriEkraniState
    extends ConsumerState<SohbetKontrolleriEkrani> {
  late bool _sessiz = widget.sessiz;
  late bool _arsiv = widget.arsiv;
  bool _mesgul = false;

  Future<void> _ayar({bool? sessiz, bool? arsiv}) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    try {
      await ref
          .read(apiProvider)
          .patch(
            '/chats/${widget.chatId}',
            data: {
              if (sessiz != null) 'muted': sessiz,
              if (arsiv != null) 'archived': arsiv,
            },
          );
      await ref.read(chatsProvider.notifier).load();
      if (!mounted) return;
      setState(() {
        if (sessiz != null) _sessiz = sessiz;
        if (arsiv != null) _arsiv = arsiv;
      });
    } catch (e) {
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) => Scaffold(
    backgroundColor: kAiZemin,
    appBar: YemekHeader(
      baslik: 'Sohbet kontrolleri',
      geriBasildi: () => Navigator.of(c).maybePop(),
    ),
    body: ListView(
      children: [
        SwitchListTile(
          value: _sessiz,
          onChanged: _mesgul ? null : (v) => _ayar(sessiz: v),
          secondary: const Icon(LucideIcons.bellOff),
          title: const Text('Sessize al'),
          subtitle: const Text('Bildirim gelmez, sohbet listede kalır'),
        ),
        SwitchListTile(
          value: _arsiv,
          onChanged: _mesgul ? null : (v) => _ayar(arsiv: v),
          secondary: const Icon(LucideIcons.archive),
          title: const Text('Arşivle'),
          subtitle: const Text('"Arşivler" sekmesine taşınır'),
        ),
      ],
    ),
  );
}

// ══════════════════════════ GIZLILIK VE EMNIYET ══════════════════════════

/// Instagram "Gizlilik ve emniyet" ekrani.
///
/// ⚠️⚠️ IKI ANAHTARIN DURUMU FARKLI, EKRANDA DA OYLE YAZIYOR:
///	· **Yazma göstergesi** GERCEKTEN calisir — kapaliyken istemci WS
///	  `typing` olayini HIC gondermez, karsi taraf gostergeyi GORMEZ.
///	· **Okundu bilgisi** yalniz EKRANDA — `POST /chats/{id}/read` cagrisini
///	  kesmek KENDI okunmamis rozetimizi de bozardi (ayni uc iki isi birden
///	  yapiyor); o ayrim SUNUCU isi.
class GizlilikEmniyetEkrani extends ConsumerStatefulWidget {
  const GizlilikEmniyetEkrani({
    super.key,
    required this.peerId,
    required this.ad,
    required this.kullaniciAdi,
    required this.engelli,
  });
  final String peerId;
  final String ad;
  final String kullaniciAdi;
  final bool engelli;

  @override
  ConsumerState<GizlilikEmniyetEkrani> createState() =>
      _GizlilikEmniyetEkraniState();
}

class _GizlilikEmniyetEkraniState extends ConsumerState<GizlilikEmniyetEkrani> {
  late bool _engelli = widget.engelli;
  late bool _okundu = tercihler.okunduBilgisi;
  late bool _yazma = tercihler.yazmaGostergesi;

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Gizlilik ve emniyet',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: ListView(
        children: [
          if (widget.kullaniciAdi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text(
                '@${widget.kullaniciAdi}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          _bolum(c, 'Hareketlerini kimler görebilir?'),
          SwitchListTile(
            value: _okundu,
            onChanged: (v) async {
              setState(() => _okundu = v);
              await tercihler.okunduBilgisiYaz(v);
            },
            title: const Text('Okundu bilgisi'),
            subtitle: const Text(
              'Diğer kişiler mesajlarını okuduğunu görebilir.',
            ),
          ),
          SwitchListTile(
            value: _yazma,
            onChanged: (v) async {
              setState(() => _yazma = v);
              await tercihler.yazmaGostergesiYaz(v);
            },
            title: const Text('Yazma göstergesi'),
            subtitle: const Text(
              'Sen bir şeyler yazarken diğer kişiler bunu görebilir.',
            ),
          ),
          // ⚠️ IKI ANAHTARIN DURUMU FARKLI — kullaniciya AYRI AYRI soylenir.
          _durustSinir(
            c,
            'Yazma göstergesi kapatıldığında karşı taraf "yazıyor…" ibaresini '
            'görmez. Okundu bilgisi ise şu an yalnızca bu cihazda saklanıyor; '
            'sunucu tarafı hazırlanıyor.',
          ),
          _bolum(c, 'Sana kimler erişebilir?'),
          ListTile(
            leading: Icon(
              _engelli ? LucideIcons.userCheck : LucideIcons.ban,
              color: _engelli ? null : const Color(0xFFE0523F),
            ),
            title: Text(
              _engelli ? 'Engeli kaldır' : 'Engelle',
              style: _engelli
                  ? null
                  : const TextStyle(color: Color(0xFFE0523F)),
            ),
            onTap: () async {
              final degisti = await engelleOnayiAc(
                c,
                ref,
                kullaniciId: widget.peerId,
                ad: widget.ad,
                suAnEngelli: _engelli,
              );
              if (degisti && mounted) setState(() => _engelli = !_engelli);
            },
          ),
          _bolum(c, 'Destekle'),
          ListTile(
            leading: const Icon(LucideIcons.flag, color: Color(0xFFE0523F)),
            title: const Text(
              'Şikâyet et',
              style: TextStyle(color: Color(0xFFE0523F)),
            ),
            onTap: () => sikayetSheetAc(
              c,
              ref,
              hedefTur: 'kullanici',
              hedefId: widget.peerId,
            ),
          ),
          const SizedBox(height: 20),
          // ⚠️ "Kısıtla" YAZILMADI: sunucuda karsiligi YOK (olculdu) ve
          //	engellemeden FARKLI bir sey vaat eder. Gorunen ama calismayan
          //	bir satir turu 66b dersinin tekrari olurdu.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Text(
              'Kısıtlama seçeneği henüz yok. Şimdilik engelleme ve şikâyet '
              'kullanılabilir.',
              style: TextStyle(
                fontSize: 12.5,
                color: ks.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bolum(BuildContext c, String metin) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
    child: Text(
      metin,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Theme.of(c).colorScheme.onSurface,
      ),
    ),
  );
}

// ══════════════════════════ ORTAK PARCALAR ══════════════════════════

/// Secim dairesi (radio gorunumu).
///
/// ⚠️ `Radio` widget'i KULLANILMADI: Flutter'in son surumlerinde
///	`groupValue`/`onChanged` kullanimdan kaldirildi ve `RadioGroup`
///	sarmali istiyor. Elle cizilen daire hem ekran goruntusuyle birebir hem
///	de o gecise BAGIMSIZ.
Widget _daire(BuildContext c, bool secili) {
  final ks = Theme.of(c).colorScheme;
  return Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: secili ? ks.onSurface : ks.onSurface.withValues(alpha: 0.4),
        width: secili ? 3 : 1.5,
      ),
    ),
  );
}

/// ⚠️⚠️ **DURUST SINIR SERIDI** — sunucuda karsiligi olmayan bir ayarin
///	ALTINA konur. Sessizce yerelde tutmak yerine kullaniciya NE OLDUGUNU
///	soyler (CLAUDE.md kural 9 + turu 135 "uydurma veri" dersi).
Widget _durustSinir(BuildContext c, String metin) {
  final ks = Theme.of(c).colorScheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ks.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 17,
            color: ks.onSurface.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              metin,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: ks.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════ MESAJ ARAMA ══════════════════════════

/// Instagram "Ara" (sohbet ici mesaj arama).
///
/// ⚠️⚠️ **SUNUCUDA ARAMA UCU YOK** ve GEREKMIYOR: `messagesProvider` sohbetin
///	mesajlarini ZATEN bellekte tutuyor. Suzgec ISTEMCIDE calisir, yani
///	suzulen kume kullanicinin gordugu kumenin TAMAMIDIR (turu 122/141'in
///	"istemci suzgeci ne zaman durusttur" olcutu).
/// ⚠️ DURUST SINIR: sohbet cok uzunsa `messagesProvider` yalniz YUKLENMIS
///	sayfayi tasir; ekran bunu ACIKCA soyler.
/// ⚠️⚠️ Arama Turkce'ye duyarsiz olmali ama `toLowerCase()` 'İ' harfini
///	BIRLESIK NOKTAYA cevirir ve "İSTANBUL" ile "istanbul" AYRI sayilir
///	(turu 140/175 tuzagi) -> `_sadelestir` ile elle esleme.
class MesajAramaEkrani extends ConsumerStatefulWidget {
  const MesajAramaEkrani({
    super.key,
    required this.chatId,
    required this.baslik,
  });
  final String chatId;
  final String baslik;

  @override
  ConsumerState<MesajAramaEkrani> createState() => _MesajAramaEkraniState();
}

class _MesajAramaEkraniState extends ConsumerState<MesajAramaEkrani> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// ⚠️ Turkce'ye duyarsiz sadelestirme (`toLowerCase` TEK BASINA YETMEZ).
  static String _sadelestir(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    final mesajlar = ref.watch(messagesProvider(widget.chatId));
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Ara',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              onChanged: (v) => setState(() => _q = _sadelestir(v.trim())),
              decoration: InputDecoration(
                hintText: '${widget.baslik} ile mesajlarda ara',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                // ⚠️ Dolgu ZORUNLU: siyah zeminde kenarliksiz ve dolgusuz bir
                //	`TextField` GORUNMEZ olur (turu 174 dersi).
                fillColor: ks.onSurface.withValues(alpha: 0.06),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: mesajlar.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(apiErrorMessage(e))),
              data: (liste) {
                if (_q.isEmpty) {
                  return _bos(c, 'Mesajlarda aramak için yaz.');
                }
                // ⚠️ Silinmis mesaj ve sistem kaydi ELENIR: ikisinin de
                //	`content`i kullanicinin YAZDIGI metin degil.
                final sonuc = liste
                    .where(
                      (m) =>
                          !m.deletedForAll &&
                          m.type != 'system' &&
                          _sadelestir(m.content).contains(_q),
                    )
                    .toList();
                if (sonuc.isEmpty) {
                  return _bos(c, 'Eşleşen mesaj yok.');
                }
                return ListView.separated(
                  itemCount: sonuc.length + 1,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: ks.onSurface.withValues(alpha: 0.08),
                  ),
                  itemBuilder: (bc, i) {
                    if (i == sonuc.length) {
                      // ⚠️ DURUST SINIR: yalniz YUKLENMIS mesajlar taranir.
                      return _durustSinir(
                        bc,
                        'Yalnızca bu sohbette yüklenmiş mesajlar arandı. '
                        'Daha eskisi için sohbette yukarı kaydır.',
                      );
                    }
                    final m = sonuc[i];
                    return ListTile(
                      title: Text(
                        m.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5),
                      ),
                      subtitle: Text(
                        _tarih(m.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: ks.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bos(BuildContext c, String metin) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        metin,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(c).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    ),
  );

  static String _tarih(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
