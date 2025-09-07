-- Fix database structure and RLS policies
-- This script will check current structure and fix inconsistencies

-- First, let's check what columns actually exist in our tables
DO $$
DECLARE
    col_exists boolean;
BEGIN
    -- Check if documento column exists in participantes table
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'participantes' 
        AND column_name = 'documento'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        RAISE NOTICE 'Column documento does not exist in participantes table';
        
        -- Check if cpf_cnpj exists instead
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'participantes' 
            AND column_name = 'cpf_cnpj'
        ) INTO col_exists;
        
        IF col_exists THEN
            RAISE NOTICE 'Found cpf_cnpj column, renaming to documento';
            ALTER TABLE public.participantes RENAME COLUMN cpf_cnpj TO documento;
        END IF;
    END IF;
    
    -- Check if documento column exists in numeros_sorte table
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'numeros_sorte' 
        AND column_name = 'documento'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        RAISE NOTICE 'Column documento does not exist in numeros_sorte table';
        
        -- Check if cpf_cnpj exists instead
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'numeros_sorte' 
            AND column_name = 'cpf_cnpj'
        ) INTO col_exists;
        
        IF col_exists THEN
            RAISE NOTICE 'Found cpf_cnpj column, renaming to documento';
            ALTER TABLE public.numeros_sorte RENAME COLUMN cpf_cnpj TO documento;
        END IF;
    END IF;
    
    -- Check vendas table for documento column
    SELECT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'vendas' 
        AND column_name = 'documento'
    ) INTO col_exists;
    
    IF NOT col_exists THEN
        RAISE NOTICE 'Column documento does not exist in vendas table';
        
        -- Check if documento_participante exists instead
        SELECT EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'vendas' 
            AND column_name = 'documento_participante'
        ) INTO col_exists;
        
        IF col_exists THEN
            RAISE NOTICE 'Found documento_participante column, renaming to documento';
            ALTER TABLE public.vendas RENAME COLUMN documento_participante TO documento;
        END IF;
    END IF;
END $$;

-- Now drop all existing RLS policies to start fresh
DROP POLICY IF EXISTS "admin_access_admins" ON public.admins;
DROP POLICY IF EXISTS "self_access_admins" ON public.admins;
DROP POLICY IF EXISTS "admin_access_admin_sessions" ON public.admin_sessions;
DROP POLICY IF EXISTS "self_access_admin_sessions" ON public.admin_sessions;
DROP POLICY IF EXISTS "admin_access_admin_logs" ON public.admin_logs;
DROP POLICY IF EXISTS "self_access_admin_logs" ON public.admin_logs;
DROP POLICY IF EXISTS "admin_access_configuracao_campanha" ON public.configuracao_campanha;
DROP POLICY IF EXISTS "admin_access_participantes" ON public.participantes;
DROP POLICY IF EXISTS "self_access_participantes" ON public.participantes;
DROP POLICY IF EXISTS "admin_access_numeros_sorte" ON public.numeros_sorte;
DROP POLICY IF EXISTS "self_access_numeros_sorte" ON public.numeros_sorte;
DROP POLICY IF EXISTS "admin_access_vendas" ON public.vendas;
DROP POLICY IF EXISTS "self_access_vendas" ON public.vendas;

-- Disable RLS temporarily to create new policies
ALTER TABLE public.admins DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracao_campanha DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.participantes DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.numeros_sorte DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas DISABLE ROW LEVEL SECURITY;

-- Create new RLS policies with correct column references

-- Admins table policies
CREATE POLICY "admin_access_admins" ON public.admins
FOR ALL TO authenticated
USING (
  -- Superadmin can access all
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND a.admin_type = 'superadmin'
    AND s.expires_at > now()
  ) 
  OR
  -- Admin can access their own data
  id = (
    SELECT a.id FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND s.expires_at > now()
  )
);

