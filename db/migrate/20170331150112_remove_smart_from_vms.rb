class RemoveSmartFromVms < ActiveRecord::Migration[5.0]
  def change
    remove_column :vms, :smart, :boolean
  end
end
