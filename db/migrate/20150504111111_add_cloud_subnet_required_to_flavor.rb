class AddCloudSubnetRequiredToFlavor < ActiveRecord::Migration[4.2]
  def change
    add_column :flavors, :cloud_subnet_required, :boolean
  end
end
