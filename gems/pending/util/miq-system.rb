require 'util/extensions/miq-blank'
require 'awesome_spawn'
require 'sys-uname'
if Sys::Platform::OS == :windows
  require 'util/win32/miq-wmi'
end

class MiqSystem
  @@cpu_usage_vmstat_output_mtime = nil
  @@cpu_usage_computed_value      = nil

  def self.cpu_usage
    if Sys::Platform::IMPL == :linux
      filename = "/var/www/miq/vmdb/log/vmstat_output.log"

      begin
        mtime = File.mtime(filename)
      rescue Errno::ENOENT => err
        @@cpu_usage_vmstat_output_mtime = @@cpu_usage_computed_value = nil
        return nil
      end

      # If older than 2 minutes or is in the future, consider stale and useless
      now = Time.now
      if (mtime < (now - 120)) || (mtime > now)
        @@cpu_usage_vmstat_output_mtime = @@cpu_usage_computed_value = nil
        return nil
      end

      return @@cpu_usage_computed_value if mtime == @@cpu_usage_vmstat_output_mtime

      @@cpu_usage_vmstat_output_mtime = mtime
      @@cpu_usage_computed_value      = nil

      line = MiqSystem.tail(filename, 1)

      return nil if line.nil? || line.length == 0 || line[0].nil?
      idle = line[0].strip.split[14]
      if /^[0-9]+$/ =~ idle
        @@cpu_usage_computed_value = (100 - idle.to_i)
        return @@cpu_usage_computed_value
      end
    end

    nil
  end

  def self.num_cpus
    return unless Sys::Platform::IMPL == :linux
    require 'linux_admin'
    @num_cpus ||= LinuxAdmin::Hardware.new.total_cores
  end

  def self.memory
    result = {}
    case Sys::Platform::IMPL
    when :mswin, :mingw
      # raise "MiqSystem.memory: Windows Not Supported"
    when :linux
      filename = "/proc/meminfo"
      data = nil
      File.open(filename, 'r') { |f| data = f.read_nonblock(10000) }

      data.to_s.each_line do |line|
        key, value = line.split(":")
        value = value.strip

        valueArray = value.split(" ")

        value = value.to_i                if valueArray.length == 1
        value = valueArray[0].to_i * 1024 if valueArray.length == 2 && valueArray[1].downcase == "kb"

        result[key.strip.to_sym] = value
      end
    when :macosx
      # raise "MiqSystem.memory: Mac OSX Not Supported"
    end

    result
  end

  def self.total_memory
    @total_memory ||= memory[:MemTotal]
  end

  def self.status
    result = {}

    case Sys::Platform::IMPL
    when :mswin, :mingw
      # raise "MiqSystem.status: Windows Not Supported"
    when :linux
      filename = "/proc/stat"
      MiqSystem.readfile_async(filename).to_s.split("\n").each do |line|
        x                  = line.split(' ')
        key                = x.shift
        result[key.to_sym] = x
      end
    when :macosx
      # raise "MiqSystem.status: Mac OSX Not Supported"
    end

    result
  end

  def self.disk_usage(file = nil)
    file = normalize_df_file_argument(file)

    case Sys::Platform::IMPL
    when :linux
      # Collect bytes
      result = AwesomeSpawn.run!("df", :params => ["-T", "-P", file]).output.lines.each_with_object([]) do |line, array|
        lArray = line.strip.split(" ")
        next if lArray.length != 7
        fsname, type, total, used, free, used_percentage, mount_point = lArray
        next unless total =~ /[0-9]+/
        next if array.detect { |hh| hh[:filesystem] == fsname }

        array << {
          :filesystem         => fsname,
          :type               => type,
          :total_bytes        => total.to_i * 1024,
          :used_bytes         => used.to_i * 1024,
          :available_bytes    => free.to_i * 1024,
          :used_bytes_percent => used_percentage.chomp("%").to_i,
          :mount_point        => mount_point,
        }
      end

      # Collect inodes
      AwesomeSpawn.run!("df", :params => ["-T", "-P", "-i", file]).output.lines.each do |line|
        lArray = line.strip.split(" ")
        next if lArray.length != 7
        fsname, type, total, used, free, used_percentage, mount_point = lArray
        next unless total =~ /[0-9]+/
        h = result.detect { |hh| hh[:filesystem] == fsname }
        next if h.nil?

        h[:total_inodes]        = total.to_i
        h[:used_inodes]         = used.to_i
        h[:available_inodes]    = free.to_i
        h[:used_inodes_percent] = used_percentage.chomp("%").to_i
      end
      result

    when :macosx
      AwesomeSpawn.run!("df", :params => ["-ki", file]).output.lines.each_with_object([]) do |line, array|
        lArray = line.strip.split(" ")
        next if lArray.length != 9
        fsname, total, used, free, use_percentage, iused, ifree, iuse_percentage, mount_point = lArray
        next unless total =~ /[0-9]+/
        next if array.detect { |hh| hh[:filesystem] == fsname }

        array << {
          :filesystem          => fsname,
          :total_bytes         => total.to_i * 1024,
          :used_bytes          => used.to_i * 1024,
          :available_bytes     => free.to_i * 1024,
          :used_bytes_percent  => use_percentage.chomp("%").to_i,
          :total_inodes        => iused.to_i + ifree.to_i,
          :used_inodes         => iused.to_i,
          :available_inodes    => ifree.to_i,
          :used_inodes_percent => iuse_percentage.chomp("%").to_i,
          :mount_point         => mount_point,
        }
      end
    end
  end

  def self.normalize_df_file_argument(file = nil)
    # limit disk usage to local filesystems if no file provided
    return "-l" if file.blank?

    raise "file #{file} does not exist" unless File.exist?(file)
    file
  end

  def self.arch
    arch = Sys::Platform::ARCH
    case Sys::Platform::OS
    when :unix
      if arch == :unknown
        p = Gem::Platform.local
        arch = p.cpu.to_sym
      end
    end
    arch
  end

  def self.tail(filename, last)
    return nil unless File.file?(filename)

    lines = nil
    if Sys::Platform::OS == :unix
      tail  = `tail -n #{last} #{filename}` rescue nil
      tail.force_encoding("BINARY") if tail.respond_to?(:force_encoding)
      lines = tail.nil? ? [] : tail.split("\n")
    end

    lines
  end

  def self.retryable_io_errors
    @retryable_io_errors ||= defined?(IO::WaitReadable) ? [IO::WaitReadable] : [Errno::EAGAIN, Errno::EINTR]
  end

  def self.readfile_async(filename, maxlen = 10000)
    data = nil
    File.open(filename, 'r') do |f|
      begin
        data = f.read_nonblock(maxlen)
      rescue *retryable_io_errors
        IO.select([f])
        retry
      rescue EOFError
        # Not sure what the data variable contains
      end
    end if File.exist?(filename)

    data
  end

  def self.open_browser(url)
    require 'shellwords'
    case Sys::Platform::IMPL
    when :macosx        then `open #{url.shellescape}`
    when :linux         then `xdg-open #{url.shellescape}`
    when :mingw, :mswin then `start "#{url.gsub('"', '""')}"`
    end
  end
