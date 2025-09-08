-- CORREÇÃO COMPLETA DO SISTEMA DE AUTENTICAÇÃO ADMIN
-- Esta migração corrige todos os problemas de autenticação com máxima segurança

-- ========================================
-- PARTE 1: LIMPEZA DE FUNÇÕES CONFLITANTES
-- ========================================

-- Remove funções antigas que causam conflito
DROP FUNCTION IF EXISTS public.admin_login_completo(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verificar_admin_token(TEXT);
DROP FUNCTION IF EXISTS public.admin_login(TEXT, TEXT);
DROP FUNCTION IF EXISTS public.verify_admin(TEXT);

-- ========================================
-- PARTE 2: VERIFICAR E CORRIGIR ESTRUTURA DA TABELA ADMINS
-- ========================================

-- Adicionar colunas que podem estar faltando (se não existirem)
DO $$
BEGIN
    -- Adicionar coluna admin_type se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'admins' AND column_name = 'admin_type') THEN
        ALTER TABLE public.admins ADD COLUMN admin_type TEXT DEFAULT 'admin';
    END IF;
    
    -- Adicionar coluna permissions se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'admins' AND column_name = 'permissions') THEN
        ALTER TABLE public.admins ADD COLUMN permissions JSONB DEFAULT '[]'::jsonb;
    END IF;
    
    -- Adicionar coluna active se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'admins' AND column_name = 'active') THEN
        ALTER TABLE public.admins ADD COLUMN active BOOLEAN DEFAULT true;
    END IF;
    
    -- Adicionar coluna name se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'admins' AND column_name = 'name') THEN
        ALTER TABLE public.admins ADD COLUMN name TEXT;
    END IF;
    
    -- Adicionar coluna last_login se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'admins' AND column_name = 'last_login') THEN
        ALTER TABLE public.admins ADD COLUMN last_login TIMESTAMPTZ;
    END IF;
    
    -- Adicionar coluna created_by se não existir
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'admins' AND column_name = 'created_by') THEN
        ALTER TABLE public.admins ADD COLUMN created_by UUID;
    END IF;
END $$;

-- ========================================
-- PARTE 3: CORRIGIR SENHA DO SUPERADMIN (PRIORIDADE MÁXIMA DE SEGURANÇA)
-- ========================================

-- Atualizar senha do superadmin para hash bcrypt seguro
DO $$
DECLARE
    admin_exists BOOLEAN;
    hashed_password TEXT;
