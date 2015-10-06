require 'util/runcmd'

class NetUseShare
  attr_reader :cmdMsg, :cmdRc

  def initialize(server, shareName)
    @server = server
    @shareName = shareName
    @connected = false
  end

  def connect(username, password)
    # Run 'net use' command and get return message.  Return code
    # for the process is stored in $0
    begin
      @cmdMsg = MiqUtil.runcmd("net use #{sharePath} /USER:#{logon_username(username)} #{password}")
      @connected = true
    rescue => err
      @connected = false
      @cmdMsg = err.to_s
    end
    @cmdRc = $?.exitstatus
    @connected
  end

  def logon_username(username)
    return nil if username.nil?

    # Check for usernames that supplied the domain as well
    # Example manageiq\user1 or just user1
    return username if username.include?("\\")

    # If we just have a username append the server name to it.  Otherwise
    # connecting will fail when running in SYSTEM context.
    "#{@server}\\#{username}"
  end

  def sharePath
    "\\\\#{@server}\\#{@shareName}"
  end

  def connected?
    @connected
  end

  def disconnect
    if connected?
      begin
        @cmdMsg = MiqUtil.runcmd("net use #{@shareName} /DELETE")
        @connected = false
      rescue => err
        @cmdMsg = err.to_s
      end
      @cmdRc = $?.exitstatus
    end
  end

  def copyTo(srcFile)
    newPath = File.join(sharePath, File.basename(srcFile))
    newPath.tr!("/", "\\")
    srcFile.tr!("\\", "/")
    require 'fileutils'
    FileUtils.copy(srcFile, newPath)
    File.utime(File.atime(srcFile), File.mtime(srcFile), newPath)
    newPath
  end

  def deleteFile(fileName)
    if connected?
      begin
        @cmdMsg = MiqUtil.runcmd("del #{fileName}")
      rescue => err
        @cmdMsg = err.to_s
      end
      @cmdRc = $?.exitstatus
    end
  end
end
