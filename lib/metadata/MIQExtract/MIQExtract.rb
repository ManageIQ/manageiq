#$:.push("#{File.dirname(__FILE__)}/../VMMount")
#$:.push("#{File.dirname(__FILE__)}/../VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../MiqVm")
$:.push("#{File.dirname(__FILE__)}/../../util")
$:.push("#{File.dirname(__FILE__)}/../../util/mount")
$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../util/win32")
$:.push("#{File.dirname(__FILE__)}/../linux")
$:.push("#{File.dirname(__FILE__)}/../ScanProfile")
$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")
$:.push("#{File.dirname(__FILE__)}/../../RedHatEnterpriseVirtualizationManagerAPI")

require 'MiqVm'
require 'md5deep'
require 'miq-xml'
require 'miq-logger'
require 'ostruct'
require 'Win32Accounts'
require 'Win32Software'
require 'Win32Services'
require 'Win32System'
require 'Win32EventLog'
require 'LinuxUsers'
require 'LinuxPackages'
require 'LinuxInitProcs'
require 'LinuxOSInfo'
require 'VmScanProfiles'
require 'MiqVim'
require 'miq-password'
require 'MiqVimBroker'

class MIQExtract
	attr_reader :systemFsMsg, :systemFs, :vm

	def initialize(filename, ost=nil)

    ost ||= OpenStruct.new
    @ost = ost
    @dataDir = ost.config ? ost.config.dataDir : nil
    ost.scanData = {} if ost.scanData.nil?
    @xml_class = ost.xml_class.nil? ? XmlHash::Document : ost.xml_class

		if filename.kind_of?(MiqVm)
			@externalMount = true
			@vm = filename
			@vmCfgFile = @vm.vmConfigFile

      $log.info "MIQExtract using config file: [#{@vmCfgFile}]  settings: [#{MiqPassword.sanitize_string(ost.scanData.inspect)}]"
		else
			@externalMount = false
			@vmCfgFile = filename.gsub(/^"/, "").gsub(/"$/, "")

      $log.info "MIQExtract using config file: [#{@vmCfgFile}]  settings: [#{MiqPassword.sanitize_string(ost.scanData.inspect)}]"
      ost.openParent = true if ost.scanData.fetch_path('snapshot', 'use_existing')==true
      ost.force = false if ost.scanData.fetch_path('snapshot', 'forceFleeceDefault')==false
      ost.snapshotDescription = ost.scanData.fetch_path('snapshot', 'description') if ost.scanData.fetch_path('snapshot', 'description')
      ost.snapshot_create_free_space = ost.scanData.fetch_path('snapshot', 'create_free_percent') || 100
      ost.snapshot_remove_free_space = ost.scanData.fetch_path('snapshot', 'remove_free_percent') || 100
      set_process_permissions(:set)
      connect_to_ems(ost)
			@vm = MiqVm.new(@vmCfgFile, ost)
		end

		# Set the system fs handle
		begin
      st = Time.now
      $log.info "Loading disk files for VM [#{@vmCfgFile}]"
			@systemFs = @vm.vmRootTrees[0]
			if @systemFs.nil?
				raise MiqException::MiqVmMountError, "No root filesystem found." if @vm.diskInitErrors.empty?

				err_msg = ''
				@vm.diskInitErrors.each do |disk, err|
					err = "#{err} - #{disk}" unless err.include?(disk)
					err_msg += "#{err}\n"
        end
				raise err_msg.chomp
      end

			@systemFsMsg = "OS:[#{@systemFs.guestOS}] found on VM [#{@vmCfgFile}].  Loaded in [#{Time.now-st}] seconds"
			$log.info @systemFsMsg
		rescue => err
			@systemFsMsg = "Unable to mount filesystem.  Reason:[#{err}]"
			$log.error "#{@systemFsMsg} for VM [#{@vmCfgFile}]"
      log_level = err.kind_of?(MiqException::Error) ? :debug : :error
      err.backtrace.each {|bt| $log.send(log_level, "MIQExtract.new #{bt}")}
			close
		end

		# Load Scan Profiles
    @scanProfiles = VmScanProfiles.new(ost.scanData['vmScanProfiles'], {VmScanProfiles::SCAN_ITEM_CATEGORIES=>ost.category, :xml_class => @xml_class})
	end

  def categories
    @scanProfiles.get_categories()
  end

  def split_registry(path)
    y = path.tr("\\", "/").split("/")
    return y[0].downcase, y[1..-1].join("/")
  end

  def getProfileData(&blk)
    # First check for registry keys
    if @systemFs.guestOS == "Windows"
      reg_filters = @scanProfiles.get_registry_filters()

      if reg_filters
        st = Time.now
        $log.info "Scanning [Profile-Registry] information."
        yield({:msg=>'Scanning Profile-Registry'}) if block_given?

        filters = []
        reg_filters[:HKCU].to_miq_a.each {|f| filters << {:key=>self.split_registry(f['key']).join('/'),:depth=>f['depth']}}
        @scanProfiles.parse_data(@vm, RemoteRegistry.new(@systemFs, @xml_class).loadCurrentUser(filters)) unless filters.empty?

        filters = {}
        reg_filters[:HKLM].each do |f|
          hive, path = self.split_registry(f["key"])
          filters[hive.downcase] = [] if filters[hive.downcase].nil?
          filters[hive.downcase] << path
        end unless reg_filters[:HKLM].nil?

        filters.each_pair do |k,v|
          regHnd = RemoteRegistry.new(@systemFs, @xml_class)
          xml = regHnd.loadHive(k, v)
          @scanProfiles.parse_data(@vm, xml)
        end unless filters.empty?
        $log.info "Scanning [Profile-Registry] information ran for [#{Time.now-st}] seconds."
      end
    end

    # Pass in the MiqVm handle to do file parsing
    @scanProfiles.parse_data(@vm, nil, &blk)

    return @scanProfiles.to_xml()
  end

	def extract(category, &blk)
		begin
			xml = nil
			category.to_miq_a.each do |c|
				c = c.downcase
				xml = case c
				when "accounts" then getAccounts(c)
				when "services" then getServices(c)
				when "software"	then getSoftware(c)
				when "system"   then getSystem(c)
				when "ntevents" then getEventLogs(c)
				when "vmconfig" then getVMConfig(c)
					#vmEvents are added to the blackbox externally, not extracted from the vm disks.
				when "vmevents" then return nil
        when "profiles" then getProfileData(&blk)
				else
					$log.warn "Warning: Category not processed [#{c}]"
					nil
				end

        # Write XML to data directory for debugging
        #File.open(File.join(@dataDir, "scan_#{c}.xml"),"w") {|f| xml.write(f,0)} if xml rescue nil
      end
		rescue => err
			$log.error "MIQExtract.extract #{err.to_s}"
      log_level = err.kind_of?(MiqException::Error) ? :debug : :error
      err.backtrace.each {|bt| $log.send(log_level, "MIQExtract.extract #{bt}")}
			raise err
		ensure
			return xml
		end
	end

	def getVMConfig(c)
		# Get VM config in XML format
		config_xml = @vm.vmConfig.toXML(true, @vm)

		begin
			# Log snapshot data for diagnostic purposes
			config_xml.find_each("//vm/snapshots") do |s|
				formattedXml = ""
				s.write(formattedXml,0)

				# Dump the formated snapshot xml section
				formattedXml.split("\n").each {|l| $log.debug l}

				# Log the high level snapshot details
				$log.info "Snapshot overview: Count:[#{s.attributes['numsnapshots']}]  Current:[#{s.attributes['current']}]"

				# Log each child snapshot element
				s.find_each("child::snapshot") { |ss| $log.info "Snapshot details:  id:[#{ss.attributes['uid']}]  Name:[#{ss.attributes['displayname']}]" }
			end
		rescue => e
			#$log.error e
		end

    if config_xml.class != @xml_class
      config_xml = @xml_class.load(config_xml.to_s)
    end

		return config_xml
	end

  def xml_doc_node(category)
    doc = @xml_class.createDoc(:miq)
    node = doc.root.add_element(category)
    return doc, node
  end

	def getAccounts(c)
		return if @systemFs.nil?

    doc, node = xml_doc_node(:accounts)
