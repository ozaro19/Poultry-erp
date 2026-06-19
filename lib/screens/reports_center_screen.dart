import 'package:flutter/material.dart';

import 'cycle_indicators_screen.dart';
import 'cycle_summary_report_screen.dart';
import 'inventory_balances_report_screen.dart';

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
                    'اختر التقرير المطلوب لعرض البيانات أو طباعة PDF.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
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
                      _buildReportCard(
                        context: context,
                        title: 'تقرير أرصدة المخزون',
                        subtitle: 'الأرصدة الحالية والأصناف منخفضة الرصيد',
                        icon: Icons.inventory,
                        color: Colors.orange,
                        screen: const InventoryBalancesReportScreen(),
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