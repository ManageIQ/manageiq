module Manageiq
  class BlackBox
    METADATA_CONFIG_FILE = "/metadata/xmldata.yml"

    def saveXmlData(xml, filename, options={})
      filename.downcase!
      options = {:saveDiff=>true}.merge(options)

      xml.root.add_attribute("original_filename", filename)
      scanTime = xml.root.attributes['created_on']
      scanTime ||= xml.root.attributes[:created_on]
      scanTime = scanTime.to_s
      path = getXmlFileName(filename, scanTime)

      xml_prev = nil
      xml_prev = getLastXmlFile(filename) if options[:saveDiff]

      xml = xml.to_xml if xml.kind_of?(Hash)  # XmlHash
      if xml.kind_of?(Hash)  # XmlHash
        writeData(path, xml.to_xml.to_s)
        #TODO: Change to store xml ask Marshal dump file
        #path = get_dump_name(path)
        #data = Marshal.dump(xml)
        #File.open(path, "wb") {|f| f.write(data)}
      else
        writeData(path, xml.to_s)
      end
      addConfigFile(filename, scanTime)

      XmlDiffAndStore(filename, xml, xml_prev) if xml_prev
    end

    def get_dump_name(filename)
      filepath = File.join(File.dirname(filename), "#{File.basename(filename, '.*')}.dmp")
      filepath.gsub!('\\','/')
      return filepath
    end

    def loadXmlData(filename, ost=nil)
      # Make sure we have a valid openstruct handle and "from_time" is in a valid format
      ost = OpenStruct.new() if ost.nil?
      # Check 'from_time' value and possible remove from the open struct
      validate_from_time(ost)
      ret = OpenStruct.new(:items_selected=>0, :items_total=>0)

      ret.xml = MiqXml.createDoc("<vmmetadata/>")
      ret.xml.root.add_attributes({"original_filename"=>filename, "from_time"=>ost.from_time.to_s, "taskid"=>ost.taskid})
      if filename == "vmevents"
        # Change the name of the root element so the data does not go through state data processing.
        ret.xml.root.name = "vmevents"
        #ret.xml.root << @mk.view("events").find_range_by_hash(ost.from_time.nil? ? nil : {:timestamp=>ost.from_time}).to_xml.root
      else
        @xmlData.each do |x|
          if x[:docs].include?(filename.downcase)
            unless ret.last_scan
              ret.last_scan = x[:time]
            else
              ret.last_diff_scan = x[:time] unless ret.last_diff_scan
            end
            ret.items_total += 1

            # if we have a "from time" make sure we do not include anything older
            next if ost.from_time && ost.from_time.to_i > x[:time].to_i

            # load the xml and check what kind of xml we have (full or diff)
            xmlNode = getXmlFile(filename, x[:time])
            next if xmlNode.nil?
            xmlNode = xmlNode.root

            xml_type = getXmlType(xmlNode)

            # If we have a "from_time" we are not sending full scans
            next if ost.from_time && xml_type == "full"

            # Create a new "item" element for the xml and record the scan type
            e = ret.xml.root.add_element("item", {"scanType"=>xml_type})
            e << xmlNode
            # Keep count of the number of items we add
            ret.items_selected += 1
          end
        end
      end
      ret.xml.root.add_attributes({"items_selected"=>ret.items_selected, "items_total"=>ret.items_total,
                  "last_scan"=>ret.last_scan, "last_diff_scan"=>ret.last_diff_scan})
      return ret
    end

    private

    def XmlDiffAndStore(filename, xml, xml_prev)
      # Make sure we are processing to xml files in the proper order
      if xml.root.attributes['created_on'] > xml_prev.root.attributes['created_on']
        xml.extendXmlDiff
        delta = xml.xmlDiff(xml_prev)
        delta.root.add_attribute("original_filename", filename)
        path = getXmlFileName(filename, xml_prev.root.attributes['created_on'])
        writeData(path, delta.to_s)
      end
    end

    def addConfigFile(filename, time)
      item = findXmlConfigItem(time)
      if item.nil?
        # prepend new object to array
        @xmlData.unshift({:time=>time, :docs=>[filename]})
        saveXmlConfig()
      else
        # Update existing array item
        unless item[:docs].include?(filename)
          item[:docs] << filename
          saveXmlConfig()
        end
      end
    end

    def findXmlConfigItem(time)
      item = nil
      @xmlData.each {|x|
        if x[:time] == time
          item = x
          break
        end
      }
      return item
    end

    def loadXmlConfig
      begin
        data = readData(METADATA_CONFIG_FILE)
        eval(data)
      rescue
        []
      end
    end

    def saveXmlConfig()
      writeData(METADATA_CONFIG_FILE, @xmlData.inspect)
    end

    def getLastXmlFile(filename)
      item = nil
      # This is a sorted list with the newest items on top
      @xmlData.each {|x|
        if x[:docs].include?(filename)
          item = x
          break
        end
      }
      return nil if item.nil?

      xml = getXmlFile(filename, item[:time])
      return nil if xml.nil?

      type = getXmlType(xml)
      return nil if type == "diff"
      return xml
    end

    def getXmlFile(filename, time)
      begin
        MiqXml.load(readData(getXmlFileName(filename, time)))
      rescue
        # Return nil if we fail to read the xml file
        nil
      end
    end

    def getXmlFileName(filename, time)
      timestr = time.to_s
      File.join("/metadata", "#{timestr[0..7]}.#{timestr[8..11]}", filename + ".xml")
    end

    def getXmlType(xml)
      return "diff" if xml.root.name.downcase == "xmldiff"
      return "full"
    end

    def validate_from_time(ost)
      if ost.from_time
        # Delete the "from_time" field if there is no time passed on there is no blackbox
        ost.delete_field("from_time") if (ost.from_time.strip.empty? || !self.exist?)

        # If there is only one data collection time and it does not match the "from_time"
        # remove the value so we send what we have.
        ost.delete_field("from_time") if (ost.from_time && @xmlData.length==1 && @xmlData[0][:time] != ost.from_time)
      end
    end
  end
end
