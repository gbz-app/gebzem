package database

import (
	"context"
	"os"
	"testing"
	"time"
)

// ⚠️⚠️⚠️ TURU 181 — MIGRATION MUHAFIZI (canli DB'ye DOKUNMAZ).
//
//	NEDEN VAR: bu projede migration hatalari **YALNIZ GERCEK POSTGRES'TE**
//	ortaya cikiyor. `go build` + `go vet` + `flutter analyze` UCU DE temiz
//	gecti, hata acilista API'yi oldurdu:
//	  · turu 78: `media_assets.kind` CHECK'i `'kapak'` kabul etmiyordu ->
//	    presign HER SEFERINDE 500 = kapak ozelligi **%100 OLU DOGACAKTI**.
//	  · ayni turda `ai_istekleri.durum` CHECK'i `'iptal'` kabul etmiyordu.
//	  · turu 89: `tur`/`ozellikler` sutunlari CRLF yuzunden UYGULANMAMIS,
//	    derleme yine de gecmisti.
//
//	CLAUDE.md o gunden beri *"deploy ONCESI atilabilir kopya DB'de tum
//	migration'lari sirayla uygula"* diyor — ama bu kural **YALNIZCA
//	DUZYAZIYDI**, hicbir sey onu zorlamiyordu ve elle atlanabiliyordu.
//
// ⚠️⚠️ AYRI BIR `psql` BETIGI YAZILMADI (bilincli): o, migration
//	kosucusunun **IKINCI BIR KOPYASI** olurdu (sirala -> uygula -> isaretle)
//	ve bu projede "ayni kuralin iki kopyasi drift eder" sinifi ALTI kez
//	sahaya cikti. Test URETIMDEKI `Migrate()`in TA KENDISINI cagirir.
//
// ⚠️ `GEBZEM_TEST_DB` YOKSA **SKIP** eder: yerelde `go test ./...`
//	kosanin Postgres kurmasi gerekmesin. CI o degiskeni verir (bkz.
//	`.github/workflows/backend.yml`), yani kural ORADA zorlanir.
// ⚠️ YAPMA: bu testi canli veritabanina baglama (`Migrate` gercek semayi
//	degistirir). CI atilabilir bir servis konteyneri kullanir.
func TestMigrationlarTemizSemadaUygulanir(t *testing.T) {
	url := os.Getenv("GEBZEM_TEST_DB")
	if url == "" {
		t.Skip("GEBZEM_TEST_DB yok — migration muhafizi ATLANDI (CI'da kosar)")
	}
	ctx, iptal := context.WithTimeout(context.Background(), 3*time.Minute)
	defer iptal()

	havuz, err := Connect(ctx, url)
	if err != nil {
		t.Fatalf("baglanti: %v", err)
	}
	defer havuz.Close()

	// ⚠️ TEMIZ SEMA SART: mevcut bir semanin uzerine uygulamak, "bu
	//	migration SIFIRDAN calisir mi" sorusunu YANITLAMAZ (canlida
	//	sutun zaten varken `ADD COLUMN IF NOT EXISTS` sessizce gecer).
	if _, err := havuz.Exec(ctx, `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`); err != nil {
		t.Fatalf("sema sifirlama: %v", err)
	}

	if err := Migrate(ctx, havuz); err != nil {
		t.Fatalf("MIGRATION PATLADI: %v", err)
	}

	// ⚠️ IKINCI KOSU **NO-OP OLMALI**: `Migrate` her acilista kosuyor;
	//	bir dosya idempotent degilse sunucu ikinci restart'ta OLURDU.
	if err := Migrate(ctx, havuz); err != nil {
		t.Fatalf("IKINCI KOSU PATLADI (migration idempotent DEGIL): %v", err)
	}

	var tablo, uygulanan int
	if err := havuz.QueryRow(ctx,
		`SELECT count(*) FROM information_schema.tables
		  WHERE table_schema='public' AND table_type='BASE TABLE'`).Scan(&tablo); err != nil {
		t.Fatalf("tablo sayimi: %v", err)
	}
	if err := havuz.QueryRow(ctx,
		`SELECT count(*) FROM schema_migrations`).Scan(&uygulanan); err != nil {
		t.Fatalf("migration sayimi: %v", err)
	}

	// ⚠️ Dosya sayisiyla KARSILASTIRILIR: bir migration sessizce
	//	atlanirsa (CRLF/embed hatasi — turu 89'da YASANDI) sayi tutmaz.
	girdiler, err := migrationFS.ReadDir("migrations")
	if err != nil {
		t.Fatalf("migrations klasoru okunamadi: %v", err)
	}
	if uygulanan != len(girdiler) {
		t.Fatalf("migration sayisi TUTMUYOR: dosya=%d uygulanan=%d", len(girdiler), uygulanan)
	}
	if tablo < 40 {
		t.Fatalf("tablo sayisi bekleneninden az: %d (sema eksik uygulanmis olabilir)", tablo)
	}
	t.Logf("migration %d dosya · %d tablo · ikinci kosu no-op", uygulanan, tablo)
}
