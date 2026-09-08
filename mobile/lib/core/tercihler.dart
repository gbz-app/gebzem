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
