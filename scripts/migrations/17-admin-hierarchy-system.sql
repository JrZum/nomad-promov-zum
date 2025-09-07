-- Migration: Admin Hierarchy System (Three Levels)
-- Creates superadmin/admin/participant system with granular permissions
-- Last updated: 2025-01-20

-- Create enum for admin permissions
DO $$ BEGIN
    CREATE TYPE admin_permission AS ENUM (
        'dashboard_view',
        'participantes_view',
        'participantes_edit', 
        'participantes_delete',
        'vendas_view',
        'vendas_edit',
        'vendas_delete',
        'relatorios_view',
        'relatorios_export',
        'configuracao_campanha',
        'configuracao_geral',
        'configuracao_lojas',
        'configuracao_webhooks',
        'configuracao_series',
        'admin_management',
        'system_logs'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Expand admins table with hierarchy and permissions
ALTER TABLE public.admins 
ADD COLUMN IF NOT EXISTS admin_type TEXT NOT NULL DEFAULT 'admin' CHECK (admin_type IN ('superadmin', 'admin')),
ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES public.admins(id),
ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS name TEXT,
ADD COLUMN IF NOT EXISTS last_login TIMESTAMP WITH TIME ZONE;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_admins_admin_type ON public.admins(admin_type);
CREATE INDEX IF NOT EXISTS idx_admins_active ON public.admins(active);

-- Create admin logs table for audit trail
CREATE TABLE IF NOT EXISTS public.admin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    admin_id UUID NOT NULL REFERENCES public.admins(id),
    action TEXT NOT NULL,
    target_table TEXT,
    target_id UUID,
    details JSONB,
    ip_address INET
);

-- Create function to check admin permissions
CREATE OR REPLACE FUNCTION public.check_admin_permission(
    p_admin_id UUID,
    p_permission admin_permission
) RETURNS BOOLEAN AS $$
DECLARE
    admin_record RECORD;
BEGIN
    -- Get admin data
    SELECT admin_type, permissions, active INTO admin_record
    FROM public.admins 
    WHERE id = p_admin_id;
    
    -- Check if admin exists and is active
    IF NOT FOUND OR NOT admin_record.active THEN
        RETURN FALSE;
    END IF;
    
    -- Superadmins have all permissions
    IF admin_record.admin_type = 'superadmin' THEN
        RETURN TRUE;
    END IF;
    
    -- Check if admin has specific permission
    RETURN admin_record.permissions ? p_permission::text;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to log admin actions
CREATE OR REPLACE FUNCTION public.log_admin_action(
    p_admin_id UUID,
    p_action TEXT,
    p_target_table TEXT DEFAULT NULL,
    p_target_id UUID DEFAULT NULL,
    p_details JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO public.admin_logs (admin_id, action, target_table, target_id, details)
    VALUES (p_admin_id, p_action, p_target_table, p_target_id, p_details);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update admin login function to support hierarchy
CREATE OR REPLACE FUNCTION public.admin_login_completo(
    p_email TEXT,
    p_password TEXT
) RETURNS JSONB AS $$
DECLARE
    admin_record RECORD;
    session_token TEXT;
    expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Find active admin
    SELECT id, email, password, admin_type, permissions, name, active
    INTO admin_record
    FROM public.admins 
    WHERE email = p_email AND active = true;
    
    -- Check if admin exists and password is correct
    IF NOT FOUND OR admin_record.password != p_password THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Credenciais inválidas'
        );
    END IF;
    
    -- Generate session token
    session_token := encode(gen_random_bytes(32), 'base64');
    expires_at := now() + interval '24 hours';
    
    -- Create session
    INSERT INTO public.admin_sessions (admin_id, token, expires_at)
    VALUES (admin_record.id, session_token, expires_at);
    
    -- Update last login
    UPDATE public.admins 
    SET last_login = now()
    WHERE id = admin_record.id;
    
    -- Log login action
    PERFORM public.log_admin_action(
        admin_record.id,
        'login',
        'admin_sessions',
        NULL,
        jsonb_build_object('email', p_email)
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'token', session_token,
        'admin', jsonb_build_object(
            'id', admin_record.id,
            'email', admin_record.email,
            'name', admin_record.name,
            'admin_type', admin_record.admin_type,
            'permissions', admin_record.permissions
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to create new admin (only superadmins)
CREATE OR REPLACE FUNCTION public.create_admin(
    p_creator_admin_id UUID,
    p_email TEXT,
    p_password TEXT,
    p_name TEXT,
    p_admin_type TEXT DEFAULT 'admin',
    p_permissions JSONB DEFAULT '[]'::jsonb
) RETURNS JSONB AS $$
DECLARE
    new_admin_id UUID;
    creator_type TEXT;
BEGIN
    -- Check if creator is superadmin
    SELECT admin_type INTO creator_type
    FROM public.admins 
    WHERE id = p_creator_admin_id AND active = true;
    
    IF creator_type != 'superadmin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Apenas superadmins podem criar novos administradores'
        );
    END IF;
    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM public.admins WHERE email = p_email) THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Email já existe'
        );
    END IF;
    
    -- Create new admin
    INSERT INTO public.admins (email, password, name, admin_type, permissions, created_by)
    VALUES (p_email, p_password, p_name, p_admin_type, p_permissions, p_creator_admin_id)
    RETURNING id INTO new_admin_id;
    
    -- Log creation
    PERFORM public.log_admin_action(
        p_creator_admin_id,
        'create_admin',
        'admins',
        new_admin_id,
        jsonb_build_object(
            'email', p_email,
            'name', p_name,
            'admin_type', p_admin_type,
            'permissions', p_permissions
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'admin_id', new_admin_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update admin permissions
CREATE OR REPLACE FUNCTION public.update_admin_permissions(
    p_editor_admin_id UUID,
    p_target_admin_id UUID,
    p_permissions JSONB
) RETURNS JSONB AS $$
DECLARE
    editor_type TEXT;
    target_type TEXT;
BEGIN
    -- Check if editor is superadmin
    SELECT admin_type INTO editor_type
    FROM public.admins 
    WHERE id = p_editor_admin_id AND active = true;
    
    IF editor_type != 'superadmin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Apenas superadmins podem alterar permissões'
        );
    END IF;
    
    -- Get target admin type
    SELECT admin_type INTO target_type
    FROM public.admins 
    WHERE id = p_target_admin_id;
    
    -- Cannot edit superadmin permissions
    IF target_type = 'superadmin' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Não é possível alterar permissões de superadmin'
        );
    END IF;
    
    -- Update permissions
    UPDATE public.admins 
    SET permissions = p_permissions
    WHERE id = p_target_admin_id;
    
    -- Log action
    PERFORM public.log_admin_action(
        p_editor_admin_id,
        'update_permissions',
        'admins',
        p_target_admin_id,
        jsonb_build_object('new_permissions', p_permissions)
    );
    
    RETURN jsonb_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insert initial superadmin if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.admins WHERE admin_type = 'superadmin') THEN
        INSERT INTO public.admins (
            email, 
            password, 
            name, 
            admin_type, 
            permissions,
            active
        ) VALUES (
            'superadmin@sistema.com',
            'Super@dmin123!',
            'Super Administrador',
            'superadmin',
            '[]'::jsonb,
            true
        );
        
        RAISE NOTICE 'Superadmin criado: superadmin@sistema.com / Super@dmin123!';
    END IF;
END $$;