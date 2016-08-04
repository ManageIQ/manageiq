class ChangeExcludeTableSettingsKey < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  OLD_KEY = "/workers/worker_base/replication_worker/replication/exclude_tables".freeze
  NEW_KEY = "/replication/exclude_tables".freeze

  def up
    say_with_time("Moving exclude tables configuration") do
      SettingsChange.where(:key => OLD_KEY).update_all(:key => NEW_KEY)
    end
  end

  def down
    SettingsChange.where(:key => NEW_KEY).update_all(:key => OLD_KEY)
  end
end
