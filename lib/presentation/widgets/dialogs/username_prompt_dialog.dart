import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/profile_cubit.dart';
import '../../theme/daylight_theme.dart';
import '../tactile_widgets.dart';

class UsernamePromptDialog {
  UsernamePromptDialog._();

  static Future<void> show(
    BuildContext context, {
    required ProfileCubit profileCubit,
    bool allowGuestSkip = true,
    bool requireName = false,
  }) async {
    profileCubit.clearTransientState();
    await showDialog<void>(
      context: context,
      barrierDismissible: !requireName,
      builder: (_) => BlocProvider<ProfileCubit>.value(
        value: profileCubit,
        child: _UsernamePromptDialogContent(
          allowGuestSkip: allowGuestSkip,
          requireName: requireName,
        ),
      ),
    );
  }
}

class _UsernamePromptDialogContent extends StatefulWidget {
  final bool allowGuestSkip;
  final bool requireName;

  const _UsernamePromptDialogContent({
    required this.allowGuestSkip,
    required this.requireName,
  });

  @override
  State<_UsernamePromptDialogContent> createState() =>
      _UsernamePromptDialogContentState();
}

class _UsernamePromptDialogContentState
    extends State<_UsernamePromptDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProfileCubit>();
    _controller = TextEditingController(text: cubit.state.username ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final cubit = context.read<ProfileCubit>();
    final saved = await cubit.saveUsername(_controller.text);
    if (saved && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final isSaving = state.status == ProfileActionStatus.savingName;
        final canDismiss = !isSaving && !widget.requireName;

        return PopScope(
          canPop: canDismiss,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: DaylightColors.brandRed.withValues(alpha: 0.12),
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
                          state.hasUsername
                              ? 'Edit Driver Name'
                              : 'Choose Driver Name',
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
                    state.isRecoverable
                        ? 'Your nickname is synced with your linked cloud account (${state.email}) and can be used on the Daily Leaderboard.'
                        : 'Play offline anytime as a Guest, or pick a nickname for your local profile and Daily Challenge submissions.',
                    style: DaylightTypography.rounded(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DaylightColors.inkSecondary,
                    ).copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    enabled: !isSaving,
                    autofocus: true,
                    maxLength: 24,
                    onChanged: (_) =>
                        context.read<ProfileCubit>().clearValidationError(),
                    onSubmitted: (_) => isSaving ? null : _onSubmit(),
                    style: DaylightTypography.rounded(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: DaylightColors.inkPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter nickname (2–24 chars)...',
                      errorText: state.validationError,
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
                  if (state.status == ProfileActionStatus.error &&
                      state.statusMessage != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      state.statusMessage!,
                      style: DaylightTypography.rounded(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DaylightColors.brandRed,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!widget.requireName) ...[
                        Expanded(
                          child: TactileKeycap(
                            enabled: !isSaving,
                            onTap: isSaving
                                ? null
                                : () => Navigator.of(context).pop(),
                            surfaceColor: DaylightColors.canvasBg,
                            lipColor: DaylightColors.surfaceLip,
                            borderColor: DaylightColors.surfaceLip,
                            borderRadius: 12,
                            lipHeight: 3,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Center(
                              child: Text(
                                widget.allowGuestSkip && !state.hasUsername
                                    ? 'Play as Guest'
                                    : 'Cancel',
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
                          enabled: !isSaving,
                          onTap: isSaving ? null : _onSubmit,
                          surfaceColor: DaylightColors.brandRed,
                          lipColor: DaylightColors.brandRedLip,
                          borderRadius: 12,
                          lipHeight: 3,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Center(
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Save',
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
          ),
        );
      },
    );
  }
}
