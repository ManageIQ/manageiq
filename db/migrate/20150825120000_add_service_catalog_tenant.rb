class AddServiceCatalogTenant < ActiveRecord::Migration[4.2]
  include MigrationHelper

  def change
    return if previously_migrated_as?("20151435234623")
    add_column :service_template_catalogs, :tenant_id, :bigint
    add_column :service_templates, :tenant_id, :bigint
  end
end
