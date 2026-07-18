import 'package:livekit_client/livekit_client.dart';

/// UYARLANABILIR VIDEO — kullanici sabit bir cozunurluge kilitlenmez.
///
/// Karar (arastirma sonucu, livekit_client 2.8.1 kaynak koduyla dogrulandi):
///  - 1080p YAKALA, **VP8 + simulcast** ile yayinla (H264: SDK level 3.1 =720p'ye
///    kilitliyor; VP9/AV1: orta segment Android'de donanim encode yok).
///  - **degradationPreference: balanced** — SDK varsayilani maintainResolution'dir;
///    o secilirse ag kotulesince cozunurluk sabit kalir, KARE HIZI cakilir (slayt
///    gosterisi). balanced ile hem cozunurluk hem fps dengeli duser.
///  - **adaptiveStream + dynacast** acik — karsi taraf kucuk pencerede goruyorsa
///    ust katman (1080p) HIC encode edilmez (pil/CPU/veri tasarrufu). Ag iyilesince
///    WebRTC ust katmani kendisi geri acar. Kullanici hicbir sey yapmaz.
///
/// Simulcast katmanlari: 270p / 540p / 1080p — yumusak gecis. Tavan ~2.5 Mbps;
/// dynacast sayesinde pratikte cogunlukla tek katman gider.

/// Simulcast alt katmanlari (en ust katman videoEncoding ile ayrica veriliyor)
const _layer270 = VideoParameters(
  dimensions: VideoDimensions(480, 270),
  encoding: VideoEncoding(maxBitrate: 250 * 1000, maxFramerate: 20),
);
const _layer540 = VideoParameters(
  dimensions: VideoDimensions(960, 540),
  encoding: VideoEncoding(maxBitrate: 800 * 1000, maxFramerate: 25),
);

/// 1:1 goruntulu arama icin yayin secenekleri.
/// NOT: 1080p'den 720p'ye dusuruldu. Orta segment Android'de 1080p VP8 YAZILIM
/// encode/decode ana gecikme + isinma kaynagiydi ("goruntu geriden geliyor").
/// 720p + 1.2 Mbps tavan cihaz-tarafli gecikmeyi belirgin azaltir; ag iyiyse
/// yeterince net, kotulesince adaptiveStream/balanced zaten dusuruyor.
const kVideoPublishOptions = VideoPublishOptions(
  videoCodec: 'vp8',
  simulcast: true,
  videoSimulcastLayers: [_layer270, _layer540],
  videoEncoding: VideoEncoding(maxFramerate: 30, maxBitrate: 1200 * 1000),
  degradationPreference: DegradationPreference.balanced,
);

/// Kamera yakalama: 720p (1280x720). 1080p eski/orta cihazlarda kodlayiciyi
/// zorlayip gecikme+isi yaratiyordu.
const kCameraCaptureOptions = CameraCaptureOptions(
  params: VideoParametersPresets.h720_169,
  cameraPosition: CameraPosition.front,
);

/// GRUP goruntulu arama profili (cx33 korumasi, grup-arama plani madde 4):
/// N kisi = N yayin + N*(N-1) abonelik; grid'de kutular kucuk oldugundan 540p ustu
/// ISRAF (CPU/bant/isi). Ust katman 540p/700kbps + alt katman 270p; adaptiveStream
/// zaten kucuk kutuda alt katmana iner. 1:1 secenekleri AYNEN durur (yukarida).
const kGroupVideoPublishOptions = VideoPublishOptions(
  videoCodec: 'vp8',
  simulcast: true,
  videoSimulcastLayers: [_layer270],
  videoEncoding: VideoEncoding(maxFramerate: 24, maxBitrate: 700 * 1000),
  degradationPreference: DegradationPreference.balanced,
);

/// Grup kamera yakalama: 540p — 720p yakalayip 540p encode etmek islemciyi bosa isitir.
const kGroupCameraCaptureOptions = CameraCaptureOptions(
  params: VideoParametersPresets.h540_169,
  cameraPosition: CameraPosition.front,
);

/// Ses: 1:1 konusma icin — yankı/gurultu engelleme + DTX (sessizken gonderme)
const kAudioCaptureOptions = AudioCaptureOptions(
  echoCancellation: true,
  noiseSuppression: true,
  autoGainControl: true,
);
const kAudioPublishOptions = AudioPublishOptions(dtx: true);
