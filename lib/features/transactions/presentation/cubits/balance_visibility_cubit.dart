import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages whether sensitive monetary amounts are visible or obscured.
///
/// The state is a plain [bool]: `true` = balances are visible,
/// `false` = balances are hidden (default). Balances start hidden on every
/// app launch — the user must tap the eye icon to reveal them.
/// This is intentionally session-scoped and not persisted.
class BalanceVisibilityCubit extends Cubit<bool> {
  BalanceVisibilityCubit() : super(false);

  /// Flips the current visibility state.
  void toggle() => emit(!state);
}
