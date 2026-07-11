// Firebase yapilandirmasi — Firebase Console'dan alinan degerlerle elle olusturuldu
// (flutterfire configure ciktisiyla ayni yapi)
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isIOS) return ios;
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBjaReF8WSRgVCsoAVChk3EEU5qZlm1Zs0',
    appId: '1:119018348571:android:93289efd96fe0060c998be',
    messagingSenderId: '119018348571',
    projectId: 'gebzem-app',
    storageBucket: 'gebzem-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCeSgs-AhYtVaZp25t-7Cr4PVmtC5I9MHE',
    appId: '1:119018348571:ios:e466d5d63c359458c998be',
    messagingSenderId: '119018348571',
    projectId: 'gebzem-app',
    storageBucket: 'gebzem-app.firebasestorage.app',
    iosBundleId: 'app.gebzem',
  );
}
