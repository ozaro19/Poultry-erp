import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'journal_entries_screen.dart';

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
    'الخزينة',
    Icons.account_balance_wallet,
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
    'رأس المال',
    Icons.savings,
    () {},
  ),
  _MenuCard(
    'المخازن',
    Icons.inventory,
    () {},
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
    this.onTap, {
    super.key,
  });

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