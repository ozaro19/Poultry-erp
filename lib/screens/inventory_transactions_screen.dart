import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryTransactionsScreen extends StatelessWidget {
  const InventoryTransactionsScreen({super.key});

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

  Future<void> _addInventoryTransaction(BuildContext context) async {
    final quantityController = TextEditingController();
    final descriptionController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    String transactionType = 'إضافة';

    String? selectedItemCode;
    String selectedItemName = '';
    String selectedItemUnit = '';

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
                            selectedItemName =
                                selectedItem['name'].toString();
                            selectedItemUnit =
                                selectedItem['unit'].toString();
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

            if (docs.isEmpty) {
              return const Center(
                child: Text('لا توجد حركات مخزون حتى الآن'),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final documentId = docs[index].id;

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
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteInventoryTransaction(
                          context,
                          documentId,
                          description.toString(),
                        );
                      },
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