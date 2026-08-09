// Package sohbet — IKI KISI ARASINDAKI DIREKT SOHBET icin **TEK KAYNAK**.
//
// ⚠️⚠️ NEDEN AYRI PAKET (turu 78 arastirma bulgusu):
//
//	Ayni sorgu UC yerde BIREBIR kopyalanmisti ve UCUNDE DE ayni iki kusur vardi:
//	  · backend/internal/chat/handler.go   (CreateDirect)
//	  · backend/internal/calls/handler.go  (arama kaydini sohbete yazarken)
//	  · backend/internal/calls/grup_sohbet.go
//	Bu projede "ayni kuralin iki kopyasi DRIFT eder" hatasi ALTI kez tekrarladi
//	(turu 72b/H, 75b/2, 77b). Uc kopya, dorduncusu eklenmeden once tek yere alindi.
//
// ⚠️⚠️ KUSUR 1 — `ORDER BY` YOKTU. Eski `CreateDirect` yarisindan kalma CIFT
//
//	satir olabilir (iki cihaz ayni anda sohbet acarsa: SELECT ikisinde de bos
//	doner, ikisi de INSERT eder — benzersizlik kisiti YOK). Siralamasiz
//	`LIMIT 1` hangi satiri dondurecegini PLANA GORE secer; plan degisince
//	kullanicinin sohbeti "gezinir": mesajlar bir gun bir satira, ertesi gun
//	otekine yazilir ve gecmis IKIYE BOLUNMUS gorunur.
//	FIX: `ORDER BY c.created_at, c.id` — deterministik, HER ZAMAN EN ESKISI.
//
// ⚠️⚠️ KUSUR 2 — `ilan_id IS NULL` yuklemi YOKTU (ilan sohbetleri gelince
//
//	sevk engeli olacakti). Ilan sohbetleri de `type='direct'`; bu yuklem
//	olmadan profil/aramadaki "Mesaj gonder" seni rastgele bir ILAN sohbetine
//	dusururdu ve cevapsiz arama kaydi da oraya yazilirdi.
//
// ⚠️ ENGEL KONTROLU BU FONKSIYONUN ICINDE DEGIL — bilincli:
//
//	`CreateDirect` engeli ONDEN kontrol ediyor (kullanici eylemi).
//	`calls` yollari ise arama ZATEN GERCEKLESTIKTEN sonra kayit yaziyor;
//	oraya engel kapisi koymak gecmis bir aramanin kaydini yutardi.
// ⚠️ Bu paket YALNIZ SQL SABITLERI ihrac eder, fonksiyon DEGIL.
//
//	Bir `Sorgulayici` arayuzu + adapter yazmak denendi ve ELENDI: uc cagiran
//	da farkli baglamda calisiyor (biri `*pgxpool.Pool`, biri `pgx.Tx` icinde,
//	biri HTTP handler'da hata yazarak) ve ortak bir imza uydurmak her cagirana
//	adapter kodu ekliyordu. DRIFT EDEN sey SORGUNUN KENDISIYDI (ORDER BY ve
//	ilan_id yuklemi); onu tek yere almak sorunu COZER, fazlasi gereksiz katman.
package sohbet

// DirektSorgu — mevcut direkt sohbeti bulan sorgu. **TEK KAYNAK.**
//
// $1, $2 = iki kullanici. Sira ONEMSIZ (iki JOIN simetrik).
//
// ⚠️ `c.ilan_id IS NULL`: ILAN sohbetleri de `type='direct'`; kisisel sohbet
//
//	aranirken onlar HARIC tutulur (bkz. paket serhi, KUSUR 2).
//
// ⚠️ `ORDER BY` SILINMEZ (bkz. paket serhi, KUSUR 1).
const DirektSorgu = `
	SELECT c.id FROM chats c
	JOIN chat_members m1 ON m1.chat_id=c.id AND m1.user_id=$1
	JOIN chat_members m2 ON m2.chat_id=c.id AND m2.user_id=$2
	WHERE c.type='direct' AND c.ilan_id IS NULL
	ORDER BY c.created_at, c.id
	LIMIT 1`

// IlanSorgu — belirli bir ILANA bagli sohbeti bulur.
//
// $1 = yazan, $2 = ilan sahibi, $3 = ilan id.
//
// ⚠️ Ayni kisi ayni ilan icin ikinci kez yazarsa AYNI sohbet acilir; farkli
//
//	bir ilan icin AYRI sohbet acilir (sahibinden/Letgo davranisi). Satici
//	boylece "hangi ilan icin yaziyor" sorusunu sormak zorunda kalmaz.
const IlanSorgu = `
	SELECT c.id FROM chats c
	JOIN chat_members m1 ON m1.chat_id=c.id AND m1.user_id=$1
	JOIN chat_members m2 ON m2.chat_id=c.id AND m2.user_id=$2
	WHERE c.type='direct' AND c.ilan_id=$3
	ORDER BY c.created_at, c.id
	LIMIT 1`
