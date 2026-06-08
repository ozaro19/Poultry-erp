import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'journal_entries_screen.dart';
import 'account_ledger_screen.dart';
import 'trial_balance_screen.dart';
import 'cash_screen.dart';
import 'inventory_items_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام إدارة مزارع الدواجن'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
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
              Icons.savings,
              () {},
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
              'دورات التسمين',
              Icons.agriculture,
              () {},
            ),
            _MenuCard(
              'الأصول',
              Icons.business,
              () {},
            ),
            _MenuCard(
              'التقارير',
              Icons.bar_chart,
              () {},
            ),
          ],
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
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}