require 'util/extensions/miq-module'

module MiqServerBaseMethods
  extend ActiveSupport::Concern

  included do
    cattr_accessor          :my_guid_cache

    cache_with_timeout(:my_server) { find_by(:guid => my_guid) }
  end

  module ClassMethods
    #
    # Zone and Role methods
    #
    def my_guid
      my_guid_cache ||= begin
        guid_file = Rails.root.join("GUID")
        File.write(guid_file, SecureRandom.uuid) unless File.exist?(guid_file)
        File.read(guid_file).strip
      end
    end

    def pidfile
      @pidfile ||= Rails.root.join("tmp", "pids", "evm.pid")
    end

    def running?
      p = PidFile.new(pidfile)
      p.running? ? p.pid : false
    end

    def kill
      svr = my_server(true)
      svr.kill unless svr.nil?
      PidFile.new(pidfile).remove
    end

    def stop(sync = false)
      svr = my_server(true) rescue nil
      svr.stop(sync) unless svr.nil?
      PidFile.new(pidfile).remove
    end
  end

  def kill
    # Kill all the workers of this server
    kill_all_workers

    # Then kill this server
    _log.info("initiated for #{format_full_log_msg}")
    update_attributes(:stopped_on => Time.now.utc, :status => "killed", :is_master => false)
    (pid == Process.pid) ? shutdown_and_exit : Process.kill(9, pid)
  end

  def kill_all_workers
    return unless is_local?

    killed_workers = []
    miq_workers.each do |w|
      next unless MiqWorker::STATUSES_CURRENT_OR_STARTING.include?(w.status)

      w.kill
      worker_delete(w.pid)
      killed_workers << w
    end
    miq_workers.delete(*killed_workers) unless killed_workers.empty?
  end

  def stop(sync = false)
    return if stopped?

    shutdown_and_exit_queue
    wait_for_stopped if sync
  end

  def wait_for_stopped
    loop do
      reload
      break if stopped?
      sleep stop_poll
    end
  end

  def is_local?
    guid == MiqServer.my_guid
  end

  def is_remote?
    !is_local?
  end

  def stopped?
    self.class::STATUSES_STOPPED.include?(status)
  end
end
