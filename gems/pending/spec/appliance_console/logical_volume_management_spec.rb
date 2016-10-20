require 'appliance_console/logical_volume_management'
require 'pathname'
require 'tmpdir'

describe ApplianceConsole::LogicalVolumeManagement do
  before do
    @spec_name = File.basename(__FILE__).split(".rb").first
    @disk_double = double(@spec_name, :path => "/dev/vtest")
    @config = described_class.new(:disk => @disk_double, :mount_point => "/mount_point", :name => "test")
  end

  describe ".new" do
    it "ensures required disk option is provided" do
      expect { described_class.new(:mount_point => "/mount_point", :name => "test") }.to raise_error(ArgumentError)
    end

    it "ensures required mount_point option is provided" do
      expect { described_class.new(:disk => @disk_double, :name => "test") }.to raise_error(ArgumentError)
    end

    it "ensures required name option is provided" do
      expect do
        described_class.new(:disk => @disk_double, :mount_point => "/mount_point")
      end.to raise_error(ArgumentError)
    end

    it "sets derived and default instance variables automatically" do
      expect(@config.volume_group_name).to eq("vg_test")
      expect(@config.filesystem_type).to eq("xfs")
      expect(@config.logical_volume_path).to eq("/dev/vg_test/lv_test")
    end
  end

  describe "#setup" do
    before do
      expect(@disk_double).to receive(:create_partition_table)
      expect(@disk_double).to receive(:partitions).and_return([:fake_partition])
      @config.disk = @disk_double

      @fstab = double(@spec_name)
      allow(@fstab).to receive_messages(:entries => [])
      allow(LinuxAdmin::FSTab).to receive_messages(:instance => @fstab)

      expect(AwesomeSpawn).to receive(:run!).with("parted -s /dev/vtest mkpart primary 0% 100%")
      expect(AwesomeSpawn).to receive(:run!).with("mkfs.#{@config.filesystem_type} /dev/vg_test/lv_test")
      expect(LinuxAdmin::Disk).to receive(:local).and_return([@disk_double])
      expect(LinuxAdmin::PhysicalVolume).to receive(:create).and_return(:fake_physical_volume)
      expect(LinuxAdmin::VolumeGroup).to receive(:create).and_return(:fake_volume_group)
      expect(FileUtils).to_not receive(:rm_rf).with(@config.mount_point)

      @fake_logical_volume = double(@spec_name, :path => "/dev/vg_test/lv_test")
      expect(LinuxAdmin::LogicalVolume).to receive(:create).and_return(@fake_logical_volume)
    end

    after do
      FileUtils.rm_f(@tmp_mount_point)
      FileUtils.rm_f(@config.mount_point)
    end

    it "sets up the logical disk when mount point is not a symbolic link" do
      @tmp_mount_point = @config.mount_point = Pathname.new(Dir.mktmpdir)
      expect(@fstab).to receive(:write!)
      expect(FileUtils).to_not receive(:mkdir_p).with(@config.mount_point)
      expect(AwesomeSpawn).to receive(:run!)
        .with("mount",
              :params => {"-t" => @config.filesystem_type, nil => ["/dev/vg_test/lv_test", @config.mount_point]})

      @config.setup
      expect(@config.partition).to eq(:fake_partition)
      expect(@config.physical_volume).to eq(:fake_physical_volume)
      expect(@config.volume_group).to eq(:fake_volume_group)
      expect(@config.logical_volume).to eq(@fake_logical_volume)
      expect(@fstab.entries.count).to eq(1)
    end

    it "recreates the new mount point and sets up the logical disk when mount point is a symbolic link" do
      @tmp_mount_point = Pathname.new(Dir.mktmpdir)
      @config.mount_point = Pathname.new("#{Dir.tmpdir}/#{@spec_name}")
      FileUtils.ln_s(@tmp_mount_point, @config.mount_point)
      expect(@fstab).to receive(:write!)

      expect(FileUtils).to receive(:rm_rf).with(@config.mount_point)
      expect(FileUtils).to receive(:mkdir_p).with(@config.mount_point)
      expect(FileUtils).to_not receive(:mkdir_p).with(@config.mount_point)
      expect(AwesomeSpawn).to receive(:run!)
        .with("mount",
              :params => {"-t" => @config.filesystem_type, nil => ["/dev/vg_test/lv_test", @config.mount_point]})
      @config.setup
      expect(@config.partition).to eq(:fake_partition)
      expect(@config.physical_volume).to eq(:fake_physical_volume)
      expect(@config.volume_group).to eq(:fake_volume_group)
      expect(@config.logical_volume).to eq(@fake_logical_volume)
      expect(@fstab.entries.count).to eq(1)
    end

    it "skips update if mount point is in fstab when mount point is in already fstab" do
      @tmp_mount_point = @config.mount_point = Pathname.new(Dir.mktmpdir)
      expect(FileUtils).to_not receive(:mkdir_p).with(@config.mount_point)
      expect(AwesomeSpawn).to receive(:run!)
        .with("mount",
              :params => {"-t" => @config.filesystem_type, nil => ["/dev/vg_test/lv_test", @config.mount_point]})
      allow(@fstab).to receive_messages(:entries => [double(@spec_name, :mount_point => @config.mount_point)])
      expect(@fstab).to receive(:write!).never
      allow(LinuxAdmin::FSTab).to receive_messages(:instance => @fstab)

      @config.setup

      expect(@config.partition).to eq(:fake_partition)
      expect(@config.physical_volume).to eq(:fake_physical_volume)
      expect(@config.volume_group).to eq(:fake_volume_group)
      expect(@config.logical_volume).to eq(@fake_logical_volume)
      expect(@fstab.entries.count).to eq(1)
    end
  end
end
