class VmOrTemplateTag < ProviderTag
  belongs_to :vm_or_templates, :foreign_key => :guid
end
