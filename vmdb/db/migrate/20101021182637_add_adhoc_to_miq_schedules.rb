class AddAdhocToMiqSchedules < ActiveRecord::Migration
  def self.up
    add_column :miq_schedules, :adhoc, :boolean
  end

  def self.down
    remove_column :miq_schedules, :adhoc
  end
end
