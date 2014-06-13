class RemoveDefaultsFromServiceResource < ActiveRecord::Migration
  def up
    change_column_default('service_resources', :group_idx,   nil)
    change_column_default('service_resources', :scaling_min, nil)
    change_column_default('service_resources', :scaling_max, nil)
  end

  def down
    change_column_default('service_resources', :group_idx,    0)
    change_column_default('service_resources', :scaling_min,  1)
    change_column_default('service_resources', :scaling_max, -1)
  end
end
