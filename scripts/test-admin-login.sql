-- TESTE COMPLETO DO SISTEMA DE AUTENTICAÇÃO ADMIN
-- Execute este script após aplicar a correção definitiva

-- 1. Verificar se as funções foram criadas corretamente
SELECT 
    routine_name as function_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name IN ('final_admin_login', 'final_verify_admin_token')
ORDER BY routine_name;

-- 2. Verificar dados do superadmin
SELECT 
    email,
    password,
    admin_type,
    permissions,
    active,
    name
FROM public.admins 
WHERE email = 'superadmin@sistema.com';

-- 3. Teste de login com credenciais corretas
SELECT 'TESTE 1: Login com credenciais corretas' as teste;
SELECT public.final_admin_login('superadmin@sistema.com', 'admin123');

-- 4. Teste de login com senha incorreta
SELECT 'TESTE 2: Login com senha incorreta' as teste;
SELECT public.final_admin_login('superadmin@sistema.com', 'senha_errada');

-- 5. Teste de login com email inexistente
SELECT 'TESTE 3: Login com email inexistente' as teste;
SELECT public.final_admin_login('admin_inexistente@test.com', 'qualquer_senha');

-- 6. Verificar se sessão foi criada após login bem-sucedido
SELECT 'SESSÕES ATIVAS:' as info;
SELECT 
    s.token,
    s.expires_at,
    a.email,
    a.admin_type
FROM public.admin_sessions s
JOIN public.admins a ON s.admin_id = a.id
WHERE s.expires_at > NOW();

-- 7. Teste de verificação de token (use um token retornado do login acima)
-- SELECT public.final_verify_admin_token('TOKEN_AQUI');

-- 8. Verificar permissões das funções
SELECT 
    r.routine_name,
    p.grantee,
    p.privilege_type
FROM information_schema.routines r
LEFT JOIN information_schema.routine_privileges p ON r.routine_name = p.routine_name
WHERE r.routine_name IN ('final_admin_login', 'final_verify_admin_token')
ORDER BY r.routine_name, p.grantee;

SELECT 'TODOS OS TESTES CONCLUÍDOS!' as status;