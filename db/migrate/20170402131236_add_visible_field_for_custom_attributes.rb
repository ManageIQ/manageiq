class AddVisibleFieldForCustomAttributes < ActiveRecord::Migration[5.0]
  def change
    add_column :custom_attributes, :visible, :boolean
  end
end
