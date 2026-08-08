package media

import "testing"

func TestBeyazListe(t *testing.T) {
	if TipIzinli("image", "image/svg+xml") {
		t.Fatal("SVG KABUL EDILDI — XSS acigi")
	}
	if TipIzinli("document", "application/zip") {
		t.Fatal("ZIP kabul edildi")
	}
	if TipIzinli("document", "application/vnd.android.package-archive") {
		t.Fatal("APK kabul edildi")
	}
	if !TipIzinli("image", "image/jpeg; charset=binary") {
		t.Fatal("parametreli JPEG reddedildi")
	}
}

func TestSihirliBayt(t *testing.T) {
	tablo := map[string][]byte{
		"image/jpeg":      {0xFF, 0xD8, 0xFF, 0xE0},
		"image/png":       {0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A},
		"application/pdf": []byte("%PDF-1.7\n"),
		"video/mp4":       append([]byte{0, 0, 0, 0x18}, []byte("ftypmp42")...),
		"audio/mp4":       append([]byte{0, 0, 0, 0x18}, []byte("ftypM4A ")...),
	}
	for beklenen, bas := range tablo {
		if g := GercekTip(bas); g != beklenen {
			t.Errorf("%s bekleniyordu, %q bulundu", beklenen, g)
		}
	}
}

func TestTehlikeli(t *testing.T) {
	for _, s := range []string{
		"<svg xmlns=...><script>alert(1)</script></svg>",
		"<!DOCTYPE html><html>",
		"<?php system($_GET[0]);",
		"MZ\x90\x00",
		"#!/bin/sh",
	} {
		if !TehlikeliMi([]byte(s)) {
			t.Errorf("tehlikeli sayilmadi: %q", s[:min(20, len(s))])
		}
	}
	if TehlikeliMi([]byte{0xFF, 0xD8, 0xFF, 0xE0}) {
		t.Error("normal JPEG tehlikeli sayildi")
	}
}

// Beyan/gercek uyusmazligi: PNG'yi JPEG diye beyan et.
func TestBeyanUyusmazligi(t *testing.T) {
	png := []byte{0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0}
	ok, sebep := Dogrula("image", "image/jpeg", png)
	if ok {
		t.Fatal("PNG, JPEG beyaniyla GECTI")
	}
	t.Logf("dogru reddedildi: %s", sebep)
}

// HTML'i JPEG diye beyan et (asil saldiri).
func TestHTMLSaldirisi(t *testing.T) {
	ok, sebep := Dogrula("image", "image/jpeg", []byte("<html><script>x</script>"))
	if ok {
		t.Fatal("HTML, JPEG beyaniyla GECTI — XSS")
	}
	t.Logf("dogru reddedildi: %s", sebep)
}

// GPS'li EXIF JPEG uretip reddedildigini dogrula.
func TestGPSReddi(t *testing.T) {
	// JPEG SOI + APP1(Exif) + TIFF(II) + IFD0 tek giris = GPSInfo(0x8825)
	tiff := []byte{'I', 'I', 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00} // baslik, IFD0 offset=8
	tiff = append(tiff, 0x01, 0x00)                              // 1 giris
	tiff = append(tiff, 0x25, 0x88, 0x04, 0x00, 0x01, 0, 0, 0, 0x1A, 0, 0, 0)
	seg := append([]byte("Exif\x00\x00"), tiff...)
	uz := len(seg) + 2
	jpg := []byte{0xFF, 0xD8, 0xFF, 0xE1, byte(uz >> 8), byte(uz)}
	jpg = append(jpg, seg...)

	if !GPSIceriyorMu(jpg) {
		t.Fatal("GPS etiketi BULUNAMADI — gizlilik kapisi calismiyor")
	}
	ok, sebep := Dogrula("image", "image/jpeg", jpg)
	if ok {
		t.Fatal("GPS'li fotograf GECTI")
	}
	t.Logf("dogru reddedildi: %s", sebep)

	// GPS'siz JPEG gecmeli
	temiz := []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0}
	if GPSIceriyorMu(temiz) {
		t.Fatal("GPS'siz JPEG'de yanlis pozitif")
	}
	if ok, s := Dogrula("image", "image/jpeg", temiz); !ok {
		t.Fatalf("temiz JPEG reddedildi: %s", s)
	}
}

func min(a, b int) int { if a < b { return a }; return b }
