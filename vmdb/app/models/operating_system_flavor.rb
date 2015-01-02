class OperatingSystemFlavor < ActiveRecord::Base
  belongs_to :provider
  belongs_to :provisioning_manager

  has_and_belongs_to_many :customization_scripts
end
