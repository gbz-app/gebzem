package isletme

import (
	"encoding/json"

	"github.com/jackc/pgx/v5"
)

// ⚠️⚠️⚠️ TURU 94 — ISLETME KARTI SORGUSU **TEK KAYNAK**.
//
// Kategori/rehber listesi (`Liste`) ve favori listesi (`Favorilerim`) AYNI
// karti ciziyor, yani AYNI sutunlari dondurmek ZORUNDA. Sorgu iki yere
// kopyalansaydi biri guncellenip oteki geride kalirdi ve favori ekraninda
// puan/teslimat/kampanya SESSIZCE kaybolurdu — bu projede "ayni kuralin iki
// kopyasi drift eder" sinifi ALTI kez sahaya cikti.
//
// ⚠️ YAPMA: bu iki sabiti/fonksiyonu cagri yerlerine kopyalama. Yeni sutun
//
//	eklerken UCUNU BIRLIKTE guncelle: `isletmeSutunlari` · `isletmeSatiri`
//	Scan sirasi · `isletmeSatiri` yanit haritasi.
//	(`sutun_test.go` ucunu de olcer ve bozulunca KIRMIZI duser.)
//
// ⚠️ `u.` ve `i.` takma adlari SABIT: cagiran sorgular `users u` ve
//
//	`isletmeler i` ile JOIN yapmak ZORUNDA.
const isletmeSutunlari = `
		u.id, u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
		i.kategori, i.il, i.ilce, i.adres, u.onayli, u.kapak_media_id,
		i.calisma,
		(SELECT min(p.fiyat_kurus) FROM isletme_urunleri p
		  WHERE p.isletme_id = u.id AND p.durum = 'yayinda'
		    AND p.fiyat_kurus > 0),
		(SELECT count(*) FROM isletme_urunleri p
		  WHERE p.isletme_id = u.id AND p.durum <> 'kaldirildi'),
		i.min_tutar_kurus, i.teslimat_dk_min, i.teslimat_dk_max,
		i.puan, i.puan_sayisi, i.kampanyalar`

// isletmeSatiri — bir satiri okur ve istemci sozlesmesine cevirir.
//
// ⚠️ Hata YUTULMAZ, DONDURULUR: cagiran taraf logluyor. Sessiz `continue`,
//
//	SELECT/Scan ayrisinca listeyi HICBIR IZ BIRAKMADAN bosaltirdi
//	(turu 76 "Kaydedilenler BOMBOS" sinifi).
func isletmeSatiri(rows pgx.Rows) (map[string]any, error) {
	var id, ad, kullanici, avatar, kat, il, ilce, adres string
	var medya, kapak *string
	var dogru bool
	var calisma []byte
	var minFiyat *int64
	var urunSayisi int
	var minTutar *int64
	var teslimatMin, teslimatMax *int
	var puan *float64
	var puanSayisi int
	var kampanyalar []byte
	if err := rows.Scan(&id, &ad, &kullanici, &avatar, &medya,
		&kat, &il, &ilce, &adres, &dogru, &kapak,
		&calisma, &minFiyat, &urunSayisi,
		&minTutar, &teslimatMin, &teslimatMax,
		&puan, &puanSayisi, &kampanyalar); err != nil {
		return nil, err
	}
	return map[string]any{
		"id": id, "name": ad, "username": kullanici,
		"avatar_url": avatar, "avatar_media_id": medya,
		"kategori": kat, "kategori_ad": Kategoriler[kat],
		"il": il, "ilce": ilce, "adres": adres, "dogrulandi": dogru,
		"kapak_media_id":  kapak,
		"calisma":         json.RawMessage(calisma),
		"min_fiyat_kurus": minFiyat,
		"urun_sayisi":     urunSayisi,
		"min_tutar_kurus": minTutar,
		"teslimat_dk_min": teslimatMin,
		"teslimat_dk_max": teslimatMax,
		"puan":            puan,
		"puan_sayisi":     puanSayisi,
		"kampanyalar":     json.RawMessage(kampanyalar),
	}, nil
}

// favoriSatir — `Favorilerim` icin okunur; favori listesindeki her satir
// tanim geregi favoridir, o yuzden `favorim: true` eklenir.
//
// ⚠️ Bayrak SUNUCUDAN gelir: istemci "bu ekrandayim, demek ki favoridir"
//
//	varsayimi yapsaydi ayni kart baska bir ekranda BOS kalp cizerdi.
func favoriSatir(rows pgx.Rows) (map[string]any, error) {
	m, err := isletmeSatiri(rows)
	if err != nil {
		return nil, err
	}
	m["favorim"] = true
	return m, nil
}
