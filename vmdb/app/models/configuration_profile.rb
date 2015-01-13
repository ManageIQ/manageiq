class ConfigurationProfile < ActiveRecord::Base
  include NewWithTypeStiMixin
  belongs_to :configuration_manager
end
