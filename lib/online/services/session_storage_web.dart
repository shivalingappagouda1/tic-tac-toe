import 'package:web/web.dart' as web;

class SessionStorageImpl {
  static const String _key = 'ttt_active_session';

  Future<void> save(String data) async {
    try {
      web.window.sessionStorage.setItem(_key, data);
    } catch (_) {}
  }

  Future<String?> load() async {
    try {
      return web.window.sessionStorage.getItem(_key);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      web.window.sessionStorage.removeItem(_key);
    } catch (_) {}
  }
}

SessionStorageImpl createSessionStorage() => SessionStorageImpl();
