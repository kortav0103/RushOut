import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/error/exceptions.dart';
import '../../core/services/player_identity_service.dart';

enum ProfileActionStatus {
  idle,
  savingName,
  sendingOtp,
  verifyingOtp,
  syncing,
  deletingAccount,
  success,
  error,
}

enum OtpFlowStep {
  none,
  enterEmail,
  enterCode,
}

class ProfileState extends Equatable {
  final AccountMode accountMode;
  final String? username;
  final String? email;
  final bool cloudSyncEnabled;
  final bool isCloudSynced;
  final DateTime? lastSyncedAt;
  final ProfileActionStatus status;
  final OtpFlowStep otpStep;
  final String? pendingEmail;
  final String? statusMessage;
  final String? validationError;

  const ProfileState({
    this.accountMode = AccountMode.guest,
    this.username,
    this.email,
    this.cloudSyncEnabled = false,
    this.isCloudSynced = false,
    this.lastSyncedAt,
    this.status = ProfileActionStatus.idle,
    this.otpStep = OtpFlowStep.none,
    this.pendingEmail,
    this.statusMessage,
    this.validationError,
  });

  factory ProfileState.fromSnapshot(PlayerProfileSnapshot snapshot) {
    return ProfileState(
      accountMode: snapshot.accountMode,
      username: snapshot.username,
      email: snapshot.email,
      cloudSyncEnabled: snapshot.cloudSyncEnabled,
      isCloudSynced: snapshot.isCloudSynced,
      lastSyncedAt: snapshot.lastSyncedAt,
    );
  }

  bool get hasUsername => username != null && username!.trim().isNotEmpty;

  bool get isRecoverable =>
      accountMode == AccountMode.cloudAccount &&
      email != null &&
      email!.trim().isNotEmpty;

  bool get isBusy =>
      status == ProfileActionStatus.savingName ||
      status == ProfileActionStatus.sendingOtp ||
      status == ProfileActionStatus.verifyingOtp ||
      status == ProfileActionStatus.syncing ||
      status == ProfileActionStatus.deletingAccount;

  ProfileState copyWith({
    AccountMode? accountMode,
    String? username,
    bool clearUsername = false,
    String? email,
    bool clearEmail = false,
    bool? cloudSyncEnabled,
    bool? isCloudSynced,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    ProfileActionStatus? status,
    OtpFlowStep? otpStep,
    String? pendingEmail,
    bool clearPendingEmail = false,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return ProfileState(
      accountMode: accountMode ?? this.accountMode,
      username: clearUsername ? null : (username ?? this.username),
      email: clearEmail ? null : (email ?? this.email),
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      isCloudSynced: isCloudSynced ?? this.isCloudSynced,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      status: status ?? this.status,
      otpStep: otpStep ?? this.otpStep,
      pendingEmail:
          clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
      statusMessage:
          clearStatusMessage ? null : (statusMessage ?? this.statusMessage),
      validationError: clearValidationError
          ? null
          : (validationError ?? this.validationError),
    );
  }

  @override
  List<Object?> get props => [
        accountMode,
        username,
        email,
        cloudSyncEnabled,
        isCloudSynced,
        lastSyncedAt,
        status,
        otpStep,
        pendingEmail,
        statusMessage,
        validationError,
      ];
}

class ProfileCubit extends Cubit<ProfileState> {
  final PlayerIdentityService _identityService;

  ProfileCubit({
    required PlayerIdentityService identityService,
  })  : _identityService = identityService,
        super(ProfileState.fromSnapshot(identityService.snapshot)) {
    _identityService.snapshotNotifier.addListener(_onSnapshotChanged);
  }

  void _onSnapshotChanged() {
    if (isClosed) return;
    final snap = _identityService.snapshot;
    emit(
      state.copyWith(
        accountMode: snap.accountMode,
        username: snap.username,
        clearUsername: snap.username == null,
        email: snap.email,
        clearEmail: snap.email == null,
        cloudSyncEnabled: snap.cloudSyncEnabled,
        isCloudSynced: snap.isCloudSynced,
        lastSyncedAt: snap.lastSyncedAt,
        clearLastSyncedAt: snap.lastSyncedAt == null,
      ),
    );
  }

