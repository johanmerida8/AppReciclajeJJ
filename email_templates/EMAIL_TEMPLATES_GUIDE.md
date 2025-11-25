# Email Templates System - Configuration Guide

This directory contains HTML email templates used by the Reciclaje App Supabase backend.

## Available Templates

### 1. OTP Code Template (`magic_link_otp_template.html`)
**Purpose:** Send 6-digit OTP codes for password reset  
**Expiration:** 60 seconds  
**Use Case:** When user requests password reset from login screen  

**Template Variables:**
- `{{ .Token }}` - The 6-digit OTP code

**Supabase Configuration:**
1. Go to Authentication → Email Templates → Magic Link (OTP)
2. Copy contents of `magic_link_otp_template.html`
3. Paste into the template editor
4. Save

---

### 2. Employee Temporary Password (`employee_temporary_password.html`)
**Purpose:** Send temporary password to newly created employees  
**Expiration:** No expiration (valid until changed)  
**Use Case:** When company admin creates a new employee account  

**Template Variables:**
- `{{ .Token }}` - The 8-character temporary password
- `{{ .Email }}` - The employee's email address

**Supabase Configuration:**
1. Go to Authentication → Email Templates
2. Look for "Password Recovery" or create custom template type
3. Copy contents of `employee_temporary_password.html`
4. Paste into the template editor
5. Save

---

## Template Variable Reference

All templates use Supabase's Go template syntax for variable replacement:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{ .Token }}` | Dynamic token/password/code | `123456` or `Abc12345` |
| `{{ .Email }}` | User's email address | `empleado@example.com` |
| `{{ .SiteURL }}` | Your app's base URL | `https://yourapp.com` |
| `{{ .ConfirmationURL }}` | Magic link confirmation URL | Full URL with token |

## Design System

### Brand Colors
- **Primary:** `#2D8A8A` (Teal) - Headers, important text, buttons
- **Background:** `#f5f5f5` (Light gray) - Email body
- **Card Background:** `#ffffff` (White) - Content containers
- **Warning:** `#ffc107` (Amber) - Important notices
- **Warning Background:** `#fff3cd` (Light amber)

### Typography
- **Headers:** Arial, sans-serif, 22px
- **Body:** Arial, sans-serif, 14-15px
- **Codes/Passwords:** 'Courier New', monospace, 28px with letter-spacing

### Layout
- **Max Width:** 480px
- **Padding:** 25px inside cards
- **Border Radius:** 10px for cards, 8px for inner elements

## Testing Templates

### Test OTP Template:
```sql
-- In Supabase SQL Editor
SELECT auth.send_magic_link(
  'user@example.com',
  'password_recovery'
);
```

### Test Employee Temporary Password:
1. Create employee through app UI
2. Check employee's email inbox
3. Verify template renders correctly with password visible

## Troubleshooting

### Variables Not Replacing
- ✅ Use exact syntax: `{{ .Token }}` with spaces
- ✅ Verify template is saved in correct Supabase section
- ❌ Don't use `{{.Token}}` without spaces
- ❌ Don't use custom variable names not supported by Supabase

### Email Not Sending
1. Check Supabase SMTP settings (Settings → Auth → SMTP)
2. Verify template is enabled
3. Check email rate limits
4. Review Supabase logs for errors

### Template Looks Broken
- Ensure HTML is valid (close all tags)
- Test in email clients (Gmail, Outlook, mobile)
- Use inline CSS (email clients strip `<style>` blocks)
- Avoid complex layouts (use tables for structure)

## Email Client Compatibility

These templates are tested and compatible with:
- ✅ Gmail (Web, iOS, Android)
- ✅ Outlook (Web, Desktop)
- ✅ Apple Mail (iOS, macOS)
- ✅ Yahoo Mail
- ✅ Mobile email clients

## Security Best Practices

1. **OTP Codes:** Short expiration (60s) reduces attack window
2. **Temporary Passwords:** Force change on first login
3. **No Clickable Links:** Prevents phishing (users type credentials manually)
4. **Clear Instructions:** Reduces support tickets and user errors
5. **Warning Messages:** Remind users not to share credentials

## Customization

To customize templates:
1. Edit HTML files in this directory
2. Test locally by opening in browser
3. Copy updated template to Supabase
4. Send test email to verify
5. Commit changes to version control

---

**Last Updated:** January 2025  
**Maintained By:** Reciclaje App Development Team
