require 'linux_admin'

module MiqServer::EnvironmentManagement
  extend ActiveSupport::Concern

  module ClassMethods
    def get_network_information
      ipaddr = hostname = mac_address = nil
      begin
        if MiqEnvironment::Command.is_appliance?
          eth0 = LinuxAdmin::NetworkInterface.new("eth0")

          ipaddr      = eth0.address || eth0.address6
          hostname    = LinuxAdmin::Hosts.new.hostname
          mac_address = eth0.mac_address
        else
          ipaddr      = MiqEnvironment.local_ip_address
          hostname    = MiqEnvironment.fully_qualified_domain_name
          mac_address = UUIDTools::UUID.mac_address.dup
        end
      rescue
      end

      [ipaddr, hostname, mac_address]
    end

    def start_memcached
      # TODO: Need to periodically check the memcached instance to see if it's up, and bounce it and notify the UiWorkers to re-connect
      return unless ::Settings.server.session_store.to_s == 'cache'
      return unless MiqEnvironment::Command.supports_memcached?
      require "#{Rails.root}/lib/miq_memcached" unless Object.const_defined?(:MiqMemcached)
      _svr, port = MiqMemcached.server_address.to_s.split(":")
      opts = ::Settings.session.memcache_server_opts.to_s
      MiqMemcached::Control.restart!(:port => port, :options => opts)
      _log.info("Status: #{MiqMemcached::Control.status[1]}")
    end
  end

  #
  # Apache
  #
  def start_apache
    return unless MiqEnvironment::Command.is_appliance?

    MiqApache::Control.start
  end

  def stop_apache
    return unless MiqEnvironment::Command.is_appliance?

    MiqApache::Control.stop
  end

  def disk_usage_threshold
    ::Settings.server.events.disk_usage_gt_percent
  end

  def check_disk_usage(disks)
    threshold = disk_usage_threshold

    disks.each do |disk|
      next unless disk[:used_bytes_percent].to_i > threshold
      disk_usage_event = case disk[:mount_point].chomp
                         when '/'                     then 'evm_server_system_disk_high_usage'
                         when '/boot'                 then 'evm_server_boot_disk_high_usage'
                         when '/home'                 then 'evm_server_home_disk_high_usage'
                         when '/var'                  then 'evm_server_var_disk_high_usage'
                         when '/var/log'              then 'evm_server_var_log_disk_high_usage'
                         when '/var/log/audit'        then 'evm_server_var_log_audit_disk_high_usage'
                         when '/var/www/miq/vmdb/log' then 'evm_server_log_disk_high_usage'
                         when '/var/www/miq_tmp'      then 'evm_server_miq_tmp_disk_high_usage'
                         when '/tmp'                  then 'evm_server_tmp_disk_high_usage'
                         when %r{lib/pgsql}           then 'evm_server_db_disk_high_usage'
                         end

      next unless disk_usage_event
      msg = "Filesystem: #{disk[:filesystem]} (#{disk[:type]}) on #{disk[:mount_point]} is #{disk[:used_bytes_percent]}% full with #{ActionView::Base.new.number_to_human_size(disk[:available_bytes])} free."
      MiqEvent.raise_evm_event_queue(self, disk_usage_event, :event_details => msg)
    end
  end
end
