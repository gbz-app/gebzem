import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../router.dart' show rootMessengerKey;
import '../isletme/kategori_kabuk.dart' show YemekHeader;

/// ⚠️⚠️⚠️ TURU 180ac — **"Gebzem App" BILGILENDIRME SOHBETI** (kullanici emri:
/// *"sohbete GebzemAI ve Gebzem App diye sohbet olsun; Gebzem App WhatsApp
/// gibi bilgilendirme olsun, orada detayli yazilar sohbet icerikleri ekle
/// uygulama ile ilgili"*).
///
/// WhatsApp'in kendi resmi sohbetiyle ayni is: uygulamayi TANITAN, salt
/// okunur bir sohbet.
///
/// ⚠️⚠️ **SUNUCUDA KARSILIGI YOK ve OLMASI DA GEREKMIYOR**: icerik SABIT bir
///	tanitim metnidir, kullanici verisi degil. `chats` tablosuna sahte bir
///	satir acmak (a) her hesapta migration/tohum isi olurdu, (b) silinebilir
///	/ arsivlenebilir / engellenebilir bir "kisi" gibi davranirdi.
/// ⚠️ Bu yuzden ekran **SALT OKUNUR**: giris cubugu YOK, mesaj gonderilemez.
///	Gorunen ama calismayan bir giris kutusu koymak turu 66b dersinin
///	tekrari olurdu.
/// ⚠️⚠️ **ICERIK UYDURULMADI**: her madde uygulamada GERCEKTEN VAR olan bir
///	ozelligi anlatiyor (akis · reels · kanal · sohbet medyasi · IBAN ·
///	anket · arama · isletme/randevu · ilan · ulasim · GebzemAI). Olmayan
///	bir sey vaat etmek turu 135'te (uydurma kur seridi) reddedilen sinif.
class GebzemAppEkrani extends StatelessWidget {
  const GebzemAppEkrani({super.key});

