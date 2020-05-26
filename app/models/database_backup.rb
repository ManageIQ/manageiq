class DatabaseBackup < ApplicationRecord
  SUPPORTED_DEPOTS = {
    'smb'   => 'Samba',
    'nfs'   => 'Network File System',
    's3'    => 'AWS S3',
    'swift' => 'OpenStack Swift'
  }.freeze

  def self.supported_depots
    SUPPORTED_DEPOTS
  end

  def self.backup(options)
    create.backup(options)
  end

  def self.gc(options)
    create.gc(options)
  end

  def backup(options)
    # TODO: Create a real exception out of this
    unless options[:task_id].kind_of?(Integer) && options[:file_depot_id].kind_of?(Integer)
      raise _("Missing or Invalid task: %{task_id}, depot id: %{depot_id}") % {:task_id  => options[:task_id],
                                                                               :depot_id => options[:file_depot_id]}
    end

    task = MiqTask.find(options[:task_id])
    task.update_status("Active", "Ok", "Starting DB Backup for Region: #{region_name}")

    schedule_id = options[:miq_schedule_id]
    @sch = MiqSchedule.find(schedule_id) if schedule_id.kind_of?(Integer)

    options[:userid] ||= "system"

    depot = FileDepot.find_by(:id => options[:file_depot_id])
    _backup(:uri => depot.uri, :username => depot.authentication_userid, :password => depot.authentication_password, :remote_file_name => backup_file_name, :region => depot.aws_region)

    if @sch && @sch.adhoc == true
      _log.info("Removing adhoc schedule: [#{@sch.id}] [#{@sch.name}]")
      @sch.destroy
    end

    task.update_status("Finished", "Ok", "Completed DB Backup for Region: #{region_name}.")
    task.id
  end

  def _backup(options)
    # add the metadata about this backup to this instance: (region, source hostname, db version, md5, status, etc.)

    connect_opts = options.slice(:uri, :username, :password, :region)
    connect_opts[:remote_file_name] = options[:remote_file_name] if options[:remote_file_name]
    EvmDatabaseOps.backup(current_db_opts, connect_opts)
  end

  def gc(options)
    unless options[:task_id].kind_of?(Integer)
      raise _("Missing or Invalid task: %{task_id}") % {:task_id => options[:task_id]}
    end

    task = MiqTask.find(options[:task_id])
    task.update_status("Active", "Ok", "Starting DB GC for Region: #{region_name}")

    options[:userid] ||= "system"

    EvmDatabaseOps.gc(current_db_opts.merge(options))
    task.update_status("Finished", "Ok", "Completed DB GC for Region: #{region_name}.")
    task.id
  end

  def restore(_options)
    # Check PG
  end

  def self.region_name
    "region_#{my_region_number}"
  end

  delegate :region_name, :to => :class

  def schedule_name
    @schedule_name ||= begin
      sch_name = @sch.name.gsub(/[^[:alnum:]]/, "_") if @sch
      sch_name ||= "schedule_unknown"
      sch_name
    end
  end

  def backup_file_name
    File.join(region_name, schedule_name, "#{region_name}_#{Time.now.utc.strftime("%Y%m%d_%H%M%S")}.backup")
  end

  private

  def current_db_opts
    current = ActiveRecord::Base.configurations[Rails.env]
    {
      :hostname => current["host"],
      :dbname   => current["database"],
      :username => current["username"],
      :password => current["password"]
    }
  end
end
