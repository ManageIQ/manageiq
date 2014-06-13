require_relative 'rhevm_template'

class RhevmVm < RhevmTemplate

  self.top_level_strings    = [:name, :origin, :type, :description]
  self.top_level_booleans   = [:stateless]
  self.top_level_integers   = [:memory]
  self.top_level_timestamps = [:creation_time, :start_time]
  self.top_level_objects    = [:cluster, :template, :host]

  attr_accessor :creation_status_link

  def initialize(*args)
    super

    @creation_status_link = @relationships.delete(:creation_status)
  end

  def creation_status
    return nil if @creation_status_link.blank?
    @service.status(@creation_status_link)
  end

  def start
    if block_given?
      operation(:start) { |xml| yield xml }
    else
      operation(:start)
    end
  rescue RhevmApiError => err
    raise RhevmApiVmAlreadyRunning, err.message if err.message.include?("VM is running.")
    raise
  end

  def stop
    operation(:stop)
  rescue RhevmApiError => err
    raise RhevmApiVmIsNotRunning, err.message if err.message.include?("VM is not running")
    raise
  end

  def shutdown
    operation(:shutdown)
  rescue RhevmApiError => err
    raise RhevmApiVmIsNotRunning, err.message if err.message.include?("VM is not running")
    raise
  end

  def destroy
    # TODO:
    # 1. If VM was running, wait for it to stop
    begin
      stop
    rescue RhevmApiVmIsNotRunning
    end

    super
  end

  def move(storage_domain)
    response = operation(:move) do |xml|
      xml.storage_domain(:id => self.class.object_to_id(storage_domain))
    end

    # Sample Response
    # <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    # <action id="13be9571-61a0-40ef-be6c-50696f61cab1" href="/api/vms/5819ddca-47c0-47d8-8b75-c5b8d1f2b354/move/13be9571-61a0-40ef-be6c-50696f61cab1">
    #   <link rel="parent" href="/api/vms/5819ddca-47c0-47d8-8b75-c5b8d1f2b354"/>
    #   <link rel="replay" href="/api/vms/5819ddca-47c0-47d8-8b75-c5b8d1f2b354/move"/>
    #   <async>true</async>
    #   <storage_domain id="08d61895-b465-406f-955c-72fd9ddbbe05"/>
    #   <status>
    #     <state>pending</state>
    #   </status>
    # </action>
    doc = Nokogiri::XML(response)
    action = doc.xpath("//action").first
    raise RhevmApiError, "No Action in Response: #{response.inspect}" if action.nil?
    action['href']
  end

  # cpu_hash needs to look like { :cores => 1, :sockets => 1 }
  def cpu_topology=(cpu_hash)
    update! do |xml|
      xml.cpu do
        xml.topology(cpu_hash)
      end
      xml.memory self[:memory]  # HACK: RHEVM BUG: RHEVM resets it to 10GB, unless we set it
    end
  end

  def description=(value)
    update! do |xml|
      xml.description value.to_s
      xml.memory self[:memory]  # HACK: RHEVM BUG: RHEVM resets it to 10GB, unless we set it
    end
  end

  def host_affinity=(host, affinity = :migratable)
    update! do |xml|
      xml.memory self[:memory]  # HACK: RHEVM BUG: RHEVM resets it to 10GB, unless we set it
      xml.placement_policy do
        if host.nil?
          xml.host
        else
          xml.host(:id => self.class.object_to_id(host))
        end
        xml.affinity affinity.to_s
      end
    end
  end

  def memory=(value)
    update! do |xml|
      xml.memory value
    end
  end

  def memory_reserve=(value)
    update! do |xml|
      xml.memory_policy do
        xml.guaranteed(value)
      end
    end
  end

  # Attaches a payload.
  #
  # payloads:: Hash of payload_type => {file_name => content} that will be
  #   attached.  Acceptable payload_types are floppy or cdrom.
  def attach_payload(payloads)
    send("attach_payload_#{payload_version}".to_sym, payloads)
  end

  def payload_version
    version = service.version

    if version[:major].to_i >= 3
      return "3_0" if version[:minor].to_i < 3
      return "3_3"
    end
  end

  def attach_payload_3_0(payloads)
    update! do |xml|
      xml.payloads do
        payloads.each do |type, files|
          xml.payload(:type => type) do
            files.each do |file_name, content|
              xml.file(:name => file_name) do
                xml.content content
              end
            end
          end
        end
      end
    end
  end

  def attach_payload_3_3(payloads)
    update! do |xml|
      xml.payloads do
        payloads.each do |type, files|
          xml.payload(:type => type) do
            xml.files do
              files.each do |file_name, content|
                xml.file do
                  xml.name file_name
                  xml.content content
                end
              end
            end
          end
        end
      end
    end
  end

  # Detaches a payload
  #
  # types:: A payload type or Array of payload types to detach.
  #         Acceptable types are floppy or cdrom.
  def detach_payload(types)
    # HACK: The removal of payloads is not supported until possibly RHEVM 3.1.1
    #       https://bugzilla.redhat.com/show_bug.cgi?id=882649
    #       For now, just set the payload to blank content.
    payload = Array(types).each_with_object({}) { |t, h| h[t] = {} }
    attach_payload(payload)
  end

  # Attaches the +files+ as a floppy drive payload.
  #
  # files:: Hash of file_name => content that will be attached as a floppy
  def attach_floppy(files)
    attach_payload("floppy" => files || {})
  end

  # Detaches the floppy drive payload.
  def detach_floppy
    detach_payload("floppy")
  end

  def boot_from_network
    start do |xml|
      xml.vm do
        xml.os do
          xml.boot(:dev => 'network')
        end
      end
    end
  rescue RhevmApiError => err
    raise unless err.message =~ /disks .+ are locked/
    raise RhevmApiVmNotReadyToBoot.new [err.message, err]
  end

  def boot_from_cdrom(iso_file_name)
    start do |xml|
      xml.vm do
        xml.os do
          xml.boot(:dev => 'cdrom')
        end
        xml.cdroms do
          xml.cdrom do
            xml.file(:id => iso_file_name)
          end
        end
      end
    end
  rescue RhevmApiError => err
    raise unless err.message =~ /disks .+ are locked/
    raise RhevmApiVmNotReadyToBoot.new [err.message, err]
  end

  def self.parse_xml(xml)
    hash = super
    node = xml_to_nokogiri(xml)

    parse_first_node(node, :placement_policy, hash,
                     :node => [:affinity])

    parse_first_node_with_hash(node, 'placement_policy/host', hash[:placement_policy][:host] = {},
                     :attribute => [:id])

    parse_first_node(node, :memory_policy, hash,
                     :node_to_i => [:guaranteed])

    hash[:guest_info] = {}
    node.xpath('guest_info').each do |gi|
      ips = hash[:guest_info][:ips] = []
      gi.xpath('ips/ip').each do |ip|
        ips << {:address => ip[:address]}
      end
    end

    hash
  end

  def create_device(device_type)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.send(device_type) { yield xml if block_given? }
    end
    data = builder.doc.root.to_xml
    path = "#{api_endpoint}/#{device_type.pluralize}"

    @service.resource_post(path, data)
  end

  def create_nic(options = {})
    create_device("nic") do |xml|
      xml.name      options[:name]
      xml.interface options[:interface] unless options[:interface].blank?
      xml.network(:id => options[:network_id]) unless options[:network_id].blank?
      xml.mac(:address => options[:mac_address]) unless options[:mac_address].blank?
    end
  end

  def create_disk(options = {})
    create_device("disk") do |xml|
      [:name, :interface, :format, :size, :type].each do |key|
        next if options[key].blank?
        xml.send("#{key}_", options[key])
      end

      [:sparse, :bootable, :wipe_after_delete, :propagate_errors].each do |key|
        xml.send("#{key}_", options[key]) unless options[key].nil?
      end

      xml.storage_domains { xml.storage_domain(:id => options[:storage]) } if options[:storage]
    end
  end

  def create_snapshot(desc)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.snapshot do
        xml.description desc
      end
    end
    data = builder.doc.root.to_xml
    path = "#{api_endpoint}/snapshots"

    response = @service.resource_post(path, data)

    snap = RhevmSnapshot.create_from_xml(@service, response)

    while snap[:snapshot_status] == "locked"
      sleep 2
      snap.reload
    end
    snap
  end

  def create_template(options={})
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.template do
        xml.name options[:name]
        xml.vm(:id => self[:id])
      end
    end
    data = builder.doc.root.to_xml

    response = @service.resource_post(:templates, data)
    RhevmTemplate.create_from_xml(@service, response)
  rescue RhevmApiError => err
    raise RhevmApiTemplateAlreadyExists, err.message if err.message.include?("Template name already exists")
    raise
  end
end
