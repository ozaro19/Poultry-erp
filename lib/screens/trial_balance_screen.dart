import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrialBalanceScreen extends StatelessWidget {
  const TrialBalanceScreen({super.key});

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

  Future<List<QueryDocumentSnapshot>> _loadJournalEntries() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('journal_entries')
        .get();

    return snapshot.docs;
  }

  Future<List<Map<String, dynamic>>> _buildTrialBalance() async {
    final accounts = await _loadAccounts();
    final journalEntries = await _loadJournalEntries();

    final Map<String, Map<String, dynamic>> balances = {};

    for (final account in accounts) {
      final code = account['code'].toString();

      balances[code] = {
        'code': code,
        'nameAr': account['nameAr'] ?? '',
        'nameEn': account['nameEn'] ?? '',
        'debit': 0.0,
        'credit': 0.0,
      };
    }

    for (final doc in journalEntries) {
      final data = doc.data() as Map<String, dynamic>;
      final lines = (data['lines'] as List?) ?? [];

      for (final line in lines) {
        final item = line as Map<String, dynamic>;

        final accountCode = item['accountCode'].toString();

        final debit = double.tryParse(
              item['debit'].toString(),
            ) ??
            0;

        final credit = double.tryParse(
              item['credit'].toString(),
            ) ??
            0;

        if (!balances.containsKey(accountCode)) {
          balances[accountCode] = {
            'code': accountCode,
            'nameAr': item['accountName'] ?? '',
            'nameEn': '',
            'debit': 0.0,
            'credit': 0.0,
          };
        }

        balances[accountCode]!['debit'] =
            (balances[accountCode]!['debit'] as double) + debit;

        balances[accountCode]!['credit'] =
            (balances[accountCode]!['credit'] as double) + credit;
      }
    }

    final result = balances.values.toList();

    result.sort(
      (a, b) => a['code'].toString().compareTo(
            b['code'].toString(),
          ),
    );

    return result;
  }

  String _balanceType(double balance) {
    if (balance > 0) return 'مدين';
    if (balance < 0) return 'دائن';
    return 'متعادل';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ميزان المراجعة'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _buildTrialBalance(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل ميزان المراجعة'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final rows = snapshot.data!;

            if (rows.isEmpty) {
              return const Center(
                child: Text('لا توجد بيانات لعرض ميزان المراجعة'),
              );
            }

            double totalDebit = 0;
            double totalCredit = 0;

            for (final row in rows) {
              totalDebit += row['debit'] as double;
              totalCredit += row['credit'] as double;
            }

            final difference = totalDebit - totalCredit;
            final isBalanced = difference == 0;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            isBalanced
                                ? 'ميزان المراجعة متوازن'
                                : 'يوجد فرق: $difference',
                            style: TextStyle(
                              color: isBalanced ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: const [
                            DataColumn(
                              label: Text('الكود'),
                            ),
                            DataColumn(
                              label: Text('الحساب'),
                            ),
                            DataColumn(
                              label: Text('إجمالي مدين'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('إجمالي دائن'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('الرصيد'),
                              numeric: true,
                            ),
                            DataColumn(
                              label: Text('طبيعة الرصيد'),
                            ),
                          ],
                          rows: rows.map((row) {
                            final debit = row['debit'] as double;
                            final credit = row['credit'] as double;
                            final balance = debit - credit;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(row['code'].toString()),
                                ),
                                DataCell(
                                  Text(row['nameAr'].toString()),
                                ),
                                DataCell(
                                  Text(debit.toString()),
                                ),
                                DataCell(
                                  Text(credit.toString()),
                                ),
                                DataCell(
                                  Text(balance.abs().toString()),
                                ),
                                DataCell(
                                  Text(_balanceType(balance)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}