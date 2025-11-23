-- =====================================================
-- URGENT FIX: Remove availability columns from article table
-- Run this in Supabase SQL Editor NOW
-- =====================================================

-- Step 1: Check current columns (BEFORE)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'article'
ORDER BY ordinal_position;

-- Step 2: Remove the problematic columns
ALTER TABLE article 
DROP COLUMN IF EXISTS "availableDays" CASCADE,
DROP COLUMN IF EXISTS "availableTimeStart" CASCADE, 
DROP COLUMN IF EXISTS "availableTimeEnd" CASCADE;

-- Step 3: Force Supabase to reload the schema cache
NOTIFY pgrst, 'reload schema';

-- Step 4: Verify columns are removed (AFTER)
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'article'
ORDER BY ordinal_position;

-- Expected columns after fix:
-- ✅ idArticle (int8)
-- ✅ name (varchar/text)
-- ✅ categoryID (int8)
-- ✅ condition (varchar/text)
-- ✅ description (text)
-- ✅ address (text)
-- ✅ lat (float8)
-- ✅ lng (float8)
-- ✅ userID (int8)
-- ✅ state (int8)
-- ✅ lastUpdate (timestamptz)
-- 
-- ❌ NO availableDays
-- ❌ NO availableTimeStart
-- ❌ NO availableTimeEnd

SELECT '✅ Migration completed successfully!' as status;
