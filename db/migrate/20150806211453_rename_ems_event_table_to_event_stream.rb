class RenameEmsEventTableToEventStream < ActiveRecord::Migration
  disable_ddl_transaction!
  include MigrationHelper

  class EventStream < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  class EmsEvent < ActiveRecord::Base; end

  def up
    rename_table :ems_events, :event_streams

    add_column :event_streams, :type, :string
    say_with_time("Updating Type in EventStreams") do
      base_relation = EventStream.where(:type => nil)
      say "#{base_relation.size} records with batch size 1000", :subitem
      loop do
        count = base_relation.limit(1000).update_all(:type => 'EmsEvent')
        print "."
        break if count == 0
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
  end
end
