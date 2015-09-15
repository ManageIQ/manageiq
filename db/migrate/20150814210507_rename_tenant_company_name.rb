class RenameTenantCompanyName < ActiveRecord::Migration
  def change
    rename_column :tenants, :company_name, :name
  end
end
