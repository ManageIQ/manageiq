class RemoveOperatingRangesFromVmsTable < ActiveRecord::Migration
  def up
    remove_column :vms, :operating_ranges
  end

  def down
    add_column :vms, :operating_ranges, :text
  end
end
