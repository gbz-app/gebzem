/* Gebzem yonetim paneli — turu 181.
 *
 * ⚠️⚠️ OTURUM: sunucu artik ADMIN_KEY'i DEGIL kisa omurlu bir JETON
 *    donduruyor (bkz. internal/admin/oturum.go). Jeton `X-Admin-Jeton`
 *    BASLIGIYLA gider — sorgu parametresi Caddy/Cloudflare loglarina ve
 *    tarayici gecmisine duserdi.
 * ⚠️ YAPMA: jetonu `?key=` olarak gondermeye donme.
 *
 * ⚠️⚠️ XSS: DB'den gelen HER metin `esc()` ile kacisli yazilir. Sikayet
 *    aciklamasi, isletme adi, urun adi — hepsi KULLANICI GIRDISI ve
 *    panelde ham basilirsa yoneticinin oturumunu calan bir XSS olur.
 * ⚠️ YAPMA: sablonlara `${x}` ile ham deger koyma; `${esc(x)}` yaz.
 */
'use strict';

var jeton = localStorage.getItem('gbzjeton') || '';
var aktifSekme = 'genel';
var sayacTimer = null;

/* ---------- yardimcilar ---------- */

function esc(s) {
  var d = document.createElement('span');
  d.textContent = s == null ? '' : String(s);
  return d.innerHTML;
}

function $(id) { return document.getElementById(id); }

function toast(mesaj, hataMi) {
  var t = document.createElement('div');
  t.className = 'toast' + (hataMi ? ' hata' : '');
  t.textContent = mesaj;
  document.body.appendChild(t);
  setTimeout(function () { t.remove(); }, 3200);
}

/* api — TUM admin istekleri buradan gecer.
 *
 * ⚠️ 401 gelirse oturum DUSMUSTUR (jeton suresi doldu ya da sunucu yeniden
 *    basladi) -> giris ekranina don. Sessizce bos liste gostermek,
 *    yoneticinin "veri yok" sanmasina yol acardi. */
function api(yol, secenek) {
  secenek = secenek || {};
  secenek.headers = Object.assign(
    { 'X-Admin-Jeton': jeton }, secenek.headers || {});
  if (secenek.body !== undefined && typeof secenek.body !== 'string') {
    secenek.headers['Content-Type'] = 'application/json';
    secenek.body = JSON.stringify(secenek.body);
  }
  return fetch(yol, secenek).then(function (y) {
    if (y.status === 401) { cikisYap(); throw new Error('oturum sona erdi'); }
    return y.json().then(function (veri) {
      if (!y.ok) throw new Error(veri && veri.error ? veri.error : 'hata');
      return veri;
    });
  });
}

function kurusMetni(k) {
  if (!k || k <= 0) return '—';
  var tam = Math.floor(k / 100), kus = k % 100;
  return kus === 0 ? tam + ' TL'
    : tam + ',' + String(kus).padStart(2, '0') + ' TL';
}

/* ---------- giris ---------- */

$('lform').addEventListener('submit', function (e) {
  e.preventDefault();
  $('lerr').textContent = '';
  $('lbtn').disabled = true;
  fetch('/admin/giris', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ user: $('lu').value, pass: $('lp').value })
  }).then(function (y) { return y.json().then(function (v) { return { y: y, v: v }; }); })
    .then(function (s) {
      $('lbtn').disabled = false;
      if (!s.y.ok) { $('lerr').textContent = s.v.error || 'giriş başarısız'; return; }
      jeton = s.v.jeton;
      localStorage.setItem('gbzjeton', jeton);
      basla();
    })
    .catch(function () {
      $('lbtn').disabled = false;
      $('lerr').textContent = 'bağlantı hatası';
    });
});

function cikisYap() {
  // ⚠️ Sunucuda da dusur: yalniz localStorage temizlemek jetonu gecerli
  //    birakirdi (bkz. oturum.go `Cikis`).
  if (jeton) fetch('/admin/cikis', { method: 'POST', headers: { 'X-Admin-Jeton': jeton } });
  jeton = '';
  localStorage.removeItem('gbzjeton');
  if (sayacTimer) { clearInterval(sayacTimer); sayacTimer = null; }
  $('app').hidden = true;
  $('login').hidden = false;
}
$('cikis').addEventListener('click', cikisYap);

function basla() {
  $('login').hidden = true;
  $('app').hidden = false;
  saatBasla();
  rozetTazele();
  sekmeAc('genel');
}

function saatBasla() {
  function tik() {
    var d = new Date();
    $('saat').textContent = d.toLocaleTimeString('tr-TR');
  }
  tik();
  if (sayacTimer) clearInterval(sayacTimer);
  sayacTimer = setInterval(function () { tik(); rozetTazele(); }, 30000);
}

/* Bekleyen sikayet rozeti — kuyrugun gorunur olmasi icin.
 * ⚠️ Hata SESSIZ: rozet ikincil bir bilgi, tum paneli hata mesajiyla
 *    doldurmasi yanlis olurdu. */
function rozetTazele() {
  api('/admin/istatistik').then(function (s) {
    var r = $('rozetSikayet');
    if (s.sikayet_yeni > 0) { r.textContent = s.sikayet_yeni; r.hidden = false; }
    else r.hidden = true;
  }).catch(function () {});
}

