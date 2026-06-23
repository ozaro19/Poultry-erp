import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuditLogsScreen extends StatelessWidget {
  const AuditLogsScreen({super.key});

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) {
      return 'جارٍ التسجيل...';
    }

    final date = value.toDate();
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$year-$month-$day  $hour:$minute';
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'backup':
        return Icons.backup;
      case 'auth':
        return Icons.login;
      case 'accounting':
        return Icons.account_balance;
      case 'inventory':
        return Icons.inventory_2;
      case 'assets':
        return Icons.precision_manufacturing;
      case 'capital':
        return Icons.savings;
      case 'farm':
        return Icons.agriculture;
      default:
        return Icons.history;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'backup':
        return Colors.indigo;
      case 'auth':
        return Colors.green;
      case 'accounting':
        return Colors.blue;
      case 'inventory':
        return Colors.orange;
      case 'assets':
        return Colors.deepPurple;
      case 'capital':
        return Colors.teal;
      case 'farm':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _safeText(dynamic value) {
    if (value == null) return 'غير محدد';
    final text = value.toString().trim();
    if (text.isEmpty) return 'غير محدد';
    return text;
  }

  Widget _buildMetadata(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'تفاصيل إضافية',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      children: metadata.entries.map((entry) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(entry.key),
          subtitle: Text(_safeText(entry.value)),
        );
      }).toList(),
    );
  }

  Widget _buildLogCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final action = _safeText(data['action']);
    final category = _safeText(data['category']);
    final description = _safeText(data['description']);
    final userEmail = _safeText(data['userEmail']);
    final userRole = _safeText(data['userRole']);
    final createdAt = _formatTimestamp(data['createdAt']);

    final metadataValue = data['metadata'];
    final metadata = metadataValue is Map
        ? Map<String, dynamic>.from(metadataValue)
        : <String, dynamic>{};

    final color = _colorForCategory(category);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(
                _iconForCategory(category),
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Chip(
                        label: Text('النوع: $category'),
                      ),
                      Chip(
                        label: Text('الإجراء: $action'),
                      ),
                      Chip(
                        label: Text('المستخدم: $userEmail'),
                      ),
                      Chip(
                        label: Text('الصلاحية: $userRole'),
                      ),
                      Chip(
                        label: Text('التاريخ: $createdAt'),
                      ),
                    ],
                  ),
                  _buildMetadata(metadata),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'لا توجد عمليات مسجلة حتى الآن',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Text(
              'حدث خطأ أثناء تحميل سجل العمليات:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsQuery = FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('createdAt', descending: true)
        .limit(100);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('سجل العمليات'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: logsQuery.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error!);
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سجل العمليات داخل النظام',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'يعرض آخر 100 عملية تم تسجيلها داخل النظام.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...docs.map(_buildLogCard),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}