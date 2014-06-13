$:.push("#{File.dirname(__FILE__)}/../../../util")

require 'miq-xml'
require 'digest/md5'
require 'remote-registry'
require 'enumerator'
require 'miq-encode'

class FleeceHives
  def self.collect_hive_data(xmlNode, hiveName, regHnd, xmlCol, fs)
		# SAM hive
		if hiveName.downcase == "sam" then
			scanFor = [
									["SAM", "HKEY_LOCAL_MACHINE\\SAM\\SAM"],
								]
		# SYSTEM hive
		elsif hiveName.downcase == "system"
			# Preprocess some keys by making copies of them so they are not lost during processServices
			scanFor = [
									# The following are used for system category
									["system/network", "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters"],
								]
			scanFor.each {|i| addElement(xmlNode.root, i[0], i[1], xmlCol, true)}
				
			processServices(xmlNode, hiveName, regHnd, xmlCol)

			scanFor = [
									["system/os", "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ComputerName"],
									["system/os", "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment"],
									["system/os", "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\ProductOptions"],
								]
		# SOFTWARE hive
		elsif hiveName.downcase == "software"
			scanFor = [
									# The following are used for the system category
									["system/network", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\NetworkCards"],

									# The following are used for the software category
									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Hotfix"],
#									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Classes\\Installer\\Products"],
                  ["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Installer\\UserData"],
									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall"],
									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\App Paths"],
#									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"],
#									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce"],
#									["software", "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnceEx"],
								]

			# The following are for the system/os category, but I can't remove it for
      #   software because it screws up the product keys, due to the way product
      #   keys are precollected from this key
			eNode = MIQRexml.findElement("system/os", xmlCol.root)
			eNode = eNode.add_element("key", {"keyname" => "CurrentVersion", "fqname" => "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion"})
			currentOS_ele = regHnd.open(HKEY_LOCAL_MACHINE, "SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion")
			currentOS_ele.each_element_with_attribute('name') { |e| eNode << e } unless currentOS_ele.nil?
		end

		scanFor.each {|i| addElement(xmlNode.root, i[0], i[1], xmlCol)} unless scanFor.nil?
      
	  case hiveName.downcase
	  when "software"
		  begin
			  self.postProcessApps(xmlCol, fs)
		  rescue Exception => err
			  $log.warn "Exception during Post-process Applications: [#{err.to_s}]"
		  end
			begin
				self.collectProductKeys(xmlNode.root, xmlCol, regHnd)
			rescue => err
				$log.warn "Exception during Collect Product Keys: [#{err.to_s}]"
			end
	  end
  end

	def self.scanRegistry(c, fs, hives = ["sam", nil, "security", nil, "default", nil, "system", nil, "software", nil])

		xmlCol = MiqXml.createDoc("<miq/>")

		hives.each_slice(2) do |hive, filter|
			regHnd = RemoteRegistry.new(fs)

			$log.debug "Loading registry hive [#{hive}]..."
			xml = regHnd.loadHive(hive, filter)
			$log.debug "Loading registry hive complete."

			#File.open("C:/temp/reg_extract_full_#{c}.xml","w"){|f| xml.write(f,0)}
			
			#Scrap details from this hive
			$log.debug "Fleecing registry data."
			FleeceHives.collect_hive_data(xml, hive, regHnd, xmlCol, fs)
			$log.debug "Fleecing complete."
		end

		#File.open("C:/temp/reg_extract_#{c}.xml","w"){|f| xmlCol.write(f,0)}
		return xmlCol
	end

	def self.DecodeProductKey(product_key)
		begin
			return if product_key.blank? || product_key.length < 67
			y = [];	product_key.split(",")[52..67].each {|b| y << b.hex}
			return MIQEncode.base24Decode(y)
		rescue => err
			$log.error "MIQ(OS-DecodeProductKey): [#{err}]"
		end
	end  
	
  def self.collectProductKeys(xml, xmlCol, regHnd)
		prodKeys = MIQRexml.findElement("software/productkeys", xmlCol.root)
		regHnd.digitalProductKeys.each do |e|
			if e.parent && e.parent.attributes['fqname'] && e.parent.attributes['fqname'].downcase != 'software\\microsoft\\windows nt\\currentversion'
				pk = self.productKeys(e)
				prodKeys << pk if pk
			end        
		end
  end

  def self.productKeys(xmlNode)
		p = xmlNode.parent
		
		newEle = xmlNode.get_path
		t = nil
		newEle.each_recursive {|e1| t = e1}
		
		p.each_element {|e|
			if e.attributes['name'] && e.attributes['name'].downcase.include?("product")
				x = e.shallow_copy
				x.text = e.text
				t << x
			end
		}
    ret = nil
    begin
			ret = newEle.find_first("//*/key[@keyname=\"Microsoft\"]")
			ret = ret.elements[1] if ret
    rescue => e
    end
		return ret
  end

  def self.postProcessApps(xmlCol, fs)
    appPath = MIQRexml.findRegElement("software/App Paths", xmlCol.root)
		return if appPath.nil?
		# The icon sections below will need to be uncommented when we are ready to start
		# implementing application image uploading.
		#iconNode = MIQRexml.findElement("Applications/images", xmlCol.root)
    appPath.each_element {|e|
      e.each_element_with_attribute( 'name', '(Default)', max=1 ) {|e1|
        begin
          fileName = e1.text
          fileName.gsub!("\\", "/")
          fileName = fileName[1..-2] if fileName[0,1] == "\"" && fileName[-1,1] == "\""
          
#          $log.warn "Processing App - [#{fileName}]"
          fh = fs.fileOpen(fileName)
          vi = File.getVersionInfo(fh)
					# Access application icons  
					#peData = PEheader.new(fh)
          fh.close
#          $log.warn "Processing App - [#{fileName}] - VI length:[#{vi.length}]"
					if vi.length > 0
						e2 = e.add_element('versioninfo')
						vi.each_pair { |k,v| e2.add_element("value", {"name"=>k}).add_text(v.to_s) }
					end
	  
		#		  if peData.icons.length > 0
		#			ie = e1.add_element("image",{"file"=>fileName, "count"=>peData.icons.length.to_s, "md5"=>Digest::MD5.hexdigest(peData.icons[0])})
		#			addIconData(ie, peData, iconNode)
		#		  end
        rescue Exception => e
#          $log.warn "postProcessApps - [#{fileName}] - error [#{e.to_s}]"
        end
      }
    }
  end

  def self.addIconData(icon_element, peData, iconNode)
		$log.debug "Adding application image: [#{icon_element}]"
		# Copy this element into another branch of the xml to store icon binary data
		newEle = iconNode.add_element(icon_element.name, icon_element.attributes)
		# Encode binary icon data as an element
		newEle.add_element("binary", {"type"=>"icon"}).add_text(MIQEncode.encode(peData.icons[0]))
  end
  
  def self.processServices(xmlNode, hiveName, regHnd, xmlCol)
		eServices = MIQRexml.findElement("services", xmlCol.root)

    eSvcList = MIQRexml.findRegElement("HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services", xmlNode.root)
		if eSvcList
			eSvcList.each_element do |e|
				next if e.name != "key"

				# Remove child elements's that have children.  This data is not being processed on the server
				# and adds a lot of extract size to the xml and time for tagging.
				e.each_element { |e1| e1.remove! if e1.name == 'key' }

				# Create one element referring to the type by name
				serviceType = MIQRexml.getChildAttrib(e, "Type", 1).to_i
				e2 = e.add_element("value", {"name" => "TypeName", "type" => "REG_SZ"})
				e2.text = if (serviceType & 0x00000001) > 0
						"kernel"
					elsif (serviceType & 0x00000002) > 0
						"filesystem"
					elsif ((serviceType & 0x00000010) > 0) || ((serviceType & 0x00000020) > 0)
						"win32_service"
					else
						"misc"
					end

				eServices << e
			end
		end
  end

  def self.addElement(xmlNode, nodeName, regPath, xmlCol, makeCopy=false)
		eNode = MIQRexml.findElement(nodeName, xmlCol.root)
		eNew =  MIQRexml.findRegElement(regPath, xmlNode)

		if makeCopy
			eNode << MiqXml.createDoc(eNew.to_s).root if eNew
		else			
			eNode << eNew if eNew
		end
  end
end
