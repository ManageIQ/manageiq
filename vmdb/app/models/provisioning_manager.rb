class ProvisioningManager < ActiveRecord::Base
  belongs_to :provider
  has_many :operating_system_flavors
end
