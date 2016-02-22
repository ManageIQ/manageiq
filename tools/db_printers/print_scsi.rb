Host.all.each do |host|
  puts "Host: #{host.name} (id: #{host.id})"

  host.hardware.guest_devices.where(:device_type => 'storage').order("lower(device_name)").each do |adapter|
    sub_name = adapter.iscsi_name.nil? ? "" : " (#{adapter.iscsi_name})"
    puts "  SCSI Adapter: #{adapter.device_name}#{sub_name}"
    adapter.miq_scsi_targets.order("lower(target)").each do |target|
      puts "    Target: #{target.iscsi_name} (#{target.target})"
      target.miq_scsi_luns.order("lower(lun)").each do |lun|
        puts "      Lun: #{lun.canonical_name} (#{lun.lun})"
      end
    end
  end unless host.hardware.nil?

  puts; puts
end
