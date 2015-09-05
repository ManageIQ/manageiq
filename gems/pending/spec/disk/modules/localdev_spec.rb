require 'spec_helper'

require 'ostruct'
require 'disk/MiqDisk'
require 'disk/modules/LocalDevMod'

describe LocalDevMod do
  describe "#read" do
    around do |example|
      Camcorder.use_recording('localdev_read') do
        Camcorder.intercept RawBlockIO, :seek, :read

        disk_info = OpenStruct.new(:fileName => '/dev/loop0')
        @disk     = MiqDisk.getDisk(disk_info, "LocalDevProbe")

        example.run
      end
    end

    it "returns bytes read from disk" do
      res  = @disk.read(10)
      res.should == Array.new(10) { 0 }.pack('C*')
    end
  end

  describe "#write" do
    around do |example|
      Camcorder.use_recording('localdev_write') do
        Camcorder.intercept RawBlockIO, :seek, :read

        disk_info = OpenStruct.new(:fileName => '/dev/loop0')
        @disk     = MiqDisk.getDisk(disk_info, "LocalDevProbe")

        example.run
      end
    end

    it "raises error" do
      data = Array.new(10) { 0 }
      expect { @disk.write(data, 10) }.to raise_error
    end
  end
end
