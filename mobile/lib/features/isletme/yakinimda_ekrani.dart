/// ⚠️⚠️⚠️ TURU 85 — "YAKINIMDA": USTTE HARITA, ALTTA KARTLAR.
///
/// Kullanici emri: *"menuye tikladigimizda acilan pencereye yakinimda
/// eklemeliyiz; ustte harita altta kartlar olacak — isletmeler, eczane vs;
/// harita uber tarzi grimsi beyaz olsun"*.
///
/// ═══════════ HARITA HAKKINDA DURUST DURUM (TURU 85b'de GUNCELLENDI) ═══════
///
/// ⚠️⚠️ **BU SERH ESKIDEN "SDK KURULU DEGIL" DIYORDU — ARTIK KURULU.**
///	Turu 85'te `google_maps_flutter` eklendi, Maps SDK'lari (Android +
///	iOS) `gebzem-app` projesinde ACILDI ve Maps'e KISITLI bir anahtar
///	uretildi. Denetim bu bayat serhi bulguladi: metin hala *"YAPMA:
///	`google_maps_flutter` ekleme"* hukmu tasiyordu, yani gelecekte biri
///	SDK'yi KALDIRMAYA calisabilirdi.
///
/// BUGUNKU DURUM:
///   · SDK KURULU ve KULLANILIYOR (`GoogleMap` asagida).
///   · ANAHTAR **REPODA DEGIL**: derleme aninda enjekte edilir (Android
///     `manifestPlaceholders`, iOS PlistBuddy -> Info.plist). Repo PUBLIC
///     oldugu icin anahtarin izlenen hicbir dosyada bulunmamasi ZORUNLU.
///   · `haritaAnahtariVar` (`--dart-define=HARITA`) derlemede anahtar
///     verilip verilmedigini soyler; verilmediyse ALTTAKI yer tutucu cizilir.
///   · Stil YEREL JSON ("uber tarzi grimsi beyaz"); CLAUDE.md `cloudMapId`
///     kullanimini yasakliyor (ucretli) — yerel stil UCRETSIZDIR.
///
/// ⚠️ YAPMA: `haritaAnahtariVar` kapisini kaldirip haritayi kosulsuz cizme.
///    Anahtarsiz derlemede harita Android'de "For development purposes only"
///    filigranli GRI kutu, iOS'ta BOS ekran olur — ozellik BOZUK gorunur.
/// ⚠️ YAPMA: anahtari koda/pubspec'e/Info.plist'e SABIT yazma (repo PUBLIC).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart'
    show EagerGestureRecognizer, OneSequenceGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/yenile.dart';
import '../medya/konum_servisi.dart';
import '../medya/medya_gorsel.dart';
import '../sosyal/profil_sayfasi.dart';
import 'isletme_servisi.dart';

/// Uber tarzi acik-gri harita paleti.
///
/// ⚠️ Renkler Google'in "silver" stiliyle ayni aileden secildi: zemin kirli
///    beyaz, yollar beyaz, su acik gri-mavi. Gercek harita geldiginde AYNI
///    palet JSON stil olarak verilecek — yer tutucu ile harita arasinda
///    gorsel SICRAMA olmasin.
/// ⚠️⚠️ HARITA ANAHTARI DERLEMEYE GOMULUDUR — istemci onu OKUYAMAZ (Android'de
///    manifest meta-data, iOS'ta Info.plist; ikisi de native tarafta).
///
///    Bu bayrak `--dart-define=HARITA=1` ile gelir ve CI'da anahtar VARSA
///    gecilir. Boylece: anahtar yoksa harita HIC KURULMAZ ve kullanici bozuk
///    gri kutu yerine DURUST bir yer tutucu gorur.
/// ⚠️ YAPMA: varsayilani `true` yapma — yerel `flutter run` (secret'siz)
///    anahtarsiz calisir ve harita bozuk gorunurdu.
const haritaAnahtariVar = bool.fromEnvironment('HARITA');

