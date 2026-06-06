import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

 Future<void> _addAccount(BuildContext context) async {
  final codeController = TextEditingController();
  final nameArController = TextEditingController();
  final nameEnController = TextEditingController();
  final levelController = TextEditingController(text: '1');

  String selectedParentCode = 'root';

  final accountsSnapshot = await FirebaseFirestore.instance
      .collection('chart_of_accounts')
      .orderBy('code')
      .get();

  final accounts = accountsSnapshot.docs.map((doc) {
    final data = doc.data();

    return {
      'id': doc.id,
      ...data,
    };
  }).toList();

  if (!context.mounted) return;

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
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

                  DropdownButtonFormField<String>(
                    value: selectedParentCode,
                    decoration: const InputDecoration(
                      labelText: 'الحساب الأب',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'root',
                        child: Text('root - حساب رئيسي'),
                      ),
                      ...accounts.map((account) {
                        final code = account['code'].toString();
                        final nameAr = account['nameAr'].toString();

                        return DropdownMenuItem(
                          value: code,
                          child: Text('$code - $nameAr'),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        selectedParentCode = value;

                        if (value == 'root') {
                          levelController.text = '1';
                        } else {
                          final parentAccount = accounts.firstWhere(
                            (account) =>
                                account['code'].toString() == value,
                          );

                          final parentLevel = int.tryParse(
                                parentAccount['level'].toString(),
                              ) ??
                              1;

                          levelController.text =
                              (parentLevel + 1).toString();
                        }
                      });
                    },
                  ),

                  TextField(
                    controller: levelController,
                    decoration: const InputDecoration(
                      labelText: 'المستوى',
                    ),
                    keyboardType: TextInputType.number,
                    readOnly: true,
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

                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يجب إدخال كود الحساب'),
                      ),
                    );
                    return;
                  }

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
                    'parentCode': selectedParentCode,
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
      (child) =>
          child['parentCode'].toString().trim() == code.trim(),
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