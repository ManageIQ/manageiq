class AddNuageFieldsToCloudSubnets < ActiveRecord::Migration[5.0]
  def change
    add_column :cloud_subnets, :parent_type, :string
    add_column :cloud_subnets, :entity_scope, :string
    add_column :cloud_subnets, :external_id, :string
    add_column :cloud_subnets, :parent_id, :string
    add_column :cloud_subnets, :policy_group_id, :string
  end
end
