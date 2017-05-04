class AddStiToCloudSubnets < ActiveRecord::Migration[4.2]
  def change
    add_column :cloud_subnets, :type, :string
  end
end
