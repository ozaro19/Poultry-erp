import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountLedgerScreen extends StatefulWidget {
  const AccountLedgerScreen({super.key});

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  String? selectedAccountCode;
  String selectedAccountName = '';

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

  List<Map<String, dynamic>> _extractLedgerRows(
    List<QueryDocumentSnapshot> docs,
    String accountCode,
  ) {
    final rows = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final lines = (data['lines'] as List?) ?? [];

      for (final line in lines) {
        final item = line as Map<String, dynamic>;

        if (item['accountCode'].toString() == accountCode) {
          rows.add({
            'entryNo': data['entryNo'] ?? '',
            'date': data['date'],
            'description': data['description'] ?? '',
            'debit': item['debit'] ?? 0,
            'credit': item['credit'] ?? 0,
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
          title: const Text('كشف حساب'),
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

              if (accounts.isEmpty) {
                return const Center(
                  child: Text('لا توجد حسابات في شجرة الحسابات'),
                );
              }

              return Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedAccountCode,
                    decoration: const InputDecoration(
                      labelText: 'اختر الحساب',
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
                        selectedAccountCode = value;
                        selectedAccountName =
                            selectedAccount['nameAr'].toString();
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  if (selectedAccountCode == null)
                    const Expanded(
                      child: Center(
                        child: Text('اختاري حسابًا لعرض كشف الحساب'),
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
                              child: Text('حدث خطأ أثناء تحميل القيود'),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          final rows = _extractLedgerRows(
                            docs,
                            selectedAccountCode!,
                          );

                          if (rows.isEmpty) {
                            return Center(
                              child: Text(
                                'لا توجد حركات على الحساب $selectedAccountCode - $selectedAccountName',
                              ),
                            );
                          }

                          double balance = 0;
                          double totalDebit = 0;
                          double totalCredit = 0;

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'كشف حساب: $selectedAccountCode - $selectedAccountName',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                DataTable(
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
                                      label: Text('مدين'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('دائن'),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text('الرصيد'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: rows.map((row) {
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
                                          Text(row['entryNo'].toString()),
                                        ),
                                        DataCell(
                                          Text(row['description'].toString()),
                                        ),
                                        DataCell(
                                          Text(debit.toString()),
                                        ),
                                        DataCell(
                                          Text(credit.toString()),
                                        ),
                                        DataCell(
                                          Text(balance.toString()),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 16),

                                const Divider(),

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
                                  'الرصيد النهائي: $balance',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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