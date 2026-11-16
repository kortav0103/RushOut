import 'package:flutter/material.dart';
import '../../theme/daylight_theme.dart';
import '../tactile_widgets.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const PrivacyPolicyDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DaylightColors.surfaceWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DaylightColors.surfaceLip, width: 1.5),
      ),
      title: Row(
        children: [
          const Icon(Icons.shield_outlined, color: DaylightColors.completedMint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Privacy Policy & Terms',
              style: DaylightTypography.rounded(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '1. Local Data Storage (Offline-First)',
              style: TextStyle(
                color: DaylightColors.inkPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Campaign level progress, star ratings, in-progress board moves, and audio preferences are stored locally on your device using SQLite and SharedPreferences. Uninstalling the app or clearing app data removes local data.',
              style: TextStyle(
                color: DaylightColors.inkSecondary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '2. Daily Challenge & Leaderboard',
              style: TextStyle(
                color: DaylightColors.inkPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'When you choose to submit a Daily Challenge score, an anonymous session identifier, your chosen display nickname, completion date, and move count are transmitted to our Supabase leaderboard service. No contacts, location data, or email addresses are collected.',
              style: TextStyle(
                color: DaylightColors.inkSecondary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '3. Optional Cloud Progress Sync',
              style: TextStyle(
                color: DaylightColors.inkPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Cloud sync is disabled by default. When you explicitly enable Cloud Sync in your Driver Profile, we transmit your anonymous session ID, an app-scoped installation identifier, nickname, tutorial status, campaign level progress, and update timestamps to Supabase so your profile is backed up under your anonymous session.',
              style: TextStyle(
                color: DaylightColors.inkSecondary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '4. Fair Play & Community Standards',
              style: TextStyle(
                color: DaylightColors.inkPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Submitted nicknames must be appropriate and free of offensive language or links. Scores are validated server-side and limited to one submission per player per day.',
              style: TextStyle(
                color: DaylightColors.inkSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TactileKeycap(
          onTap: () => Navigator.of(context).pop(),
          surfaceColor: DaylightColors.brandRed,
          lipColor: DaylightColors.brandRedLip,
          borderRadius: 12,
          lipHeight: 3,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'Close',
            style: DaylightTypography.rounded(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
