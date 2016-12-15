class AddDisabledFieldToEms < ActiveRecord::Migration[5.0]
  def change
    add_column :ext_management_systems, :disabled, :boolean
  end
end
