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
    final response = await _supabase
      .from('users')
      .select('role')
      .eq('email', email)
      .maybeSingle();
    
    if (response != null && response['role'] != null) {
      return response['role'] as String;
    }
    return null;
  }

  // sign out
  Future<void> signOut() async => await _supabase.auth.signOut();

  // get user email
  String? getCurrentUserEmail() {
    final session = _supabase.auth.currentSession;
    final user = session?.user;
    return user?.email;
  }

  // get user role

  // generate and send otp
  Future<String> generateAndSendOTP(String email) async {
    // clean up expired OTPs before generating a new one
    await cleanupExpiredOTPs();

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