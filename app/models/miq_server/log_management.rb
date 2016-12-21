require 'util/postgres_admin'

module MiqServer::LogManagement
  extend ActiveSupport::Concern

  included do
    belongs_to :log_file_depot, :class_name => "FileDepot"
    has_many   :log_files, :dependent => :destroy, :as => :resource
  end

  def format_log_time(time)
    time.respond_to?(:strftime) ? time.strftime("%Y%m%d_%H%M%S") : "unknown"
  end

  def post_historical_logs(taskid, log_depot)
    task = MiqTask.find(taskid)
    resource = who_am_i

    # Post all compressed logs for a specific date + configs, creating a new row per day
    VMDB::Util.compressed_log_patterns.each do |pattern|
      evm = VMDB::Util.get_evm_log_for_date(pattern)
      next if evm.nil?

      log_start, log_end = VMDB::Util.get_log_start_end_times(evm)
      date = File.basename(pattern).gsub!(/\*|\.gz/, "")

      date_string = "#{format_log_time(log_start)} #{format_log_time(log_end)}" unless log_start.nil? && log_end.nil?
      date_string ||= date
      name = "Archived #{self.name} logs #{date_string} "
      desc = "Logs for Zone #{zone.name rescue nil} Server #{self.name} #{date_string}"

      cond = {:historical => true, :name => name, :state => 'available'}
      cond[:logging_started_on] = log_start unless log_start.nil?
      cond[:logging_ended_on] = log_end unless log_end.nil?
      logfile = log_files.find_by(cond)
      if logfile && logfile.log_uri.nil?
        _log.info("Historical logfile already exists with id: [#{logfile.id}] for [#{resource}] dated: [#{date}] with contents from: [#{log_start}] to: [#{log_end}]")
        next
      else
        logfile = LogFile.historical_logfile
      end

      msg = "Creating historical Logfile for [#{resource}] dated: [#{date}] from: [#{log_start}] to [#{log_end}]"
      task.update_status("Active", "Ok", msg)
      _log.info(msg)

      begin
        log_files << logfile
        save
        msg = "Zipping and posting historical logs and configs on #{resource}"
        task.update_status("Active", "Ok", msg)
        _log.info(msg)

        patterns = [pattern]
        cfg_pattern = ::Settings.log.collection.archive.pattern
        patterns += cfg_pattern if cfg_pattern.kind_of?(Array)

        local_file = VMDB::Util.zip_logs("evm_server_daily.zip", patterns, "admin")

        logfile.update_attributes(
          :file_depot         => log_depot,
          :local_file         => local_file,
          :logging_started_on => log_start,
          :logging_ended_on   => log_end,
          :name               => name,
          :description        => desc,
          :miq_task_id        => task.id
        )

        logfile.upload
      rescue StandardError, Timeout::Error => err
        logfile.update_attributes(:state => "error")
        _log.error("Posting of historical logs failed for #{resource} due to error: [#{err.class.name}] [#{err}]")
        raise
      end

      msg = "Historical log files from #{resource} for #{date} are posted"
      task.update_status("Active", "Ok", msg)
      _log.info(msg)

      # TODO: If the gz has been posted and the gz is more than X days old, delete it
    end
  end

  def _post_my_logs(options)
    # Make the request to the MiqServer whose logs are needed
    MiqQueue.put_or_update(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "post_logs",
      :server_guid => guid,
      :zone        => my_zone,
    ) do |msg, item|
      _log.info("Previous adhoc log collection is still running, skipping...Resource: [#{self.class.name}], id: [#{id}]") unless msg.nil?
      item.merge(
        :miq_callback => options.delete(:callback),
        :msg_timeout  => options.delete(:timeout),
        :priority     => MiqQueue::HIGH_PRIORITY,
        :args         => [options])
    end
  end

  def synchronize_logs(*args)
    options = args.extract_options!
    args << self unless args.last.kind_of?(self.class)
    LogFile.logs_from_server(*args, options)
  end

  def last_log_sync_on
    log_files.maximum(:updated_on)
  end

  def last_log_sync_message
    last_log = log_files.order(:updated_on => :desc).first
    last_log.try(:miq_task).try!(:message)
  end

  def post_logs(options)
    taskid = options[:taskid]
    task = MiqTask.find(taskid)
    context_log_depot = log_depot(options[:context])

    # the current queue item and task must be errored out on exceptions so re-raise any caught errors
    raise _("Log depot settings not configured") unless context_log_depot
    context_log_depot.update_attributes(:support_case => options[:support_case].presence)

    post_historical_logs(taskid, context_log_depot) unless options[:only_current]
    post_current_logs(taskid, context_log_depot)
    task.update_status("Finished", "Ok", "Log files were successfully collected")
  end

  def current_log_patterns
    # use an array union to add pg log path patterns if not already there
    ::Settings.log.collection.current.pattern | pg_log_patterns
  end

  def pg_data_dir
    PostgresAdmin.data_directory
  end

  def pg_log_patterns
    pg_data = pg_data_dir
    return [] unless pg_data

    pg_data = Pathname.new(pg_data)
    [pg_data.join("*.conf"), pg_data.join("pg_log/*")]
  end

  def post_current_logs(taskid, log_depot)
    resource = who_am_i
    task = MiqTask.find(taskid)

    delete_old_requested_logs
    logfile = LogFile.current_logfile
    logfile.update_attributes(:miq_task_id => taskid)
    begin
      log_files << logfile
      save

      log_prefix = "Task: [#{task.id}]"
      msg = "Posting logs for: #{resource}"
      _log.info("#{log_prefix} #{msg}")
      task.update_status("Active", "Ok", msg)

      msg = "Zipping and posting current logs and configs on #{resource}"
      _log.info("#{log_prefix} #{msg}")
      task.update_status("Active", "Ok", msg)

      local_file = VMDB::Util.zip_logs("evm.zip", current_log_patterns, "system")

      evm = VMDB::Util.get_evm_log_for_date("log/*.log")
      log_start, log_end = VMDB::Util.get_log_start_end_times(evm)

      date_string = "#{format_log_time(log_start)} #{format_log_time(log_end)}" unless log_start.nil? && log_end.nil?
      name = "Requested #{self.name} logs #{date_string} "
      desc = "Logs for Zone #{zone.name rescue nil} Server #{self.name} #{date_string}"

      logfile.update_attributes(
        :file_depot         => log_depot,
        :local_file         => local_file,
        :logging_started_on => log_start,
        :logging_ended_on   => log_end,
        :name               => name,
        :description        => desc,
      )

      logfile.upload
    rescue StandardError, Timeout::Error => err
      _log.error("#{log_prefix} Posting of current logs failed for #{resource} due to error: [#{err.class.name}] [#{err}]")
      logfile.update_attributes(:state => "error")
      raise
    end
    msg = "Current log files from #{resource} are posted"
    _log.info("#{log_prefix} #{msg}")
    task.update_status("Active", "Ok", msg)
  end

  def delete_old_requested_logs
    log_files.where(:historical => false).destroy_all
  end

  def delete_active_log_collections_queue
    MiqQueue.put_or_update(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "delete_active_log_collections",
      :server_guid => guid
    ) do |msg, item|
      _log.info("Previous cleanup is still running, skipping...") unless msg.nil?
      item.merge(:priority => MiqQueue::HIGH_PRIORITY)
    end
  end

  def delete_active_log_collections
    log_files.each do |lf|
      if lf.state == 'collecting'
        _log.info("Deleting #{lf.description}")
        lf.miq_task.update_attributes(:state => 'Finished', :status => 'Error', :message => 'Log Collection Incomplete during Server Startup') unless lf.miq_task.nil?
        lf.destroy
      end
    end

    # Since a task is created before a logfile, there's a chance we have a task without a logfile
    MiqTask.where(:miq_server_id => id).where("name like ?", "Zipped log retrieval for %").where("state != ?", "Finished").each do |task|
      task.update_attributes(:state => 'Finished', :status => 'Error', :message => 'Log Collection Incomplete during Server Startup')
    end
  end

  def log_collection_active_recently?(since = nil)
    since ||= 15.minutes.ago.utc
    return true if log_files.exists?(["created_on > ? AND state = ?", since, "collecting"])
    MiqTask.exists?(["miq_server_id = ? and name like ? and state != ? and created_on > ?", id, "Zipped log retrieval for %", "Finished", since])
  end

  def log_collection_active?
    return true if log_files.exists?(:state => "collecting")
    MiqTask.exists?(["miq_server_id = ? and name like ? and state != ?", id, "Zipped log retrieval for %", "Finished"])
  end

  def log_depot(context)
    context == "Zone" ? zone.log_file_depot : log_file_depot
  end

  def base_zip_log_name
    t = Time.now.utc.strftime('%FT%H_%M_%SZ'.freeze)
    # Name the file based on GUID and time.  GUID and Date/time of the request are as close to unique filename as we're going to get
    "App-#{guid}-#{t}"
  end
end
