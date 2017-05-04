class AddStatusToFloatingIps < ActiveRecord::Migration[4.2]
  def change
    add_column :floating_ips, :status, :string
  end
end
