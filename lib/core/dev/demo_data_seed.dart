import 'package:finance_frontend/features/accounts/domain/entities/account.dart';
import 'package:finance_frontend/features/accounts/domain/entities/account_type_enum.dart';
import 'package:finance_frontend/features/accounts/domain/entities/dtos/account_create.dart';
import 'package:finance_frontend/features/accounts/domain/service/account_service.dart';
import 'package:finance_frontend/features/budget/domain/entities/budget.dart';
import 'package:finance_frontend/features/budget/domain/entities/dtos/budget_create.dart';
import 'package:finance_frontend/features/budget/domain/service/budget_service.dart';
import 'package:finance_frontend/features/categories/domain/entities/category.dart';
import 'package:finance_frontend/features/categories/domain/entities/category_type_enum.dart';
import 'package:finance_frontend/features/categories/domain/entities/dtos/category_create.dart';
import 'package:finance_frontend/features/categories/domain/service/category_service.dart';
import 'package:finance_frontend/features/transactions/data/model/dtos/transaction_create.dart';
import 'package:finance_frontend/features/transactions/domain/entities/transaction_type.dart';
import 'package:finance_frontend/features/transactions/domain/service/transaction_service.dart';

class DemoSeedResult {
  final int accountsCreated;
  final int categoriesCreated;
  final int transactionsCreated;
  final int budgetsCreated;

  const DemoSeedResult({
    required this.accountsCreated,
    required this.categoriesCreated,
    required this.transactionsCreated,
    required this.budgetsCreated,
  });

  int get totalCreated =>
      accountsCreated +
      categoriesCreated +
      transactionsCreated +
      budgetsCreated;

  String summary() {
    return 'Demo data ready: '
        '$accountsCreated accounts, '
        '$categoriesCreated categories, '
        '$transactionsCreated transactions, '
        '$budgetsCreated budgets created.';
  }
}

