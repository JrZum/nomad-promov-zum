export type AdminType = 'superadmin' | 'admin';

export type AdminPermission = 
  | 'dashboard_view'
  | 'participantes_view'
  | 'participantes_edit'
  | 'participantes_delete'
  | 'vendas_view'
  | 'vendas_edit'
  | 'vendas_delete'
  | 'relatorios_view'
  | 'relatorios_export'
  | 'configuracao_campanha'
  | 'configuracao_geral'
  | 'configuracao_lojas'
  | 'configuracao_webhooks'
  | 'configuracao_series'
  | 'admin_management'
  | 'system_logs';

export interface AdminUser {
  id: string;
  email: string;
  name?: string;
  admin_type: AdminType;
  permissions: AdminPermission[];
  active?: boolean;
  last_login?: string;
  created_by?: string;
}

export interface AdminCreateData {
  email: string;
  password: string;
  name: string;
  admin_type: AdminType;
  permissions: AdminPermission[];
}

export interface AdminUpdateData {
  name?: string;
  permissions?: AdminPermission[];
  active?: boolean;
}