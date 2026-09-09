import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ⚠️⚠️ TURU 81 — CIHAZ TERCIHLERI (tema, onboarding gorulme durumu).
///
/// ═══════════ NEDEN `AppStorage` DEGIL ═══════════
///
/// `AppStorage` **guvenli depo**dur (Keychain/Keystore) ve orada YALNIZ
/// oturum jetonu + kullanici kimligi durur. Tema tercihi ve "onboarding
/// gorulda mu" bilgisi SIR DEGILDIR; guvenli depoya yazmak
///   (a) her okumada kripto islemi demektir (acilis yolunda gereksiz gecikme),
///   (b) iOS'ta `first_unlock` oncesi `PlatformException` firlatir ve tema
///       okunamazsa uygulama YANLIS temada acilirdi.
/// ⚠️ YAPMA: bu iki degeri `AppStorage`a tasima.
///
/// ⚠️ `shared_preferences` ZATEN kurulu (^2.5.5) — yeni bagimlilik YOK.
class Tercihler {
  Tercihler(this._p);

  /// ⚠️ NULL OLABILIR: `SharedPreferences` acilamazsa uygulama YINE DE ACILIR
  ///    ve varsayilanlarla calisir. `late` bir alan birakilsaydi ilk erisimde
  ///    `LateInitializationError` ile ACILISTA COKERDI — tema tercihi ugruna
  ///    uygulamayi kaybetmek kabul edilemez.
  final SharedPreferences? _p;

  static const _kTema = 'tema_modu';
  static const _kOnboarding = 'onboarding_goruldu';
  static const _kHarita = 'harita_stili';
  static const _kSonAramalar = 'son_aramalar';
  static const _kYildizli = 'yildizli_mesajlar';
  static const _kTekAcilan = 'tek_kullanimlik_acilan';
  static const _kSohbetTema = 'sohbet_tema_';
  static const _kTakmaAd = 'takma_ad_';
  static const _kSureli = 'sureli_mesaj_';
  static const _kYazmaGostergesi = 'yazma_gostergesi';
  static const _kOkunduBilgisi = 'okundu_bilgisi';

  // ══════════════ TURU 180ab — SOHBET AYARLARI (CIHAZDA) ══════════════
  //
  // ⚠️⚠️⚠️ **BES AYARIN DA SUNUCUDA KARSILIGI YOK — OLCULDU** (backend
  //	grep, 9 Eyl): `nickname` 0 · `theme` 0 · `ephemeral` 0 ·
  //	`read_receipt` 0 · `restrict` 0 eslesme. Bu bir ARAYUZ TURU
  //	(CLAUDE.md kural 9) -> deger CIHAZDA tutulur, sunucuya GONDERILMEZ.
  // ⚠️ Her ekranda **DURUST SINIR** yaziliyor ("yalnızca bu cihazda") —
  //	sessizce yerelde tutup kullaniciya "ayarlandi" demek turu 135'te
  //	(uydurma kur seridi) reddedilen sinifin ta kendisi olurdu.
  // ⚠️ Anahtarlar **SOHBET/KISI BASINA** onekli: tek bir global deger
  //	kullanilsaydi bir sohbette secilen tema TUM sohbetlere yayilirdi.

  /// Sohbet balonu rengi anahtari ('varsayilan' · 'mor' · 'mavi' · ...).
  /// ⚠️ Bu ayar GERCEKTEN calisir (balon rengi cihazda cizilir); "yerel"
  ///	olmasi onu YALAN yapmaz — karsi tarafta gorunmedigi ekranda yazili.
  String sohbetTemasi(String chatId) =>
      _p?.getString('$_kSohbetTema$chatId') ?? 'varsayilan';

  Future<void> sohbetTemasiYaz(String chatId, String deger) async {
    if (deger == 'varsayilan') {
      await _p?.remove('$_kSohbetTema$chatId');
      return;
    }
    await _p?.setString('$_kSohbetTema$chatId', deger);
  }

  /// Kisiye verilen takma ad. Bos dize = takma ad YOK.
  String takmaAd(String peerId) =>
      _p?.getString('$_kTakmaAd$peerId') ?? '';

  Future<void> takmaAdYaz(String peerId, String ad) async {
    final t = ad.trim();
    if (t.isEmpty) {
      await _p?.remove('$_kTakmaAd$peerId');
      return;
    }
    // ⚠️ Tavan 40: sinirsiz birakilsaydi sohbet basligi ve liste satiri
    //	kirpilir, ustelik tercih dosyasi sisirdi.
    await _p?.setString('$_kTakmaAd$peerId', t.substring(0, min(40, t.length)));
  }

