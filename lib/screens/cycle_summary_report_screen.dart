import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CycleSummaryReportScreen extends StatefulWidget {
  const CycleSummaryReportScreen({super.key});

  @override
  State<CycleSummaryReportScreen> createState() =>
      _CycleSummaryReportScreenState();
}

class _CycleSummaryReportScreenState extends State<CycleSummaryReportScreen> {
  List<Map<String, dynamic>> _cycles = [];
  bool _isLoading = true;

  String? _selectedCycleId;
  Map<String, dynamic>? _selectedCycle;

  @override
  void initState() {
    super.initState();
    _loadCycles();
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Future<void> _loadCycles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .get();

    final cycles = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    cycles.sort(
      (a, b) => a['code'].toString().compareTo(
            b['code'].toString(),
          ),
    );

    if (!mounted) return;

    setState(() {
      _cycles = cycles;
      _isLoading = false;

      if (cycles.isNotEmpty) {
        _selectedCycleId = cycles.first['id'].toString();
        _selectedCycle = cycles.first;
      }
    });
  }

    Widget _buildInfoCard({
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
                size: 32,
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

      Widget _buildSummarySection(
    QuerySnapshot followupSnapshot,
    QuerySnapshot expensesSnapshot,
    QuerySnapshot salesSnapshot,
  ) {
    if (_selectedCycle == null) {
      return const Center(
        child: Text('اختر دورة لعرض التقرير'),
      );
    }

    final docs = followupSnapshot.docs;

    final records = docs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();

    final expenseDocs = expensesSnapshot.docs;

    final expenseRecords = expenseDocs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();

    final totalExpenses = expenseRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['amount']),
    );
    final saleDocs = salesSnapshot.docs;

    final saleRecords = saleDocs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();

    final totalSales = saleRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalAmount']),
    );

    final totalBirdsSold = saleRecords.fold<int>(
      0,
      (total, record) => total + _toInt(record['birdsSold']),
    );

