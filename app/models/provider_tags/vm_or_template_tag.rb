class VmOrTemplateTag < ProviderTag
  belongs_to :vm_or_template, :foreign_key => :resource_id, :primary_key => :ems_ref

  # TODO: Can we automatically use the VmTag subclass from here if the :type
  # column is a Vm instead of a Template?
end
