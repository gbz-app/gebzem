package ilan

import "testing"

// ⚠️⚠️⚠️ TURU 91 — MUHAFIZ: HER TALEP KATEGORISININ BIR HEDEFI OLMALI.
//
// ═══════════ NEDEN ═══════════
//
// Talep kategorileri `Turler` icinde, fan-out hedefleri `talepHedefKategori`
// haritasinda. IKI LISTE ve bu projede "ayni bilginin iki kopyasi KACINILMAZ
// OLARAK DRIFT EDER" DORT kez sahaya cikti (turu 72b/H, 75b, 78b, 80b).
//
// ⚠️ DRIFTIN BEDELI **TAMAMEN SESSIZDIR**: yeni bir talep kategorisi eklenip
//
//	haritaya yazilmazsa talep OLUSUR, listede GORUNUR, uc 201 doner —
//	ama HICBIR ISLETMEYE BILDIRILMEZ. Kullanici "kimse teklif vermiyor"
//	der ve sebebini bulmanin yolu YOKTUR (log'a duser ama kimse bakmaz).
//
// ⚠️ TERS YON DE KONTROL EDILIR: haritada var olmayan bir kategoriye giris
//
//	yazmak (yazim hatasi) da sessizdir — o giris HIC KULLANILMAZ.
//
// ⚠️ YAPMA: bu testi silme. Talep kategorisi eklerken `Turler` ve
//
//	`talepHedefKategori`i BIRLIKTE guncelle.
func TestHerTalepKategorisininHedefiVar(t *testing.T) {
	var talep *Tur
	for i := range Turler {
		if TalepTuru(Turler[i].Anahtar) {
			talep = &Turler[i]
			break
		}
	}
	if talep == nil {
		t.Fatal("`talep` turu `Turler` icinde BULUNAMADI — teklif akisinin " +
			"tamami buna bagli")
	}
	if len(talep.Kategoriler) == 0 {
		t.Fatal("`talep` turunun KATEGORISI YOK")
	}

	gorulen := map[string]bool{}
	for _, k := range talep.Kategoriler {
		gorulen[k.Anahtar] = true
		hedef, ok := talepHedefKategori[k.Anahtar]
		if !ok || len(hedef) == 0 {
			t.Errorf("TALEP KATEGORISI %q (%s) icin `talepHedefKategori`de "+
				"hedef YOK.\n"+
				"  Bu kategoride acilan talep HICBIR ISLETMEYE BILDIRILMEZ:\n"+
				"  uc 201 doner, talep listede gorunur, ama kimse haberdar\n"+
				"  olmaz. Kullanici 'kimse teklif vermiyor' der ve sebebini\n"+
				"  bulamaz.\n"+
				"  COZUM: talep.go icindeki haritaya giris ekle.",
				k.Anahtar, k.Ad)
		}
	}

	// Ters yon: haritada OLU giris var mi?
	for anahtar := range talepHedefKategori {
		if !gorulen[anahtar] {
			t.Errorf("`talepHedefKategori` icinde %q girisi var ama boyle bir "+
				"TALEP KATEGORISI YOK — bu giris HIC KULLANILMAZ.\n"+
				"  Yazim hatasi mi, yoksa kategori kaldirildi da harita "+
				"guncellenmedi mi?", anahtar)
		}
	}
}

// Hedef kategorilerin GERCEKTEN var olan isletme kategorileri oldugunu
// dogrular.
//
// ⚠️ Bu, bir onceki testin YAKALAYAMADIGI ikinci drift yonudur: harita
//
//	doldurulmus olabilir ama icindeki isletme kategorisi YANLIS YAZILMIS
//	olabilir (`"kuafor"` yerine `"kuaför"`). O durumda sorgu HIC SATIR
//	DONDURMEZ ve sonuc yine "kimseye bildirilmedi"dir — ama bu sefer log
//	bile "kategori haritada yok" DEMEZ, yani daha da sessizdir.
//
// ⚠️ `isletme` paketini IMPORT ETMEZ (dongu riski): beklenen kume burada
//
//	yazili ve `isletme.Kategoriler` degisirse bu liste de guncellenmeli.
//	Kucuk ve nadiren degisen bir kume oldugu icin bu kabul edilebilir;
//	alternatif (import) `isletme -> ilan` yonundeki mevcut bagimliligi
//	TERSINE cevirip DONGU olustururdu (`isletme/modul.go` `ilan.Alan`
//	tipini kullaniyor).
func TestTalepHedefleriGecerliIsletmeKategorisi(t *testing.T) {
	gecerli := map[string]bool{
		"yemek": true, "kafe": true, "market": true, "giyim": true,
		"kuafor": true, "guzellik": true, "diyetisyen": true, "oto": true,
		"saglik": true, "eczane": true, "otel": true, "egitim": true,
		"emlak": true, "spor": true, "teknoloji": true, "eglence": true,
		"hizmet": true, "diger": true,
	}
	for kategori, hedefler := range talepHedefKategori {
		for _, h := range hedefler {
			if !gecerli[h] {
				t.Errorf("talep kategorisi %q -> ISLETME KATEGORISI %q "+
					"GECERSIZ.\n"+
					"  Sorgu hic satir dondurmez ve talep SESSIZCE kimseye "+
					"bildirilmez (log bile 'kategori haritada yok' demez).\n"+
					"  Gecerli kume: isletme.Kategoriler.", kategori, h)
			}
		}
	}
}
