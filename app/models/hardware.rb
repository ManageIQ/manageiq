class Hardware < ApplicationRecord
  belongs_to  :vm_or_template
  belongs_to  :vm,            :foreign_key => :vm_or_template_id
  belongs_to  :miq_template,  :foreign_key => :vm_or_template_id
  belongs_to  :host
  belongs_to  :computer_system
  belongs_to  :physical_switch, :foreign_key => :switch_id, :inverse_of => :hardware

  has_many    :networks, :dependent => :destroy
  has_many    :firmwares, :as => :resource, :dependent => :destroy

  has_many    :disks, -> { order(:location) }, :dependent => :destroy
  has_many    :hard_disks, -> { where.not(:device_type => 'floppy').where.not(Disk.arel_table[:device_type].lower.matches('%cdrom%')).order(:location) }, :class_name => "Disk", :foreign_key => :hardware_id
  has_many    :floppies, -> { where(:device_type => 'floppy').order(:location) }, :class_name => "Disk", :foreign_key => :hardware_id
  has_many    :cdroms, -> { where(Disk.arel_table[:device_type].lower.matches('%cdrom%')).order(:location) }, :class_name => "Disk", :foreign_key => :hardware_id

  has_many    :partitions, :dependent => :destroy
  has_many    :volumes, :dependent => :destroy

  has_many    :guest_devices, :dependent => :destroy
  has_many    :storage_adapters, -> { where(:device_type => 'storage') }, :class_name => "GuestDevice", :foreign_key => :hardware_id
  has_many    :nics, -> { where(:device_type => 'ethernet') }, :class_name => "GuestDevice", :foreign_key => :hardware_id
  has_many    :ports, -> { where.not(:device_type => 'storage') }, :class_name => "GuestDevice", :foreign_key => :hardware_id
  has_many    :physical_ports, -> { where(:device_type => 'physical_port') }, :class_name => "GuestDevice", :foreign_key => :hardware_id
  has_many    :connected_physical_switches, :through => :guest_devices

  has_many    :management_devices, -> { where(:device_type => 'management') }, :class_name => "GuestDevice", :foreign_key => :hardware_id

  virtual_column :ipaddresses,   :type => :string_set, :uses => :networks
  virtual_column :hostnames,     :type => :string_set, :uses => :networks
  virtual_column :mac_addresses, :type => :string_set, :uses => :nics

  virtual_aggregate :used_disk_storage,      :disks, :sum, :used_disk_storage
  virtual_aggregate :allocated_disk_storage, :disks, :sum, :size
  virtual_total     :num_disks,              :disks
  virtual_total     :num_hard_disks,         :hard_disks

  def ipaddresses
    @ipaddresses ||= if networks.loaded?
                       networks.collect(&:ipaddress).compact.uniq + networks.collect(&:ipv6address).compact.uniq
                     else
                       networks.pluck(:ipaddress, :ipv6address).flatten.tap(&:compact!).tap(&:uniq!)
                     end
  end

  def hostnames
    @hostnames ||= networks.collect(&:hostname).compact.uniq
  end

  def mac_addresses
    @mac_addresses ||= nics.collect(&:address).compact.uniq
  end

  def ram_size_in_bytes
    memory_mb.to_i * 1.megabyte
  end

  virtual_attribute :ram_size_in_bytes, :integer, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::Multiplication.new([t[:memory_mb]], 1.megabyte))
  end)

  @@dh = {"type" => "device_name", "devicetype" => "device_type", "id" => "location", "present" => "present",
    "filename" => "filename", "startconnected" => "start_connected", "autodetect" => "auto_detect", "mode" => "mode",
    "connectiontype" => "mode", "size" => "size", "free_space" => "free_space", "size_on_disk" => "size_on_disk",
    "generatedaddress" => "address", "disk_type" => "disk_type"}

  def self.add_elements(parent, xmlNode)
    _log.info("Adding Hardware XML elements for VM[id]=[#{parent.id}] from XML doc [#{xmlNode.root.name}]")
    parent.hardware = Hardware.new if parent.hardware.nil?
    # Record guest_devices so we can delete any removed items.
    deletes = {:gd => [], :disk => []}

    # Excluding ethernet devices from deletes because the refresh is the master of the data and it will handle the deletes.
    deletes[:gd] = parent.hardware.guest_devices
                   .where.not(:device_type => "ethernet")
                   .select(:id, :device_type, :location, :address)
                   .collect { |rec| [rec.id, [rec.device_type, rec.location, rec.address]] }

    if parent.vendor == "redhat"
      deletes[:disk] = parent.hardware.disks.select(:id, :device_type, :location)
                     .collect { |rec| [rec.id, [rec.device_type, "0:#{rec.location}"]] }
    else
      deletes[:disk] = parent.hardware.disks.select(:id, :device_type, :location)
                     .collect { |rec| [rec.id, [rec.device_type, rec.location]] }
    end

    xmlNode.root.each_recursive do |e|
      begin
        parent.hardware.send("m_#{e.name}", parent, e, deletes) if parent.hardware.respond_to?("m_#{e.name}")
      rescue => err
        _log.warn(err.to_s)
      end
    end

    GuestDevice.delete(deletes[:gd].transpose[0])
    Disk.delete(deletes[:disk].transpose[0])

    # Count the count of ethernet devices
    parent.hardware.number_of_nics = parent.hardware.nics.length

    parent.hardware.save
  end

  def aggregate_cpu_speed
    if has_attribute?("aggregate_cpu_speed")
      self["aggregate_cpu_speed"]
    elsif try(:cpu_total_cores) && try(:cpu_speed)
      cpu_total_cores * cpu_speed
    end
  end

  virtual_attribute :aggregate_cpu_speed, :integer, :arel => (lambda do |t|
    t.grouping(t[:cpu_total_cores] * t[:cpu_speed])
  end)

  def v_pct_free_disk_space
    return nil if disk_free_space.nil? || disk_capacity.nil? || disk_capacity.zero?

    (disk_free_space.to_f / disk_capacity * 100).round(2)
  end
  # resulting sql: "(cast(disk_free_space as float) / (disk_capacity * 100))"
  virtual_attribute :v_pct_free_disk_space, :float, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::Division.new(
      Arel::Nodes::NamedFunction.new("CAST", [t[:disk_free_space].as("float")]),
      t[:disk_capacity]) * 100)
  end)

  def v_pct_used_disk_space
    percent_free = v_pct_free_disk_space
    100 - percent_free if percent_free
  end
  # resulting sql: "(cast(disk_free_space as float) / (disk_capacity * -100) + 100)"
  # to work with arel better, put the 100 at the end
  virtual_attribute :v_pct_used_disk_space, :float, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::Division.new(
      Arel::Nodes::NamedFunction.new("CAST", [t[:disk_free_space].as("float")]),
      t[:disk_capacity]) * -100 + 100)
  end)

  def provisioned_storage
    if has_attribute?("provisioned_storage")
      self["provisioned_storage"]
    else
      allocated_disk_storage.to_i + ram_size_in_bytes
    end
  end

  virtual_attribute :provisioned_storage, :integer, :arel => (lambda do |t|
    t.grouping(
      t.grouping(Arel::Nodes::NamedFunction.new('COALESCE', [arel_attribute(:allocated_disk_storage), 0])) +
      t.grouping(Arel::Nodes::NamedFunction.new('COALESCE', [t[:memory_mb], 0])) * 1.megabyte
    )
  end)

  def connect_lans(lans)
    return if lans.blank?

    nics.each do |n|
      # TODO: Use a different field here
      #   model is temporarily being used here to transfer the name of the
      #   lan to which this nic is connected.  If model ends up being an
      #   otherwise used field, this will need to change
      n.lan = lans.find { |l| l.name == n.model }
      n.model = nil
      n.save
    end
  end

  def disconnect_lans
    nics.each do |n|
      n.lan = nil
      n.save
    end
  end

  def m_controller(_parent, xmlNode, deletes)
    # $log.info("Adding controller XML elements for [#{xmlNode.attributes["type"]}]")
    xmlNode.each_element do |e|
      next if e.attributes['present'].to_s.downcase == "false"

      da = {"device_type" => xmlNode.attributes["type"].to_s.downcase, "controller_type" => xmlNode.attributes["type"]}
      # Loop over the device mapping table and add attributes
      @@dh.each_pair { |k, v|  da.merge!(v => e.attributes[k]) if e.attributes[k] }

      if da["device_name"] == 'disk'
        target = disks
        target_type = :disk
      else
        target = guest_devices
        target_type = :gd
      end

      # Try to find the existing row
      found = target.find_by(:device_type => da["device_type"], :location => da["location"])
      found ||= da["address"] && target.find_by(:device_type => da["device_type"], :address => da["address"])
      # Add or update the device
      if found.nil?
        target.create(da)
      else
        da.delete('device_name') if target_type == :disk
        found.update(da)
      end

      # Remove the devices from the delete list if it matches on device_type and either location or address
      deletes[target_type].delete_if { |ele| (ele[1][0] == da["device_type"]) && (ele[1][1] == da["location"] || (!da["address"].nil? && ele[1][2] == da["address"])) }
    end
  end

  def m_memory(_parent, xmlNode, _deletes)
    self.memory_mb = xmlNode.attributes["memsize"]
  end

  def m_bios(_parent, xmlNode, _deletes)
    new_bios = Digest::UUID.clean(xmlNode.attributes["bios"])
    self.bios = new_bios.nil? ? xmlNode.attributes["bios"] : new_bios

    new_bios = Digest::UUID.clean(xmlNode.attributes["location"])
    self.bios_location = new_bios.nil? ? xmlNode.attributes["location"] : new_bios
  end

  def m_vm(parent, xmlNode, _deletes)
    xmlNode.each_element do |e|
      self.guest_os = e.attributes["guestos"] if e.name == "guestos"
      self.config_version = e.attributes["version"] if e.name == "config"
      self.virtual_hw_version = e.attributes["version"] if e.name == "virtualhw"
      self.time_sync = e.attributes["synctime"] if e.name == "tools"
      self.annotation = e.attributes["annotation"] if e.name == "annotation"
      self.cpu_speed = e.attributes["cpuspeed"] if e.name == "cpuspeed"
      self.cpu_type = e.attributes["cputype"] if e.name == "cputype"
      parent.autostart = e.attributes["autostart"] if e.name == "autostart"
      self.cpu_sockets = e.attributes["numvcpus"] if e.name == "numvcpus"
    end
  end

  def m_files(_parent, xmlNode, _deletes)
    self.size_on_disk = xmlNode.attributes["size_on_disk"]
    self.disk_free_space = xmlNode.attributes["disk_free_space"]
    self.disk_capacity = xmlNode.attributes["disk_capacity"]
  end

  def m_snapshots(parent, xmlNode, _deletes)
    Snapshot.add_elements(parent, xmlNode)
  end

  def m_volumes(parent, xmlNode, _deletes)
    Volume.add_elements(parent, xmlNode)
  end
end