end

if __FILE__ == $0
  def number_to_human_size(size, precision = 1)
    size = Kernel.Float(size)
    case
    when size == (1024**0) then "1 Byte"
    when size < (1024**1) then "%d Bytes" % size
    when size < (1024**2) then "%.#{precision}f KB" % (size / (1024.0**1))
    when size < (1024**3) then "%.#{precision}f MB" % (size / (1024.0**2))
    when size < (1024**4) then "%.#{precision}f GB" % (size / (1024.0**3))
    else                      "%.#{precision}f TB" % (size / (1024.0**4))
    end.sub(".%0#{precision}d" % 0, '')    # .sub('.0', '')
  end

  result = MiqSystem.memory
  puts "Memory: #{result.inspect}"

  result = MiqSystem.disk_usage
  format_string = "%-12s %6s %12s %12s %12s %12s %12s %12s %12s %12s %12s"
  header = format(format_string,
                  "Filesystem",
                  "Type",
                  "Total",
                  "Used",
                  "Available",
                  "%Used",
                  "iTotal",
                  "iUsed",
                  "iFree",
                  "%iUsed",
                  "Mounted on")
  puts header

  result.each { |disk|
    formatted = format(format_string,
                       disk[:filesystem],
                       disk[:type],
                       number_to_human_size(disk[:total_bytes]),
                       number_to_human_size(disk[:used_bytes]),
                       number_to_human_size(disk[:available_bytes]),
                       "#{disk[:used_bytes_percent]}%",
                       disk[:total_inodes],
                       disk[:used_inodes],
                       disk[:available_inodes],
                       "#{disk[:used_inodes_percent]}%",
                       disk[:mount_point]
                      )
    puts formatted
  }

end
