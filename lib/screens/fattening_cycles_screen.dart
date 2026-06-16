import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FatteningCyclesScreen extends StatefulWidget {
  const FatteningCyclesScreen({super.key});

  @override
  State<FatteningCyclesScreen> createState() => _FatteningCyclesScreenState();
}

class _FatteningCyclesScreenState extends State<FatteningCyclesScreen> {
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  Color _statusColor(String status) {
    if (status == 'نشطة') return Colors.green;
    if (status == 'مغلقة') return Colors.red;

    return Colors.grey;
  }

  IconData _statusIcon(String status) {
    if (status == 'نشطة') return Icons.play_circle;
    if (status == 'مغلقة') return Icons.stop_circle;

    return Icons.circle;
  }

  Future<void> _addCycle(BuildContext context) async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final chicksCountController = TextEditingController();
    final breedController = TextEditingController();
    final notesController = TextEditingController();

    DateTime startDate = DateTime.now();
    String status = 'نشطة';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة دورة تسمين'),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تاريخ البداية: ${startDate.year}-${startDate.month}-${startDate.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate != null) {
                                setState(() {
                                  startDate = pickedDate;
                                });
                              }
                            },
                            child: const Text('اختيار التاريخ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'كود الدورة',
                          hintText: 'مثال: C001',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الدورة',
                          hintText: 'مثال: دورة يونيو 2026',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: chicksCountController,
                        decoration: const InputDecoration(
                          labelText: 'عدد الكتاكيت',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: breedController,
                        decoration: const InputDecoration(
                          labelText: 'السلالة',
                          hintText: 'مثال: أبيض / روز / ساسو',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'حالة الدورة',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'نشطة',
                            child: Text('نشطة'),
                          ),
                          DropdownMenuItem(
                            value: 'مغلقة',
                            child: Text('مغلقة'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            status = value;
                          });
                        },
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
                    final code = codeController.text.trim();
                    final name = nameController.text.trim();
                    final chicksCount = int.tryParse(
                          chicksCountController.text.trim(),
                        ) ??
                        0;
                    final breed = breedController.text.trim();
                    final notes = notesController.text.trim();

                    if (code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال كود الدورة'),
                        ),
                      );
                      return;
                    }

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال اسم الدورة'),
                        ),
                      );
                      return;
                    }

                    if (chicksCount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال عدد كتاكيت صحيح'),
                        ),
                      );
                      return;
                    }

                    final existingCycle = await FirebaseFirestore.instance
                        .collection('fattening_cycles')
                        .where(
                          'code',
                          isEqualTo: code,
                        )
                        .get();

                    if (!context.mounted) return;

                    if (existingCycle.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('كود الدورة موجود بالفعل'),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('fattening_cycles')
                        .add({
                      'code': code,
                      'name': name,
                      'startDate': Timestamp.fromDate(startDate),
                      'chicksCount': chicksCount,
                      'breed': breed,
                      'status': status,
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

  Future<void> _editCycle(
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

    final chicksCountController = TextEditingController(
      text: (data['chicksCount'] ?? 0).toString(),
    );

    final breedController = TextEditingController(
      text: (data['breed'] ?? '').toString(),
    );

    final notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    final oldCode = (data['code'] ?? '').toString();

    DateTime startDate = DateTime.now();
    String status = (data['status'] ?? 'نشطة').toString();

    final currentDate = data['startDate'];

    if (currentDate is Timestamp) {
      startDate = currentDate.toDate();
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تعديل دورة تسمين'),
              content: SizedBox(
                width: 550,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تاريخ البداية: ${startDate.year}-${startDate.month}-${startDate.day}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate != null) {
                                setState(() {
                                  startDate = pickedDate;
                                });
                              }
                            },
                            child: const Text('اختيار التاريخ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'كود الدورة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الدورة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: chicksCountController,
                        decoration: const InputDecoration(
                          labelText: 'عدد الكتاكيت',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: breedController,
                        decoration: const InputDecoration(
                          labelText: 'السلالة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(
                          labelText: 'حالة الدورة',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'نشطة',
                            child: Text('نشطة'),
                          ),
                          DropdownMenuItem(
                            value: 'مغلقة',
                            child: Text('مغلقة'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            status = value;
                          });
                        },
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
                    final newCode = codeController.text.trim();
                    final newName = nameController.text.trim();
                    final newChicksCount = int.tryParse(
                          chicksCountController.text.trim(),
                        ) ??
                        0;
                    final newBreed = breedController.text.trim();
                    final newNotes = notesController.text.trim();

                    if (newCode.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال كود الدورة'),
                        ),
                      );
                      return;
                    }

                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال اسم الدورة'),
                        ),
                      );
                      return;
                    }

                    if (newChicksCount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال عدد كتاكيت صحيح'),
                        ),
                      );
                      return;
                    }

                    if (newCode != oldCode) {
                      final existingCycle = await FirebaseFirestore.instance
                          .collection('fattening_cycles')
                          .where(
                            'code',
                            isEqualTo: newCode,
                          )
                          .get();

                      if (!context.mounted) return;

                      if (existingCycle.docs.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('كود الدورة موجود بالفعل'),
                          ),
                        );
                        return;
                      }
                    }

                    await FirebaseFirestore.instance
                        .collection('fattening_cycles')
                        .doc(documentId)
                        .update({
                      'code': newCode,
                      'name': newName,
                      'startDate': Timestamp.fromDate(startDate),
                      'chicksCount': newChicksCount,
                      'breed': newBreed,
                      'status': status,
                      'notes': newNotes,
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

  Future<void> _deleteCycle(
    BuildContext context,
    String documentId,
    String name,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: Text('هل تريد حذف الدورة: $name ؟'),
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
          .collection('fattening_cycles')
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
          title: const Text('دورات التسمين'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addCycle(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('fattening_cycles')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل دورات التسمين'),
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
                child: Text('لا توجد دورات تسمين حتى الآن'),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final documentId = docs[index].id;

                final code = (data['code'] ?? '').toString();
                final name = (data['name'] ?? '').toString();
                final startDate = data['startDate'] as Timestamp?;
                final chicksCount = data['chicksCount'] ?? 0;
                final breed = (data['breed'] ?? '').toString();
                final status = (data['status'] ?? '').toString();
                final notes = (data['notes'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(
                      _statusIcon(status),
                      color: _statusColor(status),
                    ),
                    title: Text(
                      '$code - $name',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'تاريخ البداية: ${_formatDate(startDate)}\n'
                      'عدد الكتاكيت: $chicksCount\n'
                      'السلالة: $breed\n'
                      'الحالة: $status\n'
                      'ملاحظات: $notes',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _editCycle(
                              context,
                              documentId,
                              data,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteCycle(
                              context,
                              documentId,
                              name,
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