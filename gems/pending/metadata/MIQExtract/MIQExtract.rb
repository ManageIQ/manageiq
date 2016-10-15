require 'MiqVm/MiqVm'
require 'metadata/util/md5deep'
require 'util/miq-xml'
require 'util/miq-logger'
require 'ostruct'
require 'metadata/util/win32/Win32Accounts'
require 'metadata/util/win32/Win32Software'
require 'metadata/util/win32/Win32Services'
require 'metadata/util/win32/Win32System'
require 'metadata/util/win32/Win32EventLog'
require 'metadata/linux/LinuxUsers'
require 'metadata/linux/LinuxPackages'
require 'metadata/linux/LinuxInitProcs'
require 'metadata/linux/LinuxSystemd'
require 'metadata/linux/LinuxOSInfo'
require 'metadata/ScanProfile/VmScanProfiles'
require 'VMwareWebService/MiqVim'
require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackImage'
require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance'
require 'util/miq-password'
require 'VMwareWebService/MiqVimBroker'

class MIQExtract
  attr_reader :systemFsMsg, :systemFs, :vm

  def initialize(filename, ost = nil) # TODO: Always pass in MiqVm
    ost ||= OpenStruct.new
    @ost = ost
    @dataDir = ost.config.try(:dataDir)
    ost.scanData = {} if ost.scanData.nil?
    @xml_class = ost.xml_class.nil? ? XmlHash::Document : ost.xml_class

    # TODO: Should all be subclasses of MiqVm.
    #       Going forward, we should only pass in an MiqVm - so the "else" will be removed.
    if filename.respond_to?(:rootTrees)
      @externalMount = true
      @target = filename
      @configFile = filename.respond_to?(:vmConfigFile) ? @target.vmConfigFile : nil

      $log.info "MIQExtract using config file: [#{@configFile}]  settings: [#{MiqPassword.sanitize_string(ost.scanData.inspect)}]"
    else
      @externalMount = false
      @configFile = filename.gsub(/^"/, "").gsub(/"$/, "")

      $log.info "MIQExtract using config file: [#{@configFile}]  settings: [#{MiqPassword.sanitize_string(ost.scanData.inspect)}]"
      ost.openParent = true if ost.scanData.fetch_path('snapshot', 'use_existing') == true
      ost.force = false if ost.scanData.fetch_path('snapshot', 'forceFleeceDefault') == false
      ost.snapshotDescription = ost.scanData.fetch_path('snapshot', 'description') if ost.scanData.fetch_path('snapshot', 'description')
      ost.snapshot_create_free_space = ost.scanData.fetch_path('snapshot', 'create_free_percent') || 100
      ost.snapshot_remove_free_space = ost.scanData.fetch_path('snapshot', 'remove_free_percent') || 100
      @target = MiqVm.new(@configFile, ost)
    end

    # Set the system fs handle
    begin
      st = Time.now
      $log.info "Loading disk files for VM [#{@configFile}]"
      @systemFs = @target.rootTrees[0]
      if @systemFs.nil?
        raise MiqException::MiqVmMountError, "No root filesystem found." if @target.diskInitErrors.empty?

        err_msg = ''
        @target.diskInitErrors.each do |disk, err|
          err = "#{err} - #{disk}" unless err.include?(disk)
          err_msg += "#{err}\n"
        end
        raise err_msg.chomp
      end

      @systemFsMsg = "OS:[#{@systemFs.guestOS}] found on VM [#{@configFile}].  Loaded in [#{Time.now - st}] seconds"
      $log.info @systemFsMsg
    rescue => err
      @systemFsMsg = "Unable to mount filesystem.  Reason:[#{err}]"
      $log.error "#{@systemFsMsg} for VM [#{@configFile}]"
      log_level = err.kind_of?(MiqException::Error) ? :debug : :error
      err.backtrace.each { |bt| $log.send(log_level, "MIQExtract.new #{bt}") }
      close
    end

    # Load Scan Profiles
    @scanProfiles = VmScanProfiles.new(ost.scanData['vmScanProfiles'], VmScanProfiles::SCAN_ITEM_CATEGORIES => ost.category, :xml_class => @xml_class)
  end

  def categories
    @scanProfiles.get_categories
  end

  def split_registry(path)
    y = path.tr("\\", "/").split("/")
    return y[0].downcase, y[1..-1].join("/")
  end

  def getProfileData(&blk)
    # First check for registry keys
    if @systemFs.guestOS == "Windows"
      reg_filters = @scanProfiles.get_registry_filters

      if reg_filters
        st = Time.now
        $log.info "Scanning [Profile-Registry] information."
        yield({:msg => 'Scanning Profile-Registry'}) if block_given?

        filters = []
        reg_filters[:HKCU].to_miq_a.each { |f| filters << {:key => split_registry(f['key']).join('/'), :depth => f['depth']} }
        @scanProfiles.parse_data(@target, RemoteRegistry.new(@systemFs, @xml_class).loadCurrentUser(filters)) unless filters.empty?

        filters = {}
        reg_filters[:HKLM].each do |f|
          hive, path = split_registry(f["key"])
          filters[hive.downcase] = [] if filters[hive.downcase].nil?
          filters[hive.downcase] << path
        end unless reg_filters[:HKLM].nil?

        filters.each_pair do |k, v|
          regHnd = RemoteRegistry.new(@systemFs, @xml_class)
          xml = regHnd.loadHive(k, v)
          @scanProfiles.parse_data(@target, xml)
        end unless filters.empty?
        $log.info "Scanning [Profile-Registry] information ran for [#{Time.now - st}] seconds."
      end
    end

    # Pass in the MiqVm handle to do file parsing
    @scanProfiles.parse_data(@target, nil, &blk)

    @scanProfiles.to_xml
  end

  def extract(category, &blk)
    xml = nil
    category.to_miq_a.each do |c|
      c = c.downcase
      xml = case c
            when "accounts" then getAccounts(c)
            when "services" then getServices(c)
            when "software" then getSoftware(c)
            when "system"   then getSystem(c)
            when "ntevents" then getEventLogs(c)
            when "vmconfig" then getVMConfig(c)
            # vmEvents are added to the blackbox externally, not extracted from the vm disks.
            when "vmevents" then return nil
            when "profiles" then getProfileData(&blk)
            else
              $log.warn "Warning: Category not processed [#{c}]"
              nil
            end

      # Write XML to data directory for debugging
      # File.open(File.join(@dataDir, "scan_#{c}.xml"),"w") {|f| xml.write(f,0)} if xml rescue nil
    end
  rescue => err
    $log.error "MIQExtract.extract #{err}"
    log_level = err.kind_of?(MiqException::Error) ? :debug : :error
    err.backtrace.each { |bt| $log.send(log_level, "MIQExtract.extract #{bt}") }
    raise err
  ensure
    return xml
  end

  def getVMConfig(_c)
    # Get VM config in XML format
    config_xml = @target.vmConfig.toXML(true, @target)

    begin
      # Log snapshot data for diagnostic purposes
      config_xml.find_each("//vm/snapshots") do |s|
        formattedXml = ""
        s.write(formattedXml, 0)

        # Dump the formated snapshot xml section
        formattedXml.split("\n").each { |l| $log.debug l }

        # Log the high level snapshot details
        $log.info "Snapshot overview: Count:[#{s.attributes['numsnapshots']}]  Current:[#{s.attributes['current']}]"

        # Log each child snapshot element
        s.find_each("child::snapshot") { |ss| $log.info "Snapshot details:  id:[#{ss.attributes['uid']}]  Name:[#{ss.attributes['displayname']}]" }
      end
    rescue => e
      # $log.error e
    end

    if config_xml.class != @xml_class
      config_xml = @xml_class.load(config_xml.to_s)
    end

    config_xml
  end

  def xml_doc_node(category)
    doc = @xml_class.createDoc(:miq)
    node = doc.root.add_element(category)
    return doc, node
  end

  def getAccounts(c)
    return if @systemFs.nil?

    doc, node = xml_doc_node(:accounts)
    #   doc.root.attributes["xsi:schemaLocation"] += " accounts.xsd"

    case @systemFs.guestOS
    when "Windows"
      MiqWin32::Accounts.new(c, @systemFs).to_xml(node)
    when "Linux"
      MiqLinux::Users.new(@systemFs).to_xml(node)
    end

    doc
  end

  def getServices(c)
    return if @systemFs.nil?

    doc, node = xml_doc_node(:services)
    #   doc.root.attributes["xsi:schemaLocation"] += " services.xsd"

    case @systemFs.guestOS
    when "Windows"
      MiqWin32::Services.new(c, @systemFs).to_xml(node)
    when "Linux"
      MiqLinux::Systemd.new(@systemFs).toXml(node) if MiqLinux::Systemd.detected?(@systemFs)
      MiqLinux::InitProcs.new(@systemFs).toXml(node)
    end

    doc
  end

  def getSystem(c)
    return if @systemFs.nil?

    doc, node = xml_doc_node(:system)
    #   doc.root.attributes["xsi:schemaLocation"] += " system.xsd"

    case @systemFs.guestOS
    when "Windows"
      MiqWin32::System.new(c, @systemFs).to_xml(node)
    when "Linux"
      MiqLinux::OSInfo.new(@systemFs).toXml(node)
    end

    doc
  end

  def getSoftware(c)
    return if @systemFs.nil?

    doc, node = xml_doc_node(:software)
    #   doc.root.attributes["xsi:schemaLocation"] += " software.xsd"

    case @systemFs.guestOS
    when "Windows"
      MiqWin32::Software.new(c, @systemFs).to_xml(node)
    when "Linux"
      MiqLinux::Packages.new(@systemFs).toXml(node)
    end

    doc
  end

  def getEventLogs(_c)
    ntevent = Win32EventLog.new(@systemFs)
    ntevent.readAllLogs(Win32EventLog::SYSTEM_LOGS)
  end

  def scanMD5deep
    # Produce file system XML with MD5 info
    $log.debug "Starting Filesystem scan"
    # scanPath = "c:/program files"
    scanPath = "c:/program files/Java/jdk1.5.0_12/jre/lib"
    md5 = MD5deep.new(@systemFs, 'versioninfo' => true, 'imports' => true)
    xml = md5.scan(scanPath, scanPath)
  end

  def getBaseConfigName
    File.join(File.dirname(@configFile), File.basename(@configFile, ".*"))
  end

  def close
    return if @externalMount
    # Call Unmount command if drive was succesfully mounted
    unless @target.nil?
      $log.debug "Unmounting..."
      begin
        @target.unmount
        $log.debug "Unmounting complete"
      rescue => err
        $log.error "Error during disk unmounting for VM:[#{@configFile}]"
        $log.debug err.backtrace.join("\n")
      ensure
        @ost.miqVim.disconnect if @ost.miqVim
        unmount_storage(@mount) unless @mount.blank?
        set_process_permissions(:reset)
      end
    end
  end  # close
end  # MIQExtract class
