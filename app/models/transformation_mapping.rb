class TransformationMapping < ApplicationRecord
  VM_CONFLICT = "conflict".freeze
  VM_EMPTY_NAME = "empty_name".freeze
  VM_IN_OTHER_PLAN = "in_other_plan".freeze
  VM_MIGRATED = "migrated".freeze
  VM_NOT_EXIST = "not_exist".freeze
  VM_VALID = "ok".freeze
  VM_INACTIVE = "inactive".freeze

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
    valid_list = []

    transformation_mapping_items.where(:source_type => EmsCluster).collect(&:source).each do |cluster|
      cluster.vms.each do |vm|
        reason = validate_vm(vm, true)
        valid_list << describe_vm(vm, reason) if reason == VM_VALID
      end
    end

    {"valid_vms" => valid_list}
  end

  def identify_vms(vm_list)
    valid_list = []
    invalid_list = []
    conflict_list = []

    vm_list.each do |row|
      vm_name = row['name']

      if vm_name.blank?
        invalid_list << describe_non_vm(vm_name)
        next
      end

      query = Vm.where(:name => vm_name)
      query = query.where(:uid_ems => row['uid_ems']) if row['uid_ems'].present?
      query = query.joins(:host).where(:hosts => {:name => row['host']}) if row['host'].present?
      query = query.joins(:ext_management_system).where(:ext_management_systems => {:name => row['provider']}) if row['provider'].present?

      vms = query.to_a
      if vms.size.zero?
        invalid_list << describe_non_vm(vm_name)
      elsif vms.size == 1
        reason = validate_vm(vms.first, false)
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
      "reason" => vm_name.blank? ? VM_EMPTY_NAME : VM_NOT_EXIST
    }
  end

  def describe_vm(vm, reason)
    {
      "name"           => vm.name,
      "cluster"        => vm.ems_cluster.try(:name) || '',
      "path"           => vm.ext_management_system ? "#{vm.ext_management_system.name}/#{vm.v_parent_blue_folder_display_path}" : '',
      "allocated_size" => vm.allocated_disk_storage,
      "id"             => vm.id,
      "ems_cluster_id" => vm.ems_cluster_id,
      "reason"         => reason
    }
  end

  def validate_vm(vm, quick = true)
    validate_result = vm.validate_v2v_migration
    return validate_result unless validate_result == VM_VALID

    # a valid vm must find all resources in the mapping and has never been migrated
    invalid_list = []

    unless valid_cluster?(vm)
      invalid_list << "cluster: %{name}" % {:name => vm.ems_cluster.name}
      return no_mapping_msg(invalid_list) if quick
    end

    invalid_storages = unmapped_storages(vm)
    if invalid_storages.present?
      invalid_list << "storages: %{list}" % {:list => invalid_storages.collect(&:name).join(", ")}
      return no_mapping_msg(invalid_list) if quick
    end

    invalid_lans = unmapped_lans(vm)
    if invalid_lans.present?
      invalid_list << "lans: %{list}" % {:list => invalid_lans.collect(&:name).join(', ')}
      return no_mapping_msg(invalid_list) if quick
    end

    invalid_list.present? ? no_mapping_msg(invalid_list) : VM_VALID
  end

  def no_mapping_msg(list)
    "Mapping source not found - %{list}" % {:list => list.join('. ')}
  end

  def valid_cluster?(vm)
    transformation_mapping_items.where(:source => vm.ems_cluster).exists?
  end

  # return an empty array if all storages are valid for transformation
  # otherwise return an array of invalid datastores
  def unmapped_storages(vm)
    vm.datastores - transformation_mapping_items.where(:source => vm.datastores).collect(&:source)
  end

  # return an empty array if all lans are valid for transformation
  # otherwise return an array of invalid lans
  def unmapped_lans(vm)
    vm.lans - transformation_mapping_items.where(:source => vm.lans).collect(&:source)
  end
end
