class PlatformConfig
  def initialize(cfg=nil)
    @cfg = cfg
    @files = nil

    if Platform::OS == :win32
      require "InstallWin"
      extend InstallWin
    else
      require "InstallLinux"
      extend InstallLinux
    end

    init
  end # def initialize

  def files=(cfg)
    @files              = Hash.new if @files.nil?
    @files[:miqHome]    = cfg[:miqHome]
    @files[:miqLogs]    = cfg[:miqLogs]
    @files[:miqCfgFile] = cfg[:cfgFile]
    @files[:miqBinDir]  = cfg[:miqBinDir]
  end
end # class PlatformConfig
