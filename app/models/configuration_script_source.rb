class ConfigurationScriptSource < ApplicationRecord
  has_many    :configuration_script_payloads
  belongs_to  :authentication
  belongs_to  :manager, :class_name => "ExtManagementSystem"

  virtual_total :total_payloads, :configuration_script_payloads

  def self.class_from_request_data(data)
    manager = ExtManagementSystem.find(data['manager_resource'])
    type = "#{manager.type}::ConfigurationScriptSource"
    descendants.find { |klass| klass.name == type }
  end
end
