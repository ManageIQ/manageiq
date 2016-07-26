class AddStiToResourcePools < ActiveRecord::Migration[5.0]
  def up
    add_column :resource_pools, :type, :string
  end

  def down
    remove_column :resource_pools, :type
  end
end
