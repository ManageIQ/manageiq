module ManageIQ::Providers::Google::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |google|
      instance = google.servers.get(dest_name, dest_availability_zone.ems_ref)

      return true if instance.ready?
      return false, instance.status_message
    end
  end

  def prepare_for_clone_task
    clone_options = super

    boot_disk = phase_context[:boot_disk]

    clone_options[:name]         = dest_name
    clone_options[:disks]        = [boot_disk]
    clone_options[:machine_type] = instance_type.ems_ref
    clone_options[:zone_name]    = dest_availability_zone.ems_ref

    clone_options
  end

  def log_clone_options(clone_options)
    _log.info("Provisioning:                  [#{clone_options[:name]}]")
    _log.info("Root Disk:                     [#{clone_options[:disks]}]")
    _log.info("Destination Availability Zone: [#{clone_options[:zone_name]}]")
    _log.info("Machine Type:                  [#{clone_options[:machine_type]}]")

    dumpObj(clone_options, "#{_log.prefix} Clone Options: ", $log, :info)
    dumpObj(options, "#{_log.prefix} Prov Options:  ", $log, :info,
            :protected => {:path => workflow_class.encrypted_options_field_regs})
  end

  def start_clone(clone_options)
    source.with_provider_connection do |google|
      instance = google.servers.create(clone_options)
      return instance.id
    end
  end
end
