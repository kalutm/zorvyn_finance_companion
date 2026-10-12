import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages whether sensitive monetary amounts are visible or obscured.
///
/// The state is a plain [bool]: `true` = balances are visible (default),
/// `false` = balances are hidden. This is intentionally session-scoped and
/// not persisted — privacy resets on every app launch.
class BalanceVisibilityCubit extends Cubit<bool> {
  BalanceVisibilityCubit() : super(true);

  /// Flips the current visibility state.
  void toggle() => emit(!state);
}
