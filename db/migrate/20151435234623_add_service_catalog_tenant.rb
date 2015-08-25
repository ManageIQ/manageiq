class AddServiceCatalogTenant < ActiveRecord::Migration
  def change
    add_column :service_template_catalogs, :tenant_id, :bigint
    add_column :service_templates, :tenant_id, :bigint
  end
end
