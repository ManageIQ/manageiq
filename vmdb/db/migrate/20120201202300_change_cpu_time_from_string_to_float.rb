class ChangeCpuTimeFromStringToFloat < ActiveRecord::Migration
  def up
    change_column :miq_workers, :cpu_time, :float, :cast_as => :float
    change_column :miq_servers, :cpu_time, :float, :cast_as => :float
  end

  def down
    change_column :miq_workers, :cpu_time, :string, :cast_as => :string
    change_column :miq_servers, :cpu_time, :string, :cast_as => :string
  end
end
