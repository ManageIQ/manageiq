require 'miq_apache'
module MiqServer::EnvironmentManagement
  extend ActiveSupport::Concern

  module ClassMethods
    # Spartan mode used for testing only.
    #   minimal - Runs with 1 worker monitor, 1 generic, and 1 priority worker only
    #             Can also specify other specific worker types, to start a single
    #               worker, via underscore separation, e.g. minimal_schedule to start
    #               1 schedule worker.
    def spartan_mode
      @spartan_mode ||= ENV["MIQ_SPARTAN"].to_s.strip
    end

    def minimal_env?
      spartan_mode.start_with?("minimal")
    end

    def normal_env?
      !self.minimal_env?
    end

    MIQ_SPARTAN_ROLE_SEPARATOR = ":"
    def minimal_env_options
      @minimal_env_options ||= begin
        options = self.minimal_env? ? spartan_mode.split(MIQ_SPARTAN_ROLE_SEPARATOR) : []
        options.shift # remove the "minimal" from the front of the array

        # Special case where Netbeans is handling the UI worker for debugging
        options.collect { |o| o.downcase == "netbeans" ? %w{schedule reporting noui} : o }.flatten
      end
    end

    def startup_mode
      mode = ""
      # Find out startup mode
      if self.minimal_env?
        mode = "Minimal"
        mode << " [#{self.minimal_env_options.join(', ')}]" unless self.minimal_env_options.empty?
      else
        mode = "Normal"
      end

      return mode
    end

    def get_network_information
      ipaddr = hostname = mac_address = ''
      begin
        if MiqEnvironment::Command.is_linux? && File.exist?('/bin/miqnet.sh')
          ipaddr      = `/bin/miqnet.sh -GET IP`.chomp
          hostname    = `/bin/miqnet.sh -GET HOST`.chomp
          mac_address = `/bin/miqnet.sh -GET MAC`.chomp
        else
          require 'MiqSockUtil'
          ipaddr      = MiqSockUtil.getIpAddr
          hostname    = MiqSockUtil.getFullyQualifiedDomainName
          mac_address = MiqUUID.mac_address.dup
        end
      rescue
      end

      return [ipaddr, hostname, mac_address]
    end

    def validate_database
      log_prefix = "MIQ(MiqServer.validate_database)"

      ActiveRecord::Base.connection.reconnect!

      # Log the Versions
      $log.info "#{log_prefix} Database Adapter: [#{ActiveRecord::Base.connection.adapter_name}], version: [#{ActiveRecord::Base.connection.database_version}]"                   if ActiveRecord::Base.connection.respond_to?(:database_version)
      $log.info "#{log_prefix} Database Adapter: [#{ActiveRecord::Base.connection.adapter_name}], detailed version: [#{ActiveRecord::Base.connection.detailed_database_version}]" if ActiveRecord::Base.connection.respond_to?(:detailed_database_version)
    end

    def start_memcached(cfg = VMDB::Config.new('vmdb'))
      #TODO: Need to periodically check the memcached instance to see if it's up, and bounce it and notify the UiWorkers to re-connect
      return unless cfg.config.fetch_path(:server, :session_store).to_s == 'cache'
      return unless MiqEnvironment::Command.supports_memcached?
      require "#{Rails.root}/lib/miq_memcached" unless Object.const_defined?(:MiqMemcached)
      svr, port = cfg.config.fetch_path(:session, :memcache_server).to_s.split(":")
      opts = cfg.config.fetch_path(:session, :memcache_server_opts).to_s
      MiqMemcached::Control.restart!(:port => port, :options => opts)
      $log.info("MIQ(#{self.name}.start_memcached) Status: #{MiqMemcached::Control.status[1]}")
    end

    def prep_apache_proxying
      return unless MiqEnvironment::Command.supports_apache?

      MiqApache::Control.kill_all
      MiqUiWorker.install_apache_proxy_config
      MiqWebServiceWorker.install_apache_proxy_config
    end

  end

  #
  # Apache
  #
  def queue_restart_apache
    MiqQueue.put_unless_exists(
      :class_name  => 'MiqServer',
      :instance_id => self.id,
      :method_name => 'restart_apache',
      :queue_name  => 'miq_server',
      :zone        => self.zone.name,
      :server_guid => self.guid
    ) do |msg|
      $log.info("MIQ(#{self.class.name}.queue_restart_apache) Server: [#{self.id}] [#{self.name}], there is already a prior request to restart apache, skipping...") unless msg.nil?
    end
  end

  def restart_apache
    MiqApache::Control.restart(false)
  end

  def check_disk_usage(disks)
    @vmdb_config = VMDB::Config.new("vmdb")
    threshold = @vmdb_config.config.fetch_path(:server, :events, :disk_usage_gt_percent) || 80

    disks.each do |disk|
      if disk[:used_bytes_percent].to_i > threshold
        disk_usage_event = case disk[:mount_point].chomp
        when '/'                                            then 'evm_server_system_disk_high_usage'
        when '/var/www/miq'                                 then 'evm_server_app_disk_high_usage'
        when '/var/www/miq/vmdb/log'                        then 'evm_server_log_disk_high_usage'
        when '/opt/rh/postgresql92/root/var/lib/pgsql/data' then 'evm_server_db_disk_high_usage'
        end

        next unless disk_usage_event
        msg = "Filesystem: #{disk[:filesystem]} (#{disk[:type]}) on #{disk[:mount_point]} is #{disk[:used_bytes_percent]}% full with #{ActionView::Base.new.number_to_human_size(disk[:available_bytes])} free."
        MiqEvent.raise_evm_event_queue(self, disk_usage_event, :event_details => msg)
      end
    end
  end

end
