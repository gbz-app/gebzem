import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import "../../core/yenile.dart";

import '../../core/api.dart';
import '../auth/auth_provider.dart';
import '../medya/medya_gorsel.dart';
import 'arama_kaydi.dart';
import '../../router.dart' show rootMessengerKey;
import 'chats_provider.dart';
import '../calls/calls_tab.dart' show CallsTab;
import '../kanal/kanal_ekrani.dart' show KanalEkrani;
import '../kanal/kanal_olustur.dart' show KanalOlustur;
import '../kanal/kanal_servisi.dart' show Kanal, kanalServisiProvider;
import '../kanal/kanallar_sekmesi.dart' show KanallarSayfasi;
import 'grup_olustur.dart';
import '../sosyal/demo_veri.dart' show kDemoAkis;
import 'models.dart';

/// WhatsApp tarzi sohbet listesi. "Gebzem" basliginin altinda ARAMA INPUT'u (yerel filtre);
/// FAB = mor-gradient + (yeni sohbet).
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

/// Sohbet listesi filtresi.
/// ⚠️ Arsiv AYRI bir gorunumdur: digerlerinde arsivlenmisler GIZLIDIR.
///
/// ⚠️⚠️ TURU 180x — KULLANICI EMRI: *"burada Tümü Grup Arşiv Aramalar olsun,
///	butonlara gerek yok"*. Iki degisiklik birden:
///	  · **`okunmamis` CIKTI** — kullanicinin saydigi dort ogede yok.
///	    Bilgi KAYBOLMADI: okunmamis rozeti her satirda ZATEN ciziliyor.
///	  · **`aramalar` GIRDI** — eskiden `_MesajSekmesi` basliginda AYRI bir
///	    "Sohbet | Aramalar" metin secicisi vardi; kullanici onu ("butonlar")
///	    kaldirmamizi istedi. Secim artik AYNI serit uzerinde.
/// ⚠️ `aramalar` bir SOHBET SUZGECI DEGIL, GOVDE DEGISTIRIR (`CallsTab`).
///	Bu yuzden asagidaki `switch`lerde ayri ele alinir; sohbet listesinde
///	"arama" diye bir kayit YOKTUR.
enum _Filtre { tumu, gruplar, arsiv, aramalar }

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _aramaCtrl = TextEditingController();
  String _arama = '';
  _Filtre _filtre = _Filtre.tumu;

  /// Abone olunan topluluklar (turu 180x — sohbet listesine karisir).
  List<Kanal> _kanallar = const [];

  @override
  void initState() {
    super.initState();
    // ⚠️ `addPostFrameCallback` DEGIL: `ref.read` `initState` govdesinde
    //    guvenli (Riverpod'un yasakladigi sey `ref.watch`); istek zaten
    //    asenkron ve sonucu `setState` ile yaziyoruz.
    _topluluklariYukle();
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  /// Cip etiketi. Arsiv icin SAYI da gosterilir — kullanici filtreye
  /// dokunmadan kac tane oldugunu gorsun.
  String _filtreAdi(_Filtre f, List<Chat>? liste) {
    final l = liste ?? const <Chat>[];
    switch (f) {
      case _Filtre.tumu:
        return 'Tümü';
      case _Filtre.gruplar:
        return 'Grup';
      case _Filtre.arsiv:
        final n = l.where((c) => c.archived).length;
        return n > 0 ? 'Arşiv ($n)' : 'Arşiv';
      case _Filtre.aramalar:
        return 'Aramalar';
    }
  }

  /// ⚠️⚠️ TURU 180x — TOPLULUKLAR SOHBET LISTESINDE (kullanici emri:
  ///	*"bu sohbetlerde topluluklarda olsun"*).
  ///
  /// ⚠️⚠️ **YENI UC YOK, BACKEND DEGISMEDI.** Topluluk = `channels` tablosu
  ///	ve `GET /chats` onlari **YAPISAL OLARAK** dondurmez (`ListChats`
  ///	yalniz `chats`ten okur — CLAUDE.md turu 75). Bu yuzden abone olunan
  ///	topluluklar AYRI ucla (`/channels`) cekilip listeye ISTEMCIDE
  ///	karistiriliyor.
  /// ⚠️ Hata YUTULUR ve liste BOS doner: topluluk istegi patlarsa sohbet
  ///	listesi CIZILMEYE DEVAM ETMELI (turu 78b dersi: tek ag hatasi tum
  ///	ekrani goturmesin).
  Future<void> _topluluklariYukle() async {
    try {
      final l = await ref.read(kanalServisiProvider).listem();
      if (mounted) setState(() => _kanallar = l);
    } catch (_) {
      // sessiz: sohbet listesi cizilmeye DEVAM etmeli
    }
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);

    // ⚠️⚠️ TURU 180t — `removeTop` ZORUNLU. Ekran artik `Scaffold` DEGIL
    //	(FAB kalkinca govde duz `Column` oldu) ve `ListView` dolgusu YOKKEN
    //	`MediaQuery.padding.top`u KENDI ust dolgusu yapiyor -> listenin
    //	basinda durum cubugu kadar BOS ALAN kaliyordu (emulatorde olculdu).
    //	Ust bosluk zaten `_MesajSekmesi` header'indaki `SafeArea`da.
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(
        children: [
          // ARAMA INPUT'u (Gebzem altinda — kullanici istegi): sohbet basligina gore filtreler
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: TextField(
              controller: _aramaCtrl,
              onChanged: (v) => setState(() => _arama = v.trim().toLowerCase()),
              decoration: InputDecoration(
                isDense: true,
                // ⚠️ Ipucu SECILI CIPE gore: "Aramalar" acikken "Sohbet ara"
                //    yazmak, kutunun o listeyi suzmedigi izlenimi verirdi.
                hintText: _filtre == _Filtre.aramalar
                    ? 'Arama geçmişinde ara'
                    : 'Sohbet ara',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _arama.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _aramaCtrl.clear();
                          setState(() => _arama = '');
                        },
                      ),
                filled: true,
                // ⚠️⚠️ TURU 115b — SABIT `0xFF232326` KALDIRILDI (emulatorde
                //	GORULDU): koyu tema icin yazilmis bu renk, turu 81'de acik
                //	tema eklendikten sonra da duruyordu. Sonuc: acik temada
                //	**SIMSIYAH bir arama kutusu** ve neredeyse okunmayan
                //	yer tutucu yazi. Ekranin en ustundeki bilesendi, yani
                //	uygulama acildigi anda goze carpiyordu.
                // ⚠️ Bu, tema iskeletinin serhinde yazan "~500 sabit renk
                //    noktasi" borcunun EN GORUNUR ornegiydi.
                fillColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // FILTRE CIPLERI — arama kutusunun ALTINDA (WhatsApp deseni).
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final f in _Filtre.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_filtreAdi(f, chats.valueOrNull)),
                      selected: _filtre == f,
                      onSelected: (_) => setState(() => _filtre = f),
                      visualDensity: VisualDensity.compact,
                      labelStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          // ⚠️⚠️ TURU 180x — "Aramalar" CIPI GOVDEYI DEGISTIRIR.
          //	Sohbet listesinde "arama" diye bir kayit YOK; bu yuzden
          //	`chats.when(...)` dalina HIC girilmez (girseydi "Eşleşen
          //	sohbet yok" yazip arama gecmisini gizlerdi).
          // ⚠️ Arama kutusu YUKARIDA KALIR ve sorgu `CallsTab`e GECER —
          //	gorunur ama hicbir sey yapmayan bir kutu birakilamaz.
          if (_filtre == _Filtre.aramalar)
            Expanded(child: CallsTab(arama: _arama))
          else
            Expanded(
              child: chats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
              // ⚠️⚠️⚠️ TURU 180t — **HATA DALINDA DA ORNEKLER.**
              //	Onceden ag hatasi TUM listeyi yutuyordu; emulatorde
              //	olculdu: sunucuya ulasilamayinca ekranda YALNIZ hata
              //	metni kaliyor ve kullanicinin ACIKCA istedigi ornek
              //	sohbetler HIC gorunmuyordu.
              // ⚠️ Hata SAKLANMIYOR: ustte ince bir serit + "Tekrar dene"
              //	KALIR — ornekleri gercek veri gibi gostermek yalan olurdu.
              error: (e, _) {
                final ornek = demoSohbetler();
                if (ornek.isEmpty) {
                  return _ErrorRetry(
                    message: apiErrorMessage(e),
                    onRetry: () => ref.read(chatsProvider.notifier).load(),
                  );
                }
                return Column(
                  children: [
                    _HataSeridi(
                      mesaj: apiErrorMessage(e),
                      onRetry: () => ref.read(chatsProvider.notifier).load(),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          for (final c in ornek) _ChatTile(chat: c),
                        ],
                      ),
                    ),
                  ],
                );
              },
              data: (ham) {
                // ⚠️⚠️⚠️ TURU 180t — **ORNEK SOHBETLER** (kullanici emri).
                //	Sunucudan gelenler ONCE, ornekler SONA eklenir.
                // ⚠️ Ornekler suzgeclerden ve aramadan **AYNI YOLDAN**
                //	gecer: turu 121d'de olculdu, demo kayitlari suzgecin
                //	DISINDA tutmak "filtre calismiyor" gibi gorunuyordu.
                final list = [...ham, ...demoSohbetler()];
                // ⚠️⚠️ TURU 76 — FILTRE (kullanici emri: "tümü / okunmamış vs").
                //    TAMAMEN ISTEMCI TARAFINDA: sunucu zaten `unread`, `type` ve
                //    `archived` donduruyor, yani YENI UC GEREKMEZ. Liste kullanicinin
                //    TUM sohbetleri oldugu icin sayfalama da gerekmiyor.
                // ⚠️ Arsiv AYRI bir filtre: digerlerinde arsivlenmisler GIZLI kalir,
                //    yoksa "arsivle" hicbir ise yaramaz.
                var visible = switch (_filtre) {
                  _Filtre.gruplar =>
                    list
                        .where((c) => !c.archived && c.type == 'group')
                        .toList(),
                  _Filtre.arsiv => list.where((c) => c.archived).toList(),
                  _ => list.where((c) => !c.archived).toList(),
                };
                if (_arama.isNotEmpty) {
                  visible = visible
                      .where((c) => c.title.toLowerCase().contains(_arama))
                      .toList();
                }
                // ⚠️⚠️ TURU 180x — TOPLULUKLAR (kullanici emri).
                // ⚠️ YALNIZ "Tümü"de: `Grup` cipi `chats.type=='group'` demek
                //	(topluluk GRUP DEGIL, `channels`), `Arşiv` ise sohbet
                //	bazli bir bayrak — topluluklarda karsiligi YOK.
                final toplulukGoster = _filtre == _Filtre.tumu;
                final kanallar = !toplulukGoster
                    ? const <Kanal>[]
                    : (_arama.isEmpty
                          ? _kanallar
                          : _kanallar
                                .where(
                                  (k) =>
                                      k.ad.toLowerCase().contains(_arama) ||
                                      k.kullaniciAdi.toLowerCase().contains(
                                        _arama,
                                      ),
                                )
                                .toList());
                // SIK GORUSULEN kisiler (test turu 7): arama YOKKEN, arama input'unun altinda
                // en son gorusulen 1:1 kisiler yatay profil seridi (WhatsApp/Telegram deseni).
                // ⚠️ Serit YALNIZ "Tümü" filtresinde: okunmamis/gruplar/arsiv
                //    goruntusunde tum kisileri gostermek FILTREYI ANLAMSIZ kilar.
                final sik = (_arama.isEmpty && _filtre == _Filtre.tumu)
                    ? (list
                          .where((c) => c.type == 'direct' && !c.archived)
                          .toList()
                        ..sort(
                          (a, b) => (b.lastAt ?? DateTime(0)).compareTo(
                            a.lastAt ?? DateTime(0),
                          ),
                        ))
                    : const <Chat>[];
                if (visible.isEmpty && sik.isEmpty && kanallar.isEmpty) {
                  return Center(
                    child: Text(
                      _arama.isNotEmpty
                          ? 'Eşleşen sohbet yok'
                          : switch (_filtre) {
                              _Filtre.gruplar =>
                                'Henüz grubun yok.\nSağ üstteki + ile grup oluştur!',
                              _Filtre.arsiv => 'Arşivde sohbet yok',
                              _ =>
                                'Henüz sohbet yok.\nSağ üstteki + ile yeni sohbet başlat!',
                            },
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return YenileSarmali(
                  onRefresh: () async {
                    // ⚠️ Topluluklar AYRI uctan geliyor; asagi-cek YALNIZ
                    //    sohbetleri tazeleseydi yeni kurulan bir topluluk
                    //    ekranda BIR DAHA gorunmezdi.
                    await Future.wait([
                      ref.read(chatsProvider.notifier).load(),
                      _topluluklariYukle(),
                    ]);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (sik.isNotEmpty)
                        _SikGorusulenSerit(kisiler: sik.take(12).toList()),
                      if (kanallar.isNotEmpty) ...[
                        const _BolumBasligi('Topluluklar'),
                        for (final k in kanallar) _ToplulukTile(kanal: k),
                        const _BolumBasligi('Sohbetler'),
                      ],
                      for (final c in visible) _ChatTile(chat: c),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // ⚠️⚠️⚠️ TURU 180t — **FAB KALDIRILDI** (kullanici emri: *"sohbet
      //	sagdaki + butonu daire kaldir ... sagda + olsun"*). Islev
      //	KAYBOLMADI: ayni sheet'i `_MesajSekmesi` header'indaki "+"
      //	`ChatsScreen.yeniSohbetSecenegiAc` ile aciyor.
    );
  }
}

/// Liste ici bolum basligi ("Topluluklar" / "Sohbetler").
///
/// ⚠️ Baslik YALNIZ topluluk VARSA cizilir: hicbir toplulugu olmayan
///	kullaniciya bos bir "Topluluklar" basligi gostermek, ozelligi
///	kirikmis gibi gosterirdi.
class _BolumBasligi extends StatelessWidget {
  const _BolumBasligi(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        metin,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// ⚠️⚠️ TURU 180x — TOPLULUK SATIRI (sohbet listesinde).
///
/// ⚠️ `_ChatTile` YENIDEN KULLANILMADI: o satir `Chat` modeline, kaydirma
///	eylemlerine (arsivle/sil), okundu rozetine ve `/chat/{id}` rotasina
///	bagli. Topluluk bunlarin HICBIRINE sahip degil (abonelik modeli ayri);
///	sahte bir `Chat` uretmek satiri kaydirinca var olmayan bir sohbeti
///	arsivlemeye calisirdi.
class _ToplulukTile extends StatelessWidget {
  const _ToplulukTile({required this.kanal});
  final Kanal kanal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Avatar(ad: kanal.ad, mediaId: kanal.avatarMediaId, cap: 48),
          // Topluluk rozeti: ayni listede kisi/grup/topluluk yan yana duruyor,
          // ayrimi YALNIZ isimden yapmak mumkun degil.
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.megaphone,
                size: 12,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        kanal.ad,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        kanal.sonMetin.isNotEmpty ? kanal.sonMetin : '@${kanal.kullaniciAdi}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => KanalEkrani(kanalId: kanal.id)),
      ),
    );
  }
}

/// SIK GORUSULEN kisiler yatay seridi (arama input'unun altinda). En son gorusulen 1:1
/// kisiler; avatar + isim; dokun -> sohbeti ac.
class _SikGorusulenSerit extends StatelessWidget {
  const _SikGorusulenSerit({required this.kisiler});
  final List<Chat> kisiler;

  @override
  Widget build(BuildContext context) {
    // ⚠️ `scheme` KALDIRILDI: harf rengini artik ortak `Avatar` belirliyor.
    // TURU 180w — YUKSEKLIK **YAZI OLCEGINDEN TURETILIR**, sabit dp DEGIL.
    //   Emulatorde olculdu: sabit 96 dp ile serit *"BOTTOM OVERFLOWED BY
    //   5.0 PIXELS"* veriyordu (sari-siyah serit) ve kisi adi KIRPILIYORDU.
    // UYARI Satir kutusu carpani **1.45** — OLCUMDEN (turu 173): uygulamanin
    //   fontu Roboto DEGIL **Google Sans Flex** ve satir kutusu punto x
    //   ~1.44 geliyor. Once 1.25 denendi ve emulatorde HALA 3.3 px
    //   TASIYORDU — sayi TAHMIN DEGIL, EKRANDAN geliyor.
    const kSatirKutu = 1.45;
    // UYARI +1 dp pay: `TextPainter` satir yuksekligini YUKARI yuvarlar,
    //   `fontSize * height` carpimi TAM vermez (turu 137).
    // UYARI Serit demo verisiyle HIC cizilmiyordu; gercek sohbet gelince
    //   (turu 180w) sahaya cikti.
    final olcek = MediaQuery.textScalerOf(context);
    final boy =
        4 + // ust dolgu
        6 + // alt dolgu
        2 +
        4 + // baslik dolgusu
        olcek.scale(12) * kSatirKutu + // baslik satiri
        48 + // avatar
        4 + // avatar - ad araligi
        olcek.scale(11) * kSatirKutu + // ad satiri
        1;
    return Container(
      height: boy,
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Text(
              'Sık görüştüklerin',
              // ⚠️ TURU 115c — SABIT  idi: acik temada 2,51:1
              //    (esik 4,5). Serit zemini yok, sayfa zemini uzerinde.
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: kisiler.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final c = kisiler[i];
                final ad = c.title.isNotEmpty ? c.title : 'Kişi';
                return GestureDetector(
                  onTap: () => context.push(
                    '/chat/${c.id}',
                    extra: {
                      'title': ad,
                      'peer_id': c.peerId,
                      'avatar_media_id': c.avatarMediaId,
                    },
                  ),
                  child: SizedBox(
                    width: 62,
                    child: Column(
                      children: [
                        // ⚠️ TURU 76: ham CircleAvatar YERINE ortak `Avatar` —
                        //    `users.avatar_url` sunucuda HIC yazilmiyor (kalici bos
                        //    string), fotograf ancak `avatar_media_id` ile (imzali
                        //    R2 adresi) gorunur. Bu serit uygulamanin en cok
                        //    bakilan yeriydi ve DAIMA harf ciziyordu.
                        Avatar(ad: ad, mediaId: c.avatarMediaId, cap: 48),
                        const SizedBox(height: 4),
                        Text(
                          ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          // ⚠️⚠️ TURU 115c — SABIT `Colors.white70` idi ve
                          //	seridin ARKASINDA ZEMIN YOK (sayfa `#F2F2F5`)
                          //	-> acik temada kontrast **1,09:1**: isimler
                          //	FIILEN GORUNMUYORDU. Mesajlar ekraninin EN
                          //	USTUNDEKI serit.
                          // ⚠️ Ayni dosyadaki `fillColor: 0xFF232326` turu
                          //    115b'de duzeltilmisti; bu ATLANMISTI — koyu
                          //    tema sabitleri dosyada TEK TEK aranmali.
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat});

  final Chat chat;

  String _timeLabel(DateTime? t) {
    if (t == null) return '';
    final local = t.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat.Hm().format(local);
    }
    if (now.difference(local).inDays < 7) {
      return DateFormat.E('tr').format(local);
    }
    return DateFormat('dd.MM.yy').format(local);
  }

  /// [benimMi]: son mesaji BEN mi gonderdim (arama kaydinda gonderen = ARAYAN).
  /// Bilinmiyorsa null -> onizleme yon iddiasinda BULUNMAZ.
  /// ⚠️ TURU 62 — ONIZLEME IKONU (kullanici emri: "uygulamada hicbir 3B ikon
  /// istemiyorum, hepsi 2B olsun"). Onizlemeler eskiden metnin ICINE emoji
  /// koyuyordu (📷 🎥 🎤 📍 📞 📹); emoji sistem emoji fontuyla PARLAK/3B cizilir.
  /// Artik ikon ayri bir Lucide (2B cizgi) widget'i olarak ciziliyor.
  /// ⚠️ YAPMA: onizleme metnine emoji geri koyma.
  IconData? _previewIkon() {
    switch (chat.lastType) {
      case 'image':
        return LucideIcons.image;
      case 'video':
        return LucideIcons.video;
      case 'audio':
        return LucideIcons.mic;
      case 'location':
        return LucideIcons.mapPin;
      // ⚠️ TURU 81 — yeni tiplerin ikonlari (metinle BIRLIKTE eklenir; ikon
      //    olmadan satirlar birbirine benzer ve tur ayirt edilemez).
      case 'contact':
        return LucideIcons.userRound;
      case 'iban':
        return LucideIcons.creditCard;
      case 'etkinlik':
        return LucideIcons.calendarDays;
      case 'poll':
        return LucideIcons.vote;
      case 'system':
        final k = AramaKaydi.coz(chat.lastMessage);
        if (k == null) return null;
        return k.video ? LucideIcons.video : LucideIcons.phone;
      default:
        return null;
    }
  }

  String _preview(bool? benimMi) {
    switch (chat.lastType) {
      case 'image':
        return 'Fotoğraf';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Sesli mesaj';
      case 'location':
        return 'Konum';
      case 'system':
        // TURU 59 — ARAMA KAYDI: eskiden HAM icerik basiliyordu, kullanici sohbet
        // listesinde "call:ended:audio:75" goruyordu. Ayristirma `AramaKaydi`de TEK
        // yerde (balonla ayni kaynak).
        // ⚠️ Taninmayan bicimde de HAM metin BASILMAZ (sozlesme: arama_kaydi.dart) —
        // aksi halde teknik isaretci listeye sizar. Yeni sistem mesaji turu
        // eklendiginde buraya ve `_CallLogChip`e insan-okur metin eklenmelidir.
        return AramaKaydi.coz(chat.lastMessage)?.onizleme(benimMi: benimMi) ??
            'Sistem mesajı';
      // ⚠️⚠️⚠️ TURU 81 — YAPISAL TIPLER (denetim bulgusu: SEVK ENGELIYDI).
      //
      //	Bu `switch`in `default` dali `chat.lastMessage`i **HAM** basiyor.
      //	Turu 81'in yeni tipleri (`contact`/`iban`/`etkinlik`/`poll`) yapisal
      //	veri tasidigi icin kullanici sohbet listesinde sunlari gorurdu:
      //	  · "TR330006100519786457841326|Ahmet Yilmaz"  ← IBAN SIZINTISI
      //	  · "3f9a1c2e-...-...|Konser"                  ← ham UUID
      //	IBAN'in bir listede (ve ekran goruntusunde) gorunmesi ayrica
      //	GIZLILIK sorunudur.
      //
      // ⚠️⚠️ SUNUCUDAKI onizleme switch'i (`chat/handler.go`) ZATEN
      //	duzeltilmisti — ama ISTEMCININ **KENDI KOPYASI** vardi ve o
      //	atlanmisti. "Ayni kuralin iki kopyasi drift eder" dersinin bu
      //	turdaki ornegidir: sunucu dogru, istemci yanlis.
      // ⚠️ YAPMA: sunucuya yeni bir mesaj tipi eklerken YALNIZ sunucu
      //	onizlemesini guncelleme; BURASI DA guncellenmeli.
      case 'contact':
        return 'Kişi';
      case 'iban':
        return 'IBAN';
      case 'etkinlik':
        return 'Etkinlik';
      case 'poll':
        // ⚠️ Ankette `content` SORUDUR (yapisal veri degil), yani gostermek
        //    GUVENLI ve YARARLI — WhatsApp da soruyu gosterir.
        return chat.lastMessage.isEmpty
            ? 'Anket'
            : 'Anket: ${chat.lastMessage}';
      default:
        return chat.lastMessage;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // TURU 59: arama kaydi onizlemesinde YON icin. Kimlik veya `last_sender_id`
    // yoksa null kalir -> onizleme yon iddiasinda bulunmaz (guvenli varsayilan).
    final myId = ref.watch(myUserIdProvider).valueOrNull;
    final bool? benimMi = (myId == null || chat.lastSenderId.isEmpty)
        ? null
        : chat.lastSenderId == myId;
    // ⚠️⚠️ TURU 115b — SOHBET SATIRI MODERNLESTIRILDI (kullanici emri: *"chat
    //    bolumunu daha profesyonel modern bir gorunume getir"*).
    //    · dikey dolgu ACIKCA veriliyor (varsayilan `ListTile` 52 dp avatarla
    //      birlikte satiri 72 dp'de sikistiriyordu; WhatsApp 76-80 dp)
    //    · okunmamis rozeti sabit 18 dp yer tutucu yerine `Visibility` ile
    //      YERINDE tutuluyor — yer tutucu `SizedBox` saat ile rozet arasinda
    //      okunmus sohbetlerde 4 dp fazladan bosluk birakiyordu
    final satir = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // ⚠️ TURU 76: bkz. yukaridaki serh. Grup sohbetinin kendi `avatar_media_id`i
      //    henuz yok -> `Avatar` harf yedegine duser (dogru davranis).
      leading: Avatar(ad: chat.title, mediaId: chat.avatarMediaId, cap: 52),
      title: Row(
        children: [
          if (chat.pinned)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(LucideIcons.pin, size: 14, color: scheme.outline),
            ),
          Expanded(
            child: Text(
              chat.title.isNotEmpty ? chat.title : 'Sohbet',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: chat.unread > 0 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      subtitle: Builder(
        builder: (context) {
          final ikon = _previewIkon();
          final metin = Text(
            _preview(benimMi),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: chat.unread > 0 ? FontWeight.w600 : FontWeight.normal,
              color: chat.unread > 0
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.6),
            ),
          );
          final onizleme = ikon == null
              ? metin
              : Row(
                  children: [
                    Icon(ikon, size: 14, color: scheme.outline),
                    const SizedBox(width: 5),
                    Expanded(child: metin),
                  ],
                );
          // ⚠️⚠️ TURU 78 — ILAN BASLIGI. Bu satir olmasaydi ilan mesajlasmasi
          //    YARIM kalirdi: sohbet ilana bagli olur ama satici HANGI ILAN
          //    oldugunu goremezdi — cozulmek istenen sorunun ta kendisi.
          if (chat.ilanBaslik.isEmpty) return onizleme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                // ⚠️ Onek ZORUNLU: yalniz baslik yazsaydik kullanici bunu son
                //    mesaj saniridi.
                'İlan: ${chat.ilanBaslik}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              onizleme,
            ],
          );
        },
      ),
      // ⚠️⚠️⚠️ TURU 115c — `mainAxisSize.min` **ZORUNLU** (SDK kaynagindan
      //	dogrulandi: `material/list_tile.dart` `trailing`e **SABIT 56 dp
      //	TAVAN** dayatir — `maxHeight: (isDense ? 48.0 : 56.0) + ...`).
      //	`mainAxisSize.max` ile Column TAM 56 dp olur ve icerik daha uzunsa
      //	TASAR. Olculen icerik = `29,42 * olcek + 9`:
      //	  olcek 1.5 -> 53,1 dp (pay 2,9)
      //	  olcek 1.8 -> 62,0 dp -> **6,0 dp TASMA**
      //	  olcek 2.0 -> 67,8 dp -> **11,8 dp TASMA**
      // ⚠️⚠️ Bu tur AGIRLASTIRDI: asagidaki `Visibility(maintainSize)` rozeti
      //	OKUNMUS satirlarda da yer kaplatiyor, yani tasma artik yalniz
      //	okunmamis satirlarda degil **HER SATIRDA** olusuyordu.
      // ⚠️ YAPMA: `min`i kaldirma. ⚠️ YAPMA: `Visibility`yi `if/else`e
      //    dondurme (o zaman saat satirdan satira 2-3 dp kayar).
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _timeLabel(chat.lastAt),
            style: TextStyle(
              fontSize: 12,
              fontWeight: chat.unread > 0 ? FontWeight.w700 : FontWeight.normal,
              color: chat.unread > 0
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 5),
          // ⚠️ `Visibility` (maintainSize) — `if/else` + yer tutucu `SizedBox`
          //    iki dalda FARKLI yukseklik uretiyordu ve okunmus satirlarda saat
          //    2-3 dp yukari kayiyordu. Rozet gorunmez olsa da AYNI yeri kaplar.
          Visibility(
            visible: chat.unread > 0,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            // ⚠️⚠️⚠️ TURU 180t — `alignment` KALDIRILDI (emulatorde OLCULDU).
            //	`Container`a `alignment` verilince cocugu bir `Align`e sarar
            //	ve `Align` GEVSEK kisitta **EN BUYUK BOYUTU** alir; rozet
            //	satirin TAM GENISLIGINE (olculdu: 328 dp) yayiliyordu.
            //	`ListTile` bunu `tileWidth == trailingSize.width` ile
            //	yakalayip yerlesimi PATLATIYOR -> *"RenderBox was not laid
            //	out"* zinciri -> **SOHBET LISTESI EKRANDA HIC CIZILMIYORDU**
            //	(ekran bombos siyah kaliyordu, hicbir sey gorunmuyordu).
            // ⚠️ Turu 138'deki *"Container alignment verilince EN BUYUGU
            //	alir"* tuzaginin BIREBIR tekrari.
            // ⚠️ Ortalama KAYBOLMADI: `Center(widthFactor: 1)` cocuga
            //	SARILIR; minWidth 20 devreye girdiginde tek haneli sayi
            //	yine ORTADA durur.
            // ⚠️ YAPMA: buraya tekrar `alignment:` koyma.
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  chat.unread > 99 ? '99+' : '${chat.unread}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      // ⚠️⚠️⚠️ TURU 180t — **ORNEK SOHBET ACILMAZ.** `demo-` onekli
      //	kayitlarin sunucuda karsiligi YOK; `/chat/<id>` BOS bir ekran
      //	acar ve kullanici uygulamayi KIRIK sanardi (turu 113'te gonderi
      //	demosunda olculen sinif).
      onTap: () {
        if (chat.id.startsWith('demo-')) {
          rootMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Bu bir örnek sohbet.')),
          );
          return;
        }
        context.push(
        '/chat/${chat.id}',
        extra: {
          'avatar_media_id': chat.avatarMediaId,
          'title': chat.title.isNotEmpty ? chat.title : 'Sohbet',
          'peer_id': chat.peerId,
          // ⚠️ TURU 76b: grup mu — ACIKCA tasinir. `peerId == null`a bakmak
          //    YANILTICI olurdu (cagiran kimligi bilmiyorsa 1:1 sohbet de grup
          //    sanilir ve "Grup bilgisi" menusu yanlis yerde cikar).
          'is_group': chat.type == 'group',
        },
        );
      },
    );

    // ⚠️⚠️ TURU 76 — KAYDIRMA AKSIYONLARI (kullanici emri: "mesaj sol sag
    //    yapinca sil/arsivle cikmali"). Uygulamada daha once HICBIR swipe
    //    hareketi YOKTU (Dismissible/Slidable proje genelinde 0 kullanim).
    // ⚠️ `Dismissible` DEGIL `Slidable`: Dismissible ogeyi AGACTAN SILER; arsiv
    //    gibi GERI ALINABILIR bir islemde satiri geri getirmek icin ek durum
    //    yonetimi gerekirdi. Slidable panel acar, satir YERINDE kalir.
    // ⚠️ `groupTag` ZORUNLU: ayni gruptaki baska bir satir acilinca bu
    //    kendiliginden KAPANIR (iki satir birden acik kalmaz).
    return Slidable(
      key: ValueKey(chat.id),
      groupTag: 'sohbet',
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _ayar(context, ref, pinned: !chat.pinned),
            backgroundColor: const Color(0xFF3A3A45),
            foregroundColor: Colors.white,
            icon: chat.pinned ? LucideIcons.pinOff : LucideIcons.pin,
            label: chat.pinned ? 'Kaldır' : 'Sabitle',
          ),
          SlidableAction(
            onPressed: (_) => _ayar(context, ref, muted: !chat.sessiz),
            backgroundColor: const Color(0xFF4A4A55),
            foregroundColor: Colors.white,
            icon: chat.sessiz ? LucideIcons.bell : LucideIcons.bellOff,
            label: chat.sessiz ? 'Sesi aç' : 'Sessiz',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _ayar(context, ref, archived: !chat.archived),
            backgroundColor: const Color(0xFF6C2BD9),
            foregroundColor: Colors.white,
            icon: chat.archived
                ? LucideIcons.archiveRestore
                : LucideIcons.archive,
            label: chat.archived ? 'Geri al' : 'Arşivle',
          ),
          SlidableAction(
            onPressed: (_) => _sil(context, ref),
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            label: 'Sil',
          ),
        ],
      ),
      child: satir,
    );
  }

  /// Sabitle / arşivle / sessize al. ⚠️ Gonderilmeyen alan sunucuda DEGISMEZ.
  Future<void> _ayar(
    BuildContext context,
    WidgetRef ref, {
    bool? pinned,
    bool? archived,
    bool? muted,
  }) async {
    final mesajci = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiProvider)
          .patch(
            '/chats/${chat.id}',
            data: {
              if (pinned != null) 'pinned': pinned,
              if (archived != null) 'archived': archived,
              if (muted != null) 'muted': muted,
            },
          );
      await ref.read(chatsProvider.notifier).load();
    } catch (e) {
      mesajci.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  /// Sohbeti BENDEN sil.
  /// ⚠️ Karsi tarafin gecmisi ETKILENMEZ — sunucu satiri silmez, `cleared_at`
  ///    damgasi atar (bkz. internal/chat/grup.go serhi). Metin bunu ACIKCA soyler,
  ///    yoksa kullanici "karsi taraftan da silindi" saniyor.
  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final mesajci = ScaffoldMessenger.of(context);
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sohbet silinsin mi?'),
        content: const Text(
          'Bu sohbet yalnızca sizden silinir. Karşı taraf mesajları görmeye '
          'devam eder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await ref.read(apiProvider).delete('/chats/${chat.id}');
      await ref.read(chatsProvider.notifier).load();
    } catch (e) {
      mesajci.showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }
}

/// Liste ustunde ince hata seridi (ornekler alta cizilmeye devam eder).
///
/// ⚠️ Tam sayfa `_ErrorRetry` YERINE: o, altindaki her seyi yutuyordu.
class _HataSeridi extends StatelessWidget {
  const _HataSeridi({required this.mesaj, required this.onRetry});
  final String mesaj;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ks = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: ks.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: ks.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mesaj,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: ks.onSurface),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text("Tekrar dene", style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

/// Mesajlar ekranindaki "+" sheet'inin bir maddesi.
///
/// ⚠️ `olustur_menusu.dart`taki `_satir` ile AYNI olculer: iki sheet ayni
///    uygulamada farkli gorunmemeli. Kod KOPYALANMADI cunku bu sheet bir
///    DEGER dondurur (`Navigator.pop(c, kod)`), digeri ekran acar — sozlesme
///    farkli. Ortaklastirmak icin ikisini de saran bir soyutlama gerekirdi ve
///    o soyutlama iki cagri yerine deger etmezdi.
Widget _yeniMadde(
  BuildContext c,
  IconData ikon,
  String baslik,
  String altBaslik,
  String kod,
) {
  final scheme = Theme.of(c).colorScheme;
  return InkWell(
    onTap: () => Navigator.pop(c, kod),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // ⚠️ TURU 115c — `primary@0.12` + mor ikon idi; kardes
              //    `olustur_menusu._satir` notr gri kullaniyordu ve iki panel
              //    yan yana FARKLI dilde duruyordu. Serh "AYNI olculer" diyor
              //    ama RENK icin yanlis izlenim veriyordu.
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, size: 19, color: scheme.onSurface),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  baslik,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  altBaslik,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: scheme.onSurface.withValues(alpha: 0.35),
          ),
        ],
      ),
    ),
  );
}


