require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. lib})))
require "appliance_console/internal_database_configuration"

describe ApplianceConsole::InternalDatabaseConfiguration do
  before do
    MiqPassword.key_root = "#{LIB_ROOT}/spec/support/"
    @config = described_class.new
  end

  after do
    MiqPassword.key_root = nil
  end

  context ".new" do
    it "set defaults automatically" do
      @config.host.should == "127.0.0.1"
      @config.username.should ==  "root"
      @config.database.should ==  "vmdb_production"
    end
  end

  context "postgresql service" do
    it "#start_postgres (private)" do
      LinuxAdmin::Service.any_instance.should_receive(:start)
      @config.should_receive(:block_until_postgres_accepts_connections)
      @config.send(:start_postgres)
    end
  end

  it "#choose_disk" do
    @config.should_receive(:ask_for_disk)
    @config.choose_disk
  end

  it "#post_activation" do
    LinuxAdmin.stub(:run).with("chkconfig", :params => {"--add" => "miqtop"})
    LinuxAdmin::Service.stub(:new => double.as_null_object)
    ApplianceConsole::ServiceGroup.any_instance.stub(:start_command)
    LinuxAdmin::Service.should_receive(:new).with(ApplianceConsole::POSTGRESQL_SERVICE).and_return(double(:enable => true))
    @config.post_activation
  end

  it "#create_partition_to_fill_disk (private)" do
    disk_double = double(:path => "/dev/vdb")
    disk_double.should_receive(:create_partition_table)
    disk_double.should_receive(:partitions).and_return(["fake partition"])
    LinuxAdmin.should_receive(:run!).with("parted -s /dev/vdb mkpart primary 0% 100%")
    LinuxAdmin::Disk.should_receive(:local).and_return([disk_double])

    @config.instance_variable_set(:@disk, disk_double)
    @config.send(:create_partition_to_fill_disk).should == "fake partition"
  end

  context "#update_fstab (private)" do
    it "adds database disk entry" do
      fstab = double
      fstab.stub(:entries => [])
      fstab.should_receive(:write!)
      LinuxAdmin::FSTab.stub(:instance => fstab)
      @config.instance_variable_set(:@logical_volume, double(:path => "/dev/vg/lv"))
      fstab.entries.count.should == 0

      @config.send(:update_fstab)
      fstab.entries.count.should == 1
      fstab.entries.first.device.should == "/dev/vg/lv"
    end

    it "skips update if mount point is in fstab" do
      fstab = double
      fstab.stub(:entries => [double(:mount_point => described_class::DATABASE_DISK_MOUNT_POINT)])
      fstab.should_receive(:write!).never
      LinuxAdmin::FSTab.stub(:instance => fstab)
      fstab.entries.count.should == 1

      @config.send(:update_fstab)
      fstab.entries.count.should == 1
    end
  end
end
