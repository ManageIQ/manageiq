class AddHostnameToVm < ActiveRecord::Migration[5.0]
  def change
    add_column :vms, :hostname, :string
  end
end
