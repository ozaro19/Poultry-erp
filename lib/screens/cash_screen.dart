import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  String? selectedCashAccountCode;
  String selectedCashAccountName = '';
  String cashSearchQuery = '';

  DateTime? fromDate;
  DateTime? toDate;

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
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

  Future<void> _addCashTransaction(BuildContext context) async {
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    DateTime selectedDate = DateTime.now();
    String transactionType = 'قبض';

    String? cashAccountCode = selectedCashAccountCode;
    String cashAccountName = selectedCashAccountName;

    String? otherAccountCode;
    String otherAccountName = '';

    final accounts = await _loadAccounts();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إضافة حركة خزينة'),
              content: SizedBox(
                width: 650,
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
                            value: 'قبض',
                            child: Text('قبض'),
                          ),
                          DropdownMenuItem(
                            value: 'صرف',
                            child: Text('صرف'),
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
                        initialValue: cashAccountCode,
                        decoration: const InputDecoration(
                          labelText: 'حساب الخزينة',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts.map((account) {
                          final code = account['code'].toString();
                          final nameAr = account['nameAr'].toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $nameAr'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedAccount = accounts.firstWhere(
                            (account) =>
                                account['code'].toString() == value,
                          );

                          setState(() {
                            cashAccountCode = value;
                            cashAccountName =
                                selectedAccount['nameAr'].toString();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: otherAccountCode,
                        decoration: const InputDecoration(
                          labelText: 'الحساب المقابل',
                          border: OutlineInputBorder(),
                        ),
                        items: accounts.map((account) {
                          final code = account['code'].toString();
                          final nameAr = account['nameAr'].toString();

                          return DropdownMenuItem(
                            value: code,
                            child: Text('$code - $nameAr'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          final selectedAccount = accounts.firstWhere(
                            (account) =>
                                account['code'].toString() == value,
                          );

                          setState(() {
                            otherAccountCode = value;
                            otherAccountName =
                                selectedAccount['nameAr'].toString();
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
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0;

                    final description = descriptionController.text.trim();

                    if (cashAccountCode == null ||
                        cashAccountCode!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار حساب الخزينة'),
                        ),
                      );
                      return;
                    }

                    if (otherAccountCode == null ||
                        otherAccountCode!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب اختيار الحساب المقابل'),
                        ),
                      );
                      return;
                    }

                    if (cashAccountCode == otherAccountCode) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لا يمكن أن يكون حساب الخزينة هو نفس الحساب المقابل',
                          ),
                        ),
                      );
                      return;
                    }

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال مبلغ صحيح'),
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

                    final entryNo = await _generateEntryNo();

                    final lines = transactionType == 'قبض'
                        ? [
                            {
                              'accountCode': cashAccountCode,
                              'accountName': cashAccountName,
                              'debit': amount,
                              'credit': 0,
                            },
                            {
                              'accountCode': otherAccountCode,
                              'accountName': otherAccountName,
                              'debit': 0,
                              'credit': amount,
                            },
                          ]
                        : [
                            {
                              'accountCode': otherAccountCode,
                              'accountName': otherAccountName,
                              'debit': amount,
                              'credit': 0,
                            },
                            {
                              'accountCode': cashAccountCode,
                              'accountName': cashAccountName,
                              'debit': 0,
                              'credit': amount,
                            },
                          ];

                    await FirebaseFirestore.instance
                        .collection('journal_entries')
                        .add({
                      'entryNo': entryNo,
                      'date': Timestamp.fromDate(selectedDate),
                      'description': '$transactionType خزينة - $description',
                      'lines': lines,
                      'totalDebit': amount,
                      'totalCredit': amount,
                      'isBalanced': true,
                      'source': 'cash',
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
Future<void> _editCashTransaction(
  BuildContext context,
  String documentId,
) async {
  if (selectedCashAccountCode == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('يجب اختيار حساب الخزينة أولًا'),
      ),
    );
    return;
  }

  final entrySnapshot = await FirebaseFirestore.instance
      .collection('journal_entries')
      .doc(documentId)
      .get();

  if (!entrySnapshot.exists) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم يتم العثور على حركة الخزينة'),
        ),
      );
    }
    return;
  }

  final data = entrySnapshot.data() ?? {};

  if ((data['source'] ?? '').toString() != 'cash') {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن تعديل هذا القيد من شاشة الخزينة'),
        ),
      );
    }
    return;
  }

  final entryNo = data['entryNo'] ?? '';
  final oldDescription = (data['description'] ?? '').toString();
  DateTime selectedDate = DateTime.now();

final currentDate = data['date'];

