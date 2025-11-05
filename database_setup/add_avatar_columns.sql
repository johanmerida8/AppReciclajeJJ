-- Add avatar columns to users table
-- Run this in Supabase SQL Editor

-- Add avatarUrl column (public URL to access the image)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS "avatarUrl" TEXT;

-- Add avatarFilePath column (storage path for reference)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS "avatarFilePath" TEXT;

-- Add avatarFileName column (filename for reference)
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS "avatarFileName" TEXT;

-- Add comment to explain columns
COMMENT ON COLUMN users."avatarUrl" IS 'Public URL to access the user profile picture';
COMMENT ON COLUMN users."avatarFilePath" IS 'Storage path where the avatar is stored (e.g., avatars/user_123/)';
COMMENT ON COLUMN users."avatarFileName" IS 'Filename of the avatar image (e.g., avatar_1234567890.jpg)';