    final totalWeightSold = saleRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalWeight']),
    );

    final netResult = totalSales - totalExpenses;
    records.sort((a, b) {
      final dateA =
          (a['date'] as Timestamp?)?.toDate() ?? DateTime(1900);
      final dateB =
          (b['date'] as Timestamp?)?.toDate() ?? DateTime(1900);

      return dateA.compareTo(dateB);
    });

    final cycleCode = (_selectedCycle!['code'] ?? '').toString();
    final cycleName = (_selectedCycle!['name'] ?? '').toString();
    final breed = (_selectedCycle!['breed'] ?? '').toString();
    final status = (_selectedCycle!['status'] ?? '').toString();

    final startDate = _selectedCycle!['startDate'] as Timestamp?;
    final initialChicks = _toInt(_selectedCycle!['chicksCount']);

    final totalMortality = records.fold<int>(
      0,
      (total, record) => total + _toInt(record['mortality']),
    );

    final totalFeed = records.fold<double>(
      0,
      (total, record) => total + _toDouble(record['feedQty']),
    );

    final remainingChicks = initialChicks - totalMortality;

    final mortalityRate = initialChicks == 0
        ? 0.0
        : (totalMortality / initialChicks) * 100;

    final latestAverageWeight = records.isEmpty
        ? 0.0
        : _toDouble(records.last['averageWeight']);

    final latestFollowupDate = records.isEmpty
        ? 'لا يوجد'
        : _formatDate(records.last['date'] as Timestamp?);

    final daysFromStart = startDate == null
        ? 0
        : DateTime.now().difference(startDate.toDate()).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$cycleCode - $cycleName',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'السلالة: $breed   |   الحالة: $status   |   تاريخ البداية: ${_formatDate(startDate)}',
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'بيانات الدورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'عدد الكتاكيت في البداية',
              value: initialChicks.toString(),
              icon: Icons.egg_alt,
              color: Colors.orange,
            ),
            _buildInfoCard(
              title: 'عمر الدورة بالأيام',
              value: daysFromStart.toString(),
              icon: Icons.today,
              color: Colors.blue,
            ),
            _buildInfoCard(
              title: 'حالة الدورة',
              value: status,
              icon: Icons.info,
              color: status == 'نشطة' ? Colors.green : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'ملخص المتابعة اليومية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'إجمالي النفوق',
              value: totalMortality.toString(),
              icon: Icons.warning,
              color: Colors.red,
            ),
            _buildInfoCard(
              title: 'المتبقي الحالي',
              value: remainingChicks.toString(),
              icon: Icons.pets,
              color: Colors.green,
            ),
            _buildInfoCard(
              title: 'نسبة النفوق',
              value: '${_formatNumber(mortalityRate)} %',
              icon: Icons.percent,
              color: Colors.deepOrange,
            ),
            _buildInfoCard(
              title: 'إجمالي العلف المستهلك',
              value: _formatNumber(totalFeed),
              icon: Icons.grass,
              color: Colors.brown,
            ),
            _buildInfoCard(
              title: 'آخر وزن متوسط',
              value: _formatNumber(latestAverageWeight),
              icon: Icons.monitor_weight,
              color: Colors.purple,
            ),
            _buildInfoCard(
              title: 'آخر متابعة',
              value: latestFollowupDate,
              icon: Icons.calendar_month,
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'مصروفات الدورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'إجمالي المصروفات',
              value: _formatNumber(totalExpenses),
              icon: Icons.receipt_long,
              color: Colors.indigo,
            ),
            _buildInfoCard(
              title: 'عدد بنود المصروفات',
              value: expenseRecords.length.toString(),
              icon: Icons.list_alt,
              color: Colors.blueGrey,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'مبيعات الدورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'إجمالي المبيعات',
              value: _formatNumber(totalSales),
              icon: Icons.monetization_on,
              color: Colors.green,
            ),
            _buildInfoCard(
              title: 'عدد الطيور المباعة',
              value: totalBirdsSold.toString(),
              icon: Icons.pets,
              color: Colors.teal,
            ),
            _buildInfoCard(
              title: 'إجمالي الوزن المباع',
              value: '${_formatNumber(totalWeightSold)} كجم',
              icon: Icons.monitor_weight,
              color: Colors.purple,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'نتيجة الدورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: netResult >= 0 ? 'صافي ربح' : 'صافي خسارة',
              value: _formatNumber(netResult.abs()),
              icon: netResult >= 0 ? Icons.trending_up : Icons.trending_down,
              color: netResult >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
        if (records.isEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'لم يتم تسجيل متابعات يومية لهذه الدورة حتى الآن.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }
  Future<void> _printReport() async {
    if (_selectedCycleId == null || _selectedCycle == null) {
      return;
    }

    final followupSnapshot = await FirebaseFirestore.instance
        .collection('cycle_daily_followups')
        .where(
          'cycleId',
          isEqualTo: _selectedCycleId,
        )
        .get();

    final expenseSnapshot = await FirebaseFirestore.instance
        .collection('cycle_expenses')
        .where(
          'cycleId',
          isEqualTo: _selectedCycleId,
        )
        .get();

    final salesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_sales')
        .where(
          'cycleId',
          isEqualTo: _selectedCycleId,
        )
        .get();

    final followupRecords = followupSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    followupRecords.sort((a, b) {
      final dateA =
          (a['date'] as Timestamp?)?.toDate() ?? DateTime(1900);
      final dateB =
          (b['date'] as Timestamp?)?.toDate() ?? DateTime(1900);

      return dateA.compareTo(dateB);
    });

    final expenseRecords = expenseSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();

    final saleRecords = salesSnapshot.docs.map((doc) {
      return doc.data();
    }).toList();
        final cycleCode = (_selectedCycle!['code'] ?? '').toString();
    final cycleName = (_selectedCycle!['name'] ?? '').toString();
    final breed = (_selectedCycle!['breed'] ?? '').toString();
    final status = (_selectedCycle!['status'] ?? '').toString();

    final startDate = _selectedCycle!['startDate'] as Timestamp?;
    final initialChicks = _toInt(_selectedCycle!['chicksCount']);

    final totalMortality = followupRecords.fold<int>(
      0,
      (total, record) => total + _toInt(record['mortality']),
    );

    final totalFeed = followupRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['feedQty']),
    );

    final remainingChicks = initialChicks - totalMortality;

    final mortalityRate = initialChicks == 0
        ? 0.0
        : (totalMortality / initialChicks) * 100;

    final latestAverageWeight = followupRecords.isEmpty
        ? 0.0
        : _toDouble(followupRecords.last['averageWeight']);

    final latestFollowupDate = followupRecords.isEmpty
        ? 'لا يوجد'
        : _formatDate(followupRecords.last['date'] as Timestamp?);

    final daysFromStart = startDate == null
        ? 0
        : DateTime.now().difference(startDate.toDate()).inDays + 1;

    final totalExpenses = expenseRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['amount']),
    );

    final totalSales = saleRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalAmount']),
    );

    final totalBirdsSold = saleRecords.fold<int>(
      0,
      (total, record) => total + _toInt(record['birdsSold']),
    );

    final totalWeightSold = saleRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalWeight']),
    );

    final netResult = totalSales - totalExpenses;
        final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();

    final netResultTitle = netResult >= 0 ? 'صافي ربح' : 'صافي خسارة';

    final reportData = [
      ['كود الدورة', cycleCode],
      ['اسم الدورة', cycleName],
      ['السلالة', breed],
      ['الحالة', status],
      ['تاريخ البداية', _formatDate(startDate)],
      ['عمر الدورة بالأيام', daysFromStart.toString()],
      ['عدد الكتاكيت في البداية', initialChicks.toString()],
      ['إجمالي النفوق', totalMortality.toString()],
      ['المتبقي الحالي', remainingChicks.toString()],
      ['نسبة النفوق', '${_formatNumber(mortalityRate)} %'],
      ['إجمالي العلف المستهلك', _formatNumber(totalFeed)],
      ['آخر وزن متوسط', _formatNumber(latestAverageWeight)],
      ['آخر متابعة', latestFollowupDate],
      ['إجمالي المصروفات', _formatNumber(totalExpenses)],
      ['إجمالي المبيعات', _formatNumber(totalSales)],
      ['عدد الطيور المباعة', totalBirdsSold.toString()],
      ['إجمالي الوزن المباع', '${_formatNumber(totalWeightSold)} كجم'],
      [netResultTitle, _formatNumber(netResult.abs())],
    ];
    final followupDetails = followupRecords.map<List<String>>((record) {
      return [
        _formatDate(record['date'] as Timestamp?),
        _toInt(record['mortality']).toString(),
        _formatNumber(_toDouble(record['feedQty'])),
        _formatNumber(_toDouble(record['averageWeight'])),
        (record['notes'] ?? '').toString(),
      ];
    }).toList();

    final expenseDetails = expenseRecords.map<List<String>>((record) {
      return [
        _formatDate(record['date'] as Timestamp?),
        (record['category'] ?? '').toString(),
        _formatNumber(_toDouble(record['amount'])),
        (record['notes'] ?? '').toString(),
      ];
    }).toList();

    final salesDetails = saleRecords.map<List<String>>((record) {
      return [
        _formatDate(record['date'] as Timestamp?),
        _toInt(record['birdsSold']).toString(),
        _formatNumber(_toDouble(record['totalWeight'])),
        _formatNumber(_toDouble(record['pricePerKg'])),
        _formatNumber(_toDouble(record['totalAmount'])),
        (record['notes'] ?? '').toString(),
      ];
    }).toList();
    pw.Widget buildDetailTable({
      required String title,
      required List<String> headers,
      required List<List<String>> data,
    }) {
      if (data.isEmpty) {
        return pw.SizedBox();
      }

      final reversedHeaders = headers.reversed.toList();

      final reversedData = data.map((row) {
        return row.reversed.toList();
      }).toList();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 18),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: reversedHeaders,
            data: reversedData,
            border: pw.TableBorder.all(
              color: PdfColors.grey600,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
            ),
            cellAlignment: pw.Alignment.centerRight,
            cellStyle: const pw.TextStyle(
              fontSize: 9,
            ),
          ),
        ],
      );
    }
        pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                'تقرير ملخص دورة تسمين',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                '$cycleCode - $cycleName',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['القيمة', 'البيان'],
              data: reportData.map((row) => row.reversed.toList()).toList(),
              border: pw.TableBorder.all(
                color: PdfColors.grey600,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
              cellAlignment: pw.Alignment.centerRight,
              cellStyle: const pw.TextStyle(
                fontSize: 11,
              ),
            ),
            buildDetailTable(
              title: 'تفاصيل المتابعة اليومية',
              headers: [
                'التاريخ',
                'النفوق',
                'العلف',
                'الوزن',
                'ملاحظات',
              ],
              data: followupDetails,
            ),
            buildDetailTable(
              title: 'تفاصيل المصروفات',
              headers: [
                'التاريخ',
                'النوع',
                'المبلغ',
                'ملاحظات',
              ],
              data: expenseDetails,
            ),
            buildDetailTable(
              title: 'تفاصيل المبيعات',
              headers: [
                'التاريخ',
                'العدد',
                'الوزن',
                'سعر الكيلو',
                'الإجمالي',
                'ملاحظات',
              ],
              data: salesDetails,
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'ملاحظة: صافي الربح أو الخسارة = إجمالي المبيعات - إجمالي المصروفات المسجلة.',
              style: const pw.TextStyle(
                fontSize: 10,
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

  bool _isSelectedCycleClosed() {
    return (_selectedCycle?['status'] ?? '').toString() == 'مغلقة';
  }

  Future<void> _closeSelectedCycle(BuildContext context) async {
    if (_selectedCycleId == null || _selectedCycle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار دورة أولًا'),
        ),
      );
      return;
    }

    if (_isSelectedCycleClosed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذه الدورة مغلقة بالفعل'),
        ),
      );
      return;
    }

    final cycleCode = (_selectedCycle!['code'] ?? '').toString();
    final cycleName = (_selectedCycle!['name'] ?? '').toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد إغلاق الدورة'),
          content: Text(
            'هل تريد إغلاق الدورة $cycleCode - $cycleName ؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('إغلاق الدورة'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final closedAt = Timestamp.now();

    await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .doc(_selectedCycleId)
        .update({
      'status': 'مغلقة',
      'closedAt': closedAt,
      'updatedAt': closedAt,
    });

    if (!context.mounted) return;

    setState(() {
      final index = _cycles.indexWhere(
        (cycle) => cycle['id'].toString() == _selectedCycleId,
      );

      if (index != -1) {
        _cycles[index]['status'] = 'مغلقة';
        _cycles[index]['closedAt'] = closedAt;
        _cycles[index]['updatedAt'] = closedAt;
        _selectedCycle = _cycles[index];
      } else {
        _selectedCycle!['status'] = 'مغلقة';
        _selectedCycle!['closedAt'] = closedAt;
        _selectedCycle!['updatedAt'] = closedAt;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إغلاق الدورة بنجاح'),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
                appBar: AppBar(
          title: const Text('تقرير ملخص الدورة'),
          actions: [
            IconButton(
              tooltip: 'طباعة PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _printReport,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _cycles.isEmpty
                ? const Center(
                    child: Text('لا توجد دورات تسمين حتى الآن'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedCycleId),
                          initialValue: _selectedCycleId,
                          decoration: const InputDecoration(
                            labelText: 'اختر الدورة',
                            border: OutlineInputBorder(),
                          ),
                          items: _cycles.map((cycle) {
                            final id = cycle['id'].toString();
                            final code = cycle['code'].toString();
                            final name = cycle['name'].toString();

                            return DropdownMenuItem(
                              value: id,
                              child: Text('$code - $name'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            final selectedCycle = _cycles.firstWhere(
                              (cycle) => cycle['id'].toString() == value,
                            );

                            setState(() {
                              _selectedCycleId = value;
                              _selectedCycle = selectedCycle;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _isSelectedCycleClosed()
                                ? null
                                : () => _closeSelectedCycle(context),
                            icon: Icon(
                              _isSelectedCycleClosed()
                                  ? Icons.lock
                                  : Icons.lock_open,
                            ),
                            label: Text(
                              _isSelectedCycleClosed()
                                  ? 'الدورة مغلقة'
                                  : 'إغلاق الدورة',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('cycle_daily_followups')
                                .where(
                                  'cycleId',
                                  isEqualTo: _selectedCycleId,
                                )
                                .snapshots(),
                            builder: (context, followupSnapshot) {
                              if (followupSnapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'حدث خطأ أثناء تحميل متابعة الدورة',
                                  ),
                                );
                              }

                              if (!followupSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('cycle_expenses')
                                    .where(
                                      'cycleId',
                                      isEqualTo: _selectedCycleId,
                                    )
                                    .snapshots(),
                                builder: (context, expenseSnapshot) {
                                  if (expenseSnapshot.hasError) {
                                    return const Center(
                                      child: Text(
                                        'حدث خطأ أثناء تحميل مصروفات الدورة',
                                      ),
                                    );
                                  }

                                  if (!expenseSnapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('cycle_sales')
                                        .where(
                                          'cycleId',
                                          isEqualTo: _selectedCycleId,
                                        )
                                        .snapshots(),
                                    builder: (context, salesSnapshot) {
                                      if (salesSnapshot.hasError) {
                                        return const Center(
                                          child: Text(
                                            'حدث خطأ أثناء تحميل مبيعات الدورة',
                                          ),
                                        );
                                      }

                                      if (!salesSnapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      return SingleChildScrollView(
                                        child: _buildSummarySection(
                                          followupSnapshot.data!,
                                          expenseSnapshot.data!,
                                          salesSnapshot.data!,
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}