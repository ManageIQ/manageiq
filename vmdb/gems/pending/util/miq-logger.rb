require 'miq-extensions'

# If a global log handle has already been defined do not load these classes
# This allows for miqverbs to be loaded under vmdb.
if $log.nil?
  require 'rubygems'  
  require 'log4r'
  require 'log4r/configurator'
  require 'time'
  require 'platform'
  require 'MiqSockUtil'

  #Define custom logging level to insert the "Summary" level
  Log4r::Configurator.custom_levels(:DEBUG, :INFO, :WARN, :ERROR, :FATAL, :SUMM)

  class MIQLoggerFormatter < Log4r::Formatter
    def format(e)
      t = Time.now.getutc
      "[----] %s, [%s #%04s:%d] %5s -- : %s\n" % [Log4r::LNAMES[e.level][0..0], t.iso8601(6).chop, Process.pid, Thread.current.object_id, Log4r::LNAMES[e.level], e.data.to_s]
    end
  end

  class MIQLogger    
    def self.get_log(config, fileName=nil, logName = "toplog")
      log = Log4r::Logger[logName]
      if log.nil?
        log = Log4r::Logger.new(logName)
        p = self.defaultFormatter

        # Initialize logging header
        log.miqLogHeader(fileName, false)

        # If we are not passed a file, we only log to the console
        # Set default logging options here
        # level = debug
        # wrap_size = 10 MB
        # wrap_time = 24 Hrs
        logSettings = {:level=>"DEBUG", :wrap_size=> 10485760,:wrap_time=> 86400, :logDir => ".", :keep=> 10}
        unless fileName.nil?
          unless config.nil?
            logSettings[:logDir] = config.miqLogs if config.miqLogs
            # Make a copy of the current log config hash and delete invalid values (Must be > 0 and fit into a Fixnum)
            logCfgDup = config.log.dup
            [:wrap_size, :wrap_time].each {|f| logCfgDup.delete(f) if (logCfgDup[f].to_i <= 0 || logCfgDup[f].to_i.class != Fixnum)}

            # Now that we have checked for valid values we need to enforce minimun settings
            # Time = 30 mins; Size = 1 MB
            # If the values are not defined let them pick up the defaults from logSettings
            logCfgDup[:wrap_time] = (30*60) if logCfgDup[:wrap_time] && logCfgDup[:wrap_time].to_i < (30*60)
            logCfgDup[:wrap_size] = (1*1048576) if logCfgDup[:wrap_size] && logCfgDup[:wrap_size].to_i < (1*1048576)

            logSettings = logSettings.merge(logCfgDup)
          end
          
          logConfig = {
            :filename => File.join(logSettings[:logDir], self.getLogName(fileName, config)),
            :maxsize => logSettings[:wrap_size],
            :maxtime => logSettings[:wrap_time],
            :trunc => false,
            :formatter => MIQLoggerFormatter
          }
          log.outputters = Log4r::RollingFileOutputter.new(logName, logConfig)

          log.addPostRollEvent(:log_cleanup, true) {cleanup_logs(logSettings[:logDir], File.basename(fileName, ".*"), logSettings[:keep], log)}
        end

        # If we are not running as an NT service, log to the console as well.
        log.add(Log4r::StdoutOutputter.new('stdout' , :formatter => MIQLoggerFormatter)) unless ENV["HOMEDRIVE"].nil?

        # Set default log level
        log.level = eval('Log4r::' + logSettings[:level].upcase)

        # Logger header here which might product duplicates if running from the scripts
        log.miqLogHeader #unless Platform::OS == :win32
      end
      return log
    end
    
    def self.cleanup_logs(targetDir, basename, miqhost_keep, log)
      files = self.collect_filenames(targetDir, basename, log)
      if files.length > miqhost_keep.to_i
        miqhost_keep.to_i.times{files.pop}
        files.each{|file| 
          log.info "MIQ(MIQLogger-cleanup_logs), deleting #{file}" if log.respond_to?(:info)
          File.delete(file[:filename])}
      end
    end
    
    def self.collect_filenames(dir, basename, log)
      begin      
        files = Array.new
        Dir.glob(File.join(dir, "#{basename}*.log")).each do |file|
          files.push(:filename=>file, :ctime=>File.ctime(file))
        end
        files.sort!{ |file1, file2| file1[:ctime]<=>file2[:ctime]}
        return files    
      rescue => error
        log.error "MIQ(MIQLogger-collect_filenames): #{error}" if log.respond_to?(:error)
      end
    end

    # Create filename
    # filename + hostname + module_version + current date/time
    def self.getLogName(fileName, config)
      name = File.basename(fileName, ".*") 
      begin
        name += "-" + MiqSockUtil.getHostName.strip.downcase
      rescue
      end
      #name += "-" + config.host_version.join(".") if config
      name += "-" + config.host_version[-1].to_s if config
      name += "-" + Time.now.utc.iso8601.gsub!("-","")
      name += "-.log"
      name.gsub!(":","").gsub!("@","-")
      return name
    end

    def self.defaultFormatter
      Log4r::PatternFormatter.new(:pattern => "[%5l] %d: %m")
    end
  end

  module Log4r
    class Logger
      def summary args
        self.summ args
      end

      def addPostRollEvent(name, run_now=false, &blk)
        self.outputters.each do |o|
          if o.respond_to?("addLogRollEvent")
            o.addLogRollEvent(name, :post, &blk)
          end
        end

        yield if run_now == true
      end

      def miqLogHeader(fileName=nil, logData=true)
        # Log an opening message framed in "*" chars
        @miqFileName = fileName if fileName
        if logData == true && @miqFileName.nil? == false
          init_msg = "* [#{File.basename(@miqFileName, ".*")}] [#{Platform::IMPL}] started on [#{Time.now}] *"
          border = "*" * init_msg.length; 
          self.summary border
          self.summary init_msg 
          self.summary border
          self.summary "Current log level:[#{Log4r::LNAMES[self.level]}]"
        end
      end
    end

    class RollingFileOutputter
      alias roll_old roll

      def roll
        runLogRollEvents(:pre)
        oldFileName = @filename
        deleteOldFile = false

        # Write a footer into the log so it is clear that it is the end
        begin
          # If count is zero then we are rolling for the first time and nothing has been written to this file
          # so skip this and delete the file after rolling so we do not leave an empty file around.
          if self.count.zero?
            deleteOldFile = true
          else
            t = Time.now.getutc
            @out.print "[9999] %s, [%s #%04s:%d] %5s -- : %s\n" % ["I", t.iso8601(6).chop, Process.pid, Thread.current.object_id, "INFO", "ROLLING LOG [#{File.basename(@filename)}]"]
          end
        rescue
        end

        # Call the original roll method so the file switch happens
        roll_old

        # Cleanup the old file which is empty because the log roller runs immediately when first started.
        # Note: Newer versions of Log4r (~1.1.4) no longer create this empty file as part of the startup, so check
        #       for its existance before getting the size.
        File.delete(oldFileName) if deleteOldFile == true && File.exist?(oldFileName) && File.size(oldFileName) == 0

        runLogRollEvents(:post, oldFileName)
      end

      def addLogRollEvent(name, mode=:post, &blk)
        @logRollBlock ||= []
        @logRollBlock << {:name=> name, :mode=> mode, :block => blk}
      end

      def runLogRollEvents(mode, oldFileName = nil)
        Thread.new do
          # Load up the parent logging handle for this outputter so we
          # can log to it if needed.
          log = Log4r::Logger[self.name]

          # Add our header to the top of the new log
          if log && mode == :post
            log.summary "Log rolling from [#{File.basename(oldFileName)}] to [#{File.basename(@filename)}] in [#{File.dirname(@filename)}]"
            log.miqLogHeader
          end

          # If there is nothing registered get out.
          return if @logRollBlock.nil?

          # Execute each registered block
          @logRollBlock.each do |event| 
            begin
              if event[:mode] == :pre
                event[:block].call(@filename)
              elsif event[:mode] == :post
                event[:block].call(@filename, oldFileName)
              end
            rescue => e
              log.error "ERROR: = [#{e}]" if log
            end
          end
        end #  Thread.new
      end  # runLogRollEvents
    end	# class RollingFileOutputter
  end # module Log4r
end
