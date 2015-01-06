module VmAmazon::Operations
  include_concern 'Guest'
  include_concern 'Power'

  def raw_destroy
    raise "VM has no #{ui_lookup(:table => "ext_management_systems")}, unable to destroy VM" unless self.ext_management_system
    with_provider_object { |instance| instance.terminate }
    self.update_attributes!(:raw_power_state => "pending") # show state as suspended
  end
end