/// + dugmesi: yeni sohbet mi, yeni grup mu.
///
/// ⚠️⚠️ TURU 180t — **DOSYA SEVIYESINE TASINDI.** "+" artik FAB degil,
///	`_MesajSekmesi`nin 44 dp header'inda (kullanici emri) ve o header
///	`ChatsScreen`in DISINDA yasiyor — sheet'i acan yolun disaridan
///	cagrilabilmesi gerekiyordu.
/// ⚠️ Ikinci bir kopya YAZILMADI: sheet govdesi TEK KAYNAK; State icindeki
///	Cagiran: `_MesajSekmesi` header'indaki "+".
Future<void> yeniSohbetSecenegiAc(BuildContext context) async {
    final secim = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      // ⚠️⚠️⚠️ TURU 114 (denetim) — **`isScrollControlled` ZORUNLU.**
      //
      //	Sheet bu turda IKI maddeden DORDE cikti. Bayrak verilmediginde
      //	Flutter tavani `ekran * 9/16` yapar; ustune `showDragHandle`
      //	(~48 dp) ve `SafeArea` alt centigi biner.
      //	OLCULDU (gercek `flutter test`, uygulamanin kendi temasi):
      //	  360x640 · olcek 1.0 -> **24 px tasma**
      //	  360x640 · olcek 1.3 -> **54 px**
      //	  360x640 · olcek 1.5 -> **94 px**, son madde
      //	  ("Toplulukları keşfet") EKRAN DISINDA ve `tester.tap` ISKALIYOR
      //	  = ozellik ULASILAMAZ.
      //	411x896 (test cihazi) TASMIYOR — bu yuzden sahada gorunmezdi.
      // ⚠️ Ayni hata turu 90b'de `olustur_menusu.dart`ta OLCULUP
      //    duzeltilmis ve orada `isScrollControlled` "ZORUNLU" diye
      //    isaretlenmisti; bu sheet o dersi ALMAMISTI.
      isScrollControlled: true,
      // ⚠️⚠️ TURU 115b — MODERNLESTIRME (kullanici emri: *"chat bolumunu daha
      //    profesyonel modern bir gorunume getir"*). Tutamac + baslik +
      //    ikonlarin renkli kutulari; `olustur_menusu.dart` ile AYNI DIL —
      //    iki sheet ayni uygulamada farkli gorunuyordu.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        // ⚠️⚠️⚠️ TURU 115c — `SingleChildScrollView` **SEVK ENGELIYDI**
        //	(gercek `showModalBottomSheet` ile OLCULDU):
        //	  360x640 · olcek 2.0 -> **34 px TASMA**
        //	  320x568 · olcek 1.8 -> **59 px**
        //	  320x568 · olcek 2.0 -> **149 px**, son madde
        //	  ("Toplulukları keşfet") **EKRAN DISINDA** = ULASILAMAZ.
        //
        // ⚠️⚠️ **TURU 114'UN BIREBIR TEKRARIYDI.** O turda olculup
        //	`isScrollControlled: true` eklenmisti — ama o bayrak yalnizca
        //	**TAVANI KALDIRIR**, icerigi KAYDIRILABILIR YAPMAZ. Kardes
        //	`olustur_menusu.dart` iki parcayi da (bayrak + kaydirma)
        //	tasiyordu; bu dosyaya YALNIZ BIRI kopyalanmisti.
        //	**ASIMETRININ KENDISI HATAYDI.**
        // ⚠️ YAPMA: bu sarmali kaldirma; `isScrollControlled`i tek basina
        //    yeterli sayma.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Yeni',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            _yeniMadde(
              c,
              LucideIcons.messageCirclePlus,
              'Yeni sohbet',
              'Bir kişiyle mesajlaş',
              'sohbet',
            ),
            _yeniMadde(
              c,
              LucideIcons.users,
              'Yeni grup',
              'Birden fazla kişiyle mesajlaş',
              'grup',
            ),
            // ⚠️⚠️⚠️ TURU 114 — **TOPLULUK** (kullanici emri: *"mesajlar
            //	kisminda topluluk yok, topluluk olusturma ekle"*).
            //
            // ⚠️⚠️ YENI TABLO/TIP **ACILMADI**: topluluk = **KANAL**
            //	(`chats.type='channel'`). Yasak testi ("ayni kavram + ayni
            //	gorunurluk + ayni aktorler") tutuyor — ikisi de *"bir kisi
            //	yazar, cok kisi okur"* iliskisidir ve `internal/kanal`
            //	paketi (olustur · abone ol · gonderi · kesfet) turu 75'ten
            //	beri CANLI. Ikinci bir kavram acmak, ayni mantigin ikinci
            //	kopyasi olurdu ve KACINILMAZ olarak drift ederdi.
            //
            // ⚠️⚠️ ASIL SORUN KESFEDILEBILIRLIKTI: kanal olusturmanin TEK
            //	girisi menu > Kanallar > "+" idi; kullanici mesajlar
            //	ekraninda arayip bulamiyordu. Yeni giris o ekrani acar —
            //	IKINCI BIR AKIS YAZILMADI.
            _yeniMadde(
              c,
              LucideIcons.radio,
              'Topluluk oluştur',
              // ⚠️⚠️ TURU 114 (denetim) — **"ve yorumlar" KALDIRILDI.**
              //	`channel_posts` (022) yalniz `begeni_sayisi` ve
              //	`goruntulenme` tutuyor; YORUM TABLOSU YOK ve `internal/
              //	kanal/handler.go` yorum ucu ACMIYOR. Var olmayan bir
              //	ozelligi vaat etmek, projedeki "ozellik var gorunup
              //	fiilen yok" sinifinin ta kendisi.
              'Sen yazarsın, üyeler okur',
              'topluluk',
            ),
            _yeniMadde(
              c,
              LucideIcons.compass,
              'Toplulukları keşfet',
              'Var olan topluluklara katıl',
              'kesfet',
            ),
            const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || secim == null) return;
    if (secim == 'sohbet') {
      context.push('/search');
      return;
    }
    // ⚠️ TURU 114 — topluluk dallari: ikisi de MEVCUT kanal ekranlarini acar.
    if (secim == 'topluluk') {
      // ⚠️⚠️⚠️ TURU 114 (denetim) — **DONEN ID OKUNUR.**
      //
      //	Ilk yazimda `await push<String>(...)` yazilip donen id ATILIYORDU.
      //	Kanallar `chats` DEGIL, AYRI `channels` tablosunda yasiyor ve
      //	`ListChats` yalniz `chats`ten okuyor — yani olusturulan topluluk
      //	mesaj listesinde **YAPISAL OLARAK GORUNEMEZ**. Kullanici
      //	degismemis listeye donuyor, olusturmanin basarisiz oldugunu
      //	saniyor ve TEKRAR TEKRAR deniyordu; her deneme GERCEK bir kanal
      //	aciyor ve 10. denemede *"en fazla 10 kanal acabilirsiniz"*
      //	hatasi geliyor — arkada 10 YETIM topluluk kaliyordu.
      // ⚠️ Turu 90b'nin *"menu DONEN ID'yi ATIYORDU"* dersinin tekrari.
      // ⚠️ Kardes cagri yeri (`kanallar_sekmesi.dart`) ZATEN boyle yapiyor;
      //    asimetrinin kendisi hataydi.
      final id = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const KanalOlustur()));
      if (id != null && context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => KanalEkrani(kanalId: id, onIsim: 'Topluluk'),
          ),
        );
      }
      return;
    }
    if (secim == 'kesfet') {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const KanallarSayfasi()));
      return;
    }
    final chatId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const GrupOlusturEkrani()),
    );
    if (chatId != null && context.mounted) {
      context.push('/chat/$chatId', extra: {'title': 'Grup'});
    }
}

