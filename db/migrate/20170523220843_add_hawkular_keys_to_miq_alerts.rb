class AddHawkularKeysToMiqAlerts < ActiveRecord::Migration[5.0]
  class MiqAlert < ActiveRecord::Base
    serialize :hawkular_keys
  end

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = '_disabled'
  end

  def change
    add_column(:miq_alerts, :hawkular_keys, :text)

    reversible do |direction|
      direction.up do
        MiqAlert.where(:db => 'MiddlewareServer').find_each do |alert|
          alert.hawkular_keys = {}

          ExtManagementSystem.where(:type => 'ManageIQ::Providers::Hawkular::MiddlewareManager').find_each do |ems|
            alert.hawkular_keys["ems_#{ems.id}"] = "MiQ-#{alert.id}"
          end

          alert.save
        end
      end
    end
  end
end
