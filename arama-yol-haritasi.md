# Gebzem — Arama & Yayın Yol Haritası (araştırma temelli)

> 16 Tem 2026, 6 derin araştırma workflow'unun (mimari + beklet + kesinti + grup/AR + 4 tür) sentezi.
> Karar: mevcut CallKit/LiveKit yaklaşımı DOĞRU; aşağıdaki sırayla, her adım öncekinin kodunu tekrar kullanır.

## MİMARİ KARARI (değiştirme)
- **1:1 kişisel arama = WhatsApp/telekom modeli (CallKit + VoIP push). KORU.** iOS'ta uygulama kapalı/kilitliyken
  güvenilir gelen-arama teslimi SADECE CallKit+PushKit ile mümkün. "Sosyal uygulama = in-app" kuralı YANLIŞ;
  belirleyici çağrı türü: 1:1 özel = CallKit, oda/yayın = in-app.
- **Grup/Spaces/canlı yayın = in-app (CallKit'e SOKMA).** Bir yayına katılmak telefon araması gibi çalmamalı.
- Gebzem zaten HİBRİT: WhatsApp taşıma (kilit ekranı) + Instagram sadeliği (tek arama, ikincisi meşgul).
- Instagram gerçeği: "Beklet/Kabul" ekranını uygulama çizmez, iOS verir; Instagram CallKit'e az/hiç girmediği için görünmez.

## İKİNCİ ARAMA & KESİNTİ (v13'te uygulandı)
- **Aynı-uygulama 2. arama:** MEŞGUL yap (ikincisini engelle). WhatsApp gibi. → v13 "meşgul muhafızı".
- **"Beklet & Kabul" (hold-swap): İNŞA ETME.** ÇOK YÜKSEK risk — flutter-webrtc #1996 + Apple 749202 AÇIK bug
  (beklet sonrası ses iki yönde ölür). WhatsApp bile yapmıyor; sadece Telegram (devasa yatırım). supportsHolding=false kalsın.
- **GSM/WhatsApp kesince ses toparlama:** DÜŞÜK risk, GetStream/Twilio deseni. → v13 app-resume nudge (_kesintidenTopla).
  Aşama 2/3 (iOS interruption listener + Android AudioFocus) gerekirse sonra; resume nudge çoğu durumu çözer.
- Instagram CallKit kullanmaz → Gebzem araması varken Instagram sesi başlayamaz; gerçek konu sadece WhatsApp + GSM.

## SONRAKİ ÖZELLİKLER — SIRA (1:1 stabil olduktan sonra)

### 1) SESLİ GRUP (3-10 kişi, herkes konuşur) — DÜŞÜK risk, İLK yap
- Mimari: tek LiveKit oda, herkes publish+subscribe (SFU NxN). 1:1 medya kodu AYNEN. Opus ~50 kbps.
- cx33 kapasite: RAHAT (~30-50 eşzamanlı 10-kişilik grup). Trafik ~2.25 GB/saat/10-kişi.
- Ek iş (medya DIŞINDA): **grup zil/davet fan-out** (internal/calls'ı N-alıcıya genişlet + per-üye durum makinesi
  ringing/accepted/declined/timeout + Redis roster). ⚠️ grup 1:1 gibi OTOMATİK İPTAL OLMAZ (biri açınca ötekiler çalar).
  Her üyeye VoIP push. Üyelik: mevcut chats type=group tekrar kullan. UI: components-flutter hazır.

### 2) GÖRÜNTÜLÜ GRUP (herkes kameralı NxN) — ORTA, CAP 6 (max 8)
- Sesli grupla AYNI kod + video. Zil/davet/CallKit altyapısı sesli gruptan ORTAK gelir.
- ⚠️ **Flutter tuzağı:** RoomOptions'ta adaptiveStream+dynacast VARSAYILAN FALSE → ELLE aç (yoksa herkes 720p,
  kapasite 10x düşer). VP8 + simulcast + degradationPreference: balanced (H264 KULLANMA — 720p tavanı).
- cx33: ~3-8 eşzamanlı 6-kişilik grup. ASIL SINIR sık sık İSTEMCİ (telefon 7+ decode → ısınma/pil).

