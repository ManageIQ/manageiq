class AddStiToCloudSubnets < ActiveRecord::Migration
  def change
    add_column :cloud_subnets, :type, :string
  end
end
