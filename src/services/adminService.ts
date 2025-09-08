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
      console.log("[AdminService] Iniciando login para:", loginData.email);
      
      // Usar a função definitiva final_admin_login
      const { data, error } = await supabase.rpc('final_admin_login', {
        login_email: loginData.email,
        login_password: loginData.password
      });

      console.log("[AdminService] Resposta da função:", { data, error });

      if (error) {
        console.error("[AdminService] Erro na Database Function:", error);
        return {
          success: false,
          error: error.message || "Erro no login do administrador"
        };
      }

      const result = data as any;
      console.log("[AdminService] Resultado processado:", result);
      
      if (result && result.success) {
        console.log("[AdminService] Login bem-sucedido!");
        return {
          success: true,
          token: result.token,
          admin: result.admin
        };
      } else {
        console.log("[AdminService] Login falhou:", result?.error);
        return {
          success: false,
          error: result?.error || "Credenciais inválidas"
        };
      }
    } catch (error) {
      console.error("[AdminService] Erro inesperado:", error);
      return {
        success: false,
        error: "Erro inesperado no login do administrador"
      };
    }
  },

  async verifyToken(token: string): Promise<AdminVerificationResponse> {
    try {
      console.log("[AdminService] Verificando token...");
      
      // Usar a função definitiva final_verify_admin_token
      const { data, error } = await supabase.rpc('final_verify_admin_token', {
        token_to_verify: token
      });

      console.log("[AdminService] Resposta da verificação:", { data, error });

      if (error) {
        console.error("[AdminService] Erro na verificação do token:", error);
        return {
          success: false,
          error: error.message || "Erro na verificação do token"
        };
      }

      const result = data as any;
      if (result && result.success) {
        console.log("[AdminService] Token válido!");
        return {
          success: true,
          admin: result.admin
        };
      } else {
        console.log("[AdminService] Token inválido:", result?.error);
        return {
          success: false,
          error: result?.error || "Token inválido ou expirado"
        };
      }
    } catch (error) {
      console.error("[AdminService] Erro inesperado na verificação:", error);
      return {
        success: false,
        error: "Erro inesperado na verificação do token"
      };
    }
  }
};