  /// Sureli mesaj secimi ('kapali' · 'goruldukten' · '24saat' · '7gun').
  /// ⚠️⚠️ **YALNIZ EKRANDA**: mesajin karsi tarafta da kaybolmasi SUNUCU
  ///	isi (`messages`ta sure sutunu YOK). Ekran bunu ACIKCA soyler.
  String sureliMesaj(String chatId) =>
      _p?.getString('$_kSureli$chatId') ?? 'kapali';

  Future<void> sureliMesajYaz(String chatId, String deger) async {
    if (deger == 'kapali') {
      await _p?.remove('$_kSureli$chatId');
      return;
    }
    await _p?.setString('$_kSureli$chatId', deger);
  }

  /// "Yazıyor…" gostergesi gonderilsin mi (GLOBAL).
  /// ⚠️ Bu ayar **GERCEKTEN CALISIR**: kapaliyken istemci WS `typing`
  ///	olayini HIC gondermez, yani karsi taraf gostergeyi GORMEZ.
  bool get yazmaGostergesi => _p?.getBool(_kYazmaGostergesi) ?? true;
  Future<void> yazmaGostergesiYaz(bool v) async =>
      _p?.setBool(_kYazmaGostergesi, v);

  /// Okundu bilgisi gonderilsin mi (GLOBAL).
  /// ⚠️⚠️ **YALNIZ EKRANDA**: `POST /chats/{id}/read` cagrisini kesmek
  ///	KENDI okunmamis rozetimizi de bozardi (ayni uc iki isi birden
  ///	yapiyor) — o ayrim SUNUCU isi. Ekran bunu ACIKCA soyler.
  bool get okunduBilgisi => _p?.getBool(_kOkunduBilgisi) ?? true;
  Future<void> okunduBilgisiYaz(bool v) async =>
      _p?.setBool(_kOkunduBilgisi, v);

  /// ⚠️ TURU 180y — acilmis "tek kullanimlik" fotograflar (media id).
  ///	Sunucuda karsiligi YOK; isaret CIHAZDA (bkz. `_TekKullanimlikBalon`).
  bool tekKullanimlikAcildiMi(String mediaId) =>
      (_p?.getStringList(_kTekAcilan) ?? const []).contains(mediaId);

  Future<void> tekKullanimlikAc(String mediaId) async {
    final l = _p?.getStringList(_kTekAcilan) ?? const <String>[];
    if (l.contains(mediaId)) return;
    await _p?.setStringList(_kTekAcilan, [mediaId, ...l].take(500).toList());
  }

  /// ⚠️⚠️⚠️ TURU 180y — **YILDIZLI MESAJLAR** (kullanici emri: *"mesaj
  ///	detaylarinda yildiz vs"*).
  ///
  /// ⚠️⚠️ **SUNUCUDA KARSILIGI YOK.** `messages` tablosunda yildiz/favori
  ///	sutunu YOK ve bu bir ARAYUZ TURU (backend'e dokunulmuyor). Bu yuzden
  ///	yildiz **CIHAZDA** tutuluyor: kullanici kendi telefonunda isaretini
  ///	gorur, uygulama kapanip acilsa bile durur.
  /// ⚠️ DURUST SINIR: yildiz **CIHAZA OZELDIR** — baska cihazda ya da
  ///	uygulama silinip kurulunca GORUNMEZ, karsi taraf HIC gormez.
  ///	⏳ Kalici cozum: `messages`a `starred_by UUID[]` (ya da ayri tablo)
  ///	   + iki uc. AYRI (backend) TUR.
  /// ⚠️ Anahtar `chatId:mesajId` — mesaj kimlikleri sohbet basina artan
  ///	tamsayilar; yalniz id saklamak FARKLI sohbetlerdeki ayni numarali
  ///	mesajlari birbirine karistirirdi.
  List<String> get yildizliMesajlar =>
      _p?.getStringList(_kYildizli) ?? const [];

  bool yildizliMi(String chatId, int mesajId) =>
      yildizliMesajlar.contains('$chatId:$mesajId');

  /// Yildizi ters cevirir ve YENI durumu doner.
  Future<bool> yildizCevir(String chatId, int mesajId) async {
    final anahtar = '$chatId:$mesajId';
    final l = [...yildizliMesajlar];
    final vardi = l.remove(anahtar);
    if (!vardi) l.insert(0, anahtar);
    // ⚠️ Tavan 500: liste sinirsiz buyurse tercih dosyasi sisirdi.
    await _p?.setStringList(_kYildizli, l.take(500).toList());
    return !vardi;
  }

