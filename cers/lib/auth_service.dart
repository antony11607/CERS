import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/user/home_screen.dart';
import 'screens/volunteer/volunteer_dashboard_screen.dart';

enum LoginType { user, volunteer }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> login({
    required String email,
    required String password,
    required LoginType loginType,
    required BuildContext context,
  }) async {
    // Validate inputs first
    if (!_validateEmail(email)) {
      _showErrorDialog(
        context,
        'Invalid Email',
        'Please enter a valid email address.',
      );
      return;
    }

    if (password.isEmpty) {
      _showErrorDialog(
        context,
        'Invalid Password',
        'Please enter your password.',
      );
      return;
    }

    if (password.length < 6) {
      _showErrorDialog(
        context,
        'Invalid Password',
        'Password must be at least 6 characters.',
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE31E24)),
        ),
      ),
    );

    try {
      // Sign in with Firebase Auth
      print('[Login] Selected Role: ${loginType == LoginType.user ? "User" : "Volunteer"}');
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      print('[Firebase] Authentication Successful');
      
      // Get the authenticated user's UID
      String? uid = userCredential.user?.uid;
      print('[Firebase] UID: $uid');

      if (uid == null) {
        _hideLoading(context);
        _showErrorDialog(
          context,
          'Authentication Error',
          'Failed to get user ID. Please try again.',
        );
        return;
      }

      // Route to appropriate handler based on login type
      if (loginType == LoginType.user) {
        await _handleUserLogin(context, uid);
      } else {
        await _handleVolunteerLogin(context, uid);
      }
    } on FirebaseAuthException catch (e) {
      _hideLoading(context);
      print('[Firebase] Authentication Failed: ${e.code} - ${e.message}');
      _showErrorDialog(context, 'Login Error', _getFirebaseAuthErrorMessage(e));
    } catch (e) {
      _hideLoading(context);
      print('[Error] Unexpected error: ${e.toString()}');
      _showErrorDialog(
        context,
        'Error',
        'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<void> _handleUserLogin(BuildContext context, String uid) async {
    try {
      print('[Firestore] Searching collection: user');
      print('[Firestore] Document ID: $uid');
      
      // Check 'user' collection (singular - matches Firestore)
      DocumentSnapshot userDoc = await _firestore
          .collection('user')
          .doc(uid)
          .get();

      print('[Firestore] Document Exists: ${userDoc.exists}');

      _hideLoading(context);

      if (userDoc.exists) {
        print('[Navigation] Opening Home Screen');
        // User exists, navigate to home screen
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        print('[Navigation] User account not found in Firestore');
        // User doesn't exist in Firestore
        if (context.mounted) {
          _showErrorDialog(
            context,
            'Account Not Found',
            'User account not found.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _hideLoading(context);
      print('[Firebase] Auth Error: ${e.code}');
      _showErrorDialog(
        context,
        'Authentication Error',
        _getFirebaseAuthErrorMessage(e),
      );
    } on FirebaseException catch (e) {
      _hideLoading(context);
      print('[Firestore] Permission Error: ${e.code} - ${e.message}');
      _showErrorDialog(
        context,
        'Database Error',
        'Permission denied. Please check your account settings.',
      );
    } catch (e) {
      _hideLoading(context);
      print('[Error] User verification failed: ${e.toString()}');
      _showErrorDialog(
        context,
        'Error',
        'Failed to verify user account: ${e.toString()}',
      );
    }
  }

  Future<void> _handleVolunteerLogin(BuildContext context, String uid) async {
    try {
      print('[Firestore] Searching collection: volunteers');
      print('[Firestore] Document ID: $uid');
      
      // Check 'volunteers' collection (plural)
      DocumentSnapshot volunteerDoc = await _firestore
          .collection('volunteers')
          .doc(uid)
          .get();

      print('[Firestore] Document Exists: ${volunteerDoc.exists}');

      _hideLoading(context);

      if (volunteerDoc.exists) {
        // Check if volunteer is approved
        Map<String, dynamic> volunteerData =
            volunteerDoc.data() as Map<String, dynamic>;
        bool isApproved = volunteerData['isApproved'] ?? false;
        
        print('[Firestore] isApproved: $isApproved');

        if (isApproved) {
          print('[Navigation] Opening Volunteer Dashboard');
          // Volunteer is approved, navigate to volunteer dashboard
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const VolunteerDashboardScreen(),
              ),
            );
          }
        } else {
          print('[Navigation] Volunteer not approved');
          // Volunteer exists but not approved
          if (context.mounted) {
            _showErrorDialog(
              context,
              'Account Under Review',
              'Your volunteer application is still under review.',
            );
          }
        }
      } else {
        print('[Navigation] Volunteer account not found in Firestore');
        // Volunteer doesn't exist in Firestore
        if (context.mounted) {
          _showErrorDialog(
            context,
            'Account Not Found',
            'Volunteer account not found.',
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _hideLoading(context);
      print('[Firebase] Auth Error: ${e.code}');
      _showErrorDialog(
        context,
        'Authentication Error',
        _getFirebaseAuthErrorMessage(e),
      );
    } on FirebaseException catch (e) {
      _hideLoading(context);
      print('[Firestore] Permission Error: ${e.code} - ${e.message}');
      _showErrorDialog(
        context,
        'Database Error',
        'Permission denied. Please check your account settings.',
      );
    } catch (e) {
      _hideLoading(context);
      print('[Error] Volunteer verification failed: ${e.toString()}');
      _showErrorDialog(
        context,
        'Error',
        'Failed to verify volunteer account: ${e.toString()}',
      );
    }
  }

  bool _validateEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  void _hideLoading(BuildContext context) {
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.grey,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF0066CC),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}