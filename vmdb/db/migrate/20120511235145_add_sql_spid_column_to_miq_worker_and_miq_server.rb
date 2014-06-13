class AddSqlSpidColumnToMiqWorkerAndMiqServer < ActiveRecord::Migration
  def change
    add_column :miq_workers, :sql_spid, :integer
    add_column :miq_servers, :sql_spid, :integer

    # Data migration for reserves is done in the next migration
  end
end