/// ⚠️⚠️ **UBER TARZI GRIMSI-BEYAZ** harita stili (kullanici emri).
///
/// Google'in "silver" ailesinden: zemin kirli beyaz, yollar beyaz, POI ve
/// ilgisiz etiketler KAPALI (kalabalik yapiyor), su acik gri-mavi.
/// ⚠️ `cloudMapId` KULLANILMADI (CLAUDE.md yasagi — ucretli). Yerel JSON
///    stil UCRETSIZDIR ve ayni gorunumu verir.
/// ⚠️ Renkler yer tutucu paletiyle (`_zemin`/`_yol`/`_su`) AYNI aileden:
///    anahtar eklendiginde gorsel SICRAMA olmasin.
/// ⚠️⚠️⚠️ TURU 86 — **ÖZEL STİL KALDIRILDI, NORMAL GOOGLE HARİTASI KULLANILIYOR.**
///
/// Kullanıcı (11 Ağu): *"bu nasıl bir harita? normal google haritası değil ki bu"*.
/// **HAKLIYDI.** Turu 85'te "uber tarzı grimsi beyaz" isteğini bir stil JSON'una
/// çevirirken haritanın TANIMLAYICI her unsurunu kapatmıştım:
///
///	· `poi` -> **visibility: off**     (hiçbir işletme/mekân görünmüyor)
///	· `road … labels` -> **off**       (SOKAK ADI YOK)
///	· `labels.icon` -> **off**         (simgeler yok)
///	· `transit` -> **off**             (metro/otobüs yok)
///	· `administrative geometry` -> off (ilçe sınırları yok)
///
/// Geriye beyaz çizgili GRİ BİR KÂĞIT kalıyordu — kullanıcı nerede olduğunu
/// anlayamıyor, bir yeri tanıyamıyordu. "Grimsi beyaz" bir RENK TERCİHİYDİ;
/// haritayı OKUNAMAZ hale getirme yetkisi değildi.
///
/// ⚠️ **DERS: bir görsel tercihi uygularken ürünün TEMEL İŞLEVİNİ elinden
///    alma.** Harita bir dekor değil; sokak adı ve mekân etiketleri onun
///    VAROLUŞ SEBEBİDİR.
/// ⚠️ YAPMA: buraya `poi`/`road labels`/`transit` kapatan bir stil geri koyma.
///    Renk tonu istenirse YALNIZCA `geometry` renkleri değiştirilir, hiçbir
///    `visibility: off` eklenmez.
/// ⚠️ `cloudMapId` YASAK (CLAUDE.md — ücretli).
const String? _haritaStili = null;

const _zemin = Color(0xFFF2F3F5);
const _yol = Color(0xFFFFFFFF);
const _yolCizgi = Color(0xFFE4E6EA);
const _su = Color(0xFFDDE6EC);
const _yesil = Color(0xFFE8EDE6);

class YakinimdaEkrani extends ConsumerStatefulWidget {
  const YakinimdaEkrani({super.key});

  @override
  ConsumerState<YakinimdaEkrani> createState() => _YakinimdaEkraniState();
}

