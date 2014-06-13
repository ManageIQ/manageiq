class RenameMiqScheduleLastUpdateOnToUpdatedAt < ActiveRecord::Migration
  def up
    rename_column :miq_schedules, :last_update_on, :updated_at
  end

  def down
    rename_column :miq_schedules, :updated_at, :last_update_on
  end
end