/* ---------- gezinme ---------- */

var basliklar = {
  genel: 'Genel Bakış', firmalar: 'Firmalar', urunler: 'Ürünler',
  kullanicilar: 'Kullanıcılar', sikayetler: 'Şikâyetler',
  icerik: 'İçerik Moderasyonu', yayinlar: 'Canlı Yayınlar',
  gunluk: 'İşlem Günlüğü'
};

document.querySelectorAll('#nav a').forEach(function (a) {
  a.addEventListener('click', function () { sekmeAc(a.dataset.t); });
});

function sekmeAc(t) {
  aktifSekme = t;
  document.querySelectorAll('#nav a').forEach(function (a) {
    a.classList.toggle('active', a.dataset.t === t);
  });
  $('ptitle').textContent = basliklar[t] || t;
  $('govde').innerHTML = '<div class=bos>Yükleniyor…</div>';
  ({
    genel: genelCiz, firmalar: firmalarCiz, urunler: urunlerCiz,
    kullanicilar: kullanicilarCiz, sikayetler: sikayetlerCiz,
    icerik: icerikCiz, yayinlar: yayinlarCiz, gunluk: gunlukCiz
  }[t] || genelCiz)();
}

function hataCiz(e) {
  $('govde').innerHTML = '<div class=bos>' + esc(e.message || 'hata') + '</div>';
}

/* ---------- 1. genel bakis ---------- */

function genelCiz() {
  api('/admin/istatistik').then(function (s) {
    var kutular = [
      ['kullanici', 'Kullanıcı'], ['isletme', 'Firma'],
      ['onayli', 'Onaylı hesap'], ['askida', 'Askıda hesap', true],
      ['urun', 'Ürün / hizmet'], ['ilan', 'İlan'],
      ['etkinlik', 'Etkinlik'], ['randevu', 'Açık randevu'],
      ['gonderi', 'Gönderi'], ['karantina', 'Karantinada', true],
      ['kanal', 'Topluluk'], ['hikaye', 'Hikâye (24s)'],
      ['sikayet_yeni', 'Bekleyen şikâyet', true],
      ['sikayet_toplam', 'Toplam şikâyet'],
      ['arama_aktif', 'Aktif arama'], ['yayin_aktif', 'Canlı yayın'],
      ['medya_aktif', 'Medya (aktif)'], ['medya_silinen', 'Medya (silinmiş)']
    ];
    var h = '<div class=grid>';
    kutular.forEach(function (k) {
      var uyari = k[2] && s[k[0]] > 0 ? ' uyari' : '';
      h += '<div class="kpi' + uyari + '"><div class=n>' + (s[k[0]] || 0) +
        '</div><div class=l>' + esc(k[1]) + '</div></div>';
    });
    h += '</div>';
    $('govde').innerHTML = h;
  }).catch(hataCiz);
}

/* ---------- 2. firmalar ---------- */

var kategoriler = null;

function kategorileriAl() {
  if (kategoriler) return Promise.resolve(kategoriler);
  return api('/admin/kategoriler').then(function (k) {
    // ⚠️ Liste SUNUCUDAN gelir (turu 77 kurali): panele sabit yazilsaydi
    //    yeni bir kategori eklemek bu dosyayi da degistirmeyi gerektirir.
    k.sort(function (a, b) { return a.ad.localeCompare(b.ad, 'tr'); });
    kategoriler = k;
    return k;
  });
}

