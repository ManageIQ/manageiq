class AddTenantIdToMiqAeNamespaces < ActiveRecord::Migration
  def change
    add_column :miq_ae_namespaces, :tenant_id, :bigint
  end
end
