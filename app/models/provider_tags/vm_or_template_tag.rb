class VmOrTemplateTag < ProviderTag
  belongs_to :vm_or_template, :foreign_key => :resource_id, :primary_key => :guid
end
