class AuthenticationConfigurationScriptBase < ApplicationRecord
  belongs_to :authentication
  belongs_to :configuration_script_base, :foreign_key => 'configuration_script_id'
end