Future<DemoSeedResult> seedDemoData({
  required AccountService accountService,
  required CategoryService categoryService,
  required TransactionService transactionService,
  required BudgetService budgetService,
}) async {
  var accountsCreated = 0;
  var categoriesCreated = 0;
  var transactionsCreated = 0;
  var budgetsCreated = 0;

  final accounts = List<Account>.from(await accountService.getUserAccounts());
  final categories = List<FinanceCategory>.from(
    await categoryService.getUserCategories(),
  );
  final budgets = List<Budget>.from(await budgetService.getUserBudgets());
  final transactions = List.from(
    await transactionService.getUserTransactions(),
  );

  Future<Account> ensureAccount({
    required String name,
    required AccountType type,
    required String currency,
  }) async {
    final existing = accounts.where(
      (a) =>
          a.name.toLowerCase() == name.toLowerCase() &&
          a.currency.toUpperCase() == currency.toUpperCase(),
    );

    if (existing.isNotEmpty) {
      final account = existing.first;
      if (!account.active) {
        final restored = await accountService.restoreAccount(account.id);
        final idx = accounts.indexWhere((a) => a.id == account.id);
        if (idx != -1) {
          accounts[idx] = restored;
        }
        return restored;
      }
      return account;
    }

    final created = await accountService.createAccount(
      AccountCreate(name: name, type: type, currency: currency),
    );
    accountsCreated += 1;
    accounts.add(created);
    return created;
  }

  Future<FinanceCategory> ensureCategory({
    required String name,
    required CategoryType type,
    String? description,
  }) async {
    final existing = categories.where(
      (c) => c.name.toLowerCase() == name.toLowerCase() && c.type == type,
    );

    if (existing.isNotEmpty) {
      final category = existing.first;
      if (!category.active) {
        final restored = await categoryService.restoreCategory(category.id);
        final idx = categories.indexWhere((c) => c.id == category.id);
        if (idx != -1) {
          categories[idx] = restored;
        }
        return restored;
      }
      return category;
    }

    final created = await categoryService.createCategory(
      CategoryCreate(name: name, type: type, description: description),
    );
    categoriesCreated += 1;
    categories.add(created);
    return created;
  }

  Future<Budget> ensureBudget({
    required String name,
    required String limitAmount,
    required String currency,
    required String categoryId,
    int alertThreshold = 80,
  }) async {
    final existing = budgets.where(
      (b) => b.name.toLowerCase() == name.toLowerCase(),
    );

    if (existing.isNotEmpty) {
      final budget = existing.first;
      if (!budget.active) {
        final restored = await budgetService.restoreBudget(budget.id);
        final idx = budgets.indexWhere((b) => b.id == budget.id);
        if (idx != -1) {
          budgets[idx] = restored;
        }
        return restored;
      }
      return budget;
    }

    final created = await budgetService.createBudget(
      BudgetCreate(
        name: name,
        limitAmount: limitAmount,
        currency: currency,
        categoryId: categoryId,
        alertThreshold: alertThreshold,
      ),
    );
    budgetsCreated += 1;
    budgets.add(created);
    return created;
  }

  final wallet = await ensureAccount(
    name: 'Cash Wallet',
    type: AccountType.CASH,
    currency: 'USD',
  );
  final bank = await ensureAccount(
    name: 'Main Bank',
    type: AccountType.BANK,
    currency: 'USD',
  );

  final salary = await ensureCategory(
    name: 'Salary',
    type: CategoryType.INCOME,
    description: 'Monthly salary income',
  );
  final freelance = await ensureCategory(
    name: 'Freelance',
    type: CategoryType.INCOME,
    description: 'Freelance side projects',
  );
  final groceries = await ensureCategory(
    name: 'Groceries',
    type: CategoryType.EXPENSE,
    description: 'Food and household supplies',
  );
  final transport = await ensureCategory(
    name: 'Transport',
    type: CategoryType.EXPENSE,
    description: 'Taxi, fuel, and commute',
  );
  final utilities = await ensureCategory(
    name: 'Utilities',
    type: CategoryType.EXPENSE,
    description: 'Power, internet, and phone',
  );
  final entertainment = await ensureCategory(
    name: 'Entertainment',
    type: CategoryType.EXPENSE,
    description: 'Streaming and outings',
  );

  await ensureBudget(
    name: 'Monthly Groceries Budget',
    limitAmount: '5500',
    currency: 'USD',
    categoryId: groceries.id,
    alertThreshold: 80,
  );
  await ensureBudget(
    name: 'Monthly Transport Budget',
    limitAmount: '3000',
    currency: 'USD',
    categoryId: transport.id,
    alertThreshold: 75,
  );
  await ensureBudget(
    name: 'Monthly Entertainment Budget',
    limitAmount: '2500',
    currency: 'USD',
    categoryId: entertainment.id,
    alertThreshold: 70,
  );

  final existingDemoDescriptions =
      transactions
          .map((t) => t.description)
          .whereType<String>()
          .where((d) => d.startsWith('[DEMO]'))
          .toSet();

  final now = DateTime.now();
  final demoTransactions = <_DemoTransactionTemplate>[
    _DemoTransactionTemplate(
      amount: '42000',
      daysAgo: 25,
      accountId: bank.id,
      categoryId: salary.id,
      type: TransactionType.INCOME,
      merchant: 'Employer Payroll',
      description: '[DEMO] Monthly Salary',
    ),
    _DemoTransactionTemplate(
      amount: '30000',
      daysAgo: 24,
      accountId: wallet.id,
      categoryId: salary.id,
      type: TransactionType.INCOME,
      merchant: 'Cash Deposit',
      description: '[DEMO] Cash Wallet Funding',
    ),
    _DemoTransactionTemplate(
      amount: '8600',
      daysAgo: 21,
      accountId: wallet.id,
      categoryId: groceries.id,
      type: TransactionType.EXPENSE,
      merchant: 'Shola Market',
      description: '[DEMO] Groceries Week 1',
    ),
    _DemoTransactionTemplate(
      amount: '2200',
      daysAgo: 19,
      accountId: wallet.id,
      categoryId: transport.id,
      type: TransactionType.EXPENSE,
      merchant: 'Ride',
      description: '[DEMO] Commute Week 1',
    ),
    _DemoTransactionTemplate(
      amount: '3500',
      daysAgo: 17,
      accountId: bank.id,
      categoryId: utilities.id,
      type: TransactionType.EXPENSE,
      merchant: 'Ethio Telecom',
      description: '[DEMO] Utilities Bill',
    ),
    _DemoTransactionTemplate(
      amount: '6200',
      daysAgo: 14,
      accountId: wallet.id,
      categoryId: groceries.id,
      type: TransactionType.EXPENSE,
      merchant: 'Fresh Corner',
      description: '[DEMO] Groceries Week 2',
    ),
    _DemoTransactionTemplate(
      amount: '4800',
      daysAgo: 12,
      accountId: bank.id,
      categoryId: freelance.id,
      type: TransactionType.INCOME,
      merchant: 'Client Invoice',
      description: '[DEMO] Freelance Payment',
    ),
    _DemoTransactionTemplate(
      amount: '2800',
      daysAgo: 9,
      accountId: wallet.id,
      categoryId: transport.id,
      type: TransactionType.EXPENSE,
      merchant: 'Fuel Station',
      description: '[DEMO] Transport Week 2',
    ),
    _DemoTransactionTemplate(
      amount: '1900',
      daysAgo: 7,
      accountId: wallet.id,
      categoryId: entertainment.id,
      type: TransactionType.EXPENSE,
      merchant: 'Cinema',
      description: '[DEMO] Weekend Outing',
    ),
    _DemoTransactionTemplate(
      amount: '5100',
      daysAgo: 4,
      accountId: wallet.id,
      categoryId: groceries.id,
      type: TransactionType.EXPENSE,
      merchant: 'Mega Mart',
      description: '[DEMO] Groceries Week 3',
    ),
    _DemoTransactionTemplate(
      amount: '1700',
      daysAgo: 2,
      accountId: wallet.id,
      categoryId: transport.id,
      type: TransactionType.EXPENSE,
      merchant: 'Taxi',
      description: '[DEMO] Recent Commute',
    ),
  ];

  for (final template in demoTransactions) {
    if (existingDemoDescriptions.contains(template.description)) {
      continue;
    }

    await transactionService.createTransaction(
      TransactionCreate(
        amount: template.amount,
        occuredAt: now.subtract(Duration(days: template.daysAgo)),
        accountId: template.accountId,
        categoryId: template.categoryId,
        currency: 'USD',
        merchant: template.merchant,
        type: template.type,
        description: template.description,
      ),
    );
    transactionsCreated += 1;
    existingDemoDescriptions.add(template.description);
  }

  return DemoSeedResult(
    accountsCreated: accountsCreated,
    categoriesCreated: categoriesCreated,
    transactionsCreated: transactionsCreated,
    budgetsCreated: budgetsCreated,
  );
}

class _DemoTransactionTemplate {
  final String amount;
  final int daysAgo;
  final String accountId;
  final String categoryId;
  final TransactionType type;
  final String merchant;
  final String description;

  const _DemoTransactionTemplate({
    required this.amount,
    required this.daysAgo,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.merchant,
    required this.description,
  });
}
