class TransformationMapping < ApplicationRecord
  VM_VALID = N_("OK").freeze
  VM_NON_EXIST = N_("VM does not exist").freeze
  VM_CONFLICT = N_("Conflict").freeze

  has_many :transformation_mapping_items, :dependent => :destroy
  has_many :service_resources, :as => :resource, :dependent => :nullify
  has_many :service_templates, :through => :service_resources

  validates :name, :presence => true, :uniqueness => true

  def destination(source)
    transformation_mapping_items.find_by(:source => source).try(:destination)
  end

  # vm_list: collection of hashes, each descriping a VM.
  def validate_vms(vm_list = nil)
    vm_list.present? ? identify_vms(vm_list) : select_vms
  end

  private

  def select_vms
    # TBD
  end

  def identify_vms(vm_list)
    valid_list = []
    invalid_list = []
    conflict_list = []

    vm_list.each do |row|
      vm_name = row['name']

      query = Vm.where(:name => vm_name)
      query = query.where(:uid_ems => row['uid_ems']) if row['uid_ems'].present?
      query = query.joins(:host).where(:hosts => {:name => row['host']}) if row['host'].present?
      query = query.joins(:ext_management_system).where(:ext_management_systems => {:name => row['provider']}) if row['provider'].present?

      vms = query.to_a
      invalid_list << describe_non_vm(vm_name) if vms.empty?

      if vms.size == 1
        reason = validate_vm(vms.first)
        (reason == VM_VALID ? valid_list : invalid_list) << describe_vm(vms.first, reason)
      else
        vms.each { |vm| conflict_list << describe_vm(vm, VM_CONFLICT) }
      end
    end

    {
      "valid_vms"    => valid_list,
      "invalid_vms"  => invalid_list,
      "conflict_vms" => conflict_list
    }
  end

  def describe_non_vm(vm_name)
    {
      "name"   => vm_name,
      "reason" => VM_NON_EXIST
    }
  end

  def describe_vm(vm, reason)
    # formate to be finalized
    {
      "name"           => vm.name,
      "cluster"        => vm.ems_cluster.name,
      "path"           => "#{vm.ext_management_system.name}/#{vm.parent_blue_folder_path(:exclude_non_display_folders => true)}",
      "allocated_size" => vm.allocated_disk_storage,
      "id"             => vm.id,
      "reason"         => reason
    }
  end

  # return an empty string if the vm can be migrated
  # otherwise the reason why it can't be migrated
  def validate_vm(vm)
    # a valid vm must find all resources in the mapping and has never been migrated
    VM_VALID
  end
end
