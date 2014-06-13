$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-xml'

module OvfConfig
  def convert(filename)
    @convertText = ""

    xml = MiqXml.loadFile(filename)

    content_node = xml.find_first("//Content")
    @vendor_string = content_node.find_first("Section/System/vssd:VirtualSystemType")

    set_node_value(content_node, 'displayName', 'Name')
    set_node_value(content_node, 'guestOS',     "Section[@xsi:type='ovf:OperatingSystemSection_Type']/Description")

    # MEMORY_RESOURCE_ID = 4
    set_node_value(content_node, 'memsize', "Section[@xsi:type='ovf:VirtualHardwareSection_Type']/Item[rasd:ResourceType=4]/rasd:VirtualQuantity")
    
    # CPU_RESOURCE_ID = 3
    node = content_node.find_first("Section[@xsi:type='ovf:VirtualHardwareSection_Type']/Item[rasd:ResourceType=3]")
    unless node.nil?
      cpu_per_socket = set_node_value(content_node, 'cpuid.coresPerSocket',     "Section[@xsi:type='ovf:VirtualHardwareSection_Type']/Item[rasd:ResourceType=3]/rasd:cpu_per_socket")
      cpu_per_socket = 1 if cpu_per_socket.nil?
       
      num_of_sockets = 1
      socket_node = content_node.find_first("Section[@xsi:type='ovf:VirtualHardwareSection_Type']/Item[rasd:ResourceType=3]/rasd:num_of_sockets")
      num_of_sockets = socket_node.text unless socket_node.nil?
      
      add_item('numvcpus', num_of_sockets.to_i * cpu_per_socket.to_i)
    end


    disks = parse_disks(xml)
    disks.each_with_index do |disk, idx|
      add_item("scsi0:#{idx}.fileName", disk[:filename])
    end

    return @convertText
  end

  def parse_disks(xml)
    dh = {}
    end_disks = []

    # DISK_RESOURCE_ID = 17
    xml.find_each("//Section[@xsi:type='ovf:VirtualHardwareSection_Type']/Item[rasd:ResourceType=17]") do |node|
      d = {}
      node.each_element {|prop| d[prop.name.to_sym] = prop.text}
      dh[d[:InstanceId]] = d
    end

    # Setup parent relationship
    dh.each do |d_ref, d|
      parent = dh[d[:Parent]]
      unless parent.nil?
        d[:parent] = parent
        (parent[:children] ||= []) << d
      end
    end

    dh.each {|d_ref, d| end_disks << d if d[:children].blank?}
    end_disks.sort! {|a,b| b[:Caption] <=> a[:Caption]}

    end_disks.each do |d|
      d[:filename] = d[:InstanceId]

      # Check if the disk is in the same directory as the OVF file
      if @direct_file_access
        test_filename = File.join(@configPath, d[:InstanceId])
        next if File.exist?(test_filename)
      end

      unless d[:StoragePoolId].blank? || d[:StorageId].blank? || d[:HostResource].blank?
        d[:filename] = "/rhev/data-center/#{d[:StoragePoolId]}/#{d[:StorageId]}/images/#{d[:HostResource]}"
        d[:filename] = File.join($rhevm_mount_root, d[:filename]) unless $rhevm_mount_root.blank?
      end
    end

    return end_disks
  end

  def set_node_value(start_node, config_name, xpath)
    value = nil
    node = start_node.find_first(xpath)
    unless node.nil?
      value = node.text
      add_item(config_name, value)
    end
    return value
  end

  def add_item(var, value)
    @convertText += "#{var} = \"#{value}\"\n"
  end

  def vendor
    vendor_str = @vendor_string.to_s.downcase
    return "rhevm" if vendor_str.include?('rhevm')
    return vendor_str
  end
end