  void clearTransientState() {
    emit(
      state.copyWith(
        status: ProfileActionStatus.idle,
        otpStep: OtpFlowStep.none,
        clearPendingEmail: true,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );
  }

  void clearValidationError() {
    if (state.validationError != null) {
      emit(state.copyWith(clearValidationError: true));
    }
  }

  void startEmailLinking() {
    emit(
      state.copyWith(
        status: ProfileActionStatus.idle,
        otpStep: OtpFlowStep.enterEmail,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );
  }

  void backToEmailStep() {
    emit(
      state.copyWith(
        status: ProfileActionStatus.idle,
        otpStep: OtpFlowStep.enterEmail,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );
  }

  void cancelEmailLinking() {
    emit(
      state.copyWith(
        status: ProfileActionStatus.idle,
        otpStep: OtpFlowStep.none,
        clearPendingEmail: true,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );
  }

  Future<bool> saveUsername(String rawName) async {
    final validationError = PlayerIdentityService.validateUsername(rawName);
    if (validationError != null) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          validationError: validationError,
          clearStatusMessage: true,
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        status: ProfileActionStatus.savingName,
        clearValidationError: true,
        clearStatusMessage: true,
      ),
    );

    try {
      final syncReport = await _identityService.setUsername(rawName);
      if (syncReport != null && !syncReport.success) {
        emit(
          state.copyWith(
            status: ProfileActionStatus.error,
            statusMessage:
                'Name saved locally, but cloud sync failed: ${syncReport.errorMessage ?? 'Unknown error.'}',
          ),
        );
        return true;
      }
      emit(
        state.copyWith(
          status: ProfileActionStatus.success,
          statusMessage: syncReport != null
              ? 'Driver name saved and synced to cloud.'
              : 'Driver name saved locally.',
          clearValidationError: true,
        ),
      );
      return true;
    } on ArgumentError catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          validationError: e.message?.toString() ?? 'Invalid nickname.',
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: 'Unable to save driver name. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> sendEmailOtp(String rawEmail) async {
    final emailError = PlayerIdentityService.validateEmail(rawEmail);
    if (emailError != null) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          validationError: emailError,
          clearStatusMessage: true,
        ),
      );
      return false;
    }

    final normalized = rawEmail.trim().toLowerCase();
    emit(
      state.copyWith(
        status: ProfileActionStatus.sendingOtp,
        pendingEmail: normalized,
        clearValidationError: true,
        clearStatusMessage: true,
      ),
    );

