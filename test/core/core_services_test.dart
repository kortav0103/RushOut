import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rush_out/core/network/network_info.dart';
import 'package:rush_out/core/services/audio_service.dart';
import 'package:rush_out/core/services/error_reporting_service.dart';
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
  });
}
