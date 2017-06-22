class AddLimitsResourcesToContainerDefinitions < ActiveRecord::Migration[5.0]
  def change
    add_column :container_definitions, :request_cpu,    :float  # cores
    add_column :container_definitions, :request_memory, :bigint # bytes
    add_column :container_definitions, :limit_cpu,      :float  # cores
    add_column :container_definitions, :limit_memory,   :bigint # bytes
  end
end
