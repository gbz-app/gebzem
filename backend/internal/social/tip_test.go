package social

import (
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
)

// ⚠️⚠️ TURU 75 — `uuid[]` <-> `[]string` DONUSUM TESTI.
//
// NEDEN VAR: `posts.media_ids` ve `channel_posts.media_ids` sutunlari **UUID[]**;
// Go tarafinda `[]string`e taraniyor. Tarama BASARISIZ olursa kod
//
//	if rows.Scan(...) != nil { continue }
//
// ile satiri **SESSIZCE ATLAR** -> akis BOMBOS doner ve hicbir hata gorunmez.
// Tam olarak bu projenin "yutulan hata" sinifi. Canli DB olmadan, pgx'in tip
// haritasi uzerinden plan kurulabildigi icin burada KANITLIYORUZ.
//
// ⚠️ YAPMA: `media_ids`i `[]string` disinda bir tipe tarayip bu testi silme.
func TestUUIDDizisiStringDilimineTaranabilir(t *testing.T) {
	m := pgtype.NewMap()

	// --- OKUMA: uuid[] -> []string
	var hedef []string
	plan := m.PlanScan(pgtype.UUIDArrayOID, pgtype.TextFormatCode, &hedef)
	if plan == nil {
		t.Fatal("uuid[] -> []string TARAMA PLANI YOK: akis satirlari sessizce atlanir")
	}
	// pgx metin bicimi dizi soz dizimi: {a,b}
	ham := []byte("{6ba7b810-9dad-11d1-80b4-00c04fd430c8,6ba7b811-9dad-11d1-80b4-00c04fd430c8}")
	if err := plan.Scan(ham, &hedef); err != nil {
		t.Fatalf("uuid[] taranamadi: %v", err)
	}
	if len(hedef) != 2 || hedef[0] != "6ba7b810-9dad-11d1-80b4-00c04fd430c8" {
		t.Fatalf("beklenmeyen sonuc: %#v", hedef)
	}

	// --- BOS DIZI (medyasiz 'yazi' gonderisi) — NULL degil '{}' gelir
	var bos []string
	if err := m.PlanScan(pgtype.UUIDArrayOID, pgtype.TextFormatCode, &bos).
		Scan([]byte("{}"), &bos); err != nil {
		t.Fatalf("bos uuid[] taranamadi: %v", err)
	}
	if len(bos) != 0 {
		t.Fatalf("bos dizi beklenirken %#v geldi", bos)
	}

	// --- YAZMA: []string -> uuid[]  (INSERT ... media_ids = $4)
	kodlama, ok := m.TypeForOID(pgtype.UUIDArrayOID)
	if !ok {
		t.Fatal("uuid[] tipi pgx haritasinda YOK")
	}
	kaynak := []string{"6ba7b810-9dad-11d1-80b4-00c04fd430c8"}
	if _, err := m.Encode(pgtype.UUIDArrayOID, pgtype.TextFormatCode, kaynak, nil); err != nil {
		t.Fatalf("[]string -> uuid[] kodlanamadi (%s): %v", kodlama.Name, err)
	}
}

// ⚠️ `media_ids = ANY($1)` sorgularinda parametre `[]string` gonderiliyor
// (`UPDATE media_assets ... WHERE id = ANY($1)`). O yol da UUID[] kodlamasi
// kullanir; ustteki test onu da kapsar.
//
// Bu test AYRICA `bigint` (post_comments.id, channel_posts.id) icin int64
// donusumunu dogrular — istemci JSON'da sayi olarak okuyor.
func TestBigintInt64Donusumu(t *testing.T) {
	m := pgtype.NewMap()
	var v int64
	plan := m.PlanScan(pgtype.Int8OID, pgtype.TextFormatCode, &v)
	if plan == nil {
		t.Fatal("bigint -> int64 tarama plani YOK")
	}
	if err := plan.Scan([]byte("9007199254740993"), &v); err != nil {
		t.Fatalf("bigint taranamadi: %v", err)
	}
	if v != 9007199254740993 {
		t.Fatalf("beklenen 9007199254740993, gelen %d", v)
	}
}
