import 'dart:convert';

import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart';

class ActiveSessionData {
  final String gameId;
  final String? roomCode;
  final String? role; // 'X' or 'O'
  final String mode; // 'completeOnline' or 'onlineWithCode'
  final bool isHost;

  const ActiveSessionData({
    required this.gameId,
    this.roomCode,
    this.role,
    required this.mode,
    this.isHost = false,
  });

  Map<String, dynamic> toMap() => {
        'gameId': gameId,
        if (roomCode != null) 'roomCode': roomCode,
        if (role != null) 'role': role,
        'mode': mode,
        'isHost': isHost,
      };

  factory ActiveSessionData.fromMap(Map<String, dynamic> map) =>
      ActiveSessionData(
        gameId: map['gameId']?.toString() ?? '',
        roomCode: map['roomCode']?.toString(),
        role: map['role']?.toString(),
        mode: map['mode']?.toString() ?? 'completeOnline',
        isHost: map['isHost'] == true,
      );
}

class SessionStorageService {
  final SessionStorageImpl _impl;

  SessionStorageService({SessionStorageImpl? impl})
      : _impl = impl ?? createSessionStorage();

  static final SessionStorageService instance = SessionStorageService();

  Future<void> saveSession(ActiveSessionData session) async {
    try {
      final jsonStr = jsonEncode(session.toMap());
      await _impl.save(jsonStr);
    } catch (_) {}
  }

  Future<ActiveSessionData?> loadSession() async {
    try {
      final jsonStr = await _impl.load();
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        return ActiveSessionData.fromMap(map);
      } else if (map is Map) {
        return ActiveSessionData.fromMap(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearSession() async {
    try {
      await _impl.clear();
    } catch (_) {}
  }
}
