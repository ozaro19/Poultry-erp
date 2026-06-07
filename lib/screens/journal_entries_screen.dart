import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntriesScreen extends StatelessWidget {
  const JournalEntriesScreen({super.key});

  Future<List<Map<String, dynamic>>> _loadAccounts() async {
    final accountsSnapshot = await FirebaseFirestore.instance
        .collection('chart_of_accounts')
        .orderBy('code')
        .get();

    return accountsSnapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  Map<String, dynamic> _createEmptyLine() {
    return {
      'accountCode': '',
      'accountName': '',
      'debitController': TextEditingController(text: '0'),
      'creditController': TextEditingController(text: '0'),
    };
  }

  double _calculateTotalDebit(List<Map<String, dynamic>> lines) {
    double total = 0;

    for (final line in lines) {
      final debitController = line['debitController'] as TextEditingController;
      total += double.tryParse(debitController.text.trim()) ?? 0;
    }

    return total;
  }

  double _calculateTotalCredit(List<Map<String, dynamic>> lines) {
    double total = 0;

    for (final line in lines) {
      final creditController =
          line['creditController'] as TextEditingController;
      total += double.tryParse(creditController.text.trim()) ?? 0;
    }

    return total;
  }

  Future<void> _addJournalEntry(BuildContext context) async {
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final accounts = await _loadAccounts();

    final lines = <Map<String, dynamic>>[
      _createEmptyLine(),
      _createEmptyLine(),
    ];

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final totalDebit = _calculateTotalDebit(lines);
            final totalCredit = _calculateTotalCredit(lines);
            final isBalanced = totalDebit == totalCredit;

            return AlertDialog(
              title: const Text('إضافة قيد يومية'),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تاريخ القيد: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
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
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'وصف القيد',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...lines.asMap().entries.map((entry) {
                        final index = entry.key;
                        final line = entry.value;

                        final debitController =
                            line['debitController'] as TextEditingController;
                        final creditController =
                            line['creditController'] as TextEditingController;

                        final selectedAccountCode =
                            line['accountCode'].toString().isEmpty
                                ? null
                                : line['accountCode'].toString();

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'سطر ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: lines.length <= 2
                                          ? null
                                          : () {
                                              setState(() {
                                                lines.removeAt(index);
                                              });
                                            },
                                    ),
                                  ],
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedAccountCode,
                                  decoration: const InputDecoration(
                                    labelText: 'الحساب',
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
                                      line['accountCode'] = value;
                                      line['accountName'] =
                                          selectedAccount['nameAr'].toString();
                                    });
                                  },
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: debitController,
                                        decoration: const InputDecoration(
                                          labelText: 'مدين',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: creditController,
                                        decoration: const InputDecoration(
                                          labelText: 'دائن',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            lines.add(_createEmptyLine());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة سطر'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'إجمالي المدين: $totalDebit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'إجمالي الدائن: $totalCredit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isBalanced ? 'القيد متوازن' : 'القيد غير متوازن',
                        style: TextStyle(
                          color: isBalanced ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
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
                    final description = descriptionController.text.trim();

                    if (description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال وصف القيد'),
                        ),
                      );
                      return;
                    }

                    final savedLines = <Map<String, dynamic>>[];

                    double finalTotalDebit = 0;
                    double finalTotalCredit = 0;

                    for (final line in lines) {
                      final accountCode =
                          line['accountCode'].toString().trim();
                      final accountName =
                          line['accountName'].toString().trim();

                      final debitController =
                          line['debitController'] as TextEditingController;
                      final creditController =
                          line['creditController'] as TextEditingController;

                      final debit =
                          double.tryParse(debitController.text.trim()) ?? 0;
                      final credit =
                          double.tryParse(creditController.text.trim()) ?? 0;

                      if (accountCode.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يجب اختيار حساب لكل سطر'),
                          ),
                        );
                        return;
                      }

                      if (debit == 0 && credit == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'كل سطر يجب أن يحتوي على مدين أو دائن',
                            ),
                          ),
                        );
                        return;
                      }

                      savedLines.add({
                        'accountCode': accountCode,
                        'accountName': accountName,
                        'debit': debit,
                        'credit': credit,
                      });

                      finalTotalDebit += debit;
                      finalTotalCredit += credit;
                    }

                    if (finalTotalDebit != finalTotalCredit) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لا يمكن حفظ قيد غير متوازن',
                          ),
                        ),
                      );
                      return;
                    }

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

                    final entryNo =
                        'JE-${nextNumber.toString().padLeft(4, '0')}';

                    await FirebaseFirestore.instance
                        .collection('journal_entries')
                        .add({
                      'entryNo': entryNo,
                      'date': Timestamp.fromDate(selectedDate),
                      'description': description,
                      'lines': savedLines,
                      'totalDebit': finalTotalDebit,
                      'totalCredit': finalTotalCredit,
                      'isBalanced': finalTotalDebit == finalTotalCredit,
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  Future<void> _deleteJournalEntry(
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
            'هل تريد حذف القيد: $description ؟',
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

  Future<void> _editJournalEntryFull(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );

    DateTime selectedDate = DateTime.now();

    final currentDate = data['date'];

    if (currentDate is Timestamp) {
      selectedDate = currentDate.toDate();
    }

    final accounts = await _loadAccounts();

    final oldLines = (data['lines'] as List?) ?? [];

    final lines = <Map<String, dynamic>>[];

    for (final oldLine in oldLines) {
      final line = oldLine as Map<String, dynamic>;

      lines.add({
        'accountCode': line['accountCode']?.toString() ?? '',
        'accountName': line['accountName']?.toString() ?? '',
        'debitController': TextEditingController(
          text: (line['debit'] ?? 0).toString(),
        ),
        'creditController': TextEditingController(
          text: (line['credit'] ?? 0).toString(),
        ),
      });
    }

    if (lines.length < 2) {
      while (lines.length < 2) {
        lines.add(_createEmptyLine());
      }
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final totalDebit = _calculateTotalDebit(lines);
            final totalCredit = _calculateTotalCredit(lines);
            final isBalanced = totalDebit == totalCredit;

            return AlertDialog(
              title: Text(
                data['entryNo'] == null || data['entryNo'].toString().isEmpty
                    ? 'تعديل القيد'
                    : 'تعديل القيد ${data['entryNo']}',
              ),
              content: SizedBox(
                width: 700,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'تاريخ القيد: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
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
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'وصف القيد',
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...lines.asMap().entries.map((entry) {
                        final index = entry.key;
                        final line = entry.value;

                        final debitController =
                            line['debitController'] as TextEditingController;
                        final creditController =
                            line['creditController'] as TextEditingController;

                        final selectedAccountCode =
                            line['accountCode'].toString().isEmpty
                                ? null
                                : line['accountCode'].toString();

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'سطر ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: lines.length <= 2
                                          ? null
                                          : () {
                                              setState(() {
                                                lines.removeAt(index);
                                              });
                                            },
                                    ),
                                  ],
                                ),
                                DropdownButtonFormField<String>(
                                  initialValue: selectedAccountCode,
                                  decoration: const InputDecoration(
                                    labelText: 'الحساب',
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
                                      line['accountCode'] = value;
                                      line['accountName'] = selectedAccount['nameAr'].toString();
                                    });
                                  },
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: debitController,
                                        decoration: const InputDecoration(
                                          labelText: 'مدين',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: creditController,
                                        decoration: const InputDecoration(
                                          labelText: 'دائن',
                                        ),
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) {
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            lines.add(_createEmptyLine());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة سطر'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'إجمالي المدين: $totalDebit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'إجمالي الدائن: $totalCredit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isBalanced ? 'القيد متوازن' : 'القيد غير متوازن',
                        style: TextStyle(
                          color: isBalanced ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
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
                    final description = descriptionController.text.trim();

                    if (description.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال وصف القيد'),
                        ),
                      );
                      return;
                    }

                    final savedLines = <Map<String, dynamic>>[];

                    double finalTotalDebit = 0;
                    double finalTotalCredit = 0;

                    for (final line in lines) {
                      final accountCode =
                          line['accountCode'].toString().trim();
                      final accountName =
                          line['accountName'].toString().trim();

                      final debitController =
                          line['debitController'] as TextEditingController;
                      final creditController =
                          line['creditController'] as TextEditingController;

                      final debit =
                          double.tryParse(debitController.text.trim()) ?? 0;
                      final credit =
                          double.tryParse(creditController.text.trim()) ?? 0;

                      if (accountCode.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يجب اختيار حساب لكل سطر'),
                          ),
                        );
                        return;
                      }

                      if (debit == 0 && credit == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'كل سطر يجب أن يحتوي على مدين أو دائن',
                            ),
                          ),
                        );
                        return;
                      }

                      savedLines.add({
                        'accountCode': accountCode,
                        'accountName': accountName,
                        'debit': debit,
                        'credit': credit,
                      });

                      finalTotalDebit += debit;
                      finalTotalCredit += credit;
                    }

                    if (finalTotalDebit != finalTotalCredit) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'لا يمكن حفظ قيد غير متوازن',
                          ),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection('journal_entries')
                        .doc(documentId)
                        .update({
                      'date': Timestamp.fromDate(selectedDate),
                      'description': description,
                      'lines': savedLines,
                      'totalDebit': finalTotalDebit,
                      'totalCredit': finalTotalCredit,
                      'isBalanced': finalTotalDebit == finalTotalCredit,
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

  void _showEntryDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final lines = (data['lines'] as List?) ?? [];
    final entryNo = data['entryNo'] ?? '';
    final description = data['description'] ?? 'تفاصيل القيد';
    final totalDebit = data['totalDebit'] ?? 0;
    final totalCredit = data['totalCredit'] ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            entryNo.toString().isEmpty
                ? description
                : '$entryNo - $description',
          ),
          content: SizedBox(
            width: 750,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (lines.isEmpty)
                    const Text('لا توجد تفاصيل لهذا القيد')
                  else
                    DataTable(
                      columns: const [
                        DataColumn(
                          label: Text('الحساب'),
                        ),
                        DataColumn(
                          label: Text('مدين'),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('دائن'),
                          numeric: true,
                        ),
                      ],
                      rows: lines.map((line) {
                        final item = line as Map<String, dynamic>;

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${item['accountCode']} - ${item['accountName']}',
                              ),
                            ),
                            DataCell(
                              Text(
                                item['debit'].toString(),
                              ),
                            ),
                            DataCell(
                              Text(
                                item['credit'].toString(),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    children: [
                      const Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'مدين: $totalDebit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'دائن: $totalCredit',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

   @override
  Widget build(BuildContext context) {
    String searchQuery = '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('القيود اليومية'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _addJournalEntry(context),
          child: const Icon(Icons.add),
        ),
        body: StatefulBuilder(
          builder: (context, setSearchState) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'ابحث برقم القيد أو الوصف أو الحساب',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setSearchState(() {
                        searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('journal_entries')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('حدث خطأ'),
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
                          child: Text('لا توجد قيود يومية حتى الآن'),
                        );
                      }

                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final description =
                            (data['description'] ?? '').toString().toLowerCase();
                        final entryNo =
                            (data['entryNo'] ?? '').toString().toLowerCase();

                        final lines = (data['lines'] as List?) ?? [];

                        final linesText = lines.map((line) {
                          final item = line as Map<String, dynamic>;

                          final accountCode =
                              (item['accountCode'] ?? '').toString();
                          final accountName =
                              (item['accountName'] ?? '').toString();

                          return '$accountCode $accountName';
                        }).join(' ').toLowerCase();

                        return entryNo.contains(searchQuery) ||
                            description.contains(searchQuery) ||
                            linesText.contains(searchQuery);
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        return const Center(
                          child: Text('لا توجد نتائج مطابقة للبحث'),
                        );
                      }

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data =
                              filteredDocs[index].data() as Map<String, dynamic>;
                          final documentId = filteredDocs[index].id;

                          final description = data['description'] ?? '';
                          final entryNo = data['entryNo'] ?? '';
                          final totalDebit = data['totalDebit'] ?? 0;
                          final totalCredit = data['totalCredit'] ?? 0;
                          final isBalanced = data['isBalanced'] == true;
                          final date = data['date'] as Timestamp?;
                          final lines = (data['lines'] as List?) ?? [];

                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              onTap: () => _showEntryDetails(context, data),
                              leading: Icon(
                                isBalanced ? Icons.check_circle : Icons.error,
                                color: isBalanced ? Colors.green : Colors.red,
                              ),
                              title: Text(
                                entryNo.toString().isEmpty
                                    ? description
                                    : '$entryNo - $description',
                              ),
                              subtitle: Text(
                                'التاريخ: ${_formatDate(date)}\n'
                                'مدين: $totalDebit | دائن: $totalCredit\n'
                                'عدد السطور: ${lines.length}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isBalanced ? 'متوازن' : 'غير متوازن',
                                    style: TextStyle(
                                      color:
                                          isBalanced ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('تم الضغط على زر التعديل'),
                                        ),
                                      );

                                      await _editJournalEntryFull(
                                        context,
                                        documentId,
                                        data,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      _deleteJournalEntry(
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
              ],
            );
          },
        ),
      ),
    );
  }
}