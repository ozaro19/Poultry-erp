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
                final existingAccount =
                    await FirebaseFirestore.instance
                        .collection('chart_of_accounts')
                        .where(
                          'code',
                          isEqualTo: codeController.text,
                        )
                        .get();

                if (existingAccount.docs.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'كود الحساب موجود بالفعل',
                      ),
                    ),
                  );
                  return;
                }

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

  Future<void> _editAccount(
    BuildContext context,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    final nameArController =
        TextEditingController(text: data['nameAr']);

    final nameEnController =
        TextEditingController(text: data['nameEn']);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تعديل الحساب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
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
                    .doc(documentId)
                    .update({
                  'nameAr': nameArController.text,
                  'nameEn': nameEnController.text,
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
Future<void> _deleteAccount(
  BuildContext context,
  String documentId,
  String accountCode,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text(
          'هل تريد حذف الحساب $accountCode ؟',
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
    final children =
      await FirebaseFirestore.instance
          .collection('chart_of_accounts')
          .where(
            'parentCode',
            isEqualTo: accountCode,
          )
          .get();

    if (children.docs.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن حذف الحساب لأنه يحتوي على حسابات فرعية',
            ),
          ),
        );
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('chart_of_accounts')
        .doc(documentId)
        .delete();
  }
    await FirebaseFirestore.instance
        .collection('chart_of_accounts')
        .doc(documentId)
        .delete();
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
              final level = data['level'] ?? 1;
              return Padding(
                padding: EdgeInsets.only(
                  right: (level - 1) * 30.0,
                ),
                child: ListTile(
                leading: const Icon(Icons.account_tree),
                title: Text(
                  '${data['code']} - ${data['nameAr']}',
                ),
                subtitle: Text(
                  '${data['nameEn']} | Level: ${data['level']}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _editAccount(
                          context,
                          docs[index].id,
                          data,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteAccount(
                          context,
                          docs[index].id,
                          data['code'],
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
    );
  }
}