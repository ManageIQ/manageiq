class AddWarnValueTo < ActiveRecord::Migration[4.2]
  def change
    add_column :tenant_quotas, :warn_value, :float
  end
end
