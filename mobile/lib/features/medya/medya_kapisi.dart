import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calls/call_provider.dart';
import 'medya_servisi.dart' show kTavanlar;
import '../calls/medya_beklet.dart' show SesSahipligi;
import '../calls/pip_service.dart';
import '../../router.dart' show rootMessengerKey;

/// ⚠️⚠️⚠️ TURU 74 — MEDYA ÇAKIŞMA KAPISI. **BU DOSYAYI OKUMADAN MEDYA KODU YAZMA.**
///
/// Bu uygulamada aynı anda 1:1 arama, sesli oda ya da canlı yayın olabilir. iOS'ta:
///   · Ses birimi `RTCAudioSession.isAudioEnabled` **PROSES GENELİNDE TEK** bayraktır,
///   · flutter_webrtc **TEK PAYLAŞILAN `videoCapturer`** tutar.
/// Bu yüzden sohbette kamera açmak ya da ses kaydetmek, SÜREN bir aramayı/yayını
/// öldürebilir. Proje bunu 70+ turda defalarca yaşadı:
///   · turu 50 — iki capture oturumu birbirini öldürdü, aramaların **%14'ünde**
///     tek taraflı video (9/9 iOS).
///   · turu 64/65 — ses oturumunu geri alma denemesi `!pri`
///     (`AVAudioSessionErrorCodeInsufficientPriority`) ile REDDEDİLDİ.
///   · turu 62-C — Android'de ses rotası bozulup hoparlöre atladı.
///
/// KARAR TABLOSU (araştırma + denetim sonucu):
/// | İşlem                     | Arama/oda/yayın sürerken |
/// |---------------------------|--------------------------|
/// | Galeriden seçme           | SERBEST (kamera/mikrofona dokunmaz) |
/// | **Kamerayla çekim**       | **ENGELLİ** |
/// | **Ses notu kaydı**        | **ENGELLİ** |
/// | **Ses notu oynatma**      | **ENGELLİ** |
/// | Fotoğraf görüntüleme      | SERBEST |
/// | Sıkıştırma / yükleme      | SERBEST (saf CPU / ağ) |
///
/// ⚠️ İKİ KAYNAK BİRDEN SORULUR, biri yetmez:
///   · `SesSahipligi` — gerçekten bağlı bir arama/oda/yayın var mı (turu 73 defteri).
///     ⚠️ Tek başına ÇALMA fazını kaçırır (arama henüz bağlanmadı ama zil çalıyor).
///   · `mesgulMu` — ekranda bir arama/oda/yayın muhafızı var mı (çalma fazı dahil).
///     ⚠️ Tek başına bayat muhafız yüzünden yanlış pozitif verebilir.
///   · `PipService.gsmAramada` — hücresel görüşme sürüyor mu.
/// ⚠️ YAPMA: bu üçünden birini çıkarma.
/// ⚠️ YAPMA: bu mantığı çağıran yerlere kopyalama — TEK KAYNAK burasıdır.
class MedyaKapisi {
  MedyaKapisi._();

  /// ⚠️⚠️ TURU 74b (DENETİM BULGUSU) — SİSTEM PICKER'I AÇIK MI?
  ///
  /// Galeri/kamera picker'ı AYRI SÜREÇTE çalışır ve donanımı bizden ÇALMAZ —
  /// ama **uygulamayı arka plana atar** ve BİZİM kendi yaşam döngüsü kodumuz
  /// bunu "kullanıcı uygulamadan çıktı" sanıp:
  ///   · `active_call_controller` görüntülü aramanın KAMERASINI KAPATIR
  ///     (PiP kuruluysa 900 ms sonra, değilse ANINDA),
  ///   · dönüşte `_kesintidenTopla` → `_sesiAc(true)` ile ses birimini
  ///     ZORLA TOGGLE eder (~50-150 ms sağırlık),
  ///   · oda/yayın ekranları da `resumed` dalında `_sesiAc(true)` çağırır.
  /// Sonuç: görüntülü arama sürerken galeriden fotoğraf seçen kullanıcının
  /// karşı tarafı **donmuş/kapalı kamera** görürdü.
  ///
  /// Bu bayrak "arka plana geçiş GERÇEK Mİ" ayrımını sağlar; picker yüzünden
  /// olan geçişlerde kamera/ses yıkımı ATLANIR.
  /// ⚠️ `try/finally` ile SET/RESET edilmeli — picker iptal edilse bile bayrak
  ///     asılı kalmamalı (asılı kalırsa gerçek arka plan geçişinde kamera
  ///     kapanmaz ve iOS kesintisi yaşanır).
  static bool pickerAcik = false;

