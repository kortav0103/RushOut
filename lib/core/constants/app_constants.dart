class AppConstants {
  AppConstants._();

  // Grid & Board Rules
  static const int gridSize = 6;
  static const int boardStringLength = 36;
  static const int exitRow = 2;
  static const int targetWinCol = 4;
  static const int targetEscapeCol = 6;
  static const String targetVehicleId = 'A';
  static const String emptyCellChar = 'o';
  static const String wallCellChar = 'x';

  // Difficulty Optimal Move Ranges
  static const int easyMinMoves = 5;
  static const int easyMaxMoves = 10;
  static const int mediumMinMoves = 11;
  static const int mediumMaxMoves = 18;
  static const int hardMinMoves = 19;
  static const int hardMaxMoves = 25;
  static const int levelsPerDifficulty = 1350;
  static const int totalCampaignLevels = 4050;

  // Asset Paths
  static const String levelsFilePath = 'assets/levels/rush1000.txt';
  static const String vehiclesImageDir = 'assets/images/vehicles/';
  static const String targetCarSprite = 'assets/images/vehicles/target_car.png';
  static const List<String> car2Sprites = [
    'assets/images/vehicles/car_2_police.png',
    'assets/images/vehicles/car_2_taxi.png',
    'assets/images/vehicles/car_2_ambulance.png',
    'assets/images/vehicles/car_2_sedan.png',
  ];
  static const List<String> truck3Sprites = [
    'assets/images/vehicles/truck_3_firetruck.png',
    'assets/images/vehicles/truck_3_limo.png',
  ];

  // Audio Paths
  static const String bgmLoopPath = 'assets/audio/bgm_loop.mp3';
  static const String sfxCarSelect = 'assets/audio/sfx/car_select.mp3';
  static const String sfxSlide = 'assets/audio/sfx/slide.mp3';
  static const String sfxHornCollide = 'assets/audio/sfx/horn_collide.mp3';
  static const String sfxUndoWhoosh = 'assets/audio/sfx/undo_whoosh.mp3';
  static const String sfxHintPing = 'assets/audio/sfx/hint_ping.mp3';
  static const String sfxWin = 'assets/audio/sfx/win.mp3';
  static const String sfxStarPop = 'assets/audio/sfx/star_pop.mp3';
}