function firmalarCiz() {
  var q = '', kat = '';
  function yukle() {
    api('/admin/isletmeler?q=' + encodeURIComponent(q) +
        '&kategori=' + encodeURIComponent(kat)).then(function (liste) {
      var h = '';
      h += '<div class=arac>' +
        '<input id=fq placeholder="Ad, kullanıcı adı ya da telefon ara" value="' + esc(q) + '" style="min-width:250px">' +
        '<select id=fkat></select>' +
        '<button class=btn id=fara>Ara</button>' +
        '<button class="btn yesil" id=fyeni>+ Yeni firma</button>' +
        '</div>';
      if (!liste.length) {
        h += '<div class=bos>Kayıt yok.</div>';
      } else {
        h += '<div class=sar><table class=tablo><tr>' +
          '<th>Firma</th><th>Kategori</th><th>Konum</th><th>Ürün</th>' +
          '<th>Durum</th><th>Eklendi</th><th></th></tr>';
        liste.forEach(function (f) {
          var durum = '';
          if (f.kapali) durum += '<span class="et gri">Kapalı</span> ';
          else durum += '<span class="et yesil">Açık</span> ';
          if (f.onayli) durum += '<span class="et mor">Onaylı</span> ';
          if (f.askida) durum += '<span class="et kirmizi">Askıda</span>';
          h += '<tr>' +
            '<td><b>' + esc(f.name) + '</b>' +
              (f.username ? '<br><span style="color:var(--dim);font-size:12px">@' + esc(f.username) + '</span>' : '') +
              '<br><span style="color:var(--dim);font-size:12px">' + esc(f.phone) + '</span></td>' +
            '<td>' + esc(f.kategori_ad || f.kategori || '—') + '</td>' +
            '<td>' + esc([f.ilce, f.il].filter(Boolean).join(' / ') || '—') +
              (f.enlem || f.boylam ? '<br><span style="color:var(--dim);font-size:11.5px">konum var</span>' : '') + '</td>' +
            '<td>' + f.urun_sayisi + '</td>' +
            '<td>' + durum + '</td>' +
            '<td style="color:var(--dim);font-size:12.5px">' + esc(f.olusma) + '</td>' +
            '<td><div class=eylem>' +
              '<button class="btn gri ufak" data-duzenle="' + esc(f.id) + '">Düzenle</button>' +
              '<button class="btn gri ufak" data-urun="' + esc(f.id) + '">Ürünler</button>' +
              '<button class="btn ' + (f.onayli ? 'gri' : 'yesil') + ' ufak" data-onay="' + esc(f.id) + '" data-deger="' + (f.onayli ? '0' : '1') + '">' +
                (f.onayli ? 'Onayı kaldır' : 'Onayla') + '</button>' +
              (f.kapali ? '' : '<button class="btn kirmizi ufak" data-kapat="' + esc(f.id) + '">Kapat</button>') +
            '</div></td></tr>';
        });
        h += '</table></div>';
      }
      $('govde').innerHTML = h;

      kategorileriAl().then(function (ks) {
        var s = $('fkat');
        if (!s) return;
        s.innerHTML = '<option value="">Tüm kategoriler</option>' +
          ks.map(function (k) {
            return '<option value="' + esc(k.anahtar) + '"' +
              (k.anahtar === kat ? ' selected' : '') + '>' + esc(k.ad) + '</option>';
          }).join('');
        s.onchange = function () { kat = s.value; yukle(); };
      });

      $('fara').onclick = function () { q = $('fq').value.trim(); yukle(); };
      $('fq').onkeydown = function (e) { if (e.key === 'Enter') $('fara').click(); };
      $('fyeni').onclick = function () { firmaFormu(null, yukle); };

      document.querySelectorAll('[data-duzenle]').forEach(function (b) {
        b.onclick = function () {
          var f = liste.filter(function (x) { return x.id === b.dataset.duzenle; })[0];
          firmaFormu(f, yukle);
        };
      });
      document.querySelectorAll('[data-urun]').forEach(function (b) {
        b.onclick = function () { sekmeAc('urunler'); setTimeout(function () {
          var i = $('uisl'); if (i) { i.value = b.dataset.urun; $('uara').click(); }
        }, 260); };
      });
      document.querySelectorAll('[data-onay]').forEach(function (b) {
        b.onclick = function () {
          api('/admin/isletmeler/' + b.dataset.onay + '/onay',
            { method: 'POST', body: { onayli: b.dataset.deger === '1' } })
            .then(function () { toast('Kaydedildi'); yukle(); })
            .catch(function (e) { toast(e.message, true); });
        };
      });
      document.querySelectorAll('[data-kapat]').forEach(function (b) {
        b.onclick = function () {
          onay('Firmayı kapat',
            'Hesap kişisel profile döner. İşletme bilgileri ve ürünler SİLİNMEZ — ' +
            'istediğiniz zaman yeniden açabilirsiniz.',
            function () {
              api('/admin/isletmeler/' + b.dataset.kapat, { method: 'DELETE' })
                .then(function () { toast('Firma kapatıldı'); yukle(); })
                .catch(function (e) { toast(e.message, true); });
            });
        };
      });
    }).catch(hataCiz);
  }
  yukle();
}

