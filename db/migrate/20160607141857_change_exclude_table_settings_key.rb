class ChangeExcludeTableSettingsKey < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  def up
    say_with_time("Moving exclude tables configuration") do
      changes = SettingsChange.where(:key => "/workers/worker_base/replication_worker/replication/exclude_tables")
      changes.each { |change| change.update_attributes!(:key => "/replication/exclude_tables") }
    end
  end
end