if (currentDate is Timestamp) {
  selectedDate = currentDate.toDate();
}

  String transactionType =
    oldDescription.startsWith('صرف خزينة') ? 'صرف' : 'قبض';

  final descriptionController = TextEditingController(
    text: oldDescription
        .replaceFirst('قبض خزينة - ', '')
        .replaceFirst('صرف خزينة - ', ''),
  );

  String cashAccountCode = selectedCashAccountCode!;
  String cashAccountName = selectedCashAccountName;

  String? otherAccountCode;
  String otherAccountName = '';

  double amount = 0;

  final lines = (data['lines'] as List?) ?? [];

  for (final line in lines) {
    final item = line as Map<String, dynamic>;

    final accountCode = item['accountCode'].toString();
    final accountName = (item['accountName'] ?? '').toString();

    final debit = double.tryParse(item['debit'].toString()) ?? 0;
    final credit = double.tryParse(item['credit'].toString()) ?? 0;

    if (accountCode == cashAccountCode) {
      cashAccountName = accountName;
      amount = debit > 0 ? debit : credit;
    } else {
      otherAccountCode = accountCode;
      otherAccountName = accountName;
    }
  }

  final amountController = TextEditingController(
    text: amount.toString(),
  );

  final accounts = await _loadAccounts();

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('تعديل حركة خزينة $entryNo'),
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
                      value: 'قبض',
                      child: Text('قبض'),
                    ),
                    DropdownMenuItem(
                      value: 'صرف',
                      child: Text('صرف'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      transactionType = value;
                    });
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
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: const Text('تعديل التاريخ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'حساب الخزينة: $cashAccountCode - $cashAccountName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: otherAccountCode,
                  decoration: const InputDecoration(
                    labelText: 'الحساب المقابل',
                    border: OutlineInputBorder(),
                  ),
                  items: accounts.map((account) {
                    final code = account['code'].toString();
                    final nameAr = account['nameAr'].toString();

                    return DropdownMenuItem(
                      value: code,
                      child: Text('$code - $nameAr'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    final selectedAccount = accounts.firstWhere(
                      (account) => account['code'].toString() == value,
                    );

                    setState(() {
                      otherAccountCode = value;
                      otherAccountName = selectedAccount['nameAr'].toString();
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
              final newAmount =
                  double.tryParse(amountController.text.trim()) ?? 0;

              final newDescription =
                  descriptionController.text.trim();

              if ((otherAccountCode ?? '').isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الحساب المقابل غير موجود'),
                  ),
                );
                return;
              }

              if (newAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يجب إدخال مبلغ صحيح'),
                  ),
                );
                return;
              }

              if (newDescription.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يجب إدخال البيان'),
                  ),
                );
                return;
              }

              final newLines = transactionType == 'قبض'
                  ? [
                      {
                        'accountCode': cashAccountCode,
                        'accountName': cashAccountName,
                        'debit': newAmount,
                        'credit': 0,
                      },
                      {
                        'accountCode': otherAccountCode,
                        'accountName': otherAccountName,
                        'debit': 0,
                        'credit': newAmount,
                      },
                    ]
                  : [
                      {
                        'accountCode': otherAccountCode,
                        'accountName': otherAccountName,
                        'debit': newAmount,
                        'credit': 0,
                      },
                      {
                        'accountCode': cashAccountCode,
                        'accountName': cashAccountName,
                        'debit': 0,
                        'credit': newAmount,
                      },
                    ];

              await FirebaseFirestore.instance
                  .collection('journal_entries')
                  .doc(documentId)
                  .update({
                'date': Timestamp.fromDate(selectedDate),
                'description': '$transactionType خزينة - $newDescription',
                'lines': newLines,
                'totalDebit': newAmount,
                'totalCredit': newAmount,
                'isBalanced': true,
                'source': 'cash',
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

  Future<void> _deleteCashTransaction(
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
            'هل تريد حذف حركة الخزينة: $description ؟',
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
          .collection('journal_entries')
          .doc(documentId)
          .delete();
    }
  }

  List<Map<String, dynamic>> _extractCashRows(
    List<QueryDocumentSnapshot> docs,
    String accountCode,
  ) {
    final rows = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final lines = (data['lines'] as List?) ?? [];
      final source = (data['source'] ?? '').toString();

      for (final line in lines) {
        final item = line as Map<String, dynamic>;

        if (item['accountCode'].toString() == accountCode) {
          rows.add({
            'documentId': doc.id,
            'entryNo': data['entryNo'] ?? '',
            'date': data['date'],
            'description': data['description'] ?? '',
            'debit': item['debit'] ?? 0,
            'credit': item['credit'] ?? 0,
            'source': source,
          });
        }
      }
    }

    rows.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];

      if (dateA is Timestamp && dateB is Timestamp) {
        return dateA.toDate().compareTo(dateB.toDate());
      }

      return 0;
    });

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الخزينة'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addCashTransaction(context),
          child: const Icon(Icons.add),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadAccounts(),
            builder: (context, accountsSnapshot) {
              if (accountsSnapshot.hasError) {
                return const Center(
                  child: Text('حدث خطأ أثناء تحميل الحسابات'),
                );
              }

              if (!accountsSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final accounts = accountsSnapshot.data!;

              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedCashAccountCode,
                    decoration: const InputDecoration(
                      labelText: 'اختر حساب الخزينة',
                      border: OutlineInputBorder(),
                    ),
                    items: accounts.map((account) {
                      final code = account['code'].toString();
                      final nameAr = account['nameAr'].toString();

                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code - $nameAr'),
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
                            selectedAccount['nameAr'].toString();
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (selectedCashAccountCode == null)
                    const Expanded(
                      child: Center(
                        child: Text('اختاري حساب الخزينة لعرض الحركات'),
                      ),
                    )
                  else
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('journal_entries')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('حدث خطأ أثناء تحميل الحركات'),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          final rows = _extractCashRows(
                            docs,
                            selectedCashAccountCode!,
                          );
                          final filteredRows = rows.where((row) {
                            final entryNo = row['entryNo'].toString().toLowerCase();
                            final description = row['description'].toString().toLowerCase();

                            final matchesSearch = entryNo.contains(cashSearchQuery) ||
                                description.contains(cashSearchQuery);

                            final rowDateValue = row['date'];

                            bool matchesDate = true;

                            if (rowDateValue is Timestamp) {
                              final rowDate = rowDateValue.toDate();

                              final rowDateOnly = DateTime(
                                rowDate.year,
                                rowDate.month,
                                rowDate.day,
                              );

                              if (fromDate != null) {
                                final fromDateOnly = DateTime(
                                  fromDate!.year,
                                  fromDate!.month,
                                  fromDate!.day,
                                );

                                if (rowDateOnly.isBefore(fromDateOnly)) {
                                  matchesDate = false;
                                }
                              }

                              if (toDate != null) {
                                final toDateOnly = DateTime(
                                  toDate!.year,
                                  toDate!.month,
                                  toDate!.day,
                                );

                                if (rowDateOnly.isAfter(toDateOnly)) {
                                  matchesDate = false;
                                }
                              }
                            }

                            return matchesSearch && matchesDate;
                          }).toList();

                          double totalDebit = 0;
                          double totalCredit = 0;
                          double balance = 0;

                          for (final row in filteredRows) {
                            final debit = double.tryParse(
                                  row['debit'].toString(),
                                ) ??
                                0;

                            final credit = double.tryParse(
                                  row['credit'].toString(),
                                ) ??
                                0;

                            totalDebit += debit;
                            totalCredit += credit;
                            balance += debit - credit;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'الحساب: $selectedCashAccountCode - $selectedCashAccountName',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text('إجمالي القبض: $totalDebit'),
                                      Text('إجمالي الصرف: $totalCredit'),
                                      Text(
                                        'الرصيد الحالي: $balance',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextField(
                                decoration: const InputDecoration(
                                  labelText: 'بحث برقم القيد أو البيان',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    cashSearchQuery = value.trim().toLowerCase();
                                  });
                                },
                              ),

                              const SizedBox(height: 12),
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

                                        if (pickedDate != null) {
                                          setState(() {
                                            fromDate = pickedDate;
                                          });
                                        }
                                      },
                                      child: Text(
                                        fromDate == null
                                            ? 'من تاريخ'
                                            : 'من: ${fromDate!.year}-${fromDate!.month}-${fromDate!.day}',
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

                                        if (pickedDate != null) {
                                          setState(() {
                                            toDate = pickedDate;
                                          });
                                        }
                                      },
                                      child: Text(
                                        toDate == null
                                            ? 'إلى تاريخ'
                                            : 'إلى: ${toDate!.year}-${toDate!.month}-${toDate!.day}',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        fromDate = null;
                                        toDate = null;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              if (filteredRows.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'لا توجد حركات على هذا الحساب',
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(
                                            label: Text('التاريخ'),
                                          ),
                                          DataColumn(
                                            label: Text('رقم القيد'),
                                          ),
                                          DataColumn(
                                            label: Text('البيان'),
                                          ),
                                          DataColumn(
                                            label: Text('قبض'),
                                            numeric: true,
                                          ),
                                          DataColumn(
                                            label: Text('صرف'),
                                            numeric: true,
                                          ),
                                          DataColumn(
                                            label: Text('تعديل'),
                                          ),
                                          DataColumn(
                                            label: Text('حذف'),
                                          ),
                                        ],
                                        rows: filteredRows.map((row) {
                                          final isCashSource =
                                              row['source'].toString() ==
                                                  'cash';

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  _formatDate(
                                                    row['date'] as Timestamp?,
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  row['entryNo'].toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  row['description']
                                                      .toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  row['debit'].toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  row['credit'].toString(),
                                                ),
                                              ),
                                             DataCell(
                                                isCashSource
                                                    ? IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                        ),
                                                        onPressed: () {
                                                          _editCashTransaction(
                                                            context,
                                                            row['documentId'].toString(),
                                                          );
                                                        },
                                                      )
                                                    : const Text('-'),
                                              ),
                                              DataCell(
                                                isCashSource
                                                    ? IconButton(
                                                        icon: const Icon(
                                                          Icons.delete,
                                                        ),
                                                        onPressed: () {
                                                          _deleteCashTransaction(
                                                            context,
                                                            row['documentId']
                                                                .toString(),
                                                            row['description']
                                                                .toString(),
                                                          );
                                                        },
                                                      )
                                                    : const Text('-'),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}