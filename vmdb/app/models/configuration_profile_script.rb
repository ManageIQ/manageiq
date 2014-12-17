class ConfigurationProfileScript < ActiveRecord::Base
  belongs_to :configuration_profile
  belongs_to :customization_script
end
