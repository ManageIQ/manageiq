class RenameHardwareColumns < ActiveRecord::Migration
  def change
    rename_column :hardwares, :cores_per_socket, :cpu_cores_per_socket
    rename_column :hardwares, :numvcpus, :cpu_sockets
    rename_column :hardwares, :logical_cpus, :cpu_total_cores
    rename_column :hardwares, :memory_cpu, :memory_mb
  end
end
