require 'miq_smis_client'
require 'vmdb_storage_bridge'

class MiqSmisAgent < StorageManager
  AGENT_TYPES = {
    "VMDB"  => "VMDB",
    "Agent" => "Agent"
  }

  include MiqSmisClient

  has_many  :top_managed_elements,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "agent_top_id"

  has_many  :managed_elements,
        :class_name   => "MiqCimInstance",
        :foreign_key  => "agent_id"

  virtual_column  :last_update_status_str,  :type => :string

  DEFAULT_AGENT_TYPE = 'SMIS'
  default_value_for :agent_type, DEFAULT_AGENT_TYPE

  def connect
    @conn = SmisClient.new(ipaddress, *self.auth_user_pwd(:default))
    return @conn
  end

  def disconnect
    return unless @conn
    @conn.disconnect if @conn.respond_to?(:disconnect)
    @conn = nil
  end

  def self.remove(ipaddress, username, password, agent_type)
  end

  def self.update_smis(extProf)
    zoneId = MiqServer.my_server.zone.id
    agents = self.find(:all, :conditions => {:agent_type => 'SMIS', :zone_id => zoneId})

    agents.each do |agent|
      agent.last_update_status = STORAGE_UPDATE_PENDING
      agent.save
    end

    MiqCimInstance.find(:all, :conditions => {:source => 'SMIS', :zone_id => zoneId}).each do |inst|
      inst.last_update_status = STORAGE_UPDATE_NO_AGENT
      inst.save
    end

    pendingAgents = []

    agents.each do |agent|
      $log.info "MiqSmisAgent.update_smis: Checking agent: #{agent.ipaddress}"
      connectFailed = false
      begin
        agent.connect
      rescue Exception => err
        $log.warn "MiqSmisAgent.update_smis: Agent connection failed: #{agent.ipaddress}"
        $log.warn err.to_s
        $log.warn err.backtrace.join("\n")
        connectFailed = true
      ensure
        agent.disconnect unless connectFailed
      end

      if connectFailed
        $log.info "MiqSmisAgent.update_smis: agent: #{agent.ipaddress} STORAGE_UPDATE_AGENT_INACCESSIBLE"
        agent.last_update_status = STORAGE_UPDATE_AGENT_INACCESSIBLE
        agent.managed_elements.each do |inst|
          inst.last_update_status = STORAGE_UPDATE_AGENT_INACCESSIBLE
          inst.save
        end
      else
        $log.info "MiqSmisAgent.update_smis: agent: #{agent.ipaddress} STORAGE_UPDATE_OK"
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
        $log.error "MiqSmisAgent.update_smis: agent: #{agent.ipaddress} - #{err}"
        $log.error err.backtrace.join("\n")
        agent.last_update_status = STORAGE_UPDATE_FAILED
        agent.save
      ensure
        agent.disconnect
      end
    end
    return updated
  end

  def verify_credentials(auth_type=nil)
    # Verification of creds for other SMA types is handled though mixinx.
    raise "Credential validation requires the SMIS Agent type be set." if self.agent_type.blank?
    raise "no credentials defined" if self.authentication_invalid?(auth_type)

    begin
      con = self.connect
      self.disconnect
    rescue NameError, Errno::ETIMEDOUT, Errno::ENETUNREACH, WBEM::CIMError
      #
      # We never get here.
      # When the verify fails, we get a "wrong number of args" error,
      # this seems to be due to some strange interaction between WBEM and Rails.
      # This is only a problem in the verify failure case.
      #
      $log.warn("MIQ(MiqSmisAgent-verify_credentials): #{$!.inspect}")
      raise $!.message
    rescue Exception
      $log.warn("MIQ(MiqSmisAgent-verify_credentials): #{$!.inspect}")
      # $log.info $!.backtrace.join("\n")
      raise "Unexpected response returned from #{ui_lookup(:table=>"ext_management_systems")}, see log for details"
    else
      true
    end
  end

  def update_smis(extProf)
    @conn.update_smis(extProf)
  end

  def update_stats
    self.top_managed_elements.each do |topMe|
      @conn.default_namespace = topMe.namespace
      $log.debug "\tMiqSmisAgent top managed element: #{topMe.obj_name_str}"
      smgr = SmisStatManager.new(topMe, @conn)
      smgr.updateStats
    end
  end

  def self.update_stats
    self.find(:all, :conditions => {:agent_type => 'SMIS'}).each do |agent|
      $log.info "MiqSmisAgent.update_stats Agent: #{agent.ipaddress}"

      begin
        agent.connect
        agent.update_stats
      rescue Exception => err
        $log.warn "MiqSmisAgent.update_stats: #{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        agent.disconnect
      end
    end
  end

  def update_status
    self.managed_elements.each do |me|
      changed = false
      obj = me.obj
      begin
        spRn = @conn.GetInstance(me.obj_name, :LocalNamespacePath => me.namespace, :PropertyList => ['HealthState', 'OperationalStatus'])
      rescue Exception => err
        $log.error "update_status: #{err}"
        $log.error "update_status obj_name: #{me.obj_name}"
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
        unless os  == obj['OperationalStatus']
          obj['OperationalStatus'] = os
          me.obj = obj
          changed = true
        end
      end
      me.save if changed
    end
  end

  def self.update_status
    self.find(:all, :conditions => {:agent_type => 'SMIS'}).each do |agent|
      $log.info "MiqSmisAgent.update_status Agent: #{agent.ipaddress}"

      begin
        agent.connect
        agent.update_status
      rescue Exception => err
        $log.warn "MiqSmisAgent.update_status: #{err}"
        $log.warn err.backtrace.join("\n")
        next
      ensure
        agent.disconnect
      end
    end
  end

  def self.refresh_inventory_by_subclass(ids, args={})
    $log.info "#{self.name}.refresh_inventory_by_subclass: queueing refresh requests for [ #{ids.join(', ')} ]"
    request_smis_update(ids, args)
  end

  def self.request_smis_update(ids, args={})
    zoneHash = {}
    self.find(ids).each { |a| zoneHash[a.zone_id] = true }
    zoneHash.each_key do |zid|
      if (rw = MiqSmisRefreshWorker.find_current_in_zone(zid).first).nil?
        $log.warn "#{self.name}.request_smis_update: no active SmisRefreshWorker found for zone #{zid}"
        next
      end
      $log.info "#{self.name}.request_smis_update: requesting update for zone #{zid}"
      rw.send_message_to_worker_monitor("request_smis_update")
    end
  end

  def request_smis_update
    rw = MiqSmisRefreshWorker.find_current_in_zone(self.zone_id).first
    raise "#{self.name}.request_smis_update: no active SmisRefreshWorker found for zone #{self.zone_id}" if rw.nil?
    rw.send_message_to_worker_monitor("request_smis_update")
  end

  def request_status_update
    rw = MiqSmisRefreshWorker.find_current_in_zone(self.zone_id).first
    raise "#{self.name}.request_status_update: no active SmisRefreshWorker found for zone #{self.zone_id}" if rw.nil?
    rw.send_message_to_worker_monitor("request_status_update")
  end

  #
  # While this method has more to do with the MiqCimInstance class than this class,
  # this class controls updating the database, so it should control cleanup as well.
  #
  def self.cleanup
    zoneId = MiqServer.my_server.zone.id

    MiqCimInstance.find(:all, :conditions => [
      "zone_id = ? and source = ? and (last_update_status = ? or last_update_status = ?)",
      zoneId, "SMIS", STORAGE_UPDATE_NO_AGENT, STORAGE_UPDATE_AGENT_OK_NO_INSTANCE
    ]).each do |inst|
      if inst.last_update_status == STORAGE_UPDATE_AGENT_OK_NO_INSTANCE
        alus = inst.agent.last_update_status
        next if alus == STORAGE_UPDATE_FAILED || alus == STORAGE_UPDATE_IN_PROGRESS
      end
      $log.info "MiqSmisAgent.cleanup: deleting SMI-S instance #{inst.class_name} (#{inst.id}) - #{inst.evm_display_name}, last_update_status = #{inst.last_update_status}"
      inst.destroy
    end
    return nil
  end

end
