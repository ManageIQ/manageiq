class RenameMiqEventTableToMiqEventDefinition < ActiveRecord::Migration
  include MigrationHelper

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
  end
end
