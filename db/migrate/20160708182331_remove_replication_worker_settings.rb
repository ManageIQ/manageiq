class RemoveReplicationWorkerSettings < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  def up
    say_with_time("Removing replication worker settings") do
      SettingsChange.where("key LIKE ?", "/workers/worker_base/replication_worker%").delete_all
    end
  end
end
