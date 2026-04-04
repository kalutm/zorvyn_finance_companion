import 'package:finance_frontend/features/biometrics/domain/services/biometric_auth_service.dart';
import 'package:finance_frontend/features/biometrics/presentation/cubits/biometric_gate_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BiometricGateCubit extends Cubit<BiometricGateState> {
  final BiometricAuthService _biometricAuthService;

  BiometricGateCubit(this._biometricAuthService)
    : super(const BiometricGateInitial());

  Future<void> unlockApp() async {
    emit(const BiometricGateChecking());

    final canAuthenticate = await _biometricAuthService.canAuthenticate();
    if (!canAuthenticate) {
      emit(
        const BiometricGateFailure(
          'Biometric authentication is not available on this device.',
        ),
      );
      return;
    }

    final authenticated = await _biometricAuthService.authenticate(
      reason: 'Authenticate to access Finance Companion',
    );

    if (!authenticated) {
      emit(
        const BiometricGateFailure(
          'Authentication failed. Please verify your identity and try again.',
        ),
      );
      return;
    }

    emit(const BiometricGateUnlocked());
  }
}