  /// ⚠️⚠️ İKİ AYRI METOT VAR — KARIŞTIRMA:
  ///
  ///   · [donanimSerbest] — **YAN ETKİSİZ**. `build()` içinden, her karede
  ///     çağrılabilir (kamera satırını gizlemek için).
  ///   · [izinVer] — **YAN ETKİLİ**. Yalnızca kullanıcı DOKUNDUĞUNDA çağrılır.
  ///
  /// Neden ayrı: `mesgulMu` bayat muhafızları TEMİZLER ve Sentry'e ölçüm yazar
  /// (turu 56 self-heal). `build()` içinden çağrılırsa her karede çalışır ve
  /// Sentry'i doldurur. Bu yüzden yan etkili kontrol yalnızca aksiyon yolundadır.
  /// ⚠️ YAPMA: `izinVer`i `build()` içinde çağırma.
  /// ⚠️ YAPMA: `donanimSerbest`e `mesgulMu` ekleme.
  static bool donanimSerbest(WidgetRef ref) {
    if (PipService.gsmAramada.value) return false;
    if (SesSahipligi.aramaCanli) return false;
    // Oda/yayın da donanımı tutar (SesSahipligi'nde `oda_`/`yayin_` önekiyle kayıtlı).
    if (SesSahipligi.odaVeyaYayinCanli) return false;
    // ⚠️ Çalma fazı: arama henüz bağlanmadı (SesSahipligi'ne girmedi) ama zil çalıyor.
    //    Ham `aramadaMi` yan etkisizdir — self-heal YAPMAZ.
    if (ref.read(callServiceProvider.notifier).aramadaMi) return false;
    return true;
  }

  /// Neden engelli olduğunu kullanıcıya anlatan metin (null = engel yok).
  static String? engelSebebi(WidgetRef ref) {
    if (donanimSerbest(ref)) return null;
    if (PipService.gsmAramada.value) {
      return 'Telefon görüşmeniz sürerken kullanılamaz.';
    }
    if (SesSahipligi.odaVeyaYayinCanli) {
      return 'Sohbet odası veya canlı yayın sürerken kullanılamaz.';
    }
    return 'Görüşme sürerken kullanılamaz.';
  }

  /// Engelliyse kullanıcıya söyler ve `false` döner. **YAN ETKİLİ** — yalnızca
  /// kullanıcı dokunduğunda çağrılır (bkz. [donanimSerbest] şerhi).
  /// ⚠️ `rootMessengerKey`: bu çağrı bir bottom sheet içinden gelebilir ve
  ///     `ScaffoldMessenger.of(context)` sheet kapanınca ölü bağlamda kalır.
  static bool izinVer(WidgetRef ref) {
    // ⚠️ Aksiyon yolunda `mesgulMu` DA sorulur: bayat muhafızları temizler
    //     (turu 56 self-heal) ve gerçek durumu söyler. Yan etkisi burada KABUL
    //     EDİLEBİLİR çünkü kare başına değil, dokunuş başına çalışır.
    if (ref.read(callServiceProvider.notifier).mesgulMu(etiket: 'medya')) {
      rootMessengerKey.currentState?.showSnackBar(const SnackBar(
        content: Text('Görüşme sürerken kullanılamaz.'),
        duration: Duration(seconds: 3),
      ));
      return false;
    }
    final sebep = engelSebebi(ref);
    if (sebep == null) return true;
    rootMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(sebep), duration: const Duration(seconds: 3)),
    );
    return false;
  }
}

