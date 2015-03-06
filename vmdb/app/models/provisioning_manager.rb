class ProvisioningManager < ExtManagementSystem
  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,    :dependent => :destroy
  has_many :customization_script_ptables
  has_many :customization_script_media

  def hostname_ipaddress_required?
    false
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
VMDB::Util.eager_load_subclasses('ProvisioningManager')
