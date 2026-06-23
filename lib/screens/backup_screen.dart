import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../services/audit_log_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool isExporting = false;
  bool isReadingBackup = false;

  Map<String, dynamic>? selectedBackupData;
  String? selectedBackupFileName;
  String? selectedBackupError;

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

      await AuditLogService.log(
        action: 'backup_export',
        category: 'backup',
        description: 'تم تصدير نسخة احتياطية للنظام',
        metadata: {
          'fileName': '$fileName.json',
          'collectionsCount': backupCollections.length,
          'totalRecords': backupCollections.fold<int>(
            0,
            (total, collection) => total + _safeCount(collection['count']),
          ),
        },
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

  int _safeCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  List<Map<String, dynamic>> get previewCollections {
    final backupData = selectedBackupData;
    if (backupData == null) return [];

    final collections = backupData['collections'];
    if (collections is! List) return [];

    return collections
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int get previewTotalDocuments {
    var total = 0;

    for (final collection in previewCollections) {
      final count = collection['count'];
      if (count is int || count is num) {
        total += _safeCount(count);
      } else {
        final documents = collection['documents'];
        if (documents is List) {
          total += documents.length;
        }
      }
    }

    return total;
  }

  Future<void> _pickAndPreviewBackup() async {
    setState(() {
      isReadingBackup = true;
      selectedBackupError = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('لم أستطع قراءة الملف. جربي اختيار الملف مرة أخرى.');
      }

      final jsonText = utf8.decode(bytes);
      final decoded = jsonDecode(jsonText);

      if (decoded is! Map) {
        throw Exception('هذا الملف ليس نسخة احتياطية صحيحة.');
      }

      final backupMap = Map<String, dynamic>.from(decoded);

      if (backupMap['appName'] != 'Poultry ERP') {
        throw Exception('هذا الملف لا يبدو أنه خاص بنظام Poultry ERP.');
      }

      if (backupMap['collections'] is! List) {
        throw Exception('ملف النسخة الاحتياطية لا يحتوي على بيانات المجموعات.');
      }

      setState(() {
        selectedBackupData = backupMap;
        selectedBackupFileName = file.name;
        selectedBackupError = null;
      });

      await AuditLogService.log(
        action: 'backup_preview',
        category: 'backup',
        description: 'تم فحص ملف نسخة احتياطية بدون استعادة',
        metadata: {
          'fileName': file.name,
          'collectionsCount': previewCollections.length,
          'totalRecords': previewTotalDocuments,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم فحص ملف النسخة الاحتياطية بنجاح'),
        ),
      );
    } catch (error) {
      setState(() {
        selectedBackupData = null;
        selectedBackupFileName = null;
        selectedBackupError = error.toString();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء فحص الملف: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isReadingBackup = false;
        });
      }
    }
  }

  void _clearPreview() {
    setState(() {
      selectedBackupData = null;
      selectedBackupFileName = null;
      selectedBackupError = null;
    });
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

  Widget _buildExportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تصدير نسخة احتياطية',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 20),
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

  Widget _buildPreviewSection() {
    final backupData = selectedBackupData;
    final createdAt = backupData?['createdAt']?.toString() ?? 'غير محدد';
    final backupVersion =
        backupData?['backupVersion']?.toString() ?? 'غير محدد';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'فحص ملف نسخة احتياطية',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'اختاري ملف JSON تم تصديره سابقًا من النظام لعرض محتواه بدون استعادة.',
          style: TextStyle(
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 280,
              child: ElevatedButton.icon(
                onPressed: isReadingBackup ? null : _pickAndPreviewBackup,
                icon: isReadingBackup
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  isReadingBackup
                      ? 'جاري فحص الملف...'
                      : 'اختيار وفحص ملف JSON',
                ),
              ),
            ),
            if (backupData != null)
              SizedBox(
                width: 180,
                child: OutlinedButton.icon(
                  onPressed: _clearPreview,
                  icon: const Icon(Icons.clear),
                  label: const Text('مسح الفحص'),
                ),
              ),
          ],
        ),
        if (selectedBackupError != null) ...[
          const SizedBox(height: 14),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.error,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedBackupError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (backupData != null) ...[
          const SizedBox(height: 20),
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: Colors.green,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'تم قراءة النسخة الاحتياطية بنجاح',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('اسم الملف: ${selectedBackupFileName ?? 'غير محدد'}'),
                  Text('إصدار النسخة: $backupVersion'),
                  Text('تاريخ إنشاء النسخة: $createdAt'),
                  Text('عدد المجموعات: ${previewCollections.length}'),
                  Text('إجمالي السجلات: $previewTotalDocuments'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'تفاصيل المجموعات داخل الملف',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...previewCollections.map((collection) {
            final name = collection['collection']?.toString() ?? 'غير معروف';
            final count = _safeCount(collection['count']);

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.folder_copy),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text('عدد السجلات داخل هذه المجموعة: $count'),
              ),
            );
          }),
          const SizedBox(height: 14),
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.lock,
                    color: Colors.blue,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'هذا فحص فقط. لم يتم استعادة أو تعديل أي بيانات.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
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
                    'قم بتصدير نسخة كاملة من بيانات النظام أو فحص ملف نسخة احتياطية سابق.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildExportSection(),
                  const SizedBox(height: 36),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildPreviewSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}