class VmMigrateWorkflow < MiqRequestWorkflow
  include_concern "DialogFieldValidation"

  def self.base_model
    VmMigrateWorkflow
  end

  def self.automate_dialog_request
    'UI_VM_MIGRATE_INFO'
  end

  def self.default_dialog_file
    'vm_migrate_dialogs'
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false

    vms = Vm.where(:id => @values[:src_ids])

    emses = ExtManagementSystem.where(:id => vms.pluck(:ems_id)).distinct.compact

    # If all the selected VMs share the same EMS we can present a list of CIs.
    return @target_resource = {} if emses.length != 1

    result = {:ems => ci_to_hash_struct(emses.first)}
    @manager = emses.first

    add_target(:placement_host_name,    :host,    Host,         result)
    add_target(:placement_ds_name,      :storage, Storage,      result)
    add_target(:placement_cluster_name, :cluster, EmsCluster,   result)
    add_target(:placement_rp_name,      :respool, ResourcePool, result)
    add_target(:placement_folder_name,  :folder,  EmsFolder,    result)

    if result[:folder_id].nil?
      add_target(:placement_dc_name, :datacenter, EmsFolder, result)
    else
      result[:datacenter] = find_datacenter_for_ci(result[:folder], get_ems_metadata_tree(result))
      result[:datacenter_id] = result[:datacenter].id unless result[:datacenter].nil?
    end

    unless field_supported(:cluster)
      # If the user can not pick a cluster there can only be one to select
      # from => preselect it so the hosts will be filtered accordingly.
      cluster = vms.first.ems_cluster
      result[:cluster] = ci_to_hash_struct(cluster)
    end

    rails_logger('get_source_and_targets', 1)
    @target_resource = result
  end

  def add_target(dialog_key, key, klass, result)
    super if field_supported(key)
  end

  def field_supported(key)
    !(@manager.respond_to?(:unsupported_migration_options) &&
      @manager.unsupported_migration_options.include?(key))
  end

  private

  def allowed_ci(ci, relats, filtered_ids = nil)
    sources = resources_for_ui
    return {} if sources.blank?

    super(ci, relats, sources, filtered_ids)
  end
end
