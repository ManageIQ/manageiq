class ProvisioningManager < ActiveRecord::Base
  include EmsRefresh::Manager
  belongs_to :provider

  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,    :dependent => :destroy
end
