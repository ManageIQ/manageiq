# encoding: US-ASCII

require 'Scvmm/miq_hyperv_disk'
require 'disk/modules/MiqLargeFile'
require 'disk/modules/MSCommon'

module MSVSDiskProbe
  MS_MAGIC      = "conectix"

  TYPE_FIXED    = 2
  TYPE_DYNAMIC  = 3
  TYPE_DIFF     = 4

  MOD_FIXED     = "MSVSFixedDisk"
  MOD_DYNAMIC   = "MSVSDynamicDisk"
  MOD_DIFF      = "MSVSDiffDisk"

  def self.probe(ostruct)
    return nil unless ostruct.fileName
    # If file not VHD then not Microsoft.
    # Allow ".miq" also.
    ext = File.extname(ostruct.fileName).downcase
    return nil if ext != ".vhd" && ext != ".avhd" && ext != ".miq"

    if ostruct.hyperv_connection
      ms_disk_file = connect_to_hyperv(ostruct)
    else
      # Get (assumed) footer.
      ms_disk_file = MiqLargeFile.open(ostruct.fileName, "rb")
    end
    footer = MSCommon.getFooter(ms_disk_file, true)
    ms_disk_file.close

    # Check for MS disk.
    return nil if footer['cookie'] != MS_MAGIC

    # Return module name to handle type.
    case footer['disk_type']
    when TYPE_FIXED
      return MOD_FIXED
    when TYPE_DYNAMIC
      return MOD_DYNAMIC
    when TYPE_DIFF
      return MOD_DIFF
    else
      raise "Unsupported MS disk: #{footer['disk_type']}"
    end
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
