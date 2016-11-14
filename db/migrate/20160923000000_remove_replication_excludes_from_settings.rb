class RemoveReplicationExcludesFromSettings < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  EXCLUDES_KEY = "/replication/exclude_tables".freeze

  def up
    say_with_time("Removing configured replication excludes") do
      SettingsChange.where(:key => EXCLUDES_KEY).delete_all
    end
  end
end
