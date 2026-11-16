import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
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
  final AudioPlayer Function() _bgmPlayerFactory;
  final AudioPlayer Function() _sfxPlayerFactory;
  final Future<SharedPreferences> Function()? _prefsProvider;

  final ValueNotifier<bool> _mutedNotifier = ValueNotifier<bool>(false);
  bool _isMuted = false;
  bool _isInitialized = false;
  Future<void>? _initFuture;
  bool _bgmRequested = false;
  bool _bgmLoaded = false;

  AudioService({
    HapticService? hapticService,
    bool enablePlatformAudio = true,
    AudioPlayer Function()? bgmPlayerFactory,
    AudioPlayer Function()? sfxPlayerFactory,
    Future<SharedPreferences> Function()? prefsProvider,
  })  : _hapticService = hapticService ?? const HapticService(),
        _enablePlatformAudio = enablePlatformAudio,
        _bgmPlayerFactory = bgmPlayerFactory ?? AudioPlayer.new,
        _sfxPlayerFactory = sfxPlayerFactory ?? AudioPlayer.new,
        _prefsProvider = prefsProvider;

  bool get isMuted => _isMuted;
  ValueListenable<bool> get mutedListenable => _mutedNotifier;
  HapticService get haptics => _hapticService;

  void _setMutedState(bool muted) {
    _isMuted = muted;
    _mutedNotifier.value = muted;
  }

  Future<SharedPreferences> _getPrefs() =>
      _prefsProvider?.call() ?? SharedPreferences.getInstance();

  Future<void> init() {
    if (_isInitialized) return Future.value();
    final inFlight = _initFuture;
    if (inFlight != null) return inFlight;

    final future = _performInit();
    _initFuture = future;
    return future.whenComplete(() {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
    });
  }

  Future<void> _performInit() async {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}

    try {
      final prefs = await _getPrefs();
      _setMutedState(prefs.getBool(_mutePrefKey) ?? false);
    } catch (_) {}

    if (!_enablePlatformAudio) {
      _isInitialized = true;
      return;
    }

    try {
      _bgmPlayer = _bgmPlayerFactory();
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.setVolume(_isMuted ? 0.0 : 0.35);

      final sfxContext = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();

      for (int i = 0; i < _sfxPoolSize; i++) {
        final sfx = _sfxPlayerFactory();
        await sfx.setAudioContext(sfxContext);
        await sfx.setReleaseMode(ReleaseMode.stop);
        await sfx.setVolume(_isMuted ? 0.0 : 0.85);
        _sfxPool.add(sfx);
      }
    } catch (_) {
      _bgmPlayer = null;
      _sfxPool.clear();
    }

    _isInitialized = true;
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
    _bgmRequested = true;
    if (_isMuted || _bgmPlayer == null) return;
    try {
      await _bgmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer!.play(
        AssetSource('audio/bgm_loop.mp3'),
        volume: 0.35,
      );
      _bgmLoaded = true;
    } catch (_) {}
  }

  Future<void> pauseBgm() async {
    if (_bgmPlayer == null || !_bgmLoaded) return;
    try {
      await _bgmPlayer!.pause();
    } catch (_) {}
  }

  Future<void> resumeBgm() async {
    if (_isMuted || _bgmPlayer == null) return;
    try {
      if (_bgmLoaded) {
        await _bgmPlayer!.resume();
      } else if (_bgmRequested) {
        await startBgm();
      }
    } catch (_) {}
  }

  Future<bool> toggleMute() async {
    _setMutedState(!_isMuted);
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_mutePrefKey, _isMuted);
    } catch (_) {}

    try {
      if (_bgmPlayer != null) {
        await _bgmPlayer!.setVolume(_isMuted ? 0.0 : 0.35);
        if (_isMuted) {
          await pauseBgm();
        } else {
          await resumeBgm();
        }
      }
      for (final sfx in _sfxPool) {
        await sfx.setVolume(_isMuted ? 0.0 : 0.85);
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
      await player.play(AssetSource(cleaned), volume: 0.85);
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
    _bgmPlayer = null;
    for (final sfx in _sfxPool) {
      await sfx.dispose();
    }
    _sfxPool.clear();
    _bgmRequested = false;
    _bgmLoaded = false;
    _isInitialized = false;
    _mutedNotifier.dispose();
  }
}
