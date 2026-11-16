import 'package:flutter/material.dart';
import '../../theme/daylight_theme.dart';
import '../tactile_widgets.dart';

class SettingsDialog extends StatelessWidget {
  final bool Function() isMuted;
  final Future<void> Function() onToggleMute;
  final VoidCallback onReplayTutorial;
  final VoidCallback onOpenPrivacyPolicy;

  const SettingsDialog({
    super.key,
    required this.isMuted,
    required this.onToggleMute,
    required this.onReplayTutorial,
    required this.onOpenPrivacyPolicy,
  });

  static Future<void> show(
    BuildContext context, {
    required bool Function() isMuted,
    required Future<void> Function() onToggleMute,
    required VoidCallback onReplayTutorial,
    required VoidCallback onOpenPrivacyPolicy,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => SettingsDialog(
        isMuted: isMuted,
        onToggleMute: onToggleMute,
        onReplayTutorial: onReplayTutorial,
        onOpenPrivacyPolicy: onOpenPrivacyPolicy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final isSoundOn = !isMuted();
        return Dialog(
          backgroundColor: DaylightColors.surfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(
              color: DaylightColors.surfaceLip,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: DaylightColors.canvasBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DaylightColors.surfaceLip),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: DaylightColors.inkPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settings',
                      style: DaylightTypography.rounded(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: DaylightColors.inkPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: DaylightColors.canvasBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DaylightColors.surfaceLip),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSoundOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: isSoundOn
                            ? DaylightColors.frontierAmberLip
                            : DaylightColors.brandRed,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Sound & Music',
                          style: DaylightTypography.rounded(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: DaylightColors.inkPrimary,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: isSoundOn,
                        activeTrackColor: DaylightColors.completedMint,
                        onChanged: (_) async {
                          await onToggleMute();
                          if (dialogContext.mounted) {
                            setDialogState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SettingsActionTile(
                  icon: Icons.school_rounded,
                  iconColor: DaylightColors.brandRed,
                  title: 'Replay Tutorial',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onReplayTutorial();
                  },
                ),
                const SizedBox(height: 10),
                _SettingsActionTile(
                  icon: Icons.shield_outlined,
                  iconColor: DaylightColors.completedMintLip,
                  title: 'Privacy Policy & Terms',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onOpenPrivacyPolicy();
                  },
                ),
                const SizedBox(height: 20),
                TactileKeycap(
                  onTap: () => Navigator.of(dialogContext).pop(),
                  surfaceColor: DaylightColors.brandRed,
                  lipColor: DaylightColors.brandRedLip,
                  borderRadius: 12,
                  lipHeight: 3,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Center(
                    child: Text(
                      'Done',
                      style: DaylightTypography.rounded(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TactileKeycap(
      onTap: onTap,
      surfaceColor: DaylightColors.canvasBg,
      lipColor: DaylightColors.surfaceLip,
      borderColor: DaylightColors.surfaceLip,
      borderRadius: 14,
      lipHeight: 2.5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: DaylightTypography.rounded(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: DaylightColors.inkPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: DaylightColors.inkSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