  /// TURU 175 — **SON ARAMALAR** (kullanici emri: *"aramada en son
  /// arananlar ... olacak"*).
  ///
  /// ⚠️ **KALICI** (oturum omurlu DEGIL): "en son aradiklarim" ancak
  ///	uygulama kapanip acildiginda da duruyorsa o adi hak eder.
  ///	Turu 142'de menudeki arama sayfasi bunu oturum omurlu
  ///	tutuyordu ve her acilista BOS geliyordu.
  /// ⚠️ Depo acilamazsa bos liste doner — ozellik COKMEZ, yalnizca
  ///	hatirlamaz (`_p` null olabilir, bkz. sinif serhi).
  List<String> get sonAramalar => _p?.getStringList(_kSonAramalar) ?? const [];

  /// En basa ekler, tekrarlari eler, **en fazla 8** tutar.
  ///
  /// ⚠️ Tekilleme BUYUK/KUCUK HARF DUYARSIZ ve Turkce'ye gore: `toLowerCase`
  ///	'İ'yi birlesik noktaya cevirir ve "İSTANBUL" ile "istanbul"
  ///	AYRI kayit sayilirdi (turu 140'ta olculen tuzak). Karsilastirma
  ///	icin harfler ELLE sadelestirilir.
  Future<void> aramaEkle(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;
    String sade(String x) => x
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .trim();
    final anahtar = sade(t);
    final l = [t, ...sonAramalar.where((e) => sade(e) != anahtar)];
    await _p?.setStringList(_kSonAramalar, l.take(8).toList());
  }

  Future<void> aramaSil(String q) async {
    await _p?.setStringList(
        _kSonAramalar, sonAramalar.where((e) => e != q).toList());
  }

  Future<void> aramalariTemizle() async {
    await _p?.remove(_kSonAramalar);
  }

  /// ⚠️ TURU 89 — HARITA RENGI (kullanici emri: *"ayarlardan harita rengi
  ///    ayarlanmali, gece ve uberin gri beyaz tarzi"*).
  ///    Degerler: `'sistem'` | `'gri'` | `'gece'`.
  /// ⚠️ Tema deseninin BIREBIR kardesi — yeni bir saklama yolu ACILMADI.
  /// ⚠️ Varsayilan `'sistem'`: temaya uyar. Sabit bir renk secilseydi koyu
  ///    temadaki kullanicinin ekraninin %70'i parlak beyaz kalirdi.
  String get haritaStili => _p?.getString(_kHarita) ?? 'sistem';

  Future<void> haritaStiliYaz(String s) async {
    await _p?.setString(_kHarita, s);
  }

  /// 'sistem' | 'acik' | 'koyu'
  ///
  /// ⚠️⚠️⚠️ TURU 180x — **VARSAYILAN ARTIK KOYU** (`sistem` DEGIL).
  ///
  ///	GEREKCE (emulatorde olculdu): uygulamanin ana yuzeyleri turu 174'ten
  ///	beri `koyuSayfa` ile ZORLA SIYAH ciziliyor — anasayfa · yemek ·
  ///	kategori · profil · akis · reels · mesaj · ilan · hizmet · randevu.
  ///	Cihaz acik temadaysa GERIYE KALAN ekranlar (sohbet detayi, topluluk,
  ///	grup olustur, kisi arama, ayarlar) BEYAZ aciliyor ve kullanici siyah
  ///	bir akisin ortasinda goz alan beyaz sayfalara dusuyordu.
  /// ⚠️ Bu, o ekranlari TEK TEK `koyuSayfa` ile sarmaktan DAHA GUVENLI:
  ///	sarma yontemi her ekranda "State metodunun ciplak `context`i
  ///	Theme'in USTUNDE kalir" tuzagini yeniden acar (bu projede ONBIR kez
  ///	sahaya cikti). Tema modunu degistirmek o tuzagi YAPISAL OLARAK
  ///	yaratmaz.
  /// ⚠️ Kullanicinin SECIMI DAIMA USTUNDUR: Ayarlar > Tema'dan 'acik' ya da
  ///	'sistem' secilirse o yazilir ve burasi DEVREYE GIRMEZ.
  /// ⚠️ Acik tema SILINMEDI — `lightTheme` duruyor ve secilebilir.
  ThemeMode get temaModu => switch (_p?.getString(_kTema)) {
    'acik' => ThemeMode.light,
    'koyu' => ThemeMode.dark,
    'sistem' => ThemeMode.system,
    _ => ThemeMode.dark,
  };

  Future<void> temaYaz(ThemeMode m) async {
    await _p?.setString(_kTema, switch (m) {
      ThemeMode.light => 'acik',
      ThemeMode.dark => 'koyu',
      ThemeMode.system => 'sistem',
    });
  }

