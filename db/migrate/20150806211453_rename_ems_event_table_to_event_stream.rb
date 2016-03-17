class RenameEmsEventTableToEventStream < ActiveRecord::Migration
  include MigrationHelper
  include MigrationHelper::SharedStubs

  class EventStream < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class EmsEvent < ActiveRecord::Base; end

  def up
    rename_table :ems_events, :event_streams

    add_column :event_streams, :type, :string
    say_with_time("Updating Type in EventStreams") do
      EventStream.update_all(:type => 'EmsEvent')
    end

    if RrPendingChange.table_exists?
      say_with_time("Renaming ems_events to event_streams in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "ems_events").update_all(:change_table => "event_streams")
      end

      say_with_time("Renaming ems_events to event_streams in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "ems_events").update_all(:table_name => "event_streams")
      end
    end

    change_table :event_streams do |t|
      t.references :target, :polymorphic => true, :type => :bigint
    end
  end

  def down
    remove_column :event_streams, :type

    change_table :event_streams do |t|
      t.remove_references :target, :polymorphic => true
    end

    rename_table :event_streams, :ems_events

    if RrPendingChange.table_exists?
      say_with_time("Renaming event_streams to ems_events in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "event_streams").update_all(:change_table => "ems_events")
      end

      say_with_time("Renaming event_streams to ems_events in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "event_streams").update_all(:table_name => "ems_events")
      end
    end
  end
end
