class ConfigurationProfile < ActiveRecord::Base
  belongs_to :provider
  has_many :configuration_profile_scripts
  has_many :customization_scripts, :through => :configuration_profile_scripts
  belongs_to :operating_system_flavor
end
