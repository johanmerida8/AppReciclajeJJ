# 🎯 Quick Setup Guide - OTP Email Template

## ⚡ 3-Minute Setup

### 1️⃣ Go to Supabase Dashboard
- Navigate to: **Authentication** → **Email Templates**
- Click on: **"Magic link"** tab

### 2️⃣ Copy & Paste Template
Choose one of these templates from the `/email_templates/` folder:

- **`magic_link_otp_template.html`** - Full-featured with styling ✨
- **`magic_link_otp_simple.html`** - Simple, mobile-friendly 📱

### 3️⃣ Save & Test
- Click **"Save"** in Supabase
- Go to your app → "Recover Password"
- Enter your email
- Check inbox for styled OTP email

---

## 🔑 The Magic Variable

The **most important part** of the template is:

```html
{{ .Token }}
```

This gets replaced with your 6-digit OTP code like: `501516`

**MUST BE EXACTLY:**
- ✅ `{{ .Token }}` (with dot and spaces)
- ❌ NOT `{{.Token}}` (no spaces)
- ❌ NOT `{{ Token }}` (no dot)
- ❌ NOT `{{ token }}` (lowercase)

---

## 📋 Checklist

Before testing, verify:

- [ ] Supabase Dashboard → Authentication → Settings → Email Auth = **"OTP"** (not Magic Link)
- [ ] Email template saved in **"Magic link"** tab
- [ ] Template contains `{{ .Token }}` exactly
- [ ] App restarted (hot restart)

---

## 🎨 Customization

### Change App Color
Find this line in the template:
```html
style="color: #2D8A8A"
```
Replace `#2D8A8A` with your brand color

### Change Expiration Time
In the template:
```html
Expira en <strong>60 segundos</strong>
```

To change actual expiration time:
1. Go to Supabase Dashboard
2. Settings → Authentication
3. Find "OTP Expiry"
4. Change from 60 to desired seconds (max 86400 = 24 hours)

### Add Your Logo
Replace the emoji header:
```html
<h1>🌿 Reciclaje App</h1>
```

With an image:
```html
<img src="https://your-domain.com/logo.png" alt="Logo" width="120">
```

---

## 📧 Email Preview

After saving, your users will receive:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━
    🌿 Reciclaje App
━━━━━━━━━━━━━━━━━━━━━━━━━━

Código de Verificación

Hola,

Has solicitado restablecer tu
contraseña. Usa el siguiente
código:

┌─────────────────────────┐
│   Tu código             │
│                         │
│   5  0  1  5  1  6      │
│                         │
│   ⏱️ Expira en 60 seg   │
└─────────────────────────┘

🔒 Si no solicitaste este
código, ignora este correo.

━━━━━━━━━━━━━━━━━━━━━━━━━━
Reciclaje App
━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 🚨 Troubleshooting

| Problem | Solution |
|---------|----------|
| Shows `{{ .Token }}` literally | Auth method is "Magic Link", change to "OTP" |
| Shows link instead of code | Wrong template or wrong auth method |
| Email doesn't arrive | Check spam, verify email in users table |
| Code doesn't work | Code expired (60 sec), request new one |

---

## 📱 Mobile Testing

Test on different email clients:
- ✅ Gmail (Android/iOS)
- ✅ Outlook
- ✅ Apple Mail
- ✅ Yahoo Mail

---

## 🔗 Files Created

1. **`SUPABASE_EMAIL_TEMPLATE_SETUP.md`** - Full documentation
2. **`email_templates/magic_link_otp_template.html`** - Styled template
3. **`email_templates/magic_link_otp_simple.html`** - Simple template
4. **`QUICK_SETUP.md`** - This file

---

**Ready to implement?** Copy the HTML template to Supabase now! 🚀
