import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/push.dart';
import '../../core/storage.dart';
import '../../core/ws.dart';
import '../calls/active_call_controller.dart';
import '../calls/medya_beklet.dart'; // turu 73b: SesSahipligi.sifirla
import '../medya/kullanici_ozeti.dart'; // turu 76: kimlik->avatar onbellegi
import '../medya/medya_gorsel.dart'; // turu 74b: adres onbellegi
import '../calls/callkit_service.dart';

/// Oturum durumu: null = kontrol ediliyor, '' = cikis yapilmis, dolu = girisli
class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final token = await _ref.read(storageProvider).token;
    if (token == null || token.isEmpty) {
      state = '';
      return;
    }
    // Token'i backend'e DOGRULAT. Her surumde `TRUNCATE users` yapildigi icin
    // cihazda kalan token BAYAT olabilir; dogrulamadan "girisli" gostermek,
    // kilit ekranindan kabul edilen aramada answer'i 401'e dusuruyordu (ekran
    // acilmiyor, sonra ilk normal istekte login'e atiyordu -> "sifre soruyor").
    // /users/me kullaniyoruz (/calls/ 401 muafiyeti burada gecerli DEGIL).
    try {
      await _ref.read(apiProvider).get('/users/me');
      state = token;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _ref.read(storageProvider).clear(); // bayat token temizle
        state = '';
      } else {
        state = token; // ag hatasi: cevrimdisi kullaniciyi disari atma
      }
    }
  }

  /// Kayit baslat — dev modda OTP kodu doner (SMS yerine)
  Future<String?> register(
      String phone, String password, String name, String username) async {
    final res = await _ref.read(apiProvider).post('/auth/register', data: {
      'phone': phone,
      'password': password,
      'name': name,
      'username': username,
    });
    return res.data['dev_otp'] as String?;
  }

  // ══════════════ TURU 84 — ADIMLI KAYIT (telefon -> OTP -> bilgiler) ═══════
  //
  // ⚠️ ESKI `register`/`verify` cifti SILINMEDI: sunucuda o uclar duruyor ve
  //    "sifre sifirlama" akisi hala `verify` mantigini paylasiyor.
  //    Yeni akis AYRI uclar kullanir (`/auth/kayit/...`).

  /// ADIM 1 — telefonu gonder, SMS kodu iste. Dev modda kod doner.
  ///
  /// ⚠️ HESAP OLUSTURULMAZ. Eski `register`in aksine burada yalnizca kod gider;
  ///    boylece kullanici kisisel bilgileri EN SONDA doldurur.
  Future<String?> kayitTelefon(String phone) async {
    final res = await _ref
        .read(apiProvider)
        .post('/auth/kayit/telefon', data: {'phone': phone});
    return res.data['dev_otp'] as String?;
  }

  /// ADIM 2 — kodu dogrula, KAYIT JETONU al.
  ///
  /// ⚠️ Oturum ACILMAZ (hesap henuz yok). Donen jeton yalnizca "bu telefon
  ///    dogrulandi" demektir ve 15 dakika gecerlidir.
  Future<String> kayitDogrula(String phone, String code) async {
    final res = await _ref
        .read(apiProvider)
        .post('/auth/kayit/dogrula', data: {'phone': phone, 'code': code});
    return (res.data['kayit_jetonu'] ?? '').toString();
  }

  /// ADIM 3 — hesabi olustur, OTURUM AC.
  Future<void> kayitTamamla({
    required String jeton,
    required String name,
    required String username,
    required String password,
  }) async {
    final res = await _ref.read(apiProvider).post(
      '/auth/kayit/tamamla',
      data: {
        'kayit_jetonu': jeton,
        'name': name,
        'username': username,
        'password': password,
      },
    );
    await _saveSession(res.data);
  }

  /// OTP dogrula — basarili olursa oturum acilir (test modu)
  Future<void> verify(String phone, String code) async {
    final res = await _ref.read(apiProvider).post('/auth/verify', data: {
      'phone': phone,
      'code': code,
    });
    await _saveSession(res.data);
  }

  // NOT: Firebase Phone Auth KALDIRILDI — magaza disi kurulumlarda iOS'ta cokuyor,
  // Android'de tarayiciya (reCAPTCHA) atiyordu. SMS'i artik kendi sunucumuz gonderiyor.

  Future<void> login(String phone, String password) async {
    final res = await _ref.read(apiProvider).post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    await _saveSession(res.data);
  }

  /// Sifre sifirlama kodu iste — dev modda kod doner
  Future<String?> forgot(String phone) async {
    final res = await _ref.read(apiProvider).post('/auth/forgot', data: {'phone': phone});
    return res.data['dev_otp'] as String?;
  }

  Future<void> reset(String phone, String code, String newPassword) async {
    await _ref.read(apiProvider).post('/auth/reset', data: {
      'phone': phone,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<void> logout() async {
    // C5: MINIMIZE'DAKI ARAMAYI BITIR — minimize cikisi mumkun kildi; aramayi sunucuda
    // dusurmeden cikilirsa karsi taraf sonsuz bekler (yeni acilan kenar durumu).
    // TARAMA #12: timeout SART — ag yokken end() 3 deneme ~30sn surer, cikis butonu
    // donardi. Timeout asilirsa leave arka planda surer (end retry'li), cikis HEMEN.
    try {
      final ctrl = _ref.read(activeCallProvider);
      if (ctrl.arama != null) {
        await ctrl.leave(notifyServer: true).timeout(const Duration(seconds: 3));
      }
    } catch (_) {}
    // ⚠️ TURU 73b — iOS ses-sahipligi defterini SIFIRLA (statik kume proses omrunu
    //     paylasir). Sizan tek bir kayit, sonraki oturumda odadan/yayindan cikinca
    //     ses biriminin BIR DAHA kapanmamasina yol acar (mikrofon gostergesi sonmez).
    SesSahipligi.sifirla();
    medyaAdresOnbelleginiTemizle(); // turu 74b: imzali adresler bellekte kalmasin
    // TURU 76: kimlik->avatar onbellegi (baska hesapla girilince eski
    //   avatarlar gorunmemeli).
    _ref.read(ozetDeposuProvider).temizle();
    // ONCE oturumu kapat: state='' -> router ANINDA /login'e gider. Boylece
    // butona basinca cikis HEMEN gerceklesir; temizlik adimlarindan biri hata
    // verse bile kullanici disari cikmis olur (eskiden ws.close throw ederse
    // yarida kalip cikamiyordu).
    state = '';
    // Bu cihazin push token'ini sunucudan sil (yeni giren kullanici oncekinin
    // bildirimlerini almasin) — hata olsa da cikis tamamlanir.
    try {
      await _ref.read(pushProvider).unregister();
    } catch (_) {}
    try {
      await _ref.read(wsProvider).close();
    } catch (_) {}
    try {
      await _ref.read(storageProvider).clear();
    } catch (_) {}
    // TARAMA #11 (kritik): wsProvider'i INVALIDATE ETME. CallService/DavetServisi
    // singleton'lari constructor'da BU WsService'in broadcast stream'ine abone —
    // invalidate yeni instance yaratir, aboneler OLU stream'de kalir ve relogin
    // sonrasi gelen arama/davet HIC islenmezdi. close() soketi kapatir ama stream'i
    // KAPATMAZ; login'deki connect() _closed=false ile ayni instance'i canlandirir.
    _ref.invalidate(pushProvider);
  }

  /// ⚠️⚠️⚠️ TOLERANSLI OKUMA — KATI HALI **SEVK ENGELIYDI**.
  ///
  ///	Onceden `data['user_id'] as String` yaziyordu. Turu 84'un yeni
  ///	`/auth/kayit/tamamla` ucu ise `{"token", "user": {"id": ...}}`
  ///	donduruyordu — yani `user_id` YOKTU. Sonuc: `null as String` ->
  ///	**TypeError**, jeton diske HIC yazilmiyor, `state` degismiyor ve
  ///	**KAYIT AKISI ASLA TAMAMLANMIYORDU** (hesap sunucuda olusuyor,
  ///	kullanici jenerik hata goruyor).
  ///
  /// ⚠️ Sunucu tarafi da duzeltildi (`user_id` eklendi), AMA bu tolerans
  ///    KALIR: yanit anahtari drifti bir daha SESSIZ bir cokmeye donusmesin.
  /// ⚠️ Jeton BOSSA acikca hata firlatilir — sessizce "girisli" saymak
  ///    kullaniciyi 401 dongusune sokardi.
  /// ⚠️ YAPMA: buray tekrar kati `as String` haline dondurme.
  Future<void> _saveSession(dynamic data) async {
    final token = (data['token'] ?? '').toString();
    if (token.isEmpty) {
      throw StateError('sunucu oturum jetonu dondurmedi');
    }
    final userId =
        (data['user_id'] ?? (data['user'] is Map ? data['user']['id'] : null) ?? '')
            .toString();
    await _ref.read(storageProvider).saveSession(token, userId);
    state = token;
    // Push/VoIP token'ini HEMEN kaydet (router rebuild'ini bekleme). Yeni hesapta ilk
    // aramanin karsi tarafa gitmesi token'in DB'de olmasina bagli. fire-and-forget:
    // register() retry'li ve sn surebilir; kullaniciyi girise sokarken bekletme.
    unawaited(_ref.read(pushProvider).register());
    unawaited(CallKitService.instance.voipTokeniYenidenGonder());
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, String?>(AuthNotifier.new);

/// Girisli kullanicinin id'si (senkron erisim icin ayrica tutulur)
final myUserIdProvider = FutureProvider<String?>((ref) async {
  ref.watch(authProvider); // oturum degisince yenile
  return ref.read(storageProvider).userId;
});
