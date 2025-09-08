-- VERIFICAÇÃO SE AS FUNÇÕES FORAM CRIADAS CORRETAMENTE
-- Execute este script para verificar o estado atual

-- 1. Verificar se as funções finais existem
SELECT 
    routine_name as function_name,
    routine_type,
    routine_definition IS NOT NULL as has_definition
FROM information_schema.routines 
WHERE routine_name IN ('final_admin_login', 'final_verify_admin_token')
ORDER BY routine_name;

-- 2. Verificar se o superadmin foi criado
SELECT 
    email,
    password,
    admin_type,
    permissions,
    active,
    name,
    created_at
FROM public.admins 
WHERE email = 'superadmin@sistema.com';

-- 3. Verificar permissões das funções
SELECT 
    r.routine_name,
    p.grantee,
    p.privilege_type
FROM information_schema.routines r
LEFT JOIN information_schema.routine_privileges p ON r.routine_name = p.routine_name
WHERE r.routine_name IN ('final_admin_login', 'final_verify_admin_token')
ORDER BY r.routine_name, p.grantee;

-- 4. Teste direto da função (se existir)
-- SELECT public.final_admin_login('superadmin@sistema.com', 'admin123');

SELECT 'VERIFICAÇÃO CONCLUÍDA!' as status;