function firmaFormu(f, sonra) {
  var yeni = !f;
  kategorileriAl().then(function (ks) {
    var opt = ks.map(function (k) {
      return '<option value="' + esc(k.anahtar) + '"' +
        (f && f.kategori === k.anahtar ? ' selected' : '') + '>' + esc(k.ad) + '</option>';
    }).join('');
    var h = '<h3>' + (yeni ? 'Yeni firma' : 'Firmayı düzenle') + '</h3>';
    if (yeni) {
      h += '<div class=ipucu>Yeni firma için önce bir <b>hesap</b> açılır ' +
        '(işletme kaydı bir kullanıcı hesabına bağlıdır). Hesap doğrulanmış ' +
        'olarak açılır, yani firma bu bilgilerle uygulamaya girebilir.</div>' +
        '<div class=mrow><div><label>Telefon *</label>' +
        '<input id=mphone placeholder="+905xxxxxxxxx"></div>' +
        '<div><label>Şifre * (en az 6)</label><input id=mpass type=text></div></div>' +
        '<div class=mrow><div><label>Firma adı *</label><input id=mname></div>' +
        '<div><label>Kullanıcı adı</label><input id=musername placeholder="opsiyonel"></div></div>';
    } else {
      h += '<div class=ipucu><b>' + esc(f.name) + '</b>' +
        (f.username ? ' · @' + esc(f.username) : '') + ' · ' + esc(f.phone) + '</div>';
    }
    h += '<label>Kategori</label><select id=mkat>' + opt + '</select>' +
      '<label>Açıklama</label><textarea id=maciklama placeholder="Kısa tanıtım — işletme kartında görünür">' +
        esc(f ? f.aciklama : '') + '</textarea>' +
      '<label>Adres</label><input id=madres value="' + esc(f && f.adres ? f.adres : '') + '">' +
      '<div class=mrow><div><label>İl</label><input id=mil value="' + esc(f ? f.il : '') + '"></div>' +
      '<div><label>İlçe</label><input id=milce value="' + esc(f ? f.ilce : '') + '"></div></div>' +
      '<div class=mrow><div><label>Telefon</label><input id=mtel value="' + esc(f ? f.telefon : '') + '"></div>' +
      '<div><label>Web</label><input id=mweb value="' + esc(f && f.web ? f.web : '') + '"></div></div>' +
      '<div class=mrow><div><label>Enlem</label><input id=menlem value="' + (f && f.enlem ? f.enlem : '') + '"></div>' +
      '<div><label>Boylam</label><input id=mboylam value="' + (f && f.boylam ? f.boylam : '') + '"></div></div>' +
      '<div class=ipucu>Koordinat boş bırakılırsa mevcut değer <b>korunur</b>, sıfırlanmaz.</div>' +
      '<div class=mhata id=mhata></div>' +
      '<div class=malt><button class="btn gri" id=miptal>Vazgeç</button>' +
      '<button class=btn id=mkaydet>Kaydet</button></div>';
    katmanAc(h);

    $('miptal').onclick = katmanKapat;
    $('mkaydet').onclick = function () {
      var g = {
        kategori: $('mkat').value,
        aciklama: $('maciklama').value,
        adres: $('madres').value,
        il: $('mil').value, ilce: $('milce').value,
        telefon: $('mtel').value, web: $('mweb').value
      };
      // ⚠️ Bos koordinat GONDERILMEZ (null degil, HIC): sunucu isaretci
      //    semantigi kullaniyor ve gonderilmeyen alan mevcut degeri KORUR.
      var en = parseFloat($('menlem').value), bo = parseFloat($('mboylam').value);
      if (!isNaN(en)) g.enlem = en;
      if (!isNaN(bo)) g.boylam = bo;

      var istek;
      if (yeni) {
        g.phone = $('mphone').value.trim();
        g.name = $('mname').value.trim();
        g.username = $('musername').value.trim();
        g.password = $('mpass').value;
        if (!g.phone || !g.name || g.password.length < 6) {
          $('mhata').textContent = 'Telefon, ad ve en az 6 karakterli şifre zorunlu';
          return;
        }
        istek = api('/admin/isletmeler', { method: 'POST', body: g });
      } else {
        istek = api('/admin/isletmeler/' + f.id, { method: 'PATCH', body: g });
      }
      $('mkaydet').disabled = true;
      istek.then(function () {
        katmanKapat(); toast(yeni ? 'Firma eklendi' : 'Kaydedildi'); sonra();
      }).catch(function (e) {
        $('mkaydet').disabled = false;
        $('mhata').textContent = e.message;
      });
    };
  });
}

/* ---------- 3. urunler ---------- */

function urunlerCiz() {
  var isl = '', q = '';
  function yukle() {
    api('/admin/urunler?isletme=' + encodeURIComponent(isl) +
        '&q=' + encodeURIComponent(q)).then(function (liste) {
      var h = '<div class=arac>' +
        '<input id=uq placeholder="Ürün adı ara" value="' + esc(q) + '">' +
        '<input id=uisl placeholder="İşletme kimliği (opsiyonel)" value="' + esc(isl) + '" style="min-width:290px">' +
        '<button class=btn id=uara>Ara</button></div>';
      if (!liste.length) { h += '<div class=bos>Ürün yok.</div>'; }
      else {
        h += '<div class=sar><table class=tablo><tr><th>Ürün</th><th>Firma</th>' +
          '<th>Bölüm</th><th>Fiyat</th><th>Görsel</th><th>Durum</th><th></th></tr>';
        liste.forEach(function (u) {
          var et = u.durum === 'yayinda' ? '<span class="et yesil">Yayında</span>'
            : u.durum === 'tukendi' ? '<span class="et sari">Tükendi</span>'
            : '<span class="et gri">Kaldırıldı</span>';
          h += '<tr><td><b>' + esc(u.ad) + '</b>' +
            (u.aciklama ? '<br><span style="color:var(--dim);font-size:12px">' + esc(u.aciklama.slice(0, 70)) + '</span>' : '') +
            '</td><td>' + esc(u.isletme_ad) + '</td>' +
            '<td>' + esc(u.bolum || '—') + '</td>' +
            '<td>' + esc(kurusMetni(u.fiyat_kurus)) + '</td>' +
            '<td>' + (u.medya_sayisi > 0 ? u.medya_sayisi
              : '<span style="color:var(--orange)">yok</span>') + '</td>' +
            '<td>' + et + '</td>' +
            '<td><div class=eylem>' +
              (u.durum !== 'yayinda' ? '<button class="btn yesil ufak" data-ud="' + esc(u.id) + '" data-v=yayinda>Yayınla</button>' : '') +
              (u.durum !== 'tukendi' ? '<button class="btn gri ufak" data-ud="' + esc(u.id) + '" data-v=tukendi>Tükendi</button>' : '') +
              (u.durum !== 'kaldirildi' ? '<button class="btn kirmizi ufak" data-ud="' + esc(u.id) + '" data-v=kaldirildi>Kaldır</button>' : '') +
            '</div></td></tr>';
        });
        h += '</table></div>';
      }
      $('govde').innerHTML = h;
      $('uara').onclick = function () {
        q = $('uq').value.trim(); isl = $('uisl').value.trim(); yukle();
      };
      $('uq').onkeydown = function (e) { if (e.key === 'Enter') $('uara').click(); };
      document.querySelectorAll('[data-ud]').forEach(function (b) {
        b.onclick = function () {
          api('/admin/urunler/' + b.dataset.ud + '/durum',
            { method: 'POST', body: { durum: b.dataset.v } })
            .then(function () { toast('Güncellendi'); yukle(); })
            .catch(function (e) { toast(e.message, true); });
        };
      });
    }).catch(hataCiz);
  }
  yukle();
}

