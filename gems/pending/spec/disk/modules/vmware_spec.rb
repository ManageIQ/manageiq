require 'spec_helper'

require 'ostruct'
require 'disk/MiqDisk'
require 'disk/modules/VMWareDescriptor'

describe VMWareDescriptor do
  describe "#read" do
    around do |example|
      Camcorder.use_recording('vmware_read') do
        Camcorder.intercept_d_read
        disk_info = OpenStruct.new(:fileName => image_path('rc.vmdk'))
        @disk     = MiqDisk.getDisk(disk_info, "VMWareDiskProbe")

        example.run
      end
    end

    it "returns bytes read from disk"
  end

  describe "#write" do
    around do |example|
      Camcorder.use_recording('vmware_write') do
        Camcorder.intercept_d_write
        disk_info = OpenStruct.new(:fileName => image_path(''),
                                   :mountMode => 'rw')
        @disk     = MiqDisk.getDisk(disk_info, "VMWareDiskProbe")

        example.run
      end
    end

    it "writes bytes to disk"
  end
end
