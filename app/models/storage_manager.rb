require 'miq_storage_defs'

class StorageManager < ActiveRecord::Base
  include AuthenticationMixin
  include FilterableMixin
  include RelationshipMixin

  acts_as_miq_taggable
  include ReportableMixin

  include MiqStorageDefs

  belongs_to  :zone

  validates_presence_of   :name

  serialize :type_spec_data

  virtual_column :zone_name,              :type => :string, :uses => :zone
  virtual_column :type_description,       :type => :string
  virtual_column :last_update_status_str, :type => :string

  SHORTCUT_FROM_CLASSES = [
    :CimComputerSystem,
    :CimLogicalDisk,
    :SniaFileShare,
    :CimStorageVolume,
    :MiqCimDatastore,
    :MiqCimHostSystem,
    :MiqCimVirtualMachine
  ]

  def self.new_of_type(typ, options = {})
    klass = typ.constantize
    options.symbolize_keys!

    options[:ipaddress] ||= options[:hostname]
    options[:hostname] ||= options[:ipaddress]

    klass.new(options)
  end

  def self.add(ipaddress, username, password, agent_type, zone_id = nil, hostname = nil, name = nil)
    # TODO: Use hostname, not ipaddress
    agent = find_by(:ipaddress => ipaddress, :agent_type => agent_type)
    unless agent
      agent = new
      agent.ipaddress   = ipaddress || hostname
      agent.hostname    = hostname || ipaddress
      agent.agent_type  = agent_type
      agent.zone_id   = zone_id
      agent.name      = name

      if username
        auth = Authentication.new
        # TODO: Use hostname, not ipaddress
        auth.name     = "#{self.name} #{ipaddress}"
        auth.authtype   = "default"
        auth.userid     = username
        auth.password   = password
        agent.authentications << auth
      end

      agent.save
    end

    agent
  end

  def self.agent_ids_by_class(agents = nil)
    agents ||= all
    agentIdsByClass = Hash.new { |h, k| h[k] = [] }
    agents.each { |a| agentIdsByClass[a.class] << a.id }
    agentIdsByClass
  end

  def self.refresh_inventory(smIds = nil, args = {})
    if smIds.nil?
      agents = all
    else
      agents = find(smIds)
    end

    agent_ids_by_class(agents).each do |klass, ids|
      _log.info "requesting refresh for instances of subclass #{klass.name}"
      klass.refresh_inventory_by_subclass(ids, args)
    end
  end

  def self.refresh_inventory_by_subclass(_ids, _args = {})
    _log.info "skipping instances of non-refreshable subclass #{name}"
  end

  def self.cleanup_by_agent(agent)
    _log.info "#{agent.hostname} start"
    _log.info "#{agent.hostname} agent.last_update_status = #{agent.last_update_status}"
    agent.managed_elements.where(:last_update_status => STORAGE_UPDATE_AGENT_OK_NO_INSTANCE).find_each(:batch_size => 500) do |inst|
      _log.info "deleting instance #{inst.class_name} (#{inst.id}) - #{inst.evm_display_name}, last_update_status = #{inst.last_update_status}"
      inst.destroy
    end if agent.last_update_status == STORAGE_UPDATE_OK
    _log.info "#{agent.hostname} end"
  end

  def self.queue_refresh_vmdb_cim(zone_name)
    _log.info "queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone        => zone_name,
      :msg_timeout => 36000,
      :queue_name  => "vmdb_storage_bridge",
      :class_name  => name,
      :method_name => 'refresh_vmdb_cim'
    )
  end

  def self.refresh_vmdb_cim
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find_by(:agent_type => "VMDB", :zone_id => zoneId)
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    _log.info "zone = #{zoneId} - STORAGE_UPDATE_IN_PROGRESS"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_IN_PROGRESS)

    agent.managed_elements.update_all(:last_update_status => STORAGE_UPDATE_AGENT_OK_NO_INSTANCE)

    begin
      agent.update_from_vmdb
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      _log.error "#{err}"
      $log.error err.backtrace.join("\n")
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    cleanup_by_agent(agent)
    queue_bridge_associations(MiqServer.my_server.zone.name)
  end

  def update_from_vmdb
    vsb = VmdbStorageBridge.new
    vsb.collectData
  end

  def self.queue_bridge_associations(zone_name)
    _log.info "queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone        => zone_name,
      :msg_timeout => 36000,
      :queue_name  => "vmdb_storage_bridge",
      :class_name  => name,
      :method_name => 'bridge_associations'
    )
  end

  def self.bridge_associations
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find_by(:agent_type => "VMDB", :zone_id => zoneId)
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    _log.info "zone = #{zoneId} - STORAGE_UPDATE_BRIDGE_ASSOCIATIONS"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_BRIDGE_ASSOCIATIONS)

    begin
      agent.bridge_associations
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      _log.error "#{err}"
      $log.error err.backtrace.join("\n")
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    queue_update_association_shortcuts(MiqServer.my_server.zone.name)
  end

  def bridge_associations
    vsb = VmdbStorageBridge.new
    vsb.bridgeAssociations
  end

  def self.queue_update_association_shortcuts(zone_name)
    _log.info "queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone        => zone_name,
      :msg_timeout => 36000,
      :queue_name  => "vmdb_storage_bridge",
      :class_name  => name,
      :method_name => 'update_association_shortcuts'
    )
  end

  def self.update_association_shortcuts
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find_by(:agent_type => "VMDB", :zone_id => zoneId)
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    _log.info "zone = #{zoneId} - STORAGE_UPDATE_ASSOCIATION_SHORTCUTS"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_ASSOCIATION_SHORTCUTS)

    begin
      SHORTCUT_FROM_CLASSES.each do |sfc|
        sfclass = sfc.to_s.constantize
        next unless sfclass.const_defined?(:SHORTCUT_DEFS)
        _log.info "updating shortcuts for instances of #{sfc} in zone #{zoneId}"

        sfclass.where(:zone_id => zoneId).find_each do |sfi|
          sfclass::SHORTCUT_DEFS.each do |accessor, assoc|
            sfi.send(accessor).each do |ti|
              _log.debug "#{sfi.evm_display_name} --> (#{assoc[:AssocClass]}) --> #{ti.evm_display_name}"
              sfi.addAssociation(ti, assoc)
            end
          end
        end
      end
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      _log.error "#{err}"
      $log.error err.backtrace.join("\n")
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    queue_association_cleanup_by_zone(MiqServer.my_server.zone.name)
    nil
  end

  def self.queue_association_cleanup_by_zone(zone_name)
    _log.info "queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone        => zone_name,
      :msg_timeout => 36000,
      :queue_name  => "vmdb_storage_bridge",
      :class_name  => name,
      :method_name => 'association_cleanup_by_zone'
    )
  end

  def self.association_cleanup_by_zone
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find_by(:agent_type => "VMDB", :zone_id => zoneId)
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    _log.info "zone = #{zoneId} - STORAGE_UPDATE_ASSOCIATION_CLEANUP"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_ASSOCIATION_CLEANUP)

    begin
      MiqCimAssociation.cleanup_by_zone(zoneId)
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      _log.error "#{err}"
      $log.error err.backtrace.join("\n")
      _log.info "zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    nil
  end

  def self.refresh_metrics
    statistic_time = Time.now.utc
    agent_ids_by_class.each do |klass, ids|
      _log.info "requesting refresh for instances of subclass #{klass.name}"
      klass.refresh_metrics_by_subclass(statistic_time, ids)
    end
  end

  def self.refresh_metrics_by_subclass(_statistic_time, _ids)
    _log.info "skipping instances of non-refreshable subclass #{name}"
  end

  def self.metrics_rollup_hourly
    _log.info "called"
    t = Time.now.utc
    rollup_time = Time.utc(t.year, t.month, t.day, t.hour, 0, 0, 0)
    agent_ids_by_class.each do |klass, ids|
      _log.info "requesting rollup for instances of subclass #{klass.name}"
      klass.metrics_rollup_hourly_by_subclass(rollup_time, ids)
    end
  end

  def self.metrics_rollup_hourly_by_subclass(_rollup_time, _ids)
    _log.info "skipping instances of subclass #{name}"
  end

  def self.metrics_rollup_daily(time_profile_id)
    _log.info "called: timeProfileId = #{time_profile_id}"
    t = Time.now.utc
    # Do not clear t.hour - it's needed for non-UTC time zones.
    rollup_time = Time.utc(t.year, t.month, t.day, t.hour, 0, 0, 0)
    agent_ids_by_class.each do |klass, ids|
      _log.info "requesting rollup for instances of subclass #{klass.name}"
      klass.metrics_rollup_daily_by_subclass(rollup_time, time_profile_id, ids)
    end
  end

  def self.metrics_rollup_daily_by_subclass(_rollup_time, _time_profile_id, _ids)
    _log.info "skipping instances of subclass #{name}"
  end

  def last_update_status_str
    return "OK"         if last_update_status == STORAGE_UPDATE_OK
    return "Pending"      if last_update_status == STORAGE_UPDATE_PENDING
    return "In Progress"    if last_update_status == STORAGE_UPDATE_IN_PROGRESS
    return "Agent Inaccessible" if last_update_status == STORAGE_UPDATE_AGENT_INACCESSIBLE
    return "Failed"       if last_update_status == STORAGE_UPDATE_FAILED
  end

  def my_zone
    zone = self.zone
    zone.nil? || zone.name.blank? ? MiqServer.my_zone : zone.name
  end
  alias_method :zone_name, :my_zone

  SUPPORTED_TYPES = ["MiqSmisAgent", "NetappRemoteService"]
  def self.supported_types
    SUPPORTED_TYPES.inject({}) { |h, t| h[t] = ui_lookup(:model => t); h }
  end

  def type_description
    ui_lookup(:model => read_attribute(:type))
  end

  DEFAULT_STORAGE_MANAGERS = ["NetappRemoteService"]
  def self.storage_manager_types
    supported_types.slice(*DEFAULT_STORAGE_MANAGERS)
  end
end
