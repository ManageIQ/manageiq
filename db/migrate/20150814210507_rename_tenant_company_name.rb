class RenameTenantCompanyName < ActiveRecord::Migration[4.2]
  def change
    rename_column :tenants, :company_name, :name
  end
end
