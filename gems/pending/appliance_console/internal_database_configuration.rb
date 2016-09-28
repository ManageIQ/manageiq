require "appliance_console/database_configuration"
require "pathname"
require "util/postgres_admin"
require "pg"

RAILS_ROOT ||= Pathname.new(__dir__).join("../../../")

module ApplianceConsole
  class InternalDatabaseConfiguration < DatabaseConfiguration
    attr_accessor :disk, :ssl, :run_as_evm_server

    def self.postgres_dir
      PostgresAdmin.data_directory.relative_path_from(Pathname.new("/"))
    end

    def self.postgresql_template
      PostgresAdmin.template_directory.join(postgres_dir)
    end

    def initialize(hash = {})
      set_defaults
      super
    end

    def set_defaults
      self.host              = "127.0.0.1"
      self.username          = "root"
      self.database          = "vmdb_production"
      self.run_as_evm_server = true
    end

    def activate
      if PostgresAdmin.initialized?
        say(<<-EOF.gsub!(/^\s+/, ""))
          An internal database already exists.
          Choose "Reset Internal Database" to reset the existing installation
          EOF
        return false
      end
      initialize_postgresql_disk if disk
      initialize_postgresql
      return super if run_as_evm_server
      true
    end

    def ask_questions
      choose_disk
      self.run_as_evm_server = ask_yn?("Do you also want to use this server as an application server")
      # TODO: Assume we want to create a region for a new internal database disk
      # until we allow for the internal selection against an already initialized disk.
      create_new_region_questions(false) if run_as_evm_server
      ask_for_database_credentials
    end

    def choose_disk
      @disk = ask_for_disk("database disk")
    end

    def initialize_postgresql_disk
      log_and_feedback(__method__) do
        @partition       = create_partition_to_fill_disk
        @physical_volume = create_physical_volume
        @volume_group    = create_volume_group
        @logical_volume  = create_logical_volume_to_fill_volume_group

        format_logical_volume
        mount_database_disk
        update_fstab
      end
    end

    def initialize_postgresql
      log_and_feedback(__method__) do
        prep_data_directory
        run_initdb
        relabel_postgresql_dir
        configure_postgres
        start_postgres
        create_postgres_root_user
        create_postgres_database
      end
    end

    def configure_postgres
      self.ssl = File.exist?(PostgresAdmin.certificate_location.join("postgres.key"))

      copy_template "postgresql.conf.erb"
      copy_template "pg_hba.conf.erb"
      copy_template "pg_ident.conf"
    end

    def post_activation
      start_evm if run_as_evm_server
    end

    private

    def mount_point
      Pathname.new(ENV.fetch("APPLIANCE_PG_MOUNT_POINT"))
    end

    def copy_template(src, src_dir = self.class.postgresql_template, dest_dir = PostgresAdmin.data_directory)
      full_src = src_dir.join(src)
      if src.include?(".erb")
        full_dest = dest_dir.join(src.gsub(".erb", ""))
        File.open(full_dest, "w") { |f| f.puts ERB.new(File.read(full_src), nil, '-').result(binding) }
      else
        FileUtils.cp full_src, dest_dir
      end
    end

    def create_partition_to_fill_disk
      # FIXME: when LinuxAdmin has this feature
      @disk.create_partition_table # LinuxAdmin::Disk.create_partition has this already...
      AwesomeSpawn.run!("parted -s #{@disk.path} mkpart primary 0% 100%")

      # FIXME: Refetch the disk after creating the partition
      @disk = LinuxAdmin::Disk.local.find { |d| d.path == @disk.path }
      @disk.partitions.first
    end

    def create_physical_volume
      LinuxAdmin::PhysicalVolume.create(@partition)
    end

    def create_volume_group
      LinuxAdmin::VolumeGroup.create(PostgresAdmin.volume_group_name, @physical_volume)
    end

    def create_logical_volume_to_fill_volume_group
      LinuxAdmin::LogicalVolume.create(PostgresAdmin.logical_volume_path, @volume_group, 100)
    end

    def format_logical_volume
      # LogicalVolume#format_to(:ext4) should be a thing
      # LogicalVolume#fs_type => :ext4 should be a thing
      AwesomeSpawn.run!("mkfs.#{PostgresAdmin.database_disk_filesystem} #{@logical_volume.path}")
    end

    def mount_database_disk
      # TODO: should this be moved into LinuxAdmin?
      FileUtils.rm_rf(PostgresAdmin.data_directory)
      FileUtils.mkdir_p(PostgresAdmin.data_directory)
      AwesomeSpawn.run!("mount", :params => {"-t" => PostgresAdmin.database_disk_filesystem, nil => [@logical_volume.path, mount_point]})
    end

    def update_fstab
      fstab = LinuxAdmin::FSTab.instance
      return if fstab.entries.find { |e| e.mount_point == mount_point }

      entry = LinuxAdmin::FSTabEntry.new(
        :device        => @logical_volume.path,
        :mount_point   => mount_point,
        :fs_type       => PostgresAdmin.database_disk_filesystem,
        :mount_options => "rw,noatime",
        :dumpable      => 0,
        :fsck_order    => 0
      )

      fstab.entries << entry
      fstab.write!  # Test this more, whitespace is removed
    end

    def prep_data_directory
      # initdb will fail if the database directory is not empty or not owned by the PostgresAdmin.user
      # May need to create the data dir here?
      FileUtils.chown_R(PostgresAdmin.user, PostgresAdmin.user, PostgresAdmin.data_directory)
      FileUtils.rm_rf(PostgresAdmin.data_directory.join("pg_log"))
      FileUtils.rm_rf(PostgresAdmin.data_directory.join("lost+found"))
    end

    def run_initdb
      AwesomeSpawn.run!("service", :params => {nil => [PostgresAdmin.service_name, "initdb"]})
    end

    def start_postgres
      LinuxAdmin::Service.new(PostgresAdmin.service_name).enable.start
      block_until_postgres_accepts_connections
    end

    def block_until_postgres_accepts_connections
      loop do
        break if AwesomeSpawn.run("psql -U postgres -c 'select 1'").success?
      end
    end

    def create_postgres_root_user
      conn = PG.connect(:user => "postgres", :dbname => "postgres")
      esc_pass = conn.escape_string(password)
      conn.exec("CREATE ROLE #{username} WITH LOGIN CREATEDB SUPERUSER PASSWORD '#{esc_pass}'")
    end

    def create_postgres_database
      conn = PG.connect(:user => "postgres", :dbname => "postgres")
      conn.exec("CREATE DATABASE #{database} OWNER #{username} ENCODING 'utf8'")
    end

    def relabel_postgresql_dir
      AwesomeSpawn.run!("/sbin/restorecon -R -v #{mount_point}")
    end
  end
end