/// ⚠️⚠️⚠️ TURU 77b — COKLU GORSEL SECIMI ICIN **TEK KAYNAK** (denetim bulgusu).
///
/// **SORUN:** `ImagePicker().pickMultiImage(limit: kalan)` cagrisi UC ekranda
/// birebir kopyalanmisti (gonderi olustur / kanal / ilan ver) ve UCUNDE de
/// `catch` hatayi YUTUYORDU. `image_picker` paketi `limit < 2` icin
/// **`ArgumentError` FIRLATIR**
/// (`multi_image_picker_options.dart`: *"cannot be lower than 2"*).
///
/// Sonuc: tavanin BIR ALTINA gelindiginde (gonderide 9., kanalda 9., ilanda
/// 11. gorselden sonra) "Fotoğraf ekle" dugmesi **SESSIZCE OLUYORDU** —
/// kullanici basiyor, hicbir sey olmuyor, hicbir mesaj cikmiyor. Araba/emlak
/// ilaninda 11 fotograf tamamen normaldir.
///
/// **IKINCI TUZAK:** paket dokumanina gore `limit` platformlarca **YOK
/// SAYILABILIR**. Android'de kullanici 30 fotograf secerse istemci 30 medya
/// YUKLER, sunucu 12'ye kirpar ve geriye **18 YETIM YUKLEME** kalir. Bu yuzden
/// `take(kalan)` ZORUNLU — `limit` bir istektir, GARANTI DEGILDIR.
///
/// ⚠️ YAPMA: `pickMultiImage`i ekranlarda dogrudan cagirma.
/// ⚠️ YAPMA: `take(kalan)` kirpmasini kaldirma.
/// ⚠️⚠️⚠️ TURU 180z — BELGE UZANTILARI **TEK KAYNAK**.
///
/// Sunucunun `media/sniff.go` beyaz listesi PDF · DOC · DOCX · XLS ·
/// XLSX · TXT diyor; bu liste **DAHA DAR** ve gerekcesi CANLI SUNUCUDA
/// OLCULDU:
///   · **txt CIKARILDI** — commit asamasindaki icerik kokulamasi
///     (`GercekTip`) duz metnin imzasi olmadigi icin onu TANIYAMIYOR ve
///     **422 "dosya turu taninamadi"** donuyor.
///   · **xls CIKARILDI** — OLE kabi `application/msword` olarak
///     kokulaniyor, beyan `application/vnd.ms-excel` ->
///     **422 "beyanla uyusmuyor"**.
/// Ikisini de listede biraksaydik kullanici dosyayi SECER, YUKLER ve en
/// SONDA reddedilirdi — turu 66b'nin "gorunen ama calismayan dugme"
/// dersinin en pahali hali.
/// ⏳ BACKEND TURU: `GercekTip`e text/plain dali + .xls OLE esdegerligi
///    (audio/video mp4 icin ZATEN var olan desen).
/// ⚠️ Bu liste ile [MedyaSecici.belgeMime] AYRISAMAZ: biri digerini
///    tanimadiginda yukleme sunucuda 415 ile duser.
const kBelgeUzantilari = <String>['pdf', 'doc', 'docx', 'xlsx'];

class MedyaSecici {
  MedyaSecici._();