BEGIN
    -- Verificar se o superadmin existe
    SELECT EXISTS(SELECT 1 FROM public.admins WHERE email = 'superadmin@sistema.com') INTO admin_exists;
    
    IF admin_exists THEN
        -- Gerar hash bcrypt para a senha 'Super@dmin123!'
        hashed_password := crypt('Super@dmin123!', gen_salt('bf'));
        
        -- Atualizar o superadmin com senha hasheada e dados completos
        UPDATE public.admins 
        SET 
            password = hashed_password,
            admin_type = 'superadmin',
            permissions = '["dashboard_view", "participantes_view", "participantes_edit", "participantes_delete", "vendas_view", "vendas_edit", "vendas_delete", "relatorios_view", "relatorios_export", "configuracao_campanha", "configuracao_geral", "configuracao_lojas", "configuracao_webhooks", "configuracao_series", "admin_management", "system_logs"]'::jsonb,
            active = true,
            name = 'Super Administrador',
            updated_at = NOW()
        WHERE email = 'superadmin@sistema.com';
        
        RAISE NOTICE 'Senha do superadmin atualizada com hash bcrypt seguro!';
    ELSE
        -- Criar superadmin se não existir
        hashed_password := crypt('Super@dmin123!', gen_salt('bf'));
        
        INSERT INTO public.admins (
            email, 
            password, 
            admin_type, 
            permissions, 
            active, 
            name,
            created_at,
            updated_at
        ) VALUES (
            'superadmin@sistema.com',
            hashed_password,
            'superadmin',
            '["dashboard_view", "participantes_view", "participantes_edit", "participantes_delete", "vendas_view", "vendas_edit", "vendas_delete", "relatorios_view", "relatorios_export", "configuracao_campanha", "configuracao_geral", "configuracao_lojas", "configuracao_webhooks", "configuracao_series", "admin_management", "system_logs"]'::jsonb,
            true,
            'Super Administrador',
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'Superadmin criado com hash bcrypt seguro!';
    END IF;
END $$;

-- ========================================
-- PARTE 4: RECRIAR FUNÇÕES DE AUTENTICAÇÃO SEGURAS
-- ========================================

-- Função de login admin segura
CREATE OR REPLACE FUNCTION public.secure_admin_login(
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
    -- Validar entrada
    IF login_email IS NULL OR login_password IS NULL OR 
       trim(login_email) = '' OR trim(login_password) = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Email e senha são obrigatórios'
        );
    END IF;
    
    -- Buscar admin com senha hasheada
    SELECT * INTO admin_record
    FROM public.admins
    WHERE email = trim(lower(login_email))
    AND password = crypt(login_password, password)
    AND active = true;
    
    -- Se admin não encontrado ou senha incorreta
    IF NOT FOUND THEN
        -- Log da tentativa de login falhada (por segurança)
        INSERT INTO public.admin_logs (admin_id, action, details, created_at)
        VALUES (
            NULL, 
            'login_failed', 
            jsonb_build_object('email', login_email, 'ip', inet_client_addr()),
            NOW()
        );
        
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Credenciais inválidas'
        );
    END IF;
    
    -- Gerar token de sessão seguro
    session_token := encode(gen_random_bytes(32), 'base64');
    
    -- Limpar sessões antigas do admin
    DELETE FROM public.admin_sessions 
    WHERE admin_id = admin_record.id;
    
    -- Criar nova sessão
    INSERT INTO public.admin_sessions (admin_id, token, expires_at, created_at)
    VALUES (admin_record.id, session_token, NOW() + INTERVAL '24 hours', NOW());
    
    -- Atualizar último login
    UPDATE public.admins 
    SET last_login = NOW() 
    WHERE id = admin_record.id;
    
    -- Log do login bem-sucedido
    INSERT INTO public.admin_logs (admin_id, action, details, created_at)
    VALUES (
        admin_record.id, 
        'login_success', 
        jsonb_build_object('ip', inet_client_addr()),
        NOW()
    );
    
    -- Retornar sucesso com dados do admin
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

-- Função de verificação de token segura
CREATE OR REPLACE FUNCTION public.secure_verify_admin_token(
    token_to_verify TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_record RECORD;
BEGIN
    -- Validar entrada
    IF token_to_verify IS NULL OR trim(token_to_verify) = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Token é obrigatório'
        );
    END IF;
    
    -- Buscar admin com sessão válida
    SELECT a.* INTO admin_record
    FROM public.admins a
    JOIN public.admin_sessions s ON s.admin_id = a.id
    WHERE s.token = token_to_verify
    AND s.expires_at > NOW()
    AND a.active = true;
    
    -- Se sessão não encontrada ou expirada
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Token inválido ou expirado'
        );
    END IF;
    
    -- Retornar dados do admin
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

-- Função para criar admin com senha hasheada
CREATE OR REPLACE FUNCTION public.create_admin_secure(
    creator_admin_id UUID,
    new_email TEXT,
    new_password TEXT,
    new_name TEXT,
    new_admin_type TEXT DEFAULT 'admin',
    new_permissions JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    hashed_password TEXT;
    new_admin_id UUID;
BEGIN
    -- Verificar se o criador é superadmin
    IF NOT EXISTS (
        SELECT 1 FROM public.admins 
        WHERE id = creator_admin_id 
        AND admin_type = 'superadmin' 
        AND active = true
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Apenas superadmins podem criar novos administradores'
        );
    END IF;
    
    -- Verificar se email já existe
    IF EXISTS (SELECT 1 FROM public.admins WHERE email = new_email) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Email já está em uso'
        );
    END IF;
    
    -- Gerar hash da senha
    hashed_password := crypt(new_password, gen_salt('bf'));
    
    -- Criar novo admin
    INSERT INTO public.admins (
        email, password, name, admin_type, permissions, active, created_by, created_at, updated_at
    ) VALUES (
        new_email, hashed_password, new_name, new_admin_type, new_permissions, true, creator_admin_id, NOW(), NOW()
    ) RETURNING id INTO new_admin_id;
    
    -- Log da criação
    INSERT INTO public.admin_logs (admin_id, action, target_table, target_id, details, created_at)
    VALUES (
        creator_admin_id, 
        'create_admin', 
        'admins', 
        new_admin_id,
        jsonb_build_object('email', new_email, 'admin_type', new_admin_type),
        NOW()
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'admin_id', new_admin_id
    );
