$:.push("#{File.dirname(__FILE__)}/../../lib/util/win32")

require 'ostruct'
require "win32/service"
require 'win32/process'
require 'miq-netuse'
require 'miq-wmi'
require 'miq-password'
require 'miq-powershell'
#require 'socket'

module InstallWin
  SERVICE_NAME = "miqhost"
  SERVICE_DISPLAYNAME = "ManageIQ SmartProxy"
  SERVICE_DESCRIPTION = "Provides smart management of virtualized environments."
  FIREWALL_EXCEPTION_NAME = "\"ManageIQ SmartProxy\""

  # Possible Run types
  MIQHOST_EXECUTABLE = 1  #(0x0001)
  MIQHOST_NT_SERVICE = 3  #(0x0011)
  MIQHOST_SCRIPT     = 4  #(0x0100)

  def init()
    @binDir = nil
    @deamon_stopped = false

    if $miqRunningAs.nil?
      if $miqExePath
        if ENV["HOMEDRIVE"].nil?
          $miqRunningAs = MIQHOST_NT_SERVICE
        else
          $miqRunningAs = MIQHOST_EXECUTABLE
        end
      else
        $miqRunningAs = MIQHOST_SCRIPT
      end
    end
  end

  def install
    # Copy miqhost to miq-cmd.
    require 'fileutils'
    FileUtils.copy(@cfg.installedExe, files[:miqInstalledCmd])
    File.utime(File.atime(@cfg.installedExe), File.mtime(@cfg.installedExe), files[:miqInstalledCmd])

    #The daemon might already have been stopped, but check just in case
    stop_daemon
    @binDir = @cfg.binDir
    create unless Win32::Service.exists?(SERVICE_NAME)
    if @deamon_stopped
      start_daemon
      @deamon_stopped = false
    end
  end

  def uninstall
    # This will try to stop the daemon before deleting the nt scm entry
    delete_daemon

    # Remove the Windows Firewall setting
    `netsh firewall delete portopening TCP #{@cfg.wsListenPort}`
  end

  def start_daemon
    Win32::Service.start(SERVICE_NAME)
  end

  def stop_daemon
    if Win32::Service.exists?(SERVICE_NAME)
      unless Win32::Service.status(SERVICE_NAME).current_state === "stopped"
        Win32::Service.stop(SERVICE_NAME)
        @deamon_stopped = true
      end
    end
  end

  def restart_daemon
    if ($miqRunningAs & MIQHOST_EXECUTABLE) != 0
      sleep_time = 10
      batch_cmd = []
      if $miqRunningAs != MIQHOST_EXECUTABLE
        batch_cmd << ["REM Stop Host", "net stop #{SERVICE_NAME}", ""]
      end

      batch_cmd << ["REM Sleep (Windows independent implementation)", "ping 127.0.0.1 -n 2 -w 1000 > nul", "ping 127.0.0.1 -n #{sleep_time} -w 1000> nul", ""]

      if $miqRunningAs == MIQHOST_EXECUTABLE
        # Note: The start command takes a first parameter of "Title" then the program name
        batch_cmd <<  ["REM Start Host", "start \"#{$miqExePath}\" \"#{$miqExePath}\""]
      else
        batch_cmd <<  ["REM Start Host", "net start #{SERVICE_NAME}"]
      end
      runBatchCommand("miqhostRestart", batch_cmd)
    end
  end

  def delete_daemon
    if Win32::Service.exists?(SERVICE_NAME)
      self.stop_daemon
      Win32::Service.delete(SERVICE_NAME)
    end
  end

  def agent_out
    require 'fileutils'
    buildExe = File.join( File.dirname(@cfg.installedExe), "#{File.basename(@cfg.installedExe, ".*")}.#{@cfg.host_version.last}" )
    FileUtils.copy(@cfg.installedExe, buildExe)
    # Restore File stats
    File.utime(File.atime(@cfg.installedExe), File.mtime(@cfg.installedExe), buildExe)
  end

  def agent_in
    require 'fileutils'
    buildExe = $miqExePath
    FileUtils.copy(buildExe, @cfg.installedExe)
    File.delete(files[:miqInstalledCmd]) if File.exists? files[:miqInstalledCmd]
    FileUtils.copy(@cfg.installedExe, files[:miqInstalledCmd])
    # Restore File stats
    File.utime(File.atime(buildExe), File.mtime(buildExe), @cfg.installedExe)
    File.utime(File.atime(buildExe), File.mtime(buildExe), files[:miqInstalledCmd])

    # Create the data directory if it does not already exist
    Dir.mkdir(@cfg.dataDir, 0755) if !File.directory?(@cfg.dataDir)
  end

  def agent_activate(props)
    if ($miqRunningAs & MIQHOST_EXECUTABLE) != 0
      buildExe = File.join( File.dirname(@cfg.installedExe), "#{File.basename(@cfg.installedExe, ".*")}.#{props[:build]}" )
      sleep_time = 2
      dateTime = ["REM Log Date/Time", "DATE /t", "TIME /t", ""]

      batch_cmd = [dateTime,
        "REM Sleep (Windows independent implementation)", "ping 127.0.0.1 -n 2 -w 1000 > nul", "ping 127.0.0.1 -n #{sleep_time} -w 1000> nul", ""]

      if $miqRunningAs != MIQHOST_EXECUTABLE
        batch_cmd << ["REM Stop Host", "net stop #{SERVICE_NAME}", "",]
      end

      batch_cmd << ["REM Host Out", "\"#{@cfg.installedExe}\" agentout", "",
        "REM Host In", "\"#{buildExe}\" agentin", "",]

      if $miqRunningAs == MIQHOST_EXECUTABLE
        # Note: The start command takes a first parameter of "Title" then the program name
        batch_cmd <<  ["REM Start Host", "start \"#{$miqExePath}\" \"#{$miqExePath}\""]
      else
        batch_cmd << ["REM Start Host", "net start #{SERVICE_NAME}", "",]
      end

      batch_cmd << [dateTime]

      runBatchCommand("miqhostActivate", batch_cmd)
    end
  end

  def starting
    #$log.summary "RUNNING AS [#{$miqRunningAs}]" if $log
    # Enable the Web-Service Listening port in the Windows Firewall
    begin
      `netsh firewall set portopening tcp #{@cfg.wsListenPort} #{FIREWALL_EXCEPTION_NAME} ENABLE ALL`
      $log.summary "Firewall port [#{@cfg.wsListenPort}] enabled." if $log
    rescue => e
      $log.summary "Unable to open firewall port [#{@cfg.wsListenPort}].  [#{e}]" if $log
    end
  end

  def stopping
    # Remove the Windows Firewall setting
    begin
      `netsh firewall delete portopening TCP #{@cfg.wsListenPort}`
      $log.summary "Firewall port [#{@cfg.wsListenPort}] removed." if $log
    rescue => e
      $log.summary "Unable to delete firewall port [#{@cfg.wsListenPort}].  [#{e}]" if $log
    end
  end

  def host_check(toStdout=false)
    $log.summary ""
    $log.summary "****** Host Check Start ******"

    # Log TCP/IP information
    $log.summary ""
    $log.summary "TCP/IP Settings"
    Socket.getaddrinfo(Socket.gethostname, nil).each { |s| $log.summary "Hostname(IP Address): #{s[2]} (#{s[3]})" }

    # Dump General System Info
    hostcheck_process_logger("System Information", "systeminfo")

    # Dump Process Listing
    hostcheck_process_logger("Process List", "tasklist")

    # Dump firewall setting to log
    hostcheck_process_logger("Firewall Settings", "netsh firewall show state")

    $log.summary ""
    $log.summary "****** Host Check End ******"
    $log.summary ""

    return 0
  end

  def capabilities
    caps = {:vixDisk => false, :powershell=>MiqPowerShell.is_available?}
    return caps
  end


  def hostcheck_process_logger(displayName, processName)
    begin
      $log.summary ""
      $log.summary displayName
      outputArray = `#{processName}`.strip.split("\n")
      outputArray.each {|l| $log.summary l}
    rescue => e
      $log.summary "-------------------------------------------------------------------"
      $log.summary "Data collection failed.  [#{e}]"
    end
  end

  def files
    return @files if @files

    @files              = Hash.new

    # For Windows, use defined Program Files environment path if available.
    if ENV["ProgramFiles"]
      @files[:miqHome] = File.join(ENV["ProgramFiles"].gsub("\\", "/"), "ManageIQ")

      # Check for a config file in the parent directory of where the executable is running from.
      # If it exists use this location as the miqHome path.  This will allow for multiple exes to
      # run on the same machine with different config files.
      unless ENV["MIQ_EXE_PATH"].blank?
        exe_path = File.dirname(ENV["MIQ_EXE_PATH"])
        if File.basename(exe_path) == "bin"
          yaml_path = File.dirname(exe_path)
          @files[:miqHome] = yaml_path  if File.exists?(File.join(yaml_path, "miqhost.yaml"))
        end
      end
    else
      @files[:miqHome] = "c:/miq"
    end

    @files[:miqLogs]          = File.join(@files[:miqHome],   "log")
    @files[:miqCfgFile]       = File.join(@files[:miqHome],   "miqhost.yaml")
    @files[:miqBinDir]        = File.join(@files[:miqHome],   "bin")
    @files[:miqLibDir]        = File.join(@files[:miqHome],   "lib")
    @files[:miqDataDir]        = File.join(@files[:miqHome],  "data")
    @files[:miqInstalledExe]  = File.join(@files[:miqBinDir], "miqhost.exe")
    @files[:miqInstalledCmd]  = File.join(@files[:miqBinDir], "miq-cmd.exe")

    return @files
  end

  def runBatchCommand(batchName, cmdLines, delete_script=true)
    base_cmd = "cmd.exe /c"

    # Create temp batch filename and log filename
    cmdFile = File.join(ENV['TEMP'], "#{batchName}.cmd").gsub("/","\\")
    cmdLogFile = File.join(@cfg.miqLogs, "#{batchName}.log").gsub("/","\\")

    # Convert array of commands into a string if needed.
    if cmdLines.is_a?(Array)
      cmdLines += ["REM Delete Script (self)", "del /f /q \"#{cmdFile}\""] if delete_script
      cmdLines = cmdLines.join("\n")

    end

    # Create temp batch files
    File.open(cmdFile, "w") {|f| f.write(cmdLines); f.close}

    # Run process Async
    handle = Process.create("app_name" => "#{base_cmd} \"#{cmdFile}\"")  # 2>&1>> \"#{cmdLogFile}\""
  end

  def remoteInstall(settings)
    server = settings[:hostname]
    server.gsub!("@",".")
    username = settings[:username]
    password = MiqPassword.decrypt(settings[:password])

    # Determine the filename to copy to the remote machine.
    hostFile = @cfg.installedExe
    unless settings[:version].blank?
      hostFile = File.join(File.dirname(@cfg.installedExe), File.basename(@cfg.installedExe, ".*") + ".#{settings[:version]}")
    end

    begin
      # Log into WMI and start remote process
      wmi = WMIHelper.new()
      $log.info "Remote install connecting to WMI on [#{server}]"
      wmi.connectServer(server, username, password)

      # Determine system install path and check disk space
      remoteInstallDir = preinstall_check(settings, wmi)
      adminshare = remoteInstallDir.sub(":","$")

      # Copy the file to the remote machine
      remoteShare = NetUseShare.new(server, adminshare)
      mapDrive = remoteShare.sharePath()
      $log.info "Remote install connecting to [#{mapDrive}]"
      if remoteShare.connect(username, password)
        $log.info "Remote install copying [#{hostFile}] to [#{mapDrive}]"
        remoteFile = remoteShare.copyTo(hostFile)
        $log.debug "Remote copy complete."

        # If the local miqhost is using the loopback address resolve the hostname and pass that to the
        # remote install.
        vmdbAddress = @cfg.vmdbHost
        vmdbAddress = Socket.gethostbyname(@cfg.vmdbHost)[0] if vmdbAddress.downcase == "localhost" || vmdbAddress.downcase == "127.0.0.1"
        $log.info "Remote install running install process on [#{server}] with parameters [-h #{vmdbAddress} -p #{@cfg.vmdbPort} install]"
        rc = wmi.runProcess("#{remoteFile} -h #{vmdbAddress} -p #{@cfg.vmdbPort} install", false)
        $log.debug "Remote install process complete."

        $log.info "Remote install removing install media [#{server}]"
        remoteShare.deleteFile(remoteFile)
        remoteShare.disconnect()

        $log.info "Remote install starting NT Service [#{SERVICE_NAME}] on [#{server}]"
        wmi.getWin32Service(SERVICE_NAME) {|s|
          s.StartService unless s.started
        }

        $log.info "Remote install completed."
      else
        $log.error "Unable to open share to [#{mapDrive}] Error:[#{remoteShare.cmdMsg}]  Rc:[#{remoteShare.cmdRc}]" if $log
      end
    rescue Exception => err
      $log.error "Remote install failed.  Reason:[#{err}]"
    end
  end

