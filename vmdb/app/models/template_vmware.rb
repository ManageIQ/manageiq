class TemplateVmware < TemplateInfra
  include_concern 'VmOrTemplate::VmwareShared'

  def cloneable?
    true
  end
end
