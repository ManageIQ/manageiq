class TemplateVmware < TemplateInfra
  include_concern 'VmOrTemplate::VmwareShared'

  def cloneable?
    true
  end

  def self.calculate_power_state(raw_power_state)
    # not sure why this has to be true, but the logic in ems_refresh_core_worker
    # suggests that a template_vmware can magically change into a vm_vmware by
    # simply changing a setting
    VmVmware.calculate_power_state(raw_power_state)
  end
end
