module MiqServer::LogManagement
  extend ActiveSupport::Concern

  included do
    belongs_to :log_file_depot, :class_name => "FileDepot"
    has_many   :log_files, :dependent => :destroy, :as => :resource
  end

  def sync_log_level
    Vmdb::Logging.apply_config(@vmdb_config.config[:log])
  end

  def format_log_time(time)
    return time.respond_to?(:strftime) ? time.strftime("%Y%m%d_%H%M%S") : "unknown"
  end

  def post_historical_logs(taskid)
    task = MiqTask.find(taskid)
    resource = who_am_i

    # Post all compressed logs for a specific date + configs, creating a new row per day
    log_prefix = "MIQ(#{self.class.name}.post_historical_logs)"

    VMDB::Util.compressed_log_patterns.each do |pattern|
      evm = VMDB::Util.get_evm_log_for_date(pattern)
      next if evm.nil?

      log_start, log_end = VMDB::Util.get_log_start_end_times(evm)
      date = File.basename(pattern).gsub!(/\*|\.gz/,"")

      date_string = "#{format_log_time(log_start)} #{format_log_time(log_end)}" unless log_start.nil? && log_end.nil?
      date_string ||= date
      name = "Archived #{self.name} logs #{date_string} "
      desc = "Logs for Zone #{self.zone.name rescue nil} Server #{self.name} #{date_string}"

      cond = {:historical => true, :name => name, :state => 'available'}
      cond[:logging_started_on] = log_start unless log_start.nil?
      cond[:logging_ended_on] = log_end unless log_end.nil?
      logfile = self.log_files.where(cond).first
      if logfile && logfile.log_uri.nil?
        $log.info("#{log_prefix} Historical logfile already exists with id: [#{logfile.id}] for [#{resource}] dated: [#{date}] with contents from: [#{log_start}] to: [#{log_end}]")
        next
      else
        logfile = LogFile.historical_logfile
      end

      msg = "Creating historical Logfile for [#{resource}] dated: [#{date}] from: [#{log_start}] to [#{log_end}]"
      task.update_status("Active", "Ok", msg)
      $log.info("#{log_prefix} #{msg}")

      begin
        self.log_files << logfile
        self.save
        msg = "Zipping and posting historical logs and configs on #{resource}"
        task.update_status("Active", "Ok", msg)
        $log.info("#{log_prefix} #{msg}")

        patterns = [pattern]
        cfg_pattern = get_config("vmdb").config.fetch_path(:log, :collection, :archive, :pattern)
        patterns += cfg_pattern if cfg_pattern.is_a?(Array)

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
      rescue StandardError, TimeoutError => err
        logfile.update_attributes(:state => "error" )
        $log.error("#{log_prefix} Posting of historical logs failed for #{resource} due to error: [#{err.class.name}] [#{err}]")
        raise
      end

      msg = "Historical log files from #{resource} for #{date} are posted"
      task.update_status("Active", "Ok", msg)
      $log.info("#{log_prefix} #{msg}")

      #TODO: If the gz has been posted and the gz is more than X days old, delete it
    end
  end

  def _post_my_logs(options)
    # Make the request to the MiqServer whose logs are needed
    MiqQueue.put_or_update(
      :class_name => self.class.name,
      :instance_id => self.id,
      :method_name => "post_logs",
      :server_guid => self.guid,
      :zone => self.my_zone,
    ) do |msg, item|
      $log.info("MIQ(MiqServer-_post_my_logs) Previous adhoc log collection is still running, skipping...Resource: [#{self.class.name}], id: [#{self.id}]") unless msg.nil?
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
    rec = LogFile.where(:resource_type => self.class.name, :resource_id => self.id).order("updated_on DESC").select("updated_on").first
    return rec.nil? ? nil : rec.updated_on
  end

  def last_log_sync_message
    last_log = LogFile.where(:resource_type => self.class.name, :resource_id => self.id).order("updated_on DESC").first
    return nil if last_log.nil? || last_log.miq_task.nil?
    return last_log.miq_task.message
  end

  def post_logs(options)
    taskid = options[:taskid]
    task = MiqTask.find(taskid)

    # the current queue item and task must be errored out on exceptions so re-raise any caught errors
    raise "Log depot settings not configured" unless log_depot
    log_depot.update_attributes(:support_case => options[:support_case].presence)

    self.post_historical_logs(taskid) unless options[:only_current]
    self.post_current_logs(taskid)
    task.update_status("Finished", "Ok", "Log files were successfully collected")
  end

  def post_current_logs(taskid)
    resource = who_am_i
    task = MiqTask.find(taskid)

    self.delete_old_requested_logs
    logfile = LogFile.current_logfile
    begin
      self.log_files << logfile
      self.save

      log_prefix = "MIQ(#{self.class.name}.post_current_logs) Task: [#{task.id}]"
      msg = "Posting logs for: #{resource}"
      $log.info("#{log_prefix} #{msg}")
      task.update_status("Active", "Ok", msg)

      base = base_zip_log_name + ".zip"

      msg = "Zipping and posting current logs and configs on #{resource}"
      $log.info("#{log_prefix} #{msg}")
      task.update_status("Active", "Ok", msg)

      patterns = []
      cfg_pattern = get_config("vmdb").config.fetch_path(:log, :collection, :current, :pattern)
      patterns += cfg_pattern if cfg_pattern.is_a?(Array)

      local_file = VMDB::Util.zip_logs("evm.zip", patterns, "system")

      evm = VMDB::Util.get_evm_log_for_date("log/*.log")
      log_start, log_end = VMDB::Util.get_log_start_end_times(evm)

      date_string = "#{format_log_time(log_start)} #{format_log_time(log_end)}" unless log_start.nil? && log_end.nil?
      name = "Requested #{self.name} logs #{date_string} "
      desc = "Logs for Zone #{self.zone.name rescue nil} Server #{self.name} #{date_string}"

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
    rescue StandardError, TimeoutError => err
      $log.error("#{log_prefix} Posting of current logs failed for #{resource} due to error: [#{err.class.name}] [#{err}]")
      logfile.update_attributes(:state => "error")
      raise
    end
    msg = "Current log files from #{resource} are posted"
    $log.info("#{log_prefix} #{msg}")
    task.update_status("Active", "Ok", msg)
  end

  def delete_old_requested_logs
    LogFile.destroy_all(:historical => false, :resource_id => self.id, :resource_type => self.class.name)
  end

  def delete_active_log_collections_queue
    MiqQueue.put_or_update(
      :class_name => self.class.name,
      :instance_id => self.id,
      :method_name => "delete_active_log_collections",
      :server_guid => self.guid
    ) do |msg, item|
      $log.info("MIQ(MiqServer.delete_active_log_collections_queue) Previous cleanup is still running, skipping...") unless msg.nil?
      item.merge(:priority => MiqQueue::HIGH_PRIORITY)
    end
  end

  def delete_active_log_collections
    self.log_files.each do |lf|
      if lf.state == 'collecting'
        $log.info("MIQ(MiqServer.delete_active_log_collections) Deleting #{lf.description}")
        lf.miq_task.update_attributes(:state => 'Finished', :status => 'Error', :message => 'Log Collection Incomplete during Server Startup') unless lf.miq_task.nil?
        lf.destroy
      end
    end

    # Since a task is created before a logfile, there's a chance we have a task without a logfile
    MiqTask.find(:all, :conditions => ["miq_server_id = ? and name like ? and state != ?", self.id, "Zipped log retrieval for %", "Finished"]).each do |task|
      task.update_attributes(:state => 'Finished', :status => 'Error', :message => 'Log Collection Incomplete during Server Startup')
    end
  end

  def log_collection_active_recently?(since = nil)
    since ||= 15.minutes.ago.utc
    return true if self.log_files.exists?(["created_on > ? AND state = ?", since, "collecting"])
    return MiqTask.exists?(["miq_server_id = ? and name like ? and state != ? and created_on > ?", self.id, "Zipped log retrieval for %", "Finished", since])
  end

  def log_collection_active?
    return true if self.log_files.exists?(:state => "collecting")
    return MiqTask.exists?(["miq_server_id = ? and name like ? and state != ?", self.id, "Zipped log retrieval for %", "Finished"])
  end

  def log_depot
    log_file_depot || zone.log_file_depot
  end

  def base_zip_log_name
    t = Time.now.utc.iso8601
    # Name the file based on GUID and time.  GUID and Date/time of the request are as close to unique filename as we're going to get
    %Q/App-#{self.guid}-#{t}/.gsub!(/:|\./,"_")
  end
end
