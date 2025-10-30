# Employee Management System - Implementation Guide

## Overview
Employees use a **separate `employees` table** that links to the `users` table. This avoids nullable columns in `users` and follows database best practices.

## Why Separate Table?

**Bad Practice:**
- Adding nullable `temporaryPassword` and `companyId` columns to `users` table
- Most users (administrador, admin-empresa, distribuidor) would have NULL values
- Creates sparse data and wastes storage

**Good Practice (Current Implementation):**
- Separate `employees` table with only employee-specific data
- `users` table remains clean with only core user fields
- Employees link to users via `userId` foreign key

## Database Structure

### users table (unchanged):
- `idUser` - Primary key
- `names` - Full name  
- `email` - Unique email
- `role` - 'administrador', 'admin-empresa', 'distribuidor', 'empleado'
- `state` - 0=inactive, 1=active
- No temporary password or company fields!

### employees table (new):
- `idEmployee` - Primary key
- `userId` - Foreign key to users (UNIQUE)
- `companyId` - Foreign key to company
- `temporaryPassword` - One-time password, cleared after activation
- `createdAt`, `updatedAt` - Timestamps

## Database Changes Required

Run this SQL in your Supabase SQL Editor:

```sql
-- Create separate employees table
CREATE TABLE IF NOT EXISTS public.employees (
    "idEmployee" SERIAL PRIMARY KEY,
    "userId" INTEGER NOT NULL UNIQUE REFERENCES public.users("idUser") ON DELETE CASCADE,
    "companyId" INTEGER NOT NULL REFERENCES public.company("idCompany") ON DELETE CASCADE,
    "temporaryPassword" VARCHAR(255),
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_employees_user ON public.employees("userId");
CREATE INDEX IF NOT EXISTS idx_employees_company ON public.employees("companyId");

-- Enable RLS
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

-- RLS Policies (add appropriate policies for your security needs)
```

Full SQL with RLS policies is in `create_employees_table.sql`.

## Employee Lifecycle Flow

### 1. **Admin-Empresa Creates Employee**
   - Navigate to Empleados screen
   - Click "Agregar Empleado"
   - Enter name and email
   - System generates 8-character temporary password
   - **Two records created:**
     - `users` table: `role='empleado'`, `state=0` (inactive)
     - `employees` table: `userId`, `companyId`, `temporaryPassword`
   - **Employee can NOT login to Supabase yet** (no auth account exists)

### 2. **Employee First Login**
   - Employee enters email + temporary password
   - Login checks `employees` table FIRST (before Supabase auth)
   - If `temporaryPassword` matches:
     - Redirect to EmployeeChangePasswordScreen
     - Screen cannot be bypassed (WillPopScope disabled)

### 3. **Employee Creates Password**
   - Employee must enter new password meeting requirements:
     - Minimum 8 characters
     - At least one uppercase letter
     - At least one lowercase letter
     - At least one number
     - At least one special character
   - Upon submission:
     - **Creates Supabase auth account** with email + new password
     - Updates `users`: `state=1` (active)
     - Updates `employees`: `temporaryPassword=NULL`
   - Employee is now authenticated and redirected to NavigationScreens

### 4. **Subsequent Logins**
   - Employee uses normal Supabase authentication
   - `temporaryPassword` is NULL, so no temp password check
   - Login proceeds through standard Supabase auth flow

## Code Changes Made

### 1. **Employee Model** (`lib/model/employee.dart`)
   - Simple model with only employee-specific fields
   - `userId` links to users table
   - `companyId` links to company table
   - `temporaryPassword` for one-time use

### 2. **Users Model** (`lib/model/users.dart`)
   - **NO CHANGES** - stays clean without employee fields
   - No `temporaryPassword` or `companyId` fields

### 3. **EmployeeDatabase** (`lib/database/employee_database.dart`)
   - `createEmployee()`: Creates user first, then employee record
   - `getEmployeesByCompany()`: Joins employees + users data
   - `getEmployeeByEmail()`: Returns combined employee + user data
   - `activateEmployee()`: Updates both tables (user.state=1, employee.temporaryPassword=NULL)

