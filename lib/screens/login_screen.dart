import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveUserDocument({
    required User user,
    required String defaultRole,
  }) async {
    final usersCollection = FirebaseFirestore.instance.collection('users');

    final userRef = usersCollection.doc(user.uid);

    final userDocument = await userRef.get();

    final email = user.email ?? '';

    if (!userDocument.exists) {
      DocumentSnapshot<Map<String, dynamic>>? pendingUserDocument;

      if (email.isNotEmpty) {
        final pendingSnapshot = await usersCollection
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (pendingSnapshot.docs.isNotEmpty) {
          pendingUserDocument = pendingSnapshot.docs.first;
        }
      }

      final pendingData = pendingUserDocument?.data();

      final role = (pendingData?['role'] ?? defaultRole).toString();
      final isActive = pendingData?['isActive'] != false;

      await userRef.set({
        'uid': user.uid,
        'email': email,
        'displayName': user.displayName ?? '',
        'role': role,
        'isActive': isActive,
        'status': 'active',
        'createdAt': pendingData?['createdAt'] ?? Timestamp.now(),
        'lastLoginAt': Timestamp.now(),
      });

      if (pendingUserDocument != null &&
          pendingUserDocument.id != user.uid) {
        await usersCollection.doc(pendingUserDocument.id).delete();
      }
    } else {
      await userRef.set(
        {
          'email': email,
          'status': 'active',
          'lastLoginAt': Timestamp.now(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<bool> _isFirstSystemUser() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .limit(1)
        .get();

    return snapshot.docs.isEmpty;
  }

  Future<bool> _validateUserAccess(User user) async {
    final userDocument = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDocument.data();

    final isActive = userData?['isActive'] != false;

    if (!isActive) {
      await FirebaseAuth.instance.signOut();
      return false;
    }

    return true;
  }

  String _friendlyErrorMessage(Object error) {
    final text = error.toString();

    if (text.contains('user-not-found')) {
      return 'هذا البريد غير مسجل';
    }

    if (text.contains('wrong-password')) {
      return 'كلمة المرور غير صحيحة';
    }

    if (text.contains('invalid-email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    if (text.contains('email-already-in-use')) {
      return 'هذا البريد مستخدم من قبل';
    }

    if (text.contains('weak-password')) {
      return 'كلمة المرور ضعيفة';
    }

    if (text.contains('network-request-failed')) {
      return 'تأكد من الاتصال بالإنترنت';
    }

    return 'حدث خطأ أثناء تنفيذ العملية';
  }

  Future<void> _signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('لم يتم العثور على المستخدم');
      }

      await _saveUserDocument(
        user: user,
        defaultRole: 'viewer',
      );

      final canAccess = await _validateUserAccess(user);

      if (!mounted) return;

      if (!canAccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هذا المستخدم غير نشط ولا يمكنه الدخول'),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _createFirstAdmin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور'),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final isFirstUser = await _isFirstSystemUser();

      if (!isFirstUser) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إنشاء مدير النظام من قبل. استخدم تسجيل الدخول فقط.',
            ),
          ),
        );
        return;
      }

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('لم يتم إنشاء المستخدم');
      }

      await _saveUserDocument(
        user: user,
        defaultRole: 'admin',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء مدير النظام بنجاح'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _createInvitedUserAccount() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور'),
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingSnapshot.docs.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذا البريد غير موجود في دعوات المستخدمين',
            ),
          ),
        );
        return;
      }

      final pendingUserData = pendingSnapshot.docs.first.data();
      final pendingStatus =
          (pendingUserData['status'] ?? '').toString();

      if (pendingStatus != 'pending') {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'هذا البريد مسجل بالفعل أو غير متاح كدعوة جديدة',
            ),
          ),
        );
        return;
      }

      final invitedRole =
          (pendingUserData['role'] ?? 'viewer').toString();

      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('لم يتم إنشاء المستخدم');
      }

      await _saveUserDocument(
        user: user,
        defaultRole: invitedRole,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء حساب المستخدم بنجاح'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyErrorMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Image.asset(
          'assets/images/poultry_logo.png',
          height: 90,
        ),
        const SizedBox(height: 12),
        const Text(
          'Poultry ERP',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'نظام إدارة مزارع الدواجن',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLogo(),
            const SizedBox(height: 28),
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
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _signIn,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(isLoading ? 'جاري الدخول...' : 'تسجيل الدخول'),
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : _createInvitedUserAccount,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('إنشاء حساب مستخدم بدعوة'),
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : _createFirstAdmin,
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('إنشاء أول مدير للنظام'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'استخدم زر إنشاء أول مدير مرة واحدة فقط عند بدء النظام.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade50,
                Colors.white,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _buildLoginCard(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}