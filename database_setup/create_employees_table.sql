-- Create separate employees table for company workers
-- This is better design than adding nullable columns to users table

CREATE TABLE IF NOT EXISTS public.employees (
    "idEmployee" SERIAL PRIMARY KEY,
    "userId" INTEGER NOT NULL UNIQUE REFERENCES public.users("idUser") ON DELETE CASCADE,
    "companyId" INTEGER NOT NULL REFERENCES public.company("idCompany") ON DELETE CASCADE,
    "temporaryPassword" VARCHAR(255),
    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_employees_user ON public.employees("userId");
CREATE INDEX IF NOT EXISTS idx_employees_company ON public.employees("companyId");

-- Enable Row Level Security
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;

-- Policy: Company admins can view their employees
CREATE POLICY "Company admins can view their employees" ON public.employees
    FOR SELECT
    USING (
        "companyId" IN (
            SELECT c."idCompany" 
            FROM public.company c
            INNER JOIN public.users u ON c."adminUserID" = u."idUser"
            WHERE u."idUser"::text = auth.uid()::text
        )
    );

-- Policy: Company admins can insert employees
CREATE POLICY "Company admins can insert employees" ON public.employees
    FOR INSERT
    WITH CHECK (
        "companyId" IN (
            SELECT c."idCompany" 
            FROM public.company c
            INNER JOIN public.users u ON c."adminUserID" = u."idUser"
            WHERE u."idUser"::text = auth.uid()::text
        )
    );

-- Policy: Company admins can update their employees
CREATE POLICY "Company admins can update their employees" ON public.employees
    FOR UPDATE
    USING (
        "companyId" IN (
            SELECT c."idCompany" 
            FROM public.company c
            INNER JOIN public.users u ON c."adminUserID" = u."idUser"
            WHERE u."idUser"::text = auth.uid()::text
        )
    );

-- Policy: Company admins can delete their employees
CREATE POLICY "Company admins can delete their employees" ON public.employees
    FOR DELETE
    USING (
        "companyId" IN (
            SELECT c."idCompany" 
            FROM public.company c
            INNER JOIN public.users u ON c."adminUserID" = u."idUser"
            WHERE u."idUser"::text = auth.uid()::text
        )
    );

-- Add comments
COMMENT ON TABLE public.employees IS 'Links users with role=empleado to their companies and stores temporary passwords';
COMMENT ON COLUMN public.employees."userId" IS 'Foreign key to users table (must have role=empleado)';
COMMENT ON COLUMN public.employees."companyId" IS 'Foreign key to company table';
COMMENT ON COLUMN public.employees."temporaryPassword" IS 'ONE-TIME temporary password, cleared after first login and Supabase auth creation';

/*
USAGE FLOW:
1. Admin-empresa creates employee:
   - Insert into users: names, email, role='empleado', state=0
   - Insert into employees: userId, companyId, temporaryPassword

2. Employee first login:
   - Check employees table for temporaryPassword
   - If found, force password change

3. After password change:
   - Create Supabase auth account
   - Update users: state=1
   - Update employees: temporaryPassword=NULL

4. Subsequent logins:
   - Normal Supabase auth (temporaryPassword is NULL)
*/

-- Update RLS policies if needed (existing policies should still work)
-- Employees with state=0 can login to change password, then state becomes 1 after Supabase auth creation

/* 
USAGE FLOW:
1. Admin-empresa creates employee:
   - Insert into users with: names, email, temporaryPassword, role='empleado', state=0, companyId
   
2. Employee first login:
   - Check users table for temporaryPassword (before Supabase auth)
   - If found, force password change
   
3. After password change:
   - Create Supabase auth account with new password
   - Update users: state=1, temporaryPassword=NULL
   
4. Subsequent logins:
   - Use normal Supabase authentication (temporaryPassword is NULL)
*/
