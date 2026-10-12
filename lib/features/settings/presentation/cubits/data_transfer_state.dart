import 'package:flutter/foundation.dart';

/// States for the [DataTransferCubit].
@immutable
abstract class DataTransferState {
  const DataTransferState();
}

/// The cubit is idle — no export or import in progress.
class DataTransferIdle extends DataTransferState {
  const DataTransferIdle();
}

/// An export or import operation is currently in progress.
class DataTransferLoading extends DataTransferState {
  const DataTransferLoading();
}

/// The operation completed successfully.
class DataTransferSuccess extends DataTransferState {
  final String message;
  const DataTransferSuccess(this.message);
}

/// The operation failed with an error message.
class DataTransferFailure extends DataTransferState {
  final String message;
  const DataTransferFailure(this.message);
}
