$:.push("#{File.dirname(__FILE__)}/../../util")

require 'miq-hash_struct'
require 'miq-xml'

require 'InitProcHash'

module MiqLinux
    
    class InitProcs
        
        INIT_DIRS   = [ "/etc/rc.d/init.d", "/etc/init.d" ]
        RC_DIRS     = [ "/etc/rc.d", "/etc", "/etc/init.d" ]
        RC_CHECK    = [ "rc0.d", "runlevels" ]
        RUN_LEVELS1 = [ '0', '1', '2', '3', '4', '5', '6', 'S' ]
        RUN_LEVELS2 = [ 'boot', 'default', 'network', 'single' ]
        
        def initialize(fs)
            @fs = fs
            @scriptsByName = Hash.new
            
            #
            # Try to determine where the system's init.d directory is.
            #
            $log.debug "Determining init script directory..."
            @init_dir = nil
            INIT_DIRS.each do |id|
                $log.debug "\tChecking: #{id}"
                next if !@fs.fileExists?(id)
                $log.debug "\tFound init script directory: #{id}"
                @init_dir = id
                break
            end
            if !@init_dir
                $log.warn "Could not determine init script directory."
                return
            end
            
            #
            # Try to determine where the system keeps its runlevel scripts.
            # NOTE: Gentoo is a special case. It uses "named" runlevel directories
            # under the directory "runlevels". As opposed to rc?.d directories.
            #
            $log.debug "Determining RC script directory..."
            @rc_dir = nil
            @rc_chk = nil
            RC_DIRS.each do |rd|
                $log.debug "\tChecking: #{rd}"
                next if !@fs.fileExists?(rd)
                
                RC_CHECK.each do |rcc|
                    next if !@fs.fileExists?(File.join(rd, rcc))
                    @rc_chk = rcc
                    break
                end
                break if !@rc_chk
                
                $log.debug "\tFound init script directory: #{rd} - checked: #{@rc_chk}"
                @rc_dir = rd
                break
            end
            if !@rc_dir
                $log.warn "Could not determine RC script directory."
                return
            end
            
            @fs.dirForeach(@init_dir) do |fn|
                next if @fs.fileDirectory?(File.join(@init_dir, fn))
                name = @fs.fileBasename(fn, ".sh")
                next if name.downcase == "readme" || name == "." || name == ".."
                
                addScript(@init_dir, fn, name)
            end
            
            if @rc_chk == "runlevels"
                @rc_dir = File.join(@rc_dir, @rc_chk)
                @run_levels = RUN_LEVELS2
            else
                @run_levels = RUN_LEVELS1
            end
            
            @run_levels.each do |rl|
                if @rc_chk == "runlevels"
                    rld = File.join(@rc_dir, rl)
                else
                    rld = File.join(@rc_dir, "rc#{rl}.d")
                end
                
                next if !@fs.fileDirectory?(rld)
                @fs.dirForeach(rld) do |fn|
                    # If it's not a start of kill script, skip it.
                    next if fn[0,1] != "S" && fn[0,1] != "K" && @rc_chk != "runlevels"
                    # Full path to file.
                    fp = File.join(rld, fn)
                    # If the file isn't a symbolic link, skip it.
                    next if !@fs.fileSymLink?(fp)
                    lp = @fs.getLinkPath(fp)
                    
                    # The init.d script to which the file is linked.
                    name = @fs.fileBasename(lp, ".sh")
                    
                    addScript(@fs.fileDirname(lp), @fs.fileBasename(lp), name) if !@scriptsByName[name]
                    
                    sk = (@rc_chk == "runlevels" ? 'S' : fn[0,1])
                    @scriptsByName[name].runLevels[sk] << rl
                end
            end
        end
        
        def addScript(dir, fn, name)
            s = MiqHashStruct.new
            s.name = name
            s.path = File.join(dir, fn)
            s.desc = getDesc(s.path, name)
            s.runLevels = Hash.new
            s.runLevels['S'] = []
            s.runLevels['K'] = []
            @scriptsByName[name] = s
        end
        
        def toXml(doc=nil)
            doc = MiqXml.createDoc(nil) if !doc
            
            @scriptsByName.each_value do |s|
                ip = doc.add_element("service", {"name"=> s.name, "image_path" => s.path, "typename" => "linux_initprocess"})
								ip.attributes["description"] = s.desc if s.desc
                
                s.runLevels['S'].each { |rl| ip.add_element("enable_run_level", {"value"=> rl}) }
                s.runLevels['K'].each { |rl| ip.add_element("disable_run_level", {"value"=> rl}) }
            end
        end
        
        private
        
        def getDesc(f, n)
            fdata = ""
            begin
                @fs.fileOpen(f) { |fo| fdata = fo.read }
                fdata.each_line { |fl| return $1 if fl =~ /^\s*#\s+Short-Description:\s*(.*)$/ } unless fdata.nil?
                return InitProcHash[n]
            rescue => err
                $log.warn "getDesc: could not open #{f} - #{err.to_s}"
                return ""
            end
        end
        
    end # class InitProcs
    
end # module MiqLinux
