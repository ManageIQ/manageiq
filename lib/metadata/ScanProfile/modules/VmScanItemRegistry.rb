module VmScanItemRegistry
  def to_xml()
    xml = @xml_class.newNode("scan_item")
    xml.add_attributes("guid"=>@params["guid"], "name"=>@params["name"], "item_type"=>@params["item_type"])

    self.scan_definition["content"].each do |d|
      if d[:data]
        xml_partial = xml.root.add_element("registry")
        xml_partial.add_attributes("base_path"=>base_reg_path(d), "id"=>build_reg_path(d))
        xml_partial << d[:data]
      end
    end    
    return xml
  end
  
  def parse_data(vm, data)
    if data
      self.scan_definition["content"].each do |d|
        d[:data] = MIQRexml.findRegElement(build_reg_path(d), data.root) if d[:data].nil?
      end
    end
  end
  
  def build_reg_path(scanHash)
    path = get_long_hive_name(scanHash["hive"]) + "\\" + scanHash["key"]

    # Include the value as part of the search if we have a valid value
    path += "\\" + scanHash["value"] if include_value?(scanHash)

    return path
  end
  
  def base_reg_path(scanHash)
    path = File.join(scanHash["hive"], scanHash["key"])
    path.tr!("/","\\")
    # If we are not processing the value the base path is the hive + key, minus the last path element
    path = path.split("\\")[0..-2].join("\\") unless include_value?(scanHash)
    return path
  end
  
  def include_value?(scanHash)
    # Include the value as part of the search if we have a valid value
    value = scanHash["value"].to_s.strip
    value = "" if value.length == 1 && value[0,1] == "*"
    if !value.blank?
      return true
    else
      return false
    end
  end
  
  def get_long_hive_name(hive)
    case hive
    when "HKLM"
      "HKEY_LOCAL_MACHINE"
    when "HKCU"
      "HKEY_CURRENT_USER"
    when "HKCR"
      "HKEY_CLASSES_ROOT"
    else
      hive
    end
  end
end
