module VMDB
  module Util
    # load all subclasses recursively
    def self.eager_load_subclasses(klass)
      ActiveSupport::Dependencies.autoload_paths.each do |root|
        Dir.glob(File.join(root, "#{klass.underscore}_*.rb")).sort.each do |file|
          name = File.basename(file, '.*')
          if name =~ /^#{klass.underscore}_[^_]*$/  # filter out sub-subclasses
            require_dependency file
          end
        end
        const_get(klass).subclasses.each { |k| eager_load_subclasses(k.name) }
      end
    end

    def self.http_proxy_uri
      proxy = VMDB::Config.new("vmdb").config[:http_proxy] || {}
      return nil unless proxy[:host]
      proxy = proxy.dup

      user     = proxy.delete(:user)
      user     &&= CGI.escape(user)
      password = proxy.delete(:password)
      password &&= CGI.escape(password)
      userinfo = "#{user}:#{password}".chomp(":") unless user.blank?

      proxy[:userinfo]   = userinfo
      proxy[:scheme]   ||= "http"
      proxy[:port]     &&= proxy[:port].to_i

      URI::Generic.build(proxy)
    end

    def self.compressed_log_patterns
      # From a log file such as production.log-20090504.gz,
      # create an array of strings containing the date patterns:
      # ["/home/jrafaniello/src/trunk/miq/vmdb/log/*20090502.gz", "/home/jrafaniello/src/trunk/miq/vmdb/log/*20090504.gz"]
      log_dir = File.join(Rails.root, "log")
      gz_pattern = File.join(log_dir, "*[0-9][0-9].gz")
      Dir.glob(gz_pattern).inject([]) do |arr, f|
        f.match(/.+-(\d+\.gz)/)
        name = File.join(log_dir, "*#{$1}")
        arr <<  name unless $1.nil? || arr.include?(name);
        arr
      end
    end

    #TODO: Move these methods to lib in case they can be used elsewhere
    def self.get_evm_log_for_date(pattern)
      files = Dir.glob(pattern)
      files.find {|f| f.match(/\/evm\.log/)}
    end

    def self.log_timestamp(line)
      ts = nil

      # Look for 4 digit year, hyphen, 2 digit month, hyphen, 2 digit day, T, etc.
      # [2009-05-04T18:17:50.350850 #1335]
      # Parse only the time component
      if line.match(/\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6})\s#/)
        t  = Time.parse($1)
        ts = Time.utc(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
      end

      return ts
    end

    def self.log_duration(filename)
      first, last = nil

      begin
        start_of_file = File.open(filename, 'r')

        require 'elif'
        end_of_file = Elif.open(filename) # Use Elif to read a file backwards just as File.open does forwards

        first = find_timestamp(start_of_file)
        last  = find_timestamp(end_of_file)
      ensure
        start_of_file.close if start_of_file
        end_of_file.close   if end_of_file
      end

      return first, last
    end

    def self.get_log_start_end_times(filename)
      start_time = nil
      end_time   = nil

      # Get the start and end time from the log
      unless filename.nil? || !File.exist?(filename)
        if filename.match(/\.gz$/)
          start_time, end_time = log_duration_gz(filename)
        else
          start_time, end_time = log_duration(filename)
        end
      end

      return start_time, end_time
    end

    def self.log_duration_gz(filename)
      log_header = "MIQ(VMDB::Util.log_duration_gz)"
      require 'zlib'

      begin
        $log.info "#{log_header} Opening filename: [#{filename}], size: [#{File.size(filename)}]"
        Zlib::GzipReader.open(filename) { |gz|
          lcount = 0
          gz.each_line { |line| lcount += 1 }
          $log.info "#{log_header} Lines in file: [#{lcount}]"

          hlines = []
          tlines = []

          gz.rewind
          # Collect 2 arrays of lines
          gz.each_line { |line|
            hlines << line if gz.lineno <= 50
            tlines << line if gz.lineno >= (lcount - 50)
          }

          start_time = nil
          hlines.each do |l|
            start_time = log_timestamp(l)
            break unless start_time.nil?
          end

          end_time = nil
          tlines.reverse.each do |l|
            end_time = log_timestamp(l)
            break unless end_time.nil?
          end

          $log.info "#{log_header} Start Time: [#{start_time.inspect}]"
          $log.info "#{log_header} End   Time: [#{end_time.inspect}]"

          return start_time, end_time
        }
      rescue Exception => e
        $log.error "#{log_header} #{e}"
        return []
      end
    end

    def self.zip_logs(zip_filename, dirs, userid = "system")
      require 'zip/zipfilesystem'
      log_header = "MIQ(#{self.name}.zip_logs)"

      zip_dir = Rails.root.join("data", "user", userid)
      FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)

      zfile = zip_dir.join(zip_filename)
      File.delete(zfile) if File.exist?(zfile)
      zfile_display = zfile.relative_path_from(Rails.root)

      zfile = zfile.to_s

      $log.info "#{log_header} Creating: [#{zfile_display}]"
      Zip::ZipFile.open(zfile, Zip::ZipFile::CREATE) do |zip|
        dirs.each do |dir|
          dir = Rails.root.join(dir) unless Pathname.new(dir).absolute?
          Dir.glob(dir).each do |file|
            entry, mtime = add_zip_entry(zip, file)
            $log.info "#{log_header} Adding file: [#{entry}], size: [#{File.size(file)}], mtime: [#{mtime}]"
          end
        end
        zip.close
      end
      $log.info "#{log_header} Created: [#{zfile_display}], Size: [#{File.size(zfile)}]"

      zfile
    end

    private
    #TODO: Make a class out of this so we don't have to pass around the zip.
    def self.add_zip_entry(zip, file_path)
      entry = zip_entry_from_path(file_path)
      mtime = File.mtime(file_path)
      File.directory?(file_path) ? zip.mkdir(entry) : zip.add(entry, file_path)
      zip.file.utime(mtime, entry)
      return entry, mtime
    end

    def self.zip_entry_from_path(path)
      rails_root_directories = Rails.root.to_s.split("/")
      within_rails_root = path.split("/")[0, rails_root_directories.length] == rails_root_directories
      entry = within_rails_root ? Pathname.new(path).relative_path_from(Rails.root).to_s : "ROOT#{path}"
      return entry
    end

    def self.find_timestamp(handle)
      lines     = 0
      max_lines = 250
      ts        = nil

      handle.each_line do |l|
        break if lines >= max_lines
        ts = log_timestamp(l)
        break if ts
        lines += 1
      end

      ts
    end
  end
end
