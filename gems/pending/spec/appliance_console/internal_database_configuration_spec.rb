require "appliance_console/internal_database_configuration"

describe ApplianceConsole::InternalDatabaseConfiguration do
  before do
    @old_key_root = MiqPassword.key_root
    MiqPassword.key_root = File.join(GEMS_PENDING_ROOT, "spec/support")
    @config = described_class.new
  end

  after do
    MiqPassword.key_root = @old_key_root
  end

  context ".new" do
    it "set defaults automatically" do
      expect(@config.host).to eq("127.0.0.1")
      expect(@config.username).to eq("root")
      expect(@config.database).to eq("vmdb_production")
      expect(@config.run_as_evm_server).to be true
    end
  end

  context "postgresql service" do
    it "#start_postgres (private)" do
      allow(LinuxAdmin::Service).to receive(:new).and_return(double(:service).as_null_object)
      allow(PostgresAdmin).to receive_messages(:service_name => 'postgresql')
      expect(@config).to receive(:block_until_postgres_accepts_connections)
      @config.send(:start_postgres)
    end
  end

  it "#choose_disk" do
    expect(@config).to receive(:ask_for_disk)
    @config.choose_disk
  end

  it "#create_partition_to_fill_disk (private)" do
    disk_double = double(:path => "/dev/vdb")
    expect(disk_double).to receive(:create_partition_table)
    expect(disk_double).to receive(:partitions).and_return(["fake partition"])
    expect(AwesomeSpawn).to receive(:run!).with("parted -s /dev/vdb mkpart primary 0% 100%")
    expect(LinuxAdmin::Disk).to receive(:local).and_return([disk_double])

    @config.instance_variable_set(:@disk, disk_double)
    expect(@config.send(:create_partition_to_fill_disk)).to eq("fake partition")
  end

  it ".postgresql_template" do
    allow(PostgresAdmin).to receive_messages(:data_directory     => Pathname.new("/var/lib/pgsql/data"))
    allow(PostgresAdmin).to receive_messages(:template_directory => Pathname.new("/opt/manageiq/manageiq-appliance/TEMPLATE"))
    expect(described_class.postgresql_template.to_s).to end_with("TEMPLATE/var/lib/pgsql/data")
  end

  describe "#post_activation" do
    it "doesnt start evm if run_as_evm_server is false" do
      @config.run_as_evm_server = false
      expect(@config).not_to receive(:start_evm)
      @config.post_activation
    end

    it "starts evm if run_as_evm_server is true" do
      @config.run_as_evm_server = true
      expect(@config).to receive(:start_evm)
      @config.post_activation
    end
  end

  context "#update_fstab (private)" do
    before do
      allow(PostgresAdmin).to receive_messages(:data_directory => "/var/lib/pgsql")
    end

    it "adds database disk entry" do
      fstab = double
      allow(fstab).to receive_messages(:entries => [])
      expect(fstab).to receive(:write!)
      allow(LinuxAdmin::FSTab).to receive_messages(:instance => fstab)
      @config.instance_variable_set(:@logical_volume, double(:path => "/dev/vg/lv"))
      expect(fstab.entries.count).to eq(0)

      @config.send(:update_fstab)
      expect(fstab.entries.count).to eq(1)
      expect(fstab.entries.first.device).to eq("/dev/vg/lv")
    end

    it "skips update if mount point is in fstab" do
      fstab = double
      allow(fstab).to receive_messages(:entries => [double(:mount_point => PostgresAdmin.data_directory)])
      expect(fstab).to receive(:write!).never
      allow(LinuxAdmin::FSTab).to receive_messages(:instance => fstab)
      expect(fstab.entries.count).to eq(1)

      @config.send(:update_fstab)
      expect(fstab.entries.count).to eq(1)
    end
  end
end
