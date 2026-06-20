import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cycle_performance_comparison_screen.dart';
import 'cycle_summary_report_screen.dart';
import 'fattening_cycles_screen.dart';
import 'inventory_balances_report_screen.dart';

class AlertsCenterScreen extends StatefulWidget {
  const AlertsCenterScreen({super.key});

  @override
  State<AlertsCenterScreen> createState() => _AlertsCenterScreenState();
}

class _AlertsCenterScreenState extends State<AlertsCenterScreen> {
  late Future<List<Map<String, dynamic>>> alertsFuture;

  @override
  void initState() {
    super.initState();
    alertsFuture = _loadAlerts();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

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

  int _severityRank(String severity) {
    if (severity == 'high') return 1;
    if (severity == 'medium') return 2;
    if (severity == 'info') return 3;

    return 4;
  }

  String _severityText(String severity) {
    if (severity == 'high') return 'مهم';
    if (severity == 'medium') return 'متوسط';
    if (severity == 'info') return 'معلومة';

    return 'جيد';
  }

  Color _severityColor(String severity) {
    if (severity == 'high') return Colors.red;
    if (severity == 'medium') return Colors.deepOrange;
    if (severity == 'info') return Colors.blue;

    return Colors.green;
  }

  Future<List<Map<String, dynamic>>> _loadAlerts() async {
    final alerts = <Map<String, dynamic>>[];

    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_items')
        .get();

    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_transactions')
        .get();

    final cyclesSnapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .get();

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_sales')
        .get();

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_expenses')
        .get();

    final followupsSnapshot = await FirebaseFirestore.instance
        .collection('cycle_daily_followups')
        .get();

    final totalAddByItem = <String, double>{};
    final totalIssueByItem = <String, double>{};

    for (final doc in transactionsSnapshot.docs) {
      final data = doc.data();

      final itemCode = (data['itemCode'] ?? '').toString();
      final type = (data['type'] ?? '').toString();
      final quantity = _toDouble(data['quantity']);

      if (itemCode.isEmpty) {
        continue;
      }

      if (type == 'add') {
        totalAddByItem[itemCode] =
            (totalAddByItem[itemCode] ?? 0) + quantity;
      } else if (type == 'issue') {
        totalIssueByItem[itemCode] =
            (totalIssueByItem[itemCode] ?? 0) + quantity;
      }
    }

    for (final doc in itemsSnapshot.docs) {
      final data = doc.data();

      final code = (data['code'] ?? '').toString();
      final name = (data['name'] ?? '').toString();
      final unit = (data['unit'] ?? '').toString();

      final openingQty = _toDouble(data['openingQty']);
      final minimumQty = _toDouble(data['minimumQty']);

      if (code.isEmpty || minimumQty <= 0) {
        continue;
      }

      final totalAdd = totalAddByItem[code] ?? 0;
      final totalIssue = totalIssueByItem[code] ?? 0;
      final currentBalance = openingQty + totalAdd - totalIssue;

      if (currentBalance < minimumQty) {
        alerts.add({
          'severity': 'high',
          'title': 'مخزون منخفض',
          'message':
              'الصنف $code - $name رصيده الحالي ${_formatNumber(currentBalance)} $unit أقل من الحد الأدنى ${_formatNumber(minimumQty)} $unit.',
          'icon': Icons.inventory,
        });
      }
    }

    final cycleInfoById = <String, Map<String, dynamic>>{};
    int activeCyclesCount = 0;

    for (final doc in cyclesSnapshot.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString();

      if (status == 'نشطة') {
        activeCyclesCount++;
      }

      cycleInfoById[doc.id] = {
        'code': (data['code'] ?? '').toString(),
        'name': (data['name'] ?? '').toString(),
        'status': status,
        'chicksCount': _toInt(data['chicksCount']),
      };
    }

    if (activeCyclesCount == 0) {
      alerts.add({
        'severity': 'info',
        'title': 'لا توجد دورات نشطة',
        'message':
            'لا توجد دورة تسمين نشطة حاليًا. يمكنك فتح دورة جديدة من شاشة دورات التسمين.',
        'icon': Icons.info,
      });
    }

    final salesByCycle = <String, double>{};
    final expensesByCycle = <String, double>{};

    for (final doc in salesSnapshot.docs) {
      final data = doc.data();

      final cycleId = (data['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      salesByCycle[cycleId] =
          (salesByCycle[cycleId] ?? 0) + _toDouble(data['totalAmount']);
    }

    for (final doc in expensesSnapshot.docs) {
      final data = doc.data();

      final cycleId = (data['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      expensesByCycle[cycleId] =
          (expensesByCycle[cycleId] ?? 0) + _toDouble(data['amount']);
    }

    for (final cycleId in cycleInfoById.keys) {
      final cycle = cycleInfoById[cycleId];

      if (cycle == null) {
        continue;
      }

      final totalSales = salesByCycle[cycleId] ?? 0;
      final totalExpenses = expensesByCycle[cycleId] ?? 0;
      final netResult = totalSales - totalExpenses;

      if (totalSales > 0 && netResult < 0) {
        alerts.add({
          'severity': 'medium',
          'title': 'دورة خاسرة',
          'message':
              'الدورة ${cycle['code']} - ${cycle['name']} تحقق خسارة قدرها ${_formatNumber(netResult.abs())}.',
          'icon': Icons.trending_down,
        });
      }
    }

    final mortalityByCycle = <String, int>{};

    for (final doc in followupsSnapshot.docs) {
      final data = doc.data();

      final cycleId = (data['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      mortalityByCycle[cycleId] =
          (mortalityByCycle[cycleId] ?? 0) + _toInt(data['mortality']);
    }

    for (final cycleId in mortalityByCycle.keys) {
      final cycle = cycleInfoById[cycleId];

      if (cycle == null) {
        continue;
      }

      final initialChicks = _toInt(cycle['chicksCount']);

      if (initialChicks <= 0) {
        continue;
      }

      final totalMortality = mortalityByCycle[cycleId] ?? 0;
      final mortalityRate = (totalMortality / initialChicks) * 100;

      if (mortalityRate >= 5) {
        alerts.add({
          'severity': 'high',
          'title': 'نسبة نفوق مرتفعة',
          'message':
              'الدورة ${cycle['code']} - ${cycle['name']} وصلت نسبة النفوق فيها إلى ${_formatNumber(mortalityRate)}%.',
          'icon': Icons.warning,
        });
      }
    }

    alerts.sort((a, b) {
      final severityA = (a['severity'] ?? '').toString();
      final severityB = (b['severity'] ?? '').toString();

      return _severityRank(severityA).compareTo(
        _severityRank(severityB),
      );
    });

    return alerts;
  }

  void _refreshAlerts() {
    setState(() {
      alertsFuture = _loadAlerts();
    });
  }

    void _openAlertScreen(Map<String, dynamic> alert) {
    final title = (alert['title'] ?? '').toString();

    Widget? screen;

    if (title == 'مخزون منخفض') {
      screen = const InventoryBalancesReportScreen();
    } else if (title == 'دورة خاسرة') {
      screen = const CyclePerformanceComparisonScreen();
    } else if (title == 'نسبة نفوق مرتفعة') {
      screen = const CycleSummaryReportScreen();
    } else if (title == 'لا توجد دورات نشطة') {
      screen = const FatteningCyclesScreen();
    }

    if (screen == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen!,
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final severity = (alert['severity'] ?? '').toString();
    final color = _severityColor(severity);
    final icon = alert['icon'] as IconData? ?? Icons.notifications;

    return Card(
      elevation: 3,
      child: ListTile(
        onTap: () => _openAlertScreen(alert),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                (alert['title'] ?? '').toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _severityText(severity),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'فتح الشاشة المرتبطة',
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _openAlertScreen(alert),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            (alert['message'] ?? '').toString(),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsSummary(List<Map<String, dynamic>> alerts) {
    final highCount = alerts.where((alert) {
      return (alert['severity'] ?? '').toString() == 'high';
    }).length;

    final mediumCount = alerts.where((alert) {
      return (alert['severity'] ?? '').toString() == 'medium';
    }).length;

    final infoCount = alerts.where((alert) {
      return (alert['severity'] ?? '').toString() == 'info';
    }).length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          title: 'تنبيهات مهمة',
          value: highCount.toString(),
          icon: Icons.priority_high,
          color: Colors.red,
        ),
        _buildSummaryCard(
          title: 'تنبيهات متوسطة',
          value: mediumCount.toString(),
          icon: Icons.warning_amber,
          color: Colors.deepOrange,
        ),
        _buildSummaryCard(
          title: 'معلومات',
          value: infoCount.toString(),
          icon: Icons.info,
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 250,
      child: Card(
        elevation: 3,
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
    );
  }

  Widget _buildNoAlertsMessage() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 70,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد تنبيهات حاليًا',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'كل المؤشرات الحالية تبدو جيدة.',
              style: TextStyle(
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsContent(List<Map<String, dynamic>> alerts) {
    if (alerts.isEmpty) {
      return _buildNoAlertsMessage();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAlertsSummary(alerts),
        const SizedBox(height: 24),
        const Text(
          'قائمة التنبيهات',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...alerts.map(_buildAlertCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مركز التنبيهات الذكية'),
          actions: [
            IconButton(
              tooltip: 'تحديث التنبيهات',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshAlerts,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مركز التنبيهات الذكية',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يعرض أهم التنبيهات التشغيلية والمالية من بيانات النظام.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: alertsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل التنبيهات',
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return _buildAlertsContent(snapshot.data!);
                    },
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