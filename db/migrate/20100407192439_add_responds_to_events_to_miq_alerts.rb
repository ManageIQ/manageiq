class AddRespondsToEventsToMiqAlerts < ActiveRecord::Migration
  class MiqAlert < ActiveRecord::Base; end

  def self.up
    add_column      :miq_alerts,  :responds_to_events,    :text
    add_column      :miq_alerts,  :enabled,               :boolean

    say_with_time("Update MiqAlert enabled") do
      # Default enabled to false and force responds_to_events to be set where applicable (before_save)
      MiqAlert.update_all(:enabled => false)
    end
  end

  def self.down
    remove_column   :miq_alerts,  :enabled
    remove_column   :miq_alerts,  :responds_to_events
  end
end
