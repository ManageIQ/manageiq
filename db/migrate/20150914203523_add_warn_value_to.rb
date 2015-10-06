class AddWarnValueTo < ActiveRecord::Migration
  def change
    add_column :tenant_quotas, :warn_value, :float
  end
end
