import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:mailer/smtp_server.dart';

final gmailSmtp = gmail(dotenv.env["GMAIL_MAIL"]!, dotenv.env["GMAIL_PASSWORD"]!);
final outlookSmtp = SmtpServer(
  'smtp-mail.outlook.com',
  port: 587,
  username: dotenv.env["OUTLOOK_EMAIL"]!,
  password: dotenv.env["OUTLOOK_PASSWORD"]!,
  ignoreBadCertificate: false,
  ssl: false,
  allowInsecure: true,
);

Future<bool> sendMailFromGmail({
  required String recipientEmail,
  required String recipientName,
  required String subject,
  required String htmlBody,
}) async {
  try {
    print('📧 Attempting to send email via Gmail...');
    print('   From: ${dotenv.env["GMAIL_MAIL"]!}');
    print('   To: $recipientEmail');
    print('   Subject: $subject');
    
    final message = Message()
      ..from = Address(dotenv.env["GMAIL_MAIL"]!, 'Reciclaje App')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..html = htmlBody;

    print('📨 Sending email via Gmail SMTP...');
    final sendReport = await send(message, gmailSmtp);
    print('✅ Email sent successfully via Gmail: ${sendReport.toString()}');
    return true;
  } catch (e) {
    print('❌ Error sending email via Gmail: $e');
    print('   Stack trace: ${StackTrace.current}');
    return false;
  }
}

// Future<bool> sendMailFromOutlook({
//   required String recipientEmail,
//   required String recipientName,
//   required String subject,
//   required String htmlBody,
// }) async {
//   try {
//     print('📧 Attempting to send email via Outlook...');
//     print('   From: ${dotenv.env["OUTLOOK_EMAIL"]!}');
//     print('   To: $recipientEmail');
//     print('   Subject: $subject');
    
//     final message = Message()
//       ..from = Address(dotenv.env["OUTLOOK_EMAIL"]!, 'Reciclaje App')
//       ..recipients.add(recipientEmail)
//       ..subject = subject
//       ..html = htmlBody;

//     print('📨 Sending email via Outlook SMTP...');
//     final sendReport = await send(message, outlookSmtp);
//     print('✅ Email sent successfully via Outlook: ${sendReport.toString()}');
//     return true;
//   } catch (e) {
//     print('❌ Error sending email via Outlook: $e');
//     print('   Stack trace: ${StackTrace.current}');
//     return false;
//   }
// }