class AddNuageFieldsToCloudSubnets < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_subnets, :enterprise_name, :string
    add_column :cloud_subnets, :domain_id, :bigint
    add_column :cloud_subnets, :zone_id, :bigint
    add_column :cloud_subnets, :owner_id, :bigint
  end
end
