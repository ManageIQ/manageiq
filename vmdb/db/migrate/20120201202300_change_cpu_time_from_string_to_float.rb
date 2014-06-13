class ChangeCpuTimeFromStringToFloat < ActiveRecord::Migration
  def up
    change_column :miq_workers, :cpu_time, :float
    change_column :miq_servers, :cpu_time, :float
  end

  def down
    change_column :miq_workers, :cpu_time, :string
    change_column :miq_servers, :cpu_time, :string
  end
end
