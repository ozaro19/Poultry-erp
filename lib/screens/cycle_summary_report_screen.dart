import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CycleSummaryReportScreen extends StatefulWidget {
  const CycleSummaryReportScreen({super.key});

  @override
  State<CycleSummaryReportScreen> createState() =>
      _CycleSummaryReportScreenState();
}

class _CycleSummaryReportScreenState extends State<CycleSummaryReportScreen> {
  List<Map<String, dynamic>> _cycles = [];
  bool _isLoading = true;

  String? _selectedCycleId;
  Map<String, dynamic>? _selectedCycle;

  @override
  void initState() {
    super.initState();
    _loadCycles();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0;

    return 0;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  String _formatNumber(num value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  Future<void> _loadCycles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('fattening_cycles')
        .get();

    final cycles = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    cycles.sort(
      (a, b) => a['code'].toString().compareTo(
            b['code'].toString(),
          ),
    );

    if (!mounted) return;

    setState(() {
      _cycles = cycles;
      _isLoading = false;

      if (cycles.isNotEmpty) {
        _selectedCycleId = cycles.first['id'].toString();
        _selectedCycle = cycles.first;
      }
    });
  }

    Widget _buildInfoCard({
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
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
      ),
    );
  }

      Widget _buildSummarySection(
    QuerySnapshot followupSnapshot,
    QuerySnapshot expensesSnapshot,
  ) {
    if (_selectedCycle == null) {
      return const Center(
        child: Text('اختر دورة لعرض التقرير'),
      );
    }

    final docs = followupSnapshot.docs;

    final records = docs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();

    final expenseDocs = expensesSnapshot.docs;

    final expenseRecords = expenseDocs.map((doc) {
      return doc.data() as Map<String, dynamic>;
    }).toList();

    final totalExpenses = expenseRecords.fold<double>(
      0,
      (total, record) => total + _toDouble(record['amount']),
    );

    records.sort((a, b) {
      final dateA =
          (a['date'] as Timestamp?)?.toDate() ?? DateTime(1900);
      final dateB =
          (b['date'] as Timestamp?)?.toDate() ?? DateTime(1900);

      return dateA.compareTo(dateB);
    });

    final cycleCode = (_selectedCycle!['code'] ?? '').toString();
    final cycleName = (_selectedCycle!['name'] ?? '').toString();
    final breed = (_selectedCycle!['breed'] ?? '').toString();
    final status = (_selectedCycle!['status'] ?? '').toString();

    final startDate = _selectedCycle!['startDate'] as Timestamp?;
    final initialChicks = _toInt(_selectedCycle!['chicksCount']);

    final totalMortality = records.fold<int>(
      0,
      (total, record) => total + _toInt(record['mortality']),
    );

    final totalFeed = records.fold<double>(
      0,
      (total, record) => total + _toDouble(record['feedQty']),
    );

    final remainingChicks = initialChicks - totalMortality;

    final mortalityRate = initialChicks == 0
        ? 0.0
        : (totalMortality / initialChicks) * 100;

    final latestAverageWeight = records.isEmpty
        ? 0.0
        : _toDouble(records.last['averageWeight']);

    final latestFollowupDate = records.isEmpty
        ? 'لا يوجد'
        : _formatDate(records.last['date'] as Timestamp?);

    final daysFromStart = startDate == null
        ? 0
        : DateTime.now().difference(startDate.toDate()).inDays + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$cycleCode - $cycleName',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'السلالة: $breed   |   الحالة: $status   |   تاريخ البداية: ${_formatDate(startDate)}',
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'بيانات الدورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'عدد الكتاكيت في البداية',
              value: initialChicks.toString(),
              icon: Icons.egg_alt,
              color: Colors.orange,
            ),
            _buildInfoCard(
              title: 'عمر الدورة بالأيام',
              value: daysFromStart.toString(),
              icon: Icons.today,
              color: Colors.blue,
            ),
            _buildInfoCard(
              title: 'حالة الدورة',
              value: status,
              icon: Icons.info,
              color: status == 'نشطة' ? Colors.green : Colors.grey,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'ملخص المتابعة اليومية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'إجمالي النفوق',
              value: totalMortality.toString(),
              icon: Icons.warning,
              color: Colors.red,
            ),
            _buildInfoCard(
              title: 'المتبقي الحالي',
              value: remainingChicks.toString(),
              icon: Icons.pets,
              color: Colors.green,
            ),
            _buildInfoCard(
              title: 'نسبة النفوق',
              value: '${_formatNumber(mortalityRate)} %',
              icon: Icons.percent,
              color: Colors.deepOrange,
            ),
            _buildInfoCard(
              title: 'إجمالي العلف المستهلك',
              value: _formatNumber(totalFeed),
              icon: Icons.grass,
              color: Colors.brown,
            ),
            _buildInfoCard(
              title: 'آخر وزن متوسط',
              value: _formatNumber(latestAverageWeight),
              icon: Icons.monitor_weight,
              color: Colors.purple,
            ),
            _buildInfoCard(
              title: 'آخر متابعة',
              value: latestFollowupDate,
              icon: Icons.calendar_month,
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'مصروفات الدورة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'إجمالي المصروفات',
              value: _formatNumber(totalExpenses),
              icon: Icons.receipt_long,
              color: Colors.indigo,
            ),
            _buildInfoCard(
              title: 'عدد بنود المصروفات',
              value: expenseRecords.length.toString(),
              icon: Icons.list_alt,
              color: Colors.blueGrey,
            ),
          ],
        ),
        if (records.isEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'لم يتم تسجيل متابعات يومية لهذه الدورة حتى الآن.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.red,
            ),
          ),
        ],
      ],
    );
  }

    @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تقرير ملخص الدورة'),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _cycles.isEmpty
                ? const Center(
                    child: Text('لا توجد دورات تسمين حتى الآن'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedCycleId),
                          initialValue: _selectedCycleId,
                          decoration: const InputDecoration(
                            labelText: 'اختر الدورة',
                            border: OutlineInputBorder(),
                          ),
                          items: _cycles.map((cycle) {
                            final id = cycle['id'].toString();
                            final code = cycle['code'].toString();
                            final name = cycle['name'].toString();

                            return DropdownMenuItem(
                              value: id,
                              child: Text('$code - $name'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;

                            final selectedCycle = _cycles.firstWhere(
                              (cycle) => cycle['id'].toString() == value,
                            );

                            setState(() {
                              _selectedCycleId = value;
                              _selectedCycle = selectedCycle;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                         Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('cycle_daily_followups')
                                .where(
                                  'cycleId',
                                  isEqualTo: _selectedCycleId,
                                )
                                .snapshots(),
                            builder: (context, followupSnapshot) {
                              if (followupSnapshot.hasError) {
                                return const Center(
                                  child: Text(
                                    'حدث خطأ أثناء تحميل متابعة الدورة',
                                  ),
                                );
                              }

                              if (!followupSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('cycle_expenses')
                                    .where(
                                      'cycleId',
                                      isEqualTo: _selectedCycleId,
                                    )
                                    .snapshots(),
                                builder: (context, expenseSnapshot) {
                                  if (expenseSnapshot.hasError) {
                                    return const Center(
                                      child: Text(
                                        'حدث خطأ أثناء تحميل مصروفات الدورة',
                                      ),
                                    );
                                  }

                                  if (!expenseSnapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }

                                  return SingleChildScrollView(
                                    child: _buildSummarySection(
                                      followupSnapshot.data!,
                                      expenseSnapshot.data!,
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
      ),
    );
  }
}