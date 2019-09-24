module MiqServer::ServerMonitor
  extend ActiveSupport::Concern

  def mark_as_not_responding(seconds = miq_server_time_threshold)
    msg = "#{format_full_log_msg} has not responded in #{seconds} seconds."
    _log.info(msg)
    update(:status => "not responding")
    deactivate_all_roles

    # TODO: need to add event for this
    MiqEvent.raise_evm_event_queue_in_region(self, "evm_server_not_responding", :event_details => msg)

    # Mark all messages currently being worked on by the not responding server's workers as error
    _log.info("Cleaning all active messages being processed by #{format_full_log_msg}")
    miq_workers.each(&:clean_active_messages)
  end

  def make_master_server(last_master)
    _log.info("Master server has #{last_master.nil? ? "not been set" : "died, #{last_master.name}"}.  Attempting takeover as new master server, #{name}.")
    parent = MiqRegion.my_region(true)
    parent.lock do
      # See if an ACTIVE server has already taken over
      active_servers = parent.active_miq_servers

      _log.debug("Double checking that nothing has changed")
      master = active_servers.detect(&:is_master?)
      if (last_master.nil? && !master.nil?) || (!last_master.nil? && !master.nil? && last_master.id != master.id)
        _log.info("Aborting master server takeover as another server, #{master.name}, has taken control first.")
        return nil
      end

      _log.debug("Setting this server, #{name}, as master server")

      # Set is_master on self, reset every other server in the region, including
      # inactive ones.
      parent.miq_servers.each do |s|
        s.is_master = (id == s.id)
        s.save!
      end
    end
    _log.info("This server #{name} is now set as the master server, last_master: #{last_master.try(:name)}")
    self
  end

  def miq_server_time_threshold
    ::Settings.server.heartbeat_timeout.to_i_with_method
  end

  def monitor_servers_as_master
    _log.debug("Checking other servers as master server")
    @last_master = nil
    @last_servers ||= {}

    # Check all of the other servers and see if we have new servers, servers have stopped, or servers have stopped responding
    all_servers = find_other_started_servers_in_region

    current_ids = all_servers.collect(&:id)
    last_ids    = @last_servers.keys
    added       = current_ids - last_ids
    removed     = last_ids - current_ids
    # unchanged = current_ids & last_ids

    removed.each do |id|
      last_server = @last_servers.delete(id)
      rec = last_server[:record]
      _log.info("#{rec.format_full_log_msg} has been stopped or removed, and will no longer be monitored.")
      rec.deactivate_all_roles
    end

    all_servers.each do |s|
      if added.include?(s.id)
        _log.info("#{s.format_full_log_msg} has been started or added, and will now be monitored.")
        @last_servers[s.id] = {
          :last_hb_change => Time.now.utc,
          :record         => s
        }

        if s.is_master?
          _log.info("#{s.format_short_log_msg} has been detected as a second master and is being demoted.")
          update(:is_master => false)
        end

      else # unchanged
        last_server = @last_servers[s.id]
        rec = last_server[:record]
        _log.debug("Checking #{s.format_full_log_msg}. time_threshold [#{miq_server_time_threshold.seconds.ago.utc}] last_heartbeat changed [#{rec.last_heartbeat}] last_heartbeat [#{s.last_heartbeat}]")
        # Check if the server has updated or has not passed the threshold
        if rec.last_heartbeat != s.last_heartbeat || miq_server_time_threshold.seconds.ago.utc <= last_server[:last_hb_change]
          last_server[:last_hb_change] = Time.now.utc if rec.last_heartbeat != s.last_heartbeat
          last_server[:record] = s
        else
          @last_servers.delete(s.id)
          s.mark_as_not_responding
        end
      end
    end
  end

  def monitor_servers_as_non_master
    @last_servers  = {}
    @last_master ||= {}
    rec = @last_master[:record]

    parent = MiqRegion.my_region
    master = parent.find_master_server

    msg = "Checking master MiqServer."
    msg << " There is no master server." if master.nil?
    msg << " time_threshold [#{miq_server_time_threshold.seconds.ago.utc}] last_heartbeat changed [#{@last_master[:last_hb_change]}] last_heartbeat [#{rec.last_heartbeat}]" unless master.nil? || rec.nil?
    _log.debug(msg)

    # Check if master is found; and has never been set, has changed, has heartbeated,
    #   or has not passed the threshold since the last heartbeat should have changed
    if !master.nil? && (@last_master.empty? || rec != master || rec.last_heartbeat != master.last_heartbeat || miq_server_time_threshold.seconds.ago.utc <= @last_master[:last_hb_change])
      @last_master[:last_hb_change] = Time.now.utc if rec.nil? || rec.last_heartbeat != master.last_heartbeat
      @last_master[:record] = master
    else
      _log.info("Master #{master.format_full_log_msg} has not responded in #{miq_server_time_threshold} seconds.") unless master.nil?
      make_master_server(@last_master.empty? ? nil : @last_master[:record])
      if reload.is_master?
        master.mark_as_not_responding unless master.nil?
        @last_master = nil

        parent.miq_servers.each do |s|
          next unless s.status == 'started'
          next if     s.is_master?
          @last_servers[s.id] = {:last_hb_change => Time.now.utc, :record => s}
        end

        # Raise miq_server_is_master event
        master_msg = master && " from #{master.format_short_log_msg}"
        msg = "#{format_short_log_msg} has taken over master#{master_msg}"
        MiqEvent.raise_evm_event_queue_in_region(self, "evm_server_is_master", :event_details => msg)

        monitor_servers_as_master
      else
        @last_master[:last_hb_change] = Time.now.utc
        @last_master[:record] = parent.find_master_server
      end
    end
  end

  def monitor_servers
    reload.is_master? ? monitor_servers_as_master : monitor_servers_as_non_master
  end
end
