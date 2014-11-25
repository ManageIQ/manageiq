$:.push("#{File.dirname(__FILE__)}/../../../lib/RcuWebService")

class NetAppFiler < ActsAsArModel
  set_columns_hash(
    :name       => :string,
    :ipaddress  => :string,
    :userid     => :string,
    :password   => :string,
    :ssl        => :boolean,
    :aggregates => :text,
    :volumes    => :text
  )

  YAML_FILE = File.join(Rails.root, "config/net_app_filers.yml")

  def self.find(*args)
    count = args.first
    raise "Only :all is supported for find" unless count == :all

    self.all_filers
  end

  def self.find_by_name(name)
    h = self.load_from_yaml.detect {|f| f[:name] == name}
    h ? self.new(h) : nil
  end

  def self.all_filers
    h = self.load_from_yaml.collect {|f| self.new(f)}
  end
  class << self; alias :all :all_filers; end

  def create_datastore(container, aggregate_or_volume_name, datastore_name, size, protocol = 'NFS', thin_provision = false, auto_grow = false, auto_grow_increment = nil, auto_grow_maximum = nil)
    log_header = "MIQ(#{self.class.name}.create_datastore)"
    container_dictionary = {
      'Host'       => { :moref => 'HostSystem', :ems => 'ext_management_system' },
      'EmsCluster' => { :moref => 'Cluster',    :ems => 'ext_management_system' },
    }

    begin
      require 'RcuClientBase'

      raise "Filer '#{self.name}' does not have aggregate '#{aggregate_or_volume_name}'" if protocol == "NFS"  && !self.aggregates.include?(aggregate_or_volume_name)
      raise "Filer '#{self.name}' does not have volume '#{aggregate_or_volume_name}'"    if protocol == "VMFS" && !self.volumes.include?(aggregate_or_volume_name)

      raise "Container not provided" if container.nil?
      raise "Container class=<#{container.class.name}> should be one of: #{container_dictionary.keys.sort.join(',')}" unless container_dictionary.keys.include?(container.class.name)
      ems = container.send(container_dictionary[container.class.name][:ems])
      raise "Container <#{container.name}> not connected to vCenter" if ems.nil?

      # Get VC information from ems and create an RcuClientBase object
      vc_address  = ems.ipaddress
      vc_userid   = ems.authentication_userid
      vc_password = ems.authentication_password
      $log.info("#{log_header} Connecting to VC=<#{vc_address}> with username=<#{vc_userid}>")
      rcu = RcuClientBase.new(vc_address, vc_userid, vc_password)

      # Figure out the target's Managed Object Reference
      targetMor = rcu.getMoref(container.name, container_dictionary[container.class.name][:moref])

      # Size must be at least 1 gigabyte
      size = 1.gigabyte if (size < 1.gigabyte)

      # Create the parameters needed for the rcu.createDatastore methods
      datastoreSpec = RcuHash.new("DatastoreSpec") do |ds|
        # RCU
        #ds.aggrOrVolName  = aggregate_or_volume_name
        # VSC
        ds.containerName  = aggregate_or_volume_name
        ds.controller   = RcuHash.new("ControllerSpec") do |cs|
          cs.ipAddress = self.ipaddress
          cs.username  = self.userid
          cs.password  = self.password
          cs.ssl       = self.ssl
        end
        ds.datastoreNames = datastore_name
        ds.numDatastores  = 1
        ds.protocol       = (protocol == 'VMFS') ? 'ISCSI' : protocol
        ds.sizeInMB       = size.to_i / 1.megabyte
        ds.targetMor      = targetMor
        ds.thinProvision  = thin_provision
        ds.volAutoGrow    = auto_grow
        ds.volAutoGrowInc = auto_grow_increment.to_i / 1.megabyte
        ds.volAutoGrowMax = auto_grow_maximum.to_i   / 1.megabyte
      end

      $log.info("#{log_header} Creating #{protocol} container=<#{aggregate_or_volume_name}> with size=<#{size}> as datastore=<#{datastore_name}> on NetApp Filer=<#{self.ipaddress}> with username=<#{self.userid}>")
      $log.info("#{log_header} rcu.createDatastore parameters: ds.containerName=<#{datastoreSpec.containerName}>, ds.datastoreNames=<#{datastoreSpec.datastoreNames}>, ds.numDatastores=<#{datastoreSpec.numDatastores}>, ds.protocol=<#{datastoreSpec.protocol}>, ds.sizeInMB=<#{datastoreSpec.sizeInMB}>, ds.targetMor=<#{datastoreSpec.targetMor}>, ds.thinProvision=<#{datastoreSpec.thinProvision}>, ds.volAutoGrow=<#{datastoreSpec.volAutoGrow}>, ds.volAutoGrowInc=<#{datastoreSpec.volAutoGrowInc}>, ds.volAutoGrowMax=<#{datastoreSpec.volAutoGrowMax}>")
      rv = rcu.createDatastore(datastoreSpec)
      $log.info("#{log_header} Return Value=<#{rv}> of class=<#{rv.class.name}>")
      return rv
    rescue Handsoap::Fault => hserr
      $log.error "#{log_header} Handsoap::Fault { :code => '#{hserr.code}', :reason => '#{hserr.reason}', :details => '#{hserr.details.inspect}' }"
      $log.error hserr.backtrace.join("\n")
      raise
    rescue => err
      $log.error "#{log_header} #{err}"
      $log.error err.backtrace.join("\n")
      raise
    end
  end

  def self.load_from_yaml
    return [] unless File.exist?(YAML_FILE)

    YAML.load_file(YAML_FILE)
  end
end
