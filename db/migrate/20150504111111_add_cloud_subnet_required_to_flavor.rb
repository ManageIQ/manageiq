class AddCloudSubnetRequiredToFlavor < ActiveRecord::Migration
  def change
    add_column :flavors, :cloud_subnet_required, :boolean
  end
end
