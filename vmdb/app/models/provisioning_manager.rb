class ProvisioningManager < ActiveRecord::Base
  belongs_to :provider

  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,    :dependent => :destroy
end