    try {
      await _identityService.requestEmailOtp(normalized);
      emit(
        state.copyWith(
          status: ProfileActionStatus.success,
          otpStep: OtpFlowStep.enterCode,
          pendingEmail: normalized,
          statusMessage: 'Verification code sent to $normalized.',
          clearValidationError: true,
        ),
      );
      return true;
    } on ServerException catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: e.message,
        ),
      );
      return false;
    } on ArgumentError catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          validationError: e.message?.toString() ?? 'Invalid email address.',
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: 'Failed to send verification code. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> verifyEmailOtp(String otpCode) async {
    final targetEmail = state.pendingEmail ?? '';
    final emailError = PlayerIdentityService.validateEmail(targetEmail);
    if (emailError != null) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          otpStep: OtpFlowStep.enterEmail,
          validationError: emailError,
        ),
      );
      return false;
    }

    final codeError = PlayerIdentityService.validateOtpCode(otpCode);
    if (codeError != null) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          validationError: codeError,
          clearStatusMessage: true,
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        status: ProfileActionStatus.verifyingOtp,
        clearValidationError: true,
        clearStatusMessage: true,
      ),
    );

    try {
      final report = await _identityService.verifyEmailOtpAndSync(
        email: targetEmail,
        otpCode: otpCode,
      );
      if (report.success) {
        emit(
          state.copyWith(
            status: ProfileActionStatus.success,
            otpStep: OtpFlowStep.none,
            clearPendingEmail: true,
            statusMessage: _formatSyncSuccessMessage(report, prefix: 'Account linked! '),
            clearValidationError: true,
          ),
        );
        return true;
      }

      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          otpStep: OtpFlowStep.none,
          clearPendingEmail: true,
          statusMessage:
              'Account verified, but initial sync failed: ${report.errorMessage ?? 'Please tap Sync Now.'}',
        ),
      );
      return true;
    } on ServerException catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: e.message,
        ),
      );
      return false;
    } on ArgumentError catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          validationError:
              e.message?.toString() ?? 'Invalid verification code.',
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: 'Unable to verify code right now. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<void> toggleCloudSync(bool enabled) async {
    if (enabled && !state.isRecoverable) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          otpStep: OtpFlowStep.enterEmail,
          statusMessage:
              'Link an email account first to enable cloud backup and recovery.',
          clearValidationError: true,
        ),
      );
      return;
    }

    try {
      await _identityService.setCloudSyncEnabled(enabled);
      if (!enabled) {
        emit(
          state.copyWith(
            status: ProfileActionStatus.success,
            statusMessage:
                'Cloud sync turned off. Progress remains saved locally.',
            clearValidationError: true,
          ),
        );
        return;
      }
      await syncNow();
    } on ServerException catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: e.message,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: 'Unable to update cloud sync preference.',
        ),
      );
    }
  }

  Future<CloudSyncReport> syncNow() async {
    emit(
      state.copyWith(
        status: ProfileActionStatus.syncing,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );

    final report = await _identityService.syncWithCloud(force: true);
    if (report.success) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.success,
          statusMessage: _formatSyncSuccessMessage(report),
          clearValidationError: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage:
              report.errorMessage ?? 'Cloud sync failed. Please try again.',
          clearValidationError: true,
        ),
      );
    }
    return report;
  }

  Future<void> syncInBackground() async {
    if (!_identityService.isCloudSyncEnabled) return;
    await _identityService.syncWithCloud();
  }

  Future<void> signOutCloudAccount() async {
    emit(
      state.copyWith(
        status: ProfileActionStatus.syncing,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );
    try {
      await _identityService.signOutCloudAccount();
      emit(
        state.copyWith(
          status: ProfileActionStatus.success,
          otpStep: OtpFlowStep.none,
          clearPendingEmail: true,
          statusMessage:
              'Signed out of cloud account. Local progress remains on this device.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: 'Failed to sign out. Please try again.',
        ),
      );
    }
  }

  Future<bool> deleteCloudAccount() async {
    emit(
      state.copyWith(
        status: ProfileActionStatus.deletingAccount,
        clearStatusMessage: true,
        clearValidationError: true,
      ),
    );
    try {
      await _identityService.deleteCloudAccount();
      emit(
        state.copyWith(
          status: ProfileActionStatus.success,
          otpStep: OtpFlowStep.none,
          clearPendingEmail: true,
          statusMessage:
              'Cloud account deleted. Local progress remains on this device.',
        ),
      );
      return true;
    } on ServerException catch (e) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          status: ProfileActionStatus.error,
          statusMessage: 'Failed to delete cloud account. Please try again.',
        ),
      );
      return false;
    }
  }

  static String _formatSyncSuccessMessage(
    CloudSyncReport report, {
    String prefix = '',
  }) {
    if (report.uploadedCount == 0 && report.downloadedCount == 0) {
      return '${prefix}Cloud progress is up to date!';
    }
    return '${prefix}Synced (${report.uploadedCount} uploaded, ${report.downloadedCount} restored).';
  }

  @override
  Future<void> close() {
    _identityService.snapshotNotifier.removeListener(_onSnapshotChanged);
    return super.close();
  }
}
