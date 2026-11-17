import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/app/app_dependencies.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/services/error_reporting_service.dart';
import 'package:rush_out/core/services/player_identity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectivity extends Fake implements Connectivity {
  List<ConnectivityResult> results;
  _FakeConnectivity(this.results);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;
}

class _FakeAudioPlayer extends Fake implements AudioPlayer {
  int playCalls = 0;
  int resumeCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  double? lastVolume;
  Source? lastSource;
  Future<void> Function()? onPlay;

  @override
  Future<void> setAudioContext(AudioContext ctx) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playCalls++;
    lastSource = source;
    if (volume != null) lastVolume = volume;
    if (onPlay != null) {
      await onPlay!();
    }
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _FailingPlayerIdentityService extends Fake
    implements PlayerIdentityService {
  @override
  Future<void> init() async {
    throw StateError('Simulated identity initialization failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Core Services Tests (Mục 2.8)', () {
    test('AudioService starts BGM via play() when app launches muted and user later unmutes', () async {
      SharedPreferences.setMockInitialValues({'rush_out_is_muted': true});
      final bgmPlayer = _FakeAudioPlayer();
      final sfxPlayers = <_FakeAudioPlayer>[];

      final audioService = AudioService(
        bgmPlayerFactory: () => bgmPlayer,
        sfxPlayerFactory: () {
          final p = _FakeAudioPlayer();
          sfxPlayers.add(p);
          return p;
        },
      );

      final notifiedValues = <bool>[];
      audioService.mutedListenable.addListener(() {
        notifiedValues.add(audioService.mutedListenable.value);
      });

      await audioService.init();
      expect(audioService.isMuted, isTrue);
      expect(sfxPlayers.length, 4);

      // Start BGM while muted: must record request without calling play yet
      await audioService.startBgm();
      expect(bgmPlayer.playCalls, 0);
      expect(bgmPlayer.resumeCalls, 0);

      // Unmute: must call play() to load & start BGM (not resume() on an unloaded player)
      final mutedAfterToggle = await audioService.toggleMute();
      expect(mutedAfterToggle, isFalse);
      expect(bgmPlayer.playCalls, 1);
      expect(bgmPlayer.resumeCalls, 0);
      expect(bgmPlayer.lastVolume, 0.35);
      expect(notifiedValues, [true, false]);

      // Subsequent pause -> resume calls resume() without restarting via play()
      await audioService.pauseBgm();
      expect(bgmPlayer.pauseCalls, 1);
      await audioService.resumeBgm();
      expect(bgmPlayer.resumeCalls, 1);
      expect(bgmPlayer.playCalls, 1);

      await audioService.dispose();
    });

    test('AudioService concurrent init() calls await preference loading before returning', () async {
      SharedPreferences.setMockInitialValues({'rush_out_is_muted': true});
      final bgmPlayer = _FakeAudioPlayer();

      final audioService = AudioService(
        bgmPlayerFactory: () => bgmPlayer,
        sfxPlayerFactory: () => _FakeAudioPlayer(),
        prefsProvider: () async {
          await Future<void>.delayed(const Duration(milliseconds: 25));
          return SharedPreferences.getInstance();
        },
      );

      final states = await Future.wait([
        audioService.init().then((_) => audioService.isMuted),
        audioService.init().then((_) => audioService.isMuted),
      ]);

      expect(states, [true, true]);
      await audioService.dispose();
    });

    test('NetworkInfoImpl returns true when multi-result includes a real connection alongside none', () async {
      final wifiAndNone = NetworkInfoImpl(
        _FakeConnectivity([ConnectivityResult.wifi, ConnectivityResult.none]),
      );
      expect(await wifiAndNone.isConnected, isTrue);

      final onlyNone = NetworkInfoImpl(
        _FakeConnectivity([ConnectivityResult.none]),
      );
      expect(await onlyNone.isConnected, isFalse);

      final empty = NetworkInfoImpl(_FakeConnectivity(const []));
      expect(await empty.isConnected, isFalse);
    });

    test('ErrorReportingService scrubs bare UUIDs and Supabase apikey headers/params', () {
      const raw =
          'DioException headers={apikey: sb_secret_anon_key.123, "apikey": "eyJhbGciOiJIUzI1NiJ9.payload.sig"} '
          'url=https://example.supabase.co?apikey=query_secret_456 '
          'user=550e8400-e29b-41d4-a716-446655440000 '
          'device=dev_12345678-1234-4000-8000-123456789012';

      final scrubbed = ErrorReportingService.scrubSensitiveData(raw);

      expect(scrubbed.contains('sb_secret_anon_key'), isFalse);
      expect(scrubbed.contains('eyJhbGciOiJIUzI1NiJ9'), isFalse);
      expect(scrubbed.contains('query_secret_456'), isFalse);
      expect(scrubbed.contains('550e8400-e29b-41d4-a716-446655440000'), isFalse);
      expect(scrubbed.contains('dev_12345678'), isFalse);
      expect(scrubbed, contains('[DEVICE_ID]'));
      expect(scrubbed, contains('[UUID]'));
    });

    test('ErrorReportingService scrubs email addresses and access/refresh tokens', () {
      const raw =
          'AuthError email="driver+test@example.com" alt=dev_123456@rushout.io '
          'payload={"access_token": "jwt.access.secret_123", "refresh_token": "rt_secret_xyz+99="} '
          'query=https://example.supabase.co/callback?access_token=tok_a1&refresh_token=tok_r2';

      final scrubbed = ErrorReportingService.scrubSensitiveData(raw);

      expect(scrubbed.contains('driver+test@example.com'), isFalse);
      expect(scrubbed.contains('dev_123456@rushout.io'), isFalse);
      expect(scrubbed.contains('jwt.access.secret_123'), isFalse);
      expect(scrubbed.contains('rt_secret_xyz+99='), isFalse);
      expect(scrubbed.contains('tok_a1'), isFalse);
      expect(scrubbed.contains('tok_r2'), isFalse);
      expect(scrubbed, contains('[EMAIL]'));
      expect(scrubbed, contains('"access_token": "[REDACTED]"'));
      expect(scrubbed, contains('"refresh_token": "[REDACTED]"'));
      expect(scrubbed, contains('access_token=[REDACTED]&refresh_token=[REDACTED]'));
    });

    test('AudioService pauses immediately if app goes to background while startBgm play() is in-flight [EDGE-03]', () async {
      final playGate = Completer<void>();
      final bgmPlayer = _FakeAudioPlayer()..onPlay = () => playGate.future;
      final audioService = AudioService(
        bgmPlayerFactory: () => bgmPlayer,
        sfxPlayerFactory: () => _FakeAudioPlayer(),
      );

      await audioService.init();
      final startFuture = audioService.startBgm();
      await Future<void>.delayed(Duration.zero);

      // User presses Home button before async play() resolves
      await audioService.handleAppLifecycleState(AppLifecycleState.paused);
      expect(audioService.isInBackground, isTrue);
      expect(bgmPlayer.pauseCalls, 0); // Not loaded yet

      playGate.complete();
      await startFuture;

      // Must immediately pause after play() completes
      expect(bgmPlayer.playCalls, 1);
      expect(bgmPlayer.pauseCalls, 1);

      // Returning to foreground resumes BGM
      await audioService.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(audioService.isInBackground, isFalse);
      expect(bgmPlayer.resumeCalls, 1);

      await audioService.dispose();
    });

    test('AudioService skips startBgm while already in background and starts on resume [EDGE-03]', () async {
      final bgmPlayer = _FakeAudioPlayer();
      final audioService = AudioService(
        bgmPlayerFactory: () => bgmPlayer,
        sfxPlayerFactory: () => _FakeAudioPlayer(),
      );

      await audioService.init();
      await audioService.handleAppLifecycleState(AppLifecycleState.hidden);
      expect(audioService.isInBackground, isTrue);

      await audioService.startBgm();
      expect(bgmPlayer.playCalls, 0);

      await audioService.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(bgmPlayer.playCalls, 1);

      await audioService.dispose();
    });

    test('AppDependencies.init disposes AudioService if a subsequent initialization step fails [EDGE-04]', () async {
      final bgmPlayer = _FakeAudioPlayer();
      final sfxPlayers = <_FakeAudioPlayer>[];
      final audioService = AudioService(
        bgmPlayerFactory: () => bgmPlayer,
        sfxPlayerFactory: () {
          final p = _FakeAudioPlayer();
          sfxPlayers.add(p);
          return p;
        },
      );

      await expectLater(
        () => AppDependencies.init(
          audioService: audioService,
          playerIdentityService: _FailingPlayerIdentityService(),
        ),
        throwsStateError,
      );

      expect(bgmPlayer.disposeCalls, 1);
      expect(sfxPlayers.length, 4);
      expect(sfxPlayers.every((p) => p.disposeCalls == 1), isTrue);
    });
  });
}
