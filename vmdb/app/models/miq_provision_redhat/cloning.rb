module MiqProvisionRedhat::Cloning
  def clone_complete?
    # TODO: shouldn't this error out the provision???
    return true if self.phase_context[:clone_task_ref].nil?

    self.source.with_provider_connection do |rhevm|
      status = rhevm.status(self.phase_context[:clone_task_ref])
      $log.info("MIQ(#{self.class.name}#poll_clone_complete) Clone is #{status}")

      status == 'complete'
    end
  end

  def destination_image_locked?
    rhevm_vm = get_provider_destination

    return false if rhevm_vm.nil?
    rhevm_vm.attributes.fetch_path(:status, :state) == "image_locked"
  end

  def find_destination_in_vmdb(ems_ref)
    VmRedhat.where(:name => dest_name, :ems_ref => ems_ref).first
  end

  def prepare_for_clone_task
    raise MiqException::MiqProvisionError, "Provision Request's Destination VM Name=[#{dest_name}] cannot be blank" if dest_name.blank?
    raise MiqException::MiqProvisionError, "A VM with name: [#{dest_name}] already exists" if self.source.ext_management_system.vms.where(:name => dest_name).any?

    clone_options = {
      :name       => dest_name,
      :cluster    => dest_cluster.ems_ref,
      :clone_type => get_option(:linked_clone) ? :linked : :full,
      :sparse     => sparse_disk_value
    }
    clone_options[:storage] = dest_datastore.ems_ref unless dest_datastore.nil?
    clone_options
  end

  def sparse_disk_value
    case get_option(:disk_format)
    when "preallocated" then false
    when "thin"         then true
    when "default"      then nil   # default choice implies inherit from template
    end
  end

  def log_clone_options(clone_options)
    log_header = "MIQ(#{self.class.name}#log_clone_options)"

    $log.info("#{log_header} Provisioning [#{self.source.name}] to [#{dest_name}]")
    $log.info("#{log_header} Source Template:            [#{self.source.name}]")
    $log.info("#{log_header} Clone Type:                 [#{clone_options[:clone_type]}]")
    $log.info("#{log_header} Destination VM Name:        [#{clone_options[:name]}]")
    $log.info("#{log_header} Destination Cluster:        [#{dest_cluster.name} (#{dest_cluster.ems_ref})]")
    $log.info("#{log_header} Destination Datastore:      [#{dest_datastore.name} (#{dest_datastore.ems_ref})]") unless dest_datastore.nil?

    self.dumpObj(clone_options, "#{log_header} Clone Options: ", $log, :info)
    self.dumpObj(self.options,  "#{log_header} Prov Options:  ", $log, :info)
  end

  def start_clone(clone_options)
    self.source.with_provider_object do |rhevm_template|
      vm = rhevm_template.create_vm(clone_options)
      self.phase_context[:new_vm_ems_ref] = vm[:href]
      self.phase_context[:clone_task_ref] = vm.creation_status_link
    end
  end
end
