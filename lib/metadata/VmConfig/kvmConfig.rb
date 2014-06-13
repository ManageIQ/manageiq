$:.push("#{File.dirname(__FILE__)}/../../kvm")
require 'MiqKvmHost'

module KvmConfig
  def xml_to_config(xml)
    kvm = MiqKvmHost.new(nil, nil, nil)
    ch = kvm.parse_domain_xml(xml)

    add_item("displayName", ch[:name])
    add_item("memsize", ch[:currentMemory])
    add_item("numvcpu", ch[:vcpu])

    ch[:devices][:disks].each do |d|
      d_loc = get_disk_location(d)
      add_item("#{d_loc}.fileName", d[:source])
      add_item("#{d_loc}.deviceType", 'cdrom') if d[:device] == 'cdrom'
    end
  end

  def get_disk_location(disk)
    # disk[:dev] should contain a value like 'hda', 'hdb'.
    # Convert this the last char to an integer value with a = 0 and base the disk
    # location off of this.
    idx = disk[:dev].downcase[-1] - 97
    case disk[:bus].downcase
    when 'ide'
      loc = idx.divmod(2)
      "ide#{loc[0]}:#{loc[1]}"
    when 'scsi', 'virtio'
      loc = idx.divmod(0xF)
      "scsi#{loc[0]}:#{loc[1]}"
    when 'fdc'
      "floppy#{idx}"
    when 'usb'
      "usb#{idx}"
    else
      raise "GetVMConfig: Unknown disk bus type: [#{disk[:bus]}].  [#{disk.inspect}]"
    end
  end
end
