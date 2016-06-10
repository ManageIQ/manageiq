class AddTenantDefaultGroup < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base; end

  def change
    add_column :tenants, :default_miq_group_id, :bigint
    Tenant.reset_column_information
  end
end
