require 'ostruct'
require 'disk/MiqDisk'
require 'disk/modules/RawDisk'

describe RawDisk do
  it "#read" do
    Camcorder.use_recording('rawdisk_read') do
      Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :read
      Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

      disk_info = OpenStruct.new(:fileName => image_path('basic.img'))
      disk      = MiqDisk.getDisk(disk_info, "RawDiskProbe")
      expect(disk.read(10)).to eq("\0\0\0\0\0\0\0\0\0\0")
    end
  end

  it "#write" do
    Camcorder.use_recording('rawdisk_write') do
      Camcorder.intercept MiqLargeFile::MiqLargeFileOther, :seek, :write
      Camcorder.intercept MiqLargeFile::MiqLargeFileStat,  :blockdev?

      disk_info = OpenStruct.new(:fileName  => image_path('basic.img'),
                                 :mountMode => 'rw')
      disk      = MiqDisk.getDisk(disk_info, "RawDiskProbe")
      data      = Array.new(10) { 0 }
      expect(disk.write(data, 10)).to eq(30)
    end
  end
end
