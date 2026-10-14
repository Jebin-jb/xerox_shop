import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCcrfvGqvDqWcnpMyAGq6kAEvYFLnrTzMU',
    appId: '1:163376892140:web:fa62c3a8ea92e26e5abdc9',
    messagingSenderId: '163376892140',
    projectId: 'campusxerox-a2b2c',
    storageBucket: 'campusxerox-a2b2c.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCcrfvGqvDqWcnpMyAGq6kAEvYFLnrTzMU',
    appId: '1:163376892140:android:b091d7da604584ee5abdc9',
    messagingSenderId: '163376892140',
    projectId: 'campusxerox-a2b2c',
    storageBucket: 'campusxerox-a2b2c.firebasestorage.app',
  );
}
