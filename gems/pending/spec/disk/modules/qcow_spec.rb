require 'spec_helper'

require 'ostruct'
require 'disk/MiqDisk'
require 'disk/modules/QcowDisk'
require 'disk/modules/QcowDiskProbe'

describe QcowDisk do
  describe "#read" do
    around do |example|
      Camcorder.use_recording('qcow_read') do
        Camcorder.intercept_d_read
        img       = image_path('qcow2.img')
        disk_info = OpenStruct.new(:fileName => img)
        @disk     = MiqDisk.getDisk(disk_info, "QcowDiskProbe")

        example.run
      end
    end

    it "returns bytes read from disk" do
      res = @disk.read(10)
      expected = Array.new(10) { 0 }.pack('C*')
      res.should ==  expected
    end
  end

  describe "#write" do
    around do |example|
      Camcorder.use_recording('qcow_write') do
        disk_info = OpenStruct.new(:fileName => image_path('qcow2.img'))
        @disk     = MiqDisk.getDisk(disk_info, "QcowDiskProbe")
      end
    end

    it "raises an error" do
      data = Array.new(10) { 0 }
      expect { @disk.write(data, 10) }.to raise_error
    end
  end
end
