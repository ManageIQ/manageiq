require Rails.root.join('lib/migration_helper')

class RenameAutomationUriToCustomButton < ActiveRecord::Migration
  include MigrationHelper::SharedStubs

  class MiqSet < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end
  class Relationship < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    rename_table :automation_uris, :custom_buttons

    say_with_time("Renaming AutomationUriSet to CustomButtonSet in 'miq_sets'") do
      MiqSet.where(:set_type => 'AutomationUriSet').update_all(:set_type => "CustomButtonSet")
    end

    say_with_time("Renaming AutomationUriSet to CustomButtonSet in 'relationships'") do
      Relationship.where(:resource_type => 'AutomationUriSet').update_all(:resource_type => "CustomButtonSet")
    end

    say_with_time("Renaming AutomationUri to CustomButton in 'relationships'") do
      Relationship.where(:resource_type => 'AutomationUri').update_all(:resource_type => "CustomButton")
    end

    if RrPendingChange.table_exists?
      say_with_time("Renaming automation_uris to custom_buttons in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "automation_uris").update_all(:change_table => "custom_buttons")
      end

      say_with_time("Renaming automation_uris to custom_buttons in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "automation_uris").update_all(:table_name => "custom_buttons")
      end
    end
  end

  def down
    rename_table :custom_buttons, :automation_uris

    say_with_time("Renaming CustomButtonSet to AutomationUriSet in 'miq_sets'") do
      MiqSet.where(:set_type => 'CustomButtonSet').update_all(:set_type => "AutomationUriSet")
    end

    say_with_time("Renaming CustomButtonSet to AutomationUriSet in 'relationships'") do
      Relationship.where(:resource_type => 'CustomButtonSet').update_all(:resource_type => "AutomationUriSet")
    end

    say_with_time("Renaming CustomButton to AutomationUri in 'relationships'") do
      Relationship.where(:resource_type => 'CustomButton').update_all(:resource_type => "AutomationUri")
    end

    if RrPendingChange.table_exists?
      say_with_time("Renaming custom_buttons to automation_uris in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "custom_buttons").update_all(:change_table => "automation_uris")
      end

      say_with_time("Renaming custom_buttons to automation_uris in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "custom_buttons").update_all(:table_name => "automation_uris")
      end
    end
  end
end
