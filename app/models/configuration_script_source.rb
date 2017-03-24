class ConfigurationScriptSource < ApplicationRecord
  has_many    :configuration_script_payloads
  belongs_to  :authentication
  belongs_to  :manager, :class_name => "ExtManagementSystem"

  virtual_total :total_payloads, :configuration_script_payloads

  def self.class_for_manager(manager)
    descendants.find { |klass| klass.name.start_with? manager.type }
  end
end
