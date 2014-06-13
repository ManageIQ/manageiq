require 'ScanProfilesBase'
require 'HostScanProfile'
require 'HostScanItem'

class HostScanProfiles < ScanProfilesBase
  SCAN_TYPE_HOSTD = 'nteventlog'
  SCAN_TYPE_FILE = 'file'

  def get_hostd_scan_item
    scan_item = nil
    self.each_scan_item(SCAN_TYPE_HOSTD) do |si|
      next unless si.scan_definition['content'][0][:name] == 'hostd'
      scan_item = si
      break
    end
    return scan_item
  end

  def get_file_scan_item
    scan_item = nil
    self.each_scan_item(SCAN_TYPE_FILE) do |si|
      scan_item = si
      break
    end
    return scan_item
  end

  def parse_data_hostd(vim)
    si = self.get_hostd_scan_item
    return if si.nil?
    si.parse_data(vim, nil)
    return si.scan_definition[:data]
  end

  def parse_data_files(ssu)
    si = self.get_file_scan_item
    return if si.nil?
    si.parse_data(ssu, nil)
    return si.scan_definition[:data]
  end
end
