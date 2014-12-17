class ConfiguredSystem < ActiveRecord::Base
  belongs_to :provider
  has_many :configured_system_scripts
  has_many :customization_scripts, :through => :configured_system_scripts
  belongs_to :operating_system_flavor
end
