class TransformationMapping < ApplicationRecord
  require_nested :VmMigrationValidator

  has_many :transformation_mapping_items, :dependent => :destroy
  has_many :service_resources, :as => :resource, :dependent => :nullify
  has_many :service_templates, :through => :service_resources

  validates :name, :presence => true, :uniqueness => true

  def destination(source)
    transformation_mapping_items.find_by(:source => source).try(:destination)
  end

  # vm_list: collection of hashes, each descriping a VM.
  def search_vms_and_validate(vm_list = nil)
    VmMigrationValidator.new(self, vm_list).validate
  end
end
