import 'package:flutter/foundation.dart';

@immutable
abstract class BiometricGateState {
  const BiometricGateState();
}

class BiometricGateInitial extends BiometricGateState {
  const BiometricGateInitial();
}

class BiometricGateChecking extends BiometricGateState {
  const BiometricGateChecking();
}

class BiometricGateUnlocked extends BiometricGateState {
  const BiometricGateUnlocked();
}

class BiometricGateFailure extends BiometricGateState {
  final String message;
  const BiometricGateFailure(this.message);
}
