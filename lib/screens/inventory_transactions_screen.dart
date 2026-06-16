import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'item_card_report_screen.dart';

class InventoryTransactionsScreen extends StatefulWidget {
  const InventoryTransactionsScreen({super.key});

  @override
  State<InventoryTransactionsScreen> createState() =>
      _InventoryTransactionsScreenState();
}

class _InventoryTransactionsScreenState
    extends State<InventoryTransactionsScreen> {
  String transactionSearchQuery = '';
  String transactionTypeFilter = 'الكل';

  DateTime? fromDate;
  DateTime? toDate;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
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

  Future<void> _addInventoryTransaction(BuildContext context) async {
    final quantityController = TextEditingController();
    final descriptionController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    String transactionType = 'إضافة';

    String? selectedItemCode;
    String selectedItemName = '';
    String selectedItemUnit = '';
    double selectedItemOpeningQty = 0;

    final items = await _loadItems();

    if (!context.mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إضافة أصناف أولًا قبل تسجيل حركة مخزون'),
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
              title: const Text('إضافة حركة مخزون'),
              content: SizedBox(
                width: 600,
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
                        initialValue: transactionType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الحركة',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'إضافة',
                            child: Text('إذن إضافة مخزون'),
                          ),
                          DropdownMenuItem(
                            value: 'صرف',
                            child: Text('إذن صرف مخزون'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            transactionType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedItemCode,
                        decoration: const InputDecoration(
                          labelText: 'الصنف',
                          border: OutlineInputBorder(),
                        ),
                        items: items.map((item) {
                          final code = item['code'].toString();
                          final name = item['name'].toString();
                          final unit = item['unit'].toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $name - $unit'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedItem = items.firstWhere(
                            (item) => item['code'].toString() == value,
                          );

                          setState(() {
                            selectedItemCode = value;
                            selectedItemName = selectedItem['name'].toString();
                            selectedItemUnit = selectedItem['unit'].toString();
                            selectedItemOpeningQty = double.tryParse(
                                  (selectedItem['openingQty'] ?? 0).toString(),
                                ) ??
                                0;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: quantityController,
                        decoration: const InputDecoration(
                          labelText: 'الكمية',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'البيان',
                          border: OutlineInputBorder(),
                        ),
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
                    final quantity =
                        double.tryParse(quantityController.text.trim()) ?? 0;

                    final description = descriptionController.text.trim();

                    if (selectedItemCode == null ||
                        selectedItemCode!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار الصنف'),
                        ),
                      );
                      return;
                    }

                    if (quantity <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال كمية صحيحة'),
                        ),
                      );
                      return;
                    }
                    if (transactionType == 'صرف') {
                      final currentBalance = await _calculateCurrentItemBalance(
                        selectedItemCode!,
                        selectedItemOpeningQty,
                      );

                      if (quantity > currentBalance) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'لا يمكن صرف كمية أكبر من الرصيد المتاح. الرصيد الحالي: $currentBalance',
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    if (description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال البيان'),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('inventory_transactions')
                        .add({
                      'type': transactionType == 'إضافة' ? 'add' : 'issue',
                      'typeName': transactionType,
                      'itemCode': selectedItemCode,
                      'itemName': selectedItemName,
                      'unit': selectedItemUnit,
                      'quantity': quantity,
                      'date': Timestamp.fromDate(selectedDate),
                      'description': description,
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
      },
    );
  }
  Future<void> _editInventoryTransaction(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final quantityController = TextEditingController(
      text: (data['quantity'] ?? 0).toString(),
    );

    final descriptionController = TextEditingController(
      text: (data['description'] ?? '').toString(),
    );

    final type = (data['type'] ?? '').toString();

    String transactionType = type == 'issue' ? 'صرف' : 'إضافة';
    String? selectedItemCode = (data['itemCode'] ?? '').toString();
    String selectedItemName = (data['itemName'] ?? '').toString();
    String selectedItemUnit = (data['unit'] ?? '').toString();
    DateTime selectedDate = DateTime.now();

    final currentDate = data['date'];

    if (currentDate is Timestamp) {
      selectedDate = currentDate.toDate();
    }

    double openingQty = 0;

    final items = await _loadItems();

    final matchingItems = items.where(
      (item) => item['code'].toString() == selectedItemCode,
    );

    if (matchingItems.isNotEmpty) {
      final selectedItem = matchingItems.first;

      openingQty = double.tryParse(
            (selectedItem['openingQty'] ?? 0).toString(),
          ) ??
          0;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل حركة مخزون'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: transactionType,
                    decoration: const InputDecoration(
                      labelText: 'نوع الحركة',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'إضافة',
                        child: Text('إذن إضافة مخزون'),
                      ),
                      DropdownMenuItem(
                        value: 'صرف',
                        child: Text('إذن صرف مخزون'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      transactionType = value;
                    },
                  ),
                  const SizedBox(height: 8),
                 DropdownButtonFormField<String>(
                    initialValue: selectedItemCode,
                    decoration: const InputDecoration(
                      labelText: 'الصنف',
                      border: OutlineInputBorder(),
                    ),
                    items: items.map((item) {
                      final code = item['code'].toString();
                      final name = item['name'].toString();
                      final unit = item['unit'].toString();

                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code - $name - $unit'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      final selectedItem = items.firstWhere(
                        (item) => item['code'].toString() == value,
                      );

                      selectedItemCode = value;
                      selectedItemName = selectedItem['name'].toString();
                      selectedItemUnit = selectedItem['unit'].toString();

                      openingQty = double.tryParse(
                            (selectedItem['openingQty'] ?? 0).toString(),
                          ) ??
                          0;
                    },
                  ),
                  const SizedBox(height: 8),
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
                            selectedDate = pickedDate;
                          }
                        },
                        child: const Text('تعديل التاريخ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'الكمية ($selectedItemUnit)',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'البيان',
                      border: OutlineInputBorder(),
                    ),
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
                final newQuantity =
                    double.tryParse(quantityController.text.trim()) ?? 0;

                final newDescription =
                    descriptionController.text.trim();

                if (newQuantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال كمية صحيحة'),
                    ),
                  );
                  return;
                }

                if (transactionType == 'صرف') {
                  final currentBalance =
                      await _calculateCurrentItemBalance(
                    selectedItemCode!,
                    openingQty,
                    excludeDocumentId: documentId,
                  );

                  if (newQuantity > currentBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'لا يمكن صرف كمية أكبر من الرصيد المتاح. الرصيد الحالي: $currentBalance',
                        ),
                      ),
                    );
                    return;
                  }
                }

                if (newDescription.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('يجب إدخال البيان'),
                    ),
                  );
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('inventory_transactions')
                    .doc(documentId)
                    .update({
                  'type': transactionType == 'إضافة' ? 'add' : 'issue',
                  'typeName': transactionType,
                  'itemCode': selectedItemCode,
                  'itemName': selectedItemName,
                  'unit': selectedItemUnit,
                  'quantity': newQuantity,
                  'description': newDescription,
                  'date': Timestamp.fromDate(selectedDate),
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

  Future<void> _deleteInventoryTransaction(
    BuildContext context,
    String documentId,
    String description,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف حركة المخزون: $description ؟',
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
      await FirebaseFirestore.instance
          .collection('inventory_transactions')
          .doc(documentId)
          .delete();
    }
  }

  Color _typeColor(String type) {
    if (type == 'add') return Colors.green;
    if (type == 'issue') return Colors.red;
    return Colors.grey;
  }

  IconData _typeIcon(String type) {
    if (type == 'add') return Icons.add_circle;
    if (type == 'issue') return Icons.remove_circle;
    return Icons.inventory;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
       appBar: AppBar(
          title: const Text('حركات المخزون'),
          actions: [
            IconButton(
              tooltip: 'تقرير كارت صنف',
              icon: const Icon(Icons.receipt_long),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ItemCardReportScreen(),
                  ),
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(195),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'بحث بالصنف أو البيان أو نوع الحركة',
                      prefixIcon: Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        transactionSearchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: transactionTypeFilter,
                    decoration: const InputDecoration(
                      labelText: 'نوع الحركة',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'الكل',
                        child: Text('كل الحركات'),
                      ),
                      DropdownMenuItem(
                        value: 'إضافة',
                        child: Text('إضافة فقط'),
                      ),
                      DropdownMenuItem(
                        value: 'صرف',
                        child: Text('صرف فقط'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        transactionTypeFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: fromDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (pickedDate != null && mounted) {
                              setState(() {
                                fromDate = pickedDate;
                              });
                            }
                          },
                          child: Text(
                            fromDate == null
                                ? 'من تاريخ'
                                : '${fromDate!.year}-${fromDate!.month}-${fromDate!.day}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: toDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );

                            if (pickedDate != null && mounted) {
                              setState(() {
                                toDate = pickedDate;
                              });
                            }
                          },
                          child: Text(
                            toDate == null
                                ? 'إلى تاريخ'
                                : '${toDate!.year}-${toDate!.month}-${toDate!.day}',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            fromDate = null;
                            toDate = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addInventoryTransaction(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('inventory_transactions')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل حركات المخزون'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data!.docs;

            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              final itemCode = (data['itemCode'] ?? '').toString().toLowerCase();
              final itemName = (data['itemName'] ?? '').toString().toLowerCase();
              final description = (data['description'] ?? '').toString().toLowerCase();
              final typeName = (data['typeName'] ?? '').toString().toLowerCase();
              final dateValue = data['date'];

              DateTime? transactionDate;

              if (dateValue is Timestamp) {
                transactionDate = dateValue.toDate();
              }
              final matchesSearch = itemCode.contains(transactionSearchQuery) ||
                  itemName.contains(transactionSearchQuery) ||
                  description.contains(transactionSearchQuery) ||
                  typeName.contains(transactionSearchQuery);

              final matchesType = transactionTypeFilter == 'الكل' ||
                  typeName == transactionTypeFilter;

              final matchesFromDate = fromDate == null ||
    (transactionDate != null &&
        !transactionDate.isBefore(
          DateTime(fromDate!.year, fromDate!.month, fromDate!.day),
        ));

              final matchesToDate = toDate == null ||
                  (transactionDate != null &&
                      !transactionDate.isAfter(
                        DateTime(
                          toDate!.year,
                          toDate!.month,
                          toDate!.day,
                          23,
                          59,
                          59,
                        ),
                      ));

              return matchesSearch && matchesType && matchesFromDate && matchesToDate;
            }).toList();

            if (docs.isEmpty) {
              return const Center(
                child: Text('لا توجد حركات مخزون حتى الآن'),
              );
            }
            if (filteredDocs.isEmpty) {
              return const Center(
                child: Text('لا توجد نتائج مطابقة للبحث'),
              );
            }

            return ListView.builder(
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final data = filteredDocs[index].data() as Map<String, dynamic>;
                final documentId = filteredDocs[index].id;

                final type = (data['type'] ?? '').toString();
                final typeName = (data['typeName'] ?? '').toString();
                final itemCode = data['itemCode'] ?? '';
                final itemName = data['itemName'] ?? '';
                final unit = data['unit'] ?? '';
                final quantity = data['quantity'] ?? 0;
                final description = data['description'] ?? '';
                final date = data['date'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(
                      _typeIcon(type),
                      color: _typeColor(type),
                    ),
                    title: Text(
                      '$typeName - $itemCode - $itemName',
                    ),
                    subtitle: Text(
                      'التاريخ: ${_formatDate(date)}\n'
                      'الكمية: $quantity $unit\n'
                      'البيان: $description',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _editInventoryTransaction(
                              context,
                              documentId,
                              data,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteInventoryTransaction(
                              context,
                              documentId,
                              description.toString(),
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