-- Migration: Safe RLS Policies Update with Error Handling
-- Creates comprehensive RLS policies with existence checks
-- Last updated: 2025-01-20

-- Function to safely drop policies if they exist
CREATE OR REPLACE FUNCTION public.safe_drop_policy(policy_name TEXT, table_name TEXT)
RETURNS void AS $$
BEGIN
    BEGIN
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', policy_name, table_name);
        RAISE NOTICE 'Dropped policy % on table %', policy_name, table_name;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not drop policy % on table %: %', policy_name, table_name, SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- Function to safely create policies with checks
CREATE OR REPLACE FUNCTION public.safe_create_policy(
    policy_name TEXT, 
    table_name TEXT, 
    policy_def TEXT
)
RETURNS void AS $$
BEGIN
    -- Check if table exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = safe_create_policy.table_name
    ) THEN
        RAISE NOTICE 'Table % does not exist, skipping policy %', table_name, policy_name;
        RETURN;
    END IF;

    -- Check if required functions exist
    IF policy_def LIKE '%check_admin_permission%' THEN
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_schema = 'public' AND routine_name = 'check_admin_permission'
        ) THEN
            RAISE NOTICE 'Function check_admin_permission does not exist, skipping policy %', policy_name;
            RETURN;
        END IF;
    END IF;

    BEGIN
        EXECUTE format('CREATE POLICY %I ON public.%I %s', policy_name, table_name, policy_def);
        RAISE NOTICE 'Created policy % on table %', policy_name, table_name;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Could not create policy % on table %: %', policy_name, table_name, SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- ============= DROP EXISTING POLICIES SAFELY =============

SELECT public.safe_drop_policy('Admins can access their own data', 'admins');
SELECT public.safe_drop_policy('Superadmins can access all admin data', 'admins');
SELECT public.safe_drop_policy('Admins can view own data', 'admins');
SELECT public.safe_drop_policy('Admin sessions policy', 'admin_sessions');
SELECT public.safe_drop_policy('Admins can access own sessions', 'admin_sessions');
SELECT public.safe_drop_policy('Superadmins can access all sessions', 'admin_sessions');
SELECT public.safe_drop_policy('Superadmins can access all logs', 'admin_logs');
SELECT public.safe_drop_policy('Admins can view own logs', 'admin_logs');
SELECT public.safe_drop_policy('Configuracao campanha policy', 'configuracao_campanha');
SELECT public.safe_drop_policy('Admins with permission can access configuracao_campanha', 'configuracao_campanha');
SELECT public.safe_drop_policy('Participantes policy', 'participantes');
SELECT public.safe_drop_policy('Admins with permission can access participantes', 'participantes');
SELECT public.safe_drop_policy('Participants can access own data', 'participantes');
SELECT public.safe_drop_policy('Numeros sorte policy', 'numeros_sorte');
SELECT public.safe_drop_policy('Admins with permission can access numeros_sorte', 'numeros_sorte');
SELECT public.safe_drop_policy('Participants can access own numbers', 'numeros_sorte');
SELECT public.safe_drop_policy('Vendas policy', 'vendas');
SELECT public.safe_drop_policy('Admins with permission can access vendas', 'vendas');
SELECT public.safe_drop_policy('Participants can access own sales', 'vendas');

-- ============= CREATE NEW POLICIES SAFELY =============

-- ADMINS TABLE POLICIES
SELECT public.safe_create_policy(
    'Superadmins can access all admin data',
    'admins',
    'FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.admin_type = ''superadmin''
            AND a.active = true
        )
    )'
);

SELECT public.safe_create_policy(
    'Admins can view own data',
    'admins',
    'FOR SELECT USING (
        id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
        )
    )'
);

-- ADMIN SESSIONS POLICIES
SELECT public.safe_create_policy(
    'Admins can access own sessions',
    'admin_sessions',
    'FOR ALL USING (
        admin_id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
        )
    )'
);

SELECT public.safe_create_policy(
    'Superadmins can access all sessions',
    'admin_sessions',
    'FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.admin_type = ''superadmin''
            AND a.active = true
        )
    )'
);

-- ADMIN LOGS POLICIES (only if table exists)
SELECT public.safe_create_policy(
    'Superadmins can access all logs',
    'admin_logs',
    'FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.admin_type = ''superadmin''
            AND a.active = true
        )
    )'
);

SELECT public.safe_create_policy(
    'Admins can view own logs',
    'admin_logs',
    'FOR SELECT USING (
        admin_id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
        )
    )'
);

