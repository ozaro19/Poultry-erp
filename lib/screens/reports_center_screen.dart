import 'package:flutter/material.dart';

import 'account_ledger_screen.dart';
import 'cycle_indicators_screen.dart';
import 'cycle_summary_report_screen.dart';
import 'inventory_balances_report_screen.dart';
import 'item_card_report_screen.dart';
import 'trial_balance_screen.dart';
import 'profit_loss_report_screen.dart';

class ReportsCenterScreen extends StatelessWidget {
  const ReportsCenterScreen({super.key});

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return SizedBox(
      width: 320,
      child: Card(
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => screen,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withAlpha(30),
                  child: Icon(
                    icon,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withAlpha(30),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildReportSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> reports,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          title: title,
          icon: icon,
          color: color,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: reports,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز التقارير'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'التقارير والتحليلات',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كل تقارير النظام في مكان واحد بشكل منظم وسهل الوصول.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildReportSection(
                    title: 'تقارير التسمين',
                    icon: Icons.agriculture,
                    color: Colors.green,
                    reports: [
                      _buildReportCard(
                        context: context,
                        title: 'لوحة مؤشرات التسمين',
                        subtitle: 'تحليل الأداء والربحية والتنبيهات الذكية',
                        icon: Icons.analytics,
                        color: Colors.indigo,
                        screen: const CycleIndicatorsScreen(),
                      ),
                      _buildReportCard(
                        context: context,
                        title: 'تقرير ملخص الدورة',
                        subtitle: 'ملخص كامل للدورة والمصروفات والمبيعات',
                        icon: Icons.summarize,
                        color: Colors.green,
                        screen: const CycleSummaryReportScreen(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildReportSection(
                    title: 'تقارير المخزون',
                    icon: Icons.inventory,
                    color: Colors.orange,
                    reports: [
                      _buildReportCard(
                        context: context,
                        title: 'تقرير أرصدة المخزون',
                        subtitle: 'الأرصدة الحالية والأصناف منخفضة الرصيد',
                        icon: Icons.inventory,
                        color: Colors.orange,
                        screen: const InventoryBalancesReportScreen(),
                      ),
                      _buildReportCard(
                        context: context,
                        title: 'كارت الصنف',
                        subtitle: 'عرض حركة صنف محدد من إضافات وصرف ورصيد',
                        icon: Icons.assignment,
                        color: Colors.deepPurple,
                        screen: const ItemCardReportScreen(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _buildReportSection(
                    title: 'تقارير المحاسبة',
                    icon: Icons.account_balance,
                    color: Colors.blueGrey,
                    reports: [
                      _buildReportCard(
                        context: context,
                        title: 'أرباح وخسائر عام',
                        subtitle: 'إجمالي المبيعات والمصروفات وصافي الربح',
                        icon: Icons.stacked_line_chart,
                        color: Colors.red,
                        screen: const ProfitLossReportScreen(),
                      ),
                      _buildReportCard(
                        context: context,
                        title: 'ميزان المراجعة',
                        subtitle: 'عرض أرصدة الحسابات مدينة ودائنة',
                        icon: Icons.balance,
                        color: Colors.blueGrey,
                        screen: const TrialBalanceScreen(),
                      ),
                      _buildReportCard(
                        context: context,
                        title: 'كشف حساب',
                        subtitle: 'متابعة حركة حساب معين بالتفصيل',
                        icon: Icons.list_alt,
                        color: Colors.teal,
                        screen: const AccountLedgerScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}