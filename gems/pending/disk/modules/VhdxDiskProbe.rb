# encoding: US-ASCII

require 'Scvmm/miq_hyperv_disk'

VHDX_DISK      = "VhdxDisk"
VHDX_SIGNATURE = "vhdxfile"

module VhdxDiskProbe
  def self.probe(ostruct)
    return nil unless ostruct.fileName
    # If file not VHD then not Microsoft.
    # Allow ".miq" also.
    extended = false
    ext = File.extname(ostruct.fileName).downcase
    extended = true if ext == ".vhdx" || ext == ".avhdx"
    return nil unless extended

    if ostruct.hyperv_connection
      vhdx_disk_file = connect_to_hyperv(ostruct)
    else
      vhdx_disk_file = File.new(ostruct.fileName, "rb")
    end
    rv = do_probe(vhdx_disk_file)
    vhdx_disk_file.close
    rv
  end

  def self.do_probe(io)
    io.seek(0)
    magic = io.read(8)
    return VHDX_DISK if magic == VHDX_SIGNATURE
    nil
  end

  def self.connect_to_hyperv(ostruct)
    connection  = ostruct.hyperv_connection
    network     = ostruct.driveType == "Network"
    hyperv_disk = MiqHyperVDisk.new(connection[:host],
                                    connection[:user],
                                    connection[:password],
                                    connection[:port],
                                    network)
    hyperv_disk.open(ostruct.fileName)
    hyperv_disk
  end
end
