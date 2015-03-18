module MiqProvisionVmware::Cloning
  def do_clone_task_check(clone_task_mor)
    self.source.with_provider_connection do |vim|
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
    validation_guid = self.phase_context[:new_vm_validation_guid]
    VmOrTemplate.find_all_by_name(dest_name).detect do |v|
      v.hardware.annotation && v.hardware.annotation.include?(validation_guid)
    end
  end

  def prepare_for_clone_task
    raise MiqException::MiqProvisionError, "Provision Request's Destination VM Name=[#{dest_name}] cannot be blank" if dest_name.blank?
    raise MiqException::MiqProvisionError, "A VM with name: [#{dest_name}] already exists" if self.source.ext_management_system.vms.where(:name => dest_name).any?

    clone_options = {
      :name      => dest_name,
      :host      => dest_host,
      :datastore => dest_datastore,
    }

    # Destination folder
    folder_id = get_option(:placement_folder_name)
    clone_options[:folder] = folder_id.blank? ? self.source.parent_blue_folder : EmsFolder.find_by_id(folder_id)

    # Find destination resource pool
    respool_id = get_option(:placement_rp_name)
    clone_options[:pool] = ResourcePool.find_by_id(respool_id) unless respool_id.nil?
    clone_options[:pool] ||= begin
      cluster = dest_host.owning_cluster
      cluster ? cluster.default_resource_pool : dest_host.default_resource_pool
    end

    clone_options[:config]        = self.build_config_spec
    clone_options[:customization] = self.build_customization_spec
    clone_options[:transform]     = self.build_transform_spec

    # Determine if we are doing a linked-clone provision
    clone_options[:linked_clone] = get_option(:linked_clone).to_s == 'true'
    clone_options[:snapshot]     = self.get_selected_snapshot if clone_options[:linked_clone]

    self.validate_customization_spec(clone_options[:customization])

    clone_options
  end

  def log_clone_options(clone_options)
    log_header = "MIQ(#{self.class.name}#log_clone_options)"

    $log.info("#{log_header} Provisioning [#{self.source.name}] to [#{clone_options[:name]}]")
    $log.info("#{log_header} Source Template:            [#{self.source.name}]")
    $log.info("#{log_header} Destination VM Name:        [#{clone_options[:name]}]")
    $log.info("#{log_header} Destination Host:           [#{clone_options[:host].name} (#{clone_options[:host].ems_ref})]")
    $log.info("#{log_header} Destination Datastore:      [#{clone_options[:datastore].name} (#{clone_options[:datastore].ems_ref})]")
    $log.info("#{log_header} Destination Folder:         [#{clone_options[:folder].name}] (#{clone_options[:folder].ems_ref})")
    $log.info("#{log_header} Destination Resource Pool:  [#{clone_options[:pool].name} (#{clone_options[:pool].ems_ref})]")
    $log.info("#{log_header} Power on after cloning:     [#{clone_options[:power_on].inspect}]")
    $log.info("#{log_header} Create Linked Clone:        [#{clone_options[:linked_clone].inspect}]")
    $log.info("#{log_header} Selected Source Snapshot:   [#{clone_options[:snapshot].name} (#{clone_options[:snapshot].ems_ref})]") if clone_options[:linked_clone]

    cust_dump = clone_options[:customization].try(:dup)
    cust_dump.try(:delete, 'encryptionKey')

    self.dumpObj(clone_options[:transform], "#{log_header} Transform: ",          $log, :info)
    self.dumpObj(clone_options[:config],    "#{log_header} Config spec: ",        $log, :info)
    self.dumpObj(cust_dump,                 "#{log_header} Customization spec: ", $log, :info, {:protected => {:path => /[Pp]assword\]\[value\]/}})
    self.dumpObj(self.options,              "#{log_header} Prov Options: ",       $log, :info)
  end

  def start_clone(clone_options)
    vim_clone_options = {
      :name     => clone_options[:name],
      :wait     => MiqProvisionTaskVirt::CLONE_SYNCHRONOUS,
      :template => self.create_template?
    }

    [:transform, :config, :customization, :linked_clone].each { |key| vim_clone_options[key] = clone_options[key] }

    [:folder, :host, :datastore, :pool, :snapshot].each do |key|
      ci = clone_options[key]
      next if ci.nil?
      vim_clone_options[key] = ci.ems_ref_obj
    end

    task_mor = self.clone_vm(vim_clone_options)
    $log.info("MIQ(#{self.class.name}#start_clone) Provisioning completed for [#{vim_clone_options[:name]}] from source [#{self.source.name}]") if MiqProvisionTaskVirt::CLONE_SYNCHRONOUS
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

    self.source.with_provider_object do |vim_vm|
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
      first = self.source.snapshots.first
      ss = first.get_current_snapshot unless first.blank?
    end

    ss
  end

  def build_transform_spec
    case get_option(:disk_format)
    when 'thin'  then VimString.new('sparse', "VirtualMachineRelocateTransformation")
    when 'thick' then VimString.new('flat', "VirtualMachineRelocateTransformation")
    else nil
    end
  end

end
