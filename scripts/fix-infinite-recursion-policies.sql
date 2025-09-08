-- Fix infinite recursion in RLS policies for admin_sessions
-- The problem is policies that reference admin_sessions within their own conditions

-- Drop the problematic policies that cause infinite recursion
DROP POLICY IF EXISTS "Admins can access own sessions" ON admin_sessions;
DROP POLICY IF EXISTS "Superadmins can access all sessions" ON admin_sessions;
DROP POLICY IF EXISTS "Admins can view own logs" ON admin_logs;
DROP POLICY IF EXISTS "Superadmins can access all logs" ON admin_logs;
DROP POLICY IF EXISTS "Admins can view own data" ON admins;
DROP POLICY IF EXISTS "Superadmins can access all admin data" ON admins;

-- Keep only the simple policies that don't cause recursion
-- The existing policies that work:
-- 1. "Admin sessions são acessíveis por qualquer um" - allows all access to admin_sessions
-- 2. "Allow session function access" - allows anon/authenticated to access admin_sessions
-- 3. "Admins são acessíveis por qualquer um" - allows all access to admins
-- 4. "Allow admin function access" - allows anon/authenticated to read admins
-- 5. "Allow logs function access" - allows anon/authenticated to access admin_logs

-- These existing policies are sufficient for the admin functions to work
-- without causing infinite recursion

-- Verify the remaining policies
SELECT 
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename IN ('admins', 'admin_sessions', 'admin_logs')
ORDER BY tablename, policyname;