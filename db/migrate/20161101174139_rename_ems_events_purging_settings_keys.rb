class RenameEmsEventsPurgingSettingsKeys < ActiveRecord::Migration[5.0]
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  OLD_KEYS = %w(
    /ems_events/history/keep_ems_events
    /workers/worker_base/schedule_worker/ems_events_purge_interval
  ).freeze
  NEW_KEYS = %w(
    /event_streams/history/keep_events
    /workers/worker_base/schedule_worker/event_streams_purge_interval
  ).freeze

  def up
    say_with_time("Renaming ems_events purging settings keys") do
      OLD_KEYS.zip(NEW_KEYS).each do |old, new|
        SettingsChange.where(:key => old).update_all(:key => new)
      end
    end
  end

  def down
    OLD_KEYS.zip(NEW_KEYS).each do |old, new|
      SettingsChange.where(:key => new).update_all(:key => old)
    end
  end
end