private
  def preinstall_check(settings, wmi)
    # If required Free space was not sent make it 300 MB
    settings[:requiredFreeSpace] ||= 1024 * 1024 * 300

    # Find the Windows System Path
    os = wmi.get_instance("select Caption,Name,Version,WindowsDirectory from Win32_OperatingSystem")

    # Find the Windows System Disk
    d = wmi.get_instance("select DeviceID,FreeSpace from Win32_LogicalDisk where DeviceID = '#{os.windowsDirectory[0..1]}'")

    # Verify that the target has enough disk space
    raise "Insufficent disk space to install on remote machine.  Required:[#{settings[:requiredFreeSpace]}]  Available:[#{d.freeSpace.to_i}]" if d.freeSpace.to_i < settings[:requiredFreeSpace]

    # Return the install path
    File.join(os.windowsDirectory, "temp").gsub!("\\","/")
  end

  def create
    # Determine binary path to use
    if ENV["MIQ_EXE_PATH"]
      # Create Service
      binary_path = @cfg.installedExe.dup
      binary_path.gsub!("/","\\");

      Win32::Service.create(
        "service_name"     => SERVICE_NAME,
        "binary_path_name" => binary_path,
        "display_name"     => SERVICE_DISPLAYNAME,
        "description"      => SERVICE_DESCRIPTION,
        "start_type"       => Win32::Service::AUTO_START
      )
    end
  end
end

