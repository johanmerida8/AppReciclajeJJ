import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // sign in with email and password
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // sign up with email and password
  Future<AuthResponse> signUpWithEmailPassword(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // get user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  // generate and send otp
  Future<String> generateAndSendOTP(String email) async {
    // generate 6-digit OTP
    final otp = (100000 + Random().nextInt(900000)).toString();

    try {
      // store OTP in database with expiration time
      await _supabase.from('OTP').insert({
        'email': email,
        'token': otp,
        'expires_at': DateTime.now().add(Duration(minutes: 15)).toIso8601String(),
        'used': false,
      });
      // send OTP via email using Supabase's built-in email service
      await _supabase.functions.invoke('resend-email', body: {
        'email': email,
        'otp': otp,
      });
      return otp;
    } catch (e) {
      throw Exception('Failed to generate and send OTP: $e');
    }
  }

  Future<bool> verifyOTP(String email, String otp) async {
    try {
      final res = await _supabase
          .from('OTP')
          .select()
          .eq('email', email)
          .eq('token', otp)
          .eq('used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();
      
      if (res != null) {
        // ✅ Mark OTP as used here since verification is successful
        await _supabase
            .from('OTP')
            .update({'used': true})
            .eq('token', otp)
            .eq('email', email);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to verify OTP: $e');
    }
  }

  Future<void> updatePassword(String email, String newPassword) async {
    try {

      final res = await _supabase.functions.invoke('reset-user-password', body: {
        'email': email,
        'newPassword': newPassword,
      });

      // check if there was an error in the function response
      if (res.data != null && res.data['error'] != null) {
        throw Exception(res.data['error']);
      }

    } catch (e) {
      throw Exception('Error al actualizar la contraseña: $e');
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email
    );
  }
}