import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _addAccount(BuildContext context) async {
    final codeController = TextEditingController();
    final nameArController = TextEditingController();
    final nameEnController = TextEditingController();
    final parentController = TextEditingController();
    final levelController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'كود الحساب',
                  ),
                ),
                TextField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية',
                  ),
                ),
                TextField(
                  controller: nameEnController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالإنجليزية',
                  ),
                ),
                TextField(
                  controller: parentController,
                  decoration: const InputDecoration(
                    labelText: 'الحساب الأب',
                  ),
                ),
                TextField(
                  controller: levelController,
                  decoration: const InputDecoration(
                    labelText: 'المستوى',
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
                await FirebaseFirestore.instance
                    .collection('chart_of_accounts')
                    .add({
                  'code': codeController.text,
                  'nameAr': nameArController.text,
                  'nameEn': nameEnController.text,
                  'parentCode': parentController.text,
                  'level': int.tryParse(
                        levelController.text,
                      ) ??
                      1,
                });

                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شجرة الحسابات'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addAccount(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chart_of_accounts')
            .orderBy('code')
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

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data =
                  docs[index].data() as Map<String, dynamic>;

              return ListTile(
                leading: const Icon(Icons.account_tree),
                title: Text(
                  '${data['code']} - ${data['nameAr']}',
                ),
                subtitle: Text(
                  data['nameEn'],
                ),
              );
            },
          );
        },
      ),
    );
  }
}