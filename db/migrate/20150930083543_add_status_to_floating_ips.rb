class AddStatusToFloatingIps < ActiveRecord::Migration
  def change
    add_column :floating_ips, :status, :string
  end
end
