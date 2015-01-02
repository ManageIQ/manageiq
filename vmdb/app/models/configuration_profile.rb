class ConfigurationProfile < ActiveRecord::Base
  belongs_to :provider
  has_and_belongs_to_many :customization_scripts
  belongs_to :operating_system_flavor
end
