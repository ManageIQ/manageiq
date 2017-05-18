class AddTenantIdToMiqAeNamespaces < ActiveRecord::Migration[4.2]
  include MigrationHelper

  def change
    return if previously_migrated_as?("20151435234624")
    add_column :miq_ae_namespaces, :tenant_id, :bigint
  end
end