/* ---------- 4. kullanicilar ---------- */

function kullanicilarCiz() {
  var q = '', askida = '';
  function yukle() {
    api('/admin/kullanicilar?q=' + encodeURIComponent(q) +
        '&askida=' + encodeURIComponent(askida)).then(function (liste) {
      var h = '<div class=arac>' +
        '<input id=kq placeholder="Ad, kullanıcı adı ya da telefon" value="' + esc(q) + '" style="min-width:250px">' +
        '<select id=kaskida>' +
        '<option value="">Tümü</option>' +
        '<option value="1"' + (askida === '1' ? ' selected' : '') + '>Askıdakiler</option>' +
        '<option value="0"' + (askida === '0' ? ' selected' : '') + '>Aktifler</option>' +
        '</select><button class=btn id=kara>Ara</button></div>';
      if (!liste.length) { h += '<div class=bos>Kayıt yok.</div>'; }
      else {
        h += '<div class=sar><table class=tablo><tr><th>Kullanıcı</th><th>Tür</th>' +
          '<th>Jeton</th><th>Gönderi</th><th>Şikâyet</th><th>Durum</th>' +
          '<th>Son görülme</th><th></th></tr>';
        liste.forEach(function (k) {
          var durum = k.askida
            ? '<span class="et kirmizi">Askıda</span>'
            : (k.verified ? '<span class="et yesil">Aktif</span>'
                          : '<span class="et sari">Doğrulanmamış</span>');
          if (k.onayli) durum += ' <span class="et mor">Onaylı</span>';
          h += '<tr><td><b>' + esc(k.name) + '</b>' +
            (k.username ? '<br><span style="color:var(--dim);font-size:12px">@' + esc(k.username) + '</span>' : '') +
            '<br><span style="color:var(--dim);font-size:12px">' + esc(k.phone) + '</span></td>' +
            '<td>' + (k.hesap_turu === 'isletme' ? 'Firma' : 'Kişisel') + '</td>' +
            '<td>' + k.coin + '</td><td>' + k.gonderi_sayisi + '</td>' +
            '<td>' + (k.sikayet_sayisi > 0
              ? '<span style="color:var(--orange);font-weight:700">' + k.sikayet_sayisi + '</span>'
              : '0') + '</td>' +
            '<td>' + durum +
              (k.askida && k['askı_sebep']
                ? '<br><span style="color:var(--dim);font-size:11.5px">' + esc(k['askı_sebep'].slice(0, 60)) + '</span>' : '') +
            '</td>' +
            '<td style="color:var(--dim);font-size:12.5px">' + esc(k.gorulme) + '</td>' +
            '<td><div class=eylem>' +
              (k.askida
                ? '<button class="btn yesil ufak" data-aski="' + esc(k.id) + '" data-v=0>Askıyı kaldır</button>'
                : '<button class="btn kirmizi ufak" data-aski="' + esc(k.id) + '" data-v=1>Askıya al</button>') +
              '<button class="btn gri ufak" data-jeton="' + esc(k.id) + '">Jeton</button>' +
            '</div></td></tr>';
        });
        h += '</table></div>';
      }
      $('govde').innerHTML = h;
      $('kara').onclick = function () {
        q = $('kq').value.trim(); askida = $('kaskida').value; yukle();
      };
      $('kq').onkeydown = function (e) { if (e.key === 'Enter') $('kara').click(); };
      $('kaskida').onchange = function () { $('kara').click(); };

      document.querySelectorAll('[data-aski]').forEach(function (b) {
        b.onclick = function () {
          if (b.dataset.v === '0') {
            api('/admin/kullanicilar/' + b.dataset.aski + '/aski',
              { method: 'POST', body: { askida: false } })
              .then(function () { toast('Askı kaldırıldı'); yukle(); })
              .catch(function (e) { toast(e.message, true); });
            return;
          }
          katmanAc('<h3>Hesabı askıya al</h3>' +
            '<div class=ipucu>Kullanıcı uygulamaya <b>giremez</b> ve aşağıdaki ' +
            'metni görür. Hesap ve içerikleri <b>silinmez</b>; askı istediğiniz ' +
            'zaman kaldırılabilir.</div>' +
            '<label>Sebep (kullanıcıya gösterilir)</label>' +
            '<textarea id=asebep placeholder="Örn: Topluluk kurallarını ihlal eden paylaşım"></textarea>' +
            '<div class=mhata id=mhata></div>' +
            '<div class=malt><button class="btn gri" id=miptal>Vazgeç</button>' +
            '<button class="btn kirmizi" id=monay>Askıya al</button></div>');
          $('miptal').onclick = katmanKapat;
          $('monay').onclick = function () {
            api('/admin/kullanicilar/' + b.dataset.aski + '/aski',
              { method: 'POST', body: { askida: true, sebep: $('asebep').value } })
              .then(function () { katmanKapat(); toast('Hesap askıya alındı'); yukle(); })
              .catch(function (e) { $('mhata').textContent = e.message; });
          };
        };
      });
      document.querySelectorAll('[data-jeton]').forEach(function (b) {
        b.onclick = function () {
          katmanAc('<h3>Jeton işlemi</h3>' +
            '<div class=ipucu>Pozitif değer <b>yükler</b>, negatif değer <b>düşer</b>. ' +
            'Bakiye sıfırın altına inmez.</div>' +
            '<label>Miktar</label><input id=jmiktar type=number value="1000">' +
            '<div class=mhata id=mhata></div>' +
            '<div class=malt><button class="btn gri" id=miptal>Vazgeç</button>' +
            '<button class=btn id=monay>Uygula</button></div>');
          $('miptal').onclick = katmanKapat;
          $('monay').onclick = function () {
            api('/admin/kullanicilar/' + b.dataset.jeton + '/jeton',
              { method: 'POST', body: { miktar: parseInt($('jmiktar').value, 10) || 0 } })
              .then(function (s) { katmanKapat(); toast('Yeni bakiye: ' + s.bakiye); yukle(); })
              .catch(function (e) { $('mhata').textContent = e.message; });
          };
        };
      });
    }).catch(hataCiz);
  }
  yukle();
}

