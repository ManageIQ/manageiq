$:.push("#{File.dirname(__FILE__)}")
require 'rubygems'
require 'extensions/miq-blank'
require 'platform'
require 'runcmd'
if Platform::OS == :win32
  $:.push("#{File.dirname(__FILE__)}/win32")
  require 'miq-wmi'
end

class MiqSystem

  @@cpu_usage_vmstat_output_mtime = nil
  @@cpu_usage_computed_value      = nil

  def self.cpu_usage
    if Platform::IMPL == :linux
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

    return nil
  end

  def self.num_cpus
    if Platform::IMPL == :linux
      @num_cpus ||= begin
        filename = "/proc/cpuinfo"
        count = 0
        MiqSystem.readfile_async(filename).to_s.split("\n").each do |line|
          next if line.strip.empty?
          count += 1 if (line.split(":").first.strip == 'processor')
        end
        count
      end
    else
      return nil
    end
  end

  ##############################################################################################################################
  # FREE(1)                                                    Linux User’s Manual                                                   FREE(1)
  #
  # NAME
  #        free - Display amount of free and used memory in the system
  #
  # SYNOPSIS
  #        free [-b | -k | -m | -g] [-o] [-s delay ] [-t] [-V]
  #
  # DESCRIPTION
  #        free  displays  the total amount of free and used physical and swap memory in the system, as well as the buffers used by the ker‐
  #        nel.  The shared memory column should be ignored; it is obsolete.
  #
  #    Options
  #        The -b switch displays the amount of memory in bytes; the -k switch (set by default) displays it in kilobytes; the -m switch dis‐
  #        plays it in megabytes; the -g switch displays it in gigabytes.
  #
  #        The -t switch displays a line containing the totals.
  #
  #        The  -o switch disables the display of a "buffer adjusted" line.  If the -o option is not specified, free subtracts buffer memory
  #        from the used memory and adds it to the free memory reported.
  #
  #        The -s switch activates continuous polling delay seconds apart. You may actually specify any floating  point  number  for  delay,
  #        usleep(3) is used for microsecond resolution delay times.
  #
  #        The -V displays version information.
  #
  # FILES
  #        /proc/meminfo
  #               memory information
  #
  # SEE ALSO
  #        ps(1), slabtop(1), vmstat(8), top(1)
  #
  # SAMPLE RUN on Ubuntu
  #
  # $ free -b -t
  #              total       used       free     shared    buffers     cached
  # Mem:    3190689792  865304576 2325385216          0   74690560  110784512
  # -/+ buffers/cache:  679829504 2510860288
  # Swap:   2344120320          0 2344120320
  # Total:  5534810112  865304576 4669505536
  #
  ##############################################################################################################################

  def self.memory
    result = Hash.new
    case Platform::IMPL
    when :mswin, :mingw
      # raise "MiqSystem.memory: Windows Not Supported"
    when :linux
      filename = "/proc/meminfo"
      data = nil
      File.open(filename,'r') { |f| data = f.read_nonblock(10000) }

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

    return result
  end

  def self.total_memory
    @total_memory ||= self.memory[:MemTotal]
  end

  def self.status
    result = Hash.new

    case Platform::IMPL
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

    return result
  end

  ##############################################################################################################################
  # SWAPON(8)                                               Linux Programmer’s Manual                                              SWAPON(8)
  #
  # NAME
  #        swapon, swapoff - enable/disable devices and files for paging and swapping
  #
  # SYNOPSIS
  #        /sbin/swapon [-h -V]
  #        /sbin/swapon -a [-v] [-e]
  #        /sbin/swapon [-v] [-p priority]  specialfile ...
  #        /sbin/swapon [-s]
  #        /sbin/swapoff [-h -V]
  #        /sbin/swapoff -a
  #        /sbin/swapoff specialfile ...
  #
  # DESCRIPTION
  #        Swapon is used to specify devices on which paging and swapping are to take place.
  #
  #        The  device or file used is given by the specialfile parameter. It may be of the form -L label or -U uuid to indicate a device by
  #        label or uuid.
  #
  #        Calls to swapon normally occur in the system multi-user initialization file /etc/rc making all swap devices  available,  so  that
  #        the paging and swapping activity is interleaved across several devices and files.
  #
  #        Normally, the first form is used:
  #
  #        -a     All devices marked as ‘‘swap’’ swap devices in /etc/fstab are made available, except for those with the ‘‘noauto’’ option.
  #               Devices that are already running as swap are silently skipped.
  #
  #        -e     When -a is used with swapon, -e makes swapon silently skip devices that do not exist.
  #
  #        -h     Provide help
  #
  #        -L label
  #               Use the partition that has the specified label.  (For this, access to /proc/partitions is needed.)
  #
  #        -p priority
  #               Specify priority for swapon.  This option is only available if swapon was compiled under and is  used  under  a  1.3.2  or
  #               later  kernel.  priority is a value between 0 and 32767. Higher numbers indicate higher priority. See swapon(2) for a full
  #               description of swap priorities. Add pri=value to the option field of /etc/fstab for use with swapon -a.
  #
  #        -s     Display swap usage summary by device. Equivalent to "cat /proc/swaps".  Not available before Linux 2.1.25.
  #
  #        -U uuid
  #               Use the partition that has the specified uuid.  (For this, access to /proc/partitions is needed.)
  #
  #        -v     Be verbose.
  #
  #        -V     Display version
  #
  #        Swapoff disables swapping on the specified devices and files.  When the -a flag is given, swapping is disabled on all known  swap
  #        devices and files (as found in /proc/swaps or /etc/fstab).
  #
  # NOTE
  #        You should not use swapon on a file with holes.  Swap over NFS may not work.
  #
  # SEE ALSO
  #        swapon(2), swapoff(2), fstab(5), init(8), mkswap(8), rc(8), mount(8)
  #
  # FILES
  #        /dev/hd??  standard paging devices
  #        /dev/sd??  standard (SCSI) paging devices
  #        /etc/fstab ascii filesystem description table
  #
  # HISTORY
  #        The swapon command appeared in 4.0BSD.
  #
  # AVAILABILITY
  #        The  swapon  command  is part of the util-linux-ng package and is available from ftp://ftp.kernel.org/pub/linux/utils/util-linux-
  #        ng/.
  #
  #
  # SAMPLE RUN on Ubuntu
  #
  # $ swapon -s
  #
  # Filename        Type        Size     Used  Priority
  # /dev/sda5       partition   192740   0     -1
  # /dev/sde1       partition   2096440  0     -2
  #
  ##############################################################################################################################
  def self.swapinfo
    result = Array.new

    case Platform::IMPL
    when :mswin, :mingw
      #raise "MiqSystem.swapinfo: Windows Not Supported"

    when :linux
      rc = MiqUtil.runcmd("swapon -s")

      rc.split("\n").each do |line|
        lArray = line.strip.split(" ")
        next unless lArray.length == 5
        fname, type, size, used, priority = lArray
        next unless size =~ /[0-9]+/
        h = Hash.new
        h[:filename] = fname
        h[:type]     = type
        h[:size]     = size
        h[:used]     = used
        h[:priority] = priority
        result << h
      end
    when :macosx
      #raise "MiqSystem.swapinfo: Mac OSX Not Supported"
    end

    return result
  end

  ##############################################################################################################################
  # DF(1)                                                         User Commands                                                        DF(1)
  #
  # NAME
  #        df - report file system disk space usage
  #
  # SYNOPSIS
  #        df [OPTION]... [FILE]...
  #
  # DESCRIPTION
  #        This  manual  page documents the GNU version of df.  df displays the amount of disk space available on the file system containing
  #        each file name argument.  If no file name is given, the space available on all currently mounted file  systems  is  shown.   Disk
  #        space is shown in 1K blocks by default, unless the environment variable POSIXLY_CORRECT is set, in which case 512-byte blocks are
  #        used.
  #
  #        If an argument is the absolute file name of a disk device node containing a mounted file system, df shows the space available  on
  #        that  file system rather than on the file system containing the device node (which is always the root file system).  This version
  #        of df cannot show the space available on unmounted file systems, because on most kinds of systems doing  so  requires  very  non‐
  #        portable intimate knowledge of file system structures.
  #
  # OPTIONS
  #        Show information about the file system on which each FILE resides, or all file systems by default.
  #
  #        Mandatory arguments to long options are mandatory for short options too.
  #
  #        -a, --all
  #               include dummy file systems
  #
  #        -B, --block-size=SIZE
  #               use SIZE-byte blocks
  #
  #        -h, --human-readable
  #               print sizes in human readable format (e.g., 1K 234M 2G)
  #
  #        -H, --si
  #               likewise, but use powers of 1000 not 1024
  #
  #        -i, --inodes
  #               list inode information instead of block usage
  #
  #        -k     like --block-size=1K
  #
  #        -l, --local
  #               limit listing to local file systems
  #
  #        --no-sync
  #               do not invoke sync before getting usage info (default)
  #
  #        -P, --portability
  #               use the POSIX output format
  #
  #        --sync invoke sync before getting usage info
  #
  #        -t, --type=TYPE
  #               limit listing to file systems of type TYPE
  #
  #        -T, --print-type
  #               print file system type
  #
  #        -x, --exclude-type=TYPE
  #               limit listing to file systems not of type TYPE
  #
  #        -v     (ignored)
  #
  #        --help display this help and exit
  #
  #        --version
  #               output version information and exit
  #
  #        SIZE may be (or may be an integer optionally followed by) one of following: kB 1000, K 1024, MB 1000*1000, M 1024*1024, and so on
  #        for G, T, P, E, Z, Y.
  #
  # AUTHOR
  #        Written by Torbjorn Granlund, David MacKenzie, and Paul Eggert.
  #
  # REPORTING BUGS
  #        Report bugs to <bug-coreutils@gnu.org>.
  #
  # COPYRIGHT
  #        Copyright © 2008 Free Software Foundation, Inc.  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
  #        This is free software: you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
  #
  # SEE ALSO
  #        The full documentation for df is maintained as a Texinfo manual.  If the info and df programs  are  properly  installed  at  your
  #        site, the command
  #
  #               info coreutils ’df invocation’
  #
  #        should give you access to the complete manual.
  #
  # GNU coreutils 6.10                                             April 2008                                                          DF(1)
  #
  #
  # SAMPLE RUN on Ubuntu
  #
  # $ df -T
  #
  # Filesystem    Type   1K-blocks      Used Available Use% Mounted on
  # /dev/sda1     ext3     2924572   1748796   1028384  63% /
  # varrun       tmpfs     1557952       176   1557776   1% /var/run
  # varlock      tmpfs     1557952         0   1557952   0% /var/lock
  # udev         tmpfs     1557952        76   1557876   1% /dev
  # devshm       tmpfs     1557952         0   1557952   0% /dev/shm
  # /dev/sdd1     ext3     2079888    485176   1489892  25% /var/www/miq
  # /dev/sdb1     ext3     2079888     37192   1937876   2% /var/www/miq/vmdb/log
  # /dev/sdc1     ext3     5195812    164884   4769072   4% /var/lib/data
  #
  #
  # $ df -T -i
  #
  # Filesystem    Type    Inodes   IUsed   IFree IUse% Mounted on
  # /dev/sda1     ext3    184736   93765   90971   51% /
  # varrun       tmpfs    221937      43  221894    1% /var/run
  # varlock      tmpfs    221937       4  221933    1% /var/lock
  # udev         tmpfs    221937    2853  219084    2% /dev
  # devshm       tmpfs    221937       1  221936    1% /dev/shm
  # /dev/sdd1     ext3    131072   19781  111291   16% /var/www/miq
  # /dev/sdb1     ext3    131072      41  131031    1% /var/www/miq/vmdb/log
  # /dev/sdc1     ext3    327680    1034  326646    1% /var/lib/data
  #
  #
  ##############################################################################################################################
  def self.disk_usage(file=nil)
    file = nil if file.blank?
    raise "file #{file} does not exist" unless File.exist?(file.to_s) || file.nil?

    case Platform::IMPL
    when :linux
      # Collect bytes
      result = MiqUtil.runcmd("df -T -P #{file}").lines.each_with_object([]) do |line, array|
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
      MiqUtil.runcmd("df -T -P -i #{file}").lines.each do |line|
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
      MiqUtil.runcmd("df -ki #{file}").lines.each_with_object([]) do |line, array|
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


  ##############################################################################################################################
  # DU(1)                                                         User Commands                                                        DU(1)
  #
  # NAME
  #        du - estimate file space usage
  #
  # SYNOPSIS
  #        du [OPTION]... [FILE]...
  #        du [OPTION]... --files0-from=F
  #
  # DESCRIPTION
  #        Summarize disk usage of each FILE, recursively for directories.
  #
  #        Mandatory arguments to long options are mandatory for short options too.
  #
  #        -a, --all
  #               write counts for all files, not just directories
  #
  #        --apparent-size
  #               print apparent sizes, rather than disk usage; although the apparent size is usually smaller, it may be larger due to holes
  #               in (‘sparse’) files, internal fragmentation, indirect blocks, and the like
  #
  #        -B, --block-size=SIZE
  #               use SIZE-byte blocks
  #
  #        -b, --bytes
  #               equivalent to ‘--apparent-size --block-size=1’
  #
  #        -c, --total
  #               produce a grand total
  #
  #        -D, --dereference-args
  #               dereference only symlinks that are listed on the command line
  #
  #        --files0-from=F
  #               summarize disk usage of the NUL-terminated file names specified in file F
  #
  #        -H     like --si, but also evokes a warning; will soon change to be equivalent to --dereference-args (-D)
  #
  #        -h, --human-readable
  #               print sizes in human readable format (e.g., 1K 234M 2G)
  #
  #        --si   like -h, but use powers of 1000 not 1024
  #
  #        -k     like --block-size=1K
  #
  #        -l, --count-links
  #               count sizes many times if hard linked
  #
  #        -m     like --block-size=1M
  #
  #        -L, --dereference
  #               dereference all symbolic links
  #
  #        -P, --no-dereference
  #               don’t follow any symbolic links (this is the default)
  #
  #        -0, --null
  #               end each output line with 0 byte rather than newline
  #
  #        -S, --separate-dirs
  #               do not include size of subdirectories
  #
  #        -s, --summarize
  #               display only a total for each argument
  #
  #        -x, --one-file-system
  #               skip directories on different file systems
  #
  #        -X FILE, --exclude-from=FILE
  #               Exclude files that match any pattern in FILE.
  #
  #        --exclude=PATTERN
  #               Exclude files that match PATTERN.
  #
  #        --max-depth=N
  #               print the total for a directory (or file, with --all) only if it is N or fewer levels below  the  command  line  argument;
  #               --max-depth=0 is the same as --summarize
  #
  #        --time show time of the last modification of any file in the directory, or any of its subdirectories
  #
  #        --time=WORD
  #               show time as WORD instead of modification time: atime, access, use, ctime or status
  #
  #        --time-style=STYLE
  #               show times using style STYLE: full-iso, long-iso, iso, +FORMAT FORMAT is interpreted like ‘date’
  #
  #        --help display this help and exit
  #
  #        --version
  #               output version information and exit
  #
  # SIZE may be (or may be an integer optionally followed by) one of following: kB 1000, K 1024, MB 1000*1000, M 1024*1024, and so on
  # for G, T, P, E, Z, Y.
  #
  #   PATTERNS
  #          PATTERN is a shell pattern (not a regular expression).  The pattern ?  matches any one character, whereas *  matches  any  string
  #          (composed  of  zero,  one  or multiple characters).  For example, *.o will match any files whose names end in .o.  Therefore, the
  #          command
  #
  #                 du --exclude=’*.o’
  #
  #          will skip all files and subdirectories ending in .o (including the file .o itself).
  #
  #   AUTHOR
  #          Written by Torbjorn Granlund, David MacKenzie, Paul Eggert, and Jim Meyering.
  #
  #   REPORTING BUGS
  #          Report bugs to <bug-coreutils@gnu.org>.
  #
  #   COPYRIGHT
  #          Copyright © 2008 Free Software Foundation, Inc.  License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
  #          This is free software: you are free to change and redistribute it.  There is NO WARRANTY, to the extent permitted by law.
  #
  #   SEE ALSO
  #          The full documentation for du is maintained as a Texinfo manual.  If the info and du programs  are  properly  installed  at  your
  #          site, the command
  #
  #                 info coreutils ’du invocation’
  #
  #          should give you access to the complete manual.
  #
  #   GNU coreutils 6.10                                             April 2008                                                          DU(1)
  ##############################################################################################################################
  def self.arch
    arch = Platform::ARCH
    case Platform::OS
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
    if Platform::OS == :unix
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
    File.open(filename,'r') do |f|
      begin
        data = f.read_nonblock(maxlen)
      rescue *retryable_io_errors
        IO.select([f])
        retry
      rescue EOFError
        # Not sure what the data variable contains
      end
    end if File.exist?(filename)

    return data
  end

  def self.open_browser(url)
    require 'shellwords'
    case Platform::IMPL
    when :macosx        then `open #{url.shellescape}`
    when :linux         then `xdg-open #{url.shellescape}`
    when :mingw, :mswin then `start "#{url.gsub('"', '""')}"`
    end
  end
end

if __FILE__ == $0
  def number_to_human_size(size, precision=1)
    size = Kernel.Float(size)
    case
      when size == (1024 ** 0); "1 Byte"
      when size <  (1024 ** 1); "%d Bytes" % size
      when size <  (1024 ** 2); "%.#{precision}f KB"  % (size / (1024.0 ** 1) )
      when size <  (1024 ** 3); "%.#{precision}f MB"  % (size / (1024.0 ** 2) )
      when size <  (1024 ** 4); "%.#{precision}f GB"  % (size / (1024.0 ** 3) )
      else                      "%.#{precision}f TB"  % (size / (1024.0 ** 4) )
    end.sub(".%0#{precision}d" % 0, '')    # .sub('.0', '')
  end

  result = MiqSystem.memory
  puts "Memory: #{result.inspect}"

  result = MiqSystem.swapinfo
  puts "SwapInfo: #{result.inspect}"

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
