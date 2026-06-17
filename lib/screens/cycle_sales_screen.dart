import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CycleSalesScreen extends StatefulWidget {
  const CycleSalesScreen({super.key});

  @override
  State<CycleSalesScreen> createState() => _CycleSalesScreenState();
}

class _CycleSalesScreenState extends State<CycleSalesScreen> {
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

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Future<List<Map<String, dynamic>>> _loadCycles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
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

    Future<void> _addSale(BuildContext context) async {
    final birdsSoldController = TextEditingController();
    final totalWeightController = TextEditingController();
    final pricePerKgController = TextEditingController();
    final notesController = TextEditingController();

    DateTime selectedDate = DateTime.now();

    String? selectedCycleId;
    String selectedCycleCode = '';
    String selectedCycleName = '';

    final cycles = await _loadCycles();

    if (!context.mounted) return;

    if (cycles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد دورات تسمين لإضافة مبيعات'),
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
              title: const Text('إضافة مبيعات دورة'),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تاريخ البيع: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
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
                      TextField(
                        controller: birdsSoldController,
                        decoration: const InputDecoration(
                          labelText: 'عدد الطيور المباعة',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: totalWeightController,
                        decoration: const InputDecoration(
                          labelText: 'الوزن الكلي بالكيلو',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pricePerKgController,
                        decoration: const InputDecoration(
                          labelText: 'سعر الكيلو',
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
                    final birdsSold = int.tryParse(
                          birdsSoldController.text.trim(),
                        ) ??
                        0;

                    final totalWeight = double.tryParse(
                          totalWeightController.text.trim(),
                        ) ??
                        0;

                    final pricePerKg = double.tryParse(
                          pricePerKgController.text.trim(),
                        ) ??
                        0;

                    final totalAmount = totalWeight * pricePerKg;

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

                    if (birdsSold <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب إدخال عدد طيور مباعة أكبر من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    if (totalWeight <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب إدخال وزن كلي أكبر من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    if (pricePerKg <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب إدخال سعر كيلو أكبر من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('cycle_sales')
                        .add({
                      'cycleId': selectedCycleId,
                      'cycleCode': selectedCycleCode,
                      'cycleName': selectedCycleName,
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'birdsSold': birdsSold,
                      'totalWeight': totalWeight,
                      'pricePerKg': pricePerKg,
                      'totalAmount': totalAmount,
                      'notes': notes,
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

    Future<void> _editSale(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final birdsSoldController = TextEditingController(
      text: (data['birdsSold'] ?? 0).toString(),
    );

    final totalWeightController = TextEditingController(
      text: (data['totalWeight'] ?? 0).toString(),
    );

    final pricePerKgController = TextEditingController(
      text: (data['pricePerKg'] ?? 0).toString(),
    );

    final notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    DateTime selectedDate =
        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    final cycleCode = (data['cycleCode'] ?? '').toString();
    final cycleName = (data['cycleName'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تعديل مبيعات دورة'),
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
                              'تاريخ البيع: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
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
                        controller: birdsSoldController,
                        decoration: const InputDecoration(
                          labelText: 'عدد الطيور المباعة',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: totalWeightController,
                        decoration: const InputDecoration(
                          labelText: 'الوزن الكلي بالكيلو',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pricePerKgController,
                        decoration: const InputDecoration(
                          labelText: 'سعر الكيلو',
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
                    final birdsSold = int.tryParse(
                          birdsSoldController.text.trim(),
                        ) ??
                        0;

                    final totalWeight = double.tryParse(
                          totalWeightController.text.trim(),
                        ) ??
                        0;

                    final pricePerKg = double.tryParse(
                          pricePerKgController.text.trim(),
                        ) ??
                        0;

                    final totalAmount = totalWeight * pricePerKg;

                    final notes = notesController.text.trim();
                    final dateKey = _dateKey(selectedDate);

                    if (birdsSold <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب إدخال عدد طيور مباعة أكبر من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    if (totalWeight <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب إدخال وزن كلي أكبر من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    if (pricePerKg <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'يجب إدخال سعر كيلو أكبر من صفر',
                          ),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('cycle_sales')
                        .doc(documentId)
                        .update({
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'birdsSold': birdsSold,
                      'totalWeight': totalWeight,
                      'pricePerKg': pricePerKg,
                      'totalAmount': totalAmount,
                      'notes': notes,
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
      },
    );
  }

  Future<void> _deleteSale(
    BuildContext context,
    String documentId,
    String cycleName,
    String date,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text(
            'هل تريد حذف مبيعات $cycleName بتاريخ $date ؟',
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
          .collection('cycle_sales')
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
          title: const Text('مبيعات الدورة'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addSale(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cycle_sales')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل مبيعات الدورة'),
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
                child: Text('لا توجد مبيعات مسجلة حتى الآن'),
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

                final birdsSold = data['birdsSold'] ?? 0;

                final totalWeight = double.tryParse(
                      (data['totalWeight'] ?? 0).toString(),
                    ) ??
                    0;

                final pricePerKg = double.tryParse(
                      (data['pricePerKg'] ?? 0).toString(),
                    ) ??
                    0;

                final totalAmount = double.tryParse(
                      (data['totalAmount'] ?? 0).toString(),
                    ) ??
                    0;

                final notes = (data['notes'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.monetization_on,
                      color: Colors.green,
                    ),
                    title: Text(
                      '$cycleCode - $cycleName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'تاريخ البيع: ${_formatDate(date)}\n'
                      'عدد الطيور المباعة: $birdsSold\n'
                      'الوزن الكلي: ${_formatNumber(totalWeight)} كجم\n'
                      'سعر الكيلو: ${_formatNumber(pricePerKg)}\n'
                      'إجمالي البيع: ${_formatNumber(totalAmount)}\n'
                      'ملاحظات: $notes',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _editSale(
                              context,
                              documentId,
                              data,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteSale(
                              context,
                              documentId,
                              cycleName,
                              _formatDate(date),
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