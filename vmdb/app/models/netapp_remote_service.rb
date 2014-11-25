class NetappRemoteService < StorageManager

  has_many  :top_managed_elements,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "agent_top_id"

  has_many  :managed_elements,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "agent_id",
        :dependent    => :destroy # here, but not for SMI-S

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
    @ontapClient = OntapClient.new(ipaddress, *self.auth_user_pwd(:default))
    @nmaClient = @ontapClient.conn
    return @ontapClient
  end

  def disconnect
    @nmaClient    = nil # Will disconnect and clean-up through GC
    @ontapClient  = nil
  end

  def ontap_client
    return @ontapClient unless @ontapClient.nil?
    self.connect
    @ontapClient || (raise "NetappRemoteService: not connected.")
  end

  def nma_client
    return @nmaClient unless @nmaClient.nil?
    self.connect
    @nmaClient || (raise "NetappRemoteService: not connected.")
  end

  def self.refresh_inventory_by_subclass(ids, args={})
    $log.info "#{self.name}.refresh_inventory_by_subclass: queueing refresh requests for [ #{ids.join(', ')} ]"
    queue_refresh(ids, args)
  end

  def self.refresh_metrics_by_subclass(statistic_time, ids)
    $log.info "#{self.name}.refresh_metrics_by_subclass: queueing metrics refresh requests for [ #{ids.join(', ')} ]"
    queue_metrics_refresh(statistic_time, ids)
  end

  def self.metrics_rollup_hourly_by_subclass(rollup_time, ids)
    $log.info "#{self.name}.metrics_rollup_hourly_by_subclass: queueing metrics rollup requests for [ #{ids.join(', ')} ]"
    queue_metrics_rollup_hourly(rollup_time, ids)
  end

  def self.metrics_rollup_daily_by_subclass(rollup_time, time_profile_id, ids)
    $log.info "#{self.name}.metrics_rollup_daily_by_subclass: queueing metrics rollup requests for [ #{ids.join(', ')} ]"
    queue_metrics_rollup_daily(rollup_time, time_profile_id, ids)
  end

  def self.agent_ids_by_zone(ids)
    if ids.empty?
      agents = self.all(:conditions => {:agent_type => DEFAULT_AGENT_TYPE})
    else
      agents = self.find(ids)
    end

    agentIdsByZone = Hash.new { |h, k| h[k] = [] }
    agents.each { |a| agentIdsByZone[a.zone.name] << a.id }

    return agentIdsByZone
  end

  def self.queue_refresh(nrsIds=[], args={})
    agent_ids_by_zone(nrsIds).each do |z, ids|
      $log.info "#{self.name}.queue_refresh: queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone     => z,
        :queue_name   => "netapp_refresh",
        :class_name   => self.name,
        :method_name  => 'update_ontap'
      ) do |msg, queue_options|
        merged_ids = ids
        if msg
          merged_ids = (merged_ids + msg[:args][0]).uniq
          $log.info "#{self.name}.queue_refresh: merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [merged_ids])
      end
    end
  end

  def self.queue_metrics_refresh(statistic_time=nil, nrsIds=[])
    statistic_time ||= Time.now.utc
    agent_ids_by_zone(nrsIds).each do |z, ids|
      $log.info "#{self.name}.queue_metrics_refresh: statistic_time = #{statistic_time}, zone = #{z}"
      $log.info "#{self.name}.queue_metrics_refresh: queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone     => z,
        :queue_name   => "storage_metrics_collector",
        :class_name   => self.name,
        :method_name  => 'update_metrics'
      ) do |msg, queue_options|
        merged_ids = ids
        unless msg.nil?
          merged_ids = (merged_ids + msg[:args][1]).uniq
          $log.info "#{self.name}.queue_metrics_refresh: merging requests from #{msg[:args][0]} with #{statistic_time}, zone = #{z}"
          $log.info "#{self.name}.queue_metrics_refresh: merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [statistic_time, merged_ids])
      end
    end
  end

  def self.queue_metrics_rollup_hourly(rollup_time, nrsIds=[])
    agent_ids_by_zone(nrsIds).each do |z, ids|
      $log.info "#{self.name}.queue_metrics_rollup_hourly: rollup_time = #{rollup_time}, zone = #{z}"
      $log.info "#{self.name}.queue_metrics_rollup_hourly: queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone     => z,
        :queue_name   => "storage_metrics_collector",
        :class_name   => self.name,
        :method_name  => 'rollup_hourly_metrics'
      ) do |msg, queue_options|
        merged_ids = ids
        unless msg.nil?
          merged_ids = (merged_ids + msg[:args][1]).uniq
          $log.info "#{self.name}.queue_metrics_rollup_hourly: merging requests from #{msg[:args][0]} with #{rollup_time}, zone = #{z}"
          $log.info "#{self.name}.queue_metrics_rollup_hourly: merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [rollup_time, merged_ids])
      end
    end
  end

  def self.queue_metrics_rollup_daily(rollup_time, time_profile_id, nrsIds=[])
    agent_ids_by_zone(nrsIds).each do |z, ids|
      $log.info "#{self.name}.queue_metrics_rollup_daily: rollup_time = #{rollup_time}, zone = #{z}, time_profile_id = #{time_profile_id}"
      $log.info "#{self.name}.queue_metrics_rollup_daily: queueing requests to zone #{z} for [ #{ids.join(', ')} ]"
      MiqQueue.put_or_update(
        :zone         => z,
        :queue_name   => "storage_metrics_collector",
        :class_name   => self.name,
        :method_name  => 'rollup_daily_metrics',
        :args_selector  => lambda { |a| a[1] == time_profile_id }
      ) do |msg, queue_options|
        merged_ids = ids
        unless msg.nil?
          merged_ids = (merged_ids + msg[:args][2]).uniq
          $log.info "#{self.name}.queue_metrics_rollup_daily: merging requests from #{msg[:args][0]} with #{rollup_time}, zone = #{z}, time_profile_id = #{time_profile_id}"
          $log.info "#{self.name}.queue_metrics_rollup_daily: merging requests to zone #{z} for [ #{merged_ids.join(', ')} ]"
        end
        queue_options.merge(:args => [rollup_time, time_profile_id, merged_ids])
      end
    end
  end

  def queue_refresh
    self.class.queue_refresh([self.id])
  end

  def self.agent_query(nrsIds)
    return self.where(:conditions => {:agent_type => DEFAULT_AGENT_TYPE, :zone_id => MiqServer.my_server.zone.id}) if nrsIds.empty?
    return self.where(:id => nrsIds)
  end

  def self.update_ontap(nrsIds=[])
    agent_query = self.agent_query(nrsIds)

    agent_query.update_all(:last_update_status => STORAGE_UPDATE_PENDING)
    agent_query.find_each do |agent|
      $log.info "NetappRemoteService.update_ontap: Checking agent: #{agent.ipaddress}"
      begin
        agent.connect
      rescue Exception => err
        $log.warn "NetappRemoteService.update_ontap: Agent connection failed: #{agent.ipaddress}"
        $log.warn err.to_s
        $log.warn err.backtrace.join("\n")

        $log.info "NetappRemoteService.update_ontap: agent: #{agent.ipaddress} STORAGE_UPDATE_AGENT_INACCESSIBLE"
        agent.update_attribute(:last_update_status, STORAGE_UPDATE_AGENT_INACCESSIBLE)
        agent.managed_elements.update_all(:last_update_status => STORAGE_UPDATE_AGENT_INACCESSIBLE)
        next
      end

      $log.info "NetappRemoteService.update_ontap: agent: #{agent.ipaddress} STORAGE_UPDATE_IN_PROGRESS"
      agent.update_attribute(:last_update_status, STORAGE_UPDATE_IN_PROGRESS)
      agent.managed_elements.update_all(:last_update_status => STORAGE_UPDATE_AGENT_OK_NO_INSTANCE)

      begin
        agent.update_ontap
        $log.info "NetappRemoteService.update_ontap: agent: #{agent.ipaddress} STORAGE_UPDATE_OK"
        agent.update_attribute(:last_update_status, STORAGE_UPDATE_OK)
      rescue Exception => err
        $log.error "NetappRemoteService.update_ontap: agent: #{agent.ipaddress} - #{err}"
        $log.error err.backtrace.join("\n")
        agent.update_attribute(:last_update_status, STORAGE_UPDATE_FAILED)
      ensure
        agent.disconnect
      end

      self.cleanup_by_agent(agent)
    end

    StorageManager.queue_refresh_vmdb_cim(MiqServer.my_server.zone.name)
    return nil
  end

  def update_ontap
    ontap_client.updateOntap
  end

  def self.update_metrics(statistic_time=nil, nrsIds=[])
    statistic_time ||= Time.now.utc

    self.agent_query(nrsIds).find_each do |agent|
      $log.info "NetappRemoteService.update_metrics Agent: #{agent.ipaddress} Start..."

      begin
        agent.connect
        agent.update_metrics(statistic_time)
      rescue Exception => err
        $log.warn "NetappRemoteService.update_metrics: #{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        agent.disconnect
        $log.info "NetappRemoteService.update_metrics Agent: #{agent.ipaddress} End"
      end
    end
  end

  def update_metrics(statistic_time)
    ontap_client.updateMetrics(statistic_time)
  end

  def self.rollup_hourly_metrics(rollup_time, nrsIds=[])
    self.agent_query(nrsIds).find_each do |agent|
      $log.info "NetappRemoteService.rollup_hourly_metrics Agent: #{agent.ipaddress} Start..."

      begin
        agent.rollup_hourly_metrics(rollup_time)
      rescue Exception => err
        $log.warn "NetappRemoteService.rollup_hourly_metrics: #{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        $log.info "NetappRemoteService.rollup_hourly_metrics Agent: #{agent.ipaddress} End"
      end
    end
  end

  def rollup_hourly_metrics(rollup_time)
    $log.info "NetappRemoteService.rollup_hourly_metrics Agent: #{self.ipaddress}, rollup_time: #{rollup_time}"
    topMe = self.top_managed_elements.first
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

  def self.rollup_daily_metrics(rollup_time, time_profile_id, nrsIds=[])
    unless (time_profile = TimeProfile.find(time_profile_id))
      $log.info "NetappRemoteService.rollup_daily_metrics: no TimeProfile found with id = #{time_profile_id}"
      return
    end

    self.agent_query(nrsIds).find_each do |agent|
      $log.info "NetappRemoteService.rollup_daily_metrics Agent: #{agent.ipaddress}, TZ: #{time_profile.tz} Start..."

      begin
        agent.rollup_daily_metrics(rollup_time, time_profile)
      rescue Exception => err
        $log.warn "NetappRemoteService.rollup_daily_metrics: #{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        $log.info "NetappRemoteService.rollup_daily_metrics Agent: #{agent.ipaddress}, TZ: #{time_profile.tz} End"
      end
    end
  end

  def rollup_daily_metrics(rollup_time, time_profile)
    $log.info "NetappRemoteService.rollup_daily_metrics Agent: #{self.ipaddress}, rollup_time: #{rollup_time}, TZ: #{time_profile.tz}"
    topMe = self.top_managed_elements.first
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
    return CimComputerSystem.find(:all,  :conditions => { :class_name => "ONTAP_StorageSystem" })
  end

  def self.aggregate_names(oss)
    ocea = MiqCimInstance.find(:all,  :conditions => {
      :class_name => "ONTAP_ConcreteExtent",
      :top_managed_element_id => oss.id
    })
    return ocea.collect { |oce| oce.property('name') }
  end

  def self.volume_names(oss)
    olda = MiqCimInstance.find(:all,  :conditions => {
      :class_name => "ONTAP_LogicalDisk",
      :top_managed_element_id => oss.id
    })
    return olda.collect { |old| old.property('name') }
  end

  def self.remote_service_ips(oss)
    rsapa = MiqCimInstance.find(:all,  :conditions => {
      :class_name => "ONTAP_RemoteServiceAccessPoint",
      :top_managed_element_id => oss.id
    })
    return rsapa.collect { |rsap| rsap.property('name').split(':').first }
  end

  def self.find_controller_by_ip(ip)
    find_controllers.each do |c|
      remote_service_ips(c).each { |cip| return c if cip == ip }
    end
    return nil
  end

  def self.remote_service_info(oss)
    return {
      :evm_display_name => oss.evm_display_name,
      :remote_service_ips => remote_service_ips(oss),
      :aggregates     => aggregate_names(oss),
      :volumes      => volume_names(oss)
    }
  end

  def self.all_remote_service_info
    return find_controllers.collect { |c| remote_service_info(c) }
  end

  def self.dump_controllers
    all_remote_service_info.each do |rsi|
      puts rsi[:evm_display_name]
      puts "\tIP addresses: #{rsi[:remote_service_ips].join(', ')}"
      puts "\tAggregates: #{rsi[:aggregates].join(', ')}"
      puts "\tVolumes: #{rsi[:volumes].join(', ')}"
    end
    return nil
  end

  #####################

  def has_volume?(volumeName)
    begin
      nma_client.volume_list_info(:volume, volumeName)
      return true
    rescue
      return false
    end
  end

  def volume_list_info(volName=nil)
    return nma_client.volume_list_info.volumes.volume_info.to_ary if volName.nil?
    return nma_client.volume_list_info(:volume, volName).volumes.volume_info
  end

  def has_aggr?(aggrName)
    begin
      nma_client.aggr_list_info(:aggregate, aggrName)
      return true
    rescue
      return false
    end
  end

  def aggr_list_info(aggrName=nil)
    return nma_client.aggr_list_info.aggregates.aggr_info.to_ary if aggrName.nil?
    return nma_client.aggr_list_info(:aggregate, aggrName).aggregates.aggr_info
  end

  def options_get(optName)
    rv = nma_client.options_get(:name, optName)
    return rv.value
  end

  def options_set(optName, optValue)
    nma_client.options_set {
      name  optName
      value optValue
    }
  end

  def queue_volume_create_callback(*args)
    smis_agent = MiqSmisAgent.first(:conditions => {:zone_id => self.zone_id})
    if smis_agent.nil?
      $log.error("MIQ(#{self.class.name}.queue_volume_create_callback) Unable to find an SMIS agant for zone: #{self.zone}, skipping SMIS refresh")
      return
    end

    smis_agent.request_smis_update
  end

  def queue_volume_create(volName, aggrName, volSize, spaceReserve="none")
    cb = {:class_name => self.class.name, :instance_id => self.id, :method_name => :queue_volume_create_callback}
    MiqQueue.put(
      :class_name   => self.class.name,
      :instance_id  => self.id,
      :method_name  => 'volume_create',
      :args         => [volName, aggrName, volSize, spaceReserve],
      :role         => 'ems_operations',
      :zone         => self.zone.name,
      :miq_callback => cb
    )
  end

  def volume_create(volName, aggrName, volSize, spaceReserve="none")
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

    nma_client.volume_create {
      containing_aggr_name  aggrName
      volume          volName
      space_reserve     spaceReserve
      size          volSize
    }
  end

  def nfs_add_root_hosts(path, hosts)
    hostNames =  (hosts.kind_of?(Array) ? hosts : [ hosts ])

    rv = nma_client.nfs_exportfs_list_rules(:pathname, path)
    raise "NetappRemoteService.nfs_add_root_hosts: No export rules found for path #{path}" unless rv.kind_of?(NmaHash)

    rules = rv.rules
    rules.exports_rule_info.root = NmaHash.new if rules.exports_rule_info.root.nil?
    if rules.exports_rule_info.root.exports_hostname_info.nil?
      rules.exports_rule_info.root.exports_hostname_info = NmaArray.new
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

      rha << NmaHash.new { name nrhn }
      changed = true
    end

    if changed
      nma_client.nfs_exportfs_modify_rule {
        persistent  true
        rule    rules
      }
    end
  end

  def get_addresses
    rv = nma_client.net_config_get_active
    ia = rv.net_config_info.interfaces.interface_config_info
    ia = [ ia ] unless ia.kind_of?(Array)

    addresses = []
    ia.each do |i|
      next unless (pa = i.v4_primary_address)
      addresses << pa.ip_address_info.address
    end
    return addresses
  end

  #####################

  def get_ts_data(type)
    (type_spec_data[type] || {}).clone
  end

  def set_ts_data(type, data)
    type_spec_data[type] = data
    self.save
  end

  def verify_credentials(auth_type=nil)
    raise "no credentials defined" if self.authentication_invalid?(auth_type)

    begin
      self.volume_list_info
      self.disconnect
    rescue NmaCoreException, NameError, Errno::ETIMEDOUT, Errno::ENETUNREACH
      $log.warn("MIQ(NetappRemoteService-verify_credentials): #{$!.inspect}")
      raise $!.message
    rescue Exception
      $log.warn("MIQ(NetappRemoteService-verify_credentials): #{$!.inspect}")
      raise "Unexpected response returned from #{ui_lookup(:table=>"storage_managers")}, see log for details"
    else
      true
    end
  end

end
