require 'spec_helper'

require 'ostruct'
require 'disk/MiqDisk'
require 'disk/modules/RhevmDescriptor'

describe RhevmDescriptor do
  describe "#read" do
    around do |example|
      Camcorder.use_recording('rhevm_read') do
        Camcorder.intercept_d_read
        disk_info = OpenStruct.new(:fileName => image_path('manageiq-ovirt-anand-1'),
                                   :format   => 'raw')
        @disk     = MiqDisk.getDisk(disk_info, "RhevmDiskProbe")

        example.run
      end
    end

    it "returns bytes read from disk" do
      res = @disk.read(10)
      expected = [31, 139, 8, 8, 183, 11, 253, 83, 2, 255]
      res.bytes.should == expected
    end
  end

  describe "#write" do
    around do |example|
      Camcorder.use_recording('rhevm_write') do
        Camcorder.intercept_d_write
        disk_info = OpenStruct.new(:fileName => image_path('manageiq-ovirt-anand-1'),
                                   :format   => 'raw', :mountMode => 'rw')
        @disk     = MiqDisk.getDisk(disk_info, "RhevmDiskProbe")

        example.run
      end
    end

    it "writes bytes to disk" do
      res = @disk.write(Array.new(10) { 0 }, 10)
      res.should == 30
    end
  end
end
