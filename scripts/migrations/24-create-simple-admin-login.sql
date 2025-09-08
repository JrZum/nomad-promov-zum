-- Create a simplified admin login function that works reliably
-- This replaces the complex admin_login_completo function

-- Drop existing function if it exists to avoid conflicts
DROP FUNCTION IF EXISTS public.simple_admin_login(TEXT, TEXT);

-- Create simplified admin login function
CREATE OR REPLACE FUNCTION public.simple_admin_login(
    login_email TEXT,
    login_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_record RECORD;
    session_token TEXT;
BEGIN
    -- Check if admin exists and password matches
    SELECT * INTO admin_record
    FROM public.admins
    WHERE email = login_email 
    AND password = crypt(login_password, password)
    AND active = true;
    
    -- If admin not found or password incorrect
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Credenciais inválidas'
        );
    END IF;
    
    -- Generate session token
    session_token := encode(gen_random_bytes(32), 'base64');
    
    -- Store session (cleanup old sessions first)
    DELETE FROM public.admin_sessions 
    WHERE admin_id = admin_record.id;
    
    INSERT INTO public.admin_sessions (admin_id, token, expires_at)
    VALUES (admin_record.id, session_token, NOW() + INTERVAL '24 hours');
    
    -- Update last login
    UPDATE public.admins 
    SET last_login = NOW() 
    WHERE id = admin_record.id;
    
    -- Return success with admin data
    RETURN jsonb_build_object(
        'success', true,
        'token', session_token,
        'admin', jsonb_build_object(
            'id', admin_record.id,
            'email', admin_record.email,
            'name', admin_record.name,
            'admin_type', admin_record.admin_type,
            'permissions', COALESCE(admin_record.permissions, '[]'::jsonb)
        )
    );
END;
$$;

-- Create simplified token verification function
CREATE OR REPLACE FUNCTION public.simple_verify_admin_token(
    token_to_verify TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_record RECORD;
BEGIN
    -- Get admin from valid session
    SELECT a.* INTO admin_record
    FROM public.admins a
    JOIN public.admin_sessions s ON s.admin_id = a.id
    WHERE s.token = token_to_verify
    AND s.expires_at > NOW()
    AND a.active = true;
    
    -- If session not found or expired
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Token inválido ou expirado'
        );
    END IF;
    
    -- Return admin data
    RETURN jsonb_build_object(
        'success', true,
        'admin', jsonb_build_object(
            'id', admin_record.id,
            'email', admin_record.email,
            'name', admin_record.name,
            'admin_type', admin_record.admin_type,
            'permissions', COALESCE(admin_record.permissions, '[]'::jsonb)
        )
    );
END;
$$;

-- Grant execute permissions immediately
GRANT EXECUTE ON FUNCTION public.simple_admin_login(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.simple_verify_admin_token(TEXT) TO anon, authenticated, service_role;

-- Test the function
DO $$
DECLARE
    test_result JSONB;
BEGIN
    RAISE NOTICE 'Testing simple_admin_login function...';
    
    -- Test with invalid credentials
    SELECT public.simple_admin_login('invalid@test.com', 'wrong') INTO test_result;
    
    IF test_result->>'success' = 'false' THEN
        RAISE NOTICE 'Function works correctly - invalid login rejected';
    ELSE
        RAISE NOTICE 'Function test unexpected result: %', test_result;
    END IF;
    
    RAISE NOTICE 'Simple admin login functions created successfully!';
END $$;