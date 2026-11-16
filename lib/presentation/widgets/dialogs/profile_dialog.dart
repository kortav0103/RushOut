import 'package:flutter/material.dart';
import '../../../core/services/player_identity_service.dart';
import '../../theme/daylight_theme.dart';
import '../tactile_widgets.dart';

class ProfileDialog {
  ProfileDialog._();

  static Future<void> show(
    BuildContext context, {
    required PlayerIdentityService identity,
    required Future<void> Function() onEditName,
    VoidCallback? onSynced,
  }) async {
    bool isSyncing = false;
    String? statusMsg;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final synced = identity.isCloudSynced;
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
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: DaylightColors.frontierFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: DaylightColors.frontierAmber,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: DaylightColors.frontierAmberLip,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                identity.username ?? 'Guest Driver',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DaylightTypography.rounded(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: DaylightColors.inkPrimary,
                                ),
                              ),
                              Text(
                                synced
                                    ? 'Cloud Synced'
                                    : identity.isCloudSyncEnabled
                                        ? 'Cloud Sync Enabled (Pending)'
                                        : 'Local Only (Cloud Sync Off)',
                                style: DaylightTypography.rounded(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: synced
                                      ? DaylightColors.completedMintLip
                                      : DaylightColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit Name',
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: DaylightColors.inkPrimary,
                            size: 20,
                          ),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            await onEditName();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: DaylightColors.canvasBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DaylightColors.surfaceLip),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Cloud Progress Sync',
                              style: DaylightTypography.rounded(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: DaylightColors.inkPrimary,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: identity.isCloudSyncEnabled,
                            activeTrackColor: DaylightColors.completedMint,
                            onChanged: isSyncing
                                ? null
                                : (enabled) async {
                                    await identity.setCloudSyncEnabled(enabled);
                                    if (enabled && ctx.mounted) {
                                      setDialogState(() {
                                        isSyncing = true;
                                        statusMsg = null;
                                      });
                                      final ok = await identity.syncWithCloud();
                                      if (ctx.mounted) {
                                        setDialogState(() {
                                          isSyncing = false;
                                          statusMsg = ok
                                              ? 'Progress synced to cloud!'
                                              : 'Sync enabled. Will sync when online.';
                                        });
                                      }
                                    } else if (ctx.mounted) {
                                      setDialogState(() {
                                        statusMsg = 'Cloud sync disabled (local only).';
                                      });
                                    }
                                    onSynced?.call();
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (statusMsg != null) ...[
                      Text(
                        statusMsg!,
                        style: DaylightTypography.rounded(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: DaylightColors.completedMintLip,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TactileKeycap(
                            enabled: !isSyncing,
                            onTap: isSyncing
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isSyncing = true;
                                      statusMsg = null;
                                    });
                                    await identity.setCloudSyncEnabled(true);
                                    final ok = await identity.syncWithCloud(force: true);
                                    if (ctx.mounted) {
                                      setDialogState(() {
                                        isSyncing = false;
                                        statusMsg = ok
                                            ? 'Progress synced to cloud!'
                                            : 'Offline or Supabase not configured.';
                                      });
                                    }
                                    onSynced?.call();
                                  },
                            surfaceColor: DaylightColors.canvasBg,
                            lipColor: DaylightColors.surfaceLip,
                            borderColor: DaylightColors.surfaceLip,
                            borderRadius: 12,
                            lipHeight: 3,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Center(
                              child: Text(
                                isSyncing ? 'Syncing...' : 'Sync Now',
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
                        Expanded(
                          child: TactileKeycap(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            surfaceColor: DaylightColors.brandRed,
                            lipColor: DaylightColors.brandRedLip,
                            borderRadius: 12,
                            lipHeight: 3,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Center(
                              child: Text(
                                'Close',
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
  }
}