-- Admin sessions policies
CREATE POLICY "admin_access_admin_sessions" ON public.admin_sessions
FOR ALL TO authenticated
USING (
  admin_id = (
    SELECT a.id FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND s.expires_at > now()
  )
  OR
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND a.admin_type = 'superadmin'
    AND s.expires_at > now()
  )
);

-- Admin logs policies
CREATE POLICY "admin_access_admin_logs" ON public.admin_logs
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND a.admin_type = 'superadmin'
    AND s.expires_at > now()
  )
  OR
  admin_id = (
    SELECT a.id FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND s.expires_at > now()
  )
);

-- Configuracao campanha policies
CREATE POLICY "admin_access_configuracao_campanha" ON public.configuracao_campanha
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND (
      a.admin_type = 'superadmin' 
      OR check_admin_permission(a.id, 'configuracao_campanha')
    )
    AND s.expires_at > now()
  )
);

-- Participantes policies
CREATE POLICY "admin_access_participantes" ON public.participantes
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND (
      a.admin_type = 'superadmin' 
      OR check_admin_permission(a.id, 'participantes_view')
    )
    AND s.expires_at > now()
  )
);

CREATE POLICY "self_access_participantes" ON public.participantes
FOR ALL TO anon, authenticated
USING (
  documento = coalesce(
    current_setting('app.current_participant_documento', true),
    ''
  )
);

-- Numeros sorte policies
CREATE POLICY "admin_access_numeros_sorte" ON public.numeros_sorte
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND (
      a.admin_type = 'superadmin' 
      OR check_admin_permission(a.id, 'participantes_view')
    )
    AND s.expires_at > now()
  )
);

CREATE POLICY "self_access_numeros_sorte" ON public.numeros_sorte
FOR ALL TO anon, authenticated
USING (
  documento = coalesce(
    current_setting('app.current_participant_documento', true),
    ''
  )
);

-- Vendas policies
CREATE POLICY "admin_access_vendas" ON public.vendas
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.admins a 
    JOIN public.admin_sessions s ON a.id = s.admin_id 
    WHERE s.token = (current_setting('request.headers', true)::json->>'authorization')
    AND (
      a.admin_type = 'superadmin' 
      OR check_admin_permission(a.id, 'vendas_view')
    )
    AND s.expires_at > now()
  )
);

CREATE POLICY "self_access_vendas" ON public.vendas
FOR ALL TO anon, authenticated
USING (
  documento = coalesce(
    current_setting('app.current_participant_documento', true),
    ''
  )
);

-- Re-enable RLS
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracao_campanha ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.numeros_sorte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;

-- Helper functions for testing
CREATE OR REPLACE FUNCTION set_participant_context(p_documento TEXT)
RETURNS void AS $$
DECLARE
    participant_exists boolean;
BEGIN
    -- Check if participant exists
    SELECT EXISTS(SELECT 1 FROM public.participantes WHERE documento = p_documento) INTO participant_exists;
    
    IF NOT participant_exists THEN
        RAISE EXCEPTION 'Participante com documento % não encontrado', p_documento;
    END IF;
    
    -- Set the context
    PERFORM set_config('app.current_participant_documento', p_documento, false);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clear_participant_context()
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_participant_documento', '', false);
END;
$$ LANGUAGE plpgsql;

-- Function to test RLS policies
CREATE OR REPLACE FUNCTION test_rls_policies()
RETURNS TABLE(
    table_name text,
    rls_enabled boolean,
    policy_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tablename::text,
        t.rowsecurity,
        COUNT(p.policyname)
    FROM pg_tables t
    LEFT JOIN pg_policies p ON t.tablename = p.tablename
    WHERE t.schemaname = 'public'
    AND t.tablename IN ('admins', 'admin_sessions', 'admin_logs', 'configuracao_campanha', 'participantes', 'numeros_sorte', 'vendas')
    GROUP BY t.tablename, t.rowsecurity
    ORDER BY t.tablename;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION set_participant_context(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION clear_participant_context() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION test_rls_policies() TO anon, authenticated;

-- Test the setup
SELECT 'Database structure fixed and RLS policies updated successfully' as result;