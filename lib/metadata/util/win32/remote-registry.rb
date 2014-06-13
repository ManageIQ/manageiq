require 'ms-registry'
require 'miq-xml'
require 'xml/xml_hash'
require 'system_path_win'

HKEY_LOCAL_MACHINE = "HKEY_LOCAL_MACHINE"     #0x80000002
HKEY_USERS = "default"                        #0x80000003

class RemoteRegistry
  attr_reader :fileLoadTime, :fileParseTime, :digitalProductKeys

  def initialize(fs, xml_class=MiqXml, reg_path=nil)
    @fileHnd = nil
    @HKLM_element = nil
    @loadedHives = Array.new

    # Legacy check - xml_class use to be use_hash flag
    xml_class = XmlHash::Document if xml_class == true
    xml_class = MiqXml if xml_class == false

    #Create XML document
    @xml = xml_class.createDoc(:registry)
    @HKLM_element = @xml.root.add_element("HKEY_LOCAL_MACHINE")
	  
    if fs.kind_of?(MiqFS)
      @fs = fs
      if reg_path.nil?
        path = Win32::SystemPath.registryPath(@fs) + "/"
        @RegPath = path.gsub(/^"/, "").gsub(/"$/, "")
      else
        @RegPath = reg_path
      end
    else
      @RegPath = fs
    end

    @fileLoadTime = nil
    @fileParseTime = nil
      
    @digitalProductKeys = []
	end
    
  def close
    @xml = nil
  end

	def processRegistryAll
    # Load Major hives
    loadSoftwareHive()
    loadSystemHive()
    loadDefaultHive()
    loadSecurityHive()
    loadSAMHive()
    return @xml
	end

  def open(key, subkey)
    paths = subkey.tr("\\", "/").split("/")
    if key == HKEY_LOCAL_MACHINE then
      #$log.debug "Loading hive: #{paths[0].downcase}"
      loadHive(paths[0].downcase, nil)
      paths.insert(0, key)
      #$log.debug "Search paths: #{paths} #{paths.length}"
      return MIQRexml.findRegElementInt(paths, @xml.root)
    end
  end

	def loadSoftwareHive(filter=nil)
    loadHive("software", filter)
	end
	
	def loadSystemHive(filter=nil)
    loadHive("system", filter)
	end

	def loadSecurityHive(filter=nil)
    loadHive("security", filter)
	end

	def loadSAMHive(filter=nil)
    loadHive("SAM", filter)
	end
	
	# Vista stores boot information in a registry hive in /boot/BCD
	def loadBootHive(filter=nil)
		loadHive("BCD", nil, "/boot")
	end

  def loadHive(name, filters=nil, path=@RegPath)
    xml = @xml
    unless @loadedHives.include?(name.downcase) then
      if name.downcase == "default"
        xmlNode = @xml.root.add_element("HKEY_USERS").add_element("_DEFAULT")
      else
        xmlNode = @HKLM_element.add_element(name.upcase)
      end
      xml = process_hive(path, name, xmlNode, filters)
      @loadedHives.push(name.downcase)
    end
    return xml
  end

  def loadCurrentUser(filters=nil)
    xml = @xml
    users = []
    hkcu = self.loadHive("software", [{:key=>"Microsoft/Windows NT/CurrentVersion/ProfileList",:value=>['ProfileImagePath']}])
    hkcu.root.each_recursive do |v|
      # Only process user accounts, not local system service accounts (like S-1-5-18)
      if v.name == :value && v.parent.attributes[:keyname].length > 8
        ntuser = File.join(v.text.gsub('\\','/'), 'ntuser.dat')
        users << {:path=>ntuser,:mtime=>@fs.fileMtime(ntuser).to_i} if @fs.fileExists?(ntuser)
      end
    end

    unless users.empty?
      # Sort so most recently updated is first
      users.sort! {|a,b| b[:mtime]<=>a[:mtime]}
      xmlNode = @xml.root.add_element("HKEY_CURRENT_USER")
      path, name = File.dirname(users.first[:path]), File.basename(users.first[:path])
      xml = process_hive(path, name, xmlNode, filters)
    end

    return xml
  end

  def process_hive(path, name, xmlNode, filters)
    defaultHive = MSRegHive.new(path, name.downcase, xmlNode, @fs, filters)
    defaultHive.parseHives()
    @fileLoadTime, @fileParseTime = defaultHive.fileLoadTime, defaultHive.fileParseTime
    @digitalProductKeys = defaultHive.digitalProductKeys
    $log.debug "Hive parsing complete in [#{@fileLoadTime + @fileParseTime}] seconds"
    return defaultHive.xmlNode
  end
   
  def toXML
    return @xml
  end

  # Return a list of loaded hives	so the user can check if there hive
  # is already available in the xml structure
	def loadedHives
    return @loadedHives
	end	
end
