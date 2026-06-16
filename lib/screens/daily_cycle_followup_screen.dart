import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DailyCycleFollowupScreen extends StatefulWidget {
  const DailyCycleFollowupScreen({super.key});

  @override
  State<DailyCycleFollowupScreen> createState() =>
      _DailyCycleFollowupScreenState();
}

class _DailyCycleFollowupScreenState extends State<DailyCycleFollowupScreen> {
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<List<Map<String, dynamic>>> _loadActiveCycles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .where(
          'status',
          isEqualTo: 'نشطة',
        )
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

    return cycles;
  }

  Future<List<Map<String, dynamic>>> _loadInventoryItems() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('inventory_items')
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

  Future<double> _calculateCurrentItemBalance(
    String itemCode,
    double openingQty, {
    String? excludeDocumentId,
  }) async {
    final transactionsSnapshot = await FirebaseFirestore.instance
        .collection('inventory_transactions')
        .where(
          'itemCode',
          isEqualTo: itemCode,
        )
        .get();

    double totalAdd = 0;
    double totalIssue = 0;

    for (final doc in transactionsSnapshot.docs) {
      if (excludeDocumentId != null && doc.id == excludeDocumentId) {
        continue;
      }

      final data = doc.data();

      final type = (data['type'] ?? '').toString();

      final quantity = double.tryParse(
            (data['quantity'] ?? 0).toString(),
          ) ??
          0;

      if (type == 'add') {
        totalAdd += quantity;
      } else if (type == 'issue') {
        totalIssue += quantity;
      }
    }

    return openingQty + totalAdd - totalIssue;
  }

    Future<void> _addDailyFollowup(BuildContext context) async {
    final mortalityController = TextEditingController(text: '0');
    final feedQtyController = TextEditingController(text: '0');
    final averageWeightController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    DateTime selectedDate = DateTime.now();

        String? selectedCycleId;
    String selectedCycleCode = '';
    String selectedCycleName = '';

    String? selectedFeedItemCode;
    String selectedFeedItemName = '';
    String selectedFeedItemUnit = '';
    double selectedFeedItemOpeningQty = 0;

    final cycles = await _loadActiveCycles();
    final inventoryItems = await _loadInventoryItems();

    if (!context.mounted) return;

    if (cycles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد دورات نشطة لإضافة متابعة يومية'),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة متابعة يومية'),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'التاريخ: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate != null) {
                                setState(() {
                                  selectedDate = pickedDate;
                                });
                              }
                            },
                            child: const Text('اختيار التاريخ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCycleId,
                        decoration: const InputDecoration(
                          labelText: 'اختر الدورة',
                          border: OutlineInputBorder(),
                        ),
                        items: cycles.map((cycle) {
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

                          final selectedCycle = cycles.firstWhere(
                            (cycle) => cycle['id'].toString() == value,
                          );

                          setState(() {
                            selectedCycleId = value;
                            selectedCycleCode =
                                selectedCycle['code'].toString();
                            selectedCycleName =
                                selectedCycle['name'].toString();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: mortalityController,
                        decoration: const InputDecoration(
                          labelText: 'النفوق اليومي',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                                            DropdownButtonFormField<String>(
                        initialValue: selectedFeedItemCode,
                        decoration: const InputDecoration(
                          labelText: 'صنف العلف من المخزون',
                          border: OutlineInputBorder(),
                        ),
                        items: inventoryItems.map((item) {
                          final code = (item['code'] ?? '').toString();
                          final name = (item['name'] ?? '').toString();
                          final unit = (item['unit'] ?? '').toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $name - $unit'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedItem = inventoryItems.firstWhere(
                            (item) => item['code'].toString() == value,
                          );

                          setState(() {
                            selectedFeedItemCode = value;
                            selectedFeedItemName =
                                (selectedItem['name'] ?? '').toString();
                            selectedFeedItemUnit =
                                (selectedItem['unit'] ?? '').toString();
                            selectedFeedItemOpeningQty = double.tryParse(
                                  (selectedItem['openingQty'] ?? 0).toString(),
                                ) ??
                                0;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: feedQtyController,
                        decoration: const InputDecoration(
                          labelText: 'استهلاك العلف',
                          hintText: 'مثال: 5 شيكارة',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: averageWeightController,
                        decoration: const InputDecoration(
                          labelText: 'الوزن المتوسط',
                          hintText: 'مثال: 1.25 كجم',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final mortality = int.tryParse(
                          mortalityController.text.trim(),
                        ) ??
                        0;

                    final feedQty = double.tryParse(
                          feedQtyController.text.trim(),
                        ) ??
                        0;

                    final averageWeight = double.tryParse(
                          averageWeightController.text.trim(),
                        ) ??
                        0;

                    final notes = notesController.text.trim();
                    final dateKey = _dateKey(selectedDate);

                    if (selectedCycleId == null || selectedCycleId!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار الدورة'),
                        ),
                      );
                      return;
                    }

                    if (mortality < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('النفوق لا يمكن أن يكون أقل من صفر'),
                        ),
                      );
                      return;
                    }

                    if (feedQty < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'استهلاك العلف لا يمكن أن يكون أقل من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    if (averageWeight < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'الوزن المتوسط لا يمكن أن يكون أقل من صفر',
                          ),
                        ),
                      );
                      return;
                    }
                    if (feedQty > 0 &&
                        (selectedFeedItemCode == null ||
                            selectedFeedItemCode!.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب اختيار صنف العلف من المخزون',
                          ),
                        ),
                      );
                      return;
                    }

                    if (feedQty > 0) {
                      final currentBalance =
                          await _calculateCurrentItemBalance(
                        selectedFeedItemCode!,
                        selectedFeedItemOpeningQty,
                      );

                      if (!context.mounted) return;

                      if (feedQty > currentBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'رصيد العلف غير كاف. الرصيد الحالي: $currentBalance',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    final existingFollowup = await FirebaseFirestore.instance
                        .collection('cycle_daily_followups')
                        .where(
                          'cycleId',
                          isEqualTo: selectedCycleId,
                        )
                        .where(
                          'dateKey',
                          isEqualTo: dateKey,
                        )
                        .get();

                    if (!context.mounted) return;

                    if (existingFollowup.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم تسجيل متابعة لهذا اليوم من قبل',
                          ),
                        ),
                      );
                      return;
                    }

                                        final followupRef = await FirebaseFirestore.instance
                        .collection('cycle_daily_followups')
                        .add({
                      'cycleId': selectedCycleId,
                      'cycleCode': selectedCycleCode,
                      'cycleName': selectedCycleName,
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'mortality': mortality,
                      'feedQty': feedQty,
                      'feedItemCode': selectedFeedItemCode ?? '',
                      'feedItemName': selectedFeedItemName,
                      'feedItemUnit': selectedFeedItemUnit,
                      'inventoryTransactionId': '',
                      'averageWeight': averageWeight,
                      'notes': notes,
                      'createdAt': Timestamp.now(),
                    });

                    if (feedQty > 0 &&
                        selectedFeedItemCode != null &&
                        (selectedFeedItemCode?.isNotEmpty ?? false)) {
                      final transactionRef = await FirebaseFirestore.instance
                          .collection('inventory_transactions')
                          .add({
                        'type': 'issue',
                        'typeName': 'صرف',
                        'itemCode': selectedFeedItemCode,
                        'itemName': selectedFeedItemName,
                        'unit': selectedFeedItemUnit,
                        'quantity': feedQty,
                        'date': Timestamp.fromDate(selectedDate),
                        'description':
                            'استهلاك علف للدورة $selectedCycleCode - $selectedCycleName',
                        'source': 'cycle_daily_followup',
                        'cycleId': selectedCycleId,
                        'followupId': followupRef.id,
                        'createdAt': Timestamp.now(),
                      });

                      await followupRef.update({
                        'inventoryTransactionId': transactionRef.id,
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editDailyFollowup(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final mortalityController = TextEditingController(
      text: (data['mortality'] ?? 0).toString(),
    );

    final feedQtyController = TextEditingController(
      text: (data['feedQty'] ?? 0).toString(),
    );

    final averageWeightController = TextEditingController(
      text: (data['averageWeight'] ?? 0).toString(),
    );

    final notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    DateTime selectedDate =
        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

        final cycleId = (data['cycleId'] ?? '').toString();
    final cycleName = (data['cycleName'] ?? '').toString();
    final cycleCode = (data['cycleCode'] ?? '').toString();

    final inventoryItems = await _loadInventoryItems();

    if (!context.mounted) return;

    final oldFeedItemCode = (data['feedItemCode'] ?? '').toString();

    String? selectedFeedItemCode =
        oldFeedItemCode.isEmpty ? null : oldFeedItemCode;

    String selectedFeedItemName =
        (data['feedItemName'] ?? '').toString();

    String selectedFeedItemUnit =
        (data['feedItemUnit'] ?? '').toString();

    String inventoryTransactionId =
        (data['inventoryTransactionId'] ?? '').toString();

    double selectedFeedItemOpeningQty = 0;

    if (selectedFeedItemCode != null &&
    selectedFeedItemCode.isNotEmpty) {
      for (final item in inventoryItems) {
        final itemCode = (item['code'] ?? '').toString();

        if (itemCode == selectedFeedItemCode) {
          selectedFeedItemName =
              (item['name'] ?? selectedFeedItemName).toString();

          selectedFeedItemUnit =
              (item['unit'] ?? selectedFeedItemUnit).toString();

          selectedFeedItemOpeningQty = double.tryParse(
                (item['openingQty'] ?? 0).toString(),
              ) ??
              0;

          break;
        }
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تعديل متابعة يومية'),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        'الدورة: $cycleCode - $cycleName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'التاريخ: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate != null) {
                                setState(() {
                                  selectedDate = pickedDate;
                                });
                              }
                            },
                            child: const Text('تغيير التاريخ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: mortalityController,
                        decoration: const InputDecoration(
                          labelText: 'النفوق اليومي',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                                            DropdownButtonFormField<String>(
                        initialValue: selectedFeedItemCode,
                        decoration: const InputDecoration(
                          labelText: 'صنف العلف من المخزون',
                          border: OutlineInputBorder(),
                        ),
                        items: inventoryItems.map((item) {
                          final code = (item['code'] ?? '').toString();
                          final name = (item['name'] ?? '').toString();
                          final unit = (item['unit'] ?? '').toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $name - $unit'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedItem = inventoryItems.firstWhere(
                            (item) => item['code'].toString() == value,
                          );

                          setState(() {
                            selectedFeedItemCode = value;
                            selectedFeedItemName =
                                (selectedItem['name'] ?? '').toString();
                            selectedFeedItemUnit =
                                (selectedItem['unit'] ?? '').toString();
                            selectedFeedItemOpeningQty = double.tryParse(
                                  (selectedItem['openingQty'] ?? 0).toString(),
                                ) ??
                                0;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: feedQtyController,
                        decoration: const InputDecoration(
                          labelText: 'استهلاك العلف',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: averageWeightController,
                        decoration: const InputDecoration(
                          labelText: 'الوزن المتوسط',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final mortality = int.tryParse(
                          mortalityController.text.trim(),
                        ) ??
                        0;

                    final feedQty = double.tryParse(
                          feedQtyController.text.trim(),
                        ) ??
                        0;

                    final averageWeight = double.tryParse(
                          averageWeightController.text.trim(),
                        ) ??
                        0;

                    final notes = notesController.text.trim();
                    final dateKey = _dateKey(selectedDate);

                    if (mortality < 0 || feedQty < 0 || averageWeight < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يمكن إدخال أرقام أقل من صفر'),
                        ),
                      );
                      return;
                    }
                                        if (feedQty > 0 &&
                        (selectedFeedItemCode == null ||
                            selectedFeedItemCode!.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب اختيار صنف العلف من المخزون',
                          ),
                        ),
                      );
                      return;
                    }

                    if (feedQty > 0) {
                      final excludeTransactionId =
                          inventoryTransactionId.isNotEmpty &&
                                  selectedFeedItemCode == oldFeedItemCode
                              ? inventoryTransactionId
                              : null;

                      final currentBalance =
                          await _calculateCurrentItemBalance(
                        selectedFeedItemCode!,
                        selectedFeedItemOpeningQty,
                        excludeDocumentId: excludeTransactionId,
                      );

                      if (!context.mounted) return;

                      if (feedQty > currentBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'رصيد العلف غير كاف. الرصيد الحالي: $currentBalance',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    final existingFollowup = await FirebaseFirestore.instance
                        .collection('cycle_daily_followups')
                        .where(
                          'cycleId',
                          isEqualTo: cycleId,
                        )
                        .where(
                          'dateKey',
                          isEqualTo: dateKey,
                        )
                        .get();

                    if (!context.mounted) return;

                    final duplicateExists = existingFollowup.docs.any(
                      (doc) => doc.id != documentId,
                    );

                    if (duplicateExists) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يوجد سجل متابعة آخر لنفس الدورة في نفس اليوم',
                          ),
                        ),
                      );
                      return;
                    }

                                        final followupDoc = FirebaseFirestore.instance
                        .collection('cycle_daily_followups')
                        .doc(documentId);

                    await followupDoc.update({
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'mortality': mortality,
                      'feedQty': feedQty,
                      'feedItemCode':
                          feedQty > 0 ? selectedFeedItemCode ?? '' : '',
                      'feedItemName':
                          feedQty > 0 ? selectedFeedItemName : '',
                      'feedItemUnit':
                          feedQty > 0 ? selectedFeedItemUnit : '',
                      'averageWeight': averageWeight,
                      'notes': notes,
                      'updatedAt': Timestamp.now(),
                    });

                    if (feedQty > 0 &&
                        selectedFeedItemCode != null &&
                        (selectedFeedItemCode?.isNotEmpty ?? false)) {
                      final transactionData = {
                        'type': 'issue',
                        'typeName': 'صرف',
                        'itemCode': selectedFeedItemCode,
                        'itemName': selectedFeedItemName,
                        'unit': selectedFeedItemUnit,
                        'quantity': feedQty,
                        'date': Timestamp.fromDate(selectedDate),
                        'description':
                            'استهلاك علف للدورة $cycleCode - $cycleName',
                        'source': 'cycle_daily_followup',
                        'cycleId': cycleId,
                        'followupId': documentId,
                        'updatedAt': Timestamp.now(),
                      };

                      if (inventoryTransactionId.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('inventory_transactions')
                            .doc(inventoryTransactionId)
                            .set(
                              transactionData,
                              SetOptions(merge: true),
                            );
                      } else {
                        final transactionRef =
                            await FirebaseFirestore.instance
                                .collection('inventory_transactions')
                                .add({
                          ...transactionData,
                          'createdAt': Timestamp.now(),
                        });

                        inventoryTransactionId = transactionRef.id;

                        await followupDoc.update({
                          'inventoryTransactionId': inventoryTransactionId,
                        });
                      }
                    } else {
                      if (inventoryTransactionId.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('inventory_transactions')
                            .doc(inventoryTransactionId)
                            .delete();
                      }

                      await followupDoc.update({
                        'inventoryTransactionId': '',
                      });
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('حفظ التعديل'),
                ),
              ],
            );
          },
        );
      },
    );
  }

     Future<void> _deleteFollowup(
      BuildContext context,
      String documentId,
      String cycleName,
      String date,
      Map<String, dynamic> data,
    ) async {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل تريد حذف متابعة $cycleName بتاريخ $date ؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف'),
              ),
            ],
          );
        },
      );

      if (result == true) {
        final inventoryTransactionId =
            (data['inventoryTransactionId'] ?? '').toString();

        if (inventoryTransactionId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('inventory_transactions')
              .doc(inventoryTransactionId)
              .delete();
        }

        await FirebaseFirestore.instance
            .collection('cycle_daily_followups')
            .doc(documentId)
            .delete();
      }
    }

    @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المتابعة اليومية للدورات'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addDailyFollowup(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cycle_daily_followups')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل المتابعة اليومية'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text('لا توجد متابعات يومية حتى الآن'),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final documentId = docs[index].id;

                final cycleCode = (data['cycleCode'] ?? '').toString();
                final cycleName = (data['cycleName'] ?? '').toString();
                final date = data['date'] as Timestamp?;
                final mortality = data['mortality'] ?? 0;
                final feedQty = data['feedQty'] ?? 0;
                final averageWeight = data['averageWeight'] ?? 0;
                final notes = (data['notes'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.calendar_month,
                      color: Colors.blue,
                    ),
                    title: Text(
                      '$cycleCode - $cycleName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'التاريخ: ${_formatDate(date)}\n'
                      'النفوق اليومي: $mortality\n'
                      'استهلاك العلف: $feedQty\n'
                      'الوزن المتوسط: $averageWeight\n'
                      'ملاحظات: $notes',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _editDailyFollowup(
                              context,
                              documentId,
                              data,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteFollowup(
                              context,
                              documentId,
                              cycleName,
                              _formatDate(date),
                              data,
                            );
                          },
                        ),
                      ],
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

