-- Migration: Update RLS Policies for Three-Level System
-- Creates comprehensive RLS policies for superadmin/admin/participant access
-- Last updated: 2025-01-20

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can access their own data" ON public.admins;
DROP POLICY IF EXISTS "Admin sessions policy" ON public.admin_sessions;
DROP POLICY IF EXISTS "Configuracao campanha policy" ON public.configuracao_campanha;
DROP POLICY IF EXISTS "Participantes policy" ON public.participantes;
DROP POLICY IF EXISTS "Numeros sorte policy" ON public.numeros_sorte;
DROP POLICY IF EXISTS "Vendas policy" ON public.vendas;

-- ============= ADMINS TABLE POLICIES =============

-- Superadmins can access all admin data
CREATE POLICY "Superadmins can access all admin data" ON public.admins
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.admin_type = 'superadmin'
            AND a.active = true
        )
    );

-- Admins can only view their own data
CREATE POLICY "Admins can view own data" ON public.admins
    FOR SELECT USING (
        id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
        )
    );

-- ============= ADMIN SESSIONS POLICIES =============

-- Admins can access their own sessions
CREATE POLICY "Admins can access own sessions" ON public.admin_sessions
    FOR ALL USING (
        admin_id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
        )
    );

-- Superadmins can access all sessions
CREATE POLICY "Superadmins can access all sessions" ON public.admin_sessions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.admin_type = 'superadmin'
            AND a.active = true
        )
    );

-- ============= ADMIN LOGS POLICIES =============

-- Superadmins can access all logs
CREATE POLICY "Superadmins can access all logs" ON public.admin_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.admin_type = 'superadmin'
            AND a.active = true
        )
    );

-- Admins can only view their own logs
CREATE POLICY "Admins can view own logs" ON public.admin_logs
    FOR SELECT USING (
        admin_id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
        )
    );

-- ============= CONFIGURACAO CAMPANHA POLICIES =============

-- Admins with configuracao_campanha permission can access
CREATE POLICY "Admins with permission can access configuracao_campanha" ON public.configuracao_campanha
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = 'superadmin' 
                OR public.check_admin_permission(a.id, 'configuracao_campanha')
            )
        )
    );

-- ============= PARTICIPANTES POLICIES =============

-- Admins with participantes permission can access
CREATE POLICY "Admins with permission can access participantes" ON public.participantes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = 'superadmin' 
                OR public.check_admin_permission(a.id, 'participantes_view')
            )
        )
    );

-- Participants can access their own data (using documento as identifier)
CREATE POLICY "Participants can access own data" ON public.participantes
    FOR ALL USING (
        documento = current_setting('app.current_participant_documento', true)
    );

-- ============= NUMEROS SORTE POLICIES =============

-- Admins with participantes permission can access
CREATE POLICY "Admins with permission can access numeros_sorte" ON public.numeros_sorte
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = 'superadmin' 
                OR public.check_admin_permission(a.id, 'participantes_view')
            )
        )
    );

-- Participants can access their own numbers
CREATE POLICY "Participants can access own numbers" ON public.numeros_sorte
    FOR SELECT USING (
        documento = current_setting('app.current_participant_documento', true)
    );

-- ============= VENDAS POLICIES =============

-- Admins with vendas permission can access
CREATE POLICY "Admins with permission can access vendas" ON public.vendas
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
            AND (
                a.admin_type = 'superadmin' 
                OR public.check_admin_permission(a.id, 'vendas_view')
            )
        )
    );

-- Participants can access their own sales
CREATE POLICY "Participants can access own sales" ON public.vendas
    FOR SELECT USING (
        documento = current_setting('app.current_participant_documento', true)
    );

-- ============= ENABLE RLS ON ALL TABLES =============

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracao_campanha ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.numeros_sorte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;

-- ============= HELPER FUNCTIONS FOR TESTING =============

-- Function to set participant context (for testing)
CREATE OR REPLACE FUNCTION public.set_participant_context(p_documento TEXT)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_participant_documento', p_documento, true);
END;
$$ LANGUAGE plpgsql;

-- Function to clear participant context
CREATE OR REPLACE FUNCTION public.clear_participant_context()
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_participant_documento', '', true);
END;
$$ LANGUAGE plpgsql;