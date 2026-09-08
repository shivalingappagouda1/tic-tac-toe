import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Dedicated Audio Service managing game sound effects, autoplay restrictions,
/// mute state, and debug logging.
class AudioService {
  bool _isMuted = false;
  bool get isMuted => _isMuted;
  set isMuted(bool value) {
    _isMuted = value;
    debugPrint('[AUDIO] Mute state: $_isMuted');
  }

  // Audio players for distinct sound categories to prevent clipping/cancelling
  late final AudioPlayer _movePlayer;
  late final AudioPlayer _winPlayer;
  late final AudioPlayer _drawPlayer;
  late final AudioPlayer _buttonPlayer;

  bool _isInitialized = false;

  AudioService() {
    _init();
  }

  void _init() {
    try {
      _movePlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _winPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _drawPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      _buttonPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

      // On web/chrome, AudioCache default prefix is 'assets/'.
      // If pubspec has 'assets/audio/', the full path is 'assets/audio/'.
      AudioCache.instance.prefix = 'assets/';

      _isInitialized = true;
      debugPrint('[AUDIO] Audio initialized');
    } catch (e) {
      debugPrint('[AUDIO] Audio initialization failed: $e');
    }
  }

  /// Ensures audio context is active upon first user gesture (Chrome autoplay unlock)
  void _unlockAudio() {
    if (!_isInitialized) {
      _init();
    }
  }

  Future<void> _playSound(AudioPlayer player, String soundName) async {
    if (_isMuted) {
      debugPrint('[AUDIO] Mute state: true. Suppressed $soundName');
      return;
    }

    _unlockAudio();

    try {
      await player.stop();
      // Try MP3 first
      final source = AssetSource('audio/$soundName.mp3');
      await player.play(source);
      debugPrint('[AUDIO] Successfully played $soundName.mp3');
    } catch (e) {
      debugPrint('[AUDIO] Failed playing mp3 for $soundName ($e), trying wav fallback');
      try {
        await player.stop();
        final wavSource = AssetSource('audio/$soundName.wav');
        await player.play(wavSource);
        debugPrint('[AUDIO] Successfully played $soundName.wav');
      } catch (e2) {
        debugPrint('[AUDIO] Failed playing wav fallback for $soundName: $e2');
      }
    }
  }

  /// Plays tactile wood tap when an empty cell is claimed
  void playMove() {
    debugPrint('[AUDIO] Attempting to play move');
    _playSound(_movePlayer, 'move');
  }

  /// Plays celebratory chime when Player X wins
  void playXWin() {
    debugPrint('[AUDIO] Attempting to play X win');
    _playSound(_winPlayer, 'x_win');
  }

  /// Alias for playXWin() to preserve backward compatibility
  void playWinX() => playXWin();

  /// Plays deep metallic chime when Player O wins
  void playOWin() {
    debugPrint('[AUDIO] Attempting to play O win');
    _playSound(_winPlayer, 'o_win');
  }

  /// Alias for playOWin() to preserve backward compatibility
  void playWinO() => playOWin();

  /// Plays stalemate sound on draw
  void playDraw() {
    debugPrint('[AUDIO] Attempting to play draw');
    _playSound(_drawPlayer, 'draw');
  }

  /// Plays tactile wooden button click
  void playButton() {
    debugPrint('[AUDIO] Attempting to play button');
    _playSound(_buttonPlayer, 'button');
  }

  /// Plays button sound on starting a new round
  void playNewRound() => playButton();

  /// Plays button sound on resetting session scores
  void playReset() => playButton();

  /// Toggles mute state
  void toggleMute() {
    isMuted = !isMuted;
  }

  void dispose() {
    try {
      _movePlayer.dispose();
      _winPlayer.dispose();
      _drawPlayer.dispose();
      _buttonPlayer.dispose();
    } catch (_) {}
  }
}
