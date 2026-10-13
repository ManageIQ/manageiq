class MiqProvisionOrchWorkflow < MiqProvisionVirtWorkflow
  def self.source_object_class
    OrchestrationTemplate
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false

    vm_id = get_value(@values[:src_vm_id])
    rails_logger('get_source_and_targets', 0)
    svm = OrchestrationTemplate.find_by(:id => vm_id)

    return @target_resource = {} if svm.nil?

    result = {}
    result[:vm] = ci_to_hash_struct(svm)
    result[:ems] = ci_to_hash_struct(svm.ext_management_system)

    return result if result.blank?

    add_target(:host_id, :host, Host, result)
    add_target(:storage_id, :storage, Storage, result)
    add_target(:resource_pool_id, :respool, ResourcePool, result)
    add_target(:ems_folder_id, :folder, EmsFolder, result)

    if result[:folder_id].nil?
      add_target(:datacenter_id, :datacenter, EmsFolder, result)
    else
      result[:datacenter] = find_datacenter_for_ci(result[:folder], get_ems_metadata_tree(result))
      result[:datacenter_id] = result[:datacenter].id unless result[:datacenter].nil?
    end

    rails_logger('get_source_and_targets', 1)
    @target_resource = result
  end

  # Run the relationship methods and perform set intersections on the returned values.
  # Optional starting set of results maybe passed in.
  def allowed_ci(ci, relats, filtered_ids = nil)
    return {} if get_value(@values[:placement_auto]) == true
    return {} if (sources = resources_for_ui).blank?

    get_ems_metadata_tree(sources)
    super(ci, relats, sources, filtered_ids)
  end

  def self.automate_dialog_request
    nil
  end

  def self.default_dialog_file
    "miq_provision_vmware_dialogs_ovf"
  end

  def update_field_visibility(options = {})
  end

  def set_on_vm_id_changed
  end

  def allowed_storage_profiles(_options = {})
    []
  end
end