class _YakinimdaEkraniState extends ConsumerState<YakinimdaEkrani> {
  ({double enlem, double boylam})? _konum;
  List<IsletmeOzet> _liste = [];
  bool _yukleniyor = true;
  String? _hata;
  String _kategori = '';
  double _km = 10;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  /// ⚠️⚠️⚠️ TURU 85b — BAYAT-YANIT KAPISI (denetim bulgusu).
  ///
  ///	Serhim *"yeniden girme kapisi"* diyordu ama GOVDEDE KAPI YOKTU —
  ///	yalnizca `mounted` kontrolu vardi (CLAUDE.md'nin defalarca yazdigi
  ///	"yorumun anlattigi kontrol govdede yok" sinifi, bu kez yeni kodda).
  ///	`_yukle` DORT yerden cagriliyor (acilis · asagi-cek · kategori
  ///	degisimi · mesafe degisimi) ve kullanici hizli hizli kategori
  ///	degistirdiginde istekler PARALEL ucuyor. Yanitlar GELIS SIRASINA gore
  ///	`setState` ettigi icin YAVAS gelen ESKI sorgu, HIZLI gelen YENISININ
  ///	uzerine yaziyordu: ekranda "Eczane" secili gorunurken liste
  ///	OTELLERI gosteriyordu.
  ///
  /// FIX: her cagri bir NESIL alir; yalnizca EN SON nesil ekrana yazabilir.
  /// ⚠️ Sayac `await`lerden ONCE artirilir ve YEREL bir kopya yakalanir.
  /// ⚠️ YAPMA: bunu tek bir `bool _mesgul` bayragiyla degistirme — o, ikinci
  ///    istegi TAMAMEN reddeder ve kullanicinin son secimi UYGULANMAZDI.
  int _nesil = 0;

  Future<void> _yukle({bool konumuTazele = false}) async {
    if (!mounted) return;
    final nesil = ++_nesil;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      // ⚠️ Servis await'ten ONCE yakalanir (turu 78b dersi: disposed State'te
      //    `ref.read` StateError firlatir ve is SESSIZCE iptal olur).
      final svc = ref.read(isletmeServisiProvider);
      // ⚠️⚠️ TURU 85b — ASAGI-CEK **GPS'I DE TAZELER** (denetim bulgusu).
      //    Eskiden `_konum` bir kez alinip SUREKLI onbellekten okunuyordu;
      //    kullanici baska bir semte gidip asagi cekse bile liste ESKI
      //    konuma gore geliyordu. Ustelik haritadaki mavi nokta cihazin
      //    GERCEK konumunu ciziyordu -> pin ile liste BIRBIRINI TUTMUYORDU.
      final k = (konumuTazele ? null : _konum) ?? await KonumServisi.konumAl();
      if (!mounted || nesil != _nesil) return;
      if (k == null) {
        setState(() {
          _yukleniyor = false;
          // ⚠️ TURU 85c — LISTE BURADA DA BOSALTILIR (denetim bulgusu).
          //    Kardes `catch` dalinda duzeltme yapilmisti ama BU dal
          //    atlanmisti: konum izni kaldirilip asagi cekildiginde ekran
          //    "Konumun alınamadı" derken harita BAYAT pinleri ve
          //    "N işletme yakınında" rozetini cizmeye devam ediyordu.
          //    ("Ayni kuralin iki kopyasi drift eder" — bu kez KENDI
          //     duzeltmemin kardes dalinda.)
          _liste = const [];
          _hata = 'Konumun alınamadı. Yakındakileri görebilmek için '
              'konum iznine ihtiyacımız var.';
        });
        return;
      }
      final l = await svc.yakinimda(
        enlem: k.enlem,
        boylam: k.boylam,
        km: _km,
        kategori: _kategori,
      );
      if (!mounted || nesil != _nesil) return;
      setState(() {
        _konum = k;
        _liste = l;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted || nesil != _nesil) return;
      setState(() {
        _yukleniyor = false;
        // ⚠️ Hata halinde liste BOSALTILIR: aksi halde harita ve kartlar
        //    BAYAT sonuclari cizmeye devam ediyordu ("N işletme yakınında"
        //    rozeti + pinler), yani kullanici hata seridini gorurken ALTTA
        //    guncel saniyordu (denetim bulgusu).
        _liste = const [];
        _hata = 'Yakındaki işletmeler alınamadı';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yakınımda')),
      body: YenileSarmali(
        // ⚠️ Asagi-cek KONUMU DA tazeler (bkz. `_yukle` serhi).
        onRefresh: () => _yukle(konumuTazele: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ---- USTTE HARITA
            _HaritaAlani(
              merkez: _konum,
              isletmeler: _liste,
              acildi: (i) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: i.id)),
              ),
            ),
            _suzgecSeridi(),
            // ---- ALTTA KARTLAR
            // ⚠️⚠️ TURU 85c — SPINNER YALNIZ **LISTE BOSKEN** (denetim bulgusu).
            //    Kapi duz `_yukleniyor` iken her asagi-cekte kart listesi
            //    agactan silinip yerine ikinci bir spinner geliyordu; yenileme
            //    gostergesi ZATEN uc noktayla veriliyor. Bu, turu 83'te
            //    profil/bildirimler/kaydedilenler ekranlarinda duzeltilen
            //    "yenilerken sayfa bosaliyor" sinifinin hafif tekrariydi.
            // ⚠️ YAPMA: kapiyi tekrar duz `_yukleniyor`a dondurme.
            if (_yukleniyor && _liste.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hata != null)
              _bilgi(LucideIcons.mapPinOff, _hata!, dugme: 'Tekrar dene')
            else if (_liste.isEmpty)
              _bilgi(
                LucideIcons.store,
                'Bu mesafede işletme bulunamadı.\n'
                'Mesafeyi artırmayı dene.',
              )
            else
              ..._liste.map(_kart),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _bilgi(IconData ikon, String metin, {String? dugme}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 40),
    child: Column(
      children: [
        Icon(ikon, size: 40, color: Colors.grey),
        const SizedBox(height: 14),
        Text(
          metin,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, height: 1.45),
        ),
        if (dugme != null) ...[
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _yukle, child: Text(dugme)),
        ],
      ],
    ),
  );

