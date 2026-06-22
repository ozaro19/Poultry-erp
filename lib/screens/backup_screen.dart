import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool isExporting = false;

  final List<String> collectionNames = const [
    'users',
    'system_settings',
    'counters',
    'accounts',
    'chart_of_accounts',
    'journal_entries',
    'capital_transactions',
    'assets',
    'inventory_items',
    'inventory_transactions',
    'fattening_cycles',
    'cycle_daily_followups',
    'cycle_expenses',
    'cycle_sales',
  ];

  String _formatDateTime(DateTime dateTime) {
    final year = dateTime.year.toString();
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year-$month-$day-$hour-$minute';
  }

  dynamic _prepareForJson(dynamic value) {
    if (value is Timestamp) {
      return {
        '_type': 'timestamp',
        'value': value.toDate().toIso8601String(),
      };
    }

    if (value is GeoPoint) {
      return {
        '_type': 'geoPoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }

    if (value is DocumentReference) {
      return {
        '_type': 'documentReference',
        'path': value.path,
      };
    }

    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(
          key.toString(),
          _prepareForJson(mapValue),
        ),
      );
    }

    if (value is Iterable) {
      return value.map(_prepareForJson).toList();
    }

    return value;
  }

  Future<Map<String, dynamic>> _loadCollectionBackup(
    String collectionName,
  ) async {
    final snapshot =
        await FirebaseFirestore.instance.collection(collectionName).get();

    final documents = snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'data': _prepareForJson(doc.data()),
      };
    }).toList();

    return {
      'collection': collectionName,
      'count': documents.length,
      'documents': documents,
    };
  }

  Future<void> _exportBackup() async {
    setState(() {
      isExporting = true;
    });

    try {
      final now = DateTime.now();
      final backupCollections = <Map<String, dynamic>>[];

      for (final collectionName in collectionNames) {
        final collectionBackup = await _loadCollectionBackup(collectionName);
        backupCollections.add(collectionBackup);
      }

      final backupData = {
        'appName': 'Poultry ERP',
        'backupVersion': '1.0',
        'createdAt': now.toIso8601String(),
        'collectionsCount': backupCollections.length,
        'collections': backupCollections,
      };

      const encoder = JsonEncoder.withIndent('  ');
      final jsonText = encoder.convert(backupData);

      final bytes = Uint8List.fromList(
        utf8.encode(jsonText),
      );

      final fileName = 'poultry_erp_backup_${_formatDateTime(now)}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.other,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تصدير النسخة الاحتياطية بنجاح'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تصدير النسخة الاحتياطية: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withAlpha(30),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionTile(String collectionName) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.storage),
        ),
        title: Text(
          collectionName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text('سيتم تضمين هذه المجموعة في النسخة الاحتياطية'),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoCard(
              title: 'نوع النسخة',
              value: 'JSON',
              icon: Icons.data_object,
              color: Colors.indigo,
            ),
            _buildInfoCard(
              title: 'عدد المجموعات',
              value: collectionNames.length.toString(),
              icon: Icons.storage,
              color: Colors.green,
            ),
            _buildInfoCard(
              title: 'الوضع',
              value: 'تصدير فقط',
              icon: Icons.security,
              color: Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.orange.shade50,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.orange,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هذه المرحلة تقوم بتصدير نسخة احتياطية فقط. '
                    'لن يتم تعديل أو حذف أي بيانات من قاعدة البيانات.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 280,
          child: ElevatedButton.icon(
            onPressed: isExporting ? null : _exportBackup,
            icon: isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(
              isExporting
                  ? 'جاري تصدير النسخة...'
                  : 'تصدير نسخة احتياطية',
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'المجموعات التي سيتم تصديرها',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ...collectionNames.map(_buildCollectionTile),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('النسخ الاحتياطي'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'النسخ الاحتياطي وتصدير البيانات',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قم بتصدير نسخة كاملة من بيانات النظام في ملف JSON آمن للاحتفاظ به.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}