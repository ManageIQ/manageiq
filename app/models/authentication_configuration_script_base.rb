class AuthenticationConfigurationScriptBase < ApplicationRecord
  belongs_to :authentication
  belongs_to :configuration_script_base
end