  /// Tanitim balonlari. `baslik` bos ise duz paragraf balonu cizilir.
  static const _mesajlar = <({String baslik, String metin, IconData? ikon})>[
    (
      baslik: 'Hoş geldin 👋',
      metin:
          'Gebzem; sohbet, sesli/görüntülü arama, canlı yayın, sosyal akış ve '
          'şehir rehberini tek uygulamada toplar. Bu sohbette uygulamanın ne '
          'yapabildiğini anlatıyoruz. Buraya mesaj yazamazsın — yalnızca '
          'bilgilendirme içindir.',
      ikon: null,
    ),
    (
      baslik: 'Sohbet',
      metin:
          'Birebir ve grup sohbeti, okundu bilgisi ve "yazıyor…" göstergesi. '
          'Ataç düğmesinden fotoğraf, video, belge, konum, kişi, IBAN ve anket '
          'paylaşabilirsin. Mesaja uzun basınca kopyala / yıldızla / yanıtla / '
          'sil seçenekleri çıkar.',
      ikon: LucideIcons.messageCircle,
    ),
    (
      baslik: 'Sohbet ayarları',
      metin:
          'Sohbet başlığına dokun: tema (balon rengi), takma ad, süreli '
          'mesajlar, sohbet kontrolleri, gizlilik ve emniyet, paylaşılan medya '
          'galerisi. Listede bir sohbete uzun basarsan sabitle / sessize al / '
          'arşivle / sil menüsü açılır.',
      ikon: LucideIcons.settings,
    ),
    (
      baslik: 'Arama',
      metin:
          'Sesli ve görüntülü arama; telefon kilitliyken de çalar. Görüşme '
          'sürerken uygulamadan çıkarsan küçük pencerede devam eder. Gelen '
          'GSM araması olduğunda Gebzem araması otomatik beklemeye alınır.',
      ikon: LucideIcons.phone,
    ),
    (
      baslik: 'Kanallar',
      metin:
          'Tek yönlü duyuru kanalları. Abone olduğun kanallar sohbet listende '
          'görünür. Kanal adına dokunursan profilinde paylaşılan tüm '
          'fotoğraf, video ve belgeleri bulursun.',
      ikon: LucideIcons.megaphone,
    ),
    (
      baslik: 'Akış, Reels ve hikâyeler',
      metin:
          'Gönderi paylaş, beğen, yorum yap, kaydet. Reels sekmesinde dikey '
          'videolar, üstte 24 saatlik hikâyeler. "Mahalle" sekmesi yalnızca '
          'çevrendeki konumlu gönderileri gösterir.',
      ikon: LucideIcons.clapperboard,
    ),
    (
      baslik: 'Canlı yayın ve sesli odalar',
      metin:
          'Canlı yayın açabilir, konuk alabilir, hediye gönderebilirsin. '
          'Sesli odalarda el kaldırıp konuşmacı olabilirsin.',
      ikon: LucideIcons.radio,
    ),
    (
      baslik: 'Şehir rehberi',
      metin:
          'Yakınındaki işletmeler, menüler, randevu ve rezervasyon; ilanlar, '
          'iş ilanları, etkinlikler ve hizmet talepleri. Ulaşım bölümünde '
          'Kocaeli otobüs durakları ve gerçek sefer saatleri var.',
      ikon: LucideIcons.mapPin,
    ),
    (
      baslik: 'GebzemAI',
      metin:
          'Sohbet listesinin en üstündeki GebzemAI ile yazışabilir, ürün '
          'açıklaması yazdırabilir veya menü oluşturabilirsin.',
      ikon: LucideIcons.sparkles,
    ),
    (
      baslik: 'Gizlilik',
      metin:
          'İstemediğin kişiyi engelleyebilir, uygunsuz içeriği şikâyet '
          'edebilirsin. Engelleme çift yönlüdür: karşılıklı mesaj gitmez. '
          'Sohbeti temizlemek yalnızca senin tarafını gizler.',
      ikon: LucideIcons.lock,
    ),
    (
      baslik: 'Sürüm',
      metin:
          'Bu bir test sürümüdür; bazı bölümler hazırlanıyor. Bir şey '
          'çalışmazsa uzun basıp şikâyet edebilir ya da bize yazabilirsin.',
      ikon: LucideIcons.info,
    ),
  ];

  @override
  Widget build(BuildContext context) => koyuSayfa(Builder(builder: _govde));

  Widget _govde(BuildContext c) {
    final ks = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: kAiZemin,
      appBar: YemekHeader(
        baslik: 'Gebzem App',
        geriBasildi: () => Navigator.of(c).maybePop(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: _mesajlar.length + 1,
        itemBuilder: (bc, i) {
          if (i == _mesajlar.length) {
            // ⚠️ SALT OKUNUR oldugu ACIKCA yaziliyor: giris kutusu olmayan
            //	bir sohbette kullanici "yazamiyorum, bozuk" der.
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Text(
                'Bu sohbet yalnızca bilgilendirme içindir; mesaj gönderilemez.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: ks.onSurface.withValues(alpha: 0.45),
                ),
              ),
            );
          }
          final m = _mesajlar[i];
          return Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              // ⚠️ Uzun basinca KOPYALA: tanitim metni uzun; kullanicinin
              //	bir maddeyi baskasina iletmek istemesi dogal.
              onLongPress: () {
                Clipboard.setData(
                  ClipboardData(text: '${m.baslik}\n${m.metin}'),
                );
                rootMessengerKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Kopyalandı')),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(bc).size.width * 0.86,
                ),
                decoration: BoxDecoration(
                  color: ks.bubbleOther,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (m.ikon != null) ...[
                          Icon(m.ikon, size: 17, color: ks.primary),
                          const SizedBox(width: 7),
                        ],
                        Flexible(
                          child: Text(
                            m.baslik,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ks.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.metin,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.38,
                        color: ks.onSurface.withValues(alpha: 0.86),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