  /// Kategori cipleri + mesafe secici.
  ///
  /// ⚠️ Kategori listesi `isletmeKategorileri` TEK KAYNAGINDAN gelir —
  ///    burada elle yazilsaydi sunucuya eklenen 'eczane'/'otel' gibi yeni
  ///    kategoriler bu ekranda GORUNMEZDI.
  Widget _suzgecSeridi() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            _cip('Tümü', _kategori.isEmpty, () {
              setState(() => _kategori = '');
              _yukle();
            }),
            for (final e in isletmeKategorileri.entries)
              _cip(e.value, _kategori == e.key, () {
                setState(() => _kategori = e.key);
                _yukle();
              }),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: Row(
          children: [
            const Icon(LucideIcons.ruler, size: 15, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              '${_km.round()} km içinde',
              style: const TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            Expanded(
              child: Slider(
                value: _km,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${_km.round()} km',
                onChanged: (v) => setState(() => _km = v),
                // ⚠️ Istek YALNIZ birakinca atilir: her piksel hareketinde
                //    atsaydi tek surukleme onlarca sorgu uretirdi.
                onChangeEnd: (_) => _yukle(),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _cip(String etiket, bool secili, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(etiket),
      selected: secili,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _kart(IsletmeOzet i) => ListTile(
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfilSayfasi(userId: i.id)),
    ),
    leading: Avatar(
      ad: i.ad,
      mediaId: i.avatarMediaId,
      avatarUrl: i.avatarUrl,
      cap: 46,
    ),
    title: Row(
      children: [
        Flexible(
          child: Text(
            i.ad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (i.dogrulandi) ...[
          const SizedBox(width: 4),
          const Icon(LucideIcons.badgeCheck, size: 15, color: Color(0xFF3AA9FF)),
        ],
      ],
    ),
    subtitle: Text(
      [
        isletmeKategoriAdi(i.kategori),
        if (i.ilce.isNotEmpty) i.ilce,
        if (i.adres.isNotEmpty) i.adres,
      ].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12.5),
    ),
    trailing: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          i.mesafeMetni,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        // ⚠️ "Yol tarifi" TELEFONUN KENDI harita uygulamasini acar
        //    (`KonumServisi.haritadaAc`) — uygulama ici harita gerekmez ve
        //    yol tarifi orada zaten calisir (turu 81 karari).
        GestureDetector(
          onTap: () => KonumServisi.haritadaAc(i.enlem, i.boylam),
          child: const Text(
            'Yol tarifi',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF3AA9FF)),
          ),
        ),
      ],
    ),
  );
}

/// ⚠️⚠️ HARITA ALANI — su an **YER TUTUCU** (bkz. dosya basindaki serh).
///
/// Gercek konumu ve isletmeleri DOGRU GORECELI KONUMDA cizer: merkez
/// kullanici, cevresinde isletme igneleri. Karo (tile) katmani yoktur.
///
/// ⚠️ Gercek haritaya gecerken SADECE bu sinifin `build`i degisir; ekranin
///    geri kalani ve cagri yeri AYNEN kalir.
/// ⚠️⚠️⚠️ TURU 85c — **`StatelessWidget` DEGIL `StatefulWidget`** (denetim).
///
///	`GoogleMap`in `initialCameraPosition`i adindan da anlasilacagi gibi
///	YALNIZCA ILK KURULUMDA uygulanir; sonraki `build`lerde YOK SAYILIR.
///	Ustelik `scrollGesturesEnabled: false` (harita bir listenin icinde
///	oldugu icin ZORUNLU) ve `myLocationButtonEnabled: false` -> kullanicinin
///	kamerayi elle tasima yolu da YOK.
///	SONUC: asagi-cek GPS'i tazeleyip listeyi guncelliyor ama **harita ilk
///	konuma CIVILI kaliyordu**; kullanici baska bir semte gidip yenilediginde
///	kartlar yeni sehri, harita ESKI sehri gosteriyordu ve duzeltmenin
///	HICBIR YOLU yoktu (uygulamayi oldurmek disinda).
///	FIX: `onMapCreated` ile controller saklanir, `merkez` degistiginde
///	`animateCamera` ile takip edilir.
/// ⚠️ YAPMA: `onMapCreated`i kaldirma ya da bu sinifi tekrar `Stateless`
///    yapma; `initialCameraPosition` TEK BASINA yeterli DEGILDIR.
class _HaritaAlani extends StatefulWidget {
  const _HaritaAlani({
    required this.merkez,
    required this.isletmeler,
    this.acildi,
  });

