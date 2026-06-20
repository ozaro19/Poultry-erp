import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssetDepreciationEntryScreen extends StatefulWidget {
  const AssetDepreciationEntryScreen({super.key});

  @override
  State<AssetDepreciationEntryScreen> createState() =>
      _AssetDepreciationEntryScreenState();
}

class _AssetDepreciationEntryScreenState
    extends State<AssetDepreciationEntryScreen> {
  late DateTime selectedMonth;
  late Future<Map<String, dynamic>> depreciationFuture;

  bool isPosting = false;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    depreciationFuture = _loadDepreciationData();
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

  String _formatMonth(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');

    return '${date.year}-$month';
  }

  int _monthIndex({
    required Timestamp? purchaseTimestamp,
    required DateTime depreciationMonth,
  }) {
    if (purchaseTimestamp == null) {
      return -1;
    }

    final purchaseDate = purchaseTimestamp.toDate();

    return (depreciationMonth.year - purchaseDate.year) * 12 +
        depreciationMonth.month -
        purchaseDate.month;
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

  double _depreciationForSelectedMonth({
    required double purchaseCost,
    required double salvageValue,
    required int usefulLifeMonths,
    required int monthIndex,
  }) {
    if (monthIndex < 0) {
      return 0;
    }

    if (monthIndex >= usefulLifeMonths) {
      return 0;
    }

    final monthly = _monthlyDepreciation(
      purchaseCost: purchaseCost,
      salvageValue: salvageValue,
      usefulLifeMonths: usefulLifeMonths,
    );

    final maxDepreciation = purchaseCost - salvageValue;
    final previousAccumulated = monthly * monthIndex;
    final remaining = maxDepreciation - previousAccumulated;

    if (remaining <= 0) {
      return 0;
    }

    if (monthly > remaining) {
      return remaining;
    }

    return monthly;
  }

  double _bookValueAfterPosting({
    required double purchaseCost,
    required double salvageValue,
    required int usefulLifeMonths,
    required int monthIndex,
  }) {
    final monthly = _monthlyDepreciation(
      purchaseCost: purchaseCost,
      salvageValue: salvageValue,
      usefulLifeMonths: usefulLifeMonths,
    );

    final maxDepreciation = purchaseCost - salvageValue;
    var accumulatedAfterPosting = monthly * (monthIndex + 1);

    if (accumulatedAfterPosting > maxDepreciation) {
      accumulatedAfterPosting = maxDepreciation;
    }

    if (accumulatedAfterPosting < 0) {
      accumulatedAfterPosting = 0;
    }

    return purchaseCost - accumulatedAfterPosting;
  }

  Future<bool> _hasExistingDepreciationEntry(String monthKey) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('journal_entries')
        .where('source', isEqualTo: 'asset_depreciation')
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if ((data['depreciationMonth'] ?? '').toString() == monthKey) {
        return true;
      }
    }

    return false;
  }

  Future<Map<String, dynamic>> _loadDepreciationData() async {
    final monthKey = _formatMonth(selectedMonth);

    final assetsSnapshot = await FirebaseFirestore.instance
        .collection('assets')
        .orderBy('code')
        .get();

    final rows = <Map<String, dynamic>>[];
    double totalDepreciation = 0;

    for (final doc in assetsSnapshot.docs) {
      final data = doc.data();

      final purchaseCost = _toDouble(data['purchaseCost']);
      final salvageValue = _toDouble(data['salvageValue']);
      final usefulLifeMonths = _toInt(data['usefulLifeMonths']);
      final purchaseTimestamp = data['purchaseDate'] as Timestamp?;

      final monthIndex = _monthIndex(
        purchaseTimestamp: purchaseTimestamp,
        depreciationMonth: selectedMonth,
      );

      final depreciationAmount = _depreciationForSelectedMonth(
        purchaseCost: purchaseCost,
        salvageValue: salvageValue,
        usefulLifeMonths: usefulLifeMonths,
        monthIndex: monthIndex,
      );

      if (depreciationAmount <= 0) {
        continue;
      }

      final bookValueAfterPosting = _bookValueAfterPosting(
        purchaseCost: purchaseCost,
        salvageValue: salvageValue,
        usefulLifeMonths: usefulLifeMonths,
        monthIndex: monthIndex,
      );

      totalDepreciation += depreciationAmount;

      rows.add({
        'assetId': doc.id,
        'code': (data['code'] ?? '').toString(),
        'name': (data['name'] ?? '').toString(),
        'purchaseCost': purchaseCost,
        'salvageValue': salvageValue,
        'usefulLifeMonths': usefulLifeMonths,
        'monthIndex': monthIndex,
        'depreciationAmount': depreciationAmount,
        'bookValueAfterPosting': bookValueAfterPosting,
      });
    }

    final alreadyPosted = await _hasExistingDepreciationEntry(monthKey);

    return {
      'monthKey': monthKey,
      'rows': rows,
      'totalDepreciation': totalDepreciation,
      'alreadyPosted': alreadyPosted,
    };
  }

  void _refreshData() {
    setState(() {
      depreciationFuture = _loadDepreciationData();
    });
  }

  Future<void> _pickMonth() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    setState(() {
      selectedMonth = DateTime(pickedDate.year, pickedDate.month, 1);
      depreciationFuture = _loadDepreciationData();
    });
  }

  Future<void> _ensureAccount({
    required String code,
    required String nameAr,
    required String accountType,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chart_of_accounts')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('chart_of_accounts').add({
      'code': code,
      'nameAr': nameAr,
      'nameEn': '',
      'type': accountType,
      'parentCode': '',
      'level': 0,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> _ensureDepreciationAccounts() async {
    await _ensureAccount(
      code: '5300',
      nameAr: 'مصروف إهلاك الأصول',
      accountType: 'مصروف',
    );

    await _ensureAccount(
      code: '1609',
      nameAr: 'مجمع إهلاك الأصول',
      accountType: 'أصل',
    );
  }

  Future<String> _generateEntryNumber() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('journal_entries');

    final counterSnapshot = await counterRef.get();

    int lastNumber = 0;

    if (counterSnapshot.exists) {
      final counterData = counterSnapshot.data();
      lastNumber = _toInt(counterData?['lastNumber']);
    }

    final nextNumber = lastNumber + 1;

    await counterRef.set(
      {
        'lastNumber': nextNumber,
      },
      SetOptions(merge: true),
    );

    return 'JE-${nextNumber.toString().padLeft(4, '0')}';
  }

  Future<void> _postDepreciationEntry(
    Map<String, dynamic> depreciationData,
  ) async {
    final alreadyPosted = depreciationData['alreadyPosted'] == true;
    final monthKey = depreciationData['monthKey'].toString();
    final rows = (depreciationData['rows'] as List?) ?? [];
    final totalDepreciation = _toDouble(depreciationData['totalDepreciation']);

    if (alreadyPosted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ترحيل قيد إهلاك بالفعل لهذا الشهر: $monthKey',
          ),
        ),
      );
      return;
    }

    if (rows.isEmpty || totalDepreciation <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد أصول مستحقة للإهلاك في هذا الشهر'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد ترحيل قيد الإهلاك'),
          content: Text(
            'سيتم إنشاء قيد يومية بمبلغ ${_formatNumber(totalDepreciation)} '
            'عن شهر $monthKey.\n\nهل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('ترحيل القيد'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() {
      isPosting = true;
    });

    try {
      await _ensureDepreciationAccounts();

      final entryNo = await _generateEntryNumber();

      final depreciationDetails = rows.map((row) {
        final item = row as Map<String, dynamic>;

        return {
          'assetId': item['assetId'],
          'code': item['code'],
          'name': item['name'],
          'depreciationAmount': _toDouble(item['depreciationAmount']),
          'bookValueAfterPosting': _toDouble(item['bookValueAfterPosting']),
        };
      }).toList();

      await FirebaseFirestore.instance.collection('journal_entries').add({
        'entryNo': entryNo,
        'date': Timestamp.fromDate(selectedMonth),
        'description': 'قيد إهلاك الأصول عن شهر $monthKey',
        'lines': [
          {
            'accountCode': '5300',
            'accountName': 'مصروف إهلاك الأصول',
            'debit': totalDepreciation,
            'credit': 0,
          },
          {
            'accountCode': '1609',
            'accountName': 'مجمع إهلاك الأصول',
            'debit': 0,
            'credit': totalDepreciation,
          },
        ],
        'totalDebit': totalDepreciation,
        'totalCredit': totalDepreciation,
        'isBalanced': true,
        'source': 'asset_depreciation',
        'depreciationMonth': monthKey,
        'assetDepreciationDetails': depreciationDetails,
        'createdAt': Timestamp.now(),
      });

      if (!mounted) return;

      _refreshData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم ترحيل قيد الإهلاك بنجاح: $entryNo',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء ترحيل قيد الإهلاك: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isPosting = false;
        });
      }
    }
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

  Widget _buildDataContent(Map<String, dynamic> depreciationData) {
    final monthKey = depreciationData['monthKey'].toString();
    final rows = (depreciationData['rows'] as List?) ?? [];
    final totalDepreciation = _toDouble(depreciationData['totalDepreciation']);
    final alreadyPosted = depreciationData['alreadyPosted'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(
              title: 'شهر الإهلاك',
              value: monthKey,
              icon: Icons.calendar_month,
              color: Colors.indigo,
            ),
            _buildSummaryCard(
              title: 'عدد الأصول المستحقة',
              value: rows.length.toString(),
              icon: Icons.business,
              color: Colors.brown,
            ),
            _buildSummaryCard(
              title: 'إجمالي قيد الإهلاك',
              value: _formatNumber(totalDepreciation),
              icon: Icons.trending_down,
              color: Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (alreadyPosted)
          Card(
            color: Colors.orange.shade50,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم ترحيل قيد إهلاك لهذا الشهر من قبل، ولن يسمح النظام بتكرار نفس القيد.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.date_range),
              label: Text(
                'اختيار الشهر: ${_formatMonth(selectedMonth)}',
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: isPosting || alreadyPosted
                  ? null
                  : () => _postDepreciationEntry(depreciationData),
              icon: isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.post_add),
              label: Text(
                isPosting ? 'جاري الترحيل...' : 'ترحيل قيد الإهلاك',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'تفاصيل الأصول المستحقة للإهلاك',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'لا توجد أصول مستحقة للإهلاك في هذا الشهر.',
              ),
            ),
          )
        else
          Card(
            elevation: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الكود')),
                  DataColumn(label: Text('اسم الأصل')),
                  DataColumn(label: Text('تكلفة الشراء')),
                  DataColumn(label: Text('قيمة الإهلاك')),
                  DataColumn(label: Text('القيمة الدفترية بعد الترحيل')),
                ],
                rows: rows.map((row) {
                  final item = row as Map<String, dynamic>;

                  return DataRow(
                    cells: [
                      DataCell(Text(item['code'].toString())),
                      DataCell(Text(item['name'].toString())),
                      DataCell(
                        Text(_formatNumber(_toDouble(item['purchaseCost']))),
                      ),
                      DataCell(
                        Text(
                          _formatNumber(
                            _toDouble(item['depreciationAmount']),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatNumber(
                            _toDouble(item['bookValueAfterPosting']),
                          ),
                        ),
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
          title: const Text('ترحيل قيد إهلاك الأصول'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshData,
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
                    'ترحيل قيد إهلاك الأصول',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ينشئ النظام قيد يومية تلقائيًا بمصروف الإهلاك ومجمع الإهلاك.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<Map<String, dynamic>>(
                    future: depreciationFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text(
                            'حدث خطأ أثناء تحميل بيانات الإهلاك',
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return _buildDataContent(snapshot.data!);
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