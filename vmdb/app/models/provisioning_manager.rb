class ProvisioningManager < ExtManagementSystem
  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,    :dependent => :destroy
  has_many :customization_script_ptables
  has_many :customization_script_media

  def hostname_ipaddress_required?
    false
  end
end
