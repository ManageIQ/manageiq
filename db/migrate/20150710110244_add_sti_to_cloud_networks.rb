class AddStiToCloudNetworks < ActiveRecord::Migration
  def change
    add_column :cloud_networks, :type, :string
  end
end
