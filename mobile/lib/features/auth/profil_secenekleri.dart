/// ⚠️⚠️⚠️ TURU 120 — ILGI ALANI ve TAKIM SECENEKLERI (kullanici emri:
///	*"kayitta stepte KAC YASINDASIN 28 27 yukari asagi secenek, ILGI
///	ALANLARI, TUTTUGU TAKIM vb seyleri de sor"*).
///
/// ═══════════ NEDEN ISTEMCIDE, SUNUCUDA DEGIL ═══════════
///
/// Turu 77'nin *"kategori agacini istemciye yazma"* kurali BURADA GECERLI
/// DEGIL. O kural, listenin **SORGU DAVRANISINI** belirledigi durum icindi:
/// yeni bir isletme kategorisi eklemek, eski surumlerin o kategoriyi
/// listeleyememesi demekti ve duzeltmesi MAGAZA ONAYI gerektiriyordu.
///
/// Bu iki liste hicbir sorguyu, yetkiyi ya da siralamayi beslemiyor — profil
/// suslemesi. Sunucu (`internal/profil/alanlar.go`) bunlari BEYAZ LISTEYE
/// gore dogrulamaz, yalnizca uzunluk/adet tavani uygular; yani eski bir
/// surumun sectigi deger ileride de KABUL EDILIR.
///
/// ⚠️ Ileride "ilgi alanina gore oneri/eslesme" gibi bir ozellik gelirse liste
///    SUNUCUYA tasinmali ve orada beyaz listeye cevrilmelidir.
///
/// ⚠️ Bu dosya AYRI: kayit akisi bugun kullaniyor, PROFIL DUZENLEME yarin
///    kullanacak. Iki yere kopyalanmasi bu projede alti kez yasanan drifti
///    yedinci kez uretirdi.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Sunucudaki tavanla (`profil.EnFazlaIlgi`) **BIREBIR AYNI** olmali.
///
/// ⚠️ Buyuk yazilirsa: kullanici 15 ilgi secer, sunucu 12'sini alir ve
///    kalanlar SESSIZCE kaybolur ("kaydettim ama gitmemis" sinifi).
/// ⚠️ Kucuk yazilirsa: sunucunun izin verdigi alan bos kalir (zararsiz ama
///    gereksiz kisitlama).
const int kEnFazlaIlgi = 12;

/// Yas seciciye giren aralik. Sunucudaki `profil.EnKucukYas/EnBuyukYas` ile
/// AYNI — disari tasan bir deger sunucuda SESSIZCE dusurulur.
const int kEnKucukYas = 13;
const int kEnBuyukYas = 90;

/// ⚠️ Ikon + etiket: renk korlugunde ve hizli taramada ikon anlam TASIR
///    (turu 98b dersi: *"renk TEK BASINA hicbir sey anlatmaz"*).
/// ⚠️ Etiket METNI sunucuya OLDUGU GIBI gider ve profilde OLDUGU GIBI
///    gorunur — kisaltma/kod YOK, cevrim tablosu tutmak gerekmesin.
const List<(IconData, String)> kIlgiAlanlari = <(IconData, String)>[
  (LucideIcons.volleyball, 'Futbol'),
  (LucideIcons.dumbbell, 'Spor salonu'),
  (LucideIcons.footprints, 'Yürüyüş'),
  (LucideIcons.bike, 'Bisiklet'),
  (LucideIcons.utensils, 'Yemek'),
  (LucideIcons.coffee, 'Kahve'),
  (LucideIcons.music, 'Müzik'),
  (LucideIcons.film, 'Sinema'),
  (LucideIcons.tv, 'Dizi'),
  (LucideIcons.gamepad2, 'Oyun'),
  (LucideIcons.bookOpen, 'Kitap'),
  (LucideIcons.plane, 'Seyahat'),
  (LucideIcons.tent, 'Doğa & kamp'),
  (LucideIcons.fish, 'Balık tutma'),
  (LucideIcons.camera, 'Fotoğrafçılık'),
  (LucideIcons.laptop, 'Teknoloji'),
  (LucideIcons.car, 'Otomobil'),
  (LucideIcons.shirt, 'Moda'),
  (LucideIcons.palette, 'Sanat'),
  (LucideIcons.dog, 'Evcil hayvan'),
  (LucideIcons.briefcase, 'Girişimcilik'),
  (LucideIcons.heartHandshake, 'Gönüllülük'),
];

/// ⚠️ **YEREL TAKIMLAR LISTEDE** (Kocaelispor · Gebzespor): uygulama Gebze
///    icin yaziliyor ve yalnizca dort buyugu listelemek, kullanicinin kendi
///    sehrinin takimini "Diğer"e dusururdu.
/// ⚠️ **"Takım tutmuyorum" ZORUNLU BIR SECENEK**: olmasaydi futbolla
///    ilgilenmeyen kullanici adimi bos birakmak ile yanlis bir takim secmek
///    arasinda kalirdi. Bu secenek sunucuya **BOS DIZE** olarak gider —
///    yani "belirtmedi" ile ayni sonuc, ama kullanici KARAR VERMIS olur.
const List<String> kTakimlar = <String>[
  'Galatasaray',
  'Fenerbahçe',
  'Beşiktaş',
  'Trabzonspor',
  'Başakşehir',
  'Kocaelispor',
  'Gebzespor',
  'Diğer',
  'Takım tutmuyorum',
];

/// "Takım tutmuyorum" secildiginde sunucuya BOS gider (bkz. serh).
const String kTakimYok = 'Takım tutmuyorum';
