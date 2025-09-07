-- Script para restaurar o usuário administrador no Supabase Auth
-- Este script cria o usuário admin em auth.users sincronizando com a tabela admins existente

-- Inserir o usuário administrador no Supabase Auth
INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'admin@exemplo.com',
    crypt('senha_segura', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
) ON CONFLICT (email) DO NOTHING;

-- Inserir o identity correspondente
INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    created_at,
    updated_at
) 
SELECT 
    gen_random_uuid(),
    au.id,
    jsonb_build_object('sub', au.id::text, 'email', au.email),
    'email',
    NOW(),
    NOW()
FROM auth.users au 
WHERE au.email = 'admin@exemplo.com'
AND NOT EXISTS (
    SELECT 1 FROM auth.identities ai 
    WHERE ai.user_id = au.id AND ai.provider = 'email'
);

-- Verificar se o usuário foi criado com sucesso
SELECT 
    'Usuario admin criado/atualizado com sucesso!' as status,
    email,
    email_confirmed_at,
    created_at
FROM auth.users 
WHERE email = 'admin@exemplo.com';

-- Verificar sincronização com a tabela admins
SELECT 
    'Dados da tabela admins:' as info,
    email,
    created_at as admin_created_at
FROM public.admins 
WHERE email = 'admin@exemplo.com';