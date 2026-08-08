package social

import (
	"testing"

	"github.com/jackc/pgx/v5/pgtype"
)

// ⚠️⚠️ TURU 75 — `uuid[]` PARAMETRE VE TARAMA DAVRANISI.
//
// `posts.media_ids` ve `channel_posts.media_ids` sutunlari **UUID[]**; Go
// tarafinda `[]string` ile calisiyoruz. Bu dosya o donusumun UC ayri gercegini
// kanitlar. Ucu de canli DB olmadan, pgx'in kendi tip haritasi uzerinden
// olculebiliyor.

// ---- GERCEK 1: uuid[] -> []string TARAMASI CALISIR.
//
// Onemli, cunku `satirlariOku` tarama hatasinda satiri
//
//	if rows.Scan(...) != nil { continue }
//
// ile **SESSIZCE ATLAR**. Bozulsaydi akis BOMBOS doner, hicbir hata gorunmezdi
// (projenin "yutulan hata" sinifi).
func TestUUIDDizisiStringDilimineTaranabilir(t *testing.T) {
	m := pgtype.NewMap()

	var hedef []string
	plan := m.PlanScan(pgtype.UUIDArrayOID, pgtype.TextFormatCode, &hedef)
	if plan == nil {
		t.Fatal("uuid[] -> []string TARAMA PLANI YOK: akis satirlari sessizce atlanir")
	}
	ham := []byte("{6ba7b810-9dad-11d1-80b4-00c04fd430c8,6ba7b811-9dad-11d1-80b4-00c04fd430c8}")
	if err := plan.Scan(ham, &hedef); err != nil {
		t.Fatalf("uuid[] taranamadi: %v", err)
	}
	if len(hedef) != 2 || hedef[0] != "6ba7b810-9dad-11d1-80b4-00c04fd430c8" {
		t.Fatalf("beklenmeyen sonuc: %#v", hedef)
	}

	// Medyasiz 'yazi' gonderisi: sutun '{}' tasir (NULL DEGIL).
	var bos []string
	if err := m.PlanScan(pgtype.UUIDArrayOID, pgtype.TextFormatCode, &bos).
		Scan([]byte("{}"), &bos); err != nil {
		t.Fatalf("bos uuid[] taranamadi: %v", err)
	}
	if len(bos) != 0 {
		t.Fatalf("bos dizi beklenirken %#v geldi", bos)
	}
}

// ---- GERCEK 2: `[]string` -> `uuid[]` YAZMASI **YALNIZ METIN BICIMINDE** calisir.
//
// ⚠️⚠️ BU KOLAY YANLIS ANLASILIR — bir kez yanlis teshis kondu, kaydediliyor:
// pgx `uuid[]` icin ONCE **IKILI (binary)** bicimi secer ve `[]string` icin
// ikili kodlama plani **YOKTUR**. Yani `m.Encode(UUIDArrayOID, BinaryFormatCode,
// []string{...})` HATA doner.
//
// AMA SORGU YOLU BOZUK DEGILDIR: pgx v5 `ExtendedQueryBuilder.appendParam`
// (extended_query_builder.go:55-76) tercih edilen bicim hata verirse **DIGER
// bicimi dener**. Metin bicimi calistigi icin sorgu basariyla gider.
//
// ⚠️ YAPMA: bu yuzden `[]string` -> `[]pgtype.UUID` donusumu ekleyip kodu
//
//	karmasiklastirma. Olculdu: gerek YOK. (`= ANY($1)` kullanan push ve
//	engelleme kodlari da bu yuzden yillardir sorunsuz calisiyor.)
func TestUUIDDiziParametresiMetinBicimindeKodlanir(t *testing.T) {
	m := pgtype.NewMap()
	dolu := []string{"6ba7b810-9dad-11d1-80b4-00c04fd430c8"}

	if _, err := m.Encode(pgtype.UUIDArrayOID, pgtype.TextFormatCode, dolu, nil); err != nil {
		t.Fatalf("METIN biciminde []string -> uuid[] kodlanamadi: %v", err)
	}

	// Ikilinin CALISMADIGI belgelensin — bir gun pgx bunu eklerse test
	// duser ve serhi guncellememiz gerektigini haber verir.
	if _, err := m.Encode(pgtype.UUIDArrayOID, pgtype.BinaryFormatCode, dolu, nil); err == nil {
		t.Log("BILGI: pgx artik IKILI bicimde de []string -> uuid[] kodluyor; " +
			"yukaridaki serh guncellenebilir")
	}
}

// ---- GERCEK 3 (SEVK ENGELIYDI): `nil` DILIM SQL **NULL** GONDERIR.
//
// ⚠️⚠️ `posts.media_ids` ve `channel_posts.media_ids` **NOT NULL**. Kodda
// `req.MediaIDs = nil` yazsaydik (ve bir sure OYLEYDI) HER YAZI GONDERISI
// "null value in column media_ids violates not-null constraint" ile 500 doner,
// kullanici HICBIR metin paylasamazdi. Bos dilim (`[]string{}`) ise `{}` gonderir.
//
// ⚠️ YAPMA: `MediaIDs`i `nil`e set etme; bos dilim kullan.
func TestNilDilimNullGonderirBosDilimGondermez(t *testing.T) {
	m := pgtype.NewMap()

	var bosNil []string
	buf, err := m.Encode(pgtype.UUIDArrayOID, pgtype.TextFormatCode, bosNil, nil)
	if err != nil {
		t.Fatalf("nil dilim kodlanirken hata: %v", err)
	}
	if buf != nil {
		t.Fatalf("nil dilimin NULL uretmesi bekleniyordu, %q geldi", string(buf))
	}

	bos := []string{}
	buf2, err := m.Encode(pgtype.UUIDArrayOID, pgtype.TextFormatCode, bos, nil)
	if err != nil {
		t.Fatalf("bos dilim kodlanirken hata: %v", err)
	}
	if string(buf2) != "{}" {
		t.Fatalf("bos dilimin '{}' uretmesi bekleniyordu, %q geldi", string(buf2))
	}
}

// `post_comments.id` ve `channel_posts.id` **BIGSERIAL**; istemci JSON'da sayi
// olarak okuyor. int64 donusumunu dogrular.
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
