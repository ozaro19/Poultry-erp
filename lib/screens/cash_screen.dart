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

  List<Map<String, dynamic>> _extractCashRows(
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

                          double totalDebit = 0;
                          double totalCredit = 0;
                          double balance = 0;

                          for (final row in rows) {
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

                              if (rows.isEmpty)
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
                                        ],
                                        rows: rows.map((row) {
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
                                                  row['description'].toString(),
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