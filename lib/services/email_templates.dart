/// Email templates for the Reciclaje App
class EmailTemplates {
  /// Generate HTML email for employee temporary password
  static String employeeTemporaryPassword({
    required String employeeName,
    required String email,
    required String temporaryPassword,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #2D8A8A; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
    .credentials-box { background-color: white; padding: 20px; margin: 20px 0; border-radius: 8px; border: 2px solid #2D8A8A; }
    .password-box { background-color: #fff3cd; padding: 15px; margin: 15px 0; border-radius: 8px; border-left: 4px solid #ffc107; }
    .warning { background-color: #fff3cd; padding: 15px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #ff9800; }
    .button { display: inline-block; padding: 12px 24px; background-color: #2D8A8A; color: white; text-decoration: none; border-radius: 8px; margin: 20px 0; }
    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🌿 Bienvenido a Reciclaje App</h1>
    </div>
    <div class="content">
      <h2>Hola, $employeeName!</h2>
      <p>Tu cuenta de empleado ha sido creada exitosamente.</p>
      
      <div class="credentials-box">
        <h3>📧 Credenciales de Acceso</h3>
        <p><strong>Correo:</strong> $email</p>
      </div>
      
      <div class="password-box">
        <h3>🔑 Contraseña Temporal</h3>
        <p style="font-size: 24px; font-family: monospace; letter-spacing: 2px; text-align: center; margin: 10px 0;">
          <strong>$temporaryPassword</strong>
        </p>
      </div>
      
      <div class="warning">
        <p><strong>⚠️ IMPORTANTE:</strong></p>
        <ul>
          <li>Debes cambiar esta contraseña en tu primer inicio de sesión</li>
          <li>Por seguridad, no compartas tus credenciales con nadie</li>
          <li>Si no solicitaste esta cuenta, por favor contacta a tu administrador</li>
        </ul>
      </div>
      
      <p>Descarga la aplicación e inicia sesión con las credenciales proporcionadas.</p>
      
      <div class="footer">
        <p>Este es un correo automático, por favor no respondas a este mensaje.</p>
        <p>&copy; 2025 Reciclaje App. Todos los derechos reservados.</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Generate HTML email for password reset
  static String passwordReset({
    required String userName,
    required String resetCode,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background-color: #2D8A8A; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background-color: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
    .code-box { background-color: white; padding: 20px; margin: 20px 0; border-radius: 8px; border: 2px solid #2D8A8A; text-align: center; }
    .warning { background-color: #fff3cd; padding: 15px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #ff9800; }
    .footer { text-align: center; margin-top: 30px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔐 Restablecer Contraseña</h1>
    </div>
    <div class="content">
      <h2>Hola, $userName!</h2>
      <p>Recibimos una solicitud para restablecer tu contraseña.</p>
      
      <div class="code-box">
        <h3>Tu código de verificación:</h3>
        <p style="font-size: 32px; font-family: monospace; letter-spacing: 4px; margin: 10px 0;">
          <strong>$resetCode</strong>
        </p>
      </div>
      
      <div class="warning">
        <p><strong>⚠️ IMPORTANTE:</strong></p>
        <ul>
          <li>Este código expirará en 15 minutos</li>
          <li>Si no solicitaste este cambio, ignora este correo</li>
          <li>Nunca compartas este código con nadie</li>
        </ul>
      </div>
      
      <div class="footer">
        <p>Este es un correo automático, por favor no respondas a este mensaje.</p>
        <p>&copy; 2025 Reciclaje App. Todos los derechos reservados.</p>
      </div>
    </div>
  </div>
</body>
</html>
''';
  }

  /// Generate plain text email for employee credentials (fallback)
  static String employeeTemporaryPasswordPlainText({
    required String employeeName,
    required String email,
    required String temporaryPassword,
  }) {
    return '''
🌿 Reciclaje App - Credenciales de Acceso

Hola, $employeeName!

Tu cuenta de empleado ha sido creada exitosamente.

📧 Credenciales de Acceso:
Correo: $email

🔑 Contraseña Temporal:
$temporaryPassword

⚠️ IMPORTANTE:
- Debes cambiar esta contraseña en tu primer inicio de sesión
- Por seguridad, no compartas tus credenciales con nadie
- Si no solicitaste esta cuenta, por favor contacta a tu administrador

Descarga la aplicación e inicia sesión con las credenciales proporcionadas.

---
Este es un correo automático, por favor no respondas a este mensaje.
© 2025 Reciclaje App. Todos los derechos reservados.
''';
  }
}
