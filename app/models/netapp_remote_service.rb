require 'net_app_manageability/types'

class NetappRemoteService < StorageManager
  has_many  :top_managed_elements,
            :class_name  => "MiqCimInstance",
            :foreign_key => "agent_top_id"

  has_many  :managed_elements,
            :class_name  => "MiqCimInstance",
            :foreign_key => "agent_id",
            :dependent   => :destroy # here, but not for SMI-S

  DEFAULT_AGENT_TYPE = 'NRS'
  default_value_for :agent_type, DEFAULT_AGENT_TYPE

  def self.initialize_class_for_client
    return if class_initialized_for_client?
    require "miq_ontap_client"
    include MiqOntapClient
    @class_initialized_for_client = true
  end

  def self.class_initialized_for_client?
    @class_initialized_for_client
  end

  def connect
    self.class.initialize_class_for_client

    # TODO: Use hostname, not ipaddress
    @ontapClient = OntapClient.new(ipaddress, *auth_user_pwd(:default))
    @namClient = @ontapClient.conn
    @ontapClient
  end

  def disconnect
    @namClient    = nil # Will disconnect and clean-up through GC
    @ontapClient  = nil
  end

  def ontap_client
    return @ontapClient unless @ontapClient.nil?
    connect
    @ontapClient || (raise _("NetappRemoteService: not connected."))
  end

  def nma_client
    return @namClient unless @namClient.nil?
    connect
    @namClient || (raise _("NetappRemoteService: not connected."))
  end

  def self.refresh_inventory_by_subclass(ids, args = {})
    _log.info "queueing refresh requests for [ #{ids.join(', ')} ]"
    queue_refresh(ids, args)
  end

  def self.refresh_metrics_by_subclass(statistic_time, ids)
    _log.info "queueing metrics refresh requests for [ #{ids.join(', ')} ]"
    queue_metrics_refresh(statistic_time, ids)
  end

  def self.metrics_rollup_hourly_by_subclass(rollup_time, ids)
    _log.info "queueing metrics rollup requests for [ #{ids.join(', ')} ]"
    queue_metrics_rollup_hourly(rollup_time, ids)
  end

  def self.metrics_rollup_daily_by_subclass(rollup_time, time_profile_id, ids)
    _log.info "queueing metrics rollup requests for [ #{ids.join(', ')} ]"
    queue_metrics_rollup_daily(rollup_time, time_profile_id, ids)
  end

  def self.agent_ids_by_zone(ids)
    if ids.empty?
      agents = where(:agent_type => DEFAULT_AGENT_TYPE)
    else
      agents = find(ids)
    end

    agentIdsByZone = Hash.new { |h, k| h[k] = [] }
    agents.each { |a| agentIdsByZone[a.zone.name] << a.id }

    agentIdsByZone
  end

  def self.queue_refresh(nrsIds = [], _args = {})
    agent_ids_by_zone(nrsIds).each do |z, ids|
      _log.info "queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone        => z,
        :queue_name  => "netapp_refresh",
        :class_name  => name,
        :method_name => 'update_ontap'
      ) do |msg, queue_options|
        merged_ids = ids
        if msg
          merged_ids = (merged_ids + msg[:args][0]).uniq
          _log.info "merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [merged_ids])
      end
    end
  end

  def self.queue_metrics_refresh(statistic_time = nil, nrsIds = [])
    statistic_time ||= Time.now.utc
    agent_ids_by_zone(nrsIds).each do |z, ids|
      _log.info "statistic_time = #{statistic_time}, zone = #{z}"
      _log.info "queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone        => z,
        :queue_name  => "storage_metrics_collector",
        :class_name  => name,
        :method_name => 'update_metrics'
      ) do |msg, queue_options|
        merged_ids = ids
        unless msg.nil?
          merged_ids = (merged_ids + msg[:args][1]).uniq
          _log.info "merging requests from #{msg[:args][0]} with #{statistic_time}, zone = #{z}"
          _log.info "merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [statistic_time, merged_ids])
      end
    end
  end

  def self.queue_metrics_rollup_hourly(rollup_time, nrsIds = [])
    agent_ids_by_zone(nrsIds).each do |z, ids|
      _log.info "rollup_time = #{rollup_time}, zone = #{z}"
      _log.info "queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone        => z,
        :queue_name  => "storage_metrics_collector",
        :class_name  => name,
        :method_name => 'rollup_hourly_metrics'
      ) do |msg, queue_options|
        merged_ids = ids
        unless msg.nil?
          merged_ids = (merged_ids + msg[:args][1]).uniq
          _log.info "merging requests from #{msg[:args][0]} with #{rollup_time}, zone = #{z}"
          _log.info "merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [rollup_time, merged_ids])
      end
    end
  end

  def self.queue_metrics_rollup_daily(rollup_time, time_profile_id, nrsIds = [])
    agent_ids_by_zone(nrsIds).each do |z, ids|
      _log.info "rollup_time = #{rollup_time}, zone = #{z}, time_profile_id = #{time_profile_id}"
      _log.info "queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone          => z,
        :queue_name    => "storage_metrics_collector",
        :class_name    => name,
        :method_name   => 'rollup_daily_metrics',
        :args_selector => ->(a) { a[1] == time_profile_id }
      ) do |msg, queue_options|
        merged_ids = ids
        unless msg.nil?
          merged_ids = (merged_ids + msg[:args][2]).uniq
          _log.info "merging requests from #{msg[:args][0]} with #{rollup_time}, zone = #{z}, time_profile_id = #{time_profile_id}"
          _log.info "merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [rollup_time, time_profile_id, merged_ids])
      end
    end
  end

  def queue_refresh
    self.class.queue_refresh([id])
  end

  def self.agent_query(nrsIds)
    return where(:id => nrsIds) if nrsIds.present?
    where(:agent_type => DEFAULT_AGENT_TYPE, :zone_id => MiqServer.my_server.zone.id)
  end

  def self.update_ontap(nrsIds = [])
    agent_query = self.agent_query(nrsIds)

    agent_query.update_all(:last_update_status => STORAGE_UPDATE_PENDING)
    agent_query.find_each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Checking agent: #{agent.ipaddress}"
      begin
        agent.connect
      rescue Exception => err
        _log.warn "Agent connection failed: #{agent.ipaddress}"
        $log.warn err.to_s
        $log.warn err.backtrace.join("\n")

        _log.info "agent: #{agent.ipaddress} STORAGE_UPDATE_AGENT_INACCESSIBLE"
        agent.update_attribute(:last_update_status, STORAGE_UPDATE_AGENT_INACCESSIBLE)
        agent.managed_elements.update_all(:last_update_status => STORAGE_UPDATE_AGENT_INACCESSIBLE)
        next
      end

      _log.info "agent: #{agent.ipaddress} STORAGE_UPDATE_IN_PROGRESS"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_IN_PROGRESS)
      agent.managed_elements.update_all(:last_update_status => STORAGE_UPDATE_AGENT_OK_NO_INSTANCE)

      # TODO: Log hostname, not ipaddress
      begin
        agent.update_ontap
        _log.info "agent: #{agent.ipaddress} STORAGE_UPDATE_OK"
        agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
      rescue Exception => err
        _log.error "agent: #{agent.ipaddress} - #{err}"
        $log.error err.backtrace.join("\n")
        agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
      ensure
        agent.disconnect
      end

      cleanup_by_agent(agent)
    end

    StorageManager.queue_refresh_vmdb_cim(MiqServer.my_server.zone.name)
    nil
  end

  def update_ontap
    ontap_client.updateOntap
  end

  def self.update_metrics(statistic_time = nil, nrsIds = [])
    statistic_time ||= Time.now.utc

    agent_query(nrsIds).find_each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Agent: #{agent.ipaddress} Start..."

      begin
        agent.connect
        agent.update_metrics(statistic_time)
      rescue Exception => err
        _log.warn "#{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        agent.disconnect
        _log.info "Agent: #{agent.ipaddress} End"
      end
    end
  end

  def update_metrics(statistic_time)
    ontap_client.updateMetrics(statistic_time)
  end

  def self.rollup_hourly_metrics(rollup_time, nrsIds = [])
    agent_query(nrsIds).find_each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Agent: #{agent.ipaddress} Start..."

      begin
        agent.rollup_hourly_metrics(rollup_time)
      rescue Exception => err
        _log.warn "#{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        _log.info "Agent: #{agent.ipaddress} End"
      end
    end
  end

  def rollup_hourly_metrics(rollup_time)
    # TODO: Log hostname, not ipaddress
    _log.info "Agent: #{ipaddress}, rollup_time: #{rollup_time}"
    topMe = top_managed_elements.first
    topMe.elements_with_metrics.each do |se|
      rollup_hourly_metrics_for_node(se, rollup_time)
    end unless topMe.nil?
  end

  def rollup_hourly_metrics_for_node(node, rollup_time)
    if (metric = node.metrics).nil?
      return
    end
    node.metrics.rollup_hourly(rollup_time)
  end

  def self.rollup_daily_metrics(rollup_time, time_profile_id, nrsIds = [])
    unless (time_profile = TimeProfile.find(time_profile_id))
      _log.info "no TimeProfile found with id = #{time_profile_id}"
      return
    end

    agent_query(nrsIds).find_each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Agent: #{agent.ipaddress}, TZ: #{time_profile.tz} Start..."

      begin
        agent.rollup_daily_metrics(rollup_time, time_profile)
      rescue Exception => err
        _log.warn "#{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        _log.info "Agent: #{agent.ipaddress}, TZ: #{time_profile.tz} End"
      end
    end
  end

  def rollup_daily_metrics(rollup_time, time_profile)
    # TODO: Log hostname, not ipaddress
    _log.info "Agent: #{ipaddress}, rollup_time: #{rollup_time}, TZ: #{time_profile.tz}"
    topMe = top_managed_elements.first
    topMe.elements_with_metrics.each do |se|
      rollup_daily_metrics_for_node(se, rollup_time, time_profile)
    end unless topMe.nil?
  end

  def rollup_daily_metrics_for_node(node, rollup_time, time_profile)
    if (metric = node.metrics).nil?
      return
    end
    node.metrics.rollup_daily(rollup_time, time_profile)
  end

  #
  # Class methods used by RCU.
  #

  def self.find_controllers
    CimComputerSystem.where(:class_name => "ONTAP_StorageSystem").to_a
  end

  def self.aggregate_names(oss)
    MiqCimInstance.select(:id, :properites)
      .where(:class_name => "ONTAP_ConcreteExtent", :top_managed_element_id => oss.id)
      .collect { |oce| oce.property('name') }
  end

  def self.volume_names(oss)
    MiqCimInstance.select(:id, :properites)
      .where(:class_name => "ONTAP_LogicalDisk", :top_managed_element_id => oss.id)
      .collect { |old| old.property('name') }
  end

  def self.remote_service_ips(oss)
    MiqCimInstance.select(:id, :properites)
      .where(:class_name => "ONTAP_RemoteServiceAccessPoint", :top_managed_element_id => oss.id)
      .collect { |rsap| rsap.property('name').split(':').first }
  end

  def self.find_controller_by_ip(ip)
    find_controllers.each do |c|
      remote_service_ips(c).each { |cip| return c if cip == ip }
    end
    nil
  end

  def self.remote_service_info(oss)
    {
      :evm_display_name   => oss.evm_display_name,
      :remote_service_ips => remote_service_ips(oss),
      :aggregates         => aggregate_names(oss),
      :volumes            => volume_names(oss)
    }
  end

  def self.all_remote_service_info
    find_controllers.collect { |c| remote_service_info(c) }
  end

  def self.dump_controllers
    all_remote_service_info.each do |rsi|
      puts rsi[:evm_display_name]
      puts "\tIP addresses: #{rsi[:remote_service_ips].join(', ')}"
      puts "\tAggregates: #{rsi[:aggregates].join(', ')}"
      puts "\tVolumes: #{rsi[:volumes].join(', ')}"
    end
    nil
  end

  #####################

  def has_volume?(volumeName)
    nma_client.volume_list_info(:volume, volumeName)
    return true
  rescue
    return false
  end

  def volume_list_info(volName = nil)
    return nma_client.volume_list_info.volumes.volume_info.to_ary if volName.nil?
    nma_client.volume_list_info(:volume, volName).volumes.volume_info
  end

  def has_aggr?(aggrName)
    nma_client.aggr_list_info(:aggregate, aggrName)
    return true
  rescue
    return false
  end

  def aggr_list_info(aggrName = nil)
    return nma_client.aggr_list_info.aggregates.aggr_info.to_ary if aggrName.nil?
    nma_client.aggr_list_info(:aggregate, aggrName).aggregates.aggr_info
  end

  def options_get(optName)
    rv = nma_client.options_get(:name, optName)
    rv.value
  end

  def options_set(optName, optValue)
    nma_client.options_set do
      name  optName
      value optValue
    end
  end

  def queue_volume_create_callback(*_args)
    smis_agent = MiqSmisAgent.find_by(:zone_id => zone_id)
    if smis_agent.nil?
      _log.error("Unable to find an SMIS agant for zone: #{zone}, skipping SMIS refresh")
      return
    end

    smis_agent.request_smis_update
  end

  def queue_volume_create(volName, aggrName, volSize, spaceReserve = "none")
    cb = {:class_name => self.class.name, :instance_id => id, :method_name => :queue_volume_create_callback}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => id,
      :method_name  => 'volume_create',
      :args         => [volName, aggrName, volSize, spaceReserve],
      :role         => 'ems_operations',
      :zone         => zone.name,
      :miq_callback => cb
    )
  end

  def volume_create(volName, aggrName, volSize, spaceReserve = "none")
    #
    # The creation of the volume will result in the creation a qtree entry for its root.
    # If we want to base a VMware datastore on the volume's NFS share, the security style of
    # its corresponding qtree must not be 'ntfs'.
    #
    # Unfortunately, the API doesn't provide a way to specify this value or change it after the fact.
    # The security style is always set to the value of the 'wafl.default_security_style' option.
    # So we must ensure that this value is set to either 'unix' or 'mixed' before the volume is created.
    #
    if options_get('wafl.default_security_style') == "ntfs"
      options_set('wafl.default_security_style', 'mixed')
    end

    nma_client.volume_create do
      containing_aggr_name  aggrName
      volume          volName
      space_reserve     spaceReserve
      size          volSize
    end
  end

  def nfs_add_root_hosts(path, hosts)
    hostNames =  (hosts.kind_of?(Array) ? hosts : [hosts])

    rv = nma_client.nfs_exportfs_list_rules(:pathname, path)
    unless rv.kind_of?(NetAppManageability::NAMHash)
      raise _("NetappRemoteService.nfs_add_root_hosts: No export rules found for path %{path}") % {:path => path}
    end

    rules = rv.rules
    rules.exports_rule_info.root = NetAppManageability::NAMHash.new if rules.exports_rule_info.root.nil?
    if rules.exports_rule_info.root.exports_hostname_info.nil?
      rules.exports_rule_info.root.exports_hostname_info = NetAppManageability::NAMArray.new
    else
      rules.exports_rule_info.root.exports_hostname_info = rules.exports_rule_info.root.exports_hostname_info.to_ary
    end

    rha = rules.exports_rule_info.root.exports_hostname_info

    changed = false
    hostNames.each do |nrhn|
      skip = false
      rha.each do |crhh|
        if crhh.name == nrhn
          skip = true
          break
        end
      end
      next if skip

      rha << NetAppManageability::NAMHash.new { name nrhn }
      changed = true
    end

    if changed
      nma_client.nfs_exportfs_modify_rule do
        persistent  true
        rule    rules
      end
    end
  end

  def get_addresses
    rv = nma_client.net_config_get_active
    ia = rv.net_config_info.interfaces.interface_config_info
    ia = [ia] unless ia.kind_of?(Array)

    addresses = []
    ia.each do |i|
      next unless (pa = i.v4_primary_address)
      addresses << pa.ip_address_info.address
    end
    addresses
  end

  #####################

  def get_ts_data(type)
    (type_spec_data[type] || {}).clone
  end

  def set_ts_data(type, data)
    type_spec_data[type] = data
    save
  end

  def verify_credentials(auth_type = nil)
    raise _("no credentials defined") if missing_credentials?(auth_type)

    begin
      volume_list_info
      disconnect
    rescue NetAppManageability::Error, NameError, Errno::ETIMEDOUT, Errno::ENETUNREACH
      _log.warn("#{$!.inspect}")
      raise $!.message
    rescue Exception
      _log.warn("#{$!.inspect}")
      raise _("Unexpected response returned from %{table}, see log for details") %
              {:table => ui_lookup(:table => "storage_managers")}
    else
      true
    end
  end
end
