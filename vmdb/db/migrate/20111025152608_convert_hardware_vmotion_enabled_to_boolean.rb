class ConvertHardwareVmotionEnabledToBoolean < ActiveRecord::Migration
  def self.up
    change_column :hardwares, :vmotion_enabled, :boolean
  end

  def self.down
    change_column :hardwares, :vmotion_enabled, :integer
  end
end
