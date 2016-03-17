class RenameMiqEventTableToMiqEventDefinition < ActiveRecord::Migration
  include MigrationHelper
  include MigrationHelper::SharedStubs

  class MiqSet < ActiveRecord::Base; end

  class Relationship < ActiveRecord::Base; end

  class MiqEvent < ActiveRecord::Base; end

  class MiqEventDefinition < ActiveRecord::Base; end

  def up
    rename_table  :miq_events, :miq_event_definitions

    say_with_time("Renaming MiqEventSet to MiqEventDefinitionSet in 'miq_sets'") do
      MiqSet.where(:set_type => 'MiqEventSet').update_all(:set_type => 'MiqEventDefinitionSet')
    end

    say_with_time("Renaming MiqEventSet to MiqEventDefinitionSet in 'relationships'") do
      Relationship.where(:resource_type => 'MiqEventSet').update_all(:resource_type => "MiqEventDefinitionSet")
    end

    say_with_time("Renaming MiqEvent to MiqEventDefinition in 'relationships'") do
      Relationship.where(:resource_type => 'MiqEvent').update_all(:resource_type => "MiqEventDefinition")
    end

    if RrPendingChange.table_exists?
      say_with_time("Renaming miq_events to miq_event_definitions in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "miq_events").update_all(:change_table => "miq_event_definitions")
      end

      say_with_time("Renaming miq_events to miq_event_definitions in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "miq_events").update_all(:table_name => "miq_event_definitions")
      end
    end
  end

  def down
    rename_table  :miq_event_definitions, :miq_events

    say_with_time("Renaming MiqEventDefinitionSet to MiqEventSet in 'miq_sets'") do
      MiqSet.where(:set_type => 'MiqEventDefinitionSet').update_all(:set_type => 'MiqEventSet')
    end

    say_with_time("Renaming MiqEventDefinitionSet to MiqEventSet in 'relationships'") do
      Relationship.where(:resource_type => 'MiqEventDefinitionSet').update_all(:resource_type => "MiqEventSet")
    end

    say_with_time("Renaming MiqEventDefinition to MiqEvent in 'relationships'") do
      Relationship.where(:resource_type => 'MiqEventDefinition').update_all(:resource_type => "MiqEvent")
    end

    if RrPendingChange.table_exists?
      say_with_time("Renaming miq_event_definitions to miq_events in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "miq_event_definitions").update_all(:change_table => "miq_events")
      end

      say_with_time("Renaming miq_event_definitions to miq_events in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "miq_event_definitions").update_all(:table_name => "miq_events")
      end
    end
  end
end
