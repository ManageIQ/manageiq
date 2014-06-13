class VmMigrateWorkflow < MiqRequestWorkflow
  def self.base_model
    VmMigrateWorkflow
  end

  def self.automate_dialog_request
    'UI_VM_MIGRATE_INFO'
  end

  def self.default_dialog_file
    'vm_migrate_dialogs'
  end

  def create_request(values, requester_id, auto_approve=false)
    event_message = "VM Migrate requested by [#{requester_id}] for VM:#{values[:src_host_id].inspect}"
    super(values, requester_id, 'Vm', 'vm_migrate_request_created', event_message, auto_approve)
  end

  def update_request(request, values, requester_id)
    event_message = "VM Migrate request was successfully updated by [#{requester_id}] for VM:#{values[:src_host_id].inspect}"
    super(request, values, requester_id, 'Vm', 'vm_migrate_request_updated', event_message)
  end

  def get_source_and_targets(refresh=false)
    return @target_resource if @target_resource && refresh==false

    ems = @values[:src_ids].to_miq_a.collect {|v_id| v = Vm.find_by_id(v_id); v.ext_management_system}.uniq.compact

    # If all the selected VMs share the same EMS we can present a list of CIs.
    return @target_resource={} if ems.length != 1

    result = {:ems => ci_to_hash_struct(ems.first)}
    add_target(:placement_host_name,    :host,    Host,         result)
    add_target(:placement_ds_name,      :storage, Storage,      result)
    add_target(:placement_cluster_name, :cluster, EmsCluster,   result)
    add_target(:placement_rp_name,      :respool, ResourcePool, result)
    add_target(:placement_folder_name,  :folder,  EmsFolder,    result)

    unless result[:folder_id].nil?
      result[:datacenter] = find_datacenter_for_ci(result[:folder], get_ems_metadata_tree(result))
      result[:datacenter_id] = result[:datacenter].id unless result[:datacenter].nil?
    else
      add_target(:placement_dc_name, :datacenter, EmsFolder, result)
    end
    rails_logger('get_source_and_targets', 1)
    return @target_resource=result
  end

  def validate_placement(field, values, dlg, fld, value)
    # check the :placement_auto flag, then make sure the field is not blank
    return nil unless value.blank?
    return nil unless get_value(values[field]).blank?
    return "#{required_description(dlg, fld)} is required"
  end

  private

  def allowed_ci(ci, relats, filtered_ids=nil)
    sources = resources_for_ui
    return {} if sources.blank?

    super(ci, relats, sources, filtered_ids)
  end
end
