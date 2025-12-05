-- ✅ Employee State Management System
-- The system uses temporaryPassword to track pending password setup
-- No new column needed - we use existing temporaryPassword field

-- Employee States:
-- 1. PENDING SETUP: user.state = 0 AND employee.temporaryPassword IS NOT NULL
--    → Employee created by admin, needs to set permanent password
--    → Cannot login yet, cannot be toggled by admin
-- 
-- 2. ACTIVE: user.state = 1 AND employee.temporaryPassword IS NULL
--    → Employee completed password setup and is active
--    → Can login, admin can deactivate
--
-- 3. DEACTIVATED: user.state = 0 AND employee.temporaryPassword IS NULL
--    → Admin deactivated the employee
--    → Cannot login, admin can reactivate

-- When admin creates employee:
-- 1. Create user with state = 0
-- 2. Create employee with temporaryPassword = <generated>
-- 3. Send email with temporary password

-- When employee sets permanent password:
-- 1. Update user.state = 1
-- 2. Update employee.temporaryPassword = NULL
-- 3. Now employee can login and admin can manage state

-- Admin actions:
-- - Cannot toggle state if temporaryPassword IS NOT NULL (pending setup)
-- - Can deactivate if temporaryPassword IS NULL AND state = 1 (active → deactivated)
-- - Can reactivate if temporaryPassword IS NULL AND state = 0 (deactivated → active)

-- Login validation:
-- 1. If temporaryPassword exists → redirect to password change screen
-- 2. If state = 0 AND temporaryPassword = NULL → show "Account deactivated by admin"
-- 3. If state = 1 AND temporaryPassword = NULL → allow login

-- No SQL migration needed - existing schema supports this logic
