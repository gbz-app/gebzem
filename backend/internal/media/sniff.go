package media

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"strings"
)

// ⚠️⚠️ TURU 74 — DOSYA TIPI DOGRULAMA + GIZLILIK TARAMASI.
//
// ILKE: **ISTEMCININ BEYANINA ASLA GUVENME.** Uzanti ve `Content-Type` saldirganin
// kontrolunde. Nesne R2'ye yuklendikten SONRA ilk parcasi cekilir ve GERCEK tipi
// SIHIRLI BAYTLARDAN tespit edilir; beyanla uyusmuyorsa nesne SILINIR.
//
// ⚠️ NEDEN ONEMLI (somut): saldirgan `image/jpeg` diye beyan edip HTML yuklerse ve
//    biz onu ayni alan adindan sunarsak, tarayici HTML olarak calistirir -> oturum
//    calma. SVG ozellikle tehlikelidir: icinde <script> tasiyabilir ve "gorsel"dir.
//    Bu yuzden SVG **KESIN YASAK** (beyaz listede YOK).

// IzinliTip — kind bazinda kabul edilen MIME'ler.
// ⚠️ BEYAZ LISTE (kara liste DEGIL): yeni bir tehlikeli tip cikinca kod degismeden
//    guvende kaliriz.
var izinliTipler = map[string]map[string]bool{
	"image": {
		"image/jpeg": true,
		"image/png":  true,
		"image/webp": true,
		// ⚠️ image/gif YOK: animasyonlu GIF kotu sikistirilir (video kullan) ve
		//    "GIF bombasi" (dev cozunurluk, binlerce kare) bir bellek saldirisidir.
		// ⚠️ image/svg+xml YOK ve ASLA EKLENMEYECEK: XSS tasiyicisi.
		// ⚠️ image/heic YOK: Android'de acilmaz; istemci JPEG'e cevirir.
	},
	"avatar": {
		"image/jpeg": true,
		"image/png":  true,
		"image/webp": true,
	},
	"video": {
		"video/mp4": true,
	},
	"audio": {
		"audio/mp4":  true, // m4a (AAC) — record paketinin varsayilani
		"audio/mpeg": true,
		// ⚠️ TURU 74b: "audio/aac" CIKARILDI — ham ADTS akisi `GercekTip`te
		//    "audio/mpeg" olarak taninir, yani beyanla ASLA uyusmaz (olu kod).
	},
	"document": {
		"application/pdf": true,
		"application/msword": true,
		"application/vnd.openxmlformats-officedocument.wordprocessingml.document": true,
		"application/vnd.ms-excel": true,
		"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": true,
		"text/plain": true,
		// ⚠️ ZIP/RAR/APK/EXE/JS/HTML **YASAK**: zararli yazilim tasiyicisi.
		//    ZIP ayrica "zip bombasi" ve office dosyalarinin ic formati oldugu icin
		//    sihirli bayt ayrimi kirilgan — riski almiyoruz.
	},
}

// TipIzinli — kind + mime beyaz listede mi.
func TipIzinli(kind, mime string) bool {
	m := izinliTipler[kind]
	if m == nil {
		return false
	}
	// "image/jpeg; charset=..." gibi ekleri at
	if i := strings.IndexByte(mime, ';'); i >= 0 {
		mime = strings.TrimSpace(mime[:i])
	}
	return m[strings.ToLower(mime)]
}

// GercekTip — sihirli baytlardan GERCEK MIME'i cikarir. Bilinmiyorsa "".
// ⚠️ `http.DetectContentType` KULLANILMIYOR: o "text/plain" gibi genis tahminler
//    yapar ve HTML'i "text/html" diye dogru bulsa da bizim ihtiyacimiz KESIN esitlik.
func GercekTip(bas []byte) string {
	switch {
	case len(bas) >= 3 && bytes.Equal(bas[:3], []byte{0xFF, 0xD8, 0xFF}):
		return "image/jpeg"
	case len(bas) >= 8 && bytes.Equal(bas[:8], []byte{0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A}):
		return "image/png"
	case len(bas) >= 12 && bytes.Equal(bas[:4], []byte("RIFF")) && bytes.Equal(bas[8:12], []byte("WEBP")):
		return "image/webp"
	case len(bas) >= 5 && bytes.Equal(bas[:5], []byte("%PDF-")):
		return "application/pdf"
	case len(bas) >= 12 && bytes.Equal(bas[4:8], []byte("ftyp")):
		// ISO taban medya: mp4 (video) ve m4a (ses) AYNI kutuyu kullanir.
		// Marka koduna bakariz.
		marka := string(bas[8:12])
		if strings.HasPrefix(marka, "M4A") || marka == "M4B " {
			return "audio/mp4"
		}
		return "video/mp4"
	case len(bas) >= 3 && bytes.Equal(bas[:3], []byte("ID3")):
		return "audio/mpeg"
	case len(bas) >= 2 && bas[0] == 0xFF && (bas[1]&0xE0) == 0xE0:
		return "audio/mpeg" // ID3'suz MP3 cercevesi
	case len(bas) >= 4 && bytes.Equal(bas[:4], []byte{0xD0, 0xCF, 0x11, 0xE0}):
		return "application/msword" // eski Office (OLE)
	case len(bas) >= 4 && bytes.Equal(bas[:4], []byte{'P', 'K', 0x03, 0x04}):
		// ⚠️ ZIP kabi: docx/xlsx BU kabi kullanir ama duz ZIP de ayni gorunur.
		//    Ayirt etmek icin ic dizini okumak gerekir; RISKI ALMIYORUZ.
		//    Beyan docx/xlsx ise GECERLI sayilir, aksi halde reddedilir (asagida).
		return "application/zip"
	}
	return ""
}

