package diyet

import "strings"

// ⚠️⚠️ TURU 91 — BESIN LISTESI **GO'DA GOMULU**, TABLODA DEGIL.
//
// Gerekce (kategori agacinin turu 77'deki gerekcesiyle AYNI): kucuk, sabit ve
// nadiren degisen bir LOOKUP icin tablo + migration + yonetim ekrani gereksiz
// karmasiklik. Ustelik bu veri KIMSEYE AIT DEGIL — kullanici basina satir
// acmak (or. `isletme_urunleri`) hem YANLIS modelleme olurdu hem de
// `GET /users/{id}/urunler` HERKESE ACIK oldugu icin anlamsiz bir yuzey acardi.
//
// ⚠️ YAPMA: bu listeyi `isletme_urunleri`ne yazma.
// ⚠️ Liste buyurse (>500 kalem) AYRI bir lookup tablosuna tasinir; o zaman da
//
//	kullanici basina satir DEGIL, tek bir referans tablosu olur.
//
// Degerler 100 GRAM icindir (TUBER / USDA yaklasik degerleri).
// ⚠️ TIBBI KESINLIK IDDIASI YOK: bu bir TAHMIN aracidir, diyetisyenin verdigi
//
//	liste esas alinir. Arayuz de bunu soyler.
type Besin struct {
	Ad           string  `json:"ad"`
	Kalori       int     `json:"kalori"`  // kcal / 100 g
	Gram         int     `json:"gram"`    // varsayilan porsiyon (g)
	Protein      float64 `json:"protein"` // g / 100 g
	Karbonhidrat float64 `json:"karbonhidrat"`
	Yag          float64 `json:"yag"`
}

var besinler = []Besin{
	// ── EKMEK & TAHIL ──
	{"Beyaz ekmek", 265, 50, 9.0, 49.0, 3.2},
	{"Tam buğday ekmek", 247, 50, 13.0, 41.0, 3.4},
	{"Simit", 310, 100, 9.5, 55.0, 5.0},
	{"Poğaça", 350, 80, 7.0, 42.0, 17.0},
	{"Beyaz pirinç pilavı", 130, 150, 2.7, 28.0, 0.3},
	{"Bulgur pilavı", 83, 150, 3.1, 18.6, 0.2},
	{"Makarna (haşlanmış)", 131, 150, 5.0, 25.0, 1.1},
	{"Yulaf ezmesi", 389, 40, 16.9, 66.3, 6.9},
	{"Mercimek çorbası", 60, 250, 3.5, 9.0, 1.2},

	// ── ET & PROTEIN ──
	{"Tavuk göğsü (ızgara)", 165, 120, 31.0, 0.0, 3.6},
	{"Tavuk but (ızgara)", 209, 120, 26.0, 0.0, 11.0},
	{"Dana kıyma (yağsız)", 250, 100, 26.0, 0.0, 15.0},
	{"Dana biftek", 271, 150, 25.0, 0.0, 19.0},
	{"Kuzu pirzola", 294, 150, 25.0, 0.0, 21.0},
	{"Köfte", 240, 120, 18.0, 6.0, 16.0},
	{"Somon", 208, 120, 20.0, 0.0, 13.0},
	{"Hamsi", 131, 100, 20.0, 0.0, 4.8},
	{"Levrek", 97, 150, 18.4, 0.0, 2.0},
	{"Ton balığı (konserve)", 116, 80, 26.0, 0.0, 1.0},
	{"Yumurta (haşlanmış)", 155, 50, 13.0, 1.1, 11.0},
	{"Yumurta (omlet)", 154, 100, 11.0, 1.0, 12.0},
	{"Nohut (haşlanmış)", 164, 150, 8.9, 27.4, 2.6},
	{"Kuru fasulye", 127, 150, 8.7, 22.8, 0.5},
	{"Mercimek (haşlanmış)", 116, 150, 9.0, 20.0, 0.4},

	// ── SUT & SUT URUNLERI ──
	{"Süt (yarım yağlı)", 50, 200, 3.4, 4.8, 1.6},
	{"Yoğurt (tam yağlı)", 61, 200, 3.5, 4.7, 3.3},
	{"Yoğurt (light)", 43, 200, 4.4, 5.0, 0.4},
	{"Ayran", 37, 250, 1.7, 2.9, 1.9},
	{"Beyaz peynir", 264, 30, 17.0, 2.0, 21.0},
	{"Kaşar peyniri", 375, 30, 25.0, 1.5, 30.0},
	{"Lor peyniri", 98, 50, 11.0, 3.4, 4.3},
	{"Kefir", 41, 200, 3.3, 4.5, 1.0},

	// ── SEBZE ──
	{"Domates", 18, 100, 0.9, 3.9, 0.2},
	{"Salatalık", 15, 100, 0.7, 3.6, 0.1},
	{"Marul", 15, 80, 1.4, 2.9, 0.2},
	{"Havuç", 41, 100, 0.9, 9.6, 0.2},
	{"Brokoli", 34, 150, 2.8, 6.6, 0.4},
	{"Ispanak", 23, 150, 2.9, 3.6, 0.4},
	{"Patates (haşlanmış)", 87, 150, 1.9, 20.0, 0.1},
	{"Patates kızartması", 312, 100, 3.4, 41.0, 15.0},
	{"Kuru soğan", 40, 50, 1.1, 9.3, 0.1},
	{"Biber (yeşil)", 20, 100, 0.9, 4.6, 0.2},
	{"Patlıcan", 25, 150, 1.0, 5.9, 0.2},
	{"Kabak", 17, 150, 1.2, 3.1, 0.3},

	// ── MEYVE ──
	{"Elma", 52, 150, 0.3, 14.0, 0.2},
	{"Muz", 89, 120, 1.1, 23.0, 0.3},
	{"Portakal", 47, 150, 0.9, 12.0, 0.1},
	{"Mandalina", 53, 100, 0.8, 13.3, 0.3},
	{"Üzüm", 69, 100, 0.7, 18.0, 0.2},
	{"Çilek", 32, 150, 0.7, 7.7, 0.3},
	{"Karpuz", 30, 200, 0.6, 7.6, 0.2},
	{"Kavun", 34, 200, 0.8, 8.2, 0.2},
	{"Şeftali", 39, 150, 0.9, 9.5, 0.3},
	{"Armut", 57, 150, 0.4, 15.0, 0.1},
	{"Kayısı (kuru)", 241, 30, 3.4, 63.0, 0.5},
	{"Hurma", 277, 30, 1.8, 75.0, 0.2},

	// ── KURUYEMIS & YAG ──
	{"Ceviz", 654, 30, 15.0, 14.0, 65.0},
	{"Badem", 579, 30, 21.0, 22.0, 50.0},
	{"Fındık", 628, 30, 15.0, 17.0, 61.0},
	{"Fıstık", 567, 30, 26.0, 16.0, 49.0},
	{"Zeytin (siyah)", 115, 30, 0.8, 6.3, 11.0},
	{"Zeytinyağı", 884, 10, 0.0, 0.0, 100.0},
	{"Tereyağı", 717, 10, 0.9, 0.1, 81.0},
	{"Tahin", 595, 20, 17.0, 21.0, 54.0},

	// ── HAZIR & TATLI ──
	{"Pide (kıymalı)", 275, 200, 12.0, 33.0, 10.0},
	{"Lahmacun", 240, 120, 11.0, 30.0, 8.0},
	{"Döner (et)", 290, 150, 20.0, 12.0, 18.0},
	{"Tavuk döner", 220, 150, 22.0, 12.0, 10.0},
	{"Hamburger", 295, 200, 17.0, 24.0, 14.0},
	{"Pizza (dilim)", 266, 100, 11.0, 33.0, 10.0},
	{"Baklava", 428, 60, 6.0, 50.0, 23.0},
	{"Sütlaç", 143, 150, 3.5, 24.0, 3.5},
	{"Künefe", 380, 100, 8.0, 45.0, 19.0},
	{"Çikolata (sütlü)", 535, 30, 7.6, 59.0, 30.0},
	{"Bisküvi", 480, 30, 6.0, 65.0, 21.0},
	{"Cips", 536, 30, 7.0, 53.0, 35.0},

	// ── ICECEK ──
	{"Çay (şekersiz)", 1, 200, 0.0, 0.2, 0.0},
	{"Türk kahvesi (sade)", 2, 60, 0.1, 0.3, 0.0},
	{"Kola", 42, 330, 0.0, 10.6, 0.0},
	{"Meyve suyu (portakal)", 45, 200, 0.7, 10.4, 0.2},
	{"Limonata", 40, 250, 0.1, 10.0, 0.0},
	{"Şalgam suyu", 13, 200, 0.4, 2.6, 0.1},
}

