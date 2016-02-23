class AddStatContainergroupCreateRate < ActiveRecord::Migration[5.0]
  def change
    add_column :metric_rollups, :stat_containergroup_create_rate, :integer
    add_column :metric_rollups, :stat_containergroup_delete_rate, :integer
  end
end
