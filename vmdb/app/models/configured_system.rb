class ConfiguredSystem < ActiveRecord::Base
  belongs_to :provider
  belongs_to :configuration_manager

  belongs_to :provisioning_profile
  has_and_belongs_to_many :customization_scripts
  belongs_to :operating_system_flavor
  belongs_to :configuration_profile
end