### 3) SPACES / SESLİ ODA (host + speaker + kalabalık dinleyici, el kaldırma) — ORTA-YÜKSEK iş, UCUZ altyapı
- Model: tek oda, roller = token grant (dinleyici canPublish:false+canSubscribe:true → uplink yok). SFU yükü
  KONUŞMACI sayısıyla artar, dinleyiciyle değil.
- Rol/moderasyon (hepsi sunucu-taraflı izin): promote/demote = UpdateParticipant canPublish; sustur = MutePublishedTrack;
  at = RemoveParticipant; ban = backend blocked_users (LiveKit'te yok). ⚠️ metadata race (#1829) → **rol kaynağı DB'de**.
  El kaldırma: dinleyici data sinyali → host onay → UpdateParticipant. Backend: internal/rooms (/promote,/demote,/mute,/remove).
- cx33: tek Space ~200-500 dinleyici (ses ucuz, ~20x). ⚠️ OSS'de oda TEK NODE'a sığmak ZORUNDA (bölünemez);
  binlerce dinleyici → dikey ölçek / LiveKit Cloud / hibrit (pasif kitle HLS). Flutter UI SIFIRDAN.
- Yasal: 5651/BTK (log, 4-saat kaldırma, ~1M/gün eşiğinde temsilci); kayıtta KVKK.

### 4) CANLI YAYIN (1 yayıncı + binlerce izleyici + hediye) — EN ZOR/PAHALI, EN SON
- WebRTC vs HLS karar ağacı: <500 izleyici → saf WebRTC (~300ms, çift yönlü hediye/reaksiyon anlık);
  500-10K → hibrit (yayıncı WebRTC + kitle LL-HLS); 10K+ → HLS zorunlu. Prototipte SAF WebRTC + <500 ile başla.
- LiveKit native HLS egress (.ts/.m3u8 → R2, RTMP relay gerekmez). R2 egress ÜCRETSİZ → dağıtım ~bedava
  (WebRTC 10K izleyici/saat ~$600-900'e karşılık). LL-HLS 2-5sn = TikTok Live seviyesi.
- ⚠️ cx33 VİDEO YAYINDA İLK/EN SERT zorlanır: NIC/bant sınır (~200-350 video izleyici) + 20TB → sadece ~70-75 saat/ay
  tam video. **Egress AYRI MAKİNE** (min 4 CPU/4GB) şart. Büyümede Hetzner dedicated (CCX23/33, €25-50/ay).
- Hediye/coin: TikTok modeli (coin satın al → hediye → yayıncı gelir). coin_ledger var. Hediye WS fanout (HLS'e data ulaşmaz).
  ⚠️ **Apple/Google IAP %30/%15 (kaçış yok)** + payout 6493/İyzico (asla kendi bünyede) + 5651 gerçek-zamanlı video moderasyon.

## AR FİLTRE / ARKA PLAN — ERTELENDİ (kullanıcı kararı + araştırma)
- **DeepAR'a PARA VERME:** Flutter plugini ~3 yıl terk, 50K'da ~$1000/ay, LiveKit'e bağlamak haftalarca native.
- **Sadece arka plan için: Google ML Kit Selfie Segmentation — BEDAVA**, on-device, MAU ücreti yok, güncel Flutter plugini.
  İlk sürüm BLUR (kolay), sonra hazır arka plan görselleri.
- ⚠️ Entegrasyon riski YÜKSEK: livekit_client 2.8.1 VideoProcessor API var ama Flutter'da hazır işleyici YOK (kendin yaz),
  ~1-2 hafta iki-platform native. **AR'yi AYRI video source ile izole et (canlı 1:1'i bozma).** Yüz filtresi kritikse: Banuba (pahalı).

## OLÇEKLENME
- 4 tür AYNI LiveKit oda/participant modelini paylaşır (canlı yayın HLS hariç). Ortak kod çok.
- Tek makine (cx33) limiti: canlı yayın video izleyici İLK zorlar; Spaces dinleyici çok sonra. Oda bölünemez (OSS).
- Türkiye mobil = TURN relay zorunlu → gerçek egress teorik NxN'in ~1.3-2 katı.
- Büyümede: Hetzner dedicated vCPU (CCX23/33) + egress ayrı node + coklu-node (Redis mesh, farklı odaları dağıtır).