// Ara — besin adinda GECEN kalemleri dondurur.
//
// ⚠️ TURKCE KUCULTME: `strings.ToLower` Turkce'de YANLIS calisir —
//
//	"İ" -> "i̇" (birlesik nokta) ve "I" -> "i" olur, yani "İSPANAK" araması
//	"ispanak"i BULAMAZ. Bu yuzden Turkce'ye ozgu harfler ELLE eslenir.
//	Bu proje `unicode/cases` bagimliligi eklemek istemiyor; kucuk bir
//	yardimci yeterli.
func Ara(q string) []Besin {
	q = trKucult(strings.TrimSpace(q))
	if q == "" {
		// ⚠️ Bos aramada ILK 30 kalem doner (bos ekran YERINE oneri).
		if len(besinler) > 30 {
			return besinler[:30]
		}
		return besinler
	}
	out := []Besin{}
	for _, b := range besinler {
		if strings.Contains(trKucult(b.Ad), q) {
			out = append(out, b)
			if len(out) >= 40 {
				break
			}
		}
	}
	return out
}

func trKucult(s string) string {
	var sb strings.Builder
	for _, r := range s {
		switch r {
		case 'I':
			sb.WriteRune('ı')
		case 'İ':
			sb.WriteRune('i')
		case 'Ş':
			sb.WriteRune('ş')
		case 'Ğ':
			sb.WriteRune('ğ')
		case 'Ü':
			sb.WriteRune('ü')
		case 'Ö':
			sb.WriteRune('ö')
		case 'Ç':
			sb.WriteRune('ç')
		default:
			if r >= 'A' && r <= 'Z' {
				sb.WriteRune(r + 32)
			} else {
				sb.WriteRune(r)
			}
		}
	}
	return sb.String()
}
