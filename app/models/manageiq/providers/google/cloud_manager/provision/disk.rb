module ManageIQ::Providers::Google::CloudManager::Provision::Disk
  def create_disks(disks_attrs)
    disk_results = []
    source.with_provider_connection do |google|
      disks_attrs.each do |disk_attrs|
        disk_results << google.disks.create(disk_attrs)
      end
    end
    disk_results
  end

  def create_disk(disk_attrs)
    create_disks([disk_attrs]).first
  end

  def check_disks_ready(disks_attrs)
    source.with_provider_connection do |google|
      disks_attrs.each do |disk_attrs|
        disk = google.disks.get(disk_attrs[:name], disk_attrs[:zone_name])
        return false unless disk.ready?
      end
    end
    true
  end
end
