import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuditLogService {
  static Future<void> log({
    required String action,
    required String category,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      String? userRole;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        userRole = userDoc.data()?['role']?.toString();
      }

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': action,
        'category': category,
        'description': description,
        'userId': user?.uid,
        'userEmail': user?.email,
        'userRole': userRole,
        'createdAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (_) {
      // لا نوقف العملية الأساسية إذا فشل تسجيل السجل
    }
  }
}