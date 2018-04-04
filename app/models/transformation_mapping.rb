class TransformationMapping < ApplicationRecord
  VM_VALID = N_("OK").freeze

  has_many :transformation_mapping_items, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true

  def destination(source)
    transformation_mapping_items.find_by(:source => source).try(:destination)
  end

  def select_vms
    valid_list = []

    transformation_mapping_items.where(:source_type => EmsCluster).collect(&:source).each do |cluster|
      cluster.vms.each do |vm|
        reason = validate_vm(vm)
        valid_list << describe_vm(vm, reason) if reason == VM_VALID
      end
    end

    {"valid_vms" => valid_list}
  end

  def validate_vm(vm)
    invalid_list = []
    invalid_list << N_("cluster: %{name}") % {:name => vm.ems_cluster.name} unless valid_cluster?(vm)

    invalid_storages = validate_storages(vm)
    invalid_list << N_("storages: %{list}") % {:list => invalid_storages.join(", ")} if invalid_storages.present?

    invalid_lans = validate_lans(vm)
    invalid_list << N_("lans: %{list}") % {:list => invalid_lans.join(', ')} if invalid_lans.present?

    return N_("Not defined source for this migration - %{list}") % {:list => invalid_list.join('. ')} if invalid_list.present?

    vm.valid_for_v2v_migration? ? VM_VALID : N_('VM has been migrated')
  end

  def valid_cluster?(vm)
    transformation_mapping_items.where(:source => vm.ems_cluster).present?
  end

  # return an empty array if all storages are valid for transformation
  # otherwise return an array of invalid datastores
  def validate_storages(vm)
    vm.datastores - transformation_mapping_items.where(:source => vm.datastores).collect(&:source)
  end

  # return an empty array if all lans are valid for transformation
  # otherwise return an array of invalid lans
  def validate_lans(vm)
    vm.lans - transformation_mapping_items.where(:source => vm.lans).collect(&:source)
  end
end
