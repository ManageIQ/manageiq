class OperatingSystemFlavor < ActiveRecord::Base
  belongs_to :provider

  has_many :customization_scripts, :through => :operating_system_flavor_scripts
  has_many :operating_system_flavor_scripts
end
