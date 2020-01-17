RSpec.describe Volume do
  context "#volume_group" do
    it "nil when starts with '***physical_'," do
      expect(Volume.new(:volume_group => '***physical_scsi0:0:1').volume_group).to be_falsey
    end

    it "the value when NOT starts with '***physical_'" do
      expect(Volume.new(:volume_group => 'RootVolGroup00').volume_group).to eq('RootVolGroup00')
    end
  end

  context "#free_space_percent" do
    it "nil when size == nil" do
      expect(Volume.new(:size => nil).free_space_percent).to be_falsey
    end

    it "nil when size == 0" do
      expect(Volume.new(:size => 0).free_space_percent).to be_falsey
    end

    it "nil when free_space == nil" do
      expect(Volume.new(:free_space => nil).free_space_percent).to be_falsey
    end

    it "the percentage of free space" do
      expect(Volume.new(:free_space => 40.0, :size => 200.0).free_space_percent).to eq(40.0 / 200.0 * 100)
    end
  end

  context "#used_space_percent" do
    it "nil when size == nil" do
      expect(Volume.new(:size => nil).used_space_percent).to be_falsey
    end

    it "nil when size == 0" do
      expect(Volume.new(:size => 0).used_space_percent).to be_falsey
    end

    it "nil when used_space == nil" do
      expect(Volume.new(:used_space => nil).used_space_percent).to be_falsey
    end

    it "the percentage of used space" do
      expect(Volume.new(:used_space => 40.0, :size => 200.0).used_space_percent).to eq(40.0 / 200.0 * 100)
    end
  end

  context "#find_disk_by_controller" do
    it "nil when controller NOT like 'scsi0:0:0'" do
      expect(described_class.find_disk_by_controller(double, 'wrong_format')).to be_falsey
    end

    it "disk_id when controller like 'scsi0:0:0'" do
      parent = disk = double
      allow(disk).to receive(:find_by).with(:controller_type => 'scsi', :location => '0:1').and_return('001')
      allow(parent).to receive_messages(:hardware => double(:disks => disk))
      expect(described_class.find_disk_by_controller(parent, 'scsi0:1:1')).to eq('001')
    end
  end
end