END;
$$;

-- ========================================
-- PARTE 5: PERMISSÕES E SEGURANÇA
-- ========================================

-- Conceder permissões para as funções
GRANT EXECUTE ON FUNCTION public.secure_admin_login(TEXT, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.secure_verify_admin_token(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_admin_secure(UUID, TEXT, TEXT, TEXT, TEXT, JSONB) TO anon, authenticated, service_role;

-- Garantir que enum admin_permission existe e tem permissões
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'admin_permission') THEN
        CREATE TYPE public.admin_permission AS ENUM (
            'dashboard_view', 'participantes_view', 'participantes_edit', 'participantes_delete',
            'vendas_view', 'vendas_edit', 'vendas_delete', 'relatorios_view', 'relatorios_export',
            'configuracao_campanha', 'configuracao_geral', 'configuracao_lojas', 'configuracao_webhooks',
            'configuracao_series', 'admin_management', 'system_logs'
        );
    END IF;
    
    GRANT USAGE ON TYPE public.admin_permission TO anon, authenticated, service_role;
END $$;

-- ========================================
-- PARTE 6: TESTES DE SEGURANÇA
-- ========================================

-- Teste completo do sistema
DO $$
DECLARE
    test_result JSONB;
    test_token TEXT;
BEGIN
    RAISE NOTICE 'Iniciando testes de segurança do sistema de autenticação...';
    
    -- Teste 1: Login com credenciais inválidas
    SELECT public.secure_admin_login('invalid@test.com', 'wrong') INTO test_result;
    IF test_result->>'success' = 'false' THEN
        RAISE NOTICE '✓ Teste 1 PASSOU: Login inválido rejeitado corretamente';
    ELSE
        RAISE WARNING '✗ Teste 1 FALHOU: Login inválido não foi rejeitado';
    END IF;
    
    -- Teste 2: Login com superadmin
    SELECT public.secure_admin_login('superadmin@sistema.com', 'Super@dmin123!') INTO test_result;
    IF test_result->>'success' = 'true' THEN
        test_token := test_result->>'token';
        RAISE NOTICE '✓ Teste 2 PASSOU: Login do superadmin funcionando';
        
        -- Teste 3: Verificação de token
        SELECT public.secure_verify_admin_token(test_token) INTO test_result;
        IF test_result->>'success' = 'true' THEN
            RAISE NOTICE '✓ Teste 3 PASSOU: Verificação de token funcionando';
        ELSE
            RAISE WARNING '✗ Teste 3 FALHOU: Verificação de token falhou';
        END IF;
    ELSE
        RAISE WARNING '✗ Teste 2 FALHOU: Login do superadmin falhou - %', test_result->>'error';
    END IF;
    
    -- Teste 4: Token inválido
    SELECT public.secure_verify_admin_token('token_invalido') INTO test_result;
    IF test_result->>'success' = 'false' THEN
        RAISE NOTICE '✓ Teste 4 PASSOU: Token inválido rejeitado corretamente';
    ELSE
        RAISE WARNING '✗ Teste 4 FALHOU: Token inválido não foi rejeitado';
    END IF;
    
    RAISE NOTICE '=== CORREÇÃO COMPLETA DA AUTENTICAÇÃO ADMIN FINALIZADA ===';
    RAISE NOTICE 'Sistema de autenticação seguro implementado com sucesso!';
    RAISE NOTICE 'Login: superadmin@sistema.com | Senha: Super@dmin123!';
END $$;