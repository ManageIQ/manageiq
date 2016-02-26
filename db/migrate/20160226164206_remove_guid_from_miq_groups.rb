class RemoveGuidFromMiqGroups < ActiveRecord::Migration[5.0]
  def change
    remove_column :miq_groups, :guid, :string, :limit => 36
  end
end
