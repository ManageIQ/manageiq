class Hardware < ActiveRecord::Base
  belongs_to  :vm_or_template
  belongs_to  :vm,            :foreign_key => :vm_or_template_id
  belongs_to  :miq_template,  :foreign_key => :vm_or_template_id
  belongs_to  :host
  belongs_to  :computer_system

  has_many    :networks, :dependent => :destroy

  has_many    :disks, :dependent => :destroy, :order => :location
  has_many    :hard_disks, :class_name => "Disk", :foreign_key => :hardware_id, :conditions => "device_type != 'floppy' AND device_type NOT LIKE '%cdrom%'", :order => :location
  has_many    :floppies, :class_name => "Disk", :foreign_key => :hardware_id, :conditions => "device_type = 'floppy'", :order => :location
  has_many    :cdroms, :class_name => "Disk", :foreign_key => :hardware_id, :conditions => "device_type LIKE '%cdrom%'", :order => :location

  has_many    :hard_disk_storages, :through => :hard_disks, :source => :storage, :uniq => true

  has_many    :partitions, :dependent => :destroy
  has_many    :volumes, :dependent => :destroy

  has_many    :guest_devices, :dependent => :destroy
  has_many    :storage_adapters, :class_name => "GuestDevice", :foreign_key => :hardware_id, :conditions => "device_type = 'storage'"
  has_many    :nics, :class_name => "GuestDevice", :foreign_key => :hardware_id, :conditions => "device_type = 'ethernet'"
  has_many    :ports, :class_name => "GuestDevice", :foreign_key => :hardware_id, :conditions => "device_type != 'storage'"

  virtual_column :ipaddresses,   :type => :string_set, :uses => :networks
  virtual_column :hostnames,     :type => :string_set, :uses => :networks
  virtual_column :mac_addresses, :type => :string_set, :uses => :nics

  include ReportableMixin

  def ipaddresses
    @ipaddresses ||= self.networks.collect { |n| n.ipaddress }.compact.uniq
  end

  def hostnames
    @hostnames ||= self.networks.collect { |n| n.hostname }.compact.uniq
  end

  def mac_addresses
    @mac_addresses ||= self.nics.collect { |n| n.address }.compact.uniq
  end

  @@dh = {"type"=>"device_name", "devicetype"=>"device_type", "id"=>"location", "present"=>"present",
    "filename"=>"filename", "startconnected"=>"start_connected", "autodetect"=>"auto_detect", "mode"=>"mode",
    "connectiontype"=>"mode", "size"=>"size","free_space"=>"free_space","size_on_disk"=>"size_on_disk",
    "generatedaddress"=>"address", "disk_type"=>"disk_type"}

  def self.add_elements(parent, xmlNode)
    $log.info("MIQ(hardware-add_elements) Adding Hardware XML elements for VM[id]=[#{parent.id}] from XML doc [#{xmlNode.root.name}]")
    parent.hardware = Hardware.new if parent.hardware == nil
    # Record guest_devices so we can delete any removed items.
    deletes = {:gd => [], :disk => []}

    # Excluding ethernet devices from deletes because the refresh is the master of the data and it will handle the deletes.
    deletes[:gd] = parent.hardware.guest_devices.find(:all,
      :conditions => ["device_type != ?", "ethernet"],
      :select=>"id, device_type, location, address"
    ).collect {|rec| [rec.id, [rec.device_type, rec.location, rec.address]]}

    deletes[:disk] = parent.hardware.disks.find(:all,
      :select=>"id, device_type, location"
    ).collect {|rec| [rec.id, [rec.device_type, rec.location]]}

    xmlNode.root.each_recursive { |e|
      begin
        parent.hardware.send("m_#{e.name}", parent, e, deletes) if parent.hardware.respond_to?("m_#{e.name}")
      rescue => err
        $log.warn "MIQ(hardware-add_elements) #{err}"
      end
    }

    GuestDevice.delete(deletes[:gd].transpose[0])
    Disk.delete(deletes[:disk].transpose[0])

    # Count the count of ethernet devices
    parent.hardware.number_of_nics = parent.hardware.nics.length

    parent.hardware.save
  end

  def aggregate_cpu_speed
    return nil if self.logical_cpus.blank? || self.cpu_speed.blank?
    return (self.logical_cpus * self.cpu_speed)
  end

  def m_controller(parent, xmlNode, deletes)
    #$log.info("Adding controller XML elements for [#{xmlNode.attributes["type"]}]")
    xmlNode.each_element { |e|
      next if e.attributes['present'].to_s.downcase == "false"
      da = {"device_type" => xmlNode.attributes["type"].to_s.downcase, "controller_type"=> xmlNode.attributes["type"]}
      # Loop over the device mapping table and add attributes
      @@dh.each_pair { |k, v|  da.merge!({v => e.attributes[k]}) if e.attributes[k] }

      if da["device_name"] == 'disk'
        target = self.disks
        target_type = :disk
      else
        target = self.guest_devices
        target_type = :gd
      end

      # Try to find the existing row
      found = target.find_by_device_type_and_location(da["device_type"], da["location"])
      found = target.find_by_device_type_and_address(da["device_type"], da["address"]) if found.nil? && !da["address"].nil?
      # Add or update the device
      if found.nil?
        target.create(da)
      else
        da.delete('device_name') if target_type == :disk
        found.update_attributes(da)
      end

      # Remove the devices from the delete list if it matches on device_type and either location or address
      deletes[target_type].delete_if {|ele| (ele[1][0] == da["device_type"]) && (ele[1][1] == da["location"] || (!da["address"].nil? && ele[1][2] == da["address"]))}
    }
  end

  def m_memory(parent, xmlNode, deletes)
    self.memory_cpu = xmlNode.attributes["memsize"]
  end

  def m_bios(parent, xmlNode, deletes)
    new_bios = MiqUUID.clean_guid(xmlNode.attributes["bios"])
    self.bios = new_bios.nil? ? xmlNode.attributes["bios"] : new_bios

    new_bios = MiqUUID.clean_guid(xmlNode.attributes["location"])
    self.bios_location = new_bios.nil? ? xmlNode.attributes["location"] : new_bios
  end

  def m_vm(parent, xmlNode, deletes)
    xmlNode.each_element { |e|
      self.guest_os = e.attributes["guestos"] if e.name == "guestos"
      self.config_version = e.attributes["version"] if e.name == "config"
      self.virtual_hw_version = e.attributes["version"] if e.name == "virtualhw"
      self.time_sync = e.attributes["synctime"] if e.name == "tools"
      self.annotation = e.attributes["annotation"] if e.name == "annotation"
      self.cpu_speed = e.attributes["cpuspeed"] if e.name == "cpuspeed"
      self.cpu_type = e.attributes["cputype"] if e.name == "cputype"
      parent.autostart = e.attributes["autostart"] if e.name == "autostart"
      self.numvcpus = e.attributes["numvcpus"] if e.name == "numvcpus"
    }
  end

  def m_files(parent, xmlNode, deletes)
    self.size_on_disk = xmlNode.attributes["size_on_disk"]
    self.disk_free_space = xmlNode.attributes["disk_free_space"]
    self.disk_capacity = xmlNode.attributes["disk_capacity"]
  end

  def m_snapshots(parent, xmlNode, deletes)
    Snapshot.add_elements(parent, xmlNode)
  end

  def m_volumes(parent, xmlNode, deletes)
    Volume.add_elements(parent, xmlNode)
  end
end
