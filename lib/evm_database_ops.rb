$LOAD_PATH << File.expand_path(__dir__)
require 'util/postgres_admin'

$LOAD_PATH << File.join(GEMS_PENDING_ROOT, "util/mount")
require 'miq_generic_mount_session'

class EvmDatabaseOps
  include Vmdb::Logging
  BACKUP_TMP_FILE = "/tmp/miq_backup"

  DEFAULT_OPTS = {:dbname => 'vmdb_production'}

  def self.backup_destination_free_space(file_location)
    require 'fileutils'
    parent_directory = File.dirname(file_location)
    FileUtils.mkdir_p(parent_directory)

    free_space = begin
      output = MiqUtil.runcmd("df -P #{parent_directory}")
      data_line = output.split("\n")[1] if output.kind_of?(String)
      data_line.split[3].to_i * 1024 if data_line
    end

    free_space || 0
  end

  def self.database_size(opts)
    PostgresAdmin.database_size(opts)
  end

  def self.backup(db_opts, connect_opts = {})
    # db_opts:
    #   :dbname => 'vmdb_production',
    #   :username => 'root',
    #   :local_file => "/tmp/backup_1",      - Backup locally to the file specified

    # connect_opts:
    #   :uri => "smb://dev005.manageiq.com/share1",
    #   :username => 'samba_one',
    #   :password => 'Zug-drep5s',
    #   :remote_file_name => "backup_1",     - Provide a base file name for the uploaded file

    db_opts = DEFAULT_OPTS.merge(db_opts)

    begin
      if db_opts[:local_file].nil?
        connect_opts[:remote_file_name] ||= File.basename(backup_file_name)

        session = MiqGenericMountSession.new_session(connect_opts)

        uri = File.join(connect_opts[:uri], "db_backup", connect_opts[:remote_file_name])
        db_opts[:local_file] = session.uri_to_local_path(uri)
      end

      free_space = backup_destination_free_space(db_opts[:local_file])
      db_size = database_size(db_opts)
      if free_space > db_size
        _log.info("[#{db_opts[:dbname]}] with database size: [#{db_size} bytes], free space at [#{db_opts[:local_file]}]: [#{free_space} bytes]")
      else
        msg = "Destination location: [#{db_opts[:local_file]}], does not have enough free disk space: [#{free_space} bytes] for database of size: [#{db_size} bytes]"
        _log.warn("#{msg}")
        MiqEvent.raise_evm_event_queue(MiqServer.my_server, "evm_server_db_backup_low_space", :event_details => msg)
        raise MiqException::MiqDatabaseBackupInsufficientSpace, msg
      end
      backup = PostgresAdmin.backup(db_opts)
    ensure
      session.disconnect if session
    end

    uri ||= backup
    _log.info("[#{db_opts[:dbname]}] database has been backed up to file: [#{uri}]")
    uri
  end

  def self.restore(db_opts, connect_opts = {})
    # db_opts:
    #  :local_file => "/tmp/backup_1",          - Restore from this local file
    #  :dbname => 'vmdb_production'
    #  :username => 'root'

    # connect_opts:
    #   :uri => "smb://dev005.manageiq.com/share1/db_backup/miq_pg_backup_20100719_215444",
    #   :username => 'samba_one',
    #   :password => 'Zug-drep5s',

    db_opts = DEFAULT_OPTS.merge(db_opts)

    begin
      if db_opts[:local_file].nil?
        uri = connect_opts[:uri]
        connect_opts[:uri] = File.dirname(connect_opts[:uri])
        session = MiqGenericMountSession.new_session(connect_opts)
        db_opts[:local_file] = session.uri_to_local_path(uri)
      end

      backup = PostgresAdmin.restore(db_opts)
    ensure
      session.disconnect if session
    end

    uri ||= backup
    _log.info("[#{db_opts[:dbname]}] database has been restored from file: [#{uri}]")
    uri
  end

  def self.gc(options = {})
    PostgresAdmin.gc(options)
  end

  def self.database_connections(database = nil, type = :all)
    database ||= Rails.configuration.database_configuration[Rails.env]["database"]
    conn = ActiveRecord::Base.connection
    conn.client_connections.count { |c| c["database"] == database }
  end

  def self.stop
    _log.info("Stopping internal database")
    PostgresAdmin.stop(DEFAULT_OPTS.merge(:graceful => true))
  end

  def self.start
    _log.info("Starting internal database")
    PostgresAdmin.start(DEFAULT_OPTS)
  end

  private

  def self.upload(connect_opts, local_file, destination_file)
    MiqGenericMountSession.in_depot_session(connect_opts) { |session| session.upload(local_file, destination_file) }
    destination_file
  end

  def self.download(connect_opts, local_file)
    MiqGenericMountSession.in_depot_session(connect_opts) { |session| session.download(local_file, connect_opts[:uri]) }
    local_file
  end

  def self.backup_file_name
    time_suffix  = Time.now.utc.strftime("%Y%m%d_%H%M%S")
    "#{BACKUP_TMP_FILE}_#{time_suffix}"
  end
end
