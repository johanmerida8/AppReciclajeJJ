# Employee State Management - Quick Reference

## 🎯 Three Employee States

### 1️⃣ PENDING PASSWORD SETUP
**Icon**: ⏱️ Orange Clock (not clickable)  
**When**: Admin just created employee, temp password sent  
**Login**: Redirects to password change screen  
**Admin**: Cannot toggle state (shows info dialog)  
**Database**: `state=0` AND `temporaryPassword != null`

### 2️⃣ ACTIVE
**Icon**: 🚫 Orange Person Off (clickable)  
**When**: Employee set permanent password  
**Login**: Allowed ✅  
**Admin**: Can deactivate  
**Database**: `state=1` AND `temporaryPassword = null`

### 3️⃣ DEACTIVATED
**Icon**: ➕ Green Person Add (clickable)  
**When**: Admin deactivated the employee  
**Login**: Blocked ❌ ("cuenta desactivada")  
**Admin**: Can reactivate  
**Database**: `state=0` AND `temporaryPassword = null`

## 🔄 Flow

```
Admin Creates → Pending (⏱️) → Employee Sets Password → Active (🚫)
                                                            ↓
                                                    Admin Deactivates
                                                            ↓
                                                    Deactivated (➕)
                                                            ↓
                                                    Admin Reactivates
                                                            ↓
                                                    Back to Active (🚫)
```

## 🛡️ Login Validation

1. Has temp password? → Redirect to password change
2. state=0 & no temp password? → "Account deactivated"
3. state != 1? → "Account inactive"
4. Otherwise → Allow login ✅

## 🎨 Visual Indicators

| State | Icon | Color | Clickable | Badge | Tooltip |
|-------|------|-------|-----------|-------|---------|
| Pending | ⏱️ schedule | Orange | No | - | "Pendiente: debe configurar contraseña" |
| Active | 🚫 person_off | Orange | Yes | Green "Activo" | "Desactivar empleado" |
| Deactivated | ➕ person_add | Green | Yes | Gray "Inactivo" | "Activar empleado" |

## ✅ What's Working

- Employee creation with temp password
- Password change activates account automatically
- Login blocks deactivated accounts
- Admin can toggle only active/deactivated employees
- Pending employees cannot be toggled (shows info dialog)
- All three states have distinct visual appearance
