module ManageIQ::Providers::Google::CloudManager::Provision::Cloning
  def do_clone_task_check(clone_task_ref)
    source.with_provider_connection do |google|
      instance = google.servers.get(dest_name, dest_availability_zone.ems_ref)

      return true if instance.ready?
      return false, instance.status_message
    end
  end

  def initial_disk
    # Check if the source is a snapshot; if it is, we can't use a single
    # request to make the instance and have to create the disk first
    resource = ManageIQ::Providers::Google::Resource.new(source.location)

    if resource.snapshot?
      # Unfortunately we have to provision the disk first, then provision the
      # instance.
      return create_initial_disk_from_snapshot.get_as_boot_disk(true, true)
    elsif resource.image?
      # We can provision the instance in the same request; just return the hash
      return initial_disk_hash
    else
      # Unknown type!
      _log.error("Unknown resource location to provision from: #{source.location}")
      raise MiqException::MiqProvisionError, _("Unsupported source: #{source.location}")
    end
  end

  def initial_disk_hash
    {
      :boot             => true,
      :autoDelete       => true,
      :initializeParams => {
        :name        => dest_name,
        :diskSizeGb  => get_option(:boot_disk_size).to_i,
        :sourceImage => source.location,
      },
    }
  end

  def create_initial_disk_from_snapshot
    disk = source.with_provider_connection do |google|
      google.disks.create(
        :name            => dest_name,
        :size_gb         => get_option(:boot_disk_size).to_i,
        :zone_name       => dest_availability_zone.ems_ref,
        :source_snapshot => source.name,
      )
    end
    # Poll until the operation is complete
    disk.wait_for { ready? }

    disk
  end

  def prepare_for_clone_task
    clone_options = super

    clone_options[:name] = dest_name
    clone_options[:disks] = [initial_disk]
    clone_options[:machine_type] = instance_type.ems_ref
    clone_options[:zone_name] = dest_availability_zone.ems_ref

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