/* ---------- 5. sikayetler ---------- */

function sikayetlerCiz() {
  var durum = 'yeni';
  function yukle() {
    api('/admin/sikayetler?durum=' + encodeURIComponent(durum)).then(function (liste) {
      var h = '<div class=arac><select id=sdurum>' +
        ['yeni', 'incelendi', 'islem_yapildi', 'reddedildi', 'hepsi'].map(function (d) {
          var ad = { yeni: 'Bekleyen', incelendi: 'İncelendi',
            islem_yapildi: 'İşlem yapıldı', reddedildi: 'Reddedildi', hepsi: 'Hepsi' }[d];
          return '<option value="' + d + '"' + (d === durum ? ' selected' : '') + '>' + ad + '</option>';
        }).join('') + '</select></div>';
      if (!liste.length) { h += '<div class=bos>Bu durumda şikâyet yok.</div>'; }
      else {
        h += '<div class=sar><table class=tablo><tr><th>Hedef</th><th>Sebep</th>' +
          '<th>Açıklama</th><th>Şikâyet eden</th><th>Tekrar</th><th>Durum</th>' +
          '<th>Zaman</th><th></th></tr>';
        liste.forEach(function (s) {
          var hedef = s.hedef_ad
            ? esc(s.hedef_ad) + (s.hedef_kadi ? ' <span style="color:var(--dim)">@' + esc(s.hedef_kadi) + '</span>' : '')
            : '<span style="color:var(--dim)">' + esc(s.hedef_tur) + ' · ' + esc(s.hedef_id.slice(0, 12)) + '</span>';
          var et = { yeni: 'kirmizi', incelendi: 'sari',
            islem_yapildi: 'yesil', reddedildi: 'gri' }[s.durum] || 'gri';
          h += '<tr><td>' + hedef + '<br><span class="et gri">' + esc(s.hedef_tur) + '</span></td>' +
            '<td>' + esc(s.sebep || '—') + '</td>' +
            '<td style="max-width:260px">' + esc((s.aciklama || '—').slice(0, 160)) + '</td>' +
            '<td>' + esc(s.sikayetci || '—') + '</td>' +
            '<td>' + (s.tekrar > 1
              ? '<span style="color:var(--orange);font-weight:800">' + s.tekrar + '</span>' : s.tekrar) + '</td>' +
            '<td><span class="et ' + et + '">' + esc(s.durum) + '</span></td>' +
            '<td style="color:var(--dim);font-size:12.5px">' + esc(s.zaman) + '</td>' +
            '<td><button class="btn gri ufak" data-sk="' + s.id + '">İşle</button></td></tr>';
        });
        h += '</table></div>';
      }
      $('govde').innerHTML = h;
      $('sdurum').onchange = function () { durum = $('sdurum').value; yukle(); };
      document.querySelectorAll('[data-sk]').forEach(function (b) {
        b.onclick = function () {
          var s = liste.filter(function (x) { return String(x.id) === b.dataset.sk; })[0];
          katmanAc('<h3>Şikâyeti işle</h3>' +
            '<div class=ipucu><b>' + esc(s.hedef_tur) + '</b> · ' + esc(s.hedef_id) +
            '<br>Sebep: ' + esc(s.sebep || '—') +
            (s.aciklama ? '<br>Açıklama: ' + esc(s.aciklama) : '') + '</div>' +
            '<label>Karar</label><select id=skarar>' +
            '<option value=incelendi>İncelendi</option>' +
            '<option value=islem_yapildi>İşlem yapıldı</option>' +
            '<option value=reddedildi>Reddedildi</option>' +
            '<option value=yeni>Kuyruğa geri al</option></select>' +
            '<label>Not (yalnızca yönetim görür)</label><textarea id=snot>' + esc(s.admin_notu || '') + '</textarea>' +
            '<div class=mhata id=mhata></div>' +
            '<div class=malt><button class="btn gri" id=miptal>Vazgeç</button>' +
            '<button class=btn id=monay>Kaydet</button></div>');
          $('miptal').onclick = katmanKapat;
          $('monay').onclick = function () {
            api('/admin/sikayetler/' + s.id,
              { method: 'PATCH', body: { durum: $('skarar').value, not: $('snot').value } })
              .then(function () { katmanKapat(); toast('Kaydedildi'); rozetTazele(); yukle(); })
              .catch(function (e) { $('mhata').textContent = e.message; });
          };
        };
      });
    }).catch(hataCiz);
  }
  yukle();
}

