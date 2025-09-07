import React, { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import { AlertTriangle, UserPlus, Users, Shield, Eye, EyeOff } from "lucide-react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { AdminCreateData, AdminUser, AdminPermission } from "@/types/admin";
import { adminManagementService } from "@/services/adminManagementService";
import { useAdminPermissions } from "@/hooks/useAdminPermissions";
import AdminPermissionGuard from "@/components/AdminPermissionGuard";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { toast } from "@/hooks/use-toast";

const createAdminSchema = z.object({
  email: z.string().email("Email inválido"),
  password: z.string().min(8, "Senha deve ter no mínimo 8 caracteres"),
  name: z.string().min(2, "Nome deve ter no mínimo 2 caracteres"),
  admin_type: z.enum(['admin'], { required_error: "Tipo é obrigatório" }),
  permissions: z.array(z.string()).min(1, "Selecione pelo menos uma permissão")
});

const PERMISSION_LABELS: Record<AdminPermission, string> = {
  'dashboard_view': 'Visualizar Dashboard',
  'participantes_view': 'Visualizar Participantes',
  'participantes_edit': 'Editar Participantes',
  'participantes_delete': 'Excluir Participantes',
  'vendas_view': 'Visualizar Vendas',
  'vendas_edit': 'Editar Vendas',
  'vendas_delete': 'Excluir Vendas',
  'relatorios_view': 'Visualizar Relatórios',
  'relatorios_export': 'Exportar Relatórios',
  'configuracao_campanha': 'Configurar Campanhas',
  'configuracao_geral': 'Configurações Gerais',
  'configuracao_lojas': 'Configurar Lojas',
  'configuracao_webhooks': 'Configurar Webhooks',
  'configuracao_series': 'Configurar Séries',
  'admin_management': 'Gestão de Admins',
  'system_logs': 'Logs do Sistema'
};

const PERMISSION_GROUPS = {
  'Dashboard': ['dashboard_view'],
  'Participantes': ['participantes_view', 'participantes_edit', 'participantes_delete'],
  'Vendas': ['vendas_view', 'vendas_edit', 'vendas_delete'],
  'Relatórios': ['relatorios_view', 'relatorios_export'],
  'Configurações': ['configuracao_campanha', 'configuracao_geral', 'configuracao_lojas', 'configuracao_webhooks', 'configuracao_series'],
  'Sistema': ['admin_management', 'system_logs']
};

const AdminManagement: React.FC = () => {
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [showPasswords, setShowPasswords] = useState<Record<string, boolean>>({});
  const { isSuperAdmin } = useAdminPermissions();

  const form = useForm<z.infer<typeof createAdminSchema>>({
    resolver: zodResolver(createAdminSchema),
    defaultValues: {
      email: "",
      password: "",
      name: "",
      admin_type: "admin",
      permissions: []
    }
  });

  const loadAdmins = async () => {
    setLoading(true);
    try {
      const result = await adminManagementService.getAdminsList();
      if (result.success) {
        setAdmins(result.data || []);
      } else {
        toast({
          title: "Erro",
          description: result.error || "Erro ao carregar administradores",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error("Erro ao carregar admins:", error);
      toast({
        title: "Erro",
        description: "Erro inesperado ao carregar administradores",
        variant: "destructive"
      });
    } finally {
      setLoading(false);
    }
  };

  const onSubmit = async (data: z.infer<typeof createAdminSchema>) => {
    try {
      const adminData: AdminCreateData = {
        email: data.email,
        password: data.password,
        name: data.name,
        admin_type: data.admin_type,
        permissions: data.permissions as AdminPermission[]
      };

      const result = await adminManagementService.createAdmin(adminData);
      
      if (result.success) {
        toast({
          title: "Sucesso",
          description: "Administrador criado com sucesso"
        });
        setIsCreateDialogOpen(false);
        form.reset();
        loadAdmins();
      } else {
        toast({
          title: "Erro",
          description: result.error || "Erro ao criar administrador",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error("Erro ao criar admin:", error);
      toast({
        title: "Erro",
        description: "Erro inesperado ao criar administrador",
        variant: "destructive"
      });
    }
  };

  const toggleAdminStatus = async (adminId: string, currentStatus: boolean) => {
    try {
      const result = await adminManagementService.toggleAdminStatus(adminId, !currentStatus);
      
      if (result.success) {
        toast({
          title: "Sucesso",
          description: `Administrador ${!currentStatus ? 'ativado' : 'desativado'} com sucesso`
        });
        loadAdmins();
      } else {
        toast({
          title: "Erro",
          description: result.error || "Erro ao alterar status",
          variant: "destructive"
        });
      }
    } catch (error) {
      console.error("Erro ao alterar status:", error);
      toast({
        title: "Erro",
        description: "Erro inesperado ao alterar status",
        variant: "destructive"
      });
    }
  };

  const handlePermissionChange = (permission: string, checked: boolean) => {
    const currentPermissions = form.getValues("permissions");
    if (checked) {
      form.setValue("permissions", [...currentPermissions, permission]);
    } else {
      form.setValue("permissions", currentPermissions.filter(p => p !== permission));
    }
  };

  const handleGroupPermissionChange = (groupPermissions: string[], checked: boolean) => {
    const currentPermissions = form.getValues("permissions");
    if (checked) {
      const newPermissions = [...new Set([...currentPermissions, ...groupPermissions])];
      form.setValue("permissions", newPermissions);
    } else {
      form.setValue("permissions", currentPermissions.filter(p => !groupPermissions.includes(p)));
    }
  };

  const togglePasswordVisibility = (adminId: string) => {
    setShowPasswords(prev => ({
      ...prev,
      [adminId]: !prev[adminId]
    }));
  };

  useEffect(() => {
    if (isSuperAdmin()) {
      loadAdmins();
    }
  }, [isSuperAdmin]);

  return (
    <AdminPermissionGuard permission="admin_management">
      <div className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              Gestão de Administradores
            </CardTitle>
            <CardDescription>
              Gerencie administradores do sistema e suas permissões
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="flex justify-between items-center mb-4">
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <Shield className="h-4 w-4" />
                <span>Acesso restrito a Superadministradores</span>
              </div>
              
              <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
                <DialogTrigger asChild>
                  <Button>
                    <UserPlus className="h-4 w-4 mr-2" />
                    Criar Administrador
                  </Button>
                </DialogTrigger>
                <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
                  <DialogHeader>
                    <DialogTitle>Criar Novo Administrador</DialogTitle>
                    <DialogDescription>
                      Preencha os dados e selecione as permissões para o novo administrador
                    </DialogDescription>
                  </DialogHeader>
                  
                  <Form {...form}>
                    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                      <div className="grid grid-cols-2 gap-4">
                        <FormField
                          control={form.control}
                          name="name"
                          render={({ field }) => (
                            <FormItem>
                              <FormLabel>Nome</FormLabel>
                              <FormControl>
                                <Input placeholder="Nome completo" {...field} />
                              </FormControl>
                              <FormMessage />
                            </FormItem>
                          )}
                        />
                        
                        <FormField
                          control={form.control}
                          name="email"
                          render={({ field }) => (
                            <FormItem>
                              <FormLabel>Email</FormLabel>
                              <FormControl>
                                <Input type="email" placeholder="email@exemplo.com" {...field} />
                              </FormControl>
                              <FormMessage />
                            </FormItem>
                          )}
                        />
                      </div>
                      
                      <FormField
                        control={form.control}
                        name="password"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel>Senha</FormLabel>
                            <FormControl>
                              <Input type="password" placeholder="Mínimo 8 caracteres" {...field} />
                            </FormControl>
                            <FormMessage />
                          </FormItem>
                        )}
                      />
                      
                      <div className="space-y-4">
                        <Label className="text-base font-medium">Permissões</Label>
                        <div className="grid gap-4">
                          {Object.entries(PERMISSION_GROUPS).map(([groupName, groupPermissions]) => {
                            const currentPermissions = form.watch("permissions");
                            const allGroupSelected = groupPermissions.every(p => currentPermissions.includes(p));
                            const someGroupSelected = groupPermissions.some(p => currentPermissions.includes(p));
                            
                            return (
                              <div key={groupName} className="space-y-2">
                                <div className="flex items-center space-x-2">
                                  <Checkbox
                                    id={`group-${groupName}`}
                                    checked={allGroupSelected}
                                    onCheckedChange={(checked) => 
                                      handleGroupPermissionChange(groupPermissions, !!checked)
                                    }
                                  />
                                  <Label htmlFor={`group-${groupName}`} className="font-medium">
                                    {groupName}
                                  </Label>
                                </div>
                                <div className="ml-6 grid grid-cols-2 gap-2">
                                  {groupPermissions.map((permission) => (
                                    <div key={permission} className="flex items-center space-x-2">
                                      <Checkbox
                                        id={permission}
                                        checked={currentPermissions.includes(permission)}
                                        onCheckedChange={(checked) => 
                                          handlePermissionChange(permission, !!checked)
                                        }
                                      />
                                      <Label htmlFor={permission} className="text-sm">
                                        {PERMISSION_LABELS[permission as AdminPermission]}
                                      </Label>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      </div>
                      
                      <div className="flex justify-end gap-2">
                        <Button 
                          type="button" 
                          variant="outline" 
                          onClick={() => setIsCreateDialogOpen(false)}
                        >
                          Cancelar
                        </Button>
                        <Button type="submit">
                          Criar Administrador
                        </Button>
                      </div>
                    </form>
                  </Form>
                </DialogContent>
              </Dialog>
            </div>

            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Nome</TableHead>
                    <TableHead>Email</TableHead>
                    <TableHead>Tipo</TableHead>
                    <TableHead>Permissões</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Último Login</TableHead>
                    <TableHead>Ações</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {loading ? (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center py-4">
                        Carregando...
                      </TableCell>
                    </TableRow>
                  ) : admins.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={7} className="text-center py-4">
                        Nenhum administrador encontrado
                      </TableCell>
                    </TableRow>
                  ) : (
                    admins.map((admin) => (
                      <TableRow key={admin.id}>
                        <TableCell>{admin.name || 'N/A'}</TableCell>
                        <TableCell>{admin.email}</TableCell>
                        <TableCell>
                          <Badge variant={admin.admin_type === 'superadmin' ? 'default' : 'secondary'}>
                            {admin.admin_type === 'superadmin' ? 'Superadmin' : 'Admin'}
                          </Badge>
                        </TableCell>
                        <TableCell>
                          <div className="flex flex-wrap gap-1">
                            {admin.admin_type === 'superadmin' ? (
                              <Badge variant="outline">Todas as permissões</Badge>
                            ) : (
                              admin.permissions?.slice(0, 3).map((permission) => (
                                <Badge key={permission} variant="outline" className="text-xs">
                                  {PERMISSION_LABELS[permission] || permission}
                                </Badge>
                              ))
                            )}
                            {admin.permissions && admin.permissions.length > 3 && (
                              <Badge variant="outline" className="text-xs">
                                +{admin.permissions.length - 3} mais
                              </Badge>
                            )}
                          </div>
                        </TableCell>
                        <TableCell>
                          <Switch
                            checked={admin.active !== false}
                            onCheckedChange={() => toggleAdminStatus(admin.id, admin.active !== false)}
                            disabled={admin.admin_type === 'superadmin'}
                          />
                        </TableCell>
                        <TableCell>
                          {admin.last_login 
                            ? new Date(admin.last_login).toLocaleDateString('pt-BR')
                            : 'Nunca'
                          }
                        </TableCell>
                        <TableCell>
                          {admin.admin_type !== 'superadmin' && (
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => {/* TODO: Edit permissions dialog */}}
                            >
                              Editar
                            </Button>
                          )}
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      </div>
    </AdminPermissionGuard>
  );
};

export default AdminManagement;