import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Supports runtime/compile-time configuration via `--dart-define` parameters
/// so secrets and project identifiers are never hardcoded in source control.
class DefaultFirebaseOptions {
  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCWrnsg_U3kiLdUB1Qn1r-WHMy5kiKOs0A',
  );
  static const String _appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:385165638245:web:656ae76b89aafdde60648c',
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '385165638245',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'tic-tac-toe-online-91c52',
  );
  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'tic-tac-toe-online-91c52.firebaseapp.com',
  );
  static const String _databaseURL = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
    defaultValue:
        'https://tic-tac-toe-online-91c52-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'tic-tac-toe-online-91c52.firebasestorage.app',
  );

  /// Returns true if valid Firebase configuration parameters were supplied.
  static bool get isConfigured =>
      _apiKey.isNotEmpty && _projectId.isNotEmpty && _appId.isNotEmpty;

  static FirebaseOptions? get currentPlatform {
    if (!isConfigured) return null;

    if (kIsWeb) {
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain.isNotEmpty ? _authDomain : null,
        databaseURL: _databaseURL.isNotEmpty ? _databaseURL : null,
        storageBucket: _storageBucket.isNotEmpty ? _storageBucket : null,
      );
    }

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      databaseURL: _databaseURL.isNotEmpty ? _databaseURL : null,
    );
  }
}
