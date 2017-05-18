class AddSharedToCloudNetwork < ActiveRecord::Migration[4.2]
  def change
    add_column :cloud_networks, :shared, :boolean
  end
end