#		doc.root.attributes["xsi:schemaLocation"] += " accounts.xsd"

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
#		doc.root.attributes["xsi:schemaLocation"] += " services.xsd"

		case @systemFs.guestOS
		when "Windows"
			MiqWin32::Services.new(c, @systemFs).to_xml(node)
		when "Linux"
			MiqLinux::InitProcs.new(@systemFs).toXml(node)
		end

		doc
	end

	def getSystem(c)
		return if @systemFs.nil?

		doc, node = xml_doc_node(:system)
#		doc.root.attributes["xsi:schemaLocation"] += " system.xsd"

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
#		doc.root.attributes["xsi:schemaLocation"] += " software.xsd"

		case @systemFs.guestOS
		when "Windows"
			MiqWin32::Software.new(c, @systemFs).to_xml(node)
		when "Linux"
			MiqLinux::Packages.new(@systemFs).toXml(node)
		end

		doc
	end

	def getEventLogs(c)
		begin
			ntevent = Win32EventLog.new(@systemFs)
			ntevent.readAllLogs(Win32EventLog::SYSTEM_LOGS)
		end
	end

	def scanMD5deep()
		# Produce file system XML with MD5 info
		$log.debug "Starting Filesystem scan"
		#scanPath = "c:/program files"
		scanPath = "c:/program files/Java/jdk1.5.0_12/jre/lib"
		md5 = MD5deep.new(@systemFs, {'versioninfo'=>true,'imports'=>true})
		xml = md5.scan(scanPath, scanPath)
	end

	def getBaseConfigName
		File.join(File.dirname(@vmCfgFile), File.basename(@vmCfgFile, ".*"))
	end

	def close
		return if @externalMount
		# Call Unmount command if drive was succesfully mounted
		unless @vm.nil? then
			$log.debug "Unmounting..."
      begin
  			@vm.unmount
    		$log.debug "Unmounting complete"
      rescue => err
        $log.error "Error during disk unmounting for VM:[#{@vmCfgFile}]"
        $log.debug err.backtrace.join("\n")
      ensure
        @ost.miqVim.disconnect if @ost.miqVim
        self.unmount_storage(@mount) unless @mount.blank?
        set_process_permissions(:reset)
      end
		end
	end  #close

  def set_process_permissions(mode=:set)
    log_header = "MIQExtract.set_process_permissions:"
    grp_id = @ost.scanData.fetch_path('permissions', 'group')
    unless grp_id.nil?
      if mode == :set
        $log.info "#{log_header} Process Group ID change requested from current:<#{Process.gid}> to <#{grp_id}>"
        begin
          @ost.scanData['permissions']['saved_group'] = Process.gid
          Process::GID.change_privilege(grp_id)
          $log.info "#{log_header} Group ID changed to <#{Process.gid}>"
        rescue => err
          $log.warn "#{log_header} Unable to change Group ID for current process.  Message: <#{err}>"
        end
      else
        saved_grp_id = @ost.scanData.fetch_path('permissions', 'saved_group')
        unless saved_grp_id.nil?
          $log.info "#{log_header} Resetting Process Group ID from Current:<#{Process.gid}> to <#{saved_grp_id}>"
          begin
            Process::GID.change_privilege(saved_grp_id)
            $log.info "#{log_header} Group ID reset to <#{Process.gid}>"
          rescue => err
            $log.warn "#{log_header} Unable to reset Group ID for current process.  Message: <#{err}>"
          end
        end
      end
    end
  end

  def mount_storage(mount_hash)
    require 'miq_nfs_session'
    log_header = "MIQ(MIQExtract.mount_storage)"

    begin
      FileUtils.mkdir_p(mount_hash[:link_path]) unless File.directory?(mount_hash[:link_path])
      mount_hash[:mount_points].each do |mnt|
        $log.info "#{log_header} Creating mount point <#{mnt.inspect}>"
        MiqNfsSession.new(mnt).connect
      end
      mount_hash[:symlinks].each do |link|
        $log.info "#{log_header} Creating symlink <#{link.inspect}>"
        File.symlink(link[:source], link[:target])
      end
    rescue
      $log.error "#{log_header} Unable to mount all items from <#{mount_hash[:base_dir]}>"
      unmount_storage(mount_hash)
      raise $!
    end
  end

  def unmount_storage(mount_hash)
    log_header = "MIQ(MIQExtract.unmount_storage)"
    begin
      $log.warn "#{log_header} Unmount all items from <#{mount_hash[:base_dir]}>"
      mount_hash[:mount_points].each {|mnt| MiqNfsSession.disconnect(mnt[:mount_point])}
      FileUtils.rm_rf(mount_hash[:base_dir])
    rescue
      $log.warn "#{log_header} Failed to unmount all items from <#{mount_hash[:base_dir]}>.  Reason: <#{$!}>"
    end
  end

  def connect_to_ems(ost)
    if ost
      ems_connect_type = ost.scanData.fetch_path('ems', 'connect_to') || 'host'
      klass_name = ost.scanData.fetch_path("ems", ems_connect_type, :class_name).to_s
      if klass_name.include?('Redhat')
        connect_to_ems_rhevm(ost, ems_connect_type)
      else
        connect_to_ems_vmware(ost, ems_connect_type)
      end
    end
  end

  def connect_to_ems_vmware(ost, ems_connect_type)
    if ost.config && ost.config.capabilities[:vixDisk] == true
      # Make sure we were given a ems/host to connect to
      miqVimHost = ost.scanData.fetch_path("ems", ems_connect_type)
      if miqVimHost
        st = Time.now
        use_broker = ost.scanData["ems"][:use_vim_broker] == true
        miqVimHost[:address] = miqVimHost[:ipaddress] if miqVimHost[:address].nil?
        ems_display_text = "#{ems_connect_type}(#{use_broker ? 'via broker' : 'directly'}):#{miqVimHost[:address]}"
        $log.info "Connecting to [#{ems_display_text}] for VM:[#{@vmCfgFile}]"
        miqVimHost[:password_decrypt] = MiqPassword.decrypt(miqVimHost[:password])
        if !$miqHostCfg || !$miqHostCfg.emsLocal
          ($miqHostCfg ||= OpenStruct.new).vimHost = ost.scanData["ems"]['host']
          $miqHostCfg.vimHost[:use_vim_broker] = use_broker
        end

        begin
          require 'miq_fault_tolerant_vim'
          ost.miqVim = MiqFaultTolerantVim.new(:ip => miqVimHost[:address], :user => miqVimHost[:username], :pass => miqVimHost[:password_decrypt], :use_broker => use_broker, :vim_broker_drb_port => ost.scanData['ems'][:vim_broker_drb_port])
          #ost.snapId = opts.snapId if opts.snapId
          $log.info "Connection to [#{ems_display_text}] completed for VM:[#{@vmCfgFile}] in [#{Time.now-st}] seconds"
        rescue Timeout::Error => err
          msg = "Connection to [#{ems_display_text}] timed out for VM:[#{@vmCfgFile}] with error [#{err.to_s}] after [#{Time.now-st}] seconds"
          $log.error msg
          raise err, msg, err.backtrace
        rescue Exception => err
          msg = "Connection to [#{ems_display_text}] failed for VM:[#{@vmCfgFile}] with error [#{err.to_s}] after [#{Time.now-st}] seconds"
          $log.error msg
          raise err, msg, err.backtrace
        end
      end
    end
  end

  def connect_to_ems_rhevm(ost, ems_connect_type)
    log_header = "MIQ(MIQExtract.connect_to_ems_rhevm)"
    @mount = ost.scanData[:mount]
    unless @mount.blank?
      $rhevm_mount_root = @mount[:base_dir]
      $log.info "#{log_header} Mounting storage for VM at <#{$rhevm_mount_root}>"
      self.mount_storage(@mount)
      @vmCfgFile = File.join($rhevm_mount_root, @vmCfgFile)
    end

    # Check if we've been told explicitly not to connect to the ems
    return if ost.scanData.fetch_path("ems", 'connect') == false

    # Make sure we were given a ems/host to connect to
    miqVimHost = ost.scanData.fetch_path("ems", ems_connect_type)
    if miqVimHost
      st = Time.now
      #use_broker = ost.scanData["ems"][:use_vim_broker] == true
      use_broker = false
      miqVimHost[:address] = miqVimHost[:ipaddress] if miqVimHost[:address].nil?
      ems_display_text = "#{ems_connect_type}(#{use_broker ? 'via broker' : 'directly'}):#{miqVimHost[:address]}"
      $log.info "Connecting to [#{ems_display_text}] for VM:[#{@vmCfgFile}]"
      miqVimHost[:password_decrypt] = MiqPassword.decrypt(miqVimHost[:password])

      begin
        require 'rhevm_inventory'
        ems_opt = {
          :server   => miqVimHost[:address],
          :username => miqVimHost[:username],
          :password => miqVimHost[:password_decrypt]
        }
        ems_opt[:port] = miqVimHost[:port] unless miqVimHost[:port].blank?

        rhevm = Ovirt::Inventory.new(ems_opt)
        rhevm.api
        ost.miqRhevm = rhevm
        $log.info "Connection to [#{ems_display_text}] completed for VM:[#{@vmCfgFile}] in [#{Time.now-st}] seconds"
      rescue Timeout::Error => err
        msg = "Connection to [#{ems_display_text}] timed out for VM:[#{@vmCfgFile}] with error [#{err.to_s}] after [#{Time.now-st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      rescue Exception => err
        msg = "Connection to [#{ems_display_text}] failed for VM:[#{@vmCfgFile}] with error [#{err.to_s}] after [#{Time.now-st}] seconds"
        $log.error msg
        raise err, msg, err.backtrace
      end
    end
  end

end  # MIQExtract class
