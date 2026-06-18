import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CycleIndicatorsScreen extends StatefulWidget {
  const CycleIndicatorsScreen({super.key});

  @override
  State<CycleIndicatorsScreen> createState() =>
      _CycleIndicatorsScreenState();
}

class _CycleIndicatorsScreenState extends State<CycleIndicatorsScreen> {
  String _selectedCycleId = 'all';

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
    Future<Map<String, dynamic>> _loadIndicators() async {
    final cyclesSnapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .get();

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_expenses')
        .get();

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_sales')
        .get();

    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_items')
        .get();

    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_transactions')
        .get();

    final cycles = cyclesSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    final expenses = expensesSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final sales = salesSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final items = itemsSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final transactions = transactionsSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final cyclesForFilter = cycles.map((cycle) {
      return {
        'id': cycle['id'].toString(),
        'code': (cycle['code'] ?? '').toString(),
        'name': (cycle['name'] ?? '').toString(),
      };
    }).toList();

    final filteredCycles = _selectedCycleId == 'all'
        ? cycles
        : cycles.where((cycle) {
            return cycle['id'].toString() == _selectedCycleId;
          }).toList();

    final filteredCycleIds = filteredCycles.map((cycle) {
      return cycle['id'].toString();
    }).toSet();

    final filteredSales = sales.where((record) {
      final cycleId = (record['cycleId'] ?? '').toString();

      return filteredCycleIds.contains(cycleId);
    }).toList();

    final filteredExpenses = expenses.where((record) {
      final cycleId = (record['cycleId'] ?? '').toString();

      return filteredCycleIds.contains(cycleId);
    }).toList();

    final activeCycles = filteredCycles.where((cycle) {
      return (cycle['status'] ?? '').toString() == 'نشطة';
    }).length;

    final closedCycles = filteredCycles.where((cycle) {
      return (cycle['status'] ?? '').toString() == 'مغلقة';
    }).length;

    final totalSales = filteredSales.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalAmount']),
    );

    final totalExpenses = filteredExpenses.fold<double>(
      0,
      (total, record) => total + _toDouble(record['amount']),
    );

    double totalProfit = 0;
    double totalLoss = 0;

    final cycleResults = <Map<String, dynamic>>[];

    for (final cycle in filteredCycles) {
      final cycleId = cycle['id'].toString();

      final cycleSales = filteredSales.where((record) {
        return (record['cycleId'] ?? '').toString() == cycleId;
      }).fold<double>(
        0,
        (total, record) => total + _toDouble(record['totalAmount']),
      );

      final cycleExpenses = filteredExpenses.where((record) {
        return (record['cycleId'] ?? '').toString() == cycleId;
      }).fold<double>(
        0,
        (total, record) => total + _toDouble(record['amount']),
      );

      final netResult = cycleSales - cycleExpenses;

      if (netResult >= 0) {
        totalProfit += netResult;
      } else {
        totalLoss += netResult.abs();
      }

      cycleResults.add({
        'code': (cycle['code'] ?? '').toString(),
        'name': (cycle['name'] ?? '').toString(),
        'status': (cycle['status'] ?? '').toString(),
        'sales': cycleSales,
        'expenses': cycleExpenses,
        'netResult': netResult,
      });
    }

    cycleResults.sort(
      (a, b) => a['code'].toString().compareTo(
            b['code'].toString(),
          ),
    );
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

    final netResult = totalSales - totalExpenses;

    return {
      'totalCycles': filteredCycles.length,
      'activeCycles': activeCycles,
      'closedCycles': closedCycles,
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'totalProfit': totalProfit,
      'totalLoss': totalLoss,
      'netResult': netResult,
      'lowStockCount': lowStockCount,
      'cycleResults': cycleResults,
      'cyclesForFilter': cyclesForFilter,
    };
  }

  Widget _buildIndicatorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة مؤشرات دورات التسمين'),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _loadIndicators(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل لوحة المؤشرات'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final data = snapshot.data!;

            final cycleResults =
                data['cycleResults'] as List<Map<String, dynamic>>;

            final cyclesForFilter =
                data['cyclesForFilter'] as List<Map<String, dynamic>>;

            final netResult = data['netResult'] as num;
            final lowStockCount = data['lowStockCount'] as int;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'فلتر المؤشرات',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCycleId,
                            decoration: const InputDecoration(
                              labelText: 'اختر نطاق العرض',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('كل الدورات'),
                              ),
                              ...cyclesForFilter.map((cycle) {
                                return DropdownMenuItem<String>(
                                  value: cycle['id'].toString(),
                                  child: Text(
                                    '${cycle['code']} - ${cycle['name']}',
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                _selectedCycleId = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _selectedCycleId == 'all'
                        ? 'المؤشرات العامة لكل الدورات'
                        : 'مؤشرات الدورة المحددة',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildIndicatorCard(
                        title: 'إجمالي الدورات',
                        value: data['totalCycles'].toString(),
                        icon: Icons.layers,
                        color: Colors.blueGrey,
                      ),
                      _buildIndicatorCard(
                        title: 'الدورات النشطة',
                        value: data['activeCycles'].toString(),
                        icon: Icons.play_circle,
                        color: Colors.green,
                      ),
                      _buildIndicatorCard(
                        title: 'الدورات المغلقة',
                        value: data['closedCycles'].toString(),
                        icon: Icons.lock,
                        color: Colors.grey,
                      ),
                      _buildIndicatorCard(
                        title: 'إجمالي المبيعات',
                        value: _formatNumber(data['totalSales'] as num),
                        icon: Icons.monetization_on,
                        color: Colors.green,
                      ),
                      _buildIndicatorCard(
                        title: 'إجمالي المصروفات',
                        value: _formatNumber(data['totalExpenses'] as num),
                        icon: Icons.receipt_long,
                        color: Colors.deepOrange,
                      ),
                      _buildIndicatorCard(
                        title: 'إجمالي الأرباح',
                        value: _formatNumber(data['totalProfit'] as num),
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                      _buildIndicatorCard(
                        title: 'إجمالي الخسائر',
                        value: _formatNumber(data['totalLoss'] as num),
                        icon: Icons.trending_down,
                        color: Colors.red,
                      ),
                      _buildIndicatorCard(
                        title: 'صافي النتيجة',
                        value: _formatNumber(netResult),
                        icon: netResult >= 0
                            ? Icons.emoji_events
                            : Icons.warning,
                        color: netResult >= 0
                            ? Colors.green
                            : Colors.red,
                      ),
                      _buildIndicatorCard(
                        title: 'أصناف مخزون منخفضة',
                        value: lowStockCount.toString(),
                        icon: Icons.inventory,
                        color: lowStockCount > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'نتائج الدورات',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (cycleResults.isEmpty)
                    const Text('لا توجد دورات في نطاق العرض المحدد')
                  else
                    ...cycleResults.map((cycle) {
                      final cycleNetResult = cycle['netResult'] as double;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            cycleNetResult >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: cycleNetResult >= 0
                                ? Colors.green
                                : Colors.red,
                          ),
                          title: Text(
                            '${cycle['code']} - ${cycle['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'الحالة: ${cycle['status']}\n'
                            'المبيعات: ${_formatNumber(cycle['sales'] as num)}\n'
                            'المصروفات: ${_formatNumber(cycle['expenses'] as num)}\n'
                            'الصافي: ${_formatNumber(cycleNetResult)}',
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}