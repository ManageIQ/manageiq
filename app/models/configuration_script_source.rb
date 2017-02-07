class ConfigurationScriptSource < ApplicationRecord
  has_many    :configuration_script_payloads
  belongs_to  :manager, :class_name => "ExtManagementSystem"

  virtual_total :total_payloads, :configuration_script_payloads
end
