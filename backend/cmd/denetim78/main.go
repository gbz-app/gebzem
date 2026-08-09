// GECICI denetim aracidir — turu 78 SQL yollarini GERCEK pgx tipleriyle kosturur.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

var db *pgxpool.Pool
var ctx = context.Background()
var basarisiz int

func kontrol(ad string, err error) {
	if err != nil {
		basarisiz++
		fmt.Printf("!!! PATLADI  %s\n      %v\n", ad, err)
	} else {
		fmt.Printf("ok           %s\n", ad)
	}
}

func main() {
	var err error
	db, err = pgxpool.New(ctx, os.Getenv("DB"))
	if err != nil {
		panic(err)
	}
	defer db.Close()

	// ── hazirlik: kullanici + medya + ilan + etkinlik ────────────────────
	var me string
	err = db.QueryRow(ctx, `INSERT INTO users (phone,password_hash,name,verified)
		VALUES ('+9055511'||floor(random()*100000)::text,'x','Deneme',true) RETURNING id`).Scan(&me)
	kontrol("hazirlik: kullanici", err)

	var foto, video string
	kontrol("hazirlik: foto", db.QueryRow(ctx, `INSERT INTO media_assets (owner_id,kind,mime,object_key,bytes,status)
		VALUES ($1,'image','image/jpeg','k1-'||gen_random_uuid()::text,10,'aktif') RETURNING id`, me).Scan(&foto))
	kontrol("hazirlik: video", db.QueryRow(ctx, `INSERT INTO media_assets (owner_id,kind,mime,object_key,bytes,status)
		VALUES ($1,'video','video/mp4','k2-'||gen_random_uuid()::text,10,'aktif') RETURNING id`, me).Scan(&video))
	fmt.Printf("             medya foto=%s video=%s\n", foto[:8], video[:8])

	var ilanID string
	err = db.QueryRow(ctx, `INSERT INTO ilanlar
		(sahibi_id,tur,kategori,baslik,aciklama,fiyat_kurus,fiyat_gizli,il,ilce,media_ids,ozellikler)
		VALUES ($1,'vasita','otomobil','Araba','aciklama',100,false,'Kocaeli','Gebze',$2,$3)
		RETURNING id`, me, []string{foto, video}, []byte(`{"marka":"BMW"}`)).Scan(&ilanID)
	kontrol("hazirlik: ilan (media_ids []string -> uuid[])", err)

	var etkID string
	err = db.QueryRow(ctx, `INSERT INTO etkinlikler
		(olusturan_id,baslik,aciklama,kategori,baslangic,bitis,konum,il,ilce,enlem,boylam,
		 media_ids,ucretsiz,fiyat_kurus,kontenjan)
		VALUES ($1,'Konser','a','konser',now()+interval '3 day',now()+interval '4 day',
		        'Salon','Kocaeli','Gebze',40.8,29.4,$2,true,0,100) RETURNING id`,
		me, []string{foto, video}).Scan(&etkID)
	kontrol("hazirlik: etkinlik", err)

	// ═══════════ (B) media_kinds ALT SORGUSU — SIRA KORUNUYOR MU ═══════════
	var kinds []string
	var ids []string
	err = db.QueryRow(ctx, `
		SELECT i.media_ids,
		  COALESCE((SELECT array_agg(COALESCE(ma.kind,'yok') ORDER BY mm.idx)
		              FROM unnest(i.media_ids) WITH ORDINALITY AS mm(mid, idx)
		              LEFT JOIN media_assets ma ON ma.id = mm.mid), '{}')
		 FROM ilanlar i WHERE i.id=$1`, ilanID).Scan(&ids, &kinds)
	kontrol("ilan media_kinds alt sorgusu", err)
	fmt.Printf("             ids=%v kinds=%v\n", kisa(ids), kinds)
	if len(kinds) == 2 && kinds[0] == "image" && kinds[1] == "video" {
		fmt.Println("             SIRA DOGRU (image,video)")
	} else {
		basarisiz++
		fmt.Println("!!!          SIRA YANLIS")
	}

	// silinmis medya -> 'yok' (NULL degil) dogrulamasi
	var kinds2 []string
	err = db.QueryRow(ctx, `
		SELECT COALESCE((SELECT array_agg(COALESCE(ma.kind,'yok') ORDER BY mm.idx)
		            FROM unnest($1::uuid[]) WITH ORDINALITY AS mm(mid, idx)
		            LEFT JOIN media_assets ma ON ma.id = mm.mid), '{}')`,
		[]string{foto, "00000000-0000-0000-0000-000000000000"}).Scan(&kinds2)
	kontrol("silinmis medya -> 'yok'", err)
	fmt.Printf("             kinds=%v\n", kinds2)

	// ═══════════ (B) ilan.Guncelle — TAM DEYIM, GERCEK TIPLER ═══════════
	tamGuncelle := `
		UPDATE ilanlar SET
		  durum       = COALESCE($3, durum),
		  baslik      = COALESCE($4, baslik),
		  aciklama    = COALESCE($5, aciklama),
		  fiyat_kurus = COALESCE($6, fiyat_kurus),
		  fiyat_gizli = COALESCE($7, fiyat_gizli),
		  kategori    = COALESCE($8, kategori),
		  il          = COALESCE($9, il),
		  ilce        = COALESCE($10, ilce),
		  media_ids   = COALESCE($11, media_ids),
		  ozellikler  = COALESCE($12::jsonb, ozellikler),
		  duzenlendi_at = CASE WHEN $13 THEN now() ELSE duzenlendi_at END,
		  updated_at  = now()
		 WHERE id=$1 AND sahibi_id=$2`

	// (1) HEPSI NIL (yalniz durum) — en sik cagri
	yeni := "satildi"
	_, err = db.Exec(ctx, tamGuncelle, ilanID, me, &yeni,
		(*string)(nil), (*string)(nil), (*int64)(nil), (*bool)(nil),
		(*string)(nil), (*string)(nil), (*string)(nil),
		(*[]string)(nil), (*[]byte)(nil), false)
	kontrol("ilan.Guncelle — yalniz durum (tum isaretciler nil)", err)

	// (2) TAM guncelleme
	s := func(v string) *string { return &v }
	i64 := func(v int64) *int64 { return &v }
	b := func(v bool) *bool { return &v }
	mids := []string{video, foto}
	oz := []byte(`{"marka":"Audi","yil":2020}`)
	_, err = db.Exec(ctx, tamGuncelle, ilanID, me, s("yayinda"), s("Yeni baslik"),
		s("yeni aciklama"), i64(9900), b(true), s("suv"), s("Izmir"), s("Bornova"),
		&mids, &oz, true)
	kontrol("ilan.Guncelle — TAM (media_ids *[]string, ozellikler *[]byte)", err)

	// (3) BOS media_ids dilimi (nil DEGIL) — NOT NULL sutun
	bos := []string{}
	_, err = db.Exec(ctx, tamGuncelle, ilanID, me, (*string)(nil), (*string)(nil),
		(*string)(nil), (*int64)(nil), (*bool)(nil), (*string)(nil), (*string)(nil),
		(*string)(nil), &bos, (*[]byte)(nil), true)
	kontrol("ilan.Guncelle — BOS media_ids dilimi", err)

	// (4) ⚠️ nil DILIM (isaretci dolu ama dilim nil) -> SQL NULL -> NOT NULL ihlali?
	var nilDilim []string
	_, err = db.Exec(ctx, tamGuncelle, ilanID, me, (*string)(nil), (*string)(nil),
		(*string)(nil), (*int64)(nil), (*bool)(nil), (*string)(nil), (*string)(nil),
		(*string)(nil), &nilDilim, (*[]byte)(nil), true)
	fmt.Printf("             [bilgi] *[]string(nil icerik) sonucu: %v\n", err)

	var kalanMedya []string
	db.QueryRow(ctx, `SELECT media_ids FROM ilanlar WHERE id=$1`, ilanID).Scan(&kalanMedya)
	fmt.Printf("             ilan media_ids simdi=%d oge\n", len(kalanMedya))

	// ═══════════ (B) etkinlik.Guncelle — bitis CASE ═══════════
	etkGuncelle := `
		UPDATE etkinlikler SET
		  baslik      = COALESCE($3, baslik),
		  aciklama    = COALESCE($4, aciklama),
		  kategori    = COALESCE($5, kategori),
		  baslangic   = COALESCE($6, baslangic),
		  bitis       = CASE WHEN $7::text IS NULL THEN bitis ELSE $8 END,
		  konum       = COALESCE($9, konum),
		  il          = COALESCE($10, il),
		  ilce        = COALESCE($11, ilce),
		  media_ids   = COALESCE($12, media_ids),
		  ucretsiz    = COALESCE($13, ucretsiz),
		  fiyat_kurus = COALESCE($14, fiyat_kurus),
		  kontenjan   = COALESCE($15, kontenjan),
		  updated_at  = now()
		 WHERE id=$1 AND olusturan_id=$2 AND durum<>'silindi'`

	// bitis GONDERILMEDI -> korunmali
	_, err = db.Exec(ctx, etkGuncelle, etkID, me, s("Yeni ad"), nil, nil, nil,
		(*string)(nil), nil, nil, nil, nil, (*[]string)(nil), nil, nil, nil)
	kontrol("etkinlik.Guncelle — bitis gonderilmedi", err)
	var bitisVar bool
	db.QueryRow(ctx, `SELECT bitis IS NOT NULL FROM etkinlikler WHERE id=$1`, etkID).Scan(&bitisVar)
	fmt.Printf("             bitis korundu mu = %v (true bekleniyor)\n", bitisVar)

	// bitis BOS DIZE -> NULL yazilmali
	_, err = db.Exec(ctx, etkGuncelle, etkID, me, nil, nil, nil, nil,
		s(""), nil, nil, nil, nil, (*[]string)(nil), nil, nil, nil)
	kontrol("etkinlik.Guncelle — bitis='' (kaldir)", err)
	db.QueryRow(ctx, `SELECT bitis IS NOT NULL FROM etkinlikler WHERE id=$1`, etkID).Scan(&bitisVar)
	fmt.Printf("             bitis simdi dolu mu = %v (false bekleniyor)\n", bitisVar)

	// ═══════════ (B) vitrin sorgulari ═══════════
	_, err = db.Exec(ctx, `
		SELECT u.id, u.name, COALESCE(i.ilce,''), u.avatar_media_id
		  FROM isletmeler i JOIN users u ON u.id = i.user_id
		 WHERE u.hesap_turu='isletme' AND ($2 = '' OR i.kategori = $2)
		   AND u.avatar_media_id IS NOT NULL
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		            OR (b.blocker_id=u.id AND b.blocked_id=$1))
		 ORDER BY u.onayli DESC, u.name ASC LIMIT 6`, me, "yemek")
	kontrol("vitrin.isletmeler", err)

	var vid, vbas, vkonum string
	var vmedya *string
	err = db.QueryRow(ctx, `
		SELECT e.id, e.baslik, COALESCE(e.konum,''), e.media_ids[1]
		  FROM etkinlikler e
		 WHERE e.durum='yayinda' AND e.baslangic > now()
		   AND array_length(e.media_ids, 1) >= 1
		   AND NOT EXISTS(SELECT 1 FROM blocks b
		         WHERE (b.blocker_id=$1 AND b.blocked_id=e.olusturan_id)
		            OR (b.blocker_id=e.olusturan_id AND b.blocked_id=$1))
		 ORDER BY e.baslangic ASC LIMIT 6`, me).Scan(&vid, &vbas, &vkonum, &vmedya)
	kontrol("vitrin.etkinlikler (media_ids[1] -> *string)", err)
	fmt.Printf("             slayt medya=%v\n", vmedya != nil)

	// media_ids BOS olan etkinlik eleniyor mu?
	db.Exec(ctx, `UPDATE etkinlikler SET media_ids='{}' WHERE id=$1`, etkID)
	var adet int
	db.QueryRow(ctx, `SELECT count(*) FROM etkinlikler e
	  WHERE array_length(e.media_ids,1) >= 1`).Scan(&adet)
	fmt.Printf("             bos media_ids elenen sonrasi adet=%d (0 bekleniyor)\n", adet)
	db.Exec(ctx, `UPDATE etkinlikler SET media_ids=$2 WHERE id=$1`, etkID, []string{foto})

	// ═══════════ (B) isletme.Liste — (NOT $6 OR u.onayli) ═══════════
	for _, onayliMi := range []bool{false, true} {
		_, err = db.Exec(ctx, `
			SELECT u.id, u.name, COALESCE(u.username,''), u.avatar_url, u.avatar_media_id,
			       i.kategori, i.il, i.ilce, i.adres, u.onayli
			  FROM isletmeler i JOIN users u ON u.id = i.user_id
			 WHERE u.hesap_turu='isletme'
			   AND ($2 = '' OR i.kategori = $2)
			   AND ($3 = '' OR i.il ILIKE $3)
			   AND ($4 = '' OR u.name ILIKE '%'||$4||'%' OR COALESCE(u.username,'') ILIKE '%'||$4||'%')
			   AND ($5 = '' OR i.ilce ILIKE $5)
			   AND (NOT $6 OR u.onayli)
			   AND NOT EXISTS(SELECT 1 FROM blocks b
			         WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
			            OR (b.blocker_id=u.id AND b.blocked_id=$1))
			 ORDER BY u.onayli DESC, u.name ASC LIMIT 60`,
			me, "", "", "", "", onayliMi)
		kontrol(fmt.Sprintf("isletme.Liste (dogrulandi=%v)", onayliMi), err)
	}

	// ═══════════ etkinlik.Liste — bas_min/bas_maks ═══════════
	for _, c := range [][2]string{{"", ""}, {"2026-08-01T00:00:00Z", ""},
		{"", "2026-12-01T00:00:00Z"}, {"2026-08-01T00:00:00Z", "2026-12-01T00:00:00Z"}} {
		for tekrar := 0; tekrar < 7; tekrar++ { // 5+ = generic plana gecis
			_, err = db.Exec(ctx, `
				SELECT e.id FROM etkinlikler e JOIN users u ON u.id=e.olusturan_id
				 WHERE e.durum='yayinda' AND e.baslangic >= now()
				   AND ($2 = '' OR e.kategori = $2)
				   AND ($3 = '' OR e.il ILIKE $3)
				   AND ($4 = '' OR e.baslik ILIKE '%'||$4||'%' OR e.aciklama ILIKE '%'||$4||'%')
				   AND ($5 = '' OR e.baslangic >= $5::timestamptz)
				   AND ($6 = '' OR e.baslangic <= $6::timestamptz)
				   AND NOT EXISTS(SELECT 1 FROM blocks b
				         WHERE (b.blocker_id=$1 AND b.blocked_id=e.olusturan_id)
				            OR (b.blocker_id=e.olusturan_id AND b.blocked_id=$1))
				 ORDER BY e.baslangic ASC LIMIT 60`, me, "", "", "", c[0], c[1])
			if err != nil {
				break
			}
		}
		kontrol(fmt.Sprintf("etkinlik.Liste bas_min=%q bas_maks=%q (7 kez)", c[0], c[1]), err)
	}

	// ═══════════ kadro — ON CONFLICT kismi index ═══════════
	kadroSQL := `
		INSERT INTO etkinlik_kadro (etkinlik_id, user_id, ad, rol, sira)
		SELECT $1,$2,$3,$4,$5
		 WHERE EXISTS(SELECT 1 FROM etkinlikler
		               WHERE id=$1 AND olusturan_id=$6 AND durum<>'silindi')
		ON CONFLICT (etkinlik_id, user_id) WHERE user_id IS NOT NULL
		DO UPDATE SET rol=EXCLUDED.rol, sira=EXCLUDED.sira
		RETURNING id`
	var kid string
	err = db.QueryRow(ctx, kadroSQL, etkID, (*string)(nil), "Tarkan", "Sanatci", 0, me).Scan(&kid)
	kontrol("kadro ekle — KAYITSIZ kisi (user_id NULL)", err)
	err = db.QueryRow(ctx, kadroSQL, etkID, (*string)(nil), "Sezen", "Sanatci", 1, me).Scan(&kid)
	kontrol("kadro ekle — ikinci KAYITSIZ kisi (ayni ad degil)", err)
	err = db.QueryRow(ctx, kadroSQL, etkID, &me, "Deneme", "Konusmaci", 2, me).Scan(&kid)
	kontrol("kadro ekle — KAYITLI kisi", err)
	err = db.QueryRow(ctx, kadroSQL, etkID, &me, "Deneme", "DJ", 3, me).Scan(&kid)
	kontrol("kadro ekle — AYNI kayitli kisi TEKRAR (DO UPDATE)", err)

	var kadroAdet int
	db.QueryRow(ctx, `SELECT count(*) FROM etkinlik_kadro WHERE etkinlik_id=$1`, etkID).Scan(&kadroAdet)
	fmt.Printf("             kadro satir sayisi=%d (3 bekleniyor)\n", kadroAdet)

	// kadro LISTE
	rows, err := db.Query(ctx, `
		SELECT k.id, k.user_id, k.ad, k.rol, k.sira,
		       COALESCE(u.username,''), u.avatar_media_id
		  FROM etkinlik_kadro k LEFT JOIN users u ON u.id = k.user_id
		 WHERE k.etkinlik_id=$1 ORDER BY k.sira, k.created_at`, etkID)
	kontrol("kadro liste sorgusu", err)
	if err == nil {
		n := 0
		for rows.Next() {
			var a, c, d, e string
			var f, g *string
			var h int
			if rows.Scan(&a, &f, &c, &d, &h, &e, &g) == nil {
				n++
			}
			_ = c
		}
		rows.Close()
		fmt.Printf("             kadro Scan basarili satir=%d (3 bekleniyor)\n", n)
	}

	// ═══════════ (D) 033 UPDATE tekrar kosturulabilir mi ═══════════
	for k := 0; k < 3; k++ {
		_, err = db.Exec(ctx, `UPDATE users u SET onayli = TRUE
		  FROM isletmeler i WHERE i.user_id = u.id AND i.dogrulandi = TRUE AND u.onayli = FALSE`)
		kontrol(fmt.Sprintf("033 UPDATE ... FROM (tekrar %d)", k+1), err)
	}

	// ═══════════ (A) 036 CHECK — mevcut satir varken DROP/ADD ═══════════
	db.Exec(ctx, `INSERT INTO ai_istekleri (user_id, tur, durum) VALUES ($1,'test','tamam')`, me)
	db.Exec(ctx, `INSERT INTO ai_istekleri (user_id, tur, durum) VALUES ($1,'test','beklemede')`, me)
	_, err = db.Exec(ctx, `ALTER TABLE ai_istekleri DROP CONSTRAINT IF EXISTS ai_istekleri_durum_check;
		ALTER TABLE ai_istekleri ADD CONSTRAINT ai_istekleri_durum_check
		  CHECK (durum IN ('beklemede','tamam','hata','iptal'));`)
	kontrol("036 satir VARKEN tekrar uygulanabilir", err)

	// AI kota rezervasyonu gercekten geciyor mu
	var aiID string
	err = db.QueryRow(ctx, `INSERT INTO ai_istekleri (user_id, tur, durum)
		VALUES ($1,'baslik','beklemede') RETURNING id`, me).Scan(&aiID)
	kontrol("AI rezervasyon INSERT (durum='beklemede')", err)

	// ═══════════ chats.ilan_id ═══════════
	var chatID string
	err = db.QueryRow(ctx, `INSERT INTO chats (type, ilan_id) VALUES ('direct',$1) RETURNING id`,
		ilanID).Scan(&chatID)
	kontrol("chats.ilan_id INSERT", err)

	ozetJSON, _ := json.Marshal(map[string]any{"basarisiz": basarisiz})
	fmt.Printf("\n════ SONUC %s ════\n", ozetJSON)
	if basarisiz > 0 {
		os.Exit(1)
	}
}

func kisa(v []string) []string {
	o := make([]string, len(v))
	for i, s := range v {
		if len(s) > 8 {
			o[i] = s[:8]
		} else {
			o[i] = s
		}
	}
	return o
}
