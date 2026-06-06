import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JournalEntriesScreen extends StatelessWidget {
  const JournalEntriesScreen({super.key});

  Future<void> _addJournalEntry(BuildContext context) async {
    final descriptionController = TextEditingController();
    final debitController = TextEditingController();
    final creditController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة قيد يومية'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'وصف القيد',
                  ),
                ),
                TextField(
                  controller: debitController,
                  decoration: const InputDecoration(
                    labelText: 'إجمالي المدين',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: creditController,
                  decoration: const InputDecoration(
                    labelText: 'إجمالي الدائن',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final debit =
                    double.tryParse(debitController.text.trim()) ?? 0;
                final credit =
                    double.tryParse(creditController.text.trim()) ?? 0;

                await FirebaseFirestore.instance
                    .collection('journal_entries')
                    .add({
                  'date': Timestamp.now(),
                  'description': descriptionController.text.trim(),
                  'totalDebit': debit,
                  'totalCredit': credit,
                  'isBalanced': debit == credit,
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
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  @override
  Widget build(BuildContext context) {
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
        body: StreamBuilder<QuerySnapshot>(
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

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                final description = data['description'] ?? '';
                final totalDebit = data['totalDebit'] ?? 0;
                final totalCredit = data['totalCredit'] ?? 0;
                final isBalanced = data['isBalanced'] == true;
                final date = data['date'] as Timestamp?;

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(
                      isBalanced ? Icons.check_circle : Icons.error,
                      color: isBalanced ? Colors.green : Colors.red,
                    ),
                    title: Text(description),
                    subtitle: Text(
                      'التاريخ: ${_formatDate(date)}\n'
                      'مدين: $totalDebit | دائن: $totalCredit',
                    ),
                    trailing: Text(
                      isBalanced ? 'متوازن' : 'غير متوازن',
                      style: TextStyle(
                        color: isBalanced ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
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