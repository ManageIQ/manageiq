class AddDeprecatedToVms < ActiveRecord::Migration[5.0]
  def change
    add_column :vms, :deprecated, :boolean
  end
end