// ⚠️⚠️ TEHLIKELI ICERIK TARAMASI — beyan ne olursa olsun bunlar REDDEDILIR.
// Saldirgan `image/jpeg` beyan edip HTML/JS yukleyebilir; sihirli bayt kontrolu
// bunlari zaten yakalar ama BURASI IKINCI KAPI (savunma katmani).
func TehlikeliMi(bas []byte) bool {
	// ⚠️⚠️ TURU 74b — `bytes.ToLower` IKILI VERIDE KULLANILAMAZ (test yakaladi).
	// `bytes.ToLower` UTF-8 COZER; 0xFF gibi gecersiz baytlar U+FFFD replacement
	// karakterine (EF BF BD) donusur. JPEG imzasi {FF D8 FF E0} boylece dort
	// replacement karakterine dusuyor ve `ToLower({CA FE BA BE})` (Mach-O) ile
	// BIREBIR AYNI oluyordu -> **HER JPEG "tehlikeli" sayiliyordu.**
	// Cozum: IKILI imzalar BAYT BAYT (buyuk/kucuk harf donusumu YOK), METIN
	// imzalar yalniz ASCII kucuk harfe cevrilerek karsilastirilir.
	// ⚠️ YAPMA: buraya `bytes.ToLower`/`strings.ToLower` geri koyma.

	// (a) IKILI imzalar — TAM BAYT esitligi
	ikili := [][]byte{
		{'M', 'Z'},                 // Windows PE (exe/dll)
		{0x7F, 'E', 'L', 'F'},      // Linux ELF
		{'d', 'e', 'x', '\n'},      // Android DEX
		{0xCA, 0xFE, 0xBA, 0xBE},   // Java class / Mach-O fat
		{0xFE, 0xED, 0xFA, 0xCE},   // Mach-O 32
		{0xFE, 0xED, 0xFA, 0xCF},   // Mach-O 64
	}
	for _, t := range ikili {
		if bytes.HasPrefix(bas, t) {
			return true
		}
	}

	// (b) METIN imzalar — bas kisimdaki bosluklari atla, ASCII kucuk harfle karsilastir
	s := bytes.TrimLeft(bas, " \t\r\n\x00")
	if len(s) > 64 {
		s = s[:64]
	}
	kucuk := asciiKucuk(s)
	metin := []string{
		"<?xml", "<svg", "<html", "<!doctype", "<script", "<?php", "#!/",
	}
	for _, t := range metin {
		if bytes.HasPrefix(kucuk, []byte(t)) {
			return true
		}
	}
	return false
}

// asciiKucuk — YALNIZ A-Z araligini cevirir; diger baytlara DOKUNMAZ.
// ⚠️ `bytes.ToLower`in aksine UTF-8 COZMEZ, dolayisiyla ikili veriyi BOZMAZ.
func asciiKucuk(b []byte) []byte {
	out := make([]byte, len(b))
	for i, c := range b {
		if c >= 'A' && c <= 'Z' {
			c += 'a' - 'A'
		}
		out[i] = c
	}
	return out
}

// ⚠️⚠️ EXIF GPS TARAMASI — GIZLILIK.
//
// Telefonla cekilen fotograf EXIF'inde **TAM KOORDINAT** tasir. Kullanici sohbete
// fotograf atarken evinin konumunu paylastigini BILMEZ. Bu yuzden:
//   · Istemci sikistirirken EXIF'i zaten atar (flutter_image_compress varsayilani),
//   · AMA sunucu GUVENMEZ ve GPS etiketi bulursa nesneyi REDDEDER (422).
// Boylece "istemci guncellenmemis" ya da "istemci sahte" durumlarinda da korunuruz.
//
// ⚠️ Neden reddetmek de temizlemek degil: EXIF'i sunucuda temizlemek dosyayi
//    YENIDEN YAZMAYI gerektirir (indir-isle-yukle) — cx33'te kabul edilemez.
//    Istemciyi dogru davranmaya ZORLAMAK daha ucuz ve daha guvenli.
func GPSIceriyorMu(bas []byte) bool {
	if len(bas) < 12 || !bytes.Equal(bas[:3], []byte{0xFF, 0xD8, 0xFF}) {
		return false // yalniz JPEG'de EXIF ariyoruz
	}
	// APP1 (0xFFE1) segmentini bul, icinde "Exif\0\0" olmali.
	i := 2
	for i+4 <= len(bas) {
		if bas[i] != 0xFF {
			i++
			continue
		}
		isaret := bas[i+1]
		if isaret == 0xD8 || isaret == 0x01 || (isaret >= 0xD0 && isaret <= 0xD7) {
			i += 2
			continue
		}
		if i+4 > len(bas) {
			return false
		}
		uzunluk := int(binary.BigEndian.Uint16(bas[i+2 : i+4]))
		if uzunluk < 2 || i+2+uzunluk > len(bas) {
			return false
		}
		if isaret == 0xE1 {
			seg := bas[i+4 : i+2+uzunluk]
			if len(seg) > 6 && bytes.HasPrefix(seg, []byte("Exif\x00\x00")) {
				return exifGPSVarMi(seg[6:])
			}
		}
		if isaret == 0xDA { // goruntu verisi basladi — EXIF bitti
			return false
		}
		i += 2 + uzunluk
	}
	return false
}

