class RemoveLastReplicationColumnsFromMiqDatabase < ActiveRecord::Migration[5.0]
  def change
    remove_column :miq_databases, :last_replication_id, :bigint
    remove_column :miq_databases, :last_replication_count, :bigint
  end
end
