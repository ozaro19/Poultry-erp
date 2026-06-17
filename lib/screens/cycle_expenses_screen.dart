import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CycleExpensesScreen extends StatefulWidget {
  const CycleExpensesScreen({super.key});

  @override
  State<CycleExpensesScreen> createState() => _CycleExpensesScreenState();
}

class _CycleExpensesScreenState extends State<CycleExpensesScreen> {
  final List<String> _categories = const [
    'أدوية',
    'تحصينات',
    'عمالة',
    'كهرباء',
    'فرشة',
    'نقل',
    'مصروفات أخرى',
  ];

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
  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chart_of_accounts')
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

  Future<String> _generateEntryNo() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('journal_entries');

    final counterSnapshot = await counterRef.get();

    int lastNumber = 0;

    if (counterSnapshot.exists) {
      final counterData = counterSnapshot.data();
      lastNumber = counterData?['lastNumber'] ?? 0;
    }

    final nextNumber = lastNumber + 1;

    await counterRef.set({
      'lastNumber': nextNumber,
    }, SetOptions(merge: true));

    return 'JE-${nextNumber.toString().padLeft(4, '0')}';
  }

    Future<void> _addExpense(BuildContext context) async {
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    DateTime selectedDate = DateTime.now();

    String selectedCategory = _categories.first;

    String? selectedCycleId;
    String selectedCycleCode = '';
    String selectedCycleName = '';

    String? selectedExpenseAccountCode;
    String selectedExpenseAccountName = '';

    String? selectedCashAccountCode;
    String selectedCashAccountName = '';

    final cycles = await _loadCycles();
    final accounts = await _loadAccounts();

    if (!context.mounted) return;

    if (cycles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد دورات تسمين لإضافة مصروف'),
        ),
      );
      return;
    }
    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد حسابات. أضف شجرة الحسابات أولًا'),
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
              title: const Text('إضافة مصروف دورة'),
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
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'نوع المصروف',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedExpenseAccountCode,
                        decoration: const InputDecoration(
                          labelText: 'حساب المصروف',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts.map((account) {
                          final code = (account['code'] ?? '').toString();

                          final name = (account['nameAr'] ??
                                  account['name'] ??
                                  account['nameEn'] ??
                                  '')
                              .toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $name'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedAccount = accounts.firstWhere(
                            (account) => account['code'].toString() == value,
                          );

                          setState(() {
                            selectedExpenseAccountCode = value;
                            selectedExpenseAccountName =
                                (selectedAccount['nameAr'] ??
                                        selectedAccount['name'] ??
                                        selectedAccount['nameEn'] ??
                                        '')
                                    .toString();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCashAccountCode,
                        decoration: const InputDecoration(
                          labelText: 'حساب الخزينة',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts.map((account) {
                          final code = (account['code'] ?? '').toString();

                          final name = (account['nameAr'] ??
                                  account['name'] ??
                                  account['nameEn'] ??
                                  '')
                              .toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $name'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedAccount = accounts.firstWhere(
                            (account) => account['code'].toString() == value,
                          );

                          setState(() {
                            selectedCashAccountCode = value;
                            selectedCashAccountName =
                                (selectedAccount['nameAr'] ??
                                        selectedAccount['name'] ??
                                        selectedAccount['nameEn'] ??
                                        '')
                                    .toString();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
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
                    final amount = double.tryParse(
                          amountController.text.trim(),
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

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال مبلغ أكبر من صفر'),
                        ),
                      );
                      return;
                    }
                    if (selectedExpenseAccountCode == null ||
                        selectedExpenseAccountCode!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار حساب المصروف'),
                        ),
                      );
                      return;
                    }

                    if (selectedCashAccountCode == null ||
                        selectedCashAccountCode!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار حساب الخزينة'),
                        ),
                      );
                      return;
                    }

                    final expenseAccountCode = selectedExpenseAccountCode!;
                    final cashAccountCode = selectedCashAccountCode!;
                    final expenseRef = await FirebaseFirestore.instance
                        .collection('cycle_expenses')
                        .add({
                      'cycleId': selectedCycleId,
                      'cycleCode': selectedCycleCode,
                      'cycleName': selectedCycleName,
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'category': selectedCategory,
                      'amount': amount,
                      'expenseAccountCode': expenseAccountCode,
                      'expenseAccountName': selectedExpenseAccountName,
                      'cashAccountCode': cashAccountCode,
                      'cashAccountName': selectedCashAccountName,
                      'journalEntryId': '',
                      'notes': notes,
                      'createdAt': Timestamp.now(),
                    });

                    final entryNo = await _generateEntryNo();

                    final journalEntryRef = await FirebaseFirestore.instance
                        .collection('journal_entries')
                        .add({
                      'entryNo': entryNo,
                      'date': Timestamp.fromDate(selectedDate),
                      'description':
                          'مصروف دورة $selectedCycleCode - $selectedCycleName - $selectedCategory',
                      'lines': [
                        {
                          'accountCode': expenseAccountCode,
                          'accountName': selectedExpenseAccountName,
                          'debit': amount,
                          'credit': 0,
                        },
                        {
                          'accountCode': cashAccountCode,
                          'accountName': selectedCashAccountName,
                          'debit': 0,
                          'credit': amount,
                        },
                      ],
                      'totalDebit': amount,
                      'totalCredit': amount,
                      'source': 'cycle_expense',
                      'sourceId': expenseRef.id,
                      'cycleId': selectedCycleId,
                      'createdAt': Timestamp.now(),
                    });

                    await expenseRef.update({
                      'journalEntryId': journalEntryRef.id,
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

    Future<void> _editExpense(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final amountController = TextEditingController(
      text: (data['amount'] ?? 0).toString(),
    );

    final notesController = TextEditingController(
      text: (data['notes'] ?? '').toString(),
    );

    DateTime selectedDate =
        (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();

    String selectedCategory =
        (data['category'] ?? _categories.first).toString();

    if (!_categories.contains(selectedCategory)) {
      selectedCategory = _categories.first;
    }

    final cycleCode = (data['cycleCode'] ?? '').toString();
    final cycleName = (data['cycleName'] ?? '').toString();

    final journalEntryId =
        (data['journalEntryId'] ?? '').toString();

    final expenseAccountCode =
        (data['expenseAccountCode'] ?? '').toString();

    final expenseAccountName =
        (data['expenseAccountName'] ?? '').toString();

    final cashAccountCode =
        (data['cashAccountCode'] ?? '').toString();

    final cashAccountName =
        (data['cashAccountName'] ?? '').toString();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('تعديل مصروف دورة'),
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
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'نوع المصروف',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
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
                    final amount = double.tryParse(
                          amountController.text.trim(),
                        ) ??
                        0;

                    final notes = notesController.text.trim();
                    final dateKey = _dateKey(selectedDate);

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال مبلغ أكبر من صفر'),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('cycle_expenses')
                        .doc(documentId)
                        .update({
                      'date': Timestamp.fromDate(selectedDate),
                      'dateKey': dateKey,
                      'category': selectedCategory,
                      'amount': amount,
                      'notes': notes,
                      'updatedAt': Timestamp.now(),
                    });

                    if (journalEntryId.isNotEmpty &&
                        expenseAccountCode.isNotEmpty &&
                        cashAccountCode.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('journal_entries')
                          .doc(journalEntryId)
                          .update({
                        'date': Timestamp.fromDate(selectedDate),
                        'description':
                            'مصروف دورة $cycleCode - $cycleName - $selectedCategory',
                        'lines': [
                          {
                            'accountCode': expenseAccountCode,
                            'accountName': expenseAccountName,
                            'debit': amount,
                            'credit': 0,
                          },
                          {
                            'accountCode': cashAccountCode,
                            'accountName': cashAccountName,
                            'debit': 0,
                            'credit': amount,
                          },
                        ],
                        'totalDebit': amount,
                        'totalCredit': amount,
                        'updatedAt': Timestamp.now(),
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

  Future<void> _deleteExpense(
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
            'هل تريد حذف مصروف $cycleName بتاريخ $date ؟',
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
      final journalEntryId =
          (data['journalEntryId'] ?? '').toString();

      if (journalEntryId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('journal_entries')
            .doc(journalEntryId)
            .delete();
      }

      await FirebaseFirestore.instance
          .collection('cycle_expenses')
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
          title: const Text('مصروفات الدورة'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addExpense(context),
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cycle_expenses')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل مصروفات الدورة'),
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
                child: Text('لا توجد مصروفات مسجلة حتى الآن'),
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
                final category = (data['category'] ?? '').toString();

                final amount = double.tryParse(
                      (data['amount'] ?? 0).toString(),
                    ) ??
                    0;

                final notes = (data['notes'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.receipt_long,
                      color: Colors.deepOrange,
                    ),
                    title: Text(
                      '$cycleCode - $cycleName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'التاريخ: ${_formatDate(date)}\n'
                      'نوع المصروف: $category\n'
                      'المبلغ: ${_formatNumber(amount)}\n'
                      'ملاحظات: $notes',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _editExpense(
                              context,
                              documentId,
                              data,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteExpense(
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