-- CONFIGURACAO CAMPANHA POLICIES
SELECT public.safe_create_policy(
    'Admins with permission can access configuracao_campanha',
    'configuracao_campanha',
    'FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = ''superadmin'' 
                OR public.check_admin_permission(a.id, ''configuracao_campanha'')
            )
        )
    )'
);

-- PARTICIPANTES POLICIES
SELECT public.safe_create_policy(
    'Admins with permission can access participantes',
    'participantes',
    'FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = ''superadmin'' 
                OR public.check_admin_permission(a.id, ''participantes_view'')
            )
        )
    )'
);

SELECT public.safe_create_policy(
    'Participants can access own data',
    'participantes',
    'FOR ALL USING (
        documento = current_setting(''app.current_participant_documento'', true)
    )'
);

-- NUMEROS SORTE POLICIES
SELECT public.safe_create_policy(
    'Admins with permission can access numeros_sorte',
    'numeros_sorte',
    'FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = ''superadmin'' 
                OR public.check_admin_permission(a.id, ''participantes_view'')
            )
        )
    )'
);

SELECT public.safe_create_policy(
    'Participants can access own numbers',
    'numeros_sorte',
    'FOR SELECT USING (
        documento = current_setting(''app.current_participant_documento'', true)
    )'
);

-- VENDAS POLICIES
SELECT public.safe_create_policy(
    'Admins with permission can access vendas',
    'vendas',
    'FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting(''request.jwt.claims'', true)::json->>''token''
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = ''superadmin'' 
                OR public.check_admin_permission(a.id, ''vendas_view'')
            )
        )
    )'
);

SELECT public.safe_create_policy(
    'Participants can access own sales',
    'vendas',
    'FOR SELECT USING (
        documento = current_setting(''app.current_participant_documento'', true)
    )'
);

-- ============= ENABLE RLS ON ALL TABLES =============

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admins') THEN
        ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on admins table';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admin_sessions') THEN
        ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on admin_sessions table';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'admin_logs') THEN
        ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on admin_logs table';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'configuracao_campanha') THEN
        ALTER TABLE public.configuracao_campanha ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on configuracao_campanha table';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'participantes') THEN
        ALTER TABLE public.participantes ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on participantes table';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'numeros_sorte') THEN
        ALTER TABLE public.numeros_sorte ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on numeros_sorte table';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vendas') THEN
        ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;
        RAISE NOTICE 'Enabled RLS on vendas table';
    END IF;
END $$;

-- ============= HELPER FUNCTIONS FOR TESTING =============

-- Function to set participant context (for testing)
CREATE OR REPLACE FUNCTION public.set_participant_context(p_documento TEXT)
RETURNS void AS $$
BEGIN
    -- Validate that participant exists
    IF NOT EXISTS (SELECT 1 FROM public.participantes WHERE documento = p_documento) THEN
        RAISE EXCEPTION 'Participant with documento % does not exist', p_documento;
    END IF;
    
    PERFORM set_config('app.current_participant_documento', p_documento, true);
    RAISE NOTICE 'Set participant context to: %', p_documento;
END;
$$ LANGUAGE plpgsql;

-- Function to clear participant context
CREATE OR REPLACE FUNCTION public.clear_participant_context()
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_participant_documento', '', true);
    RAISE NOTICE 'Cleared participant context';
END;
$$ LANGUAGE plpgsql;

-- Function to test RLS policies
CREATE OR REPLACE FUNCTION public.test_rls_policies()
RETURNS TABLE(
    table_name TEXT,
    rls_enabled BOOLEAN,
    policy_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.table_name::TEXT,
        t.row_security::BOOLEAN,
        COALESCE(p.policy_count, 0)
    FROM information_schema.tables t
    LEFT JOIN (
        SELECT 
            schemaname||'.'||tablename as full_table_name,
            COUNT(*) as policy_count
        FROM pg_policies 
        WHERE schemaname = 'public'
        GROUP BY schemaname||'.'||tablename
    ) p ON p.full_table_name = 'public.'||t.table_name
    WHERE t.table_schema = 'public' 
    AND t.table_name IN ('admins', 'admin_sessions', 'admin_logs', 'configuracao_campanha', 'participantes', 'numeros_sorte', 'vendas')
    ORDER BY t.table_name;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions on helper functions
GRANT EXECUTE ON FUNCTION public.set_participant_context(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.clear_participant_context() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.test_rls_policies() TO anon, authenticated;

-- Clean up helper functions used for safe creation
DROP FUNCTION IF EXISTS public.safe_drop_policy(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.safe_create_policy(TEXT, TEXT, TEXT);

-- Final test
SELECT 'RLS Policies Update Complete' as status;
SELECT * FROM public.test_rls_policies();