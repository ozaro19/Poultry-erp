import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryItemsScreen extends StatelessWidget {
  const InventoryItemsScreen({super.key});

  Future<void> _addItem(BuildContext context) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    final openingQtyController = TextEditingController(text: '0');

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة صنف جديد'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود الصنف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصنف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'وحدة القياس',
                      hintText: 'مثال: كجم / طن / كرتونة / شيكارة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: openingQtyController,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                final code = codeController.text.trim();
                final name = nameController.text.trim();
                final unit = unitController.text.trim();
                final openingQty =
                    double.tryParse(openingQtyController.text.trim()) ?? 0;

                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال كود الصنف'),
                    ),
                  );
                  return;
                }

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال اسم الصنف'),
                    ),
                  );
                  return;
                }

                if (unit.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال وحدة القياس'),
                    ),
                  );
                  return;
                }

                final existingItem = await FirebaseFirestore.instance
                    .collection('inventory_items')
                    .where(
                      'code',
                      isEqualTo: code,
                    )
                    .get();

                if (existingItem.docs.isNotEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('كود الصنف موجود بالفعل'),
                      ),
                    );
                  }
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('inventory_items')
                    .add({
                  'code': code,
                  'name': name,
                  'unit': unit,
                  'openingQty': openingQty,
                  'createdAt': Timestamp.now(),
                });

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
  }

  Future<void> _editItem(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final codeController = TextEditingController(
      text: (data['code'] ?? '').toString(),
    );

    final nameController = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );

    final unitController = TextEditingController(
      text: (data['unit'] ?? '').toString(),
    );

    final openingQtyController = TextEditingController(
      text: (data['openingQty'] ?? 0).toString(),
    );

    final oldCode = (data['code'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل الصنف'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'كود الصنف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الصنف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'وحدة القياس',
                      hintText: 'مثال: كجم / طن / كرتونة / شيكارة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: openingQtyController,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الافتتاحي',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
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
                final newCode = codeController.text.trim();
                final newName = nameController.text.trim();
                final newUnit = unitController.text.trim();
                final newOpeningQty =
                    double.tryParse(openingQtyController.text.trim()) ?? 0;

                if (newCode.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال كود الصنف'),
                    ),
                  );
                  return;
                }

                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال اسم الصنف'),
                    ),
                  );
                  return;
                }

                if (newUnit.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال وحدة القياس'),
                    ),
                  );
                  return;
                }

                if (newCode != oldCode) {
                  final existingItem = await FirebaseFirestore.instance
                      .collection('inventory_items')
                      .where(
                        'code',
                        isEqualTo: newCode,
                      )
                      .get();

                  if (existingItem.docs.isNotEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('كود الصنف موجود بالفعل'),
                        ),
                      );
                    }
                    return;
                  }
                }

                await FirebaseFirestore.instance
                    .collection('inventory_items')
                    .doc(documentId)
                    .update({
                  'code': newCode,
                  'name': newName,
                  'unit': newUnit,
                  'openingQty': newOpeningQty,
                  'updatedAt': Timestamp.now(),
                });

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
  }

  Future<void> _deleteItem(
    BuildContext context,
    String documentId,
    String name,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل تريد حذف الصنف: $name ؟'),
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
      await FirebaseFirestore.instance
          .collection('inventory_items')
          .doc(documentId)
          .delete();
    }
  }
  Future<Map<String, double>> _calculateItemBalance(
    String itemCode,
    double openingQty,
  ) async {
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

    final currentBalance = openingQty + totalAdd - totalIssue;

    return {
      'openingQty': openingQty,
      'totalAdd': totalAdd,
      'totalIssue': totalIssue,
      'currentBalance': currentBalance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الأصناف'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addItem(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('inventory_items')
              .orderBy('code')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل الأصناف'),
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
                child: Text('لا توجد أصناف حتى الآن'),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final documentId = docs[index].id;

                final code = data['code'] ?? '';
                final name = data['name'] ?? '';
                final unit = data['unit'] ?? '';
                final openingQty = double.tryParse(
                      (data['openingQty'] ?? 0).toString(),
                    ) ??
                    0;

                return FutureBuilder<Map<String, double>>(
                  future: _calculateItemBalance(
                    code.toString(),
                    openingQty,
                  ),
                  builder: (context, balanceSnapshot) {
                    final balanceData = balanceSnapshot.data;

                    final totalAdd = balanceData?['totalAdd'] ?? 0;
                    final totalIssue = balanceData?['totalIssue'] ?? 0;
                    final currentBalance = balanceData?['currentBalance'] ?? openingQty;

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.inventory),
                        title: Text('$code - $name'),
                        subtitle: Text(
                          'الوحدة: $unit\n'
                          'الرصيد الافتتاحي: $openingQty\n'
                          'إجمالي الإضافة: $totalAdd\n'
                          'إجمالي الصرف: $totalIssue\n'
                          'الرصيد الحالي: $currentBalance',
                        ),
                        trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _editItem(
                              context,
                              documentId,
                              data,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteItem(
                              context,
                              documentId,
                              name.toString(),
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
            );
          },
        ),
      ),
    );
  }
}