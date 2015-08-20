require "appliance_console/database_configuration"
require "appliance_console/service_group"
require "pathname"
require "util/postgres_admin"

RAILS_ROOT ||= Pathname.new(__dir__).join("../../../")

module ApplianceConsole
  class InternalDatabaseConfiguration < DatabaseConfiguration
    attr_accessor :disk
    attr_accessor :ssl

    def self.postgres_dir
      PostgresAdmin.data_directory.relative_path_from(Pathname.new("/"))
    end

    def self.postgresql_sample
      RAILS_ROOT.join("../system/COPY").join(postgres_dir)
    end

    def self.postgresql_template
      RAILS_ROOT.join("../system/TEMPLATE").join(postgres_dir)
    end

    def initialize(hash = {})
      set_defaults
      super
    end

    def set_defaults
      self.host     = "127.0.0.1"
      self.username = "root"
      self.database = "vmdb_production"
    end

    def activate
      initialize_postgresql_disk if disk
      initialize_postgresql
      super
    end

    def ask_questions
      choose_disk
      # TODO: Assume we want to create a region for a new internal database disk
      # until we allow for the internal selection against an already initialized disk.
      create_new_region_questions(false)
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
        prep_database_mount_point
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

      copy_template "postgresql.conf.erb", self.class.postgresql_template
      copy_template "pg_hba.conf.erb",     self.class.postgresql_template
      copy_template "pg_ident.conf"
    end

    def post_activation
      ServiceGroup.new(:internal_postgresql => true).restart_services
    end

    private

    def copy_template(src, src_dir = self.class.postgresql_sample, dest_dir = PostgresAdmin.data_directory)
      full_src = src_dir.join(src)
      if src.include?(".erb")
        full_dest = dest_dir.join(src.gsub(".erb", ""))
        File.open(full_dest, "w") { |f| f.puts ERB.new(File.read(full_src), nil, '-').result(binding) }
      else
        FileUtils.cp full_src, dest_dir
      end
    end

    def create_partition_to_fill_disk
      #FIXME when LinuxAdmin has this feature
      @disk.create_partition_table # LinuxAdmin::Disk.create_partition has this already...
      LinuxAdmin.run!("parted -s #{@disk.path} mkpart primary 0% 100%")

      #FIXME: Refetch the disk after creating the partition
      @disk = LinuxAdmin::Disk.local.select {|d| d.path == @disk.path}.first
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
      LinuxAdmin.run!("mkfs.#{PostgresAdmin.database_disk_filesystem} #{@logical_volume.path}")
    end

    def mount_database_disk
      #TODO: should this be moved into LinuxAdmin?
      FileUtils.rm_rf(PostgresAdmin.data_directory)
      FileUtils.mkdir_p(PostgresAdmin.data_directory)
      LinuxAdmin.run!("mount", :params => {"-t" => PostgresAdmin.database_disk_filesystem, nil => [@logical_volume.path, PostgresAdmin.data_directory]})
    end

    def update_fstab
      fstab = LinuxAdmin::FSTab.instance
      return if fstab.entries.find {|e| e.mount_point == PostgresAdmin.data_directory}

      entry = LinuxAdmin::FSTabEntry.new(
        :device        => @logical_volume.path,
        :mount_point   => PostgresAdmin.data_directory,
        :fs_type       => PostgresAdmin.database_disk_filesystem,
        :mount_options => "rw,noatime",
        :dumpable      => 0,
        :fsck_order    => 0
      )

      fstab.entries << entry
      fstab.write!  # Test this more, whitespace is removed
    end

    def prep_database_mount_point
      # initdb will fail if the database directory is not empty or not owned by the PostgresAdmin.user
      FileUtils.chown_R(PostgresAdmin.user, PostgresAdmin.user, PostgresAdmin.data_directory)
      FileUtils.rm_rf(PostgresAdmin.data_directory.join("pg_log"))
      FileUtils.rm_rf(PostgresAdmin.data_directory.join("lost+found"))
    end

    def run_initdb
      LinuxAdmin.run!("service", :params => { nil => [PostgresAdmin.service_name, "initdb"]})
    end

    def start_postgres
      LinuxAdmin::Service.new(PostgresAdmin.service_name).start
      block_until_postgres_accepts_connections
    end

    def block_until_postgres_accepts_connections
      loop do
        break if run_as_postgres("psql -c 'select 1';").exit_status == 0
      end
    end

    def create_postgres_root_user
      run_as_postgres("psql -c 'CREATE ROLE #{username} WITH LOGIN CREATEDB SUPERUSER PASSWORD '\\'#{password}\\';")
    end

    def create_postgres_database
      run_as_postgres("createdb -E utf8 -O #{username} #{database}")
    end

    # some overlap with PostgresAdmin
    def run_as_postgres(cmd)
      AwesomeSpawn.run("su", :params => {"-" => nil, nil => "postgres", "-c" => "#{PostgresAdmin.scl_enable_prefix} \"#{cmd}\""})
    end

    def relabel_postgresql_dir
      LinuxAdmin.run!("/sbin/restorecon -R -v #{PostgresAdmin.data_directory}")
    end
  end
end
