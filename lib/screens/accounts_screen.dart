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
                    labelText: 'كود الحساب الأب',
                    hintText: 'مثال: 1000 أو root',
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
                final code = codeController.text.trim();

                final existingAccount = await FirebaseFirestore.instance
                    .collection('chart_of_accounts')
                    .where(
                      'code',
                      isEqualTo: code,
                    )
                    .get();

                if (existingAccount.docs.isNotEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('كود الحساب موجود بالفعل'),
                      ),
                    );
                  }
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('chart_of_accounts')
                    .add({
                  'code': code,
                  'nameAr': nameArController.text.trim(),
                  'nameEn': nameEnController.text.trim(),
                  'parentCode': parentController.text.trim().isEmpty
                      ? 'root'
                      : parentController.text.trim(),
                  'level': int.tryParse(levelController.text.trim()) ?? 1,
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
                  'nameAr': nameArController.text.trim(),
                  'nameEn': nameEnController.text.trim(),
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
      final children = await FirebaseFirestore.instance
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
  }

  Widget _buildAccountTreeNode(
    BuildContext context,
    Map<String, dynamic> account,
    List<Map<String, dynamic>> allAccounts,
  ) {
    final documentId = account['id'].toString();
    final code = account['code'].toString();
    final nameAr = account['nameAr'].toString();
    final nameEn = account['nameEn'].toString();
    final level = int.tryParse(account['level'].toString()) ?? 1;

    final children = allAccounts
        .where(
          (child) => child['parentCode'].toString() == code,
        )
        .toList();

    children.sort(
      (a, b) => a['code'].toString().compareTo(
            b['code'].toString(),
          ),
    );

    final titleRow = Row(
      children: [
        Expanded(
          child: Text(
            '$code - $nameAr',
            style: TextStyle(
              fontWeight:
                  children.isNotEmpty ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            _editAccount(
              context,
              documentId,
              account,
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            _deleteAccount(
              context,
              documentId,
              code,
            );
          },
        ),
      ],
    );

    if (children.isNotEmpty) {
      return Padding(
        padding: EdgeInsets.only(
          right: (level - 1) * 20.0,
        ),
        child: ExpansionTile(
          initiallyExpanded: level == 1,
          leading: const Icon(Icons.account_tree),
          title: titleRow,
          subtitle: Text(
            '$nameEn | Level: $level',
          ),
          children: children
              .map(
                (child) => _buildAccountTreeNode(
                  context,
                  child,
                  allAccounts,
                ),
              )
              .toList(),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        right: (level - 1) * 20.0,
      ),
      child: ListTile(
        leading: const Icon(Icons.subdirectory_arrow_left),
        title: titleRow,
        subtitle: Text(
          '$nameEn | Level: $level',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
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

            final accounts = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return {
                'id': doc.id,
                ...data,
              };
            }).toList();

            accounts.sort(
              (a, b) => a['code'].toString().compareTo(
                    b['code'].toString(),
                  ),
            );

            final allCodes = accounts
                .map(
                  (account) => account['code'].toString(),
                )
                .toSet();

            final rootAccounts = accounts.where((account) {
              final parentCode =
                  (account['parentCode'] ?? '').toString().trim();

              return parentCode.isEmpty ||
                  parentCode == 'root' ||
                  !allCodes.contains(parentCode);
            }).toList();

            return ListView(
              children: rootAccounts
                  .map(
                    (account) => _buildAccountTreeNode(
                      context,
                      account,
                      accounts,
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}