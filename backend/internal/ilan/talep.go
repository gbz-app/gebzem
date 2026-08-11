package ilan

import (
	"context"
	"log"
)

// ⚠️⚠️⚠️ TURU 91 — TALEP FAN-OUT: yeni talep ILGILI ISLETMELERE bildirilir.
//
// Kullanici emri: *"bu bilgiler ornegin KUAFORE teklif gidecek, DIGERLERINE
// gidecek, onlar da karsi teklif verecekler"*.
//
// ═══════════ NEDEN "ILGILI" — HERKESE DEGIL ═══════════
//
// Herkese gonderseydik bir dugun talebi eczaneye, otele ve oto servise de
// duserdi; iki tur sonra isletmeler bildirimleri KAPATIRDI ve ozellik OLURDU.
// Hedefleme, talebin KATEGORISINDEN isletme KATEGORISINE bir haritayla yapilir.
//
// ⚠️ HEDEFLEME **YALNIZ BILDIRIMDE**. Teklif verme kapisi kategori
//
//	eslesmesine BAGLI DEGIL: talep herkese acik ve teklif verme sarti
//	"isletme hesabi" olmaktir. Aksi halde harita bir YETKI KAPISINA
//	donusurdu ve haritada olmayan mesru bir isletme (or. "diger"
//	kategorisindeki bir organizatoru) teklif VEREMEZDI.
//
// ⚠️ YENI BIR TALEP KATEGORISI EKLERKEN buraya da giris yaz — yoksa talep
//
//	acilir ama KIMSEYE DUSMEZ ve kullanici "kimse teklif vermiyor" der.
//	(Muhafiz: `talep_test.go`.)
var talepHedefKategori = map[string][]string{
	// ── DUGUN DALI ──
	// ⚠️ Bir talep BIRDEN COK kategoriye duser: dugun organizasyonu isini
	//    hem organizasyoncu hem otel/salon alabilir.
	"dugun_organizasyon": {"eglence", "otel", "yemek"},
	"dugun_mekan":        {"otel", "yemek", "eglence"},
	"dugun_fotograf":     {"eglence", "teknoloji"},
	"gelinlik":           {"giyim"},
	"sac_makyaj":         {"kuafor", "guzellik"},
	"dugun_muzik":        {"eglence"},
	"dugun_pasta":        {"yemek", "kafe"},
	"davetiye":           {"teknoloji", "diger"},
	"gelin_arabasi":      {"oto"},

	// ── HIZMET DALI ──
	"tadilat_talep":   {"hizmet", "teknoloji"},
	"nakliyat_talep":  {"hizmet", "oto"},
	"temizlik_talep":  {"hizmet"},
	"ozel_ders_talep": {"egitim"},
	"diyet_program":   {"diyetisyen", "saglik"},

	// ⚠️ "diger" BILINCLI olarak GENIS: hangi dala girdigi belirsiz bir
	//    talebi hic kimseye gondermemektense, genel hizmet verenlere
	//    gondermek daha iyidir.
	"talep_diger": {"hizmet", "diger"},
}

// ⚠️ Bir talep EN FAZLA kac isletmeye bildirilir.
//
// Gerekce: `bildirim.Bildir` her alici icin DB yazimi + WS yayini + push
// yapiyor. 500 isletmeye fan-out, tek istegin icinde 500 push demekti ve
// `NotifyUsers` FCM'in 500 hedef/istek sinirina dayanirdi (turu 75'te kanal
// push'u TAM BU sebeple ilk surumde YAPILMADI).
// ⚠️ 20 ASILIRSA sessizce kirpilir — ama `log` DUSER. Sessiz kirpma,
//
//	"neden bana gelmedi" sorusunu cevaplanamaz yapardi.
const talepBildirimTavani = 20

// talepBildir — yeni acilan talebi hedef kategorilerdeki isletmelere duyurur.
//
// ⚠️ HATA YUTULUR (log'lanir): bildirim gonderilemedi diye TALEP OLUSTURMA
//
//	basarisiz sayilamaz. Talep kaydi ASIL istir; bildirim yardimcidir ve
//	isletmeler talebi listeden de gorebilir.
//
// ⚠️ `h.bs` NIL olabilir (test/kurulum) — kapi ZORUNLU.
func (h *Handler) talepBildir(ctx context.Context, ilanID, kategori, il, sahip string) {
	if h.bs == nil {
		return
	}
	hedefler, ok := talepHedefKategori[kategori]
	if !ok || len(hedefler) == 0 {
		log.Printf("talep fan-out: `%s` kategorisi HARITADA YOK — kimseye "+
			"bildirilmedi (talepHedefKategori'ye giris ekle)", kategori)
		return
	}

	// ⚠️ TEK SORGU (N+1 YASAK — turu 17 dersi).
	// ⚠️ AYNI IL ONCE: yerel isletme daha alakali. `il` bossa sirasiz.
	// ⚠️ `engelYok` BURADA KULLANILMAZ ve bu BILINCLI: engel iki yonlu bir
	//    SOSYAL kuraldir; talep sahibini engellemis bir isletmeye bildirim
	//    gondermemek icin ek yuklem yazmak yerine, teklif verme yolundaki
	//    `engelYok` zaten o teklifi ENGELLIYOR. Yani en kotu ihtimalle
	//    gereksiz bir bildirim duser, gizlilik ihlali OLMAZ.
	rows, err := h.db.Query(ctx, `
		SELECT i.user_id
		  FROM isletmeler i
		  JOIN users u ON u.id = i.user_id
		 WHERE i.kategori = ANY($1)
		   AND u.hesap_turu = 'isletme'
		   AND i.user_id <> $2
		 ORDER BY CASE WHEN $3 <> '' AND i.il = $3 THEN 0 ELSE 1 END,
		          i.user_id
		 LIMIT $4`, hedefler, sahip, il, talepBildirimTavani+1)
	if err != nil {
		log.Printf("talep fan-out sorgu: %v", err)
		return
	}
	defer rows.Close()

	var alicilar []string
	for rows.Next() {
		var uid string
		if rows.Scan(&uid) != nil {
			continue
		}
		alicilar = append(alicilar, uid)
	}
	if len(alicilar) > talepBildirimTavani {
		log.Printf("talep fan-out: %d isletme uygun, TAVAN %d — kirpildi "+
			"(ilan %s)", len(alicilar), talepBildirimTavani, ilanID)
		alicilar = alicilar[:talepBildirimTavani]
	}
	for _, uid := range alicilar {
		h.bs.Bildir(ctx, uid, sahip, "talep_yeni", "ilan", ilanID)
	}
}
