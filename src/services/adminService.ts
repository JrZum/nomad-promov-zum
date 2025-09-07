import { supabase } from "@/integrations/supabase/client";

export interface AdminLoginData {
  email: string;
  password: string;
}

export interface AdminLoginResponse {
  success: boolean;
  error?: string;
  token?: string;
  admin?: {
    id: string;
    email: string;
    name?: string;
    admin_type?: string;
    permissions?: string[];
  };
}

export interface AdminVerificationResponse {
  success: boolean;
  error?: string;
  admin?: {
    id: string;
    email: string;
    name?: string;
  };
}

export const adminService = {
  async login(loginData: AdminLoginData): Promise<AdminLoginResponse> {
    try {
      const { data, error } = await supabase.rpc('admin_login_completo', {
        p_email: loginData.email,
        p_password: loginData.password
      });

      if (error) {
        console.error("Erro na Database Function de login admin:", error);
        return {
          success: false,
          error: error.message || "Erro no login do administrador"
        };
      }

      const result = data as any;
      if (result && result.success) {
        return {
          success: true,
          token: result.token,
          admin: result.admin
        };
      } else {
        return {
          success: false,
          error: result.error || "Credenciais inválidas"
        };
      }
    } catch (error) {
      console.error("Erro inesperado no login admin:", error);
      return {
        success: false,
        error: "Erro inesperado no login do administrador"
      };
    }
  },

  async verifyToken(token: string): Promise<AdminVerificationResponse> {
    try {
      const { data, error } = await supabase.rpc('verificar_admin_token', {
        p_token: token
      });

      if (error) {
        console.error("Erro na verificação do token admin:", error);
        return {
          success: false,
          error: error.message || "Erro na verificação do token"
        };
      }

      const result = data as any;
      if (result && result.success) {
        return {
          success: true,
          admin: result.admin
        };
      } else {
        return {
          success: false,
          error: result.error || "Token inválido ou expirado"
        };
      }
    } catch (error) {
      console.error("Erro inesperado na verificação do token:", error);
      return {
        success: false,
        error: "Erro inesperado na verificação do token"
      };
    }
  }
};