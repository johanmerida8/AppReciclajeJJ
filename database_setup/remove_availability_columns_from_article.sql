-- =====================================================
-- MIGRATION: Remove availability columns from article table
-- Date: 2025-11-22
-- Description: Removes old availability columns since we now use daysAvailable table
-- =====================================================

-- 1. Remove the old availability columns if they exist
ALTER TABLE article 
DROP COLUMN IF EXISTS "availableDays",
DROP COLUMN IF EXISTS "availableTimeStart", 
DROP COLUMN IF EXISTS "availableTimeEnd";

-- 2. Reload the schema cache in PostgREST (Supabase API)
-- This forces Supabase to reload the table structure
NOTIFY pgrst, 'reload schema';

-- 3. Verify the table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'article'
ORDER BY ordinal_position;

-- Expected columns should be:
-- idArticle, name, categoryID, condition, description, address, lat, lng, userID, state, lastUpdate
-- (NO availableDays, availableTimeStart, availableTimeEnd)

COMMENT ON TABLE article IS 'Article table - availability data now stored in daysAvailable table (removed availableDays, availableTimeStart, availableTimeEnd columns on 2025-11-22)';
