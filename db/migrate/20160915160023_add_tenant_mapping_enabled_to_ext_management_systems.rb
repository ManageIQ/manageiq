class AddTenantMappingEnabledToExtManagementSystems < ActiveRecord::Migration[5.0]
  def change
    add_column :ext_management_systems, :tenant_mapping_enabled, :boolean
  end
end
