import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() =>
      _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  late Future<List<Map<String, dynamic>>> usersFuture;

  final Map<String, String> roleLabels = {
    'admin': 'مدير النظام',
    'accountant': 'محاسب',
    'farm_manager': 'مشرف مزرعة',
    'viewer': 'مشاهدة فقط',
  };

  @override
  void initState() {
    super.initState();
    usersFuture = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('email')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }

  void _refreshUsers() {
    setState(() {
      usersFuture = _loadUsers();
    });
  }


  String _validRole(String role) {
    if (roleLabels.containsKey(role)) {
      return role;
    }

    return 'viewer';
  }

  String _statusLabel(Map<String, dynamic> user) {
    final status = (user['status'] ?? '').toString();
    final isActive = user['isActive'] != false;

    if (status == 'pending') {
      return 'في انتظار أول تسجيل دخول';
    }

    if (!isActive) {
      return 'معطّل';
    }

    return 'نشط';
  }

  Color _statusColor(Map<String, dynamic> user) {
    final status = (user['status'] ?? '').toString();
    final isActive = user['isActive'] != false;

    if (status == 'pending') {
      return Colors.orange;
    }

    if (!isActive) {
      return Colors.red;
    }

    return Colors.green;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'غير محدد';

    final date = timestamp.toDate();

    return '${date.year}-${date.month}-${date.day}';
  }

  Future<bool> _emailExists(String email) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> _showAddUserDialog() async {
    final emailController = TextEditingController();
    String selectedRole = 'viewer';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إضافة مستخدم'),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'صلاحية المستخدم',
                          prefixIcon: Icon(Icons.security),
                          border: OutlineInputBorder(),
                        ),
                        items: roleLabels.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;

                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ملاحظة: يتم إنشاء حساب الدخول من Firebase Auth، '
                        'وهنا يتم تحديد صلاحية المستخدم داخل النظام.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final email = emailController.text.trim();

                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال بريد إلكتروني صحيح'),
                        ),
                      );
                      return;
                    }

                    final exists = await _emailExists(email);

                    if (exists) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('هذا البريد موجود بالفعل'),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.collection('users').add({
                      'email': email,
                      'role': selectedRole,
                      'isActive': true,
                      'status': 'pending',
                      'createdAt': Timestamp.now(),
                    });

                    if (!dialogContext.mounted) return;

                    Navigator.pop(dialogContext);

                    if (!mounted) return;

                    _refreshUsers();

                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة المستخدم بنجاح'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  Future<void> _updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set(
      {
        'role': newRole,
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    _refreshUsers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تحديث صلاحية المستخدم'),
      ),
    );
  }

  Future<void> _toggleUserActive({
    required String userId,
    required bool isActive,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set(
      {
        'isActive': isActive,
        'updatedAt': Timestamp.now(),
      },
      SetOptions(merge: true),
    );

    if (!mounted) return;

    _refreshUsers();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isActive ? 'تم تفعيل المستخدم' : 'تم تعطيل المستخدم',
        ),
      ),
    );
  }

  Future<void> _deletePendingUser(Map<String, dynamic> user) async {
    final userId = user['id'].toString();
    final status = (user['status'] ?? '').toString();

    if (status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف مستخدم فعلي، يمكن تعطيله فقط'),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد الحذف'),
          content: const Text('هل تريد حذف هذا المستخدم المعلّق؟'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    await FirebaseFirestore.instance.collection('users').doc(userId).delete();

    if (!mounted) return;

    _refreshUsers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حذف المستخدم المعلّق'),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 230,
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

  Widget _buildUsersSummary(List<Map<String, dynamic>> users) {
    final activeUsers = users.where((user) {
      return user['isActive'] != false;
    }).length;

    final pendingUsers = users.where((user) {
      return (user['status'] ?? '').toString() == 'pending';
    }).length;

    final admins = users.where((user) {
      return (user['role'] ?? '').toString() == 'admin';
    }).length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          title: 'إجمالي المستخدمين',
          value: users.length.toString(),
          icon: Icons.people,
          color: Colors.indigo,
        ),
        _buildSummaryCard(
          title: 'مستخدمون نشطون',
          value: activeUsers.toString(),
          icon: Icons.verified_user,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'في الانتظار',
          value: pendingUsers.toString(),
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'مديرو النظام',
          value: admins.toString(),
          icon: Icons.admin_panel_settings,
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final userId = user['id'].toString();
    final email = (user['email'] ?? '').toString();
    final role = _validRole((user['role'] ?? 'viewer').toString());
    final isActive = user['isActive'] != false;
    final isCurrentUser = userId == currentUserId;
    final status = (user['status'] ?? '').toString();

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 270,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _statusColor(user).withAlpha(30),
                  child: Icon(
                    status == 'pending'
                        ? Icons.pending
                        : Icons.person,
                    color: _statusColor(user),
                  ),
                ),
                title: Text(
                  email,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${_statusLabel(user)}\n'
                  'تاريخ الإضافة: ${_formatDate(user['createdAt'] as Timestamp?)}',
                ),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'الصلاحية',
                  border: OutlineInputBorder(),
                ),
                items: roleLabels.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) return;

                  _updateUserRole(
                    userId: userId,
                    newRole: value,
                  );
                },
              ),
            ),
            SizedBox(
              width: 170,
              child: SwitchListTile(
                title: const Text('نشط'),
                value: isActive,
                onChanged: isCurrentUser
                    ? null
                    : (value) {
                        _toggleUserActive(
                          userId: userId,
                          isActive: value,
                        );
                      },
              ),
            ),
            IconButton(
              tooltip: 'حذف المستخدم المعلّق',
              icon: const Icon(Icons.delete),
              onPressed: status == 'pending'
                  ? () {
                      _deletePendingUser(user);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersContent(List<Map<String, dynamic>> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUsersSummary(users),
        const SizedBox(height: 24),
        const Text(
          'قائمة المستخدمين',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (users.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text('لا يوجد مستخدمون حتى الآن'),
            ),
          )
        else
          Column(
            children: users.map(_buildUserCard).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المستخدمين والصلاحيات'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
              onPressed: _refreshUsers,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddUserDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة مستخدم'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: usersFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('حدث خطأ أثناء تحميل المستخدمين'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return _buildUsersContent(snapshot.data!);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}