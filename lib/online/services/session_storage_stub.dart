class SessionStorageImpl {
  String? _stored;

  Future<void> save(String data) async {
    _stored = data;
  }

  Future<String?> load() async {
    return _stored;
  }

  Future<void> clear() async {
    _stored = null;
  }
}

SessionStorageImpl createSessionStorage() => SessionStorageImpl();
