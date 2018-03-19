describe "PartitionAlignment" do
  context "Running test" do
    before do
      aligned = 64.kilobytes
      not_aligned = 1

      @vm1 = FactoryGirl.create(:vm_vmware, :name => "VM 1 Aligned",     :hardware => FactoryGirl.create(:hardware))
      FactoryGirl.create(:disk,
                         :device_type => "floppy",
                         :hardware_id => @vm1.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "cdrom-raw",
                         :hardware_id => @vm1.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :disk_type   => "rdm-raw",
                         :hardware_id => @vm1.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :hardware_id => @vm1.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :hardware_id => @vm1.hardware.id,
                         :partitions  => [
                           FactoryGirl.create(:partition, :start_address => aligned),
                           FactoryGirl.create(:partition, :start_address => aligned)
                         ]
                        )

      @vm2 = FactoryGirl.create(:vm_vmware, :name => "VM 2 Not Aligned", :hardware => FactoryGirl.create(:hardware))
      FactoryGirl.create(:disk,
                         :device_type => "floppy",
                         :hardware_id => @vm2.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "cdrom-raw",
                         :hardware_id => @vm2.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :disk_type   => "rdm-raw",
                         :hardware_id => @vm2.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :hardware_id => @vm2.hardware.id,
                         :partitions  => [FactoryGirl.create(:partition, :start_address => not_aligned)]
                        )
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :hardware_id => @vm2.hardware.id,
                         :partitions  => [
                           FactoryGirl.create(:partition, :start_address => aligned),
                           FactoryGirl.create(:partition, :start_address => not_aligned)
                         ]
                        )

      @vm3 = FactoryGirl.create(:vm_vmware, :name => "VM 3 Unknown", :hardware => FactoryGirl.create(:hardware))

      @vm4 = FactoryGirl.create(:vm_vmware, :name => "VM 4 Unknown", :hardware => FactoryGirl.create(:hardware))
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :hardware_id => @vm4.hardware.id
                        )

      @vm5 = FactoryGirl.create(:vm_vmware, :name => "VM 4 Unknown", :hardware => FactoryGirl.create(:hardware))
      FactoryGirl.create(:disk,
                         :device_type => "disk",
                         :hardware_id => @vm5.hardware.id,
                         :partitions  => [
                           FactoryGirl.create(:partition, :start_address => aligned),
                           FactoryGirl.create(:partition)
                         ]
                        )
    end

    it "should return True for Vm alignment method" do
      expect(@vm1.disks_aligned).to eq("True")
    end

    it "should return False for Vm alignment method" do
      expect(@vm2.disks_aligned).to eq("False")
    end

    it "should return Unknown for Vm with no disks" do
      expect(@vm3.disks_aligned).to eq("Unknown")
    end

    it "should return Unknown for Vm with disk with no partitions" do
      expect(@vm4.disks_aligned).to eq("Unknown")
    end

    it "should return Unknown for Vm with disk with a partition that has no start_address" do
      expect(@vm5.disks_aligned).to eq("Unknown")
    end
  end
end
