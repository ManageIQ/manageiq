class RemoveSmartFromHosts < ActiveRecord::Migration[5.0]
  def change
    remove_column :hosts, :smart, :integer
  end
end