// exifGPSVarMi — TIFF basligini cozup IFD0'da GPS IFD isaretcisini (0x8825) arar.
func exifGPSVarMi(tiff []byte) bool {
	if len(tiff) < 8 {
		return false
	}
	var bo binary.ByteOrder
	switch {
	case bytes.HasPrefix(tiff, []byte("II")):
		bo = binary.LittleEndian
	case bytes.HasPrefix(tiff, []byte("MM")):
		bo = binary.BigEndian
	default:
		return false
	}
	ifd0 := int(bo.Uint32(tiff[4:8]))
	if ifd0 < 8 || ifd0+2 > len(tiff) {
		return false
	}
	adet := int(bo.Uint16(tiff[ifd0 : ifd0+2]))
	// ⚠️ Ust sinir: bozuk/kotu niyetli EXIF'te `adet` devasa olabilir.
	if adet > 512 {
		adet = 512
	}
	for k := 0; k < adet; k++ {
		giris := ifd0 + 2 + k*12
		if giris+12 > len(tiff) {
			return false
		}
		if bo.Uint16(tiff[giris:giris+2]) == 0x8825 { // GPSInfo IFD
			return true
		}
	}
	return false
}

// Dogrula — commit yolunun TEK karar noktasi.
// Doner: (temizMi, redSebebi)
func Dogrula(kind, beyanEdilenMIME string, bas []byte) (bool, string) {
	if !TipIzinli(kind, beyanEdilenMIME) {
		return false, "bu dosya türü desteklenmiyor"
	}
	if TehlikeliMi(bas) {
		return false, "güvenlik nedeniyle reddedildi"
	}
	gercek := GercekTip(bas)
	if gercek == "" {
		return false, "dosya türü tanınamadı"
	}
	// ⚠️ ZIP kabi ozel durumu: docx/xlsx bu kabi kullanir. Beyan office ise gecerli.
	if gercek == "application/zip" {
		if strings.Contains(beyanEdilenMIME, "openxmlformats") {
			gercek = beyanEdilenMIME
		} else {
			return false, "arşiv dosyaları desteklenmiyor"
		}
	}
	temizBeyan := beyanEdilenMIME
	if i := strings.IndexByte(temizBeyan, ';'); i >= 0 {
		temizBeyan = strings.TrimSpace(temizBeyan[:i])
	}
	// ⚠️⚠️ TURU 74b (DENETIM BULGUSU — ANDROID'DE SES NOTU HIC CALISMIYORDU):
	// `audio/mp4` (m4a) ve `video/mp4` **AYNI ISO-BMFF KABINI** kullanir; ayrim
	// yalnizca `ftyp` major brand'indedir. iOS'ta AVAudioRecorder "M4A " yazar
	// (gecerdi), Android'de `record` paketi MediaMuxer kullanir ve marka
	// "isom"/"mp42" olur -> `GercekTip` "video/mp4" doner -> beyanla uyusmuyor
	// -> **422 + nesne SILINIR.** Yani sesli mesaj iPhone'da calisir, Android'de
	// HIC calismazdi.
	// ⚠️ Guvenlik kaybi YOK: `kind` zaten audio/video ayrimini ve TAVANI uyguluyor;
	//    kap ikisinde de ayni oldugu icin bu esdegerlik dogrudur.
	// ⚠️ YAPMA: bu esdegerligi kaldirma.
	if (gercek == "video/mp4" && temizBeyan == "audio/mp4") ||
		(gercek == "audio/mp4" && temizBeyan == "video/mp4") {
		gercek = temizBeyan
	}
	if !strings.EqualFold(gercek, temizBeyan) {
		return false, fmt.Sprintf("dosya türü beyanla uyuşmuyor (%s)", gercek)
	}
	if GPSIceriyorMu(bas) {
		// ⚠️ Kullaniciya ANLASILIR mesaj: teknik "EXIF" demiyoruz.
		return false, "fotoğraf konum bilgisi içeriyor; lütfen uygulamayı güncelleyin"
	}
	return true, ""
}
