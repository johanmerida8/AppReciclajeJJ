-- =========================================
-- CLEANUP OLD OTP TABLE
-- =========================================
-- This table is no longer needed because 
-- Supabase now handles OTPs internally
-- =========================================

-- Option 1: Clear all old OTP records
DELETE FROM "OTP";

-- Option 2: Drop the table completely (recommended)
-- Uncomment the line below if you want to delete the table
-- DROP TABLE IF EXISTS "OTP";

-- =========================================
-- Note: The new system does NOT use this table!
-- Supabase manages OTP codes internally
-- =========================================