/* ---------- 6. icerik moderasyonu ---------- */

function icerikCiz() {
  var tur = 'gonderi', durum = '';
  function yukle() {
    api('/admin/icerik/' + tur + '?durum=' + encodeURIComponent(durum)).then(function (liste) {
      var turAd = { gonderi: 'Gönderiler', yorum: 'Yorumlar',
        kanal: 'Topluluklar', kanal_gonderi: 'Topluluk gönderileri' };
      var h = '<div class=arac><select id=itur>' +
        Object.keys(turAd).map(function (t) {
          return '<option value="' + t + '"' + (t === tur ? ' selected' : '') + '>' + turAd[t] + '</option>';
        }).join('') + '</select>' +
        '<select id=idurum>' +
        '<option value="">Tümü</option>' +
        '<option value="yayinda"' + (durum === 'yayinda' ? ' selected' : '') + '>Yayında</option>' +
        '<option value="karantina"' + (durum === 'karantina' ? ' selected' : '') + '>Karantinada</option>' +
        '</select></div>' +
        '<div class=ipucu style="margin-bottom:12px">Karantina <b>geri alınabilir</b>: ' +
        'içerik silinmez, yalnızca kullanıcılara görünmez olur.</div>';
      if (!liste.length) { h += '<div class=bos>Kayıt yok.</div>'; }
      else {
        h += '<div class=sar><table class=tablo><tr><th>İçerik</th><th>Sahibi</th>' +
          '<th>Şikâyet</th><th>Durum</th><th>Zaman</th><th></th></tr>';
        liste.forEach(function (i) {
          var et = i.durum === 'yayinda' ? '<span class="et yesil">Yayında</span>'
            : i.durum === 'karantina' ? '<span class="et kirmizi">Karantina</span>'
            : '<span class="et gri">' + esc(i.durum) + '</span>';
          h += '<tr><td style="max-width:340px">' + esc(i.metin || '(metin yok)') + '</td>' +
            '<td>' + esc(i.sahip || '—') +
              (i.sahip_kadi ? '<br><span style="color:var(--dim);font-size:12px">@' + esc(i.sahip_kadi) + '</span>' : '') + '</td>' +
            '<td>' + (i.sikayet_sayisi > 0
              ? '<span style="color:var(--orange);font-weight:700">' + i.sikayet_sayisi + '</span>' : '0') + '</td>' +
            '<td>' + et + '</td>' +
            '<td style="color:var(--dim);font-size:12.5px">' + esc(i.zaman) + '</td>' +
            '<td>' + (i.durum === 'karantina'
              ? '<button class="btn yesil ufak" data-id="' + esc(i.id) + '" data-v=yayinda>Yayına al</button>'
              : '<button class="btn kirmizi ufak" data-id="' + esc(i.id) + '" data-v=karantina>Karantinaya al</button>') +
            '</td></tr>';
        });
        h += '</table></div>';
      }
      $('govde').innerHTML = h;
      $('itur').onchange = function () { tur = $('itur').value; yukle(); };
      $('idurum').onchange = function () { durum = $('idurum').value; yukle(); };
      document.querySelectorAll('[data-id]').forEach(function (b) {
        b.onclick = function () {
          api('/admin/icerik/' + tur + '/' + b.dataset.id + '/durum',
            { method: 'POST', body: { durum: b.dataset.v } })
            .then(function () { toast('Güncellendi'); yukle(); })
            .catch(function (e) { toast(e.message, true); });
        };
      });
    }).catch(hataCiz);
  }
  yukle();
}

