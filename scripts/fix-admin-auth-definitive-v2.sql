-- CORREÇÃO DEFINITIVA DO SISTEMA DE AUTENTICAÇÃO ADMIN - VERSÃO 2
-- Este script resolve o problema da chave estrangeira limpando referencias primeiro

-- ETAPA 1: LIMPEZA TOTAL DE FUNÇÕES CONFLITANTES
DROP FUNCTION IF EXISTS public.admin_login(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.admin_login_completo(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.simple_admin_login(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.secure_admin_login(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.verificar_admin_token(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.verify_admin(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.secure_verify_admin_token(TEXT) CASCADE;

-- ETAPA 2: GARANTIR ESTRUTURA CORRETA DA TABELA ADMINS
CREATE TABLE IF NOT EXISTS public.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    admin_type TEXT DEFAULT 'admin',
    permissions JSONB DEFAULT '[]'::jsonb,
    active BOOLEAN DEFAULT true,
    name TEXT,
    last_login TIMESTAMP WITH TIME ZONE,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ETAPA 3: GARANTIR ESTRUTURA DA TABELA DE SESSÕES
CREATE TABLE IF NOT EXISTS public.admin_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.admins(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ETAPA 4: GARANTIR ESTRUTURA DA TABELA DE LOGS (se existir)
CREATE TABLE IF NOT EXISTS public.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES public.admins(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    details JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ETAPA 5: CRIAR ÍNDICES PARA PERFORMANCE
CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON public.admin_sessions(token);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires ON public.admin_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_admins_email ON public.admins(email);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON public.admin_logs(admin_id);

-- ETAPA 6: LIMPEZA SEGURA DO SUPERADMIN EXISTENTE
-- Primeiro: limpar todas as referências ao superadmin
DO $$ 
DECLARE
    superadmin_id UUID;
BEGIN
    -- Buscar ID do superadmin existente
    SELECT id INTO superadmin_id 
    FROM public.admins 
    WHERE email = 'superadmin@sistema.com';
    
    IF superadmin_id IS NOT NULL THEN
        -- Limpar logs primeiro
        DELETE FROM public.admin_logs WHERE admin_id = superadmin_id;
        
        -- Limpar sessões
        DELETE FROM public.admin_sessions WHERE admin_id = superadmin_id;
        
        -- Agora pode deletar o admin com segurança
        DELETE FROM public.admins WHERE id = superadmin_id;
        
        RAISE NOTICE 'Superadmin existente removido com segurança (ID: %)', superadmin_id;
    END IF;
END $$;

-- ETAPA 7: CRIAR SUPERADMIN COM SENHA SIMPLES (TEXTO PLANO)
INSERT INTO public.admins (
    email, 
    password, 
    admin_type, 
    permissions, 
    active, 
    name
) VALUES (
    'superadmin@sistema.com',
    'admin123',  -- Senha em texto plano para teste inicial
    'superadmin',
    '["dashboard_view", "participantes_view", "participantes_edit", "participantes_delete", "vendas_view", "vendas_edit", "vendas_delete", "relatorios_view", "relatorios_export", "configuracao_campanha", "configuracao_geral", "configuracao_lojas", "configuracao_webhooks", "configuracao_series", "admin_management", "system_logs"]'::jsonb,
    true,
    'Super Administrador'
);

-- ETAPA 8: CRIAR FUNÇÃO ÚNICA E ROBUSTA DE LOGIN
CREATE OR REPLACE FUNCTION public.final_admin_login(
    login_email TEXT,
    login_password TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_record RECORD;
    session_token TEXT;
    expires_time TIMESTAMP WITH TIME ZONE;
    result JSON;
BEGIN
    -- Log de debug
    RAISE NOTICE 'Tentativa de login para email: %', login_email;
    
    -- Buscar admin pelo email
    SELECT * INTO admin_record 
    FROM public.admins 
    WHERE email = login_email AND active = true;
    
    -- Verificar se admin existe
    IF NOT FOUND THEN
        RAISE NOTICE 'Admin não encontrado para email: %', login_email;
        RETURN json_build_object(
            'success', false,
            'error', 'Admin não encontrado'
        );
    END IF;
    
    -- Log do admin encontrado
    RAISE NOTICE 'Admin encontrado: ID %, Tipo %', admin_record.id, admin_record.admin_type;
    
    -- Verificar senha (por enquanto apenas texto plano)
    IF admin_record.password != login_password THEN
        RAISE NOTICE 'Senha incorreta para admin: %', login_email;
        RETURN json_build_object(
            'success', false,
            'error', 'Senha incorreta'
        );
    END IF;
    
    -- Gerar token de sessão
    session_token := encode(gen_random_bytes(32), 'base64');
    expires_time := NOW() + INTERVAL '24 hours';
    
    -- Limpar sessões antigas do admin
    DELETE FROM public.admin_sessions 
    WHERE admin_id = admin_record.id;
    
    -- Criar nova sessão
    INSERT INTO public.admin_sessions (admin_id, token, expires_at)
    VALUES (admin_record.id, session_token, expires_time);
    
    -- Atualizar último login
    UPDATE public.admins 
    SET last_login = NOW() 
    WHERE id = admin_record.id;
    
    -- Registrar log de login (se tabela existir)
    BEGIN
        INSERT INTO public.admin_logs (admin_id, action, details)
        VALUES (admin_record.id, 'LOGIN', json_build_object('email', login_email, 'timestamp', NOW()));
    EXCEPTION WHEN OTHERS THEN
        -- Ignora se tabela de logs não existir
        NULL;
    END;
    
    -- Log de sucesso
    RAISE NOTICE 'Login bem-sucedido para admin: %', login_email;
    
    -- Retornar sucesso com dados do admin
    RETURN json_build_object(
        'success', true,
        'token', session_token,
        'admin', json_build_object(
            'id', admin_record.id,
            'email', admin_record.email,
            'name', admin_record.name,
            'admin_type', admin_record.admin_type,
            'permissions', admin_record.permissions
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Erro inesperado no login: %', SQLERRM;
    RETURN json_build_object(
        'success', false,
        'error', 'Erro interno do servidor'
    );
END;
$$;

-- ETAPA 9: CRIAR FUNÇÃO DE VERIFICAÇÃO DE TOKEN
CREATE OR REPLACE FUNCTION public.final_verify_admin_token(
    token_to_verify TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    session_record RECORD;
    admin_record RECORD;
BEGIN
    -- Buscar sessão válida
    SELECT s.*, a.*
    INTO session_record
    FROM public.admin_sessions s
    JOIN public.admins a ON s.admin_id = a.id
    WHERE s.token = token_to_verify 
      AND s.expires_at > NOW()
      AND a.active = true;
    
    -- Verificar se sessão existe e é válida
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Token inválido ou expirado'
        );
    END IF;
    
    -- Retornar dados do admin
    RETURN json_build_object(
        'success', true,
        'admin', json_build_object(
            'id', session_record.id,
            'email', session_record.email,
            'name', session_record.name,
            'admin_type', session_record.admin_type,
            'permissions', session_record.permissions
        )
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', 'Erro na verificação do token'
    );
END;
$$;

-- ETAPA 10: CONFIGURAR PERMISSÕES CORRETAS
GRANT EXECUTE ON FUNCTION public.final_admin_login(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.final_verify_admin_token(TEXT) TO anon, authenticated, service_role;

-- ETAPA 11: CONFIGURAR RLS (Row Level Security)
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_logs ENABLE ROW LEVEL SECURITY;

-- Políticas para permitir acesso às funções
DROP POLICY IF EXISTS "Allow admin function access" ON public.admins;
DROP POLICY IF EXISTS "Allow session function access" ON public.admin_sessions;
DROP POLICY IF EXISTS "Allow logs function access" ON public.admin_logs;

CREATE POLICY "Allow admin function access" ON public.admins FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "Allow session function access" ON public.admin_sessions FOR ALL TO anon, authenticated USING (true);
CREATE POLICY "Allow logs function access" ON public.admin_logs FOR ALL TO anon, authenticated USING (true);

-- ETAPA 12: TESTE FINAL DA FUNÇÃO
-- Testar login do superadmin
SELECT public.final_admin_login('superadmin@sistema.com', 'admin123');

-- Verificar se dados estão corretos
SELECT 
    email,
    admin_type,
    permissions,
    active
FROM public.admins 
WHERE email = 'superadmin@sistema.com';

-- Script finalizado com sucesso
SELECT 'SISTEMA DE AUTENTICAÇÃO ADMIN CORRIGIDO COM SUCESSO! (V2)' as status;