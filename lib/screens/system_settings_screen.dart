import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() =>
      _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final companyNameController = TextEditingController();
  final reportTitleController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final footerNoteController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    companyNameController.dispose();
    reportTitleController.dispose();
    phoneController.dispose();
    addressController.dispose();
    footerNoteController.dispose();

    super.dispose();
  }

  Future<void> _loadSettings() async {
    final document = await FirebaseFirestore.instance
        .collection('system_settings')
        .doc('company')
        .get();

    final data = document.data();

    if (!mounted) {
      return;
    }

    companyNameController.text =
        (data?['companyName'] ?? 'اسم الشركة تحت الإنشاء').toString();

    reportTitleController.text =
        (data?['reportTitle'] ?? 'نظام إدارة مزارع الدواجن').toString();

    phoneController.text =
        (data?['phone'] ?? '').toString();

    addressController.text =
        (data?['address'] ?? '').toString();

    footerNoteController.text =
        (data?['footerNote'] ?? '').toString();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('system_settings')
          .doc('company')
          .set(
        {
          'companyName': companyNameController.text.trim(),
          'reportTitle': reportTitleController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'footerNote': footerNoteController.text.trim(),
          'updatedAt': Timestamp.now(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات النظام بنجاح'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الحفظ: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات النظام'),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 700,
                    ),
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'بيانات الشركة والتقارير',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: companyNameController,
                              label: 'اسم الشركة',
                              icon: Icons.business,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: reportTitleController,
                              label: 'عنوان التقرير',
                              icon: Icons.description,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: phoneController,
                              label: 'رقم الهاتف',
                              icon: Icons.phone,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: addressController,
                              label: 'العنوان',
                              icon: Icons.location_on,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: footerNoteController,
                              label: 'ملاحظات أسفل التقرير',
                              icon: Icons.notes,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: isSaving ? null : _saveSettings,
                              icon: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                isSaving
                                    ? 'جاري الحفظ...'
                                    : 'حفظ الإعدادات',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}