  /// ⚠️⚠️⚠️ IKI DURUM BIRBIRINDEN AYRILIR — ilk yazimda AYRILMAMISTI ve
  /// ozellik OLU DOGACAKTI:
  ///
  ///	`_p?.getBool(k) ?? true` ifadesi
  ///	  · "depo ACILAMADI"        (_p == null)      -> null
  ///	  · "anahtar HENUZ YAZILMADI" (temiz kurulum) -> null
  ///	durumlarinin IKISINI DE `true`ya cevirir. Ikincisi TAM OLARAK
  ///	onboarding'in GOSTERILMESI gereken durumdur — yani **temiz kurulumda
  ///	onboarding HIC ACILMAZDI** ve dort ekran yazilmis olmasina ragmen
  ///	kullanici onlari GORMEZDI ("olu ozellik" sinifinin bir ornegi daha).
  ///
  /// ⚠️ Depo YOKSA `true` doner (gosterme): bayrak YAZILAMAYACAGI icin
  ///    her acilista tekrar gosterilir ve kullanici uygulamaya HIC giremezdi.
  /// ⚠️ Depo VARSA ve anahtar yoksa `false` doner: onboarding GOSTERILIR.
  bool get onboardingGoruldu {
    final p = _p;
    if (p == null) return true;
    return p.getBool(_kOnboarding) ?? false;
  }

  Future<void> onboardingGorulduYaz() async {
    await _p?.setBool(_kOnboarding, true);
  }

  /// ⚠️⚠️ TURU 120 — TANITIMI YENIDEN GOSTER (kullanici emri: *"kullanici
  ///	girisine bir SIFIRLAMA butonu koy ... onboarding bitince bir daha
  ///	cikmiyor"*).
  ///
  /// ⚠️ `setBool(false)` DEGIL **`remove`**: anahtar hic yazilmamis hale
  ///    doner, yani TEMIZ KURULUMLA BIREBIR ayni durum olusur. `false`
  ///    yazmak ayni sonucu verirdi ama iki farkli "gosterilmeli" temsili
  ///    (anahtar yok / anahtar false) dogar ve `onboardingGoruldu`
  ///    okuyucusunun iki dali test edilmemis kalirdi.
  /// ⚠️ Yalnizca CIHAZ tercihini siler — hesaba, oturuma, sunucuya DOKUNMAZ.
  Future<void> onboardingSifirla() async {
    await _p?.remove(_kOnboarding);
  }
}

/// ⚠️ Acilista BIR KEZ kurulur ve `main()` icinde `await` edilir.
///
/// ⚠️⚠️ NEDEN `FutureProvider` DEGIL: tema ve onboarding kararinin
///    `MaterialApp` kurulurken HAZIR olmasi gerekir. `FutureProvider`
///    kullanilsaydi ilk kare varsayilan (koyu) temayla cizilir, sonra
///    tercih gelince ekran ANIDEN degisirdi ("tema atlamasi").
Tercihler tercihler = Tercihler(null);

/// ⚠️ ISTISNA FIRLATMAZ — cagirani `try` ile sarmalamak GEREKMEZ.
Future<void> tercihleriYukle() async {
  try {
    tercihler = Tercihler(await SharedPreferences.getInstance());
  } catch (_) {
    tercihler = Tercihler(null);
  }
}

/// Secili tema modu. Ayarlar ekrani bunu degistirir, `main.dart` dinler.
///
/// ⚠️ Baslangic degeri DISKTEN gelir (yukarida `late` alan `main()`de dolduruldu),
///    yani ilk kare DOGRU temayla cizilir.
class TemaNotifier extends StateNotifier<ThemeMode> {
  TemaNotifier() : super(tercihler.temaModu);

  Future<void> ayarla(ThemeMode m) async {
    state = m;
    await tercihler.temaYaz(m);
  }
}

final temaProvider = StateNotifierProvider<TemaNotifier, ThemeMode>(
  (ref) => TemaNotifier(),
);

/// Harita rengi tercihi — `TemaNotifier`in birebir kardesi.
///
/// ⚠️ Baslangic degeri DISKTEN gelir: aksi halde harita once bir stille
///    acilip sonra otekine ATLARDI (tema serhindeki "tema atlamasi" gerekcesi).
class HaritaStiliNotifier extends StateNotifier<String> {
  HaritaStiliNotifier() : super(tercihler.haritaStili);

  Future<void> ayarla(String s) async {
    state = s;
    await tercihler.haritaStiliYaz(s);
  }
}

final haritaStiliProvider = StateNotifierProvider<HaritaStiliNotifier, String>(
  (ref) => HaritaStiliNotifier(),
);
