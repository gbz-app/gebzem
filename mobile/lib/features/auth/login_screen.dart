/// ⚠️⚠️ TURU 89 — GIRIS EKRANI **KAYIT AKISININ DILINE** cevrildi.
///
/// Kullanici emirleri:
///   · *"normal giris ekranindaki MESAJ IKONUNU ve GEBZEM yazisini kaldir"*
///   · *"kayit ekranindaki tarzin AYNISI giriste de olsun"*
///
/// Onceki hal: ortalanmis 72px mor `messageCircle` ikonu + "Gebzem" basligi +
/// tema renkli varsayilan `OutlineInputBorder` alanlar. Yani kayit akisiyla
/// AYNI URUNUN IKI FARKLI GORSEL DILI vardi.
///
/// ⚠️ Ortak parcalar **KOPYALANMADI**, `auth_stil.dart` TEK KAYNAGINDAN
///    geliyor (bkz. o dosyanin serhi: iki kopya kacinilmaz olarak drift eder).
/// ⚠️ HICBIR ISLEV KALDIRILMADI: telefon, sifre (goster/gizle), "Şifremi
///    unuttum", "Kayıt ol" ve hata mesajlari AYNEN duruyor — degisen yalnizca
///    yerlesim ve bicim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api.dart';
import 'auth_provider.dart';
import 'auth_stil.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController(text: '+90');
  final _password = TextEditingController();
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).login(_phone.text.trim(), _password.text);
      // yonlendirmeyi router'in redirect'i yapar
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthSayfa(
      child: SafeArea(
        child: Column(
          children: [
            // ⚠️ Kayit akisiyla AYNI ust bosluk: iki ekran arasinda gecerken
            //    baslik ZIPLAMASIN.
            const SizedBox(height: 48),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      authBaslik(
                        'Tekrar hoş geldin',
                        'Numaran ve şifrenle giriş yap.',
                      ),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: authYazi, fontSize: 16),
                        decoration: authAlan(
                          'Telefon numarası',
                          ipucu: '+905xxxxxxxxx',
                        ),
                        validator: (v) => (v == null || v.trim().length < 12)
                            ? 'Geçerli numara girin'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        style: const TextStyle(color: authYazi, fontSize: 16),
                        decoration: authAlan(
                          'Şifre',
                          sonek: IconButton(
                            icon: Icon(
                              _hidePassword
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              size: 19,
                              color: authAltYazi,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Şifre en az 6 karakter'
                            : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/forgot'),
                          style: TextButton.styleFrom(
                            foregroundColor: authAltYazi,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Şifremi unuttum'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ⚠️ Ana dugme ALTTA SABIT (kayit akisiyla ayni): klavye acikken
            //    de erisilir ve iki ekranda ayni yerde durur.
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  authAnaDugme(
                    etiket: 'Giriş yap',
                    basildi: _submit,
                    mesgul: _loading,
                  ),
                  TextButton(
                    onPressed: _loading ? null : () => context.push('/register'),
                    style: TextButton.styleFrom(foregroundColor: authAltYazi),
                    child: const Text('Hesabın yok mu? Kayıt ol'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
