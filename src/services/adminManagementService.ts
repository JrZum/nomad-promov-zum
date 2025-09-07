import { supabase } from "@/integrations/supabase/client";
import { AdminCreateData, AdminUpdateData, AdminUser, AdminPermission } from "@/types/admin";

export interface AdminManagementResponse {
  success: boolean;
  error?: string;
  data?: any;
}

export const adminManagementService = {
  async createAdmin(adminData: AdminCreateData): Promise<AdminManagementResponse> {
    try {
      const { data, error } = await supabase.rpc('create_admin', {
        p_creator_admin_id: await this.getCurrentAdminId(),
        p_email: adminData.email,
        p_password: adminData.password,
        p_name: adminData.name,
        p_admin_type: adminData.admin_type,
        p_permissions: JSON.stringify(adminData.permissions)
      });

      if (error) {
        console.error("Erro ao criar admin:", error);
        return {
          success: false,
          error: error.message || "Erro ao criar administrador"
        };
      }

      const result = data as any;
      if (result && result.success) {
        return {
          success: true,
          data: result
        };
      } else {
        return {
          success: false,
          error: result.error || "Erro ao criar administrador"
        };
      }
    } catch (error) {
      console.error("Erro inesperado ao criar admin:", error);
      return {
        success: false,
        error: "Erro inesperado ao criar administrador"
      };
    }
  },

  async updateAdminPermissions(adminId: string, permissions: AdminPermission[]): Promise<AdminManagementResponse> {
    try {
      const { data, error } = await supabase.rpc('update_admin_permissions', {
        p_editor_admin_id: await this.getCurrentAdminId(),
        p_target_admin_id: adminId,
        p_permissions: JSON.stringify(permissions)
      });

      if (error) {
        console.error("Erro ao atualizar permissões:", error);
        return {
          success: false,
          error: error.message || "Erro ao atualizar permissões"
        };
      }

      const result = data as any;
      if (result && result.success) {
        return {
          success: true,
          data: result
        };
      } else {
        return {
          success: false,
          error: result.error || "Erro ao atualizar permissões"
        };
      }
    } catch (error) {
      console.error("Erro inesperado ao atualizar permissões:", error);
      return {
        success: false,
        error: "Erro inesperado ao atualizar permissões"
      };
    }
  },

  async getAdminsList(): Promise<AdminManagementResponse> {
    try {
      const { data, error } = await supabase
        .from('admins')
        .select('id, email, name, admin_type, permissions, active, last_login, created_at')
        .order('created_at', { ascending: false });

      if (error) {
        console.error("Erro ao buscar lista de admins:", error);
        return {
          success: false,
          error: error.message || "Erro ao buscar administradores"
        };
      }

      return {
        success: true,
        data: data || []
      };
    } catch (error) {
      console.error("Erro inesperado ao buscar admins:", error);
      return {
        success: false,
        error: "Erro inesperado ao buscar administradores"
      };
    }
  },

  async toggleAdminStatus(adminId: string, active: boolean): Promise<AdminManagementResponse> {
    try {
      const { data, error } = await supabase
        .from('admins')
        .update({ active })
        .eq('id', adminId)
        .select();

      if (error) {
        console.error("Erro ao alterar status do admin:", error);
        return {
          success: false,
          error: error.message || "Erro ao alterar status"
        };
      }

      return {
        success: true,
        data: data?.[0]
      };
    } catch (error) {
      console.error("Erro inesperado ao alterar status:", error);
      return {
        success: false,
        error: "Erro inesperado ao alterar status"
      };
    }
  },

  async getAdminLogs(adminId?: string): Promise<AdminManagementResponse> {
    try {
      let query = supabase
        .from('admin_logs')
        .select(`
          id,
          created_at,
          action,
          target_table,
          target_id,
          details,
          admins!admin_logs_admin_id_fkey(email, name)
        `)
        .order('created_at', { ascending: false })
        .limit(100);

      if (adminId) {
        query = query.eq('admin_id', adminId);
      }

      const { data, error } = await query;

      if (error) {
        console.error("Erro ao buscar logs:", error);
        return {
          success: false,
          error: error.message || "Erro ao buscar logs"
        };
      }

      return {
        success: true,
        data: data || []
      };
    } catch (error) {
      console.error("Erro inesperado ao buscar logs:", error);
      return {
        success: false,
        error: "Erro inesperado ao buscar logs"
      };
    }
  },

  async getCurrentAdminId(): Promise<string> {
    // This should get the current admin ID from the auth context
    // For now, we'll implement a simple version
    const session = await supabase.auth.getSession();
    return session.data.session?.user?.id || '';
  }
};