/* ---------- 7. yayinlar ----------
 * ⚠️⚠️ `/admin/streams` ve `POST /admin/streams/{id}/end` uclari SUNUCUDA
 *    TURU 78'DEN BERI VARDI ama PANELDE onlari cagiran HICBIR ARAYUZ YOKTU
 *    (kesif bulgusu). 5651'in "4 saat icinde kaldirma" kurali icin yazilmis
 *    moderasyon ozelligi FIILEN ULASILAMAZDI. Burada baglaniyor.
 * ⚠️ Bu uclar ESKI yetki yolunu (`?key=`) kullaniyor; jetonla da calisir
 *    cunku `admin.Yetkili` uc kaynagi da kabul eder. */

function yayinlarCiz() {
  api('/admin/streams').then(function (veri) {
    var liste = Array.isArray(veri) ? veri : (veri.streams || veri.yayinlar || []);
    var h = '<div class=ipucu style="margin-bottom:12px">Bir yayını uzaktan ' +
      'sonlandırmak 5651 kapsamındaki içerik kaldırma yükümlülüğü içindir; ' +
      'işlem <b>günlüğe</b> yazılır.</div>';
    if (!liste.length) { h += '<div class=bos>Şu an canlı yayın yok.</div>'; }
    else {
      h += '<div class=sar><table class=tablo><tr><th>Yayın</th><th>Yayıncı</th>' +
        '<th>İzleyici</th><th>Durum</th><th></th></tr>';
      liste.forEach(function (s) {
        var id = s.id || s.stream_id || '';
        h += '<tr><td>' + esc(s.title || s.baslik || id) + '</td>' +
          '<td>' + esc(s.host_name || s.yayinci || '—') + '</td>' +
          '<td>' + (s.viewers != null ? s.viewers : (s.izleyici != null ? s.izleyici : '—')) + '</td>' +
          '<td><span class="et yesil">' + esc(s.status || s.durum || 'live') + '</span></td>' +
          '<td><button class="btn kirmizi ufak" data-bitir="' + esc(id) + '">Yayını bitir</button></td></tr>';
      });
      h += '</table></div>';
    }
    $('govde').innerHTML = h;
    document.querySelectorAll('[data-bitir]').forEach(function (b) {
      b.onclick = function () {
        onay('Yayını bitir', 'Yayın anında sonlandırılır ve izleyiciler düşer.', function () {
          api('/admin/streams/' + b.dataset.bitir + '/end', { method: 'POST' })
            .then(function () { toast('Yayın sonlandırıldı'); yayinlarCiz(); })
            .catch(function (e) { toast(e.message, true); });
        });
      };
    });
  }).catch(hataCiz);
}

/* ---------- 8. islem gunlugu ---------- */

function gunlukCiz() {
  api('/admin/gunluk?limit=200').then(function (liste) {
    var h = '<div class=ipucu style="margin-bottom:12px">Panelden yapılan her ' +
      'yazma işlemi buraya kaydedilir (kim, ne zaman, neyi, önceki/sonraki değer).</div>';
    if (!liste.length) { h += '<div class=bos>Henüz işlem yok.</div>'; }
    else {
      h += '<div class=sar><table class=tablo><tr><th>Zaman</th><th>İşlem</th>' +
        '<th>Hedef</th><th>Değişiklik</th><th>IP</th></tr>';
      liste.forEach(function (g) {
        h += '<tr><td style="color:var(--dim);font-size:12.5px;white-space:nowrap">' + esc(g.zaman) + '</td>' +
          '<td><span class="et mor">' + esc(g.eylem) + '</span></td>' +
          '<td style="font-size:12.5px">' + esc(g.hedef_tur || '—') +
            (g.hedef_id ? '<br><span style="color:var(--dim)">' + esc(g.hedef_id.slice(0, 18)) + '</span>' : '') + '</td>' +
          '<td style="max-width:420px;font-size:11.5px;color:var(--dim);word-break:break-all">' +
            esc((g.sonrasi || '').slice(0, 220)) + '</td>' +
          '<td style="color:var(--dim);font-size:12px">' + esc(g.ip) + '</td></tr>';
      });
      h += '</table></div>';
    }
    $('govde').innerHTML = h;
  }).catch(hataCiz);
}

/* ---------- katman ---------- */

function katmanAc(html) {
  $('modal').innerHTML = html;
  $('perde').hidden = false;
}
function katmanKapat() { $('perde').hidden = true; $('modal').innerHTML = ''; }
$('perde').addEventListener('click', function (e) {
  if (e.target === $('perde')) katmanKapat();
});
document.addEventListener('keydown', function (e) {
  if (e.key === 'Escape' && !$('perde').hidden) katmanKapat();
});

function onay(baslik, metin, sonra) {
  katmanAc('<h3>' + esc(baslik) + '</h3><div class=ipucu>' + metin + '</div>' +
    '<div class=malt><button class="btn gri" id=miptal>Vazgeç</button>' +
    '<button class="btn kirmizi" id=monay>Onayla</button></div>');
  $('miptal').onclick = katmanKapat;
  $('monay').onclick = function () { katmanKapat(); sonra(); };
}

/* ---------- acilis ---------- */

if (jeton) {
  // ⚠️ Jeton VAR diye oturum acik SAYILMAZ: sunucu yeniden basladiysa
  //    bellekteki jetonlar dusmustur. Once bir istekle DOGRULA.
  api('/admin/istatistik').then(basla).catch(function () {});
}
