require 'metadata/ScanProfile/ScanProfilesBase'
require 'metadata/ScanProfile/VmScanProfile'
require 'metadata/ScanProfile/VmScanItem'

class VmScanProfiles < ScanProfilesBase
  SCAN_TYPE_CATEGORY = "category"
  SCAN_TYPE_REGISTRY = "registry"

  SCAN_ITEM_CATEGORIES = "categories"

  def get_categories
    categories = []
    # Get data from each "category" scan item
    each_scan_definition(SCAN_TYPE_CATEGORY) do |sd|
      # Add the target items from the content array
      sd["content"].each { |si| categories << si["target"] } unless sd["content"].nil?
    end
    if categories.empty?
      categories = @options[SCAN_ITEM_CATEGORIES].split(",") if @options[SCAN_ITEM_CATEGORIES]
    end
    categories.each do |c|
      c.delete!("\"")
      c.strip!
    end
    categories << "profiles"
    categories.uniq
  end

  def get_registry_filters
    reg_filters = Hash.new { |h, k| h[k] = [] }
    each_scan_definition(SCAN_TYPE_REGISTRY) do |sd|
      # Add the target items from the content array and
      # split the registry request into hive/key
      sd["content"].each { |si| reg_filters[si["hive"].to_sym] << si }
    end
    reg_filters
  end
end
