import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/profile_cubit.dart';
import '../../theme/daylight_theme.dart';
import '../tactile_widgets.dart';
import 'username_prompt_dialog.dart';

class ProfileDialog {
  ProfileDialog._();

  static Future<void> show(
    BuildContext context, {
    required ProfileCubit profileCubit,
  }) async {
    profileCubit.clearTransientState();
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => BlocProvider<ProfileCubit>.value(
        value: profileCubit,
        child: const _ProfileDialogContent(),
      ),
    );
  }
}

class _ProfileDialogContent extends StatefulWidget {
  const _ProfileDialogContent();

  @override
  State<_ProfileDialogContent> createState() => _ProfileDialogContentState();
}

class _ProfileDialogContentState extends State<_ProfileDialogContent> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();
        final isRecoverable = state.isRecoverable;

        return PopScope(
          canPop: !state.isBusy,
          child: Dialog(
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
                  _buildHeader(context, cubit, state),
                  const SizedBox(height: 14),
                  _buildAccountBanner(state),
                  const SizedBox(height: 12),
                  if (state.otpStep == OtpFlowStep.enterEmail)
                    _buildEmailStep(cubit, state)
                  else if (state.otpStep == OtpFlowStep.enterCode)
                    _buildOtpCodeStep(cubit, state)
                  else ...[
                    if (!isRecoverable) ...[
                      TactileKeycap(
                        enabled: !state.isBusy,
                        onTap: state.isBusy ? null : cubit.startEmailLinking,
                        surfaceColor: DaylightColors.frontierFill,
                        lipColor: DaylightColors.frontierAmberLip,
                        borderColor: DaylightColors.frontierAmber,
                        borderWidth: 1.5,
                        borderRadius: 12,
                        lipHeight: 3,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.mark_email_read_rounded,
                              size: 18,
                              color: DaylightColors.frontierAmberLip,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Link Email for Cloud Backup & Recovery',
                                textAlign: TextAlign.center,
                                style: DaylightTypography.rounded(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: DaylightColors.inkPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      _buildCloudSyncToggle(cubit, state),
                    ],
                  ],
                  if (state.statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildStatusBanner(state),
                  ],
                  const SizedBox(height: 14),
                  _buildFooterActions(context, cubit, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ProfileCubit cubit,
    ProfileState state,
  ) {
    final badgeColor = state.isRecoverable && state.isCloudSynced
        ? DaylightColors.completedMintLip
        : state.isRecoverable
            ? DaylightColors.frontierAmberLip
            : DaylightColors.inkSecondary;

    final statusSubtitle = !state.isRecoverable
        ? 'Guest Mode (Local Only)'
        : state.isCloudSynced
            ? 'Cloud Synced • ${state.email}'
            : state.cloudSyncEnabled
                ? 'Cloud Account Linked • Sync Pending'
                : 'Cloud Sync Paused • ${state.email}';

    return Row(
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
          child: Icon(
            state.isRecoverable
                ? Icons.cloud_done_rounded
                : Icons.person_rounded,
            color: badgeColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.username ?? 'Guest Driver',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DaylightTypography.rounded(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: DaylightColors.inkPrimary,
                ),
              ),
              Text(
                statusSubtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DaylightTypography.rounded(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
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
          onPressed: state.isBusy
              ? null
              : () async {
                  Navigator.of(context).pop();
                  await UsernamePromptDialog.show(
                    context,
                    profileCubit: cubit,
                    allowGuestSkip: false,
                  );
                },
        ),
      ],
    );
  }

  Widget _buildAccountBanner(ProfileState state) {
    final isRecoverable = state.isRecoverable;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DaylightColors.canvasBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DaylightColors.surfaceLip),
      ),
      child: Text(
        isRecoverable
            ? 'Your progress is linked to ${state.email}. You can sign in with this email on any device or after reinstalling to restore your profile and stars.'
            : 'Offline Guest mode stores progress only on this device. Uninstalling the app erases local data unless you link an email account.',
        style: DaylightTypography.rounded(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: DaylightColors.inkSecondary,
        ).copyWith(height: 1.35),
      ),
    );
  }

  Widget _buildCloudSyncToggle(ProfileCubit cubit, ProfileState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: DaylightColors.canvasBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DaylightColors.surfaceLip),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Auto Cloud Backup',
                  style: DaylightTypography.rounded(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DaylightColors.inkPrimary,
                  ),
                ),
              ),
              Switch.adaptive(
                value: state.cloudSyncEnabled,
                activeTrackColor: DaylightColors.completedMint,
                onChanged: state.isBusy ? null : cubit.toggleCloudSync,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: state.isBusy ? null : cubit.signOutCloudAccount,
            icon: const Icon(
              Icons.logout_rounded,
              size: 16,
              color: DaylightColors.inkSecondary,
            ),
            label: Text(
              'Sign Out Cloud Account',
              style: DaylightTypography.rounded(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: DaylightColors.inkSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailStep(ProfileCubit cubit, ProfileState state) {
    final isSending = state.status == ProfileActionStatus.sendingOtp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter your email to receive a 6-digit recovery code:',
          style: DaylightTypography.rounded(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DaylightColors.inkPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          enabled: !isSending,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => cubit.clearValidationError(),
          style: DaylightTypography.rounded(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DaylightColors.inkPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'driver@example.com',
            errorText: state.validationError,
            filled: true,
            fillColor: DaylightColors.canvasBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DaylightColors.surfaceLip),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TactileKeycap(
                enabled: !isSending,
                onTap: isSending ? null : cubit.cancelEmailLinking,
                surfaceColor: DaylightColors.canvasBg,
                lipColor: DaylightColors.surfaceLip,
                borderColor: DaylightColors.surfaceLip,
                borderRadius: 12,
                lipHeight: 3,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: DaylightTypography.rounded(
                      fontSize: 13,
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
                enabled: !isSending,
                onTap: isSending
                    ? null
                    : () => cubit.sendEmailOtp(_emailController.text),
                surfaceColor: DaylightColors.frontierAmber,
                lipColor: DaylightColors.frontierAmberLip,
                borderRadius: 12,
                lipHeight: 3,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    isSending ? 'Sending...' : 'Send Code',
                    style: DaylightTypography.rounded(
                      fontSize: 13,
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
    );
  }

  Widget _buildOtpCodeStep(ProfileCubit cubit, ProfileState state) {
    final isVerifying = state.status == ProfileActionStatus.verifyingOtp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit code sent to ${state.pendingEmail ?? 'your email'}:',
          style: DaylightTypography.rounded(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: DaylightColors.inkPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _otpController,
          enabled: !isVerifying,
          keyboardType: TextInputType.number,
          maxLength: 8,
          onChanged: (_) => cubit.clearValidationError(),
          style: DaylightTypography.rounded(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DaylightColors.inkPrimary,
            tabular: true,
          ),
          decoration: InputDecoration(
            hintText: '123456',
            counterText: '',
            errorText: state.validationError,
            filled: true,
            fillColor: DaylightColors.canvasBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: DaylightColors.surfaceLip),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TactileKeycap(
                enabled: !isVerifying,
                onTap: isVerifying ? null : cubit.backToEmailStep,
                surfaceColor: DaylightColors.canvasBg,
                lipColor: DaylightColors.surfaceLip,
                borderColor: DaylightColors.surfaceLip,
                borderRadius: 12,
                lipHeight: 3,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    'Change Email',
                    style: DaylightTypography.rounded(
                      fontSize: 13,
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
                enabled: !isVerifying,
                onTap: isVerifying
                    ? null
                    : () => cubit.verifyEmailOtp(_otpController.text),
                surfaceColor: DaylightColors.completedMint,
                lipColor: DaylightColors.completedMintLip,
                borderRadius: 12,
                lipHeight: 3,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    isVerifying ? 'Verifying...' : 'Verify & Sync',
                    style: DaylightTypography.rounded(
                      fontSize: 13,
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
    );
  }

  Widget _buildStatusBanner(ProfileState state) {
    final isError = state.status == ProfileActionStatus.error;
    final accent =
        isError ? DaylightColors.brandRed : DaylightColors.completedMintLip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.statusMessage!,
              style: DaylightTypography.rounded(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(
    BuildContext context,
    ProfileCubit cubit,
    ProfileState state,
  ) {
    final isSyncing = state.status == ProfileActionStatus.syncing;
    return Row(
      children: [
        if (state.otpStep == OtpFlowStep.none) ...[
          Expanded(
            child: TactileKeycap(
              enabled: !state.isBusy,
              onTap: state.isBusy ? null : cubit.syncNow,
              surfaceColor: DaylightColors.canvasBg,
              lipColor: DaylightColors.surfaceLip,
              borderColor: DaylightColors.surfaceLip,
              borderRadius: 12,
              lipHeight: 3,
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Center(
                child: isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DaylightColors.inkPrimary,
                        ),
                      )
                    : Text(
                        'Sync Now',
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
            enabled: !state.isBusy,
            onTap: state.isBusy ? null : () => Navigator.of(context).pop(),
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
    );
  }
}