  /// [kalan] kac gorsel daha eklenebilir. 0/negatifse secici HIC ACILMAZ.
  /// Donen liste EN FAZLA [kalan] eleman tasir.
  static Future<List<XFile>> coklu(int kalan) async {
    if (kalan <= 0) return const [];
    List<XFile> secim = const [];
    try {
      MedyaKapisi.pickerAcik = true;
      secim = await ImagePicker().pickMultiImage(
        // ⚠️ `limit: 1` GECERSIZ (ArgumentError). Tek gorsel kaldiysa sinirsiz
        //    ac ve donusu `take(1)` ile kirp — davranis kullanici icin AYNI.
        limit: kalan >= 2 ? kalan : null,
      );
    } catch (e) {
      unawaited(Sentry.captureMessage('coklu gorsel secici hatasi: $e'));
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    return secim.take(kalan).toList();
  }

  /// ⚠️⚠️ TURU 78 — VIDEO SECIMI **TEK KAYNAK** (boyut + SURE kapisi dahil).
  ///
  /// Ayni zincir `gonderi_olustur.dart`ta yaziliydi; ilan/etkinlik icin ikinci
  /// kez yazilsaydi iki kopya KACINILMAZ olarak drift ederdi (bu projede ALTI
  /// kez yasandi). Ozellikle SURE OLCUMU kritik: yanlis kopyalanirsa bir yerde
  /// 5 dakikalik, otekinde sinirsiz video kabul edilirdi.
  ///
  /// Donen `null` = kullanici vazgecti YA DA dosya reddedildi (sebep zaten
  /// [uyar] ile gosterildi).
  ///
  /// ⚠️ `maxDuration` GALERI secimlerinde YOK SAYILIR (image_picker upstream
  ///    davranisi: yalnizca KAMERA cekiminde uygulanir). Bu yuzden sure
  ///    ASAGIDA KENDIMIZ olculur; parametre yine de veriliyor (kamera yolunda
  ///    ise yarar).
  /// ⚠️ Olcum BASARISIZ olursa video REDDEDILMEZ — sunucunun bayt tavani son
  ///    savunma olarak kalir. Sessiz reddetmek, kullanicinin sebebini
  ///    anlayamayacagi bir duvar olurdu.
  static Future<File?> video({
    required Duration sureTavani,
    required void Function(String) uyar,
    WidgetRef? ref,
  }) async {
    XFile? x;
    var hata = false;
    try {
      MedyaKapisi.pickerAcik = true;
      x = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: sureTavani,
      );
    } catch (e) {
      hata = true;
      unawaited(Sentry.captureMessage('video secici hatasi: $e'));
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    // ⚠️⚠️ TURU 78b — SECICI PATLARSA KULLANICIYA SOYLENIR (denetim bulgusu).
    //    Eskiden istisna yalnizca Sentry'e yazilip `null` donuluyordu ve TUM
    //    cagiranlar `null`i "kullanici vazgecti" sayip SESSIZCE cikiyordu:
    //    "Video" dugmesi hicbir sey soylemeden OLU gorunurdu. Bu, turu 77b'de
    //    `pickMultiImage(limit:1)` ile YASANAN hatanin ayni sinifi.
    if (hata) {
      uyar('Video seçici açılamadı, tekrar deneyin');
      return null;
    }
    if (x == null) return null;

    final dosya = File(x.path);
    // ⚠️ BOYUT KAPISI (sunucu tavaniyla AYNI). Sunucu da reddeder ama kullanici
    //    100 MB'lik dosyayi bosuna yuklemeye baslamasin.
    final bayt = await dosya.length();
    final tavan = kTavanlar['video'] ?? (100 << 20);
    if (bayt > tavan) {
      uyar('Video çok büyük (en fazla ${(tavan / (1 << 20)).round()} MB)');
      return null;
    }

    final sure = await videoSuresi(dosya, ref);
    if (sure != null && sure > sureTavani) {
      // ⚠️⚠️ TURU 78b — SURE METNI TAM SAYI BOLMESIYLE YANLIS CIKIYORDU
      //    (denetim bulgusu). Reels tavani `Duration(seconds: 90)`;
      //    `inMinutes` TAM SAYI bolmesi yapip **1** dondurdugu icin mesaj
      //    "Video en fazla 1 dakika olabilir" diyordu. Kullanici 75 saniyelik
      //    videoyu "1 dakikayi asiyor" diye kirpiyor, sonra 90 saniyeye kadar
      //    izin oldugunu ogrenemiyordu.
      // ⚠️ Artik yalniz TAM DAKIKA ise dakika yazilir; aksi halde saniye.
      final sn = sureTavani.inSeconds;
      uyar(
        sn % 60 == 0
            ? 'Video en fazla ${sn ~/ 60} dakika olabilir'
            : 'Video en fazla $sn saniye olabilir',
      );
      return null;
    }
    return dosya;
  }

  /// ⚠️⚠️⚠️ TURU 180z — **BELGE SECICI** (kullanici emri: *"kanalda sadece
  /// gorsel degil video BELGE vs de paylasiliyor"*).
  ///
  /// ⚠️⚠️ **UZANTI BEYAZ LISTESI SUNUCUDAN TURETILIR, ICAT EDILMEZ.**
  ///	`media/sniff.go` `document` icin TAM SU MIME'lari kabul ediyor:
  ///	  application/pdf · application/msword ·
  ///	  ...wordprocessingml.document · application/vnd.ms-excel ·
  ///	  ...spreadsheetml.sheet · text/plain
  ///	Daha genis bir liste sunmak (zip/apk/ppt) kullaniciya dosya
  ///	sectirip yuklemenin SONUNDA sunucudan 415 aldirirdi — turu 66b'nin
  ///	"gorunen ama calismayan dugme" dersinin en pahali hali (dosya
  ///	secildi, sikistirildi, yuklendi, sonra reddedildi).
  /// ⚠️ `withData: false` ZORUNLU: 32 MB'lik bir PDF'i BELLEGE okumak dusuk
  ///	bellekli Android'de uygulamayi OLDURUR (turu 76'daki `readAsBytes`
  ///	dersi). Yukleme zinciri zaten `dosya.openRead()` ile akitiyor.
  /// ⚠️ `pickerAcik` bayragi ZORUNLU: galeri/dosya secici acikken gelen
  ///	arama ekrani ile cakismayi `MedyaKapisi` bu bayrakla onluyor.
  static Future<File?> belge({
    required void Function(String) uyar,
  }) async {
    XFile? sonuc;
    var hata = false;
    try {
      MedyaKapisi.pickerAcik = true;
      // ⚠️⚠️ `file_picker` DEGIL `file_selector` (Flutter ekibinin RESMI
      //	paketi): `file_picker` **compileSdk 34** ile geliyor ve bu
      //	projede Gradle'i `checkDebugAarMetadata` ile PATLATTI
      //	(`flutter_plugin_android_lifecycle` 36 istiyor — turu 87'nin
      //	birebir tekrari). `file_selector_android` ise
      //	`compileSdk = flutter.compileSdkVersion` kullaniyor, yani
      //	catismasi YAPISAL OLARAK imkansiz.
      //	⚠️ YAPMA: `file_picker`a geri donme.
      sonuc = await openFile(acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Belge',
          extensions: kBelgeUzantilari,
          // ⚠️ iOS/macOS uzantiyi DEGIL UTI'yi ister; verilmezse secici
          //	HER dosyayi gosterir ve kullanici sunucunun reddedecegi bir
          //	tur secebilirdi.
          uniformTypeIdentifiers: <String>[
            'com.adobe.pdf',
            'com.microsoft.word.doc',
            'org.openxmlformats.wordprocessingml.document',
            'org.openxmlformats.spreadsheetml.sheet',
          ],
          mimeTypes: <String>[
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ],
        ),
      ]);
    } catch (e) {
      hata = true;
      unawaited(Sentry.captureMessage('belge secici hatasi: $e'));
    } finally {
      MedyaKapisi.pickerAcik = false;
    }
    // ⚠️ Secici PATLARSA kullaniciya SOYLENIR (video dalindaki ayni ders):
    //	sessiz `null` donmek dugmeyi OLU gosterirdi.
    if (hata) {
      uyar('Dosya seçici açılamadı, tekrar deneyin');
      return null;
    }
    final yol = sonuc?.path;
    if (yol == null) return null;

