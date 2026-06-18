import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CycleIndicatorsScreen extends StatefulWidget {
  const CycleIndicatorsScreen({super.key});

  @override
  State<CycleIndicatorsScreen> createState() =>
      _CycleIndicatorsScreenState();
}

class _CycleIndicatorsScreenState extends State<CycleIndicatorsScreen> {
  String _selectedCycleId = 'all';
  DateTime? _fromDate;
  DateTime? _toDate;

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
  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'غير محدد';
    }

    return '${date.year}-${date.month}-${date.day}';
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool _recordMatchesDateRange(Map<String, dynamic> record) {
    final dateValue = record['date'];

    if (dateValue is! Timestamp) {
      return true;
    }

    final recordDate = _dateOnly(dateValue.toDate());

    if (_fromDate != null) {
      final fromDate = _dateOnly(_fromDate!);

      if (recordDate.isBefore(fromDate)) {
        return false;
      }
    }

    if (_toDate != null) {
      final toDate = _dateOnly(_toDate!);

      if (recordDate.isAfter(toDate)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _pickDate({
    required bool isFromDate,
  }) async {
    final initialDate = isFromDate
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? DateTime.now());

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (isFromDate) {
        _fromDate = pickedDate;
      } else {
        _toDate = pickedDate;
      }
    });
  }
  String _selectedCycleLabel(
    List<Map<String, dynamic>> cyclesForFilter,
  ) {
    if (_selectedCycleId == 'all') {
      return 'كل الدورات';
    }

    final selectedCycles = cyclesForFilter.where((cycle) {
      return cycle['id'].toString() == _selectedCycleId;
    }).toList();

    if (selectedCycles.isEmpty) {
      return 'دورة محددة';
    }

    final cycle = selectedCycles.first;

    return '${cycle['code']} - ${cycle['name']}';
  }

  String _dateRangeLabel() {
    return 'من: ${_formatDate(_fromDate)}  -  إلى: ${_formatDate(_toDate)}';
  }
  pw.Widget _buildPdfCell(
    String text, {
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  Future<void> _printIndicatorsPdf() async {
    final data = await _loadIndicators();

    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final cycleResults =
        data['cycleResults'] as List<Map<String, dynamic>>;

    final cyclesForFilter =
        data['cyclesForFilter'] as List<Map<String, dynamic>>;

    final netResult = data['netResult'] as num;
    final lowStockCount = data['lowStockCount'] as int;

    final selectedCycle = _selectedCycleLabel(cyclesForFilter);
    final dateRange = _dateRangeLabel();

    final metrics = <Map<String, String>>[
      {
        'title': 'إجمالي الدورات',
        'value': data['totalCycles'].toString(),
      },
      {
        'title': 'الدورات النشطة',
        'value': data['activeCycles'].toString(),
      },
      {
        'title': 'الدورات المغلقة',
        'value': data['closedCycles'].toString(),
      },
      {
        'title': 'إجمالي المبيعات',
        'value': _formatNumber(data['totalSales'] as num),
      },
      {
        'title': 'إجمالي المصروفات',
        'value': _formatNumber(data['totalExpenses'] as num),
      },
      {
        'title': 'إجمالي الأرباح',
        'value': _formatNumber(data['totalProfit'] as num),
      },
      {
        'title': 'إجمالي الخسائر',
        'value': _formatNumber(data['totalLoss'] as num),
      },
      {
        'title': 'صافي النتيجة',
        'value': _formatNumber(netResult),
      },
      {
        'title': 'أصناف مخزون منخفضة',
        'value': lowStockCount.toString(),
      },
    ];
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'لوحة مؤشرات دورات التسمين',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'نطاق الدورة: $selectedCycle',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'نطاق التاريخ: $dateRange',
                    style: const pw.TextStyle(
                      fontSize: 11,
                    ),
                  ),
                  pw.Text(
                    'تاريخ الطباعة: ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'المؤشرات العامة',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                    ),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1),
                      1: pw.FlexColumnWidth(2),
                    },
                    children: metrics.map((metric) {
                      return pw.TableRow(
                        children: [
                          _buildPdfCell(
                            metric['value']!,
                          ),
                          _buildPdfCell(
                            metric['title']!,
                            isHeader: true,
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Text(
                    'نتائج الدورات',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  if (cycleResults.isEmpty)
                    pw.Text(
                      'لا توجد دورات في نطاق العرض المحدد',
                      style: const pw.TextStyle(
                        fontSize: 11,
                      ),
                    )
                  else
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColors.grey400,
                      ),
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.grey300,
                          ),
                          children: [
                            _buildPdfCell(
                              'الصافي',
                              isHeader: true,
                            ),
                            _buildPdfCell(
                              'المصروفات',
                              isHeader: true,
                            ),
                            _buildPdfCell(
                              'المبيعات',
                              isHeader: true,
                            ),
                            _buildPdfCell(
                              'الحالة',
                              isHeader: true,
                            ),
                            _buildPdfCell(
                              'الدورة',
                              isHeader: true,
                            ),
                          ],
                        ),
                        ...cycleResults.map((cycle) {
                          final cycleNetResult =
                              _toDouble(cycle['netResult']);

                          return pw.TableRow(
                            children: [
                              _buildPdfCell(
                                _formatNumber(cycleNetResult),
                              ),
                              _buildPdfCell(
                                _formatNumber(cycle['expenses'] as num),
                              ),
                              _buildPdfCell(
                                _formatNumber(cycle['sales'] as num),
                              ),
                              _buildPdfCell(
                                cycle['status'].toString(),
                              ),
                              _buildPdfCell(
                                '${cycle['code']} - ${cycle['name']}',
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
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

      return filteredCycleIds.contains(cycleId) &&
          _recordMatchesDateRange(record);
    }).toList();

    final filteredExpenses = expenses.where((record) {
      final cycleId = (record['cycleId'] ?? '').toString();

      return filteredCycleIds.contains(cycleId) &&
          _recordMatchesDateRange(record);
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
          actions: [
            IconButton(
              tooltip: 'طباعة PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () {
                _printIndicatorsPdf();
              },
            ),
          ],
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
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _pickDate(isFromDate: true);
                                },
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  'من: ${_formatDate(_fromDate)}',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  _pickDate(isFromDate: false);
                                },
                                icon: const Icon(Icons.event),
                                label: Text(
                                  'إلى: ${_formatDate(_toDate)}',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _fromDate = null;
                                    _toDate = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('مسح التاريخ'),
                              ),
                            ],
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