import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBM-AOI1dJc0azlCiof6-0BjAGXzb0z8gk',
    appId: '1:685189542501:web:6a53b83ea2f67b30400c8c',
    messagingSenderId: '685189542501',
    projectId: 'cers-5bf5d',
    authDomain: 'cers-5bf5d.firebaseapp.com',
    storageBucket: 'cers-5bf5d.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBM-AOI1dJc0azlCiof6-0BjAGXzb0z8gk',
    appId: '1:685189542501:android:6a53b83ea2f67b30400c8c',
    messagingSenderId: '685189542501',
    projectId: 'cers-5bf5d',
    storageBucket: 'cers-5bf5d.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBM-AOI1dJc0azlCiof6-0BjAGXzb0z8gk',
    appId: '1:685189542501:ios:6a53b83ea2f67b30400c8c',
    messagingSenderId: '685189542501',
    projectId: 'cers-5bf5d',
    storageBucket: 'cers-5bf5d.firebasestorage.app',
    iosClientId: '1:685189542501:ios:6a53b83ea2f67b30400c8c',
    iosBundleId: 'com.shatechx.cers',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBM-AOI1dJc0azlCiof6-0BjAGXzb0z8gk',
    appId: '1:685189542501:ios:6a53b83ea2f67b30400c8c',
    messagingSenderId: '685189542501',
    projectId: 'cers-5bf5d',
    storageBucket: 'cers-5bf5d.firebasestorage.app',
    iosClientId: '1:685189542501:ios:6a53b83ea2f67b30400c8c',
    iosBundleId: 'com.shatechx.cers',
  );
}