  final ({double enlem, double boylam})? merkez;
  final List<IsletmeOzet> isletmeler;

  /// Harita balonuna dokununca cagrilir (bkz. `onInfoWindowTap` serhi).
  /// ⚠️ Gezinmeyi EKRAN yapar, bu bilesen DEGIL: `_HaritaAlani` saf gorunum
  ///    kalsin ki anahtarsiz yer tutucu daliyla ayni sozlesmeyi paylassin.
  final void Function(IsletmeOzet)? acildi;

  @override
  State<_HaritaAlani> createState() => _HaritaAlaniState();
}

class _HaritaAlaniState extends State<_HaritaAlani> {
  GoogleMapController? _harita;

  ({double enlem, double boylam})? get merkez => widget.merkez;
  List<IsletmeOzet> get isletmeler => widget.isletmeler;
  void Function(IsletmeOzet)? get acildi => widget.acildi;

  @override
  void didUpdateWidget(covariant _HaritaAlani eski) {
    super.didUpdateWidget(eski);
    // ⚠️ Kamera YALNIZ merkez GERCEKTEN degistiginde tasinir; her `build`te
    //    `animateCamera` cagirmak haritayi surekli sarsardi.
    final y = widget.merkez;
    final e = eski.merkez;
    if (y != null && (e == null || e.enlem != y.enlem || e.boylam != y.boylam)) {
      _harita?.animateCamera(
        CameraUpdate.newLatLng(LatLng(y.enlem, y.boylam)),
      );
    }
  }

