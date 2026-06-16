import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryBalancesReportScreen extends StatefulWidget {
  const InventoryBalancesReportScreen({super.key});

  @override
  State<InventoryBalancesReportScreen> createState() =>
      _InventoryBalancesReportScreenState();
}

class _InventoryBalancesReportScreenState
    extends State<InventoryBalancesReportScreen> {
  late Future<List<Map<String, dynamic>>> reportFuture;

  @override
  void initState() {
    super.initState();
    reportFuture = _loadBalancesReport();
  }

  Future<List<Map<String, dynamic>>> _loadBalancesReport() async {
    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_items')
        .orderBy('code')
        .get();

    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_transactions')
        .get();

    final Map<String, double> totalAddByItem = {};
    final Map<String, double> totalIssueByItem = {};

    for (final doc in transactionsSnapshot.docs) {
      final data = doc.data();

      final itemCode = (data['itemCode'] ?? '').toString();
      final type = (data['type'] ?? '').toString();

      final quantity = double.tryParse(
            (data['quantity'] ?? 0).toString(),
          ) ??
          0;

      if (itemCode.isEmpty) continue;

      if (type == 'add') {
        totalAddByItem[itemCode] =
            (totalAddByItem[itemCode] ?? 0) + quantity;
      } else if (type == 'issue') {
        totalIssueByItem[itemCode] =
            (totalIssueByItem[itemCode] ?? 0) + quantity;
      }
    }

    return itemsSnapshot.docs.map((doc) {
      final data = doc.data();

      final code = (data['code'] ?? '').toString();
      final name = (data['name'] ?? '').toString();
      final unit = (data['unit'] ?? '').toString();

      final openingQty = double.tryParse(
            (data['openingQty'] ?? 0).toString(),
          ) ??
          0;

      final minimumQty = double.tryParse(
            (data['minimumQty'] ?? 0).toString(),
          ) ??
          0;

      final totalAdd = totalAddByItem[code] ?? 0;
      final totalIssue = totalIssueByItem[code] ?? 0;
      final currentBalance = openingQty + totalAdd - totalIssue;

      final isLowStock = minimumQty > 0 && currentBalance < minimumQty;

      return {
        'code': code,
        'name': name,
        'unit': unit,
        'openingQty': openingQty,
        'minimumQty': minimumQty,
        'totalAdd': totalAdd,
        'totalIssue': totalIssue,
        'currentBalance': currentBalance,
        'isLowStock': isLowStock,
      };
    }).toList();
  }

  String _formatNumber(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  void _refreshReport() {
    setState(() {
      reportFuture = _loadBalancesReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير أرصدة المخزون'),
          actions: [
            IconButton(
              tooltip: 'تحديث التقرير',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshReport,
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: reportFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل تقرير أرصدة المخزون'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final rows = snapshot.data!;

            if (rows.isEmpty) {
              return const Center(
                child: Text('لا توجد أصناف حتى الآن'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];

                final code = row['code'];
                final name = row['name'];
                final unit = row['unit'];
                final openingQty = row['openingQty'];
                final minimumQty = row['minimumQty'];
                final totalAdd = row['totalAdd'];
                final totalIssue = row['totalIssue'];
                final currentBalance = row['currentBalance'];
                final isLowStock = row['isLowStock'] == true;

                return Card(
                  color: isLowStock ? Colors.red.shade50 : null,
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: ListTile(
                    leading: Icon(
                      isLowStock
                          ? Icons.warning_amber
                          : Icons.inventory,
                      color: isLowStock ? Colors.red : Colors.green,
                    ),
                    title: Text(
                      '$code - $name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'الرصيد الافتتاحي: ${_formatNumber(openingQty)} $unit\n'
                      'الحد الأدنى: ${_formatNumber(minimumQty)} $unit\n'
                      'إجمالي الإضافات: ${_formatNumber(totalAdd)} $unit\n'
                      'إجمالي الصرف: ${_formatNumber(totalIssue)} $unit\n'
                      'الرصيد الحالي: ${_formatNumber(currentBalance)} $unit\n'
                      'الحالة: ${isLowStock ? 'منخفض' : 'جيد'}',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}