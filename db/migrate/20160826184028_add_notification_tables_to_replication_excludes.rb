class AddNotificationTablesToReplicationExcludes < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  EXCLUDES_KEY = "/workers/worker_base/replication_worker/replication/exclude_tables".freeze

  def up
    say_with_time("Adding notification tables to replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).each do |s|
        s.value << "notifications"
        s.value << "notification_recipients"
        s.value << "notification_types"
        s.save!
      end
    end
  end

  def down
    say_with_time("Removing notification tables from replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).each do |s|
        s.value.delete("notifications")
        s.value.delete("notification_recipients")
        s.value.delete("notification_types")
        s.save!
      end
    end
  end
end
