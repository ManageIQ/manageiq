module ManageIQ::Providers::Amazon::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |ec2|
      instance = ec2.instances[clone_task_ref]
      status   = instance.status
      return true if status == :running
      return false, status
    end
  end

  def prepare_for_clone_task
    clone_options = super

    # How many instances to request.
    # By default one instance is requested.
    # You can specify this either as an integer or as a Range,
    # to indicate the minimum and maximum number of instances to run.
    clone_options[:count] = 1

    # Specifies whether you can terminate the instance using the EC2 API.
    #   true  => cannot terminate the instance using the API (i.e., the instance is “locked”)
    #   false => can    terminate the instance using the API
    # If you set this to true, and you later want to terminate the instance, you must first enable API termination.
    clone_options[:disable_api_termination] = false

    clone_options[:image_id]           = source.ems_ref
    clone_options[:instance_type]      = instance_type.name
    clone_options[:subnet]             = cloud_subnet.try(:ems_ref)
    clone_options[:security_group_ids] = security_groups.collect(&:ems_ref) if security_groups

    # CloudWatch
    #   true  => Advanced Monitoring
    #   false => Basic    Monitoring
    clone_options[:monitoring_enabled] = get_option(:monitoring).to_s.downcase == "advanced"

    clone_options
  end

  def log_clone_options(clone_options)
    _log.info("Provisioning [#{source.name}] to [#{dest_name}]")
    _log.info("Source Template:                 [#{self[:options][:src_vm_id].last}]")
    if dest_availability_zone
      _log.info("Destination Availability Zone:   [#{dest_availability_zone.name} (#{dest_availability_zone.ems_ref})]")
    else
      _log.info("Destination Availability Zone:  Default selection from provider")
    end
    _log.info("Guest Access Key Pair:           [#{clone_options[:key_name].inspect}]")
    _log.info("Security Group:                  [#{clone_options[:security_group_ids].inspect}]")
    _log.info("Instance Type:                   [#{clone_options[:instance_type].inspect}]")
    _log.info("Cloud Subnet:                    [#{clone_options[:subnet].inspect}]")
    _log.info("Cloud Watch:                     [#{clone_options[:monitoring_enabled].inspect}]")

    dumpObj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dumpObj(options, "#{_log.prefix} Prov Options:  ", $log, :info, :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def start_clone(clone_options)
    source.with_provider_connection do |ec2|
      instance = ec2.instances.create(clone_options)
      return instance.id
    end
  end
end
