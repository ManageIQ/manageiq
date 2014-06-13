$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/win32")
require 'rubygems'
require 'platform'
require 'runcmd'
require 'miq-wmi'
require 'miq-system'
if Platform::OS == :win32
  require 'win32/miq-win32-process'
end

class MiqProcess

  def self.get_active_process_by_name(process_name)
    pids = []

    case Platform::IMPL
    when :mswin, :mingw
      WMIHelper.connectServer().run_query("select Handle,Name from Win32_Process where Name = '#{process_name}.exe'") {|p| pids << p.Handle.to_i}
    when :linux, :macosx
      pids = %x(ps -e | grep #{process_name} | grep -v grep ).split("\n").collect { |r| r.to_i}
    else
      raise "Method MiqProcess.get_active_process_by_name not implemented on this platform [#{Platform::IMPL}]"
    end
    return pids
  end

  def self.linux_process_stat(pid = nil)
    pid ||= Process.pid

    filename = "/proc/#{pid}/stat"
    raise Errno::ESRCH.new(pid.to_s) unless File.exists?(filename)

    result = { :pid => pid }
    raw_stats = MiqSystem.readfile_async(filename)
    unless raw_stats.nil?
      stats = raw_stats.split(" ")
      if pid.to_s == stats.shift
        result[:name]                  = stats.shift.gsub(/(^\(|\)$)/, '')
        result[:state]                 = stats.shift
        result[:ppid]                  = stats.shift.to_i
        result[:pgrp]                  = stats.shift.to_i
        result[:session]               = stats.shift.to_i
        result[:tty_nr]                = stats.shift.to_i
        result[:tpgid]                 = stats.shift.to_i
        result[:flags]                 = stats.shift
        result[:minflt]                = stats.shift.to_i
        result[:cminflt]               = stats.shift.to_i
        result[:majflt]                = stats.shift.to_i
        result[:cmajflt]               = stats.shift.to_i
        result[:utime]                 = stats.shift.to_i
        result[:stime]                 = stats.shift.to_i
        result[:cutime]                = stats.shift.to_i
        result[:cstime]                = stats.shift.to_i
        result[:priority]              = stats.shift.to_i
        result[:nice]                  = stats.shift.to_i
        result[:num_threads]           = stats.shift.to_i
        result[:itrealvalue]           = stats.shift.to_i
        result[:starttime]             = stats.shift.to_i
        result[:vsize]                 = stats.shift.to_i
        result[:rss]                   = stats.shift.to_i
        result[:rsslim]                = stats.shift.to_i
        result[:startcode]             = stats.shift.to_i
        result[:endcode]               = stats.shift.to_i
        result[:startstack]            = stats.shift.to_i
        result[:kstkesp]               = stats.shift.to_i
        result[:kstkeip]               = stats.shift.to_i
        result[:signal]                = stats.shift
        result[:blocked]               = stats.shift
        result[:sigignore]             = stats.shift
        result[:sigcatch]              = stats.shift
        result[:wchan]                 = stats.shift.to_i
        result[:nswap]                 = stats.shift.to_i
        result[:cnswap]                = stats.shift.to_i
        result[:exit_signal]           = stats.shift.to_i
        result[:processor]             = stats.shift.to_i
        result[:rt_priority]           = stats.shift.to_i
        result[:policy]                = stats.shift.to_i
        result[:delayacct_blkio_ticks] = stats.shift.to_i
        result[:guest_time]            = stats.shift.to_i
        result[:cguest_time]           = stats.shift.to_i
      end
    end

    result
  end

  def self.processInfo(pid = nil)
    pid ||= Process.pid

    result = { :pid => pid }

    case Platform::IMPL
    when :mswin, :mingw
      # WorkingSetSize: The amount of memory in bytes that a process needs to execute efficiently, for an operating system that uses
      #                 page-based memory management. If an insufficient amount of memory is available (< working set size), thrashing will occur.
      # KernelModeTime: Time in kernel mode, in 100 nanoseconds
      # UserModeTime  : Time in user mode, in 100 nanoseconds.
      wmi = WMIHelper.connectServer()
      self.process_list_wmi(wmi, pid).each_pair {|k,v| result = v }
      wmi.release
    when :linux
      x = MiqProcess.linux_process_stat(pid)
      result[:name]           = x[:name]
      result[:priority]       = x[:priority]
      result[:memory_usage]   = x[:rss] * 4096
      result[:memory_size]    = x[:vsize]
      percent_memory          = (1.0 * result[:memory_usage]) / MiqSystem.total_memory
      result[:percent_memory] = self.round_to(percent_memory * 100.0, 2)
      result[:cpu_time]       = x[:stime] + x[:utime]
      cpu_status              = MiqSystem.status[:cpu]
      cpu_total               = (0..3).inject(0) { |sum,x| sum + cpu_status[x].to_i }
      cpu_total               = cpu_total / MiqSystem.num_cpus
      percent_cpu             = (1.0 * result[:cpu_time]) / cpu_total
      result[:percent_cpu]    = self.round_to(percent_cpu * 100.0, 2)
    when :macosx
      h = nil
      begin
        h = self.process_list_linux("ps -p #{pid} -o pid,rss,vsize,%mem,%cpu,time,pri,ucomm", true)
      rescue 
        raise Errno::ESRCH.new(pid.to_s)
      end
      result = h[pid]
    end

    return result
  end

  def self.command_line(pid)
    case Platform::IMPL
    when :mswin, :mingw
      WMIHelper.connectServer {|wmi| wmi.run_query("select CommandLine from Win32_Process where Handle = '#{pid}'") {|p| return p.CommandLine}}
    when :linux
      filename = "/proc/#{pid}/cmdline"
      cmdline = MiqSystem.readfile_async(filename)
      return cmdline.gsub("\000", " ").strip unless cmdline.nil?
      rc = `ps --pid=#{pid} -o ucomm,command --no-headers`
      return rc unless rc.strip.empty?
    when :macosx
      rc = `ps -p #{pid} -o ucomm,command`
      rows = rc.split("\n")

      # We always get the header back on Mac, so make sure there is more than just the header
      return rows.last.strip if rows.length > 1
    end

    return nil
  end

  def self.alive?(pid)
    raise NotImplementedError, "Method MiqProcess.alive? not implemented on this platform [#{Platform::IMPL}]" unless Platform::OS == :unix

    begin
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end
  end

  def self.is_worker?(pid)
    command_line = self.command_line(pid)
    return command_line && command_line =~ /^ruby.+(runner|mongrel_rails)/
  end

  LINUX_STATES = {
    'I' => :idle,             # Marks a process that is idle (sleeping for longer than about 20 seconds).
    'R' => :runnable,         # Marks a runnable process.
    'S' => :sleeping,         # Marks a process that is sleeping for less than about 20 seconds.
    'T' => :stopped,          # Marks a stopped process.
    'U' => :waiting,          # Marks a process in uninterruptible wait.  (MacOS X)
    'D' => :waiting,          # Marks a process in uninterruptible wait.  (Linux)
    'Z' => :zombie            # Marks a dead process (a ``zombie'').
  }

  def self.state(pid)
    raw_state = nil

    case Platform::IMPL
    when :mswin, :mingw
      # TODO
    when :linux
      raw_state = self.linux_process_stat(pid)[:state]
    when :macosx
      rc = `ps -p #{pid} -o stat`
      rows = rc.split("\n")

      # We always get the header back on Mac, so make sure there is more than just the header
      raw_state = rows.last.strip if rows.length > 1
    end

    LINUX_STATES[raw_state.to_s.first]
  end

  # cmd can be a Regex or String
  def self.find_pids(cmd)
    pids = []

    case Platform::IMPL
    when :linux
      Dir['/proc/[0-9]*/cmdline'].each do |filename|
        cmdline = MiqSystem.readfile_async(filename)
        next if cmdline.nil?
        if cmd == cmdline.gsub("\000", " ").strip
          pid = filename.split('/')[2]
          pids << pid.to_i
        end
      end
    else
      raise NotImplementedError, "Method MiqProcess.find_pids not implemented on this platform [#{Platform::IMPL}]"
    end

    return pids
  end

  def self.get_child_pids(pid = nil)
    pid ||= Process.pid

    result = []

    case Platform::IMPL
    when :linux
      # ps -l --ppid 5320
      # Gets processes whose parent pid is pid
      begin
        output = MiqUtil.runcmd("ps -l --ppid #{pid}")
      rescue => err
        return result
      end
      output.split("\n")[1..-1].each do |line|
        result.push(line.split[3].to_i)
      end
    when :macosx
      output = MiqUtil.runcmd("ps -ea -o pid,ppid ")
      rows = output.split("\n")

      # We always get the header back on Mac, so make sure to throw away the header
      rows.shift

      rows.each do |row|
        sp = row.split(' ')
        row_pid  = sp[0].to_i
        row_ppid = sp[1].to_i

        result << row_pid if row_ppid == pid
      end

    when :mswin, :mingw
      # TODO
    end
    return result
  end

  def self.process_list_all(wmi = nil)
    pl = {}
    return self.process_list_wmi(wmi) unless wmi.nil?

    case Platform::IMPL
    when :mswin, :mingw
      pl = self.process_list_wmi(wmi)
    when :linux
      pl = self.process_list_linux("ps -e -o pid,rss,vsize,%mem,%cpu,time,priority,ucomm --no-headers")
    when :macosx
      pl = self.process_list_linux("ps -e -o pid,rss,vsize,%mem,%cpu,time,pri,ucomm", true)
    end
    return pl
  end

  def self.process_list_wmi(wmi=nil, pid=nil)
      pl = {}
      wmi = WMIHelper.connectServer() if wmi.nil?
      os_data = wmi.get_instance('select TotalVisibleMemorySize from Win32_OperatingSystem')
      proc_query = 'select PageFileUsage,Name,Handle,WorkingSetSize,Priority,UserModeTime,KernelModeTime from Win32_Process'
      proc_query += " where Handle = '#{pid}'" unless pid.nil?
      proc_data = wmi.run_query(proc_query)

      # Calculate the CPU % from a 2 second sampling of the raw perf counters.
      perf_query = 'Select IDProcess,PercentProcessorTime,Timestamp_Sys100NS from Win32_PerfRawData_PerfProc_Process'
      perf_query += " where IDProcess = '#{pid}'" unless pid.nil?
      fh = {}; perf = {}
      wmi.run_query(perf_query).each {|p| fh[p.IDProcess] = {:ppt=>p.PercentProcessorTime.to_i, :ts=>p.Timestamp_Sys100NS.to_i}}
      sleep(2)
      wmi.run_query(perf_query).each do |p|
        m1 = fh[p.IDProcess]
        if m1
          n = p.PercentProcessorTime.to_i - m1[:ppt]
          d = p.Timestamp_Sys100NS.to_i - m1[:ts]
          perf[p.IDProcess.to_i] = 100*n/d
        end
      end

      proc_data.each {|p| next if p.Handle.to_i <= 4; pl[p.Handle.to_i] = self.parse_process_data(:wmi, p, perf, os_data)}
      return pl
  end

  def self.process_list_linux(cmd_str, skip_header=false)
      pl, i = {}, 0
      rc = MiqUtil.runcmd(cmd_str)
      rc.each_line do |ps_str|
        i += 1
        next if i == 1 && skip_header == true
        pinfo = ps_str.strip.split(' ')
        nh = self.parse_process_data(:linux, pinfo, perf=nil, os=nil)
        pl[nh[:pid]] = nh
        pl
      end
      return pl
  end

  def self.parse_process_data(data_type, pinfo, perf=nil, os=nil)
    nh = {}
    if data_type == :wmi
      nh[:pid]            = pinfo.Handle.to_i
      nh[:name]           = pinfo.Name
      nh[:memory_size]    = pinfo.WorkingSetSize.to_i
      nh[:memory_usage]   = nh[:memory_size] - pinfo.PageFileUsage.to_i * 1024
      # Keep the percent format to 2 decimal places
      nh[:percent_memory] = sprintf("%.2f", pinfo.WorkingSetSize.to_f / (os.TotalVisibleMemorySize.to_i * 1024) * 100)
      nh[:cpu_time]       = (pinfo.UserModeTime.to_i + pinfo.KernelModeTime.to_i) / 10000000    # in seconds
      nh[:priority]       = pinfo.Priority.to_i
      nh[:percent_cpu]    = perf[nh[:pid]]
    else
      nh[:pid]            = pinfo[0].to_i
      nh[:memory_usage]   = pinfo[1].to_i * 1024   # Memory in RAM
      nh[:memory_size]    = pinfo[2].to_i * 1024   # Memory in RAM and swap
      nh[:percent_memory] = pinfo[3]
      nh[:percent_cpu]    = pinfo[4]
      nh[:cpu_time]       = self.str_time_to_sec(pinfo[5])
      nh[:priority]       = pinfo[6]
      nh[:name]           = pinfo[7..-1].join(' ')
    end
    return nh
  end

  def self.str_time_to_sec(time_str)
    # Convert format 00:00:00 to seconds
    t = time_str.split(':')
    return (t[0].to_i*3600) + (t[1].to_i*60) + t[2].to_i
  end

  def self.suspend_process(pid)
    case Platform::OS
    when :win32 then Process.process_thread_list[pid].each {|tid| Process.suspend_resume_thread(tid, false)}
    else
      raise "Method MiqProcess.suspend_process not implemented on this platform [#{Platform::IMPL}]"
    end
  end

  def self.resume_process(pid)
    case Platform::OS
    when :win32 then Process.process_thread_list[pid].each {|tid| Process.suspend_resume_thread(tid, true)}
    else
      raise "Method MiqProcess.resume_process not implemented on this platform [#{Platform::IMPL}]"
    end
  end

  def self.round_to(number, precision)
    mult = 10 ** precision
    (number * mult).round.to_f / mult
  end
end

# Examples:
#puts MiqProcess.processInfo().inspect
#puts MiqProcess.process_list_all().inspect
#MiqProcess.process_list_all().each_pair do |k,v|
#  puts v.inspect
#end
