require "spec_helper"

describe Volume do
  context "#volume_group" do
    it "nil when starts with '***physical_'," do
      Volume.new( :volume_group => '***physical_scsi0:0:1' ).volume_group.should be_false
    end

    it "the value when NOT starts with '***physical_'" do
      Volume.new( :volume_group => 'RootVolGroup00' ).volume_group.should == 'RootVolGroup00'
    end
  end

  context "#free_space_percent" do
    it "nil when size == nil" do
      Volume.new( :size => nil ).free_space_percent.should be_false
    end

    it "nil when size == 0" do
      Volume.new( :size => 0 ).free_space_percent.should be_false
    end

    it "nil when free_space == nil" do
      Volume.new( :free_space => nil ).free_space_percent.should be_false
    end

    it "the percentage of free space" do
      Volume.new(:free_space => 40.0, :size => 200.0).free_space_percent.should == 40.0/200.0*100
    end
  end

  context "#used_space_percent" do
    it "nil when size == nil" do
      Volume.new( :size => nil ).used_space_percent.should be_false
    end

    it "nil when size == 0" do
      Volume.new( :size => 0 ).used_space_percent.should be_false
    end

    it "nil when used_space == nil" do
      Volume.new( :used_space => nil ).used_space_percent.should be_false
    end

    it "the percentage of used space" do
      Volume.new(:used_space => 40.0, :size => 200.0).used_space_percent.should == 40.0/200.0*100
    end
  end

  context "#find_disk_by_controller" do
    it "nil when controller NOT like 'scsi0:0:0'" do
      described_class.find_disk_by_controller(mock, 'wrong_format').should be_false
    end

    it "disk_id when controller like 'scsi0:0:0'" do
      parent = disk = mock()
      disk.stub(:find_by_controller_type_and_location).with('scsi', '0:1').and_return('001')
      parent.stub(:hardware => stub(:disks => disk))
      described_class.find_disk_by_controller(parent, 'scsi0:1:1').should == '001'
    end
  end

end
