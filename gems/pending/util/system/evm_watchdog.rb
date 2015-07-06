# May need this to clean up the db check and require active record
# ENV['BUNDLE_GEMFILE'] = '/var/www/miq/vmdb/Gemfile'
# require 'bundler/setup'

require 'time'

module EvmWatchdog
  PID_LOCATION = '/var/www/miq/vmdb/tmp/pids/evm.pid'.freeze
  def self.check_evm
    pid_file = self.read_pid_file(PID_LOCATION)
    pid_ps = self.get_ps_pids('evm_server.rb')
    if pid_file.nil?
      # EVM exited gracefully - no pid file, nothing to do.
      # Future TODO - Check database to see if EVM should be started?
    elsif pid_file.empty? # Not really sure how we got an empty pid file, but we'll just log it for now.
      self.log_info("Detected an empty PID file for EVM Server Process.")
    elsif pid_file.include? "no_db"
      db_state = self.get_db_state #TODO - This is here because it is costly.  Should be moved up when not as costly.
      if db_state.empty?
        # Database down, nothing to do but wait for it to come up.
      else
        self.log_info("Detected that the database is now available.")
        self.start_evm
      end
    elsif pid_file.to_i == 0
      self.log_info("Detected non-numeric PID file contents: #{pid_file}")
    elsif pid_ps.include?(pid_file.to_i)
      # If the list of pids in ps includes the pid in the file, EVM is running normally
    else
      db_state = self.get_db_state #TODO - See note above.
      if db_state.empty?
        self.log_info("Detected that the database is down.")
      elsif ["started", "starting"].include?(db_state)
        self.log_info("Detected that the EVM Server with PID [#{pid_file.to_i}] is no longer running.")
        self.start_evm
      else # Not sure why we have a pid file here, maybe we should remove it?
        self.log_info("Detected a PID file: [#{pid_file}], but server state should be: [#{db_state}]...")
      end
    end
  end

  def self.read_pid_file(path_or_io)
    fd = if path_or_io.respond_to?(:gets)
      path_or_io.read
    else
      return unless File.exist?(path_or_io)
      File.read(path_or_io)
    end
    fd.chomp.strip
  end

  def self.get_ps_pids(process_name)
    pids = self.ps_for_process(process_name)
    pids.chomp.split.map(&:to_i)
  end

  def self.ps_for_process(process_name)
    `ps -ef --no-heading | grep #{process_name} | awk '{print $2}'`
  end

  def self.get_db_state
    # TODO: This is not a good way to do this.  Can't require evm_application directly because of dependencies, need a better way to test db connections.
    db_state = `cd /var/www/miq/vmdb; bin/rails r "require './lib/tasks/evm_application'; puts EvmApplication.server_state"`
    db_state.chomp.strip
  end

  def self.start_evm
    self.log_info("Starting EVM server...")
    `/etc/init.d/evmserverd start`
  end

  def self.log_info(message)
    File.open('/var/www/miq/vmdb/log/evm.log','a') do |f|
      f.puts "[----] I, [#{Time.now.utc.iso8601(6)} ##{Process.pid}:#{Thread.current.object_id.to_s(16)}]  INFO -- : EvmWatchdog - #{message}"
    end
  end

  def self.kill_pid(pid)
    `kill #{pid}`
  end

  def self.kill_other_watchdogs
    watchdogs = self.get_ps_pids('evm_watchdog.rb')
    watchdogs.each do |process|
      self.kill_pid(process) unless process == Process.pid
    end
  end
end
