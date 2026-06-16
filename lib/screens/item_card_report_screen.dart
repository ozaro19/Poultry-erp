import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItemCardReportScreen extends StatefulWidget {
  const ItemCardReportScreen({super.key});

  @override
  State<ItemCardReportScreen> createState() => _ItemCardReportScreenState();
}

class _ItemCardReportScreenState extends State<ItemCardReportScreen> {
  late Future<List<Map<String, dynamic>>> itemsFuture;

  String? selectedItemCode;
  String selectedItemName = '';
  String selectedItemUnit = '';
  double openingQty = 0;

  @override
  void initState() {
    super.initState();
    itemsFuture = _loadItems();
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('inventory_items')
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

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  String _formatNumber(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;

    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }

    return number.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير كارت صنف'),
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: itemsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('حدث خطأ أثناء تحميل الأصناف'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final items = snapshot.data!;

            if (items.isEmpty) {
              return const Center(
                child: Text('لا توجد أصناف حتى الآن'),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedItemCode,
                    decoration: const InputDecoration(
                      labelText: 'اختر الصنف',
                      border: OutlineInputBorder(),
                    ),
                    items: items.map((item) {
                      final code = item['code'].toString();
                      final name = item['name'].toString();
                      final unit = item['unit'].toString();

                      return DropdownMenuItem(
                        value: code,
                        child: Text('$code - $name - $unit'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      final selectedItem = items.firstWhere(
                        (item) => item['code'].toString() == value,
                      );

                      setState(() {
                        selectedItemCode = value;
                        selectedItemName = selectedItem['name'].toString();
                        selectedItemUnit = selectedItem['unit'].toString();
                        openingQty = double.tryParse(
                              (selectedItem['openingQty'] ?? 0).toString(),
                            ) ??
                            0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedItemCode == null)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'اختر صنفًا لعرض كارت الصنف',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        children: [
                          Card(
                            child: ListTile(
                              title: Text(
                                '$selectedItemCode - $selectedItemName',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'الرصيد الافتتاحي: ${_formatNumber(openingQty)} $selectedItemUnit',
                              ),
                            ),
                          ),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('inventory_transactions')
                                  .where(
                                    'itemCode',
                                    isEqualTo: selectedItemCode,
                                  )
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.hasError) {
                                  return const Center(
                                    child: Text(
                                      'حدث خطأ أثناء تحميل كارت الصنف',
                                    ),
                                  );
                                }

                                if (!snapshot.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final docs = snapshot.data!.docs.toList();

                                docs.sort((a, b) {
                                  final dataA =
                                      a.data() as Map<String, dynamic>;
                                  final dataB =
                                      b.data() as Map<String, dynamic>;

                                  final dateA = dataA['date'];
                                  final dateB = dataB['date'];

                                  if (dateA is Timestamp &&
                                      dateB is Timestamp) {
                                    return dateA
                                        .toDate()
                                        .compareTo(dateB.toDate());
                                  }

                                  return 0;
                                });

                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text('لا توجد حركات لهذا الصنف'),
                                  );
                                }

                                double runningBalance = openingQty;

                                final rows = docs.map((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;

                                  final type =
                                      (data['type'] ?? '').toString();
                                  final typeName =
                                      (data['typeName'] ?? '').toString();
                                  final description =
                                      (data['description'] ?? '').toString();
                                  final date = data['date'] as Timestamp?;

                                  final quantity = double.tryParse(
                                        (data['quantity'] ?? 0).toString(),
                                      ) ??
                                      0;

                                  final addQty =
                                      type == 'add' ? quantity : 0.0;
                                  final issueQty =
                                      type == 'issue' ? quantity : 0.0;

                                  runningBalance =
                                      runningBalance + addQty - issueQty;

                                  return {
                                    'date': date,
                                    'typeName': typeName,
                                    'description': description,
                                    'addQty': addQty,
                                    'issueQty': issueQty,
                                    'balance': runningBalance,
                                  };
                                }).toList();

                                return ListView.builder(
                                  itemCount: rows.length,
                                  itemBuilder: (context, index) {
                                    final row = rows[index];

                                    final date = row['date'] as Timestamp?;
                                    final typeName = row['typeName'];
                                    final description = row['description'];
                                    final addQty = row['addQty'];
                                    final issueQty = row['issueQty'];
                                    final balance = row['balance'];

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 6,
                                        horizontal: 4,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          '$typeName - $description',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'التاريخ: ${_formatDate(date)}\n'
                                          'إضافة: ${_formatNumber(addQty)} $selectedItemUnit\n'
                                          'صرف: ${_formatNumber(issueQty)} $selectedItemUnit\n'
                                          'الرصيد بعد الحركة: ${_formatNumber(balance)} $selectedItemUnit',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
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