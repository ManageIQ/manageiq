class RemoveMiqServerProductUpdateJoinTable < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  EXCLUDES_KEY = "/workers/worker_base/replication_worker/replication/exclude_tables".freeze

  def up
    drop_join_table(:miq_servers, :product_updates)

    say_with_time("Removing miq_servers_product_updates from replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).each do |s|
        s.value.delete("miq_servers_product_updates")
        s.save!
      end
    end
  end

  def down
    create_join_table(:miq_servers, :product_updates) do |t|
      t.bigint :miq_server_id, :null => false
      t.bigint :product_update_id, :null => false
    end

    say_with_time("Adding composite primary key for miq_servers_product_updates") do
      execute("ALTER TABLE miq_servers_product_updates ADD PRIMARY KEY (product_update_id, miq_server_id)")
    end

    say_with_time("Adding miq_servers_product_updates to replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).each do |s|
        s.value << "miq_servers_product_updates"
        s.save!
      end
    end
  end
end
