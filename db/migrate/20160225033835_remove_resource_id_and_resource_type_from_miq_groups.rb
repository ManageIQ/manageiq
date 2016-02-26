class RemoveResourceIdAndResourceTypeFromMiqGroups < ActiveRecord::Migration[5.0]
  def change
    remove_column :miq_groups, :resource_id, :bigint
    remove_column :miq_groups, :resource_type, :string
  end
end
