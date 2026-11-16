import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'haptic_service.dart';

class AudioService with WidgetsBindingObserver {
  static const String _mutePrefKey = 'rush_out_is_muted';
  static const int _sfxPoolSize = 4;

  AudioPlayer? _bgmPlayer;
  final List<AudioPlayer> _sfxPool = [];
  int _sfxPoolIndex = 0;

  final HapticService _hapticService;
  final bool _enablePlatformAudio;

  bool _isMuted = false;
  bool _isInitialized = false;
  bool _bgmStarted = false;

  AudioService({
    HapticService? hapticService,
    bool enablePlatformAudio = true,
  })  : _hapticService = hapticService ?? const HapticService(),
        _enablePlatformAudio = enablePlatformAudio;

  bool get isMuted => _isMuted;
  HapticService get haptics => _hapticService;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool(_mutePrefKey) ?? false;
    } catch (_) {}

    if (!_enablePlatformAudio) return;

    try {
      _bgmPlayer = AudioPlayer();
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(_isMuted ? 0.0 : 0.3);

      for (int i = 0; i < _sfxPoolSize; i++) {
        final sfx = AudioPlayer();
        await sfx.setReleaseMode(ReleaseMode.stop);
        await sfx.setVolume(_isMuted ? 0.0 : 0.8);
        _sfxPool.add(sfx);
      }
    } catch (_) {
      _bgmPlayer = null;
      _sfxPool.clear();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleAppLifecycleState(state);
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      await pauseBgm();
    } else if (state == AppLifecycleState.resumed) {
      await resumeBgm();
    }
  }

  Future<void> startBgm() async {
    _bgmStarted = true;
    if (_isMuted || _bgmPlayer == null) return;
    try {
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.play(
        AssetSource('audio/bgm_loop.mp3'),
        volume: 0.3,
      );
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    if (_bgmPlayer == null) return;
    try {
      await _bgmPlayer!.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (_isMuted || _bgmPlayer == null) return;
    try {
      if (_bgmStarted) {
        await _bgmPlayer!.resume();
      } else {
        await startBgm();
      }
    } catch (_) {}
  }

  Future<bool> toggleMute() async {
    _isMuted = !_isMuted;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutePrefKey, _isMuted);
    } catch (_) {}

    try {
      if (_bgmPlayer != null) {
        await _bgmPlayer!.setVolume(_isMuted ? 0.0 : 0.3);
        if (_isMuted) {
          await _bgmPlayer!.pause();
        } else {
          await resumeBgm();
        }
      }
      for (final sfx in _sfxPool) {
        await sfx.setVolume(_isMuted ? 0.0 : 0.8);
      }
    } catch (_) {}
    return _isMuted;
  }

  Future<void> playSfx(String assetRelativePath) async {
    if (_isMuted || _sfxPool.isEmpty) return;
    try {
      final cleaned = assetRelativePath.replaceFirst(RegExp(r'^assets/'), '');
      final player = _sfxPool[_sfxPoolIndex];
      _sfxPoolIndex = (_sfxPoolIndex + 1) % _sfxPool.length;
      await player.stop();
      await player.play(AssetSource(cleaned), volume: 0.8);
    } catch (_) {}
  }

  Future<void> playCarSelect() => playSfx(AppConstants.sfxCarSelect);

  Future<void> playSlide() => playSfx(AppConstants.sfxSlide);

  Future<void> playHornCollide() async {
    await _hapticService.lightImpact();
    await playSfx(AppConstants.sfxHornCollide);
  }

  Future<void> playUndoWhoosh() => playSfx(AppConstants.sfxUndoWhoosh);

  Future<void> playHintPing() => playSfx(AppConstants.sfxHintPing);

  Future<void> playWin() => playSfx(AppConstants.sfxWin);

  Future<void> playStarPop() => playSfx(AppConstants.sfxStarPop);

  Future<void> dispose() async {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    await _bgmPlayer?.dispose();
    for (final sfx in _sfxPool) {
      await sfx.dispose();
    }
    _sfxPool.clear();
  }
}
