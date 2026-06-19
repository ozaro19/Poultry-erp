import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryBalancesReportScreen extends StatefulWidget {
  const InventoryBalancesReportScreen({super.key});

  @override
  State<InventoryBalancesReportScreen> createState() =>
      _InventoryBalancesReportScreenState();
}

class _InventoryBalancesReportScreenState
    extends State<InventoryBalancesReportScreen> {
  late Future<List<Map<String, dynamic>>> reportFuture;

  bool showLowStockOnly = false;

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

  String _csvValue(dynamic value) {
    final text = value.toString().replaceAll('"', '""');

    return '"$text"';
  }

  void _refreshReport() {
    setState(() {
      reportFuture = _loadBalancesReport();
    });
  }
  Future<void> _printReport() async {
    final rows = await _loadBalancesReport();

    final filteredRows = showLowStockOnly
        ? rows.where((row) => row['isLowStock'] == true).toList()
        : rows;

    if (filteredRows.isEmpty) {
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

    final phone =
        (settingsData?['phone'] ?? '').toString();

    final address =
        (settingsData?['address'] ?? '').toString();

    final footerNote =
        (settingsData?['footerNote'] ?? '').toString();

    final currentReportTitle = showLowStockOnly
        ? 'تقرير الأصناف منخفضة الرصيد'
        : 'تقرير أرصدة المخزون';

    final logoData = await rootBundle.load(
      'assets/images/poultry_logo.png',
    );

    final logoImage = pw.MemoryImage(
      logoData.buffer.asUint8List(),
    );

    final regularFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();

    pw.Widget tableCell(
      String text, {
      bool isHeader = false,
      PdfColor? color,
    }) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: isHeader ? 9 : 8,
            fontWeight: isHeader ? pw.FontWeight.bold : null,
            color: color ?? PdfColors.black,
          ),
        ),
      );
    }

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
              padding: const pw.EdgeInsets.all(10),
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
                    width: 55,
                    height: 55,
                  ),
                  pw.SizedBox(height: 5),
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
                    currentReportTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey,
                width: 0.5,
              ),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey300,
                  ),
                  children: [
                    tableCell('الحالة', isHeader: true),
                    tableCell('الرصيد الحالي', isHeader: true),
                    tableCell('إجمالي الصرف', isHeader: true),
                    tableCell('إجمالي الإضافات', isHeader: true),
                    tableCell('الحد الأدنى', isHeader: true),
                    tableCell('الرصيد الافتتاحي', isHeader: true),
                    tableCell('الوحدة', isHeader: true),
                    tableCell('اسم الصنف', isHeader: true),
                    tableCell('الكود', isHeader: true),
                  ],
                ),
                ...filteredRows.map((row) {
                  final isLowStock = row['isLowStock'] == true;

                  return pw.TableRow(
                    children: [
                      tableCell(
                        isLowStock ? 'منخفض' : 'جيد',
                        color: isLowStock ? PdfColors.red : PdfColors.green,
                      ),
                      tableCell(_formatNumber(row['currentBalance'])),
                      tableCell(_formatNumber(row['totalIssue'])),
                      tableCell(_formatNumber(row['totalAdd'])),
                      tableCell(_formatNumber(row['minimumQty'])),
                      tableCell(_formatNumber(row['openingQty'])),
                      tableCell(row['unit'].toString()),
                      tableCell(row['name'].toString()),
                      tableCell(row['code'].toString()),
                    ],
                  );
                }),
              ],
            ),
            if (footerNote.isNotEmpty) ...[
              pw.SizedBox(height: 12),
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

  Future<void> _exportCsvReport() async {
    final rows = await _loadBalancesReport();

    final filteredRows = showLowStockOnly
        ? rows.where((row) => row['isLowStock'] == true).toList()
        : rows;

    if (filteredRows.isEmpty) {
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
        'اسم الصنف',
        'الوحدة',
        'الرصيد الافتتاحي',
        'الحد الأدنى',
        'إجمالي الإضافات',
        'إجمالي الصرف',
        'الرصيد الحالي',
        'الحالة',
      ].map(_csvValue).join(','),
    );

    for (final row in filteredRows) {
      final isLowStock = row['isLowStock'] == true;

      buffer.writeln(
        [
          row['code'],
          row['name'],
          row['unit'],
          _formatNumber(row['openingQty']),
          _formatNumber(row['minimumQty']),
          _formatNumber(row['totalAdd']),
          _formatNumber(row['totalIssue']),
          _formatNumber(row['currentBalance']),
          isLowStock ? 'منخفض' : 'جيد',
        ].map(_csvValue).join(','),
      );
    }

    final bytes = Uint8List.fromList(
      utf8.encode(buffer.toString()),
    );

    await FileSaver.instance.saveFile(
      name: showLowStockOnly
          ? 'low_stock_report'
          : 'inventory_balances_report',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.other,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تصدير ملف Excel CSV بنجاح'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            showLowStockOnly
                ? 'الأصناف منخفضة الرصيد'
                : 'تقرير أرصدة المخزون',
          ),
          actions: [
            IconButton(
              tooltip: showLowStockOnly
                  ? 'عرض كل الأصناف'
                  : 'عرض الأصناف منخفضة الرصيد فقط',
              icon: Icon(
                showLowStockOnly
                    ? Icons.inventory
                    : Icons.warning_amber,
              ),
              onPressed: () {
                setState(() {
                  showLowStockOnly = !showLowStockOnly;
                });
              },
            ),
            IconButton(
              tooltip: 'تصدير Excel CSV',
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

            final filteredRows = showLowStockOnly
                ? rows.where((row) => row['isLowStock'] == true).toList()
                : rows;

            if (filteredRows.isEmpty) {
              return const Center(
                child: Text('لا توجد أصناف منخفضة الرصيد حاليًا'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredRows.length,
              itemBuilder: (context, index) {
                final row = filteredRows[index];

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