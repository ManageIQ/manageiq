require 'miq_smis_client'
require 'vmdb_storage_bridge'

class MiqSmisAgent < StorageManager
  AGENT_TYPES = {
    "VMDB"  => "VMDB",
    "Agent" => "Agent"
  }

  include MiqSmisClient

  has_many  :top_managed_elements,
            :class_name  => "MiqCimInstance",
            :foreign_key => "agent_top_id"

  has_many  :managed_elements,
            :class_name  => "MiqCimInstance",
            :foreign_key => "agent_id"

  virtual_column  :last_update_status_str,  :type => :string

  DEFAULT_AGENT_TYPE = 'SMIS'
  default_value_for :agent_type, DEFAULT_AGENT_TYPE

  def connect
    # TODO: Use hostname, not ipaddress
    @conn = SmisClient.new(ipaddress, *auth_user_pwd(:default))
    @conn
  end

  def disconnect
    return unless @conn
    @conn.disconnect if @conn.respond_to?(:disconnect)
    @conn = nil
  end

  def self.remove(_ipaddress, _username, _password, _agent_type)
  end

  def self.update_smis(extProf)
    zoneId = MiqServer.my_server.zone.id
    agents = where(:agent_type => "SMIS", :zone_id => zoneId)

    agents.each do |agent|
      agent.last_update_status = STORAGE_UPDATE_PENDING
      agent.save
    end

    MiqCimInstance.where(:source => 'SMIS', :zone_id => zoneId).each do |inst|
      inst.update_attributes(:last_update_status => STORAGE_UPDATE_NO_AGENT)
    end

    pendingAgents = []

    agents.each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Checking agent: #{agent.ipaddress}"
      connectFailed = false
      begin
        agent.connect
      rescue Exception => err
        _log.warn "Agent connection failed: #{agent.ipaddress}"
        $log.warn err.to_s
        $log.warn err.backtrace.join("\n")
        connectFailed = true
      ensure
        agent.disconnect unless connectFailed
      end

      if connectFailed
        _log.info "agent: #{agent.ipaddress} STORAGE_UPDATE_AGENT_INACCESSIBLE"
        agent.last_update_status = STORAGE_UPDATE_AGENT_INACCESSIBLE
        agent.managed_elements.each do |inst|
          inst.last_update_status = STORAGE_UPDATE_AGENT_INACCESSIBLE
          inst.save
        end
      else
        _log.info "agent: #{agent.ipaddress} STORAGE_UPDATE_OK"
        # agent.last_update_status == STORAGE_UPDATE_PENDING
        pendingAgents << agent
        agent.managed_elements.each do |inst|
          inst.last_update_status = STORAGE_UPDATE_AGENT_OK_NO_INSTANCE
          inst.save
        end
      end
      agent.save
    end

    updated = false

    pendingAgents.each do |agent|
      begin
        agent.connect
        agent.last_update_status = STORAGE_UPDATE_IN_PROGRESS
        agent.save
        agent.update_smis(extProf)
        agent.last_update_status = STORAGE_UPDATE_OK
        agent.save
        updated = true
      rescue Exception => err
        # TODO: Log hostname, not ipaddress
        _log.error "agent: #{agent.ipaddress} - #{err}"
        $log.error err.backtrace.join("\n")
        agent.last_update_status = STORAGE_UPDATE_FAILED
        agent.save
      ensure
        agent.disconnect
      end
    end
    updated
  end

  def verify_credentials(auth_type = nil)
    # Verification of creds for other SMA types is handled though mixinx.
    raise _("Credential validation requires the SMIS Agent type be set.") if agent_type.blank?
    raise _("no credentials defined") if missing_credentials?(auth_type)

    begin
      connect
      disconnect
    rescue NameError, Errno::ETIMEDOUT, Errno::ENETUNREACH, WBEM::CIMError
      #
      # We never get here.
      # When the verify fails, we get a "wrong number of args" error,
      # this seems to be due to some strange interaction between WBEM and Rails.
      # This is only a problem in the verify failure case.
      #
      _log.warn("#{$!.inspect}")
      raise $!.message
    rescue Exception
      _log.warn("#{$!.inspect}")
      # $log.info $!.backtrace.join("\n")
      raise _("Unexpected response returned from %{table}, see log for details") %
              {:table => ui_lookup(:table => "ext_management_systems")}
    else
      true
    end
  end

  def update_smis(extProf)
    @conn.update_smis(extProf)
  end

  def update_stats
    top_managed_elements.each do |topMe|
      @conn.default_namespace = topMe.namespace
      $log.debug "\tMiqSmisAgent top managed element: #{topMe.obj_name_str}"
      smgr = SmisStatManager.new(topMe, @conn)
      smgr.updateStats
    end
  end

  def self.update_stats
    where(:agent_type => 'SMIS').each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Agent: #{agent.ipaddress}"

      begin
        agent.connect
        agent.update_stats
      rescue Exception => err
        _log.warn "#{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        agent.disconnect
      end
    end
  end

  def update_status
    managed_elements.each do |me|
      changed = false
      obj = me.obj
      begin
        spRn = @conn.GetInstance(me.obj_name, :LocalNamespacePath => me.namespace, :PropertyList => ['HealthState', 'OperationalStatus'])
      rescue Exception => err
        _log.error "#{err}"
        _log.error "obj_name: #{me.obj_name}"
        next
      end
      if (hs = spRn['HealthState'])
        unless hs == obj['HealthState']
          obj['HealthState'] = hs
          me.obj = obj
          changed = true
        end
      end
      if (os = spRn['OperationalStatus'])
        unless os == obj['OperationalStatus']
          obj['OperationalStatus'] = os
          me.obj = obj
          changed = true
        end
      end
      me.save if changed
    end
  end

  def self.update_status
    where(:agent_type => 'SMIS').each do |agent|
      # TODO: Log hostname, not ipaddress
      _log.info "Agent: #{agent.ipaddress}"

      begin
        agent.connect
        agent.update_status
      rescue Exception => err
        _log.warn "#{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        agent.disconnect
      end
    end
  end

  def self.refresh_inventory_by_subclass(ids, args = {})
    _log.info "queueing refresh requests for [ #{ids.join(', ')} ]"
    request_smis_update(ids, args)
  end

  def self.request_smis_update(ids, _args = {})
    zoneHash = {}
    find(ids).each { |a| zoneHash[a.zone_id] = true }
    zoneHash.each_key do |zid|
      if (rw = MiqSmisRefreshWorker.find_current_in_zone(zid).first).nil?
        _log.warn "no active SmisRefreshWorker found for zone #{zid}"
        next
      end
      _log.info "requesting update for zone #{zid}"
      rw.send_message_to_worker_monitor("request_smis_update")
    end
  end

  def request_smis_update
    rw = MiqSmisRefreshWorker.find_current_in_zone(zone_id).first
    if rw.nil?
      raise _("%{name}.request_smis_update: no active SmisRefreshWorker found for zone %{zone}") % {:name => name,
                                                                                                    :zone => zone_id}
    end
    rw.send_message_to_worker_monitor("request_smis_update")
  end

  def request_status_update
    rw = MiqSmisRefreshWorker.find_current_in_zone(zone_id).first
    if rw.nil?
      raise _("%{name}.request_status_update: no active SmisRefreshWorker found for zone %{zone}") % {:name => name,
                                                                                                      :zone => zone_id}
    end
    rw.send_message_to_worker_monitor("request_status_update")
  end

  #
  # While this method has more to do with the MiqCimInstance class than this class,
  # this class controls updating the database, so it should control cleanup as well.
  #
  def self.cleanup
    zoneId = MiqServer.my_server.zone.id

    MiqCimInstance.where(
      :zone_id            => zoneId,
      :source             => "SMIS",
      :last_update_status => [STORAGE_UPDATE_NO_AGENT, STORAGE_UPDATE_AGENT_OK_NO_INSTANCE]).each do |inst|
      if inst.last_update_status == STORAGE_UPDATE_AGENT_OK_NO_INSTANCE
        alus = inst.agent.last_update_status
        next if alus == STORAGE_UPDATE_FAILED || alus == STORAGE_UPDATE_IN_PROGRESS
      end
      _log.info "deleting SMI-S instance #{inst.class_name} (#{inst.id}) - #{inst.evm_display_name}, last_update_status = #{inst.last_update_status}"
      inst.destroy
    end
    nil
  end
end
