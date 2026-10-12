import 'package:file_picker/file_picker.dart';
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_bloc.dart';
import 'package:finance_frontend/features/accounts/presentation/blocs/accounts/accounts_event.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budgets/budgets_event.dart';
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_bloc.dart';
import 'package:finance_frontend/features/categories/presentation/blocs/categories/categories_event.dart';
import 'package:finance_frontend/features/settings/data/services/hive_export_import_service.dart';
import 'package:finance_frontend/features/settings/presentation/cubits/data_transfer_state.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_bloc.dart';
import 'package:finance_frontend/features/transactions/presentation/bloc/transactions/transactions_event.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

/// Manages Hive data export and import operations.
///
/// After a successful import it triggers [RefreshAccounts], [RefreshTransactions],
/// [RefreshCategories], and [RefreshBudgets] on the existing BLoCs so the UI
/// reflects the restored data without requiring an app restart.
class DataTransferCubit extends Cubit<DataTransferState> {
  DataTransferCubit(this._service) : super(const DataTransferIdle());

  final HiveExportImportService _service;

  // Optional BLoC references — set by the Settings screen when it mounts.
  AccountsBloc? _accountsBloc;
  TransactionsBloc? _transactionsBloc;
  CategoriesBloc? _categoriesBloc;
  BudgetsBloc? _budgetsBloc;

  /// Inject living BLoC references so the cubit can reload them after import.
  void registerBlocs({
    required AccountsBloc accountsBloc,
    required TransactionsBloc transactionsBloc,
    required CategoriesBloc categoriesBloc,
    required BudgetsBloc budgetsBloc,
  }) {
    _accountsBloc = accountsBloc;
    _transactionsBloc = transactionsBloc;
    _categoriesBloc = categoriesBloc;
    _budgetsBloc = budgetsBloc;
  }

  // ── Export ────────────────────────────────────────────────────────────────

  /// Exports all Hive data to a zip archive and triggers the OS share sheet.
  Future<void> exportData() async {
    if (state is DataTransferLoading) return;
    emit(const DataTransferLoading());

    try {
      final zipPath = await _service.exportData();
      await Share.shareXFiles(
        [XFile(zipPath)],
        text: 'Zorvyn Finance Backup',
      );
      emit(const DataTransferSuccess('Data exported successfully.'));
    } catch (e) {
      emit(DataTransferFailure(e.toString()));
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Opens a file picker, imports the selected backup zip, then refreshes all
  /// BLoCs so the UI reflects the restored data immediately.
  Future<void> importData() async {
    if (state is DataTransferLoading) return;

    // Let the user pick a file first (before we show loading).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select Zorvyn Backup File',
    );

    if (result == null || result.files.single.path == null) {
      // User cancelled — do nothing.
      return;
    }

    emit(const DataTransferLoading());

    try {
      final zipPath = result.files.single.path!;
      await _service.importData(zipPath);

      // Reload all BLoCs from the freshly-restored Hive data.
      _reloadBlocs();

      emit(const DataTransferSuccess('Data imported successfully.'));
    } catch (e) {
      emit(DataTransferFailure(e.toString()));
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  void _reloadBlocs() {
    _accountsBloc?.add(const RefreshAccounts());
    _transactionsBloc?.add(const RefreshTransactions());
    _categoriesBloc?.add(const RefreshCategories());
    _budgetsBloc?.add(const RefreshBudgets());
  }

  /// Resets to idle (e.g. so a snackbar can be re-shown on the next action).
  void reset() => emit(const DataTransferIdle());
}
