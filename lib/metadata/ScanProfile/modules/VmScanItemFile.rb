module VmScanItemFile
  def to_xml()
    xml = @xml_class.newNode("scan_item")
    xml.add_attributes("guid"=>@params["guid"], "name"=>@params["name"], "item_type"=>@params["item_type"])

    self.scan_definition['stats'].each do |d|
      if d["data"]
        xml_partial = xml.root.add_element("filesystem")
        xml_partial.add_attributes(d["data"].root.attributes)
        xml_partial.add_attribute("id", d["target"])
        e = d["data"].root.elements[1]
        until e.blank?
          xml_partial << e
          e = d["data"].root.elements[1]
        end
      end
    end
    
    return xml
  end

  def parse_data(vm, data, &blk)
    if data.nil?
      st = Time.now
      $log.info "Scanning [Profile-Files] information."
      yield({:msg=>'Scanning Profile-File'}) if block_given?
      self.scan_definition["stats"].each do |d|
        # MD5deep scanning will raise an error if the path does not exist.
        begin
          # Skip if we already have data for this element
          options = {'contents'=>d['content']}
          d["data"] = MD5deep.scan_glob(vm.vmRootTrees[0], d["target"], options) if d["data"].nil?
        rescue
        end
      end
      $log.info "Scanning [Profile-Files] information ran for [#{Time.now-st}] seconds."
    end
  end
end
