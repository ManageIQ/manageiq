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

  def self.new_of_type(typ, options={})
    klass = typ.constantize
    options.symbolize_keys!

    options[:ipaddress] ||= options[:hostname]
    options[:hostname]  ||= options[:ipaddress]

    klass.new(options)
  end

  def self.add(ipaddress, username, password, agent_type, zone_id=nil, hostname=nil, name=nil)
    agent = self.first(:conditions => { :ipaddress => ipaddress, :agent_type => agent_type })
    unless (agent)
      agent = self.new
      agent.ipaddress   = ipaddress || hostname
      agent.hostname    = hostname || ipaddress
      agent.agent_type  = agent_type
      agent.zone_id   = zone_id
      agent.name      = name

      if username
        auth = Authentication.new
        auth.name     = "#{self.name} #{ipaddress}"
        auth.authtype   = "default"
        auth.userid     = username
        auth.password   = password
        agent.authentications << auth
      end

      agent.save
    end

    return agent
  end

  def self.agent_ids_by_class(agents=nil)
    agents ||= self.all
    agentIdsByClass = Hash.new { |h, k| h[k] = [] }
    agents.each { |a| agentIdsByClass[a.class] << a.id }
    return agentIdsByClass
  end

  def self.refresh_inventory(smIds=nil, args={})
    if smIds.nil?
      agents = self.all
    else
      agents = self.find(smIds)
    end

    agent_ids_by_class(agents).each do |klass, ids|
      $log.info "StorageManager.refresh_inventory: requesting refresh for instances of subclass #{klass.name}"
      klass.refresh_inventory_by_subclass(ids, args)
    end
  end

  def self.refresh_inventory_by_subclass(ids, args={})
    $log.info "StorageManager.refresh_inventory_by_subclass: skipping instances of non-refreshable subclass #{self.name}"
  end

  def self.cleanup_by_agent(agent)
    $log.info "StorageManager.cleanup_by_agent: #{agent.hostname} start"
    $log.info "StorageManager.cleanup_by_agent: #{agent.hostname} agent.last_update_status = #{agent.last_update_status}"
    agent.managed_elements.where(:last_update_status => STORAGE_UPDATE_AGENT_OK_NO_INSTANCE).find_each(:batch_size => 500) do |inst|
      $log.info "StorageManager.cleanup_by_agent: deleting instance #{inst.class_name} (#{inst.id}) - #{inst.evm_display_name}, last_update_status = #{inst.last_update_status}"
      inst.destroy
    end if agent.last_update_status == STORAGE_UPDATE_OK
    $log.info "StorageManager.cleanup_by_agent: #{agent.hostname} end"
  end

  def self.queue_refresh_vmdb_cim(zone_name)
    $log.info "#{self.name}.refresh_vmdb_cim: queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone     => zone_name,
      :msg_timeout  => 36000,
      :queue_name   => "vmdb_storage_bridge",
      :class_name   => self.name,
      :method_name  => 'refresh_vmdb_cim'
    )
  end

  def self.refresh_vmdb_cim
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find(:first, :conditions => {:agent_type => 'VMDB', :zone_id => zoneId})
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    $log.info "#{self.name}.refresh_vmdb_cim: zone = #{zoneId} - STORAGE_UPDATE_IN_PROGRESS"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_IN_PROGRESS)

    agent.managed_elements.update_all(:last_update_status => STORAGE_UPDATE_AGENT_OK_NO_INSTANCE)

    begin
      agent.update_from_vmdb
      $log.info "#{self.name}.refresh_vmdb_cim: zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      $log.error "#{self.name}.refresh_vmdb_cim: #{err}"
      $log.error err.backtrace.join("\n")
      $log.info "#{self.name}.refresh_vmdb_cim: zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    self.cleanup_by_agent(agent)
    self.queue_bridge_associations(MiqServer.my_server.zone.name)
  end

  def update_from_vmdb
    vsb = VmdbStorageBridge.new
    vsb.collectData
  end

  def self.queue_bridge_associations(zone_name)
    $log.info "#{self.name}.queue_bridge_associations: queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone     => zone_name,
      :msg_timeout  => 36000,
      :queue_name   => "vmdb_storage_bridge",
      :class_name   => self.name,
      :method_name  => 'bridge_associations'
    )
  end

  def self.bridge_associations
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find(:all, :conditions => {:agent_type => 'VMDB', :zone_id => zoneId}).first
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    $log.info "#{self.name}.bridge_associations: zone = #{zoneId} - STORAGE_UPDATE_BRIDGE_ASSOCIATIONS"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_BRIDGE_ASSOCIATIONS)

    begin
      agent.bridge_associations
      $log.info "#{self.name}.bridge_associations: zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      $log.error "#{self.name}.bridge_associations: #{err}"
      $log.error err.backtrace.join("\n")
      $log.info "#{self.name}.bridge_associations: zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    self.queue_update_association_shortcuts(MiqServer.my_server.zone.name)
  end

  def bridge_associations
    vsb = VmdbStorageBridge.new
    vsb.bridgeAssociations
  end

  def self.queue_update_association_shortcuts(zone_name)
    $log.info "#{self.name}.queue_update_association_shortcuts: queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone     => zone_name,
      :msg_timeout  => 36000,
      :queue_name   => "vmdb_storage_bridge",
      :class_name   => self.name,
      :method_name  => 'update_association_shortcuts'
    )
  end

  def self.update_association_shortcuts
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find(:all, :conditions => {:agent_type => 'VMDB', :zone_id => zoneId}).first
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    $log.info "#{self.name}.update_association_shortcuts: zone = #{zoneId} - STORAGE_UPDATE_ASSOCIATION_SHORTCUTS"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_ASSOCIATION_SHORTCUTS)

    begin
      SHORTCUT_FROM_CLASSES.each do |sfc|
        sfclass = sfc.to_s.constantize
        next unless sfclass.const_defined?(:SHORTCUT_DEFS)
        $log.info "#{self.name}.update_association_shortcuts: updating shortcuts for instances of #{sfc} in zone #{zoneId}"

        sfclass.where(:zone_id => zoneId).find_each do |sfi|
          sfclass::SHORTCUT_DEFS.each do |accessor, assoc|
            sfi.send(accessor).each do |ti|
              $log.debug "#{self.name}.update_association_shortcuts: #{sfi.evm_display_name} --> (#{assoc[:AssocClass]}) --> #{ti.evm_display_name}"
              sfi.addAssociation(ti, assoc)
            end
          end
        end
      end
      $log.info "#{self.name}.update_association_shortcuts: zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      $log.error "#{self.name}.update_association_shortcuts: #{err}"
      $log.error err.backtrace.join("\n")
      $log.info "#{self.name}.update_association_shortcuts: zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    self.queue_association_cleanup_by_zone(MiqServer.my_server.zone.name)
    return nil
  end

  def self.queue_association_cleanup_by_zone(zone_name)
    $log.info "#{self.name}.queue_association_cleanup_by_zone: queueing requests to zone #{zone_name}"
    MiqQueue.put_unless_exists(
      :zone     => zone_name,
      :msg_timeout  => 36000,
      :queue_name   => "vmdb_storage_bridge",
      :class_name   => self.name,
      :method_name  => 'association_cleanup_by_zone'
    )
  end

  def self.association_cleanup_by_zone
    zoneId = MiqServer.my_server.zone.id
    agent = CimVmdbAgent.find(:all, :conditions => {:agent_type => 'VMDB', :zone_id => zoneId}).first
    agent = CimVmdbAgent.add(nil, nil, nil, 'VMDB', zoneId, "VMDB-#{zoneId}") unless agent
    $log.info "#{self.name}.association_cleanup_by_zone: zone = #{zoneId} - STORAGE_UPDATE_ASSOCIATION_CLEANUP"
    agent.update_attribute(:last_update_status, STORAGE_UPDATE_ASSOCIATION_CLEANUP)

    begin
      MiqCimAssociation.cleanup_by_zone(zoneId)
      $log.info "#{self.name}.association_cleanup_by_zone: zone = #{zoneId} - STORAGE_UPDATE_OK"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
    rescue Exception => err
      $log.error "#{self.name}.association_cleanup_by_zone: #{err}"
      $log.error err.backtrace.join("\n")
      $log.info "#{self.name}.association_cleanup_by_zone: zone = #{zoneId} - STORAGE_UPDATE_FAILED"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
    end
    return nil
  end

  def self.refresh_metrics
    statistic_time = Time.now.utc
    agent_ids_by_class.each do |klass, ids|
      $log.info "StorageManager.refresh_metrics: requesting refresh for instances of subclass #{klass.name}"
      klass.refresh_metrics_by_subclass(statistic_time, ids)
    end
  end

  def self.refresh_metrics_by_subclass(statistic_time, ids)
    $log.info "StorageManager.refresh_metrics_by_subclass: skipping instances of non-refreshable subclass #{self.name}"
  end

  def self.metrics_rollup_hourly
    $log.info "StorageManager.metrics_rollup_hourly called"
    t = Time.now.utc
    rollup_time = Time.utc(t.year, t.month, t.day, t.hour, 0, 0, 0)
    agent_ids_by_class.each do |klass, ids|
      $log.info "StorageManager.metrics_rollup_hourly: requesting rollup for instances of subclass #{klass.name}"
      klass.metrics_rollup_hourly_by_subclass(rollup_time, ids)
    end
  end

  def self.metrics_rollup_hourly_by_subclass(rollup_time, ids)
    $log.info "StorageManager.metrics_rollup_hourly_by_subclass: skipping instances of subclass #{self.name}"
  end

  def self.metrics_rollup_daily(time_profile_id)
    $log.info "StorageManager.metrics_rollup_daily called: timeProfileId = #{time_profile_id}"
    t = Time.now.utc
    # Do not clear t.hour - it's needed for non-UTC time zones.
    rollup_time = Time.utc(t.year, t.month, t.day, t.hour, 0, 0, 0)
    agent_ids_by_class.each do |klass, ids|
      $log.info "StorageManager.metrics_rollup_daily: requesting rollup for instances of subclass #{klass.name}"
      klass.metrics_rollup_daily_by_subclass(rollup_time, time_profile_id, ids)
    end
  end

  def self.metrics_rollup_daily_by_subclass(rollup_time, time_profile_id, ids)
    $log.info "StorageManager.metrics_rollup_daily_by_subclass: skipping instances of subclass #{self.name}"
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
  alias zone_name my_zone

  SUPPORTED_TYPES = ["MiqSmisAgent", "NetappRemoteService"]
  def self.supported_types
    SUPPORTED_TYPES.inject({}) { |h,t| h[t] = ui_lookup(:model => t); h }
  end

  def type_description
    ui_lookup(:model => read_attribute(:type))
  end

  DEFAULT_STORAGE_MANAGERS = ["NetappRemoteService"]
  def self.storage_manager_types
    self.supported_types.slice(*DEFAULT_STORAGE_MANAGERS)
  end

end
