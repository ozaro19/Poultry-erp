import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CapitalReportScreen extends StatefulWidget {
  const CapitalReportScreen({super.key});

  @override
  State<CapitalReportScreen> createState() => _CapitalReportScreenState();
}

class _CapitalReportScreenState extends State<CapitalReportScreen> {
  late Future<List<Map<String, dynamic>>> reportFuture;

  @override
  void initState() {
    super.initState();
    reportFuture = _loadCapitalReport();
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  String _typeLabel(String type) {
    if (type == 'withdrawal') {
      return 'سحب من رأس المال';
    }

    return 'زيادة رأس مال';
  }

  Color _typeColor(String type) {
    if (type == 'withdrawal') {
      return Colors.red;
    }

    return Colors.green;
  }

  Future<List<Map<String, dynamic>>> _loadCapitalReport() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('capital_transactions')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  void _refreshReport() {
    setState(() {
      reportFuture = _loadCapitalReport();
    });
  }

  double _totalIncrease(List<Map<String, dynamic>> rows) {
    return rows
        .where((row) => row['type'] == 'increase')
        .fold<double>(
          0,
          (total, row) => total + _toDouble(row['amount']),
        );
  }

  double _totalWithdrawal(List<Map<String, dynamic>> rows) {
    return rows
        .where((row) => row['type'] == 'withdrawal')
        .fold<double>(
          0,
          (total, row) => total + _toDouble(row['amount']),
        );
  }

  String _csvValue(dynamic value) {
    final text = value.toString().replaceAll('"', '""');

    return '"$text"';
  }

  Future<void> _exportCsvReport() async {
    final rows = await _loadCapitalReport();

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
        'التاريخ',
        'نوع الحركة',
        'المبلغ',
        'الشريك / الممول',
        'قيد اليومية',
        'ملاحظات',
      ].map(_csvValue).join(','),
    );

    for (final row in rows) {
      final type = (row['type'] ?? '').toString();

      buffer.writeln(
        [
          _formatDate(row['date'] as Timestamp?),
          _typeLabel(type),
          _formatNumber(_toDouble(row['amount'])),
          row['partnerName'] ?? '',
          row['journalEntryNo'] ?? '',
          row['notes'] ?? '',
        ].map(_csvValue).join(','),
      );
    }

    final totalIncrease = _totalIncrease(rows);
    final totalWithdrawal = _totalWithdrawal(rows);
    final netCapital = totalIncrease - totalWithdrawal;

    buffer.writeln();
    buffer.writeln(
      [
        'إجمالي زيادات رأس المال',
        _formatNumber(totalIncrease),
      ].map(_csvValue).join(','),
    );

    buffer.writeln(
      [
        'إجمالي السحوبات',
        _formatNumber(totalWithdrawal),
      ].map(_csvValue).join(','),
    );

    buffer.writeln(
      [
        'صافي رأس المال',
        _formatNumber(netCapital),
      ].map(_csvValue).join(','),
    );

    final bytes = Uint8List.fromList(
      utf8.encode(buffer.toString()),
    );

    await FileSaver.instance.saveFile(
      name: 'capital_report',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.other,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير تقرير رأس المال CSV بنجاح'),
      ),
    );
  }

  Future<void> _printReport() async {
    final rows = await _loadCapitalReport();

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

    final totalIncrease = _totalIncrease(rows);
    final totalWithdrawal = _totalWithdrawal(rows);
    final netCapital = totalIncrease - totalWithdrawal;

    final tableRows = rows.map<List<String>>((row) {
      final type = (row['type'] ?? '').toString();

      return [
        _formatDate(row['date'] as Timestamp?),
        _typeLabel(type),
        _formatNumber(_toDouble(row['amount'])),
        (row['partnerName'] ?? '').toString(),
        (row['journalEntryNo'] ?? '').toString(),
        (row['notes'] ?? '').toString(),
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
                    'تقرير رأس المال',
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
                ['إجمالي زيادات رأس المال', _formatNumber(totalIncrease)],
                ['إجمالي السحوبات', _formatNumber(totalWithdrawal)],
                ['صافي رأس المال', _formatNumber(netCapital)],
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
              'تفاصيل حركات رأس المال',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: [
                'ملاحظات',
                'قيد اليومية',
                'الشريك / الممول',
                'المبلغ',
                'نوع الحركة',
                'التاريخ',
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
            'لا توجد حركات رأس مال لعرض التقرير',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    final totalIncrease = _totalIncrease(rows);
    final totalWithdrawal = _totalWithdrawal(rows);
    final netCapital = totalIncrease - totalWithdrawal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(
              title: 'إجمالي زيادات رأس المال',
              value: _formatNumber(totalIncrease),
              icon: Icons.trending_up,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'إجمالي السحوبات',
              value: _formatNumber(totalWithdrawal),
              icon: Icons.trending_down,
              color: Colors.red,
            ),
            _buildSummaryCard(
              title: 'صافي رأس المال',
              value: _formatNumber(netCapital),
              icon: Icons.account_balance,
              color: Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'تفاصيل حركات رأس المال',
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
                DataColumn(label: Text('التاريخ')),
                DataColumn(label: Text('نوع الحركة')),
                DataColumn(label: Text('المبلغ')),
                DataColumn(label: Text('الشريك / الممول')),
                DataColumn(label: Text('قيد اليومية')),
                DataColumn(label: Text('ملاحظات')),
              ],
              rows: rows.map((row) {
                final type = (row['type'] ?? '').toString();

                return DataRow(
                  cells: [
                    DataCell(
                      Text(_formatDate(row['date'] as Timestamp?)),
                    ),
                    DataCell(
                      Text(
                        _typeLabel(type),
                        style: TextStyle(
                          color: _typeColor(type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(_formatNumber(_toDouble(row['amount']))),
                    ),
                    DataCell(
                      Text((row['partnerName'] ?? '').toString()),
                    ),
                    DataCell(
                      Text((row['journalEntryNo'] ?? '').toString()),
                    ),
                    DataCell(
                      Text((row['notes'] ?? '').toString()),
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
          title: const Text('تقرير رأس المال'),
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
                    'تقرير رأس المال',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يعرض زيادات وسحوبات رأس المال وصافي رأس المال الحالي.',
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
                          child: Text('حدث خطأ أثناء تحميل تقرير رأس المال'),
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