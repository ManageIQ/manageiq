class AddOperatingRangesToVms < ActiveRecord::Migration
  def self.up
    add_column    :vms,   :operating_ranges,    :text
  end

  def self.down
    remove_column :vms,   :operating_ranges
  end
end