### 4. **EmployeesScreen** (`lib/screen/empresa/employees_screen.dart`)
   - Creates employees with `createEmployee()` method
   - Displays combined employee + user data
   - Shows status badges:
     - Orange: "Debe cambiar contraseña" (has temporaryPassword)
     - Red: "Inactivo - Pendiente de activación" (state=0)

### 5. **EmployeeChangePasswordScreen** (`lib/screen/empresa/employee_change_password_screen.dart`)
   - Accepts `Map<String, dynamic>` with employee + user data
   - Creates Supabase auth account with `signUp()`
   - Calls `activateEmployee()` to update both tables
   - Shows success message and navigates to app

### 6. **LoginScreen** (`lib/screen/login_screen.dart`)
   - Checks `getEmployeeByEmail()` before Supabase auth
   - If temporary password matches, redirects to password change
   - Otherwise proceeds with normal Supabase authentication

## Benefits of This Approach

1. ✅ **Database Best Practice**: No sparse/nullable columns in main users table
2. ✅ **Clear Separation**: Employee-specific data isolated in dedicated table
3. ✅ **Better Performance**: No wasted storage on NULL values for non-employees
4. ✅ **Scalability**: Can add employee-specific fields without touching users table
5. ✅ **Security**: Temporary passwords only exist in employees table
6. ✅ **Proper Authentication**: Employees get real Supabase auth accounts after activation
7. ✅ **Data Integrity**: UNIQUE constraint on userId prevents duplicate employees

## Data Examples

### users table (all roles):
```
idUser | names          | email                    | role         | state
-------|----------------|--------------------------|--------------|------
14     | administrador  | administrador@gmail.com  | administrador| 1
16     | Johan Merida   | emsacercado@gmail.com    | admin-empresa| 1
6      | Juan Carlos    | jc.saltg3@gmail.com      | distribuidor | 1
17     | Maria Lopez    | maria@company.com        | empleado     | 0 → 1
```

### employees table (only employees):
```
idEmployee | userId | companyId | temporaryPassword | createdAt
-----------|--------|-----------|-------------------|-------------------
1          | 17     | 5         | "aB3#xY9$" → NULL | 2025-10-30 16:00:00
```

**Notice:**
- Only employee (userId=17) has a record in employees table
- Other roles have NO records in employees table
- Temporary password is cleared after activation
- users.state goes from 0 → 1 after password creation

## Testing Steps

1. Run the SQL script in Supabase (`create_employees_table.sql`)
2. Login as admin-empresa (emsacercado@gmail.com)
3. Go to Empleados screen
4. Create a new employee - copy the temporary password shown
5. Logout
6. Login with employee email + temp password
7. Verify redirect to password change screen
8. Create a new password
9. Verify two things in Supabase:
   - `users` table: `state=1`
   - `employees` table: `temporaryPassword=NULL`
10. Logout and login again with new password
11. Should work normally through Supabase auth

## Database Schema

### Relationships:
```
users (1) ←→ (0..1) employees
  ↓
company (1) ←→ (many) employees
```

- One user can have zero or one employee record
- One company can have many employees
- Employees always link to exactly one user and one company

## Database Fields Reference

### users table:
- `idUser` - Primary key (SERIAL)
- `names` - Full name (VARCHAR)
- `email` - Unique email (VARCHAR UNIQUE)
- `role` - User role: 'administrador', 'admin-empresa', 'distribuidor', 'empleado'
- `state` - 0=inactive, 1=active (INTEGER)
- `created_at`, `lastUpdate` - Timestamps

### employees table:
- `idEmployee` - Primary key (SERIAL)
- `userId` - Foreign key to users, UNIQUE (INTEGER)
- `companyId` - Foreign key to company (INTEGER)
- `temporaryPassword` - One-time password, NULL after activation (VARCHAR)
- `createdAt`, `updatedAt` - Timestamps

## Security Notes

- Temporary passwords are randomly generated (8 chars with special characters)
- Passwords must meet strict requirements before being accepted
- Employee records link to users with `state=0` until password creation
- Temporary passwords are immediately cleared from database after use
- Employees get proper Supabase authentication after activation
- UNIQUE constraint on `userId` prevents duplicate employee records
- RLS policies ensure company admins can only manage their own employees
