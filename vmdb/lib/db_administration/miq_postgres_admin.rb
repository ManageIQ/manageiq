require 'awesome_spawn'
class MiqPostgresAdmin
  include Vmdb::Logging

  # From /etc/init.d/postgresql script
  # Installation prefix
  PREFIX='/opt/rh/postgresql92/root/usr'

  # Data directory
  PGDATA="/opt/rh/postgresql92/root/var/lib/pgsql/data"

  # Who to run the postmaster as, usually "postgres".  (NOT "root")
  PGUSER='postgres'

  # What to use to shut down the postmaster
  PGCTL="#{PREFIX}/bin/pg_ctl"

  PGSERVICE = "postgresql92-postgresql".freeze

  def self.database_size(opts)
    result = runcmd("psql", opts, :command => "SELECT pg_database_size('#{opts[:dbname]}');")
    result.match(/^\s+([0-9]+)\n/)[1].to_i
  end

  def self.backup(opts)
    self.before_backup(opts)
    self.backup_pg_compress(opts)
  end

  def self.before_backup(opts)
    #TODO: check disk space
  end

  def self.restore(opts)
    self.before_restore
    self.restore_pg_compress(opts)
  end

  def self.before_restore
    #TODO: Make sure destination DB is empty and not in use?
  end

  def self.backup_compress_with_gzip
    # 1) Use compressed dumps.  You can use your favorite compression program, for example gzip:
    #
    # pg_dump dbname | gzip > filename.gz
  end

  def self.restore_compress_with_zip
    # Reload with:
    #
    # gunzip -c filename.gz | psql dbname
    # or:
    #
    # cat filename.gz | gunzip | psql dbname
  end

  def self.backup_split_by_size
    # 2) Use split. The split command allows you to split the output into pieces that are acceptable in size to the underlying file system. For example, to make chunks of 1 megabyte:
    #
    # pg_dump dbname | split -b 1m - filename
  end

  def self.restore_split_by_size
    # Reload with:
    #
    # cat filename* | psql dbname
  end

  def self.backup_pg_compress(opts)
    # 3)
    # Use pg_dump's custom dump format.  If PostgreSQL was built on a system with
    # the zlib compression library installed, the custom dump format will compress
    # data as it writes it to the output file. This will produce dump file sizes
    # similar to using gzip, but it has the added advantage that tables can be restored
    # selectively. The following command dumps a database using the custom dump format:

    opts = opts.dup
    dbname = opts.delete(:dbname)
    runcmd("pg_dump", opts, :format => "c", :file => opts[:local_file], nil => dbname)
    opts[:local_file]
  end

  def self.recreate_db(opts)
    dbname = opts[:dbname]
    opts = opts.merge(:dbname => 'postgres')
    runcmd("psql", opts, :command => "DROP DATABASE IF EXISTS #{dbname}")
    runcmd("psql", opts,
           :command => "CREATE DATABASE #{dbname} WITH OWNER = #{opts[:username] || 'root'} ENCODING = 'UTF8'")
  end

  def self.restore_pg_compress(opts)
    # -1
    # --single-transaction: Execute the restore as a single transaction (that is, wrap the
    #   emitted commands in BEGIN/COMMIT). This ensures that either all the commands complete
    #   successfully, or no changes are applied. This option implies --exit-on-error.
    # -c
    # --clean
    #   Clean (drop) database objects before recreating them.
    # -C
    # --create
    #   Create the database before restoring into it. (When this option is used, the database
    #   named with -d is used only to issue the initial CREATE DATABASE command. All data
    #   is restored into the database name that appears in the archive.)
    # -e
    # --exit-on-error
    #   Exit if an error is encountered while sending SQL commands to the database. The default is to continue and to display a count of errors at the end of the restoration.
    # -O
    # --no-owner
    #   Do not output commands to set ownership of objects to match the original database.
    #   By default, pg_restore issues ALTER OWNER or SET SESSION AUTHORIZATION statements to
    #   set ownership of created schema elements. These statements will fail unless the initial
    #   connection to the database is made by a superuser (or the same user that owns all of the
    #   objects in the script). With -O, any user name can be used for the initial connection,
    #   and this user will own all the created objects.
    # -a
    # --data-only
    #   Restore only the data, not the schema (data definitions).
    # -U root -h localhost -p 5432

    #`psql -d #{opts[:dbname]} -c "DROP DATABASE #{opts[:dbname]}; CREATE DATABASE #{opts[:dbname]} WITH OWNER = root ENCODING = 'UTF8';"`

    #TODO: In order to restore, we need to drop the database if it exists, and recreate it it blank
    # An alternative is to use the -a option to only restore the data if there is not a migration/schema change
    self.recreate_db(opts)

    runcmd("pg_restore", opts, :verbose => nil, :exit_on_error => nil, nil => opts[:local_file])
    opts[:local_file]
  end

  GC_DEFAULTS = {
    :analyze  => false,
    :full     => false,
    :verbose  => false,
    :table    => nil,
    :dbname => nil,
    :username => nil,
    :reindex  => false
  }

  GC_AGGRESSIVE_DEFAULTS = {
    :analyze  => true,
    :full     => true,
    :verbose  => false,
    :table    => nil,
    :dbname => nil,
    :username => nil,
    :reindex  => true
  }

  def self.gc(options = {})
    options = (options[:aggressive] ? GC_AGGRESSIVE_DEFAULTS : GC_DEFAULTS).merge(options)

    result = self.vacuum(options)
    _log.info("Output... #{result}") if result.to_s.length > 0

    if options[:reindex]
      result = self.reindex(options)
      _log.info("Output... #{result}") if result.to_s.length > 0
    end
  end

  def self.vacuum(opts)
    #TODO: Add a real exception here
    raise "Vacuum requires database" unless opts[:dbname]

    args = {}
    args[:analyze] = nil if opts[:analyze]
    args[:full]    = nil if opts[:full]
    args[:verbose] = nil if opts[:verbose]
    args[:table]   = opts[:table] if opts[:table]
    runcmd("vacuumdb", opts, args)
  end

  def self.reindex(opts)
    args = {}
    args[:table] = opts[:table] if opts[:table]
    runcmd("reindexdb", opts, args)
  end

  # TODO: overlaps with appliance_console/service_group.rb

  def self.start(opts)
    runcmd_with_logging("service #{PGSERVICE} start", opts)
  end

  def self.stop(opts)
    mode = opts[:graceful] == true ? 'smart' : 'fast'
    #su - postgres -c '/usr/local/pgsql/bin/pg_ctl stop -W -D /var/lib/pgsql/data -s -m smart'
    # stop postgres as postgres user
    # -W do not wait until operation completes, ie, don't block the process
    #    while waiting for connections to close if using 'smart'
    # -s do it silently
    # -m smart - quit after all connections have disconnected
    # -m fast  - quit directly with proper shutdown
    cmd = "su - #{PGUSER} -c '#{PGCTL} stop -W -D #{PGDATA} -s -m #{mode}'"
    self.runcmd_with_logging(cmd, opts)
  end

  def self.runcmd(cmd_str, opts, args)
    default_args            = {:no_password => nil}
    default_args[:dbname]   = opts[:dbname]   if opts[:dbname]
    default_args[:username] = opts[:username] if opts[:username]
    default_args[:host]     = opts[:hostname] if opts[:hostname]
    args = default_args.merge(args)

    runcmd_with_logging(cmd_str, opts, args)
  end

  def self.runcmd_with_logging(cmd_str, opts, params = {})
    _log.info("Running command... #{AwesomeSpawn.build_command_line(cmd_str, params)}")
    with_pgpass_file(opts) do
      AwesomeSpawn.run!(cmd_str, :params => params).output
    end
  end

  # NOTE: keeping .pgpass for external databases. typically will not create/use
  PGPASS_FILE = '/root/.pgpass'
  def self.with_pgpass_file(opts)
    pass = <<-PGPASS
*:*:#{opts[:dbname]}:#{opts[:username]}:#{opts[:password]}
*:*:postgres:#{opts[:username]}:#{opts[:password]}
    PGPASS
    File.open(PGPASS_FILE, 0600, "w") { |f| f.write pass } if opts[:password]
    yield
  ensure
    File.delete(PGPASS_FILE) if opts[:password]
  end
end
