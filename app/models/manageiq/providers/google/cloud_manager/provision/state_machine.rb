module ManageIQ::Providers::Google::CloudManager::Provision::StateMachine
  def determine_placement
    availability_zone = placement
    options[:dest_availability_zone] = [availability_zone.try(:id), availability_zone.try(:name)]
    signal :prepare_instance_disks
  end

  def prepare_instance_disks
    boot_disk_size = get_option(:boot_disk_size).to_i

    resource = ManageIQ::Providers::Google::Resource.new(source.location)

    phase_context[:boot_disk_attrs] = {
      :name      => dest_name,
      :size_gb   => boot_disk_size,
      :zone_name => dest_availability_zone.ems_ref,
    }

    source_key = resource.snapshot? ? :source_snapshot : :source_image
    phase_context[:boot_disk_attrs][source_key] = source.name

    phase_context[:boot_disk] = create_disk(
      phase_context[:boot_disk_attrs]).get_as_boot_disk(true, true)

    update_and_notify_parent(:message => "Creating disk [#{dest_name}]")

    signal :poll_instance_disks_complete
  end

  def poll_instance_disks_complete
    boot_disk = phase_context[:boot_disk_attrs]

    if !check_disks_ready([boot_disk])
      requeue_phase
    else
      update_and_notify_parent(:message => "Disk [#{boot_disk[:name]}] finished creating")
      signal :prepare_provision
    end
  end
end
