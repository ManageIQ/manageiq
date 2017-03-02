class VmTag < VmOrTemplateTag
  belongs_to :vm, :foreign_key => :resource_id, :primary_key => :guid
end
