import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'accounts_screen.dart';
import 'journal_entries_screen.dart';
import 'account_ledger_screen.dart';
import 'trial_balance_screen.dart';
import 'cash_screen.dart';
import 'inventory_items_screen.dart';
import 'inventory_transactions_screen.dart';
import 'fattening_cycles_screen.dart';
import 'cycle_indicators_screen.dart';
import 'system_settings_screen.dart';
import 'reports_center_screen.dart';
import 'alerts_center_screen.dart';
import 'assets_screen.dart';
import 'capital_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'users_management_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;

    return 0;
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Future<Map<String, dynamic>> _loadDashboardData() async {
    final cyclesSnapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .get();

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_sales')
        .get();

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_expenses')
        .get();

    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_items')
        .get();

    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_transactions')
        .get();

    final followupsSnapshot = await FirebaseFirestore.instance
        .collection('cycle_daily_followups')
        .get();

    final cycles = cyclesSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    final sales = salesSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final expenses = expensesSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final items = itemsSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final transactions = transactionsSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final followups = followupsSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final activeCycles = cycles.where((cycle) {
      return (cycle['status'] ?? '').toString() == 'نشطة';
    }).length;

    final closedCycles = cycles.where((cycle) {
      return (cycle['status'] ?? '').toString() == 'مغلقة';
    }).length;

    final totalSales = sales.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalAmount']),
    );

    final totalExpenses = expenses.fold<double>(
      0,
      (total, record) => total + _toDouble(record['amount']),
    );

    final netResult = totalSales - totalExpenses;

    final transactionTotals = <String, Map<String, double>>{};

    for (final transaction in transactions) {
      final itemCode = (transaction['itemCode'] ?? '').toString();

      if (itemCode.isEmpty) {
        continue;
      }

      final type = (transaction['type'] ?? '').toString();
      final quantity = _toDouble(transaction['quantity']);

      transactionTotals.putIfAbsent(
        itemCode,
        () => {
          'add': 0,
          'issue': 0,
        },
      );

      if (type == 'add') {
        transactionTotals[itemCode]!['add'] =
            transactionTotals[itemCode]!['add']! + quantity;
      } else if (type == 'issue') {
        transactionTotals[itemCode]!['issue'] =
            transactionTotals[itemCode]!['issue']! + quantity;
      }
    }

    int lowStockCount = 0;

    for (final item in items) {
      final itemCode = (item['code'] ?? '').toString();

      final openingQty = _toDouble(item['openingQty']);
      final minimumQty = _toDouble(item['minimumQty']);

      if (minimumQty <= 0) {
        continue;
      }

      final totals = transactionTotals[itemCode];

      final totalAdd = totals == null ? 0.0 : totals['add'] ?? 0.0;
      final totalIssue = totals == null ? 0.0 : totals['issue'] ?? 0.0;

      final currentBalance = openingQty + totalAdd - totalIssue;

      if (currentBalance < minimumQty) {
        lowStockCount++;
      }
    }

    int alertsCount = lowStockCount;

    if (activeCycles == 0) {
      alertsCount++;
    }

    final salesByCycle = <String, double>{};
    final expensesByCycle = <String, double>{};

    for (final sale in sales) {
      final cycleId = (sale['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      salesByCycle[cycleId] =
          (salesByCycle[cycleId] ?? 0) + _toDouble(sale['totalAmount']);
    }

    for (final expense in expenses) {
      final cycleId = (expense['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      expensesByCycle[cycleId] =
          (expensesByCycle[cycleId] ?? 0) + _toDouble(expense['amount']);
    }

    for (final cycle in cycles) {
      final cycleId = (cycle['id'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      final cycleSales = salesByCycle[cycleId] ?? 0;
      final cycleExpenses = expensesByCycle[cycleId] ?? 0;
      final cycleNetResult = cycleSales - cycleExpenses;

      if (cycleSales > 0 && cycleNetResult < 0) {
        alertsCount++;
      }
    }

    final mortalityByCycle = <String, int>{};

    for (final followup in followups) {
      final cycleId = (followup['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      mortalityByCycle[cycleId] =
          (mortalityByCycle[cycleId] ?? 0) +
              _toDouble(followup['mortality']).toInt();
    }

    for (final cycle in cycles) {
      final cycleId = (cycle['id'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      final initialChicks = _toDouble(cycle['chicksCount']).toInt();

      if (initialChicks <= 0) {
        continue;
      }

      final totalMortality = mortalityByCycle[cycleId] ?? 0;
      final mortalityRate = (totalMortality / initialChicks) * 100;

      if (mortalityRate >= 5) {
        alertsCount++;
      }
    }

    String currentRole = 'viewer';

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      final userDocument = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final userData = userDocument.data();

      currentRole = (userData?['role'] ?? 'viewer').toString();
    }

    return {
      'activeCycles': activeCycles,
      'closedCycles': closedCycles,
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'netResult': netResult,
      'lowStockCount': lowStockCount,
      'alertsCount': alertsCount,
      'currentRole': currentRole,
    };
  }
    @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final menuColumns = screenWidth > 1000
        ? 4
        : screenWidth > 650
            ? 3
            : 2;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام إدارة مزارع الدواجن'),
          actions: [
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _loadDashboardData(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل لوحة التحكم'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final data = snapshot.data!;

            final activeCycles = data['activeCycles'] ?? 0;
            final totalSales = _toDouble(data['totalSales']);
            final totalExpenses = _toDouble(data['totalExpenses']);
            final netResult = _toDouble(data['netResult']);
            final lowStockCount = data['lowStockCount'] ?? 0;
            final alertsCount = data['alertsCount'] ?? 0;
            final currentRole =
                (data['currentRole'] ?? 'viewer').toString();

            final isAdmin = currentRole == 'admin';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ملخص سريع',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _DashboardStatCard(
                        title: 'الدورات النشطة',
                        value: activeCycles.toString(),
                        icon: Icons.play_circle,
                        color: Colors.green,
                      ),
                      _DashboardStatCard(
                        title: 'إجمالي المبيعات',
                        value: _formatNumber(totalSales),
                        icon: Icons.monetization_on,
                        color: Colors.green,
                      ),
                      _DashboardStatCard(
                        title: 'إجمالي المصروفات',
                        value: _formatNumber(totalExpenses),
                        icon: Icons.receipt_long,
                        color: Colors.deepOrange,
                      ),
                      _DashboardStatCard(
                        title: netResult >= 0
                            ? 'صافي ربح'
                            : 'صافي خسارة',
                        value: _formatNumber(netResult.abs()),
                        icon: netResult >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: netResult >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      _DashboardStatCard(
                        title: 'مخزون منخفض',
                        value: lowStockCount.toString(),
                        icon: Icons.inventory,
                        color: lowStockCount > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                      _DashboardStatCard(
                        title: 'تنبيهات',
                        value: alertsCount.toString(),
                        icon: Icons.notifications_active,
                        color: alertsCount > 0
                            ? Colors.red
                            : Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AlertsCenterScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'اختصارات النظام',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                                    GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: menuColumns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.25,
                    children: [
                      _MenuCard(
                        'شجرة الحسابات',
                        Icons.account_tree,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'الخزينة',
                        Icons.account_balance_wallet,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CashScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'القيود اليومية',
                        Icons.receipt_long,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const JournalEntriesScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'كشف حساب',
                        Icons.list_alt,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountLedgerScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'ميزان المراجعة',
                        Icons.balance,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrialBalanceScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'رأس المال',
                        Icons.account_balance,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CapitalScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'المخازن',
                        Icons.inventory,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InventoryItemsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'حركات المخزون',
                        Icons.swap_horiz,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const InventoryTransactionsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'دورات التسمين',
                        Icons.agriculture,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FatteningCyclesScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'لوحة مؤشرات التسمين',
                        Icons.insights,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CycleIndicatorsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'الأصول',
                        Icons.business,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AssetsScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'إعدادات النظام',
                        Icons.settings,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SystemSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    if (isAdmin)
                      _MenuCard(
                        'المستخدمون والصلاحيات',
                        Icons.manage_accounts,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const UsersManagementScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'التقارير',
                        Icons.bar_chart,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReportsCenterScreen(),
                            ),
                          );
                        },
                      ),
                      _MenuCard(
                        'التنبيهات الذكية',
                        Icons.notifications_active,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AlertsCenterScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withAlpha(30),
                  child: Icon(
                    icon,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard(
    this.title,
    this.icon,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 44,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
