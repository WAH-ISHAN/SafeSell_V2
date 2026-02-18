import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'connectivity_service.dart';

/// Authentication handling error types.
enum AuthError {
  network,
  userNotFound,
  wrongPassword,
  emailAlreadyInUse,
  tooManyRequests,
  weakPassword,
  invalidEmail,
  userDisabled,
  accountExistsWithDifferentCredential,
  operationNotAllowed,
  unknown,
  cancelled,
  offline,
}

/// Service for handling all authentication flows.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Login with email and password.
  Future<UserCredential> loginWithEmail(String email, String password) async {
    if (!await _checkOnline()) throw AuthException(AuthError.offline);

    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } catch (e) {
      throw AuthException(AuthError.unknown, message: e.toString());
    }
  }

  /// Register with email and password.
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    if (!await _checkOnline()) throw AuthException(AuthError.offline);

    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } catch (e) {
      throw AuthException(AuthError.unknown, message: e.toString());
    }
  }

  /// Login with Google.
  Future<UserCredential?> loginWithGoogle() async {
    if (!await _checkOnline()) throw AuthException(AuthError.offline);

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in flow
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') {
        return null; // Silent cancel
      } else if (e.code == 'network_error') {
        throw AuthException(AuthError.network);
      }
      throw AuthException(AuthError.unknown, message: e.message);
    } catch (e) {
      throw AuthException(AuthError.unknown, message: e.toString());
    }
  }

  /// Send password reset email.
  Future<void> sendPasswordReset(String email) async {
    if (!await _checkOnline()) throw AuthException(AuthError.offline);

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } catch (e) {
      throw AuthException(AuthError.unknown, message: e.toString());
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      // Ignore errors on sign out
    }
  }

  /// Check connectivity before attempting auth.
  Future<bool> _checkOnline() async {
    return await ConnectivityService.instance.checkNow();
  }

  /// Map Firebase errors to internal AuthError type.
  AuthException _mapFirebaseError(FirebaseAuthException e) {
    AuthError error;
    switch (e.code) {
      case 'user-not-found':
      case 'auth/user-not-found':
        error = AuthError.userNotFound;
        break;
      case 'wrong-password':
      case 'auth/wrong-password':
        error = AuthError.wrongPassword;
        break;
      case 'email-already-in-use':
      case 'auth/email-already-in-use':
        error = AuthError.emailAlreadyInUse;
        break;
      case 'weak-password':
      case 'auth/weak-password':
        error = AuthError.weakPassword;
        break;
      case 'invalid-email':
      case 'auth/invalid-email':
        error = AuthError.invalidEmail;
        break;
      case 'user-disabled':
      case 'auth/user-disabled':
        error = AuthError.userDisabled;
        break;
      case 'too-many-requests':
      case 'operation-not-allowed':
        error = AuthError.tooManyRequests;
        break;
      case 'network-request-failed':
        error = AuthError.network;
        break;
      case 'account-exists-with-different-credential':
        error = AuthError.accountExistsWithDifferentCredential;
        break;
      default:
        error = AuthError.unknown;
    }
    return AuthException(error, message: e.message);
  }
}

/// Custom Exception for Auth faults.
class AuthException implements Exception {
  final AuthError code;
  final String? message;

  AuthException(this.code, {this.message});

  @override
  String toString() {
    return 'AuthException: $code ($message)';
  }

  /// User-friendly error message.
  String get userMessage {
    switch (code) {
      case AuthError.network:
        return 'Network error. Please check your connection.';
      case AuthError.userNotFound:
        return 'No account found with this email.';
      case AuthError.wrongPassword:
        return 'Incorrect password. Please try again.';
      case AuthError.emailAlreadyInUse:
        return 'This email is already registered.';
      case AuthError.weakPassword:
        return 'Password is too weak. Try a stronger one.';
      case AuthError.invalidEmail:
        return 'Invalid email address format.';
      case AuthError.userDisabled:
        return 'This account has been disabled.';
      case AuthError.tooManyRequests:
        return 'Too many attempts. Please try again later.';
      case AuthError.offline:
        return 'You are offline. Please connect to internet.';
      case AuthError.accountExistsWithDifferentCredential:
        return 'Account exists with a different sign-in method.';
      case AuthError.cancelled:
        return 'Sign-in cancelled.';
      case AuthError.unknown:
      case AuthError.operationNotAllowed:
        return message ?? 'An unknown error occurred. Please try again.';
    }
  }
}