  @override
  void dispose() {
    // ⚠️ `GoogleMapController.dispose()` platform gorunumunu de yikar; burada
    //    YALNIZ referans birakilir (gorunumu Flutter'in kendisi soker).
    _harita = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ⚠️⚠️ GERCEK HARITA — yalniz ANAHTAR VARSA.
            //
            //    Anahtar yoksa Google SDK'si Android'de "For development
            //    purposes only" filigranli GRI KUTU, iOS'ta BOS ekran cizer
            //    (iOS'ta `provideAPIKey` bos anahtarla cagrilirsa ASSERT ATIP
            //    COKER — bu yuzden `AppDelegate` de bos kontrolu yapiyor).
            //    O yuzden anahtarsiz derlemede ALTTAKI yer tutucu kalir:
            //    konumlar DOGRU gorunur, yalnizca karo katmani olmaz.
            // ⚠️ YAPMA: bu kapiyi kaldirip haritayi kosulsuz cizme.
            if (haritaAnahtariVar && merkez != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(merkez!.enlem, merkez!.boylam),
                  zoom: 13.5,
                ),
                // ⚠️ Controller SAKLANIR: konum degisince kamerayi tasiyan
                //    TEK yol budur (bkz. sinif serhi).
                onMapCreated: (c) => _harita = c,
                // ⚠️ NORMAL GOOGLE HARITASI (bkz. `_haritaStili` serhi).
                style: _haritaStili,
                myLocationEnabled: true,
                // ⚠️ TURU 86 — "konumuma don" dugmesi ACILDI: harita artik
                //    surukleniyor, dolayisiyla geri donme yolu SART.
                myLocationButtonEnabled: true,
                // ⚠️⚠️⚠️ TURU 86 — HARITA JESTLERI **ACILDI** (kullanici emri).
                //
                //	Turu 85'te bunlarin hepsi `false` idi ve gerekce olarak
                //	*"harita bir LISTE ICINDE, dikey jesti alirsa kullanici
                //	sayfayi kaydiramaz"* yazilmisti. Sonuc: kullanici haritaya
                //	dokunuyor, parmagini suruyor ve **HICBIR SEY OLMUYORDU** —
                //	harita canli degil, EKRAN GORUNTUSU gibi duruyordu.
                //	Etiketlerin de kapali olmasiyla birlesince ortaya
                //	"harita olmayan bir harita" cikmisti.
                //
                //	Kaydirma catismasi `EagerGestureRecognizer` ile cozulur:
                //	dokunus HARITANIN UZERINDE baslarsa jesti HARITA alir,
                //	kartlarin uzerinde baslarsa LISTE alir. Iki yuzey ayri.
                // ⚠️ YAPMA: jestleri tekrar `false` yapma; catismayi
                //    recognizer YERINE jestleri kapatarak "cozme".
                scrollGesturesEnabled: true,
                zoomGesturesEnabled: true,
                rotateGesturesEnabled: false,
                tiltGesturesEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
                markers: {
                  for (final i in isletmeler)
                    if (i.enlem != 0 || i.boylam != 0)
                      Marker(
                        markerId: MarkerId(i.id),
                        position: LatLng(i.enlem, i.boylam),
                        // ⚠️⚠️ TURU 85b — BALONA DOKUNMA ISLETMEYI ACAR.
                        //    Eskiden `onTap` VERILMEMISTI: kullanici pine
                        //    dokunup adi goruyor, sonra balona basiyor ve
                        //    **HICBIR SEY OLMUYORDU**. Harita fiilen
                        //    DEKORATIFTI; isletmeye ulasmanin tek yolu alttaki
                        //    karti listede BULMAKTI (60 kayda kadar).
                        // ⚠️ `onTap` DEGIL `onInfoWindowTap`: pinin kendi
                        //    dokunusu balonu acmali (ad + mesafe), gezinme
                        //    ONAYLI eylem olmali — yanlislikla kaydirirken
                        //    ekran degistirmesin.
                        infoWindow: InfoWindow(
                          title: i.ad,
                          snippet: i.mesafeMetni,
                          onTap: () => acildi?.call(i),
                        ),
                      ),
                },
              )
            else ...[
              const ColoredBox(color: _zemin),
              CustomPaint(painter: _SehirCizer()),
              if (merkez != null)
                CustomPaint(
                  painter: _IgneCizer(merkez: merkez!, isletmeler: isletmeler),
                ),
            ],
            // Durust bilgi seridi.
            Positioned(
              left: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isletmeler.isEmpty
                      ? 'Konumun'
                      : '${isletmeler.length} işletme yakınında',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF3C3C43),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uber tarzi acik-gri sehir dokusu (yol agi + park + su).
///
/// ⚠️ Rastgelelik YOK: `Random` kullanilsaydi her cizimde farkli bir sehir
///    olusur ve kaydirmada TITRERDI. Desen deterministik bir formulden gelir.
class _SehirCizer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final su = Paint()..color = _su;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.72, 0)
        ..quadraticBezierTo(
          size.width * 0.86, size.height * 0.45,
          size.width * 0.78, size.height,
        )
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, 0)
        ..close(),
      su,
    );
    final park = Paint()..color = _yesil;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.06, size.height * 0.58,
            size.width * 0.22, size.height * 0.28),
        const Radius.circular(10),
      ),
      park,
    );

    final yol = Paint()
      ..color = _yol
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cizgi = Paint()
      ..color = _yolCizgi
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Yatay + dikey yol agi (kalinliklar degisken -> ana/ara yol hissi).
    for (var i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      yol.strokeWidth = i.isEven ? 9 : 5;
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.8, y), yol);
      canvas.drawLine(Offset(0, y), Offset(size.width * 0.8, y), cizgi);
    }
    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      if (x > size.width * 0.75) break;
      yol.strokeWidth = i == 2 ? 10 : 5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), yol);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), cizgi);
    }
  }

  @override
  bool shouldRepaint(_SehirCizer oldDelegate) => false;
}

