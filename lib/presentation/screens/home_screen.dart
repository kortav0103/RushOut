import 'package:flutter/material.dart';
import '../../core/services/audio_service.dart';
import '../../domain/repositories/daily_challenge_repository.dart';
import '../../domain/usecases/get_levels.dart';
import '../../domain/usecases/save_progress.dart';
import '../../domain/usecases/submit_score.dart';
import '../widgets/how_to_play_dialog.dart';
import 'daily_screen.dart';
import 'leaderboard_screen.dart';
import 'level_select_screen.dart';

class HomeScreen extends StatefulWidget {
  final AudioService audioService;
  final GetLevels getLevelsUseCase;
  final SaveProgress saveProgressUseCase;
  final DailyChallengeRepository dailyRepository;
  final SubmitScore submitScoreUseCase;
  final GetLeaderboard getLeaderboardUseCase;

  const HomeScreen({
    super.key,
    required this.audioService,
    required this.getLevelsUseCase,
    required this.saveProgressUseCase,
    required this.dailyRepository,
    required this.submitScoreUseCase,
    required this.getLeaderboardUseCase,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.audioService.startBgm();
  }

  Future<void> _toggleMute() async {
    await widget.audioService.toggleMute();
    if (mounted) {
      setState(() {});
    }
  }

  void _openLeaderboard() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LeaderboardScreen(
          getLeaderboardUseCase: widget.getLeaderboardUseCase,
        ),
      ),
    );
  }

  void _openDailyChallenge() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyScreen(
          dailyRepository: widget.dailyRepository,
          submitScoreUseCase: widget.submitScoreUseCase,
          audioService: widget.audioService,
          onOpenLeaderboard: _openLeaderboard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = widget.audioService.isMuted;

    return Scaffold(
      backgroundColor: const Color(0xFF141619),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Top Action Bar: Sound Toggle & How to Play (?)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'How to Play',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.help_outline_rounded),
                    onPressed: () => HowToPlayDialog.show(context),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: isMuted ? 'Unmute Sound' : 'Mute Sound',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor:
                          isMuted ? Colors.redAccent : Colors.amberAccent,
                    ),
                    icon: Icon(
                      isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                    ),
                    onPressed: _toggleMute,
                  ),
                ],
              ),

              const Spacer(),

              // Hero Logo & Title
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.45),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  size: 62,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'RUSHOUT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '6×6 PARKING JAM SLIDING PUZZLE',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),

              const Spacer(),

              // Main Navigation Menu Buttons
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LevelSelectScreen(
                              getLevelsUseCase: widget.getLevelsUseCase,
                              saveProgressUseCase: widget.saveProgressUseCase,
                              audioService: widget.audioService,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text(
                        'PLAY CAMPAIGN',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(
                          color: Colors.amberAccent,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _openDailyChallenge,
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      label: const Text(
                        'DAILY CHALLENGE',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: const BorderSide(
                          color: Colors.cyanAccent,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _openLeaderboard,
                      icon: const Icon(Icons.emoji_events_rounded, size: 22),
                      label: const Text(
                        'LEADERBOARD',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
