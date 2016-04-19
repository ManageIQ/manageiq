class RemoveConfigurationsFromReplicationExcludes < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  EXCLUDES_KEY = "/workers/worker_base/replication_worker/replication/exclude_tables".freeze

  def up
    say_with_time("Removing configurations from replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).each do |s|
        s.value.delete("configurations")
        s.save!
      end
    end
  end

  def down
    say_with_time("Adding configurations to replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).each do |s|
        s.value << "configurations"
        s.save!
      end
    end
  end
end