/// Kullanici + isletme igneleri. Konumlar GERCEK koordinatlardan turer.
class _IgneCizer extends CustomPainter {
  _IgneCizer({required this.merkez, required this.isletmeler})
    : _adet = isletmeler.length;

  final ({double enlem, double boylam}) merkez;
  final List<IsletmeOzet> isletmeler;

  /// ⚠️ Uzunluk KURULUM ANINDA yakalanir — `shouldRepaint` icinde AYNI liste
  ///    nesnesinin uzunlugunu kendisiyle karsilastirmak DAIMA false doner
  ///    (turu 81b'de canli ses dalgasi tam bu yuzden hic cizilmemisti).
  final int _adet;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width / 2, size.height / 2);

    // En uzak isletme kenara denk gelsin diye olcek.
    var enUzak = 0.5;
    for (final i in isletmeler) {
      if (i.km > enUzak) enUzak = i.km;
    }
    final olcek = (math.min(size.width, size.height) / 2 - 26) / enUzak;

    final igne = Paint()..color = const Color(0xFF6C2BD9);
    for (final i in isletmeler) {
      if (i.enlem == 0 && i.boylam == 0) continue;
      // Kuzey yukari: enlem farki -Y, boylam farki +X (boylam cos ile daralir).
      final dy = (i.enlem - merkez.enlem) * 111.0;
      final dx = (i.boylam - merkez.boylam) *
          111.0 * math.cos(merkez.enlem * math.pi / 180);
      final p = o + Offset(dx * olcek, -dy * olcek);
      if (p.dx < 6 || p.dx > size.width - 6 ||
          p.dy < 6 || p.dy > size.height - 6) {
        continue;
      }
      canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, igne);
    }

    // Kullanici: mavi nokta + halka (harita uygulamalarinin ortak dili).
    canvas.drawCircle(o, 13, Paint()..color = const Color(0x333AA9FF));
    canvas.drawCircle(o, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(o, 5, Paint()..color = const Color(0xFF3AA9FF));
  }

  @override
  bool shouldRepaint(_IgneCizer eski) =>
      eski._adet != _adet ||
      eski.merkez.enlem != merkez.enlem ||
      eski.merkez.boylam != merkez.boylam;
}
