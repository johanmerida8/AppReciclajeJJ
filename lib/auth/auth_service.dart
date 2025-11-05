import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // password reset constraints
  static const int RESET_COOLDOWN_MINUTES = 15;
  static const int MAX_DAILY_RESETS = 3;

  // sign in with email and password
  Future<AuthResponse> signInWithEmailPassword(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up and also create (or update) the users row with the given role.
  /// Note: in production prefer doing user creation/upsert server-side.
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password,
    String name, {
    String role = 'distribuidor',
  }) async {
    try {
      // 1) Crear auth user
      final response = await _supabase.auth.signUp(email: email, password: password);

      // 2) Si el auth user fue creado (response.user != null), aseguramos la fila en 'users'
      if (response.user != null) {
        final userRow = {
          'names': name,
          'email': email,
          'role': role,
          'state': 1,
          'created_at': DateTime.now().toIso8601String(),
        };

        try {
          // Intentamos insertar. Si tu SDK soporta upsert, puedes usar upsert en vez de insert.
          await _supabase.from('users').insert(userRow);
        } catch (insertError) {
          // Si falla por clave duplicada (email único), intentamos hacer update para sincronizar role/nombre
          // Dependiendo del error que retorna Postgres/Supabase, puedes detectar el mensaje; aquí hacemos una actualización segura:
          try {
            await _supabase
                .from('users')
                .update({
                  'names': name,
                  'role': role,
                  'state': 1,
                })
                .eq('email', email);
          } catch (updateError) {
            // si update también falla, mostramos/loggeamos para depuración
            print('Error upserting user row: $updateError');
            // no rethrow porque queremos devolver el response de auth aunque la fila users tenga problema;
            // si prefieres, puedes rethrow para que el caller lo maneje.
          }
        }
      }

      return response;
    } catch (e) {
      print('Error en signUpWithEmailPassword: $e');
      rethrow;
    }
  }

  // fetch role
  Future<String?> fetchUserRole(String email) async {
    print('🔍 AUTH_SERVICE: Fetching role for email: $email');
    
    final response = await _supabase
      .from('users')
      .select('role, state')
      .eq('email', email)
      .maybeSingle();
    
    print('🔍 AUTH_SERVICE: Response from DB: $response');
    
    if (response != null && response['role'] != null) {
      final role = response['role'] as String;
      print('🔍 AUTH_SERVICE: Returning role: "$role"');
      return role;
    }
    
    print('❌ AUTH_SERVICE: No role found, returning null');
    return null;
  }

  // check if user is approved (state = 1)
  Future<bool> isUserApproved(String email) async {
    final response = await _supabase
      .from('users')
      .select('state')
      .eq('email', email)
      .maybeSingle();
    
    if (response != null && response['state'] != null) {
      return response['state'] == 1;
    }
    return false;
  }

  // sign out
  Future<void> signOut() async => await _supabase.auth.signOut();

  // get user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  // ============================================================================
  // 🆕 SUPABASE BUILT-IN OTP & PASSWORD RESET
  // ============================================================================

  /// Send OTP to email for password reset verification
  /// Uses Supabase's built-in email OTP (free, unlimited)
  /// OTP expires in 60 seconds by default (configurable in Supabase Dashboard)
  /// 
  /// ⚠️ IMPORTANT: This does NOT store OTP in database!
  /// Supabase handles OTP codes internally - no OTP table needed
  Future<void> sendOTPToEmail(String email) async {
    try {
      print('📧 Sending Supabase OTP to: $email');
      print('⚠️ NOTE: OTP will NOT appear in database - Supabase handles it internally');
      
      // 🎯 IMPORTANT: Use shouldCreateUser: false to only send OTP (not magic link)
      await _supabase.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false, // This ensures OTP code is sent, not a magic link
        emailRedirectTo: null, // No redirect needed for OTP
      );
      
      print('✅ OTP sent successfully to: $email');
      print('💡 Check your email for the 6-digit code (expires in 60 seconds)');
    } catch (e) {
      print('❌ Error sending OTP: $e');
      throw Exception('Failed to send OTP: $e');
    }
  }

  /// Verify OTP code entered by user
  /// Returns true if OTP is valid, false otherwise
  /// 
  /// ⚠️ This verifies against Supabase's internal OTP system (NOT database table)
  Future<bool> verifySupabaseOTP(String email, String otp) async {
    try {
      print('🔍 Verifying OTP for: $email');
      print('🔍 OTP code entered: $otp');
      
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        email: email,
        token: otp,
      );
      
      if (response.session != null) {
        print('✅ OTP verified successfully for: $email');
        print('✅ User authenticated with session ID: ${response.session!.accessToken.substring(0, 20)}...');
        return true;
      }
      
      print('❌ Invalid OTP for: $email');
      return false;
    } catch (e) {
      print('❌ Error verifying OTP: $e');
      return false;
    }
  }

  /// Update password after successful OTP verification
  /// User must be authenticated (via OTP) before calling this
  Future<void> updatePasswordAfterSupabaseOTP(String newPassword) async {
    try {
      // Check if user is authenticated
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User must be authenticated to update password');
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      print('✅ Password updated successfully');
    } catch (e) {
      print('❌ Error updating password: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  /// Send password reset email with clickable link
  /// ⏱️ Link expires in 1 HOUR (Supabase default, configurable up to 24 hours)
  /// 
  /// IMPORTANT: Configure Supabase Dashboard first:
  /// 1. Go to Authentication → Email Templates → "Reset Password"
  /// 2. Customize the template (optional)
  /// 3. Set redirect URL in Settings → Authentication → Site URL
  /// 
  /// This method is FREE, unlimited, and requires NO external email service
  /// 
  /// Flow:
  /// 1. User enters email
  /// 2. Supabase sends email with reset link
  /// 3. User clicks link → App opens → Deep link captured
  /// 4. App extracts access_token from URL
  /// 5. User sets new password
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      // Check rate limits first
      final eligibility = await canRequestPasswordReset(email);
      
      if (eligibility['canReset'] != true) {
        return {
          'success': false,
          'message': eligibility['message'],
          'reason': eligibility['reason'],
        };
      }

      // Send password reset email (link expires in 1 hour)
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'reciclaje://reset-password', // Deep link to your app
      );

      // Log the attempt
      await logPasswordResetAttempt(email);

      print('✅ Password reset email sent to: $email (link expires in 1 hour)');
      
      return {
        'success': true,
        'message': 'Se ha enviado un correo para restablecer la contraseña. El enlace expira en 1 hora.',
        'attemptsToday': (eligibility['attemptsToday'] ?? 0) + 1,
      };
    } catch (e) {
      print('❌ Error sending password reset email: $e');
      return {
        'success': false,
        'message': 'Error al enviar el correo: $e',
        'error': e.toString(),
      };
    }
  }

  /// Update password after user clicks reset link
  /// This should be called after deep link is captured
  Future<void> updatePasswordFromResetLink(String newPassword) async {
    try {
      // User is automatically authenticated via the reset link token
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      print('✅ Password updated successfully from reset link');
    } catch (e) {
      print('❌ Error updating password: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  // ============================================================================
  // 🗑️ DEPRECATED - OLD METHODS (Don't use these anymore!)
  // ============================================================================
  // These methods use SendGrid edge function and custom OTP table
  // They are kept for backward compatibility only
  // ⚠️ USE sendOTPToEmail() INSTEAD (Supabase built-in, free, unlimited)
  // ============================================================================

  /// ❌ DEPRECATED: Use sendOTPToEmail() instead
  /// This method uses SendGrid edge function which requires payment
  /// Expiration: 15 minutes (stored in custom OTP table)
  @Deprecated('Use sendOTPToEmail() instead - Supabase built-in OTP')
  Future<String> generateAndSendOTP(String email) async {
    // clean up expired OTPs before generating a new one
    await cleanupExpiredOTPs();

    // generate 6-digit OTP
    final otp = (100000 + Random().nextInt(900000)).toString();

    try {
      // store OTP in database with expiration time (15 minutes)
      await _supabase.from('OTP').insert({
        'email': email,
        'token': otp,
        'expires_at': DateTime.now().add(Duration(minutes: 15)).toIso8601String(),
        'used': false,
      });
      // ⚠️ REQUIRES SendGrid edge function 'resend-email' (not free)
      await _supabase.functions.invoke('resend-email', body: {
        'email': email,
        'otp': otp,
      });
      return otp;
    } catch (e) {
      throw Exception('Failed to generate and send OTP: $e');
    }
  }

  /// ❌ DEPRECATED: Use verifySupabaseOTP() instead
  /// This method checks custom OTP table (15-minute expiration)
  @Deprecated('Use verifySupabaseOTP() instead - Supabase built-in OTP')
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

  Future<Map<String, dynamic>> canRequestPasswordReset(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();

      // check last reset attempt
      final lastResetResponse = await _supabase
          .from('password_logs')
          .select('reset_requested_at')
          .eq('email', normalizedEmail)
          .order('reset_requested_at', ascending: false)
          .limit(1);
      
      if (lastResetResponse.isNotEmpty) {
        final lastResetTime = DateTime.parse(lastResetResponse.first['reset_requested_at']);
        final timeDifference = DateTime.now().difference(lastResetTime);

        print('Last reset time: $lastResetTime');
        print('Time since last reset: ${timeDifference.inMinutes} minutes');

        if (timeDifference.inMinutes < RESET_COOLDOWN_MINUTES) {
          final remainingMinutes = RESET_COOLDOWN_MINUTES - timeDifference.inMinutes;
          return {
            'canRequest': false,
            'reason': 'cooldown',
            'remainingMinutes': remainingMinutes,
            'message': 'Por favor espera $remainingMinutes minutos antes de intentar de nuevo.'
          };
        }
      }

      // check daily limit
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final dailyAttemptsResponse = await _supabase
          .from('password_logs')
          .select('idLog')
          .eq('email', normalizedEmail)
          .gte('reset_requested_at', startOfDay.toIso8601String());
      
      if (dailyAttemptsResponse.length >= MAX_DAILY_RESETS) {
        return {
          'canRequest': false,
          'reason': 'daily_limit',
          'attempts': dailyAttemptsResponse.length,
          'message': 'Has alcanzado el límite diario de $MAX_DAILY_RESETS intentos. Por favor intenta de nuevo mañana.'
        };
      }

      return {
        'canReset': true,
        'attemptsToday': dailyAttemptsResponse.length,
        'message': 'Puedes solicitar el restablecimiento'
      };
    } catch (e) {
      print('Error checking password reset eligibility: $e');
      return {
        'canReset': false,
        'reason': 'error',
        'message': 'Error al verificar los intentos de restablecimiento: $e',
        'error': e.toString(),
      };
    }
  }

  // log password reset attempt
  Future<void> logPasswordResetAttempt(String email) async {
    try {
      await _supabase.from('password_logs').insert({
        'email': email.toLowerCase().trim(),
        'reset_requested_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Failed to log password reset attempt: $e');
    }
  }

  Future<Map<String, dynamic>> resetPasswordForEmail(String email) async {
    try {
      // check if user can request password reset
      final eligibility = await canRequestPasswordReset(email);

      if (!eligibility['canReset']) {
        return {
          'success': false,
          'message': eligibility['message'],
          'reason': eligibility['reason'],
        };
      }

      // proceed with password reset
      await _supabase.auth.resetPasswordForEmail(email);

      // log the attempt
      await logPasswordResetAttempt(email);
      
      return {
        'success': true,
        'message': 'Se ha enviado un correo para restablecer la contraseña si el correo existe en nuestro sistema!',
        'attemptsToday': eligibility['attemptsToday'] + 1,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al solicitar el restablecimiento de la contraseña: $e',
        'error': e.toString(),
      };
    }
  }

  // clean up expired OTPS
  Future<void> cleanupExpiredOTPs() async {
    try {
      final now = DateTime.now();

      // delete expired OTPs
      await _supabase
          .from('OTP')
          .delete()
          .lt('expires_at', now.toIso8601String());
      
      // also delete used OTPs older than 1 hour
      final oneHourAgo = now.subtract(const Duration(hours: 1));
      await _supabase
          .from('OTP')
          .delete()
          .eq('used', true)
          .lt('expires_at', oneHourAgo.toIso8601String());
      
      print('OTP limpeza completada');
    } catch (e) {
      print('Error en la limpieza de OTPs: $e');
    }
  }

  // clean up old password logs (call periodically)
  Future<void> cleanupOldPasswordLogs() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      await _supabase
          .from('password_logs')
          .delete()
          .lt('reset_requested_at', thirtyDaysAgo.toIso8601String());
    } catch (e) {
      print('Error en la limpieza de registros antiguos: $e');
    }
  }

  // clean up method - call periodically
  Future<void> performDatabaseCleanup() async {
    try {
      await Future.wait([
        cleanupExpiredOTPs(),
        cleanupOldPasswordLogs(),
      ]);
      print('La limpieza de logs y otps se ha completado.');
    } catch (e) {
      print('Error durante la limpieza de base de datos: $e');
    }
  }
}