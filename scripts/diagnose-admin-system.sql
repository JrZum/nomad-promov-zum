-- DIAGNÓSTICO COMPLETO DO SISTEMA DE AUTENTICAÇÃO ADMIN
-- Execute este script no SQL Editor do Supabase para verificar o estado atual

-- 1. Verificar quais funções admin existem
SELECT 
    routine_name as function_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name LIKE '%admin%login%' 
   OR routine_name LIKE '%verify%admin%'
   OR routine_name LIKE '%secure%admin%'
ORDER BY routine_name;

-- 2. Verificar se tabela admins existe e sua estrutura
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'admins' 
ORDER BY ordinal_position;

-- 3. Verificar dados na tabela admins
SELECT 
    id,
    email,
    CASE 
        WHEN LENGTH(password) > 50 THEN 'HASH_BCRYPT'
        ELSE 'TEXTO_PLANO'
    END as password_type,
    admin_type,
    permissions,
    active,
    name,
    created_at
FROM public.admins;

-- 4. Verificar se tabelas relacionadas existem
SELECT 
    table_name
FROM information_schema.tables 
WHERE table_name IN ('admin_sessions', 'admin_logs', 'admins')
  AND table_schema = 'public';

-- 5. Verificar permissões nas funções existentes
SELECT 
    r.routine_name,
    p.grantee,
    p.privilege_type
FROM information_schema.routines r
LEFT JOIN information_schema.routine_privileges p ON r.routine_name = p.routine_name
WHERE r.routine_name LIKE '%admin%'
ORDER BY r.routine_name, p.grantee;

-- 6. Testar se extensão bcrypt está disponível
SELECT 
    extname,
    extversion
FROM pg_extension 
WHERE extname = 'bcrypt';