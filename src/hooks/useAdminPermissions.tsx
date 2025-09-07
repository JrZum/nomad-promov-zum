import { useAdminAuth } from "@/context/AdminAuthContext";
import { AdminPermission } from "@/types/admin";

export const useAdminPermissions = () => {
  const { admin } = useAdminAuth();

  const hasPermission = (permission: AdminPermission): boolean => {
    if (!admin) return false;
    
    // Superadmins have all permissions
    if (admin.admin_type === 'superadmin') return true;
    
    // Check if admin has specific permission
    return admin.permissions?.includes(permission) || false;
  };

  const hasAnyPermission = (permissions: AdminPermission[]): boolean => {
    return permissions.some(permission => hasPermission(permission));
  };

  const hasAllPermissions = (permissions: AdminPermission[]): boolean => {
    return permissions.every(permission => hasPermission(permission));
  };

  const isSuperAdmin = (): boolean => {
    return admin?.admin_type === 'superadmin';
  };

  const canManageAdmins = (): boolean => {
    return hasPermission('admin_management');
  };

  const canViewDashboard = (): boolean => {
    return hasPermission('dashboard_view');
  };

  const canManageParticipants = (): boolean => {
    return hasAnyPermission(['participantes_view', 'participantes_edit']);
  };

  const canEditParticipants = (): boolean => {
    return hasPermission('participantes_edit');
  };

  const canDeleteParticipants = (): boolean => {
    return hasPermission('participantes_delete');
  };

  const canViewSales = (): boolean => {
    return hasPermission('vendas_view');
  };

  const canEditSales = (): boolean => {
    return hasPermission('vendas_edit');
  };

  const canViewReports = (): boolean => {
    return hasPermission('relatorios_view');
  };

  const canExportReports = (): boolean => {
    return hasPermission('relatorios_export');
  };

  const canConfigureSystem = (): boolean => {
    return hasAnyPermission([
      'configuracao_campanha',
      'configuracao_geral',
      'configuracao_lojas',
      'configuracao_webhooks',
      'configuracao_series'
    ]);
  };

  const getAvailablePermissions = (): AdminPermission[] => {
    if (!admin) return [];
    return admin.permissions || [];
  };

  return {
    hasPermission,
    hasAnyPermission,
    hasAllPermissions,
    isSuperAdmin,
    canManageAdmins,
    canViewDashboard,
    canManageParticipants,
    canEditParticipants,
    canDeleteParticipants,
    canViewSales,
    canEditSales,
    canViewReports,
    canExportReports,
    canConfigureSystem,
    getAvailablePermissions,
    admin
  };
};