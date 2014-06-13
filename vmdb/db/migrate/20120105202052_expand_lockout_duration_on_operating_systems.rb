class ExpandLockoutDurationOnOperatingSystems < ActiveRecord::Migration
  def up
    change_column :operating_systems, :lockout_duration, :bigint
  end

  def down
    change_column :operating_systems, :lockout_duration, :integer
  end
end
