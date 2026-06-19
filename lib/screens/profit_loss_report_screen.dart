import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProfitLossReportScreen extends StatefulWidget {
  const ProfitLossReportScreen({super.key});

  @override
  State<ProfitLossReportScreen> createState() =>
      _ProfitLossReportScreenState();
}

class _ProfitLossReportScreenState extends State<ProfitLossReportScreen> {
  late Future<Map<String, dynamic>> reportFuture;

  DateTime? fromDate;
  DateTime? toDate;

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

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';

    return '${date.year}-${date.month}-${date.day}';
  }

  bool _isWithinDateRange(Timestamp? timestamp) {
    if (fromDate == null && toDate == null) {
      return true;
    }

    if (timestamp == null) {
      return false;
    }

    final date = timestamp.toDate();

    if (fromDate != null) {
      final start = DateTime(
        fromDate!.year,
        fromDate!.month,
        fromDate!.day,
      );

      if (date.isBefore(start)) {
        return false;
      }
    }

    if (toDate != null) {
      final end = DateTime(
        toDate!.year,
        toDate!.month,
        toDate!.day,
        23,
        59,
        59,
      );

      if (date.isAfter(end)) {
        return false;
      }
    }

    return true;
  }

  Future<Map<String, dynamic>> _loadReport() async {
    final salesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_sales')
        .get();

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('cycle_expenses')
        .get();

    final salesRecords = salesSnapshot.docs.map((doc) {
      return doc.data();
    }).where((record) {
      return _isWithinDateRange(record['date'] as Timestamp?);
    }).toList();

    final expenseRecords = expensesSnapshot.docs.map((doc) {
      return doc.data();
    }).where((record) {
      return _isWithinDateRange(record['date'] as Timestamp?);
    }).toList();

    final totalSales = salesRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['totalAmount']),
    );

    final totalExpenses = expenseRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['amount']),
    );

    final relatedCycleIds = <String>{};

    for (final record in salesRecords) {
      final cycleId = (record['cycleId'] ?? '').toString();

      if (cycleId.isNotEmpty) {
        relatedCycleIds.add(cycleId);
      }
    }

    for (final record in expenseRecords) {
      final cycleId = (record['cycleId'] ?? '').toString();

      if (cycleId.isNotEmpty) {
        relatedCycleIds.add(cycleId);
      }
    }

    final netResult = totalSales - totalExpenses;

    return {
      'totalSales': totalSales,
      'totalExpenses': totalExpenses,
      'netResult': netResult,
      'salesCount': salesRecords.length,
      'expensesCount': expenseRecords.length,
      'cyclesCount': relatedCycleIds.length,
    };
  }

  void _refreshReport() {
    setState(() {
      reportFuture = _loadReport();
    });
  }

  Future<void> _pickFromDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) return;

    setState(() {
      fromDate = selectedDate;
      reportFuture = _loadReport();
    });
  }

  Future<void> _pickToDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) return;

    setState(() {
      toDate = selectedDate;
      reportFuture = _loadReport();
    });
  }

  void _clearDateFilter() {
    setState(() {
      fromDate = null;
      toDate = null;
      reportFuture = _loadReport();
    });
  }

  Widget _buildDateButton({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 260,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
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

  Widget _buildReportContent(Map<String, dynamic> data) {
    final totalSales = _toDouble(data['totalSales']);
    final totalExpenses = _toDouble(data['totalExpenses']);
    final netResult = _toDouble(data['netResult']);

    final salesCount = data['salesCount'] ?? 0;
    final expensesCount = data['expensesCount'] ?? 0;
    final cyclesCount = data['cyclesCount'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              title: 'إجمالي المبيعات',
              value: _formatNumber(totalSales),
              icon: Icons.monetization_on,
              color: Colors.green,
            ),
            _buildStatCard(
              title: 'إجمالي المصروفات',
              value: _formatNumber(totalExpenses),
              icon: Icons.receipt_long,
              color: Colors.deepOrange,
            ),
            _buildStatCard(
              title: netResult >= 0 ? 'صافي ربح' : 'صافي خسارة',
              value: _formatNumber(netResult.abs()),
              icon: netResult >= 0
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: netResult >= 0 ? Colors.green : Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              title: 'عدد عمليات البيع',
              value: salesCount.toString(),
              icon: Icons.shopping_cart,
              color: Colors.teal,
            ),
            _buildStatCard(
              title: 'عدد بنود المصروفات',
              value: expensesCount.toString(),
              icon: Icons.list_alt,
              color: Colors.blueGrey,
            ),
            _buildStatCard(
              title: 'عدد الدورات المرتبطة',
              value: cyclesCount.toString(),
              icon: Icons.agriculture,
              color: Colors.indigo,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _printReport() async {
    final data = await _loadReport();

    final totalSales = _toDouble(data['totalSales']);
    final totalExpenses = _toDouble(data['totalExpenses']);
    final netResult = _toDouble(data['netResult']);

    final salesCount = data['salesCount'] ?? 0;
    final expensesCount = data['expensesCount'] ?? 0;
    final cyclesCount = data['cyclesCount'] ?? 0;

    final settingsDocument = await FirebaseFirestore.instance
        .collection('system_settings')
        .doc('company')
        .get();

    final settingsData = settingsDocument.data();

    final companyName =
        (settingsData?['companyName'] ?? 'اسم الشركة تحت الإنشاء')
            .toString();

    final reportTitle =
        (settingsData?['reportTitle'] ?? 'نظام إدارة مزارع الدواجن')
            .toString();

    final phone =
        (settingsData?['phone'] ?? '').toString();

    final address =
        (settingsData?['address'] ?? '').toString();

    final footerNote =
        (settingsData?['footerNote'] ?? '').toString();

    final logoData = await rootBundle.load(
      'assets/images/poultry_logo.png',
    );

    final logoImage = pw.MemoryImage(
      logoData.buffer.asUint8List(),
    );

    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();

    final netResultTitle = netResult >= 0 ? 'صافي ربح' : 'صافي خسارة';

    final netResultBackgroundColor =
        netResult >= 0 ? PdfColors.green100 : PdfColors.red100;

    final netResultBorderColor =
        netResult >= 0 ? PdfColors.green : PdfColors.red;

    final reportRows = [
      ['الفترة من', _formatDate(fromDate)],
      ['الفترة إلى', _formatDate(toDate)],
      ['إجمالي المبيعات', _formatNumber(totalSales)],
      ['إجمالي المصروفات', _formatNumber(totalExpenses)],
      [netResultTitle, _formatNumber(netResult.abs())],
      ['عدد عمليات البيع', salesCount.toString()],
      ['عدد بنود المصروفات', expensesCount.toString()],
      ['عدد الدورات المرتبطة', cyclesCount.toString()],
    ];

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
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(
                  color: PdfColors.grey600,
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Image(
                    logoImage,
                    width: 60,
                    height: 60,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'هاتف: $phone',
                      style: const pw.TextStyle(
                        fontSize: 9,
                      ),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'العنوان: $address',
                      style: const pw.TextStyle(
                        fontSize: 9,
                      ),
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Text(
                    reportTitle,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'تقرير أرباح وخسائر عام',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['القيمة', 'البيان'],
              data: reportRows.map((row) => row.reversed.toList()).toList(),
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
            pw.SizedBox(height: 14),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: netResultBackgroundColor,
                border: pw.Border.all(
                  color: netResultBorderColor,
                ),
              ),
              child: pw.Center(
                child: pw.Text(
                  '$netResultTitle: ${_formatNumber(netResult.abs())}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (footerNote.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Text(
                footerNote,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير أرباح وخسائر عام'),
          actions: [
            IconButton(
              tooltip: 'طباعة PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _printReport,
            ),
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
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقرير أرباح وخسائر عام',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يعرض إجمالي المبيعات والمصروفات وصافي الربح أو الخسارة خلال فترة محددة.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildDateButton(
                        title: 'من تاريخ',
                        value: _formatDate(fromDate),
                        icon: Icons.date_range,
                        onTap: _pickFromDate,
                      ),
                      _buildDateButton(
                        title: 'إلى تاريخ',
                        value: _formatDate(toDate),
                        icon: Icons.event,
                        onTap: _pickToDate,
                      ),
                      SizedBox(
                        width: 180,
                        child: OutlinedButton.icon(
                          onPressed: _clearDateFilter,
                          icon: const Icon(Icons.clear),
                          label: const Text('مسح الفلتر'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<Map<String, dynamic>>(
                    future: reportFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل تقرير الأرباح والخسائر',
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