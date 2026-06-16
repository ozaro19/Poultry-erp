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

    Future<void> _addDailyFollowup(BuildContext context) async {
    final mortalityController = TextEditingController(text: '0');
    final feedQtyController = TextEditingController(text: '0');
    final averageWeightController = TextEditingController(text: '0');
    final notesController = TextEditingController();

    DateTime selectedDate = DateTime.now();

    String? selectedCycleId;
    String selectedCycleCode = '';
    String selectedCycleName = '';

    final cycles = await _loadActiveCycles();

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

                    await FirebaseFirestore.instance
                        .collection('cycle_daily_followups')
                        .add({
                      'cycleId': selectedCycleId,
                      'cycleCode': selectedCycleCode,
                      'cycleName': selectedCycleName,
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'mortality': mortality,
                      'feedQty': feedQty,
                      'averageWeight': averageWeight,
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

    Future<void> _deleteFollowup(
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
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteFollowup(
                          context,
                          documentId,
                          cycleName,
                          _formatDate(date),
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

