module ManageIQ::Providers::Vmware::InfraManager::Provision::Cloning
  def do_clone_task_check(clone_task_mor)
    source.with_provider_connection do |vim|
      begin
        state, val = vim.pollTask(clone_task_mor, "VMClone")
        case state
        when TaskInfoState::Success
          return true
        when TaskInfoState::Running
          return false, val.nil? ? "beginning" : "#{val}% complete"
        else
          return false, state
        end
      end
    end
  rescue MiqException::MiqVimBrokerUnavailable => err
    return false, "not available because <#{err.message}>"
  end

  def find_destination_in_vmdb
    # The new VM will have the guid we placed in the annotations field
    validation_guid = phase_context[:new_vm_validation_guid]
    VmOrTemplate.where(:name => dest_name).detect do |v|
      v.hardware.annotation && v.hardware.annotation.include?(validation_guid)
    end
  end

  def prepare_for_clone_task
    raise MiqException::MiqProvisionError, "Provision Request's Destination VM Name=[#{dest_name}] cannot be blank" if dest_name.blank?
    raise MiqException::MiqProvisionError, "A VM with name: [#{dest_name}] already exists" if source.ext_management_system.vms.where(:name => dest_name).any?
    raise MiqException::MiqProvisionError, "Neither Cluster nor Host selected for [#{dest_name}]" if dest_host.nil? && dest_cluster.nil?
    raise MiqException::MiqProvisionError, "A Host must be selected on a non-DRS enabled cluster" if dest_host.nil? && !dest_cluster.drs_enabled

    clone_options = {
      :name          => dest_name,
      :cluster       => dest_cluster,
      :host          => dest_host,
      :datastore     => dest_datastore,
      :folder        => dest_folder,
      :pool          => dest_resource_pool,
      :config        => build_config_spec,
      :customization => build_customization_spec,
      :transform     => build_transform_spec
    }

    # Determine if we are doing a linked-clone provision
    clone_options[:linked_clone] = get_option(:linked_clone).to_s == 'true'
    clone_options[:snapshot]     = get_selected_snapshot if clone_options[:linked_clone]

    validate_customization_spec(clone_options[:customization])

    clone_options
  end

  def dest_resource_pool
    respool_id = get_option(:placement_rp_name)
    resource_pool = ResourcePool.find_by(:id => respool_id) unless respool_id.nil?
    return resource_pool unless resource_pool.nil?

    cluster = dest_cluster
    cluster ? cluster.default_resource_pool : dest_host.default_resource_pool
  end

  def dest_folder
    folder_id = get_option(:placement_folder_name)
    return EmsFolder.find_by(:id => folder_id) if folder_id

    dc = dest_cluster.parent_datacenter

    # Pick the parent folder in the destination datacenter
    find_folder("#{dc.folder_path}/vm", dc)
  end

  def find_folder(folder_path, datacenter)
    EmsFolder.where(:name => File.basename(folder_path), :ems_id => source.ems_id).detect do |f|
      f.folder_path == folder_path && f.parent_datacenter == datacenter
    end
  end

  def log_clone_options(clone_options)
    _log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
    _log.info("Source Template:            [#{source.name}]")
    _log.info("Destination VM Name:        [#{clone_options[:name]}]")
    _log.info("Destination Cluster:        [#{clone_options[:cluster].name} (#{clone_options[:cluster].ems_ref})]")   if clone_options[:cluster]
    _log.info("Destination Host:           [#{clone_options[:host].name} (#{clone_options[:host].ems_ref})]")         if clone_options[:host]
    _log.info("Destination Datastore:      [#{clone_options[:datastore].name} (#{clone_options[:datastore].ems_ref})]")
    _log.info("Destination Folder:         [#{clone_options[:folder].name}] (#{clone_options[:folder].ems_ref})")
    _log.info("Destination Resource Pool:  [#{clone_options[:pool].name} (#{clone_options[:pool].ems_ref})]")
    _log.info("Power on after cloning:     [#{clone_options[:power_on].inspect}]")
    _log.info("Create Linked Clone:        [#{clone_options[:linked_clone].inspect}]")
    _log.info("Selected Source Snapshot:   [#{clone_options[:snapshot].name} (#{clone_options[:snapshot].ems_ref})]") if clone_options[:linked_clone]

    cust_dump = clone_options[:customization].try(:dup)
    cust_dump.try(:delete, 'encryptionKey')

    dumpObj(clone_options[:transform], "#{_log.prefix} Transform: ",          $log, :info)
    dumpObj(clone_options[:config],    "#{_log.prefix} Config spec: ",        $log, :info)
    dumpObj(cust_dump,                 "#{_log.prefix} Customization spec: ", $log, :info, :protected => {:path => /[Pp]assword\]\[value\]/})
    dumpObj(options,                   "#{_log.prefix} Prov Options: ",       $log, :info, :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def start_clone(clone_options)
    vim_clone_options = {
      :name     => clone_options[:name],
      :wait     => MiqProvision::CLONE_SYNCHRONOUS,
      :template => self.create_template?
    }

    [:transform, :config, :customization, :linked_clone].each { |key| vim_clone_options[key] = clone_options[key] }

    [:folder, :host, :datastore, :pool, :snapshot].each do |key|
      ci = clone_options[key]
      next if ci.nil?
      vim_clone_options[key] = ci.ems_ref_obj
    end

    #TODO lookup a host in the cluster vim_clone_options[:datastore] = clone_options[:host].host_storages.find_by(:storage_id => clone_options[:datastore].id).ems_ref

    task_mor = clone_vm(vim_clone_options)
    _log.info("Provisioning completed for [#{vim_clone_options[:name]}] from source [#{source.name}]") if MiqProvision::CLONE_SYNCHRONOUS
    task_mor
  end

  def clone_vm(vim_clone_options)
    vim_clone_options = {:power_on => false, :template => false, :wait => true}.merge(vim_clone_options)

    cspec = VimHash.new('VirtualMachineCloneSpec') do |cs|
      cs.powerOn       = vim_clone_options[:power_on].to_s
      cs.template      = vim_clone_options[:template].to_s
      cs.config        = vim_clone_options[:config]        if vim_clone_options[:config]
      cs.customization = vim_clone_options[:customization] if vim_clone_options[:customization]
      cs.snapshot      = vim_clone_options[:snapshot]      if vim_clone_options[:snapshot]
      cs.location = VimHash.new('VirtualMachineRelocateSpec') do |csl|
        csl.datastore    = vim_clone_options[:datastore]  if vim_clone_options[:datastore]
        csl.host         = vim_clone_options[:host]       if vim_clone_options[:host]
        csl.pool         = vim_clone_options[:pool]       if vim_clone_options[:pool]
        csl.disk         = vim_clone_options[:disk]       if vim_clone_options[:disk]
        csl.transform    = vim_clone_options[:transform]  if vim_clone_options[:transform]
        csl.diskMoveType = VimString.new('createNewChildDiskBacking', "VirtualMachineRelocateDiskMoveOptions") if vim_clone_options[:linked_clone] == true
      end
    end

    task_mor = nil

    source.with_provider_object do |vim_vm|
      task_mor = vim_vm.cloneVM_raw(vim_clone_options[:folder], vim_clone_options[:name], cspec, vim_clone_options[:wait])
    end

    task_mor
  end

  def get_selected_snapshot
    selected_snapshot = get_option(:snapshot).to_s.downcase
    if selected_snapshot.to_i > 0
      ss = Snapshot.find_by_id(selected_snapshot)
      raise MiqException::MiqProvisionError, "Unable to load requested snapshot <#{selected_snapshot}:#{get_option_last(:snapshot)}> for linked-clone processing." if ss.nil?
    else
      first = source.snapshots.first
      ss = first.get_current_snapshot unless first.blank?
    end

    ss
  end

  def build_transform_spec
    case get_option(:disk_format)
    when 'thin'  then VimString.new('sparse', "VirtualMachineRelocateTransformation")
    when 'thick' then VimString.new('flat', "VirtualMachineRelocateTransformation")
    end
  end
end
