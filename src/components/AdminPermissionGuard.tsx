import React from "react";
import { useAdminPermissions } from "@/hooks/useAdminPermissions";
import { AdminPermission } from "@/types/admin";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Lock } from "lucide-react";

interface AdminPermissionGuardProps {
  children: React.ReactNode;
  permission?: AdminPermission;
  permissions?: AdminPermission[];
  requireAll?: boolean;
  fallback?: React.ReactNode;
  showFallback?: boolean;
}

const AdminPermissionGuard: React.FC<AdminPermissionGuardProps> = ({
  children,
  permission,
  permissions = [],
  requireAll = false,
  fallback,
  showFallback = true
}) => {
  const { hasPermission, hasAnyPermission, hasAllPermissions } = useAdminPermissions();

  // Build permissions array
  const permissionsToCheck = permission ? [permission] : permissions;

  // Check permissions
  let hasAccess = false;
  if (permissionsToCheck.length === 1) {
    hasAccess = hasPermission(permissionsToCheck[0]);
  } else if (requireAll) {
    hasAccess = hasAllPermissions(permissionsToCheck);
  } else {
    hasAccess = hasAnyPermission(permissionsToCheck);
  }

  if (hasAccess) {
    return <>{children}</>;
  }

  // Show fallback or default unauthorized message
  if (fallback) {
    return <>{fallback}</>;
  }

  if (showFallback) {
    return (
      <Alert className="border-destructive/50 text-destructive">
        <Lock className="h-4 w-4" />
        <AlertDescription>
          Você não tem permissão para acessar esta funcionalidade.
        </AlertDescription>
      </Alert>
    );
  }

  return null;
};

export default AdminPermissionGuard;