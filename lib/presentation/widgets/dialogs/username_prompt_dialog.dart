import 'package:flutter/material.dart';
import '../../../core/services/player_identity_service.dart';
import '../../theme/daylight_theme.dart';
import '../tactile_widgets.dart';

class UsernamePromptDialog {
  UsernamePromptDialog._();

  static Future<void> show(
    BuildContext context, {
    required PlayerIdentityService identity,
    bool isFirstLaunch = false,
    VoidCallback? onSaved,
  }) async {
    final controller = TextEditingController(text: identity.username ?? '');
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isFirstLaunch,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: DaylightColors.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: DaylightColors.surfaceLip,
                  width: 2,
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color:
                                DaylightColors.brandRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: DaylightColors.brandRed,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isFirstLaunch
                                ? 'Pick Your Driver Name'
                                : 'Edit Driver Name',
                            style: DaylightTypography.rounded(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: DaylightColors.inkPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isFirstLaunch
                          ? 'Your campaign progress is saved locally on this device. You can optionally enable Cloud Sync anytime in your Driver Profile.'
                          : 'This name appears on your local profile and Daily Challenge leaderboard.',
                      style: DaylightTypography.rounded(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DaylightColors.inkSecondary,
                      ).copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 24,
                      style: DaylightTypography.rounded(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: DaylightColors.inkPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter username (2–24 chars)...',
                        errorText: errorText,
                        errorMaxLines: 2,
                        filled: true,
                        fillColor: DaylightColors.canvasBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: DaylightColors.surfaceLip,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!isFirstLaunch) ...[
                          Expanded(
                            child: TactileKeycap(
                              onTap: () => Navigator.of(dialogContext).pop(),
                              surfaceColor: DaylightColors.canvasBg,
                              lipColor: DaylightColors.surfaceLip,
                              borderColor: DaylightColors.surfaceLip,
                              borderRadius: 12,
                              lipHeight: 3,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Center(
                                child: Text(
                                  'Cancel',
                                  style: DaylightTypography.rounded(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: DaylightColors.inkPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: TactileKeycap(
                            onTap: () async {
                              final name = controller.text.trim();
                              final validationError =
                                  PlayerIdentityService.validateUsername(name);
                              if (validationError != null) {
                                if (ctx.mounted) {
                                  setDialogState(() {
                                    errorText = validationError;
                                  });
                                }
                                return;
                              }
                              try {
                                await identity.setUsername(name);
                              } catch (e) {
                                if (ctx.mounted) {
                                  setDialogState(() {
                                    errorText = e.toString();
                                  });
                                }
                                return;
                              }
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              onSaved?.call();
                            },
                            surfaceColor: DaylightColors.brandRed,
                            lipColor: DaylightColors.brandRedLip,
                            borderRadius: 12,
                            lipHeight: 3,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Center(
                              child: Text(
                                isFirstLaunch ? "Let's Go!" : 'Save',
                                style: DaylightTypography.rounded(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }
}
