$:.push("#{File.dirname(__FILE__)}/../../lib/Verbs")
$:.push("#{File.dirname(__FILE__)}/../../lib/util")
$:.push("#{File.dirname(__FILE__)}/..")

require 'MiqVerbs'
require 'ostruct'
require 'miq-encode'
require 'MiqThreadCtl'
require 'platform'
require 'yaml'
require 'win32/process' if Platform::OS == :win32

module Manageiq
  class ProcessQueue
    @@gPid = 0
    
    def initialize(cfg, queueName="default_queue", options = {})
      @miqp = MiqParser.new(cfg)
      @options = {:timeout=>0, :persist=>false}.merge(options)
      @tasks = []
      @qName = queueName
      @stats = {:total=>0, :errors=>0, :name=>queueName}
      @taskFile = File.join(cfg.dataDir, "pq-#{queueName}.yaml")
      @syncQueue = (queueName == "sync") ? true : false
      @current_task = {}
      @continue = true
      unless @syncQueue
        loadQueueFile() if @options[:persist]
        MiqThreadCtl << @taskloopThread = Thread.new {taskLoop}
      end
    end
    
    def taskLoop
			begin
				while MiqThreadCtl.continue?
					if !@tasks.empty? && @continue == true
						# Pull the first item off the array
						currTask = @tasks.shift
						pid = @@gPid = @@gPid.next

            self.set_current_task(currTask, pid)
            
						# There is no one watching for exceptions, so ignore
						if forkProcess?(currTask)
              parseCommand_fork(currTask, pid)
						else
							parseCommand(currTask, pid)
						end
					else
				    MiqThreadCtl.quiesceExit
						# If no task sleep to give up cpu cycles
						sleep(1)
					end
				end
			rescue Timeout::Error, StandardError => err
				# Make sure we keep the task loop going
				#$log.error "taskLoop: [#{err.to_s}]"
				#$log.error err.backtrace
				sleep(1)
				retry
			end
    end
	
		def forkProcess?(currTask)
			# If we are fleecing on ESX/linux spawn off a separate process
			# to better use process/memory resources.		
			["scanmetadata","syncmetadata"].include?(currTask[0]) && Platform::IMPL == :linux
			#return false
		end
    
    def parseCommand (args, pid=nil)
      @stats[:total] += 1
      if pid.nil?
        pid = @@gPid = @@gPid.next
        self.set_current_task(args, pid)
      end
      $log.info "#{print_hex_pid(pid)} Running Command: [#{current_task_string(false)}]"
      startTime = Time.now

      # Call MiqVerbs here to run the command
      begin
				ret = Timeout::timeout(@options[:timeout]) do
					@miqp.clearRet
					@miqp.parse(args.flatten)
					@miqp.miqRet
				end
			rescue Exception => errObject
				ret = OpenStruct.new(:error => errObject.backtrace.join("\n"))
      ensure
        # End task logic
        if ret.error
          @stats[:errors] += 1

          if errObject.class == Timeout::Error
            $log.error "#{print_hex_pid(pid)} Command [#{args[0]}] timed out after [#{Time.now-startTime}] seconds.  #{print_task_id(args)}  Type:[#{errObject.nil? ? "NA" : errObject.class}]"
          else
            $log.error "#{print_hex_pid(pid)} Command [#{args[0]}] failed after [#{Time.now-startTime}] seconds.  #{print_task_id(args)}  Type:[#{errObject.nil? ? "NA" : errObject.class}]"
            print_backtrace(ret.error, pid)
          end

          if errObject.class == NoMemoryError
            $log.fatal "Initiating program restart due to error:[NoMemoryError]"
            $miqHostServer.restart()
          end
        else
          #        puts "#{print_hex_pid(pid)} Command Returned: [#{ret.value.strip}]"
          $log.info "#{print_hex_pid(pid)} Command [#{args[0]}] completed successfully in [#{Time.now-startTime}] seconds.  #{print_task_id(args)}"
        end
      end

      # Update current task information
      self.clear_current_task()
      updatePendingTasks()
      
      yield(ret) if block_given?      
      raise ret.error if ret.error
      return ret.value if ret.value
    end

    def parseCommand_fork(args, pid)
      fpid = fork do
        # Set the module description so init.d does not send the
        # shutdown message to this forked process
        $0 = "miqscanner"
        @current_task[:process_id] = Process.pid
        parseCommand(args, pid)
      end
      @current_task[:process_id] = fpid
      begin
        startTime = Time.now
        ret = Timeout::timeout(@options[:timeout]) do
          $log.info "#{print_hex_pid(pid)} Waiting for external process [#{fpid}] to complete.  Timeout: [#{@options[:timeout]}]"
          fstatus = Process.waitpid2(fpid)
          $log.info "#{print_hex_pid(pid)} External process [#{fpid}] completed.  Status: [#{fstatus[1].inspect}]"
        end
      rescue Exception => errObject
        if errObject.kind_of?(Timeout::Error)
          # Thread the stopping so we can block on the pid and report status
          Thread.new {sleep(2); stop_current_task()}
          fstatus = Process.waitpid2(fpid)
          $log.info "#{print_hex_pid(pid)} External process [#{fpid}] completed.  Status: [#{fstatus[1].inspect}]"
          $log.error "#{print_hex_pid(pid)} Command [#{args[0]}] timed out after [#{Time.now-startTime}] seconds.  #{print_task_id(args)}  Type:[#{errObject.nil? ? "NA" : errObject.class}]"
        else
          $log.error "#{print_hex_pid(pid)} Command [#{args[0]}] failed after [#{Time.now-startTime}] seconds.  #{print_task_id(args)}  Type:[#{errObject.nil? ? "NA" : errObject.class}]"
          print_backtrace(ret.error, pid)
        end
      ensure
        self.clear_current_task()
      end
    end
  
		def get_task_id(x)
			x.each do |a|
				if a.kind_of?(String) && a.downcase.include?("--taskid")
					taskid = a.split("=")[1]
					taskid = taskid.gsub(/^"/, "").gsub(/"$/, "")
					return taskid if taskid.length > 0
					return nil
				end
			end
			return nil
		end
		
		def add(newTask)
			$log.info "Adding task [#{newTask.flatten.join(" ")[0..255].tr("\n"," ")}] to queue [#{@qName}]"
			@tasks << newTask
			updatePendingTasks()
		end

		def print_hex_pid(pid)
			return sprintf("pid:[%04X]", pid) unless pid.nil?
			""
		end

		def print_task_id(x)
			taskid = get_task_id(x)
			return "TaskId:[#{taskid}]" unless taskid.nil?
			return ""
		end
		
		def print_backtrace(errStr, pid)
			errArray = errStr.strip.split("\n")

      # If the log level is greater than "debug" just dump the first 2 error lines
      errArray = errArray[0,2] if $log.level > 1

 			# Print the stack trace to debug logging level
   		errArray.each {|e| $log.error "#{print_hex_pid(pid)} Error Trace: [#{e}]"}
		end
    
		def queueSize
			@tasks.length
		end

		def stats
			@stats.merge(:pending=>@tasks.length)
		end
		
		def contents
			ret = []

			unless @current_task.empty?
				taskid = get_task_id(@current_task[:command])
				ret << { :taskid => taskid, :status => "running" } unless taskid.nil?
      end
			
			@tasks.each do |task|
				taskid = get_task_id(task)
				ret << { :taskid => taskid, :status => "pending" } unless taskid.nil?
      end

			ret
		end
    
    def current_task_string(include_process_info=true)
      return "" if @current_task.empty?
      task = ""
      task += "#{print_hex_pid(@current_task[:process_queue_id])}-[##{@current_task[:process_id]}] " if include_process_info
      task += "#{@current_task[:command].flatten.join(" ")[0..255].tr("\n"," ")}"
    end

    def processing_pid()
      return nil if @current_task.empty?
      return @current_task[:process_id]
    end

		def updatePendingTasks()
			#
			# Create the configuration file, based on the specified options.
			#
			begin
				if @options[:persist]
					if @tasks.empty?
						File.delete(@taskFile) if File.exist?(@taskFile)
					else
						File.open(@taskFile, 'w') { |cf| YAML.dump(@tasks, cf)}
					end
				end
			rescue => e
				$log.error e
			end
		end
    
		def loadQueueFile()
			begin
				prevTasks = YAML.load_file(@taskFile) if File.exist?(@taskFile)
				@tasks = prevTasks if prevTasks.is_a?(Array)
			rescue => e
				$log.error e
			end
		end
    
		# Return the current global pid counter
		def self.total
			@@gPid
		end

    def set_current_task(task_str, pid)
      @current_task.clear
      @current_task[:process_id] = Process.pid
      @current_task[:process_queue_id] = pid
      @current_task[:command] = task_str
      @current_task[:thread] = Thread.current
    end

    def clear_current_task
      @current_task.clear
    end

    def clear_queue_items(options=nil)
      # Check that the current queue name is specified
      return if !options[:queue_name].nil? && !options[:queue_name].to_miq_a.include?(@qName)
      $log.debug "(ProcessQueue:clear_queue_items) Queue:[#{@qName}] Options:[#{options.inspect}]"

      begin
        self.stop()

        # If no task_id clear all tasks from this queue
        if options[:task_id].nil?
          $log.info "(ProcessQueue:clear_queue_items) Queue:[#{@qName}] clearing all processes"
          @tasks.clear()
          stop_current_task()
        else
          $log.info "(ProcessQueue:clear_queue_items) Queue:[#{@qName}] clearing process with task id [#{options[:task_id]}]"
          options[:task_id].to_miq_a.each do |task_id|
            stop_current_task() if task_id == get_task_id(@current_task[:command])
            @tasks.delete_if {|task| task_id == get_task_id(task)}
          end
        end
      ensure
        updatePendingTasks()
        self.run()
      end
    end

    def stop_current_task()
      unless @current_task.empty?
        if @current_task[:process_id] == Process.pid
#          $log.info "Stopping thread [#{@current_task[:thread].id}]  Alive?: [#{@current_task[:thread].alive?}]  [#{Thread.current.id}]"
#          Thread.kill(@current_task[:thread])
#          $log.info "Stopped thread [#{@current_task[:thread].id}]  Alive?: [#{@current_task[:thread].alive?}]"
        else
          $log.info "Stopping queue process [#{@current_task[:process_id]}] running command [#{current_task_string(true)}]"
          Process.kill(9, @current_task[:process_id])
        end
      end
    end

    def shutdown()
      $log.debug "Shutting down queue [#{@qName}]"
      self.stop
      self.stop_current_task()
      $log.debug "Queue [#{@qName}] shutdown complete."
    end

    def stop
      $log.debug "Halting processing for queue: [#{@qName}]"
      @continue = false
    end

    def run
      $log.debug "Resuming processing for queue: [#{@qName}]"
      @continue = true
    end    
	end # Class ProcessQueue
end # module Manageiq
