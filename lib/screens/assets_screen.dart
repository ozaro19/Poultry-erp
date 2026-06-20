import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssetsScreen extends StatefulWidget {
  const AssetsScreen({super.key});

  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  late Future<List<Map<String, dynamic>>> assetsFuture;

  @override
  void initState() {
    super.initState();
    assetsFuture = _loadAssets();
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';

    return '${date.year}-${date.month}-${date.day}';
  }

  Future<List<Map<String, dynamic>>> _loadAssets() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('assets')
        .orderBy('code')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
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

  Future<void> _ensureAssetPurchaseAccounts() async {
    await _ensureAccount(
      code: '1600',
      nameAr: 'الأصول الثابتة',
      accountType: 'أصل',
    );

    await _ensureAccount(
      code: '1100',
      nameAr: 'الخزينة',
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

  Future<String?> _createAssetPurchaseJournalEntry({
    required String assetId,
    required String assetCode,
    required String assetName,
    required double purchaseCost,
    required DateTime purchaseDate,
  }) async {
    if (purchaseCost <= 0) {
      return null;
    }

    await _ensureAssetPurchaseAccounts();

    final entryNo = await _generateEntryNumber();

    final journalEntryRef =
        await FirebaseFirestore.instance.collection('journal_entries').add({
      'entryNo': entryNo,
      'date': Timestamp.fromDate(purchaseDate),
      'description': 'شراء أصل ثابت: $assetName - $assetCode',
      'lines': [
        {
          'accountCode': '1600',
          'accountName': 'الأصول الثابتة',
          'debit': purchaseCost,
          'credit': 0,
        },
        {
          'accountCode': '1100',
          'accountName': 'الخزينة',
          'debit': 0,
          'credit': purchaseCost,
        },
      ],
      'totalDebit': purchaseCost,
      'totalCredit': purchaseCost,
      'isBalanced': true,
      'source': 'asset_purchase',
      'assetId': assetId,
      'createdAt': Timestamp.now(),
    });

    return journalEntryRef.id;
  }

  void _refreshAssets() {
    setState(() {
      assetsFuture = _loadAssets();
    });
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

  Future<void> _showAssetForm({
    String? assetId,
    Map<String, dynamic>? asset,
  }) async {
    final codeController = TextEditingController(
      text: (asset?['code'] ?? '').toString(),
    );

    final nameController = TextEditingController(
      text: (asset?['name'] ?? '').toString(),
    );

    final purchaseCostController = TextEditingController(
      text: asset == null
          ? ''
          : _formatNumber(_toDouble(asset['purchaseCost'])),
    );

    final salvageValueController = TextEditingController(
      text: asset == null
          ? '0'
          : _formatNumber(_toDouble(asset['salvageValue'])),
    );

    final usefulLifeController = TextEditingController(
      text: asset == null
          ? ''
          : _toInt(asset['usefulLifeMonths']).toString(),
    );

    final notesController = TextEditingController(
      text: (asset?['notes'] ?? '').toString(),
    );

    DateTime? purchaseDate =
        (asset?['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(assetId == null ? 'إضافة أصل جديد' : 'تعديل أصل'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: codeController,
                        label: 'كود الأصل',
                        icon: Icons.qr_code,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: nameController,
                        label: 'اسم الأصل',
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: purchaseCostController,
                        label: 'تكلفة الشراء',
                        icon: Icons.payments,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: salvageValueController,
                        label: 'القيمة التخريدية',
                        icon: Icons.recycling,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: usefulLifeController,
                        label: 'العمر الإنتاجي بالشهور',
                        icon: Icons.timelapse,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: purchaseDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (selectedDate == null) return;

                          setDialogState(() {
                            purchaseDate = selectedDate;
                          });
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'تاريخ الشراء: ${_formatDate(purchaseDate)}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: notesController,
                        label: 'ملاحظات',
                        icon: Icons.notes,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final code = codeController.text.trim();
                    final name = nameController.text.trim();

                    final purchaseCost = double.tryParse(
                          purchaseCostController.text.trim(),
                        ) ??
                        0;

                    final salvageValue = double.tryParse(
                          salvageValueController.text.trim(),
                        ) ??
                        0;

                    final usefulLifeMonths = int.tryParse(
                          usefulLifeController.text.trim(),
                        ) ??
                        0;

                    if (code.isEmpty ||
                        name.isEmpty ||
                        purchaseCost <= 0 ||
                        usefulLifeMonths <= 0 ||
                        purchaseDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يرجى إدخال كود واسم الأصل والتكلفة والعمر الإنتاجي',
                          ),
                        ),
                      );
                      return;
                    }

                    final data = {
                      'code': code,
                      'name': name,
                      'purchaseCost': purchaseCost,
                      'salvageValue': salvageValue,
                      'usefulLifeMonths': usefulLifeMonths,
                      'purchaseDate': Timestamp.fromDate(purchaseDate!),
                      'notes': notesController.text.trim(),
                      'updatedAt': Timestamp.now(),
                    };

                    if (assetId == null) {
                      data['createdAt'] = Timestamp.now();

                      final assetRef = await FirebaseFirestore.instance
                          .collection('assets')
                          .add(data);

                      final journalEntryId =
                          await _createAssetPurchaseJournalEntry(
                        assetId: assetRef.id,
                        assetCode: code,
                        assetName: name,
                        purchaseCost: purchaseCost,
                        purchaseDate: purchaseDate!,
                      );

                      if (journalEntryId != null) {
                        await assetRef.set(
                          {
                            'purchaseJournalEntryId': journalEntryId,
                          },
                          SetOptions(merge: true),
                        );
                      }
                    } else {
                      await FirebaseFirestore.instance
                          .collection('assets')
                          .doc(assetId)
                          .update(data);
                    }

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    if (!mounted) return;

                    _refreshAssets();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          assetId == null
                              ? 'تمت إضافة الأصل بنجاح'
                              : 'تم تعديل الأصل بنجاح',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    nameController.dispose();
    purchaseCostController.dispose();
    salvageValueController.dispose();
    usefulLifeController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteAsset(String assetId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل تريد حذف هذا الأصل؟'),
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
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    await FirebaseFirestore.instance
        .collection('assets')
        .doc(assetId)
        .delete();

    if (!mounted) return;

    _refreshAssets();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف الأصل بنجاح'),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildAssetCard(Map<String, dynamic> asset) {
    final assetId = asset['id'].toString();

    final code = (asset['code'] ?? '').toString();
    final name = (asset['name'] ?? '').toString();

    final purchaseCost = _toDouble(asset['purchaseCost']);
    final salvageValue = _toDouble(asset['salvageValue']);
    final usefulLifeMonths = _toInt(asset['usefulLifeMonths']);

    final purchaseTimestamp = asset['purchaseDate'] as Timestamp?;
    final purchaseDate = purchaseTimestamp?.toDate();

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

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 4,
      ),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.business),
        ),
        title: Text(
          '$code - $name',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'تاريخ الشراء: ${_formatDate(purchaseDate)}\n'
            'تكلفة الشراء: ${_formatNumber(purchaseCost)}\n'
            'القيمة التخريدية: ${_formatNumber(salvageValue)}\n'
            'العمر الإنتاجي: $usefulLifeMonths شهر\n'
            'الإهلاك الشهري: ${_formatNumber(monthlyDepreciation)}\n'
            'الإهلاك المتراكم: ${_formatNumber(accumulatedDepreciation)}\n'
            'القيمة الدفترية الحالية: ${_formatNumber(bookValue)}',
          ),
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit),
              onPressed: () {
                _showAssetForm(
                  assetId: assetId,
                  asset: asset,
                );
              },
            ),
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete),
              onPressed: () {
                _deleteAsset(assetId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsContent(List<Map<String, dynamic>> assets) {
    if (assets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد أصول مسجلة حتى الآن',
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: assets.length,
      itemBuilder: (context, index) {
        return _buildAssetCard(assets[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأصول والإهلاك'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshAssets,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _showAssetForm();
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة أصل'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: assetsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل الأصول'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return _buildAssetsContent(snapshot.data!);
          },
        ),
      ),
    );
  }
}