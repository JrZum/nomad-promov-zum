-- Fix permissions for admin functions to allow anon and authenticated roles to execute them
-- This script ensures that admin login functions can be called from the frontend

-- Grant execute permissions on admin functions to anon and authenticated roles
GRANT EXECUTE ON FUNCTION public.admin_login_completo(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.verificar_admin_token(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_admin_permission(UUID, admin_permission) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_admin_action(UUID, TEXT, TEXT, UUID, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_admin(UUID, TEXT, TEXT, TEXT, TEXT, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_admin_permissions(UUID, UUID, JSONB) TO anon, authenticated;

-- Also ensure the admin_permission enum type is accessible
GRANT USAGE ON TYPE public.admin_permission TO anon, authenticated;

-- Test if admin_login_completo function is now accessible
DO $$
BEGIN
    RAISE NOTICE 'Testing admin function permissions...';
    -- This will just verify the function exists and is callable
    PERFORM public.admin_login_completo('test@test.com', 'test');
    RAISE NOTICE 'Admin functions are accessible!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Function access test failed: %', SQLERRM;
END $$;