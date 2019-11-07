class TransformationMapping::VmMigrationValidator
  require 'miq-hash_struct'

  VM_CONFLICT = "conflict".freeze
  VM_EMPTY_NAME = "empty_name".freeze
  VM_UNSUPPORTED_NAME = 'unsupported_name'.freeze
  VM_IN_OTHER_PLAN = "in_other_plan".freeze
  VM_INACTIVE = "inactive".freeze
  VM_INVALID = "invalid".freeze
  VM_MIGRATED = "migrated".freeze
  VM_NOT_EXIST = "not_exist".freeze
  VM_VALID = "ok".freeze

  def initialize(mapping, vm_list = nil, service_template_id = nil)
    @mapping = mapping
    @vm_list = vm_list
    @service_template_id = service_template_id.try(:to_i)
  end

  def validate
    @vm_list.present? ? identify_vms : select_vms
  end

  def select_vms
    valid_list = []

    Vm.where(:ems_cluster => mapped_clusters).includes(:lans, :storages).each do |vm|
      reason = validate_vm(vm, true)
      valid_list << VmMigrateStruct.new(vm.name, vm, VM_VALID, reason) if reason == VM_VALID
    end

    {"valid" => valid_list}
  end

  def identify_vms
    valid_list = []
    invalid_list = []
    conflict_list = []

    vm_names = @vm_list.collect { |row| row['name'] }
    vm_objects = Vm.where(:name => vm_names).includes(:ems_cluster, :lans, :storages, :host, :ext_management_system)

    @vm_list.each do |row|
      vm_name = row['name']

      if vm_name.blank?
        invalid_list << VmMigrateStruct.new('', nil, VM_INVALID, VM_EMPTY_NAME)
        next
      end

      if vm_objects.select { |vm| vm.name == vm_name && !vm.active? }.any?
        invalid_list << VmMigrateStruct.new(vm_name, nil, VM_INVALID, VM_INACTIVE)
        next
      end

      vms = vm_objects.select { |vm| mapped_clusters.include?(vm.ems_cluster) }
      vms = vms.select { |vm| vm.name == vm_name }
      vms = vms.select { |vm| vm.uid_ems == row['uid_ems'] } if row['uid_ems'].present?
      vms = vms.select { |vm| vm.host.name == row['host'] } if row['host'].present?
      vms = vms.select { |vm| vm.ext_management_system.name == row['provider'] } if row['provider'].present?

      if vms.empty?
        invalid_list << VmMigrateStruct.new(vm_name, nil, VM_INVALID, VM_NOT_EXIST)
      elsif vms.size == 1
        vm = vms.first
        reason = validate_vm(vm, false)
        if reason == VM_VALID
          valid_list << VmMigrateStruct.new(vm.name, vm, VM_VALID, reason)
        else
          invalid_list << VmMigrateStruct.new(vm.name, vm, VM_INVALID, reason)
        end
      else
        vms.each { |v| conflict_list << VmMigrateStruct.new(v.name, v, VM_CONFLICT, VM_CONFLICT) }
      end
    end

    {
      "valid"      => valid_list,
      "invalid"    => invalid_list,
      "conflicted" => conflict_list
    }
  end

  def validate_vm(vm, quick = true)
    validate_result = vm_migration_status(vm)
    return validate_result unless validate_result == VM_VALID

    # The VM name must be valid in the destination provider
    valid_vm_name = validate_vm_name(vm)
    return valid_vm_name unless valid_vm_name == VM_VALID

    # a valid vm must find all resources in the mapping and has never been migrated
    invalid_list = []
    issue = no_mapping_list(invalid_list, "storages", vm.datastores - mapped_storages)
    return no_mapping_msg(invalid_list) if issue && quick

    no_mapping_list(invalid_list, "lans", vm.lans - mapped_lans)

    invalid_list.present? ? no_mapping_msg(invalid_list) : VM_VALID
  end

  def vm_migration_status(vm)
    vm_as_resources = ServiceResource.joins(:service_template).where(:resource => vm, :service_templates => {:type => 'ServiceTemplateTransformationPlan'})

    # VM has not been migrated before
    return VM_VALID if vm_as_resources.empty?

    return VM_MIGRATED unless vm_as_resources.where(:status => ServiceResource::STATUS_COMPLETED).empty?

    # VM failed in previous migration
    vm_as_resources.all? { |rsc| rsc.status == ServiceResource::STATUS_FAILED || rsc.service_template_id == @service_template_id  } ? VM_VALID : VM_IN_OTHER_PLAN
  end

  def no_mapping_list(invalid_list, data_type, new_records)
    return false if new_records.blank?
    invalid_list << "#{data_type}: %{list}" % {:list => new_records.collect(&:name).join(", ")}
    true
  end

  def no_mapping_msg(list)
    "Mapping source not found - %{list}" % {:list => list.join('. ')}
  end

  def mapped_clusters
    @mapped_clusters ||= EmsCluster.where(:id => @mapping.transformation_mapping_items.where(:source_type => 'EmsCluster').select(:source_id))
  end

  def mapped_storages
    @mapped_storages ||= Storage.where(:id => @mapping.transformation_mapping_items.where(:source_type => 'Storage').select(:source_id))
  end

  def mapped_lans
    @mapped_lans ||= Lan.where(:id => @mapping.transformation_mapping_items.where(:source_type => 'Lan').select(:source_id))
  end

  def destination_cluster(vm)
    @mapping.transformation_mapping_items.find_by(:source => vm.ems_cluster)&.destination
  end

  def validate_vm_name(vm)
    send("validate_vm_name_#{destination_cluster(vm).ext_management_system.emstype}", vm) ? VM_VALID : VM_UNSUPPORTED_NAME
  end

  def validate_vm_name_rhevm(vm)
    # Regexp from oVirt code: frontend/webadmin/modules/uicommonweb/src/main/java/org/ovirt/engine/ui/uicommonweb/validation/BaseI18NValidation.java
    vm.name =~ /^[\p{L}0-9._-]*$/
  end

  def validate_vm_name_openstack(vm)
    # Regexp decided after discussion with Bernard Cafarelli
    vm.name =~ /^[[:graph:]\s]+$/
  end

  class VmMigrateStruct < MiqHashStruct
    def initialize(vm_name, vm, status, reason)
      options = {"name" => vm_name, "status" => status, "reason" => reason}

      if vm.present?
        options.merge!(
          "cluster"                   => vm.ems_cluster.try(:name) || '',
          "path"                      => vm.ext_management_system ? "#{vm.ext_management_system.name}/#{vm.v_parent_blue_folder_display_path}" : '',
          "allocated_size"            => vm.allocated_disk_storage,
          "id"                        => vm.id.to_s,
          "ems_cluster_id"            => vm.ems_cluster_id.to_s,
          "warm_migration_compatible" => vm.supports_warm_migrate?
        )
      end

      super(options)
    end
  end
end
