class ProvisioningManager < ExtManagementSystem
  has_many :operating_system_flavors, :dependent => :destroy
  has_many :customization_scripts,    :dependent => :destroy
  has_many :customization_script_ptables
  has_many :customization_script_media

  def self.hostname_required?
    false
  end
end
