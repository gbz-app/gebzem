/// SOHBETTEKI ARAMA KAYDI sistem mesajlarinin TEK ayristirma yeri (TURU 59).
///
/// Neden ayri dosya: ayni icerik iki yerde cizilir — sohbet thread'inde balon
/// (`_CallLogChip`) ve SOHBET LISTESI onizlemesinde tek satir. Onizleme eskiden
/// `chat.lastMessage`i HAM basiyordu: kullanici listede "call:ended:audio:75"
/// goruyordu. Ayristirma iki yerde ayri yazilirsa biri kacinilmaz sekilde
/// geride kalir; bu yuzden TEK KAYNAK.
///
/// Sunucu bicimleri (backend/internal/calls/handler.go):
///   · "call:missed:audio|video"           — cevapsiz (ESKI, degistirilmez)
///   · `call:ended:audio|video:<saniye>`   — cevaplanan (turu 58)
///   · `call:group:invite|end:<id>`        — grup araması kaydi (turu 21)
///
/// ⚠️ YAPMA: taninmayan `call:*` bicimini HAM metin olarak gosterme — kullaniciya
/// teknik isaretci sizar. Taninmayan bicim `null` doner, cagiran notr metin basar.
class AramaKaydi {
  const AramaKaydi({
    required this.video,
    required this.cevapsiz,
    required this.grup,
    required this.grupBitti,
    required this.saniye,
  });

  final bool video;
  final bool cevapsiz;
  final bool grup;
  final bool grupBitti;
  final int saniye;

  /// `content` bir arama kaydi degilse (veya bicim taninmiyorsa) null.
  static AramaKaydi? coz(String content) {
    if (!content.startsWith('call:')) return null;
    final p = content.split(':');
    if (p.length < 2) return null;
    switch (p[1]) {
      case 'group':
        return AramaKaydi(
          video: true,
          cevapsiz: false,
          grup: true,
          grupBitti: p.length > 2 && p[2] == 'end',
          saniye: 0,
        );
      case 'missed':
      case 'ended':
        return AramaKaydi(
          video: p.length > 2 && p[2] == 'video',
          cevapsiz: p[1] == 'missed',
          grup: false,
          grupBitti: false,
          saniye: p.length > 3 ? (int.tryParse(p[3]) ?? 0) : 0,
        );
      default:
        return null;
    }
  }

  /// "1 dk. 5 sn." / "37 sn." / "1 sa. 4 dk." / "2 sa." — WhatsApp bicimi.
  /// ⚠️ Tam saat siniri: dakika 0 ise " 0 dk." EKLENMEZ (WhatsApp "1 sa." yazar).
  static String sureMetni(int sn) {
    if (sn < 60) return '$sn sn.';
    final dk = sn ~/ 60;
    final kalan = sn % 60;
    if (dk < 60) return kalan == 0 ? '$dk dk.' : '$dk dk. $kalan sn.';
    final sa = dk ~/ 60;
    final kalanDk = dk % 60;
    return kalanDk == 0 ? '$sa sa.' : '$sa sa. $kalanDk dk.';
  }

  /// SOHBET LISTESI onizleme satiri.
  ///
  /// [benimMi]: son mesajin gondereni BEN miyim (arama kayitlarinda gonderen HER
  /// ZAMAN ARAYANDIR). Cevapsiz aramada "Cevapsız ..." YALNIZ ARANAN icin dogrudur;
  /// arayan icin WhatsApp sadece "Sesli arama" yazar. Yon bilinmiyorsa (`null` —
  /// or. sunucu `last_sender_id` dondurmuyorsa) YONSUZ, iki taraf icin de dogru
  /// olan metne duseriz. ⚠️ YAPMA: yon bilinmezken "Cevapsız" yazma.
  /// ⚠️ TURU 62 — METINDE EMOJI YOK (kullanici emri: "hicbir 3B ikon istemiyorum").
  /// Emoji sistem emoji fontuyla PARLAK/3B cizilir. Ikon artik AYRI bir widget olarak
  /// (`onizlemeIkonu`) veriliyor ve cagiran onu 2B Lucide ikonu olarak cizer.
  /// ⚠️ YAPMA: bu metne emoji geri koyma.
  String onizleme({bool? benimMi}) {
    if (grup) return grupBitti ? 'Grup araması sona erdi' : 'Grup araması';
    final ad = video ? 'Görüntülü arama' : 'Sesli arama';
    if (cevapsiz) {
      if (benimMi == false) {
        return video ? 'Cevapsız görüntülü arama' : 'Cevapsız sesli arama';
      }
      return ad; // arayan (veya yon bilinmiyor)
    }
    return saniye > 0 ? '$ad · ${sureMetni(saniye)}' : ad;
  }
}
