class AddStiToCloudNetworks < ActiveRecord::Migration[4.2]
  def change
    add_column :cloud_networks, :type, :string
  end
end
