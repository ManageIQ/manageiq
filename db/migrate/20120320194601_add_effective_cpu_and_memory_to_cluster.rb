class AddEffectiveCpuAndMemoryToCluster < ActiveRecord::Migration
  class EmsCluster < ActiveRecord::Base
    include ReservedMixin
    include MigrationStubHelper # NOTE: Must be included after other mixins
  end

  def self.up
    add_column :ems_clusters, :effective_cpu,    :bigint
    add_column :ems_clusters, :effective_memory, :bigint

    say_with_time("Migrate data from reserved table") do
      EmsCluster.includes(:reserved_rec).each do |e|
        e.reserved_hash_migrate(:effective_cpu, :effective_memory)
      end
    end
  end

  def self.down
    remove_column :ems_clusters, :effective_cpu
    remove_column :ems_clusters, :effective_memory
  end
end
