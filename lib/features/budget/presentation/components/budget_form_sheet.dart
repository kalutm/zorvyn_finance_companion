import 'package:decimal/decimal.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_create.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_patch.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_bloc.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_event.dart';
import 'package:finance_frontend/features/budget/presentation/blocs/budget_form/budget_form_state.dart';
import 'package:finance_frontend/features/categories/domain/entities/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetFormSheet extends StatefulWidget {
  static const String allCategoriesValue = '__all_categories__';
  static const String allAccountsValue = '__all_accounts__';

  final Budget? initialBudget;
  final List<FinanceCategory> categories;
  final List<Account> accounts;

  const BudgetFormSheet({
    super.key,
    this.initialBudget,
    required this.categories,
    required this.accounts,
  });

  @override
  State<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();

  String _selectedCategoryId = BudgetFormSheet.allCategoriesValue;
  String _selectedAccountId = BudgetFormSheet.allAccountsValue;
  double _alertThreshold = 80;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBudget;
    if (initial != null) {
      _nameCtrl.text = initial.name;
      _limitCtrl.text = initial.limitAmount;
      _currencyCtrl.text = initial.currency;
      _selectedCategoryId =
          initial.categoryId ?? BudgetFormSheet.allCategoriesValue;
      _selectedAccountId =
          initial.accountId ?? BudgetFormSheet.allAccountsValue;
      _alertThreshold = initial.alertThreshold.toDouble();
    } else {
      _currencyCtrl.text = 'ETB';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  String _normalizeScopeValue(String value) {
    if (value == BudgetFormSheet.allCategoriesValue ||
        value == BudgetFormSheet.allAccountsValue) {
      return '';
    }
    return value;
  }

  bool _isValidDecimal(String value) {
    try {
      final parsed = Decimal.parse(value);
      return parsed > Decimal.zero;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialBudget != null;

    return BlocListener<BudgetFormBloc, BudgetFormState>(
      listener: (context, state) {
        if (state is BudgetOperationSuccess ||
            state is BudgetDeleteOperationSuccess) {
          Navigator.of(context).pop();
        } else if (state is BudgetOperationFailure) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isEditing ? 'Edit Budget' : 'Create Budget',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            hintText: 'e.g., Monthly Groceries Budget',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Name required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _limitCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Budget Limit',
                            hintText: 'e.g., 5000',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) {
                              return 'Budget amount required';
                            }
                            if (!_isValidDecimal(value)) {
                              return 'Enter a valid amount greater than 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currencyCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            hintText: 'e.g., ETB',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 3,
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.length != 3) {
                              return 'Currency code must be 3 letters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category Scope',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: BudgetFormSheet.allCategoriesValue,
                              child: Text('All categories'),
                            ),
                            ...widget.categories
                                .where((c) => c.active)
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedAccountId,
                          decoration: const InputDecoration(
                            labelText: 'Account Scope',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: BudgetFormSheet.allAccountsValue,
                              child: Text('All accounts'),
                            ),
                            ...widget.accounts
                                .where((a) => a.active)
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(a.name),
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedAccountId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Warning threshold (${_alertThreshold.round()}%)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: _alertThreshold,
                          min: 50,
                          max: 100,
                          divisions: 10,
                          label: '${_alertThreshold.round()}%',
                          onChanged: (value) {
                            setState(() {
                              _alertThreshold = value;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _submit(context, isEditing),
                          child: Text(
                            isEditing ? 'Save Changes' : 'Create Budget',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context, bool isEditing) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameCtrl.text.trim();
    final limit = _limitCtrl.text.trim();
    final currency = _currencyCtrl.text.trim().toUpperCase();
    final categoryId = _normalizeScopeValue(_selectedCategoryId);
    final accountId = _normalizeScopeValue(_selectedAccountId);
    final alert = _alertThreshold.round();

    if (isEditing && widget.initialBudget != null) {
      final initial = widget.initialBudget!;
      final patch = BudgetPatch(
        name: name != initial.name ? name : null,
        limitAmount: limit != initial.limitAmount ? limit : null,
        currency: currency != initial.currency ? currency : null,
        categoryId:
            categoryId != (initial.categoryId ?? '') ? categoryId : null,
        accountId: accountId != (initial.accountId ?? '') ? accountId : null,
        alertThreshold: alert != initial.alertThreshold ? alert : null,
      );

      if (patch.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      context.read<BudgetFormBloc>().add(UpdateBudget(initial.id, patch));
      return;
    }

    final create = BudgetCreate(
      name: name,
      limitAmount: limit,
      currency: currency,
      categoryId: categoryId,
      accountId: accountId,
      alertThreshold: alert,
    );

    context.read<BudgetFormBloc>().add(CreateBudget(create));
  }
}
