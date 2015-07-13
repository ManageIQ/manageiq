class CloudTenantOpenstack < CloudTenant
  has_and_belongs_to_many :miq_templates,
                          :foreign_key             => "cloud_tenant_id",
                          :join_table              => "cloud_tenants_vms",
                          :association_foreign_key => "vm_id",
                          :class_name              => "TemplateOpenstack"
end