/// ⚠️⚠️⚠️ TURU 180t — **ORNEK SOHBETLER** (kullanici emri: *"ornek
///	sohbetler ekle"*).
///
/// ⚠️⚠️ `kDemoAkis` bayragina baglidir (akis/hikaye demosuyla AYNI
///	anahtar): yayin oncesi TEK YERDEN kapanir.
/// ⚠️⚠️ Kimlikler **`demo-` onekli**: `chats_screen` bunlara dokununca
///	sohbeti ACMAZ, durustce "ornek kayit" der — gercek bir sohbet
///	rotasina gitseydi BOS ekran acilir, kullanici KIRIK sanardi
///	(turu 113'te gonderi demosunda olculen sinif).
/// ⚠️ Sunucudan gelen sohbetler DAIMA ONCE gelir: ornekler listenin
///	SONUNA eklenir ve gercek veri varken bile gorunur (kullanici
///	"ornek sohbetler ekle" dedi, "bosken goster" demedi).
List<Chat> demoSohbetler() {
  if (!kDemoAkis) return const [];
  Chat y(String id, String ad, String son, String tur, int okunmamis,
          {int dkOnce = 0}) =>
      Chat(
        id: 'demo-sohbet-$id',
        type: tur,
        title: ad,
        avatarUrl: '',
        pinned: false,
        archived: false,
        lastMessage: son,
        lastType: 'text',
        lastSenderId: '',
        // ⚠️ Zaman SABIT DEGIL, GORELI: sabit bir tarih yazilsaydi
        //	liste "2 gun once" gibi eskiyen bir sey gosterirdi.
        lastAt: DateTime.now().subtract(Duration(minutes: dkOnce)),
        unread: okunmamis,
      );
  return [
    y('1', 'Ayşe Demir', 'Yarın sahilde buluşalım mı?', 'direct', 2, dkOnce: 4),
    y('2', 'Mehmet Kaya', 'Fotoğrafları attım, baktın mı?', 'direct', 0,
        dkOnce: 38),
    y('3', 'Gebze Komşuları', 'Zeynep: Pazar kaçta açılıyor?', 'group', 5,
        dkOnce: 95),
    y('4', "McDonald's", 'Siparişiniz hazırlanıyor.', 'direct', 0,
        dkOnce: 210),
    y('5', 'Kuaför Serkan', 'Randevunuzu onayladık.', 'direct', 1,
        dkOnce: 400),
  ];
}
