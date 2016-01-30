require 'metadata/ScanProfile/ScanProfilesBase'
require 'metadata/ScanProfile/HostScanProfile'
require 'metadata/ScanProfile/HostScanItem'

class HostScanProfiles < ScanProfilesBase
  SCAN_TYPE_HOSTD = 'nteventlog'
  SCAN_TYPE_FILE = 'file'

  def get_hostd_scan_item
    scan_item = nil
    each_scan_item(SCAN_TYPE_HOSTD) do |si|
      next unless si.scan_definition['content'][0][:name] == 'hostd'
      scan_item = si
      break
    end
    scan_item
  end

  def get_file_scan_item
    scan_item = nil
    each_scan_item(SCAN_TYPE_FILE) do |si|
      scan_item = si
      break
    end
    scan_item
  end

  def parse_data_hostd(vim)
    si = get_hostd_scan_item
    return if si.nil?
    si.parse_data(vim, nil)
    si.scan_definition[:data]
  end

  def parse_data_files(ssu)
    si = get_file_scan_item
    return if si.nil?
    si.parse_data(ssu, nil)
    si.scan_definition[:data]
  end
end
