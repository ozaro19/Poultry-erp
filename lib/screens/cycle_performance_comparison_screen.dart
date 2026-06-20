import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CyclePerformanceComparisonScreen extends StatefulWidget {
  const CyclePerformanceComparisonScreen({super.key});

  @override
  State<CyclePerformanceComparisonScreen> createState() =>
      _CyclePerformanceComparisonScreenState();
}

class _CyclePerformanceComparisonScreenState
    extends State<CyclePerformanceComparisonScreen> {
  late Future<Map<String, dynamic>> reportFuture;

  @override
  void initState() {
    super.initState();
    reportFuture = _loadReport();
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

  Future<Map<String, dynamic>> _loadReport() async {
    final cyclesSnapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .get();

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_sales')
        .get();

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_expenses')
        .get();

    final totalSalesByCycle = <String, double>{};
    final totalExpensesByCycle = <String, double>{};

    for (final doc in salesSnapshot.docs) {
      final data = doc.data();

      final cycleId = (data['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      totalSalesByCycle[cycleId] =
          (totalSalesByCycle[cycleId] ?? 0) +
              _toDouble(data['totalAmount']);
    }

    for (final doc in expensesSnapshot.docs) {
      final data = doc.data();

      final cycleId = (data['cycleId'] ?? '').toString();

      if (cycleId.isEmpty) {
        continue;
      }

      totalExpensesByCycle[cycleId] =
          (totalExpensesByCycle[cycleId] ?? 0) +
              _toDouble(data['amount']);
    }

    final rows = cyclesSnapshot.docs.map((doc) {
      final data = doc.data();

      final cycleId = doc.id;
      final cycleCode = (data['code'] ?? '').toString();
      final cycleName = (data['name'] ?? '').toString();
      final status = (data['status'] ?? '').toString();

      final totalSales = totalSalesByCycle[cycleId] ?? 0;
      final totalExpenses = totalExpensesByCycle[cycleId] ?? 0;
      final netResult = totalSales - totalExpenses;

      return {
        'cycleId': cycleId,
        'cycleCode': cycleCode,
        'cycleName': cycleName,
        'status': status,
        'totalSales': totalSales,
        'totalExpenses': totalExpenses,
        'netResult': netResult,
      };
    }).toList();

    rows.sort((a, b) {
      return _toDouble(b['netResult']).compareTo(
        _toDouble(a['netResult']),
      );
    });

    Map<String, dynamic>? bestProfitCycle;
    Map<String, dynamic>? highestSalesCycle;
    Map<String, dynamic>? highestExpensesCycle;

    if (rows.isNotEmpty) {
      bestProfitCycle = rows.first;

      highestSalesCycle = rows.reduce((a, b) {
        return _toDouble(a['totalSales']) >= _toDouble(b['totalSales'])
            ? a
            : b;
      });

      highestExpensesCycle = rows.reduce((a, b) {
        return _toDouble(a['totalExpenses']) >=
                _toDouble(b['totalExpenses'])
            ? a
            : b;
      });
    }

    return {
      'rows': rows,
      'bestProfitCycle': bestProfitCycle,
      'highestSalesCycle': highestSalesCycle,
      'highestExpensesCycle': highestExpensesCycle,
    };
  }

  void _refreshReport() {
    setState(() {
      reportFuture = _loadReport();
    });
  }

  String _cycleTitle(Map<String, dynamic>? cycle) {
    if (cycle == null) {
      return 'لا يوجد';
    }

    final code = (cycle['cycleCode'] ?? '').toString();
    final name = (cycle['cycleName'] ?? '').toString();

    return '$code - $name';
  }

  Widget _buildHighlightCard({
    required String title,
    required Map<String, dynamic>? cycle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 300,
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _cycleTitle(cycle),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
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

  Widget _buildComparisonTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('لا توجد دورات لعرض المقارنة'),
      );
    }

    return Card(
      elevation: 3,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('الدورة')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('المبيعات')),
            DataColumn(label: Text('المصروفات')),
            DataColumn(label: Text('النتيجة')),
          ],
          rows: rows.map((row) {
            final cycleCode = (row['cycleCode'] ?? '').toString();
            final cycleName = (row['cycleName'] ?? '').toString();
            final status = (row['status'] ?? '').toString();

            final totalSales = _toDouble(row['totalSales']);
            final totalExpenses = _toDouble(row['totalExpenses']);
            final netResult = _toDouble(row['netResult']);

            return DataRow(
              cells: [
                DataCell(Text('$cycleCode - $cycleName')),
                DataCell(Text(status)),
                DataCell(Text(_formatNumber(totalSales))),
                DataCell(Text(_formatNumber(totalExpenses))),
                DataCell(
                  Text(
                    _formatNumber(netResult.abs()),
                    style: TextStyle(
                      color: netResult >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReportContent(Map<String, dynamic> data) {
    final rows = (data['rows'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();

    final bestProfitCycle =
        data['bestProfitCycle'] as Map<String, dynamic>?;

    final highestSalesCycle =
        data['highestSalesCycle'] as Map<String, dynamic>?;

    final highestExpensesCycle =
        data['highestExpensesCycle'] as Map<String, dynamic>?;

    final bestProfitValue = bestProfitCycle == null
        ? '0'
        : _formatNumber(_toDouble(bestProfitCycle['netResult']).abs());

    final highestSalesValue = highestSalesCycle == null
        ? '0'
        : _formatNumber(_toDouble(highestSalesCycle['totalSales']));

    final highestExpensesValue = highestExpensesCycle == null
        ? '0'
        : _formatNumber(_toDouble(highestExpensesCycle['totalExpenses']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildHighlightCard(
              title: 'أفضل دورة ربحًا',
              cycle: bestProfitCycle,
              value: bestProfitValue,
              icon: Icons.emoji_events,
              color: Colors.green,
            ),
            _buildHighlightCard(
              title: 'أعلى مبيعات',
              cycle: highestSalesCycle,
              value: highestSalesValue,
              icon: Icons.monetization_on,
              color: Colors.teal,
            ),
            _buildHighlightCard(
              title: 'أعلى مصروفات',
              cycle: highestExpensesCycle,
              value: highestExpensesValue,
              icon: Icons.receipt_long,
              color: Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'جدول مقارنة الدورات',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        _buildComparisonTable(rows),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مقارنة أداء الدورات'),
          actions: [
            IconButton(
              tooltip: 'تحديث التقرير',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshReport,
            ),
          ],
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
                    'مقارنة أداء الدورات',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يقارن بين الدورات من حيث المبيعات والمصروفات وصافي الربح أو الخسارة.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<Map<String, dynamic>>(
                    future: reportFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل مقارنة الدورات',
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return _buildReportContent(snapshot.data!);
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