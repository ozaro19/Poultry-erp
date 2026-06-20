import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CapitalScreen extends StatefulWidget {
  const CapitalScreen({super.key});

  @override
  State<CapitalScreen> createState() => _CapitalScreenState();
}

class _CapitalScreenState extends State<CapitalScreen> {
  late Future<List<Map<String, dynamic>>> transactionsFuture;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    transactionsFuture = _loadTransactions();
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;

    return 0;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  String _typeLabel(String type) {
    if (type == 'withdrawal') {
      return 'سحب من رأس المال';
    }

    return 'زيادة رأس مال';
  }

  Color _typeColor(String type) {
    if (type == 'withdrawal') {
      return Colors.red;
    }

    return Colors.green;
  }

  Future<List<Map<String, dynamic>>> _loadTransactions() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('capital_transactions')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  void _refreshTransactions() {
    setState(() {
      transactionsFuture = _loadTransactions();
    });
  }

  Future<void> _ensureAccount({
    required String code,
    required String nameAr,
    required String accountType,
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chart_of_accounts')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('chart_of_accounts').add({
      'code': code,
      'nameAr': nameAr,
      'nameEn': '',
      'type': accountType,
      'parentCode': '',
      'level': 0,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> _ensureCapitalAccounts() async {
    await _ensureAccount(
      code: '1100',
      nameAr: 'الخزينة',
      accountType: 'أصل',
    );

    await _ensureAccount(
      code: '3000',
      nameAr: 'رأس المال',
      accountType: 'حقوق ملكية',
    );
  }

  Future<String> _generateEntryNumber() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('journal_entries');

    final counterSnapshot = await counterRef.get();

    int lastNumber = 0;

    if (counterSnapshot.exists) {
      final counterData = counterSnapshot.data();
      lastNumber = _toInt(counterData?['lastNumber']);
    }

    final nextNumber = lastNumber + 1;

    await counterRef.set(
      {
        'lastNumber': nextNumber,
      },
      SetOptions(merge: true),
    );

    return 'JE-${nextNumber.toString().padLeft(4, '0')}';
  }

  Future<Map<String, String>> _createCapitalJournalEntry({
    required String type,
    required double amount,
    required DateTime date,
    required String partnerName,
    required String notes,
  }) async {
    await _ensureCapitalAccounts();

    final entryNo = await _generateEntryNumber();

    final description = type == 'withdrawal'
        ? 'سحب من رأس المال${partnerName.isNotEmpty ? ' - $partnerName' : ''}'
        : 'زيادة رأس مال${partnerName.isNotEmpty ? ' - $partnerName' : ''}';

    final lines = type == 'withdrawal'
        ? [
            {
              'accountCode': '3000',
              'accountName': 'رأس المال',
              'debit': amount,
              'credit': 0,
            },
            {
              'accountCode': '1100',
              'accountName': 'الخزينة',
              'debit': 0,
              'credit': amount,
            },
          ]
        : [
            {
              'accountCode': '1100',
              'accountName': 'الخزينة',
              'debit': amount,
              'credit': 0,
            },
            {
              'accountCode': '3000',
              'accountName': 'رأس المال',
              'debit': 0,
              'credit': amount,
            },
          ];

    final journalEntryRef =
        await FirebaseFirestore.instance.collection('journal_entries').add({
      'entryNo': entryNo,
      'date': Timestamp.fromDate(date),
      'description': description,
      'lines': lines,
      'totalDebit': amount,
      'totalCredit': amount,
      'isBalanced': true,
      'source': 'capital_transaction',
      'capitalType': type,
      'partnerName': partnerName,
      'notes': notes,
      'createdAt': Timestamp.now(),
    });

    return {
      'id': journalEntryRef.id,
      'entryNo': entryNo,
    };
  }

  Future<void> _showCapitalForm() async {
    final amountController = TextEditingController();
    final partnerNameController = TextEditingController();
    final notesController = TextEditingController();

    String selectedType = 'increase';
    DateTime selectedDate = DateTime.now();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة حركة رأس مال'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'نوع الحركة',
                          prefixIcon: Icon(Icons.swap_vert),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'increase',
                            child: Text('زيادة رأس مال'),
                          ),
                          DropdownMenuItem(
                            value: 'withdrawal',
                            child: Text('سحب من رأس المال'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedType = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ',
                          prefixIcon: Icon(Icons.payments),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: partnerNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الشريك / الممول',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );

                          if (pickedDate == null) return;

                          setDialogState(() {
                            selectedDate = pickedDate;
                          });
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'التاريخ: ${selectedDate.year}-${selectedDate.month}-${selectedDate.day}',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          prefixIcon: Icon(Icons.notes),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final amount = double.tryParse(
                                amountController.text.trim(),
                              ) ??
                              0;

                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('يرجى إدخال مبلغ صحيح'),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isSaving = true;
                          });

                          try {
                            final partnerName =
                                partnerNameController.text.trim();
                            final notes = notesController.text.trim();

                            final journalInfo =
                                await _createCapitalJournalEntry(
                              type: selectedType,
                              amount: amount,
                              date: selectedDate,
                              partnerName: partnerName,
                              notes: notes,
                            );

                            await FirebaseFirestore.instance
                                .collection('capital_transactions')
                                .add({
                              'type': selectedType,
                              'typeLabel': _typeLabel(selectedType),
                              'amount': amount,
                              'date': Timestamp.fromDate(selectedDate),
                              'partnerName': partnerName,
                              'notes': notes,
                              'journalEntryId': journalInfo['id'],
                              'journalEntryNo': journalInfo['entryNo'],
                              'createdAt': Timestamp.now(),
                            });

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            if (!mounted) return;

                            _refreshTransactions();

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم تسجيل حركة رأس المال وإنشاء قيد اليومية',
                                ),
                              ),
                            );
                          } catch (error) {
                            if (!mounted) return;

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'حدث خطأ أثناء حفظ حركة رأس المال: $error',
                                ),
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                isSaving = false;
                              });
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(isSaving ? 'جاري الحفظ...' : 'حفظ'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    partnerNameController.dispose();
    notesController.dispose();
  }

  Future<void> _deleteTransaction(Map<String, dynamic> transaction) async {
    final transactionId = transaction['id'].toString();
    final journalEntryId = (transaction['journalEntryId'] ?? '').toString();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text(
            'سيتم حذف حركة رأس المال وقيد اليومية المرتبط بها. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    if (journalEntryId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('journal_entries')
          .doc(journalEntryId)
          .delete();
    }

    await FirebaseFirestore.instance
        .collection('capital_transactions')
        .doc(transactionId)
        .delete();

    if (!mounted) return;

    _refreshTransactions();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف حركة رأس المال وقيد اليومية المرتبط بها'),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(30),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> transactions) {
    final totalIncrease = transactions
        .where((transaction) => transaction['type'] == 'increase')
        .fold<double>(
          0,
          (total, transaction) => total + _toDouble(transaction['amount']),
        );

    final totalWithdrawal = transactions
        .where((transaction) => transaction['type'] == 'withdrawal')
        .fold<double>(
          0,
          (total, transaction) => total + _toDouble(transaction['amount']),
        );

    final netCapital = totalIncrease - totalWithdrawal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSummaryCard(
              title: 'إجمالي زيادات رأس المال',
              value: _formatNumber(totalIncrease),
              icon: Icons.trending_up,
              color: Colors.green,
            ),
            _buildSummaryCard(
              title: 'إجمالي السحوبات',
              value: _formatNumber(totalWithdrawal),
              icon: Icons.trending_down,
              color: Colors.red,
            ),
            _buildSummaryCard(
              title: 'صافي رأس المال',
              value: _formatNumber(netCapital),
              icon: Icons.account_balance,
              color: Colors.indigo,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'حركات رأس المال',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (transactions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('لا توجد حركات رأس مال مسجلة حتى الآن'),
            ),
          )
        else
          Card(
            elevation: 3,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('نوع الحركة')),
                  DataColumn(label: Text('المبلغ')),
                  DataColumn(label: Text('الشريك / الممول')),
                  DataColumn(label: Text('قيد اليومية')),
                  DataColumn(label: Text('إجراء')),
                ],
                rows: transactions.map((transaction) {
                  final type = (transaction['type'] ?? '').toString();
                  final amount = _toDouble(transaction['amount']);

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          _formatDate(transaction['date'] as Timestamp?),
                        ),
                      ),
                      DataCell(
                        Text(
                          _typeLabel(type),
                          style: TextStyle(
                            color: _typeColor(type),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataCell(Text(_formatNumber(amount))),
                      DataCell(
                        Text(
                          (transaction['partnerName'] ?? '').toString(),
                        ),
                      ),
                      DataCell(
                        Text(
                          (transaction['journalEntryNo'] ?? '').toString(),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: 'حذف',
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _deleteTransaction(transaction);
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رأس المال'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshTransactions,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCapitalForm,
          icon: const Icon(Icons.add),
          label: const Text('إضافة حركة'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إدارة رأس المال',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سجل زيادات وسحوبات رأس المال مع إنشاء قيود يومية تلقائيًا.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: transactionsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('حدث خطأ أثناء تحميل بيانات رأس المال'),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      return _buildContent(snapshot.data!);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}