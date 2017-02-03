class ConfigurationScriptSource < ApplicationRecord
  has_many    :configuration_script_payloads
  belongs_to  :authentication
  belongs_to  :manager, :class_name => "ExtManagementSystem"
end
