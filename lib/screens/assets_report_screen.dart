import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AssetsReportScreen extends StatefulWidget {
  const AssetsReportScreen({super.key});

  @override
  State<AssetsReportScreen> createState() => _AssetsReportScreenState();
}

class _AssetsReportScreenState extends State<AssetsReportScreen> {
  late Future<List<Map<String, dynamic>>> reportFuture;

  @override
  void initState() {
    super.initState();
    reportFuture = _loadAssetsReport();
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;

    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  int _monthsElapsed(Timestamp? purchaseTimestamp) {
    if (purchaseTimestamp == null) {
      return 0;
    }

    final purchaseDate = purchaseTimestamp.toDate();
    final now = DateTime.now();

    var months = (now.year - purchaseDate.year) * 12;
    months += now.month - purchaseDate.month;

    if (now.day < purchaseDate.day) {
      months--;
    }

    if (months < 0) {
      return 0;
    }

    return months;
  }

  double _monthlyDepreciation({
    required double purchaseCost,
    required double salvageValue,
    required int usefulLifeMonths,
  }) {
    if (usefulLifeMonths <= 0) {
      return 0;
    }

    final depreciableValue = purchaseCost - salvageValue;

    if (depreciableValue <= 0) {
      return 0;
    }

    return depreciableValue / usefulLifeMonths;
  }

  double _accumulatedDepreciation({
    required double purchaseCost,
    required double salvageValue,
    required int usefulLifeMonths,
    required int elapsedMonths,
  }) {
    final monthly = _monthlyDepreciation(
      purchaseCost: purchaseCost,
      salvageValue: salvageValue,
      usefulLifeMonths: usefulLifeMonths,
    );

    final maxDepreciation = purchaseCost - salvageValue;
    final accumulated = monthly * elapsedMonths;

    if (accumulated > maxDepreciation) {
      return maxDepreciation;
    }

    if (accumulated < 0) {
      return 0;
    }

    return accumulated;
  }

  Future<List<Map<String, dynamic>>> _loadAssetsReport() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('assets')
        .orderBy('code')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      final purchaseCost = _toDouble(data['purchaseCost']);
      final salvageValue = _toDouble(data['salvageValue']);
      final usefulLifeMonths = _toInt(data['usefulLifeMonths']);

      final purchaseTimestamp = data['purchaseDate'] as Timestamp?;
      final elapsedMonths = _monthsElapsed(purchaseTimestamp);

      final monthlyDepreciation = _monthlyDepreciation(
        purchaseCost: purchaseCost,
        salvageValue: salvageValue,
        usefulLifeMonths: usefulLifeMonths,
      );

      final accumulatedDepreciation = _accumulatedDepreciation(
        purchaseCost: purchaseCost,
        salvageValue: salvageValue,
        usefulLifeMonths: usefulLifeMonths,
        elapsedMonths: elapsedMonths,
      );

      final bookValue = purchaseCost - accumulatedDepreciation;

      return {
        'id': doc.id,
        'code': (data['code'] ?? '').toString(),
        'name': (data['name'] ?? '').toString(),
        'purchaseDate': purchaseTimestamp,
        'purchaseCost': purchaseCost,
        'salvageValue': salvageValue,
        'usefulLifeMonths': usefulLifeMonths,
        'elapsedMonths': elapsedMonths,
        'monthlyDepreciation': monthlyDepreciation,
        'accumulatedDepreciation': accumulatedDepreciation,
        'bookValue': bookValue,
        'notes': (data['notes'] ?? '').toString(),
      };
    }).toList();
  }

  void _refreshReport() {
    setState(() {
      reportFuture = _loadAssetsReport();
    });
  }

  String _csvValue(dynamic value) {
    final text = value.toString().replaceAll('"', '""');

    return '"$text"';
  }

  Future<void> _exportCsvReport() async {
    final rows = await _loadAssetsReport();

    if (rows.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات للتصدير'),
        ),
      );
      return;
    }

    final buffer = StringBuffer('\uFEFF');

    buffer.writeln(
      [
        'الكود',
        'اسم الأصل',
        'تاريخ الشراء',
        'تكلفة الشراء',
        'القيمة التخريدية',
        'العمر الإنتاجي بالشهور',
        'الشهور المنقضية',
        'الإهلاك الشهري',
        'الإهلاك المتراكم',
        'القيمة الدفترية',
      ].map(_csvValue).join(','),
    );

    for (final row in rows) {
      buffer.writeln(
        [
          row['code'],
          row['name'],
          _formatDate(row['purchaseDate'] as Timestamp?),
          _formatNumber(_toDouble(row['purchaseCost'])),
          _formatNumber(_toDouble(row['salvageValue'])),
          row['usefulLifeMonths'],
          row['elapsedMonths'],
          _formatNumber(_toDouble(row['monthlyDepreciation'])),
          _formatNumber(_toDouble(row['accumulatedDepreciation'])),
          _formatNumber(_toDouble(row['bookValue'])),
        ].map(_csvValue).join(','),
      );
    }

    final bytes = Uint8List.fromList(
      utf8.encode(buffer.toString()),
    );

    await FileSaver.instance.saveFile(
      name: 'assets_report',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.other,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير تقرير الأصول CSV بنجاح'),
      ),
    );
  }

  Future<void> _printReport() async {
    final rows = await _loadAssetsReport();

    if (rows.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد بيانات للطباعة'),
        ),
      );
      return;
    }

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

    final phone = (settingsData?['phone'] ?? '').toString();
    final address = (settingsData?['address'] ?? '').toString();
    final footerNote = (settingsData?['footerNote'] ?? '').toString();

    final logoData = await rootBundle.load(
      'assets/images/poultry_logo.png',
    );

    final logoImage = pw.MemoryImage(
      logoData.buffer.asUint8List(),
    );

    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final totalCost = rows.fold<double>(
      0,
      (total, row) => total + _toDouble(row['purchaseCost']),
    );

    final totalAccumulated = rows.fold<double>(
      0,
      (total, row) => total + _toDouble(row['accumulatedDepreciation']),
    );

    final totalBookValue = rows.fold<double>(
      0,
      (total, row) => total + _toDouble(row['bookValue']),
    );

    final tableRows = rows.map<List<String>>((row) {
      return [
        row['code'].toString(),
        row['name'].toString(),
        _formatDate(row['purchaseDate'] as Timestamp?),
        _formatNumber(_toDouble(row['purchaseCost'])),
        _formatNumber(_toDouble(row['monthlyDepreciation'])),
        _formatNumber(_toDouble(row['accumulatedDepreciation'])),
        _formatNumber(_toDouble(row['bookValue'])),
      ];
    }).toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
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
                    'تقرير الأصول والإهلاك',
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
              data: [
                ['إجمالي تكلفة الأصول', _formatNumber(totalCost)],
                ['إجمالي الإهلاك المتراكم', _formatNumber(totalAccumulated)],
                ['إجمالي القيمة الدفترية', _formatNumber(totalBookValue)],
              ].map((row) => row.reversed.toList()).toList(),
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
                fontSize: 10,
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'تفاصيل الأصول',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'القيمة الدفترية',
                'الإهلاك المتراكم',
                'الإهلاك الشهري',
                'تكلفة الشراء',
                'تاريخ الشراء',
                'اسم الأصل',
                'الكود',
              ],
              data: tableRows.map((row) => row.reversed.toList()).toList(),
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
                fontSize: 8,
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

  Widget _buildSummaryCard({
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

  Widget _buildReportContent(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد أصول لعرض التقرير',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    final totalCost = rows.fold<double>(
      0,
      (total, row) => total + _toDouble(row['purchaseCost']),
    );

    final totalAccumulated = rows.fold<double>(
      0,
      (total, row) => total + _toDouble(row['accumulatedDepreciation']),
    );

    final totalBookValue = rows.fold<double>(
      0,
      (total, row) => total + _toDouble(row['bookValue']),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(
              title: 'إجمالي تكلفة الأصول',
              value: _formatNumber(totalCost),
              icon: Icons.payments,
              color: Colors.indigo,
            ),
            _buildSummaryCard(
              title: 'إجمالي الإهلاك المتراكم',
              value: _formatNumber(totalAccumulated),
              icon: Icons.trending_down,
              color: Colors.deepOrange,
            ),
            _buildSummaryCard(
              title: 'إجمالي القيمة الدفترية',
              value: _formatNumber(totalBookValue),
              icon: Icons.account_balance,
              color: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'تفاصيل الأصول',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 3,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('الكود')),
                DataColumn(label: Text('اسم الأصل')),
                DataColumn(label: Text('تاريخ الشراء')),
                DataColumn(label: Text('تكلفة الشراء')),
                DataColumn(label: Text('الإهلاك الشهري')),
                DataColumn(label: Text('الإهلاك المتراكم')),
                DataColumn(label: Text('القيمة الدفترية')),
              ],
              rows: rows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text(row['code'].toString())),
                    DataCell(Text(row['name'].toString())),
                    DataCell(
                      Text(_formatDate(row['purchaseDate'] as Timestamp?)),
                    ),
                    DataCell(
                      Text(_formatNumber(_toDouble(row['purchaseCost']))),
                    ),
                    DataCell(
                      Text(
                        _formatNumber(_toDouble(row['monthlyDepreciation'])),
                      ),
                    ),
                    DataCell(
                      Text(
                        _formatNumber(
                          _toDouble(row['accumulatedDepreciation']),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(_formatNumber(_toDouble(row['bookValue']))),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
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
          title: const Text('تقرير الأصول والإهلاك'),
          actions: [
            IconButton(
              tooltip: 'تصدير CSV',
              icon: const Icon(Icons.table_chart),
              onPressed: _exportCsvReport,
            ),
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
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقرير الأصول والإهلاك',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يعرض تكلفة الأصول والإهلاك المتراكم والقيمة الدفترية الحالية.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: reportFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل تقرير الأصول',
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