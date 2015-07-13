class ConvertHardwareVmotionEnabledToBoolean < ActiveRecord::Migration
  def self.up
    change_column :hardwares, :vmotion_enabled, :boolean, :cast_as => :boolean
  end

  def self.down
    change_column :hardwares, :vmotion_enabled, :integer, :cast_as => :integer
  end
end
