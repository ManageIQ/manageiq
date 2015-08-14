require "appliance_console/database_configuration"
require "appliance_console/service_group"

module ApplianceConsole
  class InternalDatabaseConfiguration < DatabaseConfiguration
    DATABASE_DISK_FILESYSTEM_TYPE = "xfs".freeze
    POSTGRES_USER                 = "postgres".freeze
    POSTGRES_DIR                  = "opt/rh/postgresql92/root/var/lib/pgsql/data".freeze
    DATABASE_DISK_MOUNT_POINT     = Pathname.new("/").join(POSTGRES_DIR).freeze
    VOLUME_GROUP_NAME             = "vg_data".freeze
    LOGICAL_VOLUME_NAME           = "lv_pg".freeze
    LOGICAL_VOLUME_PATH           = Pathname.new("/dev").join(VOLUME_GROUP_NAME, LOGICAL_VOLUME_NAME).freeze
    SCL_ENABLE_PREFIX             = "scl enable postgresql92".freeze
    CERT_LOCATION                 = Pathname.new("/var/www/miq/vmdb/certs").freeze
    POSTGRESQL_SAMPLE             = Pathname.new("/var/www/miq/system/COPY/").join(POSTGRES_DIR).freeze
    POSTGRESQL_TEMPLATE           = Pathname.new("/var/www/miq/system/TEMPLATE/").join(POSTGRES_DIR).freeze
    POSTGRESQL_SERVICE            = "postgresql92-postgresql".freeze
    attr_accessor :disk
    attr_accessor :ssl

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
      self.ssl = File.exist?(CERT_LOCATION.join("postgres.key"))

      copy_template "postgresql.conf.erb", POSTGRESQL_TEMPLATE
      copy_template "pg_hba.conf.erb",     POSTGRESQL_TEMPLATE
      copy_template "pg_ident.conf"
    end

    def post_activation
      ServiceGroup.new(:internal_postgresql => true).restart_services
    end

    private

    def copy_template(src, src_dir = POSTGRESQL_SAMPLE, dest_dir = DATABASE_DISK_MOUNT_POINT)
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
      LinuxAdmin::VolumeGroup.create(VOLUME_GROUP_NAME, @physical_volume)
    end

    def create_logical_volume_to_fill_volume_group
      LinuxAdmin::LogicalVolume.create(LOGICAL_VOLUME_PATH, @volume_group, 100)
    end

    def format_logical_volume
      # LogicalVolume#format_to(:ext4) should be a thing
      # LogicalVolume#fs_type => :ext4 should be a thing
      LinuxAdmin.run!("mkfs.#{DATABASE_DISK_FILESYSTEM_TYPE} #{@logical_volume.path}")
    end

    def mount_database_disk
      #TODO: should this be moved into LinuxAdmin?
      FileUtils.rm_rf(DATABASE_DISK_MOUNT_POINT)
      FileUtils.mkdir_p(DATABASE_DISK_MOUNT_POINT)
      LinuxAdmin.run!("mount", :params => {"-t" => DATABASE_DISK_FILESYSTEM_TYPE, nil => [@logical_volume.path, DATABASE_DISK_MOUNT_POINT]})
    end

    def update_fstab
      fstab = LinuxAdmin::FSTab.instance
      return if fstab.entries.find {|e| e.mount_point == DATABASE_DISK_MOUNT_POINT}

      entry = LinuxAdmin::FSTabEntry.new(
        :device        => @logical_volume.path,
        :mount_point   => DATABASE_DISK_MOUNT_POINT,
        :fs_type       => DATABASE_DISK_FILESYSTEM_TYPE,
        :mount_options => "rw,noatime",
        :dumpable      => 0,
        :fsck_order    => 0
      )

      fstab.entries << entry
      fstab.write!  # Test this more, whitespace is removed
    end

    def prep_database_mount_point
      # initdb will fail if the database directory is not empty or not owned by the POSTGRES_USER
      FileUtils.chown_R(POSTGRES_USER, POSTGRES_USER, DATABASE_DISK_MOUNT_POINT)
      FileUtils.rm_rf(DATABASE_DISK_MOUNT_POINT.join("pg_log"))
      FileUtils.rm_rf(DATABASE_DISK_MOUNT_POINT.join("lost+found"))
    end

    def run_initdb
      LinuxAdmin.run!("service", :params => { nil => [POSTGRESQL_SERVICE, "initdb"]})
    end

    def start_postgres
      LinuxAdmin::Service.new(POSTGRESQL_SERVICE).start
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

    # some overlap with MiqPostgresAdmin
    def run_as_postgres(cmd)
      AwesomeSpawn.run("su", :params => {"-" => nil, nil => "postgres", "-c" => "#{SCL_ENABLE_PREFIX} \"#{cmd}\""})
    end

    def relabel_postgresql_dir
      LinuxAdmin.run!("/sbin/restorecon -R -v #{DATABASE_DISK_MOUNT_POINT}")
    end
  end
end
