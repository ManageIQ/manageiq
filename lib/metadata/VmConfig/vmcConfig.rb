$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-xml'
require 'time'

module VmcConfig
	def convert(filename)
		@convertText = ""
		#$log.debug "Processing Windows Configuration file [#{filename}]"
		add_item("displayName", File.basename(filename, ".vmc"))
    xml = MiqXml.loadFile(filename)
    hw_version(xml)
    xml.each_recursive do |e|
      if self.respond_to?(e.name) && e.name.downcase != "id" && e.name.downcase != "type"
        self.send(e.name, e)
      end
    end
    return @convertText
	end

	def ide_controller(element)
		cid, lid = element.attributes['id'], 0
		element.each_recursive { |e|
			lid = e.attributes["id"] if e.name === "location"
			if e.name === "drive_type"
				drive_type = e.text.to_i
				case e.text.to_i
				when 0
					# No disk present here
				when 1
					drive_type = "harddisk"
				when 2
					# Add cd-rom
					add_item("ide#{cid}:#{lid}.present", "TRUE")
					add_item("ide#{cid}:#{lid}.fileName", "auto detect")
					add_item("ide#{cid}:#{lid}.deviceType", "cdrom-raw")
				end
			end

			# Add disk name using the relative path when the disk name exists.
            # Also skip undo disks
			if e.name === "relative" && e.text.nil? == false && e.parent.name != "undo_pathname"
				add_item("ide#{cid}:#{lid}.fileName", e.text.tr("\\", "/"))
				add_item("ide#{cid}:#{lid}.present", "TRUE")
			end
		}
	end

	def ethernet_adapter(element)
		lid = 0
		element.each_recursive { |e|
			lid = e.attributes["id"] if e.name === "ethernet_controller"
			if e.name === "name"
				connType = e.text
				connType = "nat" if connType.nil?
				add_item("Ethernet#{lid}.connectionType", connType)
				add_item("Ethernet#{lid}.present", "TRUE")
			end
			if e.name === "ethernet_card_address"
				x = e.text
				add_item("Ethernet#{lid}.generatedAddress", "%s:%s:%s:%s:%s:%s" % [x[0..1],x[2..3],x[4..5],x[6..7],x[8..9],x[10..11]])
			end
		}		
	end
	
	def ram_size(element)
		add_item("memsize", element.text)
	end
	
	def hw_version(xml)
		add_item("config.version", xml.find_first("//version" ).text)
	end

	def undo_drives(element)
		enabled = element.find_first("./enabled")
		if enabled && enabled.text.downcase == "true"
			# General snapshot details
			# Note: Virtual Server 2005 only supports one snapshot, so this data
			#       is static.  SCVMM will likely cause this to change.
			writeHeader = true
			idx = 0
			Dir.glob(File.join(@configPath, "*.vud")).each do |f| 
				# Only add the snapshot header data if we've found a snapshot file
				if writeHeader
					$log.warn "Writing header"
					add_item("snapshot.numSnapshots", "1")
					add_item("snapshot.current", "1")

					# First snapshot details
					add_item("snapshot0.uid", "1")
					add_item("snapshot0.displayName", "Undo Drives")

					writeHeader = false
        end
				
				add_item("snapshot0.disk#{idx}.filename", File.basename(f))
				begin
					 add_item("snapshot0.create_time", parse_create_time(f).iso8601(6)) if idx==0
				rescue
				end
				idx+=1
			end
		end
	end
	
	def parse_create_time(filename)
		name = File.basename(filename, ".*").split("_")[-1]
		Time.parse("#{name[10..13]}-#{name[6..7]}-#{name[8..9]}T#{name[0..1]}:#{name[2..3]}:#{name[4..5]}").utc
	end

	def add_item(var, value)
		@convertText += "#{var} = \"#{value}\"\n"
	end

  def vendor
    return "microsoft"
  end
end
