class DatabaseBackup < ActiveRecord::Base
  SUPPORTED_DEPOTS = {
    'smb' => 'Samba',
    'nfs' => 'Network File System'
  }.freeze

  def self.backup_supported?
    # We currently only support Postgres via internal/external db
    return @backup_supported unless @backup_supported.nil?
    @backup_supported = MiqDbConfig.current.options[:name] =~ /[in|ex]ternal|postgresql/ ? true : false
  end

  class << self
    alias_method :gc_supported?, :backup_supported?
  end

  def self.supported_depots
    SUPPORTED_DEPOTS
  end

  def self.backup(options)
    self.create.backup(options)
  end

  def backup(options)
    #TODO: Create a real exception out of this
    raise "Unsupported database" unless self.class.backup_supported?
    raise "Missing or Invalid task: #{options[:task_id]}, depot id: #{options[:file_depot_id]}" unless options[:task_id].kind_of?(Integer) && options[:file_depot_id].kind_of?(Integer)

    task = MiqTask.find(options[:task_id])
    task.update_status("Active", "Ok", "Starting DB Backup for Region: #{self.region_name}")

    schedule_id = options[:miq_schedule_id]
    @sch = MiqSchedule.find(schedule_id) if schedule_id.is_a?(Integer)

    options[:userid] ||= "system"

    depot = FileDepot.find_by_id(options[:file_depot_id])
    self._backup(:uri => depot.uri, :username => depot.authentication_userid, :password => depot.authentication_password, :remote_file_name => self.backup_file_name)

    if @sch && @sch.adhoc == true
      $log.info("MIQ(DatabaseBackup.backup) Removing adhoc schedule: [#{@sch.id}] [#{@sch.name}]") if $log
      @sch.destroy
    end

    task.update_status("Finished", "Ok", "Completed DB Backup for Region: #{self.region_name}.")
    task.id
  end

  def _backup(options)
    # add the metadata about this backup to this instance: (region, source hostname, db version, md5, status, etc.)

    current = MiqDbConfig.current.options
    db_opts = {:hostname => current[:host], :dbname => current[:database], :username => current[:username], :password => current[:password] }
    connect_opts = { :uri => options[:uri], :username => options[:username], :password => options[:password] }
    connect_opts[:remote_file_name] = options[:remote_file_name] if options[:remote_file_name]
    EvmDatabaseOps.backup(db_opts, connect_opts)
  end

  def self.gc(options)
    raise "Unsupported database" unless self.gc_supported?
    raise "Missing or Invalid task: #{options[:task_id]}" unless options[:task_id].kind_of?(Integer)

    task = MiqTask.find(options[:task_id])
    task.update_status("Active", "Ok", "Starting DB GC for Region: #{self.region_name}")

    options[:userid] ||= "system"

    self._gc(options)
    task.update_status("Finished", "Ok", "Completed DB GC for Region: #{self.region_name}.")
    task.id
  end

  def self._gc(options)
    current = MiqDbConfig.current.options
    db_opts = {:hostname => current[:host], :dbname => current[:database], :username => current[:username], :password => current[:password] }

    EvmDatabaseOps.gc(db_opts.merge(options))
  end


  def restore(options)
    # Check PG
  end

  def self.region_name
    "region_#{my_region_number}"
  end

  def region_name
    self.class.region_name
  end

  def schedule_name
    @schedule_name ||= begin
      sch_name = @sch.name.gsub(/[^[:alnum:]]/, "_") if @sch
      sch_name ||= "schedule_unknown"
      sch_name
    end
  end

  def backup_file_name
    File.join(self.region_name, self.schedule_name, "#{self.region_name}_#{Time.now.utc.strftime("%Y%m%d_%H%M%S")}.backup")
  end
end
