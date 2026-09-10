import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'urun_servisi.dart';

/// ⚠️⚠️⚠️ TURU 180ag — ISLETME KARTININ ALTINDAKI MENU SERIDI ICIN URUN
///	ONBELLEGI (kullanici emri: *"altina menuler gelsin, menu icinde resim
///	menu ismi ve fiyat"*).
///
/// **NEDEN AYRI BIR KATMAN GEREKTI:** liste ucu (`/isletmeler`,
/// `/isletmeler/yakinimda`) urun ADI ve GORSELI **DONDURMUYOR** — yalnizca
/// `urun_sayisi` ve `min_fiyat_kurus` tasiyor (turu 139'da olculdu ve o gun
/// bu yuzden kartta urun adi YAZILAMAMISTI). Menuyu cizmenin tek yolu
/// isletme basina `/users/{id}/urunler` cagirmak.
///
/// ⚠️⚠️ **BU BIR N+1'DIR VE BILEREK KABUL EDILDI** (turu 17'de kapatilan
///	sinif). Bedeli UC KATMANLA sinirlandi:
///	  1. **TEMBEL**: yalniz EKRANDA CIZILEN kart ister. `SliverList.builder`
///	     gorunmeyen karti kurmaz -> 60 kayitlik listede ~3-5 istek olur,
///	     60 degil.
///	  2. **SEMAFOR (4)**: es zamanli istek tavani. Yoksa hizli kaydirmada
///	     onlarca istek ayni anda cikip Dio havuzunu bogar ve ANA IZOLAT
///	     JSON cozumleriyle kilitlenirdi (turu 91'de olculdu).
///	  3. **TEK UCUS + ONBELLEK**: ayni isletme icin ikinci istek ATILMAZ;
///	     kart yeniden cizilse de (kaydirma, setState, filtre) veri
///	     onbellekten gelir.
///
/// ⚠️ **HATA ONBELLEGE YAZILMAZ**: gecici ag hatasi kaliciya donusmesin —
///	kart bir sonraki cizimde tekrar dener (turu 76 `kullanici_ozeti`
///	dersiyle ayni karar).
/// ⚠️ **OTURUM OMURLU**: `logout`ta temizlenir; baska hesapla girildiginde
///	eski isletmenin menusu gorunmemeli.
/// ⚠️ YAPMA: burayi `Future.wait` ile toplu cagriya cevirme — uc TEKIL
///	(`/users/{id}/urunler`), toplu bir karsiligi YOK; `Future.wait` yalnizca
///	semaforu ATLAR.
///
/// ⏳ **BACKEND TURU (bekleyen is):** `/isletmeler` ve `/isletmeler/yakinimda`
///	yanitlarina isletme basina **ILK 5 URUN** (ad · fiyat_kurus · ilk
///	media_id) eklenirse bu katmanin TAMAMI gereksizlesir ve N+1 kokten
///	kalkar. O gun burasi silinip `IsletmeOzet.urunler` okunur.
class UrunDeposu {
  UrunDeposu(this._ref);

  final Ref _ref;

  /// Cozulmus liste. Anahtar YOKSA "henuz sorulmadi" demektir.
  final Map<String, List<Urun>> _onbellek = {};

  /// Ucustaki istekler — ayni isletme icin IKINCI istek acilmaz.
  final Map<String, Future<List<Urun>>> _ucusta = {};

  /// ⚠️ Es zamanli istek tavani. Degeri degistirirsen sebebini yaz:
  ///	4, hizli kaydirmada gorunur olan kart sayisiyla (3-5) ayni buyuklukte
  ///	secildi — daha kucugu seridi gec doldurur, daha buyugu havuzu bogar.
  static const int _tavan = 4;
  int _acik = 0;
  final List<Completer<void>> _kuyruk = [];

  /// Onbellekteki deger (varsa) — cizim ANINDA istek ATMADAN okumak icin.
  List<Urun>? bak(String isletmeId) => _onbellek[isletmeId];

  Future<List<Urun>> coz(String isletmeId) {
    if (isletmeId.isEmpty) return Future.value(const []);
    final hazir = _onbellek[isletmeId];
    if (hazir != null) return Future.value(hazir);
    final ucus = _ucusta[isletmeId];
    if (ucus != null) return ucus;

    final is_ = _getir(isletmeId);
    _ucusta[isletmeId] = is_;
    // ⚠️ `whenComplete` HEM basarida HEM hatada calisir: bir kez patlayan
    //    kimlik SUREC BOYUNCA hatali Future'i paylasmasin (turu 91 dersi).
    is_.whenComplete(() => _ucusta.remove(isletmeId));
    return is_;
  }

  Future<List<Urun>> _getir(String isletmeId) async {
    await _slotAl();
    try {
      final l = await _ref.read(urunServisiProvider).liste(isletmeId);
      // ⚠️ MUSTERIYE YALNIZ 'yayinda' kalemler cizilir: sunucu silmeyi "soft
      //    delete" yapiyor (`durum='kaldirildi'`) ve listede DONDURMEYE
      //    devam ediyor (turu 178'de McDonald's kaydinda 18 yayinda / 24
      //    kaldirilmis olculdu).
      final gorunur = l.where((u) => u.durum == 'yayinda').toList()
        ..sort((a, b) => a.sira.compareTo(b.sira));
      _onbellek[isletmeId] = gorunur;
      return gorunur;
    } catch (_) {
      // ⚠️ ONBELLEGE YAZMA (bkz. sinif serhi).
      return const [];
    } finally {
      _slotBirak();
    }
  }

  Future<void> _slotAl() {
    if (_acik < _tavan) {
      _acik++;
      return Future.value();
    }
    final c = Completer<void>();
    _kuyruk.add(c);
    return c.future;
  }

  /// ⚠️ `finally` ICINDE cagrilir — sayac dusmezse kuyruk KALICI kilitlenir
  ///	ve menu seridi bir daha HIC dolmaz (turu 91'de aynen yasandi).
  void _slotBirak() {
    if (_kuyruk.isNotEmpty) {
      _kuyruk.removeAt(0).complete();
      return;
    }
    _acik--;
  }

  /// ⚠️ Cikista ZORUNLU.
  void temizle() {
    _onbellek.clear();
    _ucusta.clear();
    for (final c in _kuyruk) {
      if (!c.isCompleted) c.complete();
    }
    _kuyruk.clear();
    _acik = 0;
  }
}

final urunDeposuProvider = Provider<UrunDeposu>(UrunDeposu.new);
