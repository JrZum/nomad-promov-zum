-- Script de Correção: Políticas RLS para Sistema de Três Níveis
-- Corrige referências à coluna documento e melhora a robustez
-- Execute APÓS o script 17-admin-hierarchy-system.sql

-- Primeiro, vamos verificar e corrigir a estrutura se necessário
DO $$
BEGIN
    -- Verificar se a coluna documento existe na tabela participantes
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'participantes' 
        AND column_name = 'documento'
    ) THEN
        RAISE EXCEPTION 'ERRO: Tabela participantes não possui coluna documento. Verifique a estrutura da tabela.';
    END IF;
    
    RAISE NOTICE 'Estrutura da tabela participantes verificada com sucesso.';
END $$;

-- Desabilitar RLS temporariamente para limpeza
ALTER TABLE IF EXISTS public.admins DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.admin_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.admin_logs DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.configuracao_campanha DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.participantes DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.numeros_sorte DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.vendas DISABLE ROW LEVEL SECURITY;

-- Remover todas as políticas existentes
DO $$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT schemaname, tablename, policyname 
        FROM pg_policies 
        WHERE schemaname = 'public'
        AND tablename IN ('admins', 'admin_sessions', 'admin_logs', 'configuracao_campanha', 'participantes', 'numeros_sorte', 'vendas')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', pol.policyname, pol.schemaname, pol.tablename);
    END LOOP;
    RAISE NOTICE 'Políticas RLS antigas removidas com sucesso.';
END $$;

-- ============= NOVAS POLÍTICAS RLS SEGURAS =============

-- ADMINS TABLE - Políticas para administradores
CREATE POLICY "admins_superadmin_all_access" ON public.admins
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.admin_type = 'superadmin'
            AND a.active = true
        )
    );

CREATE POLICY "admins_self_access" ON public.admins
    FOR SELECT TO authenticated USING (
        id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
        )
    );

-- ADMIN SESSIONS - Políticas para sessões
CREATE POLICY "admin_sessions_own_access" ON public.admin_sessions
    FOR ALL TO authenticated USING (
        admin_id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
        )
    );

CREATE POLICY "admin_sessions_superadmin_access" ON public.admin_sessions
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.admin_type = 'superadmin'
            AND a.active = true
        )
    );

-- ADMIN LOGS - Políticas para logs
CREATE POLICY "admin_logs_superadmin_access" ON public.admin_logs
    FOR SELECT TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.admin_type = 'superadmin'
            AND a.active = true
        )
    );

CREATE POLICY "admin_logs_own_access" ON public.admin_logs
    FOR SELECT TO authenticated USING (
        admin_id = (
            SELECT a.id FROM public.admin_sessions s
            JOIN public.admins a ON s.admin_id = a.id
            WHERE s.token = current_setting('request.jwt.claims', true)::json->>'token'
            AND s.expires_at > now()
            AND a.active = true
        )
    );

-- CONFIGURACAO CAMPANHA - Baseado em permissões
CREATE POLICY "configuracao_campanha_admin_access" ON public.configuracao_campanha
    FOR ALL TO authenticated USING (
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

-- PARTICIPANTES - Admin access e self access
CREATE POLICY "participantes_admin_access" ON public.participantes
    FOR ALL TO authenticated USING (
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

-- Para participantes individuais (usando session variable)
CREATE POLICY "participantes_self_access" ON public.participantes
    FOR ALL TO anon USING (
        documento = current_setting('app.current_participant_documento', true)
    );

-- NUMEROS SORTE - Admin e participante access
CREATE POLICY "numeros_sorte_admin_access" ON public.numeros_sorte
    FOR ALL TO authenticated USING (
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

CREATE POLICY "numeros_sorte_participant_access" ON public.numeros_sorte
    FOR SELECT TO anon USING (
        documento = current_setting('app.current_participant_documento', true)
    );

-- VENDAS - Admin e participante access
CREATE POLICY "vendas_admin_access" ON public.vendas
    FOR ALL TO authenticated USING (
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

CREATE POLICY "vendas_participant_access" ON public.vendas
    FOR SELECT TO anon USING (
        documento = current_setting('app.current_participant_documento', true)
    );

-- ============= HABILITAR RLS EM TODAS AS TABELAS =============

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.configuracao_campanha ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.numeros_sorte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vendas ENABLE ROW LEVEL SECURITY;

-- ============= FUNÇÕES AUXILIARES MELHORADAS =============

-- Função melhorada para definir contexto de participante
CREATE OR REPLACE FUNCTION public.set_participant_context(p_documento TEXT)
RETURNS void AS $$
BEGIN
    IF p_documento IS NULL OR p_documento = '' THEN
        RAISE EXCEPTION 'Documento do participante não pode ser vazio';
    END IF;
    
    -- Verificar se o participante existe
    IF NOT EXISTS (SELECT 1 FROM public.participantes WHERE documento = p_documento) THEN
        RAISE EXCEPTION 'Participante com documento % não encontrado', p_documento;
    END IF;
    
    PERFORM set_config('app.current_participant_documento', p_documento, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para limpar contexto
CREATE OR REPLACE FUNCTION public.clear_participant_context()
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_participant_documento', '', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para testar políticas
CREATE OR REPLACE FUNCTION public.test_rls_policies()
RETURNS TABLE(
    table_name TEXT,
    policy_count INTEGER,
    rls_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tablename::TEXT,
        COUNT(p.policyname)::INTEGER as policy_count,
        t.rowsecurity as rls_enabled
    FROM pg_tables t
    LEFT JOIN pg_policies p ON t.tablename = p.tablename AND t.schemaname = p.schemaname
    WHERE t.schemaname = 'public'
    AND t.tablename IN ('admins', 'admin_sessions', 'admin_logs', 'configuracao_campanha', 'participantes', 'numeros_sorte', 'vendas')
    GROUP BY t.tablename, t.rowsecurity
    ORDER BY t.tablename;
END;
$$ LANGUAGE plpgsql;

-- Verificação final
SELECT 'Políticas RLS configuradas com sucesso!' as status;
SELECT * FROM public.test_rls_policies();