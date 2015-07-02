class AddSharedToCloudNetwork < ActiveRecord::Migration
  def change
    add_column :cloud_networks, :shared, :boolean
  end
end
