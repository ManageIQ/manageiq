$LOAD_PATH << File.expand_path(__dir__)
require 'util/postgres_admin'

require 'mount/miq_generic_mount_session'
require 'util/miq_object_storage'

class EvmDatabaseOps
  include Vmdb::Logging
  BACKUP_TMP_FILE = "/tmp/miq_backup".freeze
  DUMP_TMP_FILE   = "/tmp/miq_pg_dump".freeze

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

  def self.validate_free_space(database_opts)
    free_space = backup_destination_free_space(database_opts[:local_file])
    db_size = database_size(database_opts)
    if free_space > db_size
      _log.info("[#{database_opts[:dbname]}] with database size: [#{db_size} bytes], free space at [#{database_opts[:local_file]}]: [#{free_space} bytes]")
    else
      msg = "Destination location: [#{database_opts[:local_file]}], does not have enough free disk space: [#{free_space} bytes] for database of size: [#{db_size} bytes]"
      _log.warn(msg)
      MiqEvent.raise_evm_event_queue(MiqServer.my_server, "evm_server_db_backup_low_space", :event_details => msg)
      raise MiqException::MiqDatabaseBackupInsufficientSpace, msg
    end
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

    uri = with_file_storage(:backup, db_opts, connect_opts) do |database_opts|
      validate_free_space(database_opts)
      backup_result = PostgresAdmin.backup(database_opts)
      backup_result
    end
    _log.info("[#{merged_db_opts(db_opts)[:dbname]}] database has been backed up to file: [#{uri}]")
    uri
  end

  def self.dump(db_opts, connect_opts = {})
    # db_opts and connect_opts similar to .backup

    uri = with_file_storage(:dump, db_opts, connect_opts) do |database_opts|
      # For database dumps, this isn't going to be as accurate (since the dump
      # size will probably be larger than the calculated BD size), but it still
      # won't hurt to do as a generic way to get a rough idea if we have enough
      # disk space or the appliance for the task.
      validate_free_space(database_opts)
      PostgresAdmin.backup_pg_dump(database_opts)
    end
    _log.info("[#{merged_db_opts(db_opts)[:dbname]}] database has been dumped up to file: [#{uri}]")
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

    uri = with_file_storage(:restore, db_opts, connect_opts) do |database_opts|
      prepare_for_restore(database_opts[:local_file])

      # remove all the connections before we restore; AR will reconnect on the next query
      ActiveRecord::Base.connection_pool.disconnect!
      PostgresAdmin.restore(database_opts)
    end
    _log.info("[#{merged_db_opts(db_opts)[:dbname]}] database has been restored from file: [#{uri}]")
    uri
  end

  private_class_method def self.merged_db_opts(db_opts)
    DEFAULT_OPTS.merge(db_opts)
  end

  STORAGE_ACTIONS_TO_METHODS = { :backup => :add, :dump => :add, :restore => :download }.freeze
  private_class_method def self.with_file_storage(action, db_opts, connect_opts)
    db_opts = merged_db_opts(db_opts)

    if db_opts[:local_file].nil?
      if action == :restore
        uri = connect_opts[:uri]
        connect_opts[:uri] = File.dirname(connect_opts[:uri])
      else
        connect_opts[:remote_file_name] ||= File.basename(backup_file_name(action))
        #
        # If the passed in URI contains query parameters, ignore them
        # when creating the dump file name. They'll be used in the session object.
        #
        uri_parts = [connect_opts[:uri].split('?')[0]]
        uri_parts << (action == :dump ? "db_dump" : "db_backup") unless connect_opts[:skip_directory]
        uri_parts << connect_opts[:remote_file_name]
        uri = File.join(uri_parts)
      end
    else
      uri = db_opts[:local_file]

      # HACK(ish): This just puts the bare minimum necessary for URI.parse to
      # recognize the :uri option as "file" scheme, and allows MiqFileStorage
      # to then instantiate MiqLocalMountSession below in the
      # `.with_interface_class` method.
      connect_opts[:uri] = "file://"
    end

    MiqFileStorage.with_interface_class(connect_opts) do |file_storage|
      send_args = [uri, db_opts[:byte_count]].compact

      # Note:  `input_path` will always be a fifo stream (input coming from
      # PostgresAdmin, and the output going to the `uri`), since we want to
      # maintain the same interface for all backup types.
      #
      # This means that `uri` will always be the final destination, but
      # `input_path` below will be an intermediary fifo that will take the
      # input from `pg_dump`, `pg_restore`, or `pg_basebackup`, and streams the
      # results from those commands (in ruby) it to whatever file storage
      # endpoint `uri` is pointing to.
      #
      # This also makes sure that the streamed output is never written to disk
      # locally, unless `uri` is targeting the local machine.  This is why we
      # set `db_opts` local file to that stream.
      file_storage.send(STORAGE_ACTIONS_TO_METHODS[action], *send_args) do |input_path|
        db_opts[:local_file] = input_path
        yield(db_opts)
      end
    end

    uri
  end

  private_class_method def self.prepare_for_restore(filename)
    backup_type = validate_backup_file_type(filename)

    if application_connections?
      message = "Database restore failed. Shut down all evmserverd processes before attempting a database restore"
      _log.error(message)
      raise message
    end

    MiqRegion.replication_type = :none
    60.times do
      break if VmdbDatabaseConnection.where("application_name LIKE 'pglogical manager%'").count.zero?
      _log.info("Waiting for pglogical connections to close...")
      sleep 5
    end

    connection_count = backup_type == :basebackup ? VmdbDatabaseConnection.unscoped.count : VmdbDatabaseConnection.count
    if connection_count > 1
      message = "Database restore failed. #{connection_count - 1} connections remain to the database."
      _log.error(message)
      raise message
    end
  end

  private_class_method def self.validate_backup_file_type(filename)
    if PostgresAdmin.base_backup_file?(filename)
      :basebackup
    elsif PostgresAdmin.pg_dump_file?(filename)
      :pgdump
    else
      message = "#{filename} is not in a recognized database backup format"
      _log.error(message)
      raise message
    end
  end

  private_class_method def self.application_connections?
    VmdbDatabaseConnection.all.map(&:application_name).any? { |app_name| app_name.start_with?("MIQ") }
  end

  def self.gc(options = {})
    PostgresAdmin.gc(options)
  end

  def self.database_connections(database = nil, type = :all)
    database ||= Rails.configuration.database_configuration[Rails.env]["database"]
    conn = ActiveRecord::Base.connection
    conn.client_connections.count { |c| c["database"] == database }
  end

  def self.upload(connect_opts, local_file, destination_file)
    MiqGenericMountSession.in_depot_session(connect_opts) { |session| session.upload(local_file, destination_file) }
    destination_file
  end

  def self.download(connect_opts, local_file)
    MiqGenericMountSession.in_depot_session(connect_opts) { |session| session.download(local_file, connect_opts[:uri]) }
    local_file
  end

  def self.backup_file_name(action = :backup)
    time_suffix  = Time.now.utc.strftime("%Y%m%d_%H%M%S")
    "#{action == :backup ? BACKUP_TMP_FILE : DUMP_TMP_FILE}_#{time_suffix}"
  end
  private_class_method :backup_file_name
end