    final dosya = File(yol);
    final bayt = await dosya.length();
    final tavan = kTavanlar['document'] ?? (32 << 20);
    if (bayt > tavan) {
      uyar('Dosya çok büyük (en fazla ${(tavan / (1 << 20)).round()} MB)');
      return null;
    }
    // ⚠️ 0 baytlik dosya: sunucu `Content-MD5` dogrulamasindan gecer ama
    //	karsi tarafta acilmayan bir ek birakir.
    if (bayt <= 0) {
      uyar('Dosya boş görünüyor');
      return null;
    }
    return dosya;
  }

  /// Bir dosya adindan sunucunun bekledigi MIME'i turetir.
  ///
  /// ⚠️⚠️ Sunucu MIME'i **ISTEMCININ BEYANIYLA** karsilastiriyor
  ///	(`TipIzinli(kind, mime)`) ve imzaya da o MIME giriyor — yanlis
  ///	beyan R2'de **403 SignatureDoesNotMatch** ya da sunucuda 415 uretir.
  /// ⚠️ Bilinmeyen uzanti `application/octet-stream` DONDURMEZ: o tur beyaz
  ///	listede YOK ve istek 415 ile reddedilirdi. Uzanti listesi
  ///	`belge()` seciciyle AYNI kaynaktan gelmeli.
  static String belgeMime(String dosyaAdi) {
    final n = dosyaAdi.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.doc')) return 'application/msword';
    if (n.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (n.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    // ⚠️ Buraya DUSMEK, secicinin beyaz listesiyle bu haritanin
    //	AYRISTIGI anlamina gelir. `text/plain` sunucuda 422 aliyor;
    //	varsayilan PDF: en azindan kokulanabilen bir tur.
    return 'application/pdf';
  }

  /// Video suresini olcer. Olculemezse `null` doner (kapiyi ACIK birakir).
  ///
  /// ⚠️⚠️ `mixWithOthers: true` ZORUNLU — aksi halde bu KISA olcum bile iOS'ta
  ///    AVAudioSession kategorisini degistirip SUREN ARAMANIN sesini bozardi.
  ///    iOS'ta ses oturumu PROSES GENELINDE TEKTIR (turu 64/65/73 dersleri).
  /// ⚠️ Gecici oynatici HEMEN dispose edilir.
  ///
  /// ⚠️⚠️⚠️ TURU 78b — `donanimSerbest` KAPISI EKLENDI (denetim bulgusu).
  ///    `mixWithOthers: true` "oturumu ELE GECIRME" demektir; **"oturuma HIC
  ///    DOKUNMA" DEMEK DEGILDIR** — bu ayrim turu 75b'de `MedyaVideo._kur()`
  ///    icin SEVK ENGELI olarak kayda gecti ve oraya ayni kapi konuldu.
  ///    `video_player` iOS'ta `initialize()` sirasinda RTCAudioSession
  ///    kilidinin DISINDAN AVAudioSession'i yeniden yapilandirir.
  ///    Senaryo gercek: kullanici ilan formunda "Video" der, galeri DAKIKALARCA
  ///    acik kalabilir, bu sirada gelen aramayi kilit ekranindan kabul eder,
  ///    sonra galeriye donup video secer -> olcum SUREN ARAMANIN sesini bozar.
  /// ⚠️ Kapi kapaliyken `null` donulur: sure OLCULEMEZ sayilir ve dosya kabul
  ///    edilir (sunucu tavani yine korur). Bu, aramayi bozmaktansa dogru taviz.
  /// ⚠️ YAPMA: bu kapiyi kaldirma.
  static Future<Duration?> videoSuresi(File f, [WidgetRef? ref]) async {
    if (ref != null && !MedyaKapisi.donanimSerbest(ref)) return null;
    VideoPlayerController? c;
    try {
      c = VideoPlayerController.file(
        f,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await c.initialize().timeout(const Duration(seconds: 8));
      final d = c.value.duration;
      return d == Duration.zero ? null : d;
    } catch (_) {
      return null;
    } finally {
      unawaited(c?.dispose());
    }